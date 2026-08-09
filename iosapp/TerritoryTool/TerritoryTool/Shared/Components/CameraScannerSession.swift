import AudioToolbox
import AVFoundation
import Foundation

/// Propietario de la `AVCaptureSession` que leen los escáneres de QR de la app.
///
/// Vive **fuera del actor principal** a propósito. El target compila con
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, así que sin el `nonisolated` esta clase
/// quedaría aislada a main y volveríamos al problema que resuelve: configurar la sesión,
/// arrancarla y pararla son operaciones bloqueantes (Apple recomienda explícitamente una
/// cola serie dedicada). Hacerlas en main producía un tirón al abrir el escáner y otro,
/// muy visible, justo al leer un código.
///
/// Invariante que sostiene el `@unchecked Sendable`: **todo** el estado mutable de abajo
/// —`isConfigured`, `wantsRunning`, `hasReportedCode`, `device`— se lee y se escribe
/// exclusivamente desde `queue`, que es serie. El delegado de metadatos también se entrega
/// ahí, así que la lectura de un código no necesita sincronización adicional. Las llamadas
/// de vuelta hacia la UI salen siempre en el actor principal.
nonisolated final class CameraScannerSession: NSObject, @unchecked Sendable, AVCaptureMetadataOutputObjectsDelegate {

    enum Failure: Error {
        case deviceUnavailable
        case configurationFailed
    }

    /// Sólo para enlazar la `AVCaptureVideoPreviewLayer`, que sí se crea en main.
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "com.jared.TerritoryTool.scanner.session")
    private let onScan: @MainActor @Sendable (String) -> Void
    private let onFailure: @MainActor @Sendable (Failure) -> Void

    // MARK: Estado confinado a `queue`

    private var isConfigured = false
    private var wantsRunning = false
    private var hasReportedCode = false
    private var device: AVCaptureDevice?

    init(
        onScan: @escaping @MainActor @Sendable (String) -> Void,
        onFailure: @escaping @MainActor @Sendable (Failure) -> Void = { _ in }
    ) {
        self.onScan = onScan
        self.onFailure = onFailure
        super.init()
    }

    // MARK: - Control

    /// Configura la sesión la primera vez y la arranca. Vuelve de inmediato.
    func start() {
        queue.async { [self] in
            wantsRunning = true
            hasReportedCode = false
            guard configureIfNeeded() else { return }
            // La pantalla puede haberse cerrado mientras se configuraba: no arrancamos
            // una sesión que ya nadie está mirando.
            guard wantsRunning, !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in
            wantsRunning = false
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    func setRunning(_ running: Bool) {
        running ? start() : stop()
    }

    func setTorch(_ on: Bool) {
        queue.async { [self] in
            guard let device, device.hasTorch, device.isTorchAvailable else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                // Linterna no disponible: ignorar en silencio.
            }
        }
    }

    // MARK: - Configuración

    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }

        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            report(.deviceUnavailable)
            return false
        }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            report(.configurationFailed)
            return false
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard session.canAddInput(input) else {
            report(.configurationFailed)
            return false
        }
        session.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else {
            report(.configurationFailed)
            return false
        }
        session.addOutput(metadataOutput)
        // El delegado se entrega en la misma cola serie que posee la sesión: así
        // `stopRunning()` tras una lectura es una llamada directa que no toca main.
        metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
        metadataOutput.metadataObjectTypes = [.qr]

        device = captureDevice
        isConfigured = true
        return true
    }

    private func report(_ failure: Failure) {
        let onFailure = self.onFailure
        Task { @MainActor in onFailure(failure) }
    }

    // MARK: - Lectura

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Ya estamos en `queue`: `hasReportedCode` no necesita más sincronización.
        guard wantsRunning,
              !hasReportedCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else {
            return
        }

        hasReportedCode = true
        // Congela la previsualización tras la lectura. Antes esto se hacía desde el
        // delegado en main y bloqueaba justo en el instante del escaneo.
        wantsRunning = false
        if session.isRunning { session.stopRunning() }

        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        let onScan = self.onScan
        Task { @MainActor in onScan(value) }
    }
}

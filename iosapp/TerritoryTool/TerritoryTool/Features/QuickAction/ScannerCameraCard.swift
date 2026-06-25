import AVFoundation
import SwiftUI

/// Tarjeta de cámara embebida para la pantalla de Acción rápida.
/// No ocupa toda la pantalla: vive integrada con el resto de la UI y emite el
/// código detectado sin ejecutar acciones de negocio. Gestiona permiso y linterna.
struct ScannerCameraCard: View {
    /// Mientras sea `false` la sesión se pausa (p. ej. al presentar una hoja).
    @Binding var isActive: Bool
    var onScan: (String) -> Void
    var onManualSearch: () -> Void

    @State private var authStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var torchOn = false
    @Environment(\.scenePhase) private var scenePhase

    private let height: CGFloat = 230

    var body: some View {
        ZStack {
            switch authStatus {
            case .authorized:
                cameraContent
            case .notDetermined:
                requestingContent
            default:
                deniedContent
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(Color.hairline.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.glassShadow, radius: 14, x: 0, y: 8)
        .task { await requestAccessIfNeeded() }
    }

    // MARK: - Cámara activa

    private var cameraContent: some View {
        ZStack {
            EmbeddedScannerRepresentable(
                isScanning: isActive && scenePhase == .active,
                torchOn: torchOn,
                onScan: onScan
            )

            VStack {
                HStack {
                    Spacer()
                    torchButton
                }
                Spacer()
                hint
            }
            .padding(AppSpacing.sm)
        }
    }

    private var hint: some View {
        Text("quick_action.scan_overlay")
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, AppSpacing.xs)
    }

    private var torchButton: some View {
        Button {
            torchOn.toggle()
            HapticManager.shared.impact(style: .light)
        } label: {
            Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(Text("quick_action.torch"))
    }

    // MARK: - Permiso pendiente

    private var requestingContent: some View {
        VStack(spacing: AppSpacing.sm) {
            ProgressView().tint(.white)
            Text("quick_action.camera_requesting")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Permiso denegado

    private var deniedContent: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "camera.metering.none")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Text("quick_action.camera_denied_title")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("quick_action.camera_denied_hint")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: AppSpacing.sm) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("quick_action.open_settings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Button(action: onManualSearch) {
                    Text("quick_action.search_manually")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                }
            }
            .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.md)
    }

    private func requestAccessIfNeeded() async {
        guard authStatus == .notDetermined else { return }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authStatus = granted ? .authorized : .denied
    }
}

// MARK: - Puente AVFoundation embebido

private struct EmbeddedScannerRepresentable: UIViewControllerRepresentable {
    var isScanning: Bool
    var torchOn: Bool
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> EmbeddedScannerController {
        let controller = EmbeddedScannerController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ controller: EmbeddedScannerController, context: Context) {
        controller.onScan = onScan
        controller.setScanning(isScanning)
        controller.setTorch(torchOn)
    }
}

final class EmbeddedScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "quickaction.scanner.session")
    private var isConfigured = false
    private var wantsScanning = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        device = videoCaptureDevice
        guard let input = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        isConfigured = true

        if wantsScanning { setScanning(true) }
    }

    func setScanning(_ on: Bool) {
        wantsScanning = on
        guard isConfigured else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if on, !self.session.isRunning {
                self.session.startRunning()
            } else if !on, self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Linterna no disponible: ignorar en silencio.
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard wantsScanning,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        // Pausar para "congelar" la previsualización tras una lectura.
        setScanning(false)
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onScan?(value)
    }
}

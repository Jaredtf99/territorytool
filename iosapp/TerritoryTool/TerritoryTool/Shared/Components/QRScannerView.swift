import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, QRScannerViewControllerDelegate {
        let parent: QRScannerView

        init(parent: QRScannerView) {
            self.parent = parent
        }

        func didScanCode(_ code: String) {
            parent.onScan(code)
            parent.isPresented = false
        }

        func didFail(error: Error) {
            print("QR Scanner failed: \(error.localizedDescription)")
            parent.isPresented = false
        }

        func didCancel() {
            parent.isPresented = false
        }
    }
}

protocol QRScannerViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFail(error: Error)
    func didCancel()
}

/// Sólo UI: la `AVCaptureSession` la posee `CameraScannerSession`, que la configura,
/// arranca y para en su propia cola serie. Antes todo eso ocurría en el hilo principal
/// (configuración en `viewDidLoad`, `stopRunning()` desde el delegado de metadatos), que
/// era el bloqueo más visible del escáner.
class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerViewControllerDelegate?

    private lazy var scannerSession = CameraScannerSession(
        onScan: { [weak self] code in
            self?.delegate?.didScanCode(code)
        },
        onFailure: { [weak self] failure in
            self?.delegate?.didFail(error: failure)
        }
    )
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        // La capa de previsualización es UI: se crea aquí y se enlaza a una sesión que
        // todavía no está configurada. Es seguro; se rellena cuando la cola de la sesión
        // termina de configurarla.
        let layer = AVCaptureVideoPreviewLayer(session: scannerSession.session)
        layer.frame = view.layer.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        addCloseButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        scannerSession.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scannerSession.stop()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    private func addCloseButton() {
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc func closeTapped() {
        delegate?.didCancel()
    }
}

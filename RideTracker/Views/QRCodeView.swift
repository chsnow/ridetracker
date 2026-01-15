import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let data: String

    var body: some View {
        if let image = generateQRCode(from: data) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 100))
                .foregroundColor(.secondary)
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up for better quality
        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - QR Code Share Sheet

struct QRCodeShareSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var shareType: ShareDataType = .history

    enum ShareDataType: String, CaseIterable {
        case history = "History"
        case notes = "Notes"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Share Type", selection: $shareType) {
                    ForEach(ShareDataType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                QRCodeView(data: dataToShare)

                Text("Scan this QR code to import \(shareType.rawValue.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    UIPasteboard.general.string = dataToShare
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .navigationTitle("Share via QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var dataToShare: String {
        switch shareType {
        case .history:
            return appState.exportHistory()
        case .notes:
            return appState.exportNotes()
        }
    }
}

// MARK: - QR Code Scanner

import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRScannerView

        init(_ parent: QRScannerView) {
            self.parent = parent
        }

        func didFindCode(_ code: String) {
            parent.scannedCode = code
            parent.dismiss()
        }

        func didFailWithError(_ error: Error) {
            parent.dismiss()
        }
    }
}

protocol QRScannerDelegate: AnyObject {
    func didFindCode(_ code: String)
    func didFailWithError(_ error: Error)
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRScannerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError(ScannerError.noCameraAvailable)
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFailWithError(error)
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            delegate?.didFailWithError(ScannerError.inputFailed)
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            delegate?.didFailWithError(ScannerError.outputFailed)
            return
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        self.captureSession = session
        self.previewLayer = previewLayer

        // Add frame overlay
        addScanFrame()
    }

    private func addScanFrame() {
        let frameSize: CGFloat = 250
        let frameView = UIView(frame: CGRect(
            x: (view.bounds.width - frameSize) / 2,
            y: (view.bounds.height - frameSize) / 2,
            width: frameSize,
            height: frameSize
        ))
        frameView.layer.borderColor = UIColor.white.cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 12
        view.addSubview(frameView)

        // Add instruction label
        let label = UILabel()
        label.text = "Position QR code within frame"
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: frameView.bottomAnchor, constant: 20)
        ])
    }

    private func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func stopScanning() {
        captureSession?.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            stopScanning()
            delegate?.didFindCode(stringValue)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

enum ScannerError: LocalizedError {
    case noCameraAvailable
    case inputFailed
    case outputFailed

    var errorDescription: String? {
        switch self {
        case .noCameraAvailable:
            return "Camera not available"
        case .inputFailed:
            return "Failed to setup camera input"
        case .outputFailed:
            return "Failed to setup metadata output"
        }
    }
}

// MARK: - QR Scanner Sheet

struct QRScannerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var scannedCode: String?
    @State private var showingImportConfirmation = false
    @State private var importType: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerView(scannedCode: $scannedCode)
                    .ignoresSafeArea()
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: scannedCode) { _, newValue in
                if let code = newValue {
                    processScannedCode(code)
                }
            }
            .alert("Import Data", isPresented: $showingImportConfirmation) {
                Button("Replace All") {
                    performImport(strategy: .replace)
                }
                Button("Merge") {
                    performImport(strategy: .merge)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How would you like to import the scanned \(importType)?")
            }
        }
    }

    private func processScannedCode(_ code: String) {
        // Try to parse as history
        if let data = code.data(using: .utf8) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if (try? decoder.decode([RideHistoryEntry].self, from: data)) != nil {
                importType = "history"
                showingImportConfirmation = true
                return
            }

            if (try? decoder.decode([String: String].self, from: data)) != nil {
                importType = "notes"
                showingImportConfirmation = true
                return
            }
        }

        dismiss()
    }

    private func performImport(strategy: ImportStrategy) {
        guard let code = scannedCode else { return }

        switch importType {
        case "history":
            appState.importHistory(from: code, strategy: strategy)
        case "notes":
            appState.importNotes(from: code, strategy: strategy)
        default:
            break
        }

        dismiss()
    }
}

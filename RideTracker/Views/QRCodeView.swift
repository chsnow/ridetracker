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
    @State private var copied = false

    enum ShareDataType: String, CaseIterable {
        case history = "History"
        case notes = "Notes"
    }

    private var dataToShare: String {
        // Always use compressed format for QR codes (more efficient)
        switch shareType {
        case .history:
            return appState.exportHistoryEncoded()
        case .notes:
            return appState.exportNotesEncoded()
        }
    }

    private var dataSize: String {
        let bytes = dataToShare.utf8.count
        if bytes < 1024 {
            return "\(bytes) bytes"
        } else {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        }
    }

    private var entryCount: Int {
        switch shareType {
        case .history:
            return appState.rideHistory.count
        case .notes:
            return appState.notes.count
        }
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

                VStack(spacing: 4) {
                    Text("Scan to import \(shareType.rawValue.lowercased())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(entryCount) items - \(dataSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)

                Button {
                    UIPasteboard.general.string = dataToShare
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy to Clipboard", systemImage: copied ? "checkmark" : "doc.on.doc")
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
}

// MARK: - QR Code Scanner

import AVFoundation

struct QRScannerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var scannedCode: String?
    @State private var showingImportConfirmation = false
    @State private var importType: String = ""
    @State private var cameraPermissionDenied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            QRScannerRepresentable(
                scannedCode: $scannedCode,
                onError: { _ in
                    cameraPermissionDenied = true
                }
            )
            .ignoresSafeArea()

            // Overlay UI
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding()
                }

                Spacer()

                // Scan frame
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 250, height: 250)

                Text("Position QR code within frame")
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .padding(.top, 20)

                Spacer()
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
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("How would you like to import the scanned \(importType)?")
        }
        .alert("Camera Access", isPresented: $cameraPermissionDenied) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Camera access is required to scan QR codes. Please enable it in Settings.")
        }
    }

    private func processScannedCode(_ code: String) {
        let dataType = DataEncoder.detectDataType(code)

        switch dataType {
        case .compressedHistory, .jsonHistory:
            importType = "history"
            showingImportConfirmation = true
        case .compressedNotes, .jsonNotes:
            importType = "notes"
            showingImportConfirmation = true
        case .unknown:
            dismiss()
        }
    }

    private func performImport(strategy: ImportStrategy) {
        guard let code = scannedCode else { return }

        // Use the unified import method that handles all formats
        let result = appState.importData(from: code, strategy: strategy)

        // Could show an alert with result, but for now just dismiss
        if case .failure = result {
            // Could show error, but QR codes should be valid if detected
        }

        dismiss()
    }
}

// MARK: - QR Scanner UIViewRepresentable

struct QRScannerRepresentable: UIViewRepresentable {
    @Binding var scannedCode: String?
    var onError: (Error) -> Void

    func makeUIView(context: Context) -> QRScannerUIView {
        let view = QRScannerUIView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: QRScannerUIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QRScannerUIViewDelegate {
        let parent: QRScannerRepresentable

        init(_ parent: QRScannerRepresentable) {
            self.parent = parent
        }

        func didFindCode(_ code: String) {
            parent.scannedCode = code
        }

        func didFailWithError(_ error: Error) {
            parent.onError(error)
        }
    }
}

protocol QRScannerUIViewDelegate: AnyObject {
    func didFindCode(_ code: String)
    func didFailWithError(_ error: Error)
}

class QRScannerUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRScannerUIViewDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
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
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)

        self.captureSession = session
        self.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned else { return }

        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            hasScanned = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            captureSession?.stopRunning()
            delegate?.didFindCode(stringValue)
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
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

import AVFoundation
import Combine
import SwiftUI

// Live camera for the Camera tab (Figma 1012:388). Owns only the capture session; the caller decides what a
// photo means. Start on appear and stop on disappear so the camera is off while another tab is showing.
nonisolated final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    enum Status {
        case idle, running, denied, unavailable
    }

    @Published private(set) var status: Status = .idle
    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "dressed.camera.session")
    private var position: AVCaptureDevice.Position = .back
    private var isConfigured = false
    var onPhoto: ((Data) -> Void)?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.run() } else { self?.set(.denied) }
            }
        default:
            set(.denied)
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        set(.idle)
    }

    func flip() {
        queue.async { [self] in
            position = position == .back ? .front : .back
            guard isConfigured, let input = makeInput() else { return }
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            session.addInput(input)
            session.commitConfiguration()
        }
    }

    func capture() {
        queue.async { [self] in
            guard session.isRunning else { return }
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    private func run() {
        queue.async { [self] in
            if !isConfigured {
                guard let input = makeInput(), session.canAddInput(input), session.canAddOutput(output) else {
                    set(.unavailable)
                    return
                }
                session.beginConfiguration()
                session.sessionPreset = .photo
                session.addInput(input)
                session.addOutput(output)
                session.commitConfiguration()
                isConfigured = true
            }
            if !session.isRunning { session.startRunning() }
            set(.running)
        }
    }

    private func makeInput() -> AVCaptureDeviceInput? {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            return nil
        }
        return try? AVCaptureDeviceInput(device: device)
    }

    private func set(_ status: Status) {
        DispatchQueue.main.async { self.status = status }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        DispatchQueue.main.async { self.onPhoto?(data) }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

struct CameraCaptureView: View {
    @StateObject private var camera = CameraController()

    let onClose: () -> Void
    let onUpload: () -> Void
    let onPhoto: (Data) -> Void
    /// Shown top right while a shared item is waiting for review.
    var onReviewShare: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.status == .running {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            } else if camera.status == .denied || camera.status == .unavailable {
                VStack(spacing: DSSpacing.md) {
                    DSIcon("TablerCamera", size: 48)
                    Text(camera.status == .denied
                         ? "Allow camera access in Settings to take photos."
                         : "Camera is unavailable on this device. Use Upload to choose a photo or link.")
                        .font(DSFont.body)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(DSColor.glass)
                .padding(DSSpacing.lg)
            }

            VStack {
                HStack {
                    Button(action: onClose) {
                        DSIcon("TablerX", size: 24).foregroundStyle(DSColor.iconMuted)
                    }
                    .buttonStyle(.ds(.glass))
                    .accessibilityLabel("Close camera")
                    .accessibilityIdentifier("camera.close")
                    Spacer()
                    if let onReviewShare {
                        Button("Review Share", action: onReviewShare).buttonStyle(.ds(.glass))
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)

                Spacer()

                DSCameraControls(onUpload: onUpload, onCapture: camera.capture, onFlip: camera.flip)
                    .padding(.horizontal, 30)
                    .padding(.bottom, DSSpacing.sm)
            }
        }
        .onAppear {
            camera.onPhoto = onPhoto
            camera.start()
        }
        .onDisappear { camera.stop() }
    }
}

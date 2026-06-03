import Foundation
import AVFoundation
import UIKit

/// AVFoundation wrapper: a front-camera video stream for liveness and a
/// back-camera photo capture for documents. UI-agnostic; expose `previewLayer`.
public final class CameraController: NSObject {
    public let session = AVCaptureSession()
    public lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    private let queue = DispatchQueue(label: "com.idanalyzer.docupass.camera")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var frameHandler: ((UIImage, Int) -> Void)?
    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private var usingFront = false

    public static func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
        }
    }

    /// Start the FRONT camera with a per-frame handler for liveness.
    public func startFaceAnalysis(_ handler: @escaping (UIImage, Int) -> Void) {
        frameHandler = handler
        configure(front: true) { [weak self] in
            guard let self else { return }
            if self.session.canAddOutput(self.videoOutput) {
                self.videoOutput.setSampleBufferDelegate(self, queue: self.queue)
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.session.addOutput(self.videoOutput)
            }
        }
    }

    /// Start the BACK camera for still document capture.
    public func startDocumentCapture() {
        configure(front: false) { [weak self] in
            guard let self else { return }
            if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
        }
    }

    public func captureDocument() async throws -> UIImage {
        try await withCheckedContinuation { (cont: CheckedContinuation<UIImage, Error>) in
            photoContinuation = cont
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    public func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    private func configure(front: Bool, addOutput: @escaping () -> Void) {
        usingFront = front
        queue.async {
            self.session.beginConfiguration()
            self.session.inputs.forEach { self.session.removeInput($0) }
            let position: AVCaptureDevice.Position = front ? .front : .back
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            addOutput()
            self.session.commitConfiguration()
            if !self.session.isRunning { self.session.startRunning() }
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let handler = frameHandler else { return }
        // Front camera sensor is landscape-right; present upright.
        let orientation: UIImage.Orientation = usingFront ? .leftMirrored : .right
        guard let image = ImageUtils.image(from: sampleBuffer, orientation: orientation) else { return }
        let ts = Int(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000)
        handler(image, ts)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto,
                            error: Error?) {
        let cont = photoContinuation
        photoContinuation = nil
        if let error { cont?.resume(throwing: error); return }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            cont?.resume(throwing: DocuPassError(code: "CAPTURE_ERROR", message: "No image data"))
            return
        }
        cont?.resume(returning: image)
    }
}

import AVFoundation
import SwiftUI
import UIKit

enum DocupassCameraMode { case document, face }

final class CameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.idanalyzer.docupass.camera.session")
    private let sampleQueue = DispatchQueue(label: "com.idanalyzer.docupass.camera.samples")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let imageLock = NSLock()
    private var latestImageStorage: UIImage?
    private var frameHandler: ((CMSampleBuffer, UIImage.Orientation, Int) -> Void)?
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func start(mode: DocupassCameraMode, frameHandler: ((CMSampleBuffer, UIImage.Orientation, Int) -> Void)? = nil) async throws {
        guard await Self.requestPermission() else { throw CameraError.permissionDenied }
        self.frameHandler = frameHandler
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    try self.configure(mode: mode)
                    if !self.session.isRunning { self.session.startRunning() }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func stop() {
        frameHandler = nil
        sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.session.isRunning else { continuation.resume(throwing: CameraError.notRunning); return }
                self.photoContinuation = continuation
                let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                settings.photoQualityPrioritization = .balanced
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func latestFaceImage() -> UIImage? {
        imageLock.lock(); defer { imageLock.unlock() }
        return latestImageStorage
    }

    private func configure(mode: DocupassCameraMode) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)

        let position: AVCaptureDevice.Position = mode == .face ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else { throw CameraError.cameraUnavailable }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.configurationFailed }
        session.addInput(input)

        switch mode {
        case .document:
            guard session.canAddOutput(photoOutput) else { throw CameraError.configurationFailed }
            session.addOutput(photoOutput)
            if let connection = photoOutput.connection(with: .video), connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
        case .face:
            videoOutput.setSampleBufferDelegate(self, queue: sampleQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): kCMPixelFormat_32BGRA]
            guard session.canAddOutput(videoOutput) else { throw CameraError.configurationFailed }
            session.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
                if connection.isVideoMirroringSupported { connection.isVideoMirrored = true }
            }
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = Int(ProcessInfo.processInfo.systemUptime * 1_000)
        if let image = ImageUtils.image(from: sampleBuffer) {
            imageLock.lock(); latestImageStorage = image; imageLock.unlock()
        }
        frameHandler?(sampleBuffer, .up, timestamp)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let continuation = photoContinuation
        photoContinuation = nil
        if let error { continuation?.resume(throwing: error); return }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { continuation?.resume(throwing: CameraError.noImageData); return }
        continuation?.resume(returning: image)
    }
}

enum CameraError: LocalizedError {
    case permissionDenied, cameraUnavailable, configurationFailed, notRunning, noImageData
    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Camera permission is required."
        case .cameraUnavailable: "The requested camera is unavailable."
        case .configurationFailed: "The camera could not be configured."
        case .notRunning: "The camera is not running."
        case .noImageData: "The camera did not return image data."
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) { uiView.previewLayer.session = session }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

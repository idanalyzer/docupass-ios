import AVFoundation
import UIKit

struct Landmark2D: Sendable {
    let x: Double
    let y: Double
}

#if canImport(MediaPipeTasksVision)
import MediaPipeTasksVision

final class FaceLandmarkerLiveStreamEngine: NSObject {
    var onResult: (([Landmark2D]?, Error?) -> Void)?
    private var landmarker: FaceLandmarker?

    override init() {
        super.init()
        guard let path = DocupassBundle.resources.path(forResource: "face_landmarker", ofType: "task") else { return }
        let options = FaceLandmarkerOptions()
        options.baseOptions.modelAssetPath = path
        options.runningMode = .liveStream
        options.numFaces = 1
        options.minFaceDetectionConfidence = 0.5
        options.minFacePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.outputFaceBlendshapes = false
        options.outputFacialTransformationMatrixes = false
        options.faceLandmarkerLiveStreamDelegate = self
        landmarker = try? FaceLandmarker(options: options)
    }

    var isReady: Bool { landmarker != nil }

    func detectAsync(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestampMilliseconds: Int) {
        guard let image = try? MPImage(sampleBuffer: sampleBuffer, orientation: orientation) else { return }
        try? landmarker?.detectAsync(image: image, timestampInMilliseconds: timestampMilliseconds)
    }

    func close() { landmarker = nil }
}

extension FaceLandmarkerLiveStreamEngine: FaceLandmarkerLiveStreamDelegate {
    func faceLandmarker(_ faceLandmarker: FaceLandmarker, didFinishDetection result: FaceLandmarkerResult?, timestampInMilliseconds: Int, error: Error?) {
        let landmarks = result?.faceLandmarks.first.map { face in face.map { Landmark2D(x: Double($0.x), y: Double($0.y)) } }
        onResult?(landmarks, error)
    }
}
#else
final class FaceLandmarkerLiveStreamEngine {
    var onResult: (([Landmark2D]?, Error?) -> Void)?
    var isReady: Bool { false }
    func detectAsync(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, timestampMilliseconds: Int) {}
    func close() {}
}
#endif

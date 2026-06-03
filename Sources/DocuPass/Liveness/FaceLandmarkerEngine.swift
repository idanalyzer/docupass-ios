import Foundation
import UIKit
import MediaPipeTasksVision

/// Wraps the MediaPipe Tasks Vision `FaceLandmarker` (video mode, single face)
/// using the bundled `face_landmarker.task` — the SAME model the web/Android use.
public final class FaceLandmarkerEngine {
    private let landmarker: FaceLandmarker

    public init?(modelName: String = "face_landmarker") {
        guard let modelPath = DocuPassBundle.resources.path(forResource: modelName, ofType: "task") else { return nil }
        let options = FaceLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .video
        options.numFaces = 1
        options.outputFaceBlendshapes = false
        options.outputFacialTransformationMatrixes = false
        guard let lm = try? FaceLandmarker(options: options) else { return nil }
        self.landmarker = lm
    }

    /// Detect landmarks for one video frame. `timestampMs` must increase monotonically.
    public func detect(image: UIImage, timestampMs: Int) -> [Landmark2D]? {
        guard let mpImage = try? MPImage(uiImage: image) else { return nil }
        guard let result = try? landmarker.detect(videoFrame: mpImage, timestampInMilliseconds: timestampMs) else { return nil }
        guard let face = result.faceLandmarks.first, !face.isEmpty else { return nil }
        return face.map { Landmark2D(x: Double($0.x), y: Double($0.y)) }
    }
}

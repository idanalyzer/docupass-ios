import Combine
import Foundation
import UIKit

@MainActor
final class LivenessController: ObservableObject {
    @Published private(set) var instruction = "ALIGN FACE TO CIRCLE"
    @Published private(set) var progress: Double = 0
    @Published private(set) var capturedCount = 0
    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?

    let camera = CameraController()
    private let engine = FaceLandmarkerLiveStreamEngine()
    private let actions: [KYCAction]
    private let holdSeconds: Double
    private let circleY: Double
    private let circleRadius: Double
    private var actionIndex = -1
    private var stepStart: TimeInterval?
    private var capturedImages: [String] = []
    private var completion: (([String]) -> Void)?
    private var completed = false

    init(actions: [KYCAction], holdSeconds: Double, circleY: Double, circleRadius: Double, completion: @escaping ([String]) -> Void) {
        self.actions = actions; self.holdSeconds = holdSeconds; self.circleY = circleY; self.circleRadius = circleRadius; self.completion = completion
        engine.onResult = { [weak self] landmarks, error in
            Task { @MainActor in self?.process(landmarks: landmarks, error: error) }
        }
    }

    func start() async {
        guard engine.isReady else { errorMessage = "MediaPipe face landmarker could not be initialized."; return }
        do {
            try await camera.start(mode: .face) { [weak engine] buffer, orientation, timestamp in
                engine?.detectAsync(sampleBuffer: buffer, orientation: orientation, timestampMilliseconds: timestamp)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func initiate() {
        guard isReady else { return }
        if actions.isEmpty {
            guard let image = camera.latestFaceImage() else { return }
            completion?([ImageUtils.prepareUpload(image, maxSize: 1_280)])
            completed = true
        } else {
            actionIndex = 0; instruction = actions[0].instruction; progress = 0
        }
    }

    func stop() { camera.stop(); engine.close() }

    private func process(landmarks: [Landmark2D]?, error: Error?) {
        guard !completed else { return }
        if let error { errorMessage = error.localizedDescription; return }
        guard let landmarks, landmarks.count > 454 else { resetStep(alignment: actionIndex == -1); return }
        let aligned = [10, 152, 234, 454].allSatisfy { isInsideCircle(landmarks[$0]) }
        if actionIndex == -1 {
            isReady = aligned; instruction = aligned ? "READY TO SCAN" : "ALIGN FACE TO CIRCLE"; return
        }
        guard aligned else { instruction = "KEEP FACE INSIDE"; stepStart = nil; progress = 0; return }
        guard actions.indices.contains(actionIndex) else { return }
        let minX = landmarks.map(\.x).min() ?? 0, maxX = landmarks.map(\.x).max() ?? 1
        let minY = landmarks.map(\.y).min() ?? 0, maxY = landmarks.map(\.y).max() ?? 1
        let faceWidth = max(maxX - minX, 0.001), faceHeight = max(maxY - minY, 0.001)
        let noseX = (landmarks[1].x - minX) / faceWidth
        let noseY = (landmarks[1].y - minY) / faceHeight
        let triggered: Bool
        switch actions[actionIndex] {
        case .turnLeft: triggered = noseX < 0.38
        case .turnRight: triggered = noseX > 0.62
        case .turnUp: triggered = noseY < 0.42
        case .mouthOpen: triggered = abs(landmarks[14].y - landmarks[13].y) / faceHeight > 0.12
        }
        guard triggered else { instruction = actions[actionIndex].instruction; stepStart = nil; progress = 0; return }
        let now = ProcessInfo.processInfo.systemUptime
        if stepStart == nil { stepStart = now }
        let elapsed = now - (stepStart ?? now)
        progress = min(elapsed / holdSeconds, 1)
        instruction = "HOLDING..."
        guard elapsed >= holdSeconds else { return }
        stepStart = nil; progress = 0
        if let image = camera.latestFaceImage() { capturedImages.append(ImageUtils.prepareUpload(image, maxSize: 1_280)); capturedCount = capturedImages.count }
        actionIndex += 1
        if actions.indices.contains(actionIndex) { instruction = actions[actionIndex].instruction }
        else { instruction = "VERIFIED"; completed = true; completion?(capturedImages) }
    }

    private func resetStep(alignment: Bool) {
        stepStart = nil; progress = 0
        if alignment { isReady = false; instruction = "ALIGN FACE TO CIRCLE" }
    }

    private func isInsideCircle(_ point: Landmark2D) -> Bool {
        let aspectRatio = Double(UIScreen.main.bounds.height / max(UIScreen.main.bounds.width, 1))
        return hypot(point.x - 0.5, (point.y - circleY) * aspectRatio) < circleRadius
    }
}

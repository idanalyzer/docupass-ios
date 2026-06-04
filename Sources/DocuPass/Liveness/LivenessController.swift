import Foundation
import UIKit

/// A 2D normalized facial landmark (x,y in [0,1]).
public struct Landmark2D { public let x: Double; public let y: Double }

public enum LivenessStep { case front, frontSuccess, turnLeft, turnRight, doneSuccess, complete }

public struct LivenessUpdate {
    public let step: LivenessStep
    public let progress: Double
    public let faceVisible: Bool
    public let bestNeutralFrame: UIImage?
}

/// Port of the DocuPass v3 web `FaceChecker`:
/// neutral hold -> turn left -> turn right, best-neutral by eye-polygon area.
/// Pure logic — feed it landmarks + the frame they came from.
public final class LivenessController {
    private let config: LivenessConfig
    private let now: () -> Double // ms

    private var step: LivenessStep = .front
    private var holdStart: Double = -1
    private var phaseStart: Double = -1
    private var bestNeutral: UIImage?
    private var bestArea: Double = -1

    public init(config: LivenessConfig = LivenessConfig(),
                now: @escaping () -> Double = { Date().timeIntervalSince1970 * 1000 }) {
        self.config = config
        self.now = now
    }

    public var currentStep: LivenessStep { step }

    public func reset() {
        step = .front; holdStart = -1; phaseStart = -1; bestNeutral = nil; bestArea = -1
    }

    public func update(landmarks: [Landmark2D]?, frame: UIImage) -> LivenessUpdate {
        let t = now()
        let faceVisible = (landmarks?.count ?? 0) > 366
        switch step {
        case .front: return updateFront(landmarks, frame, t, faceVisible)
        case .frontSuccess: return successAnim(t, next: .turnLeft, faceVisible)
        case .turnLeft: return updateTurn(landmarks, t, faceVisible, left: true)
        case .turnRight: return updateTurn(landmarks, t, faceVisible, left: false)
        case .doneSuccess: return successAnim(t, next: .complete, faceVisible)
        case .complete: return LivenessUpdate(step: .complete, progress: 1, faceVisible: faceVisible, bestNeutralFrame: nil)
        }
    }

    private func updateFront(_ lm: [Landmark2D]?, _ frame: UIImage, _ t: Double, _ faceVisible: Bool) -> LivenessUpdate {
        guard faceVisible, let lm else {
            holdStart = -1
            return LivenessUpdate(step: .front, progress: 0, faceVisible: false, bestNeutralFrame: nil)
        }
        let percent = headPose(lm)
        if holdStart < 0 { holdStart = t }
        if abs(percent) > config.thresholdOffsetPercent { holdStart = t }
        let diff = t - holdStart
        if diff > config.frontStayMs {
            if bestNeutral != nil {
                step = .frontSuccess; phaseStart = -1
                return LivenessUpdate(step: .frontSuccess, progress: 1, faceVisible: true, bestNeutralFrame: nil)
            } else {
                holdStart = t
            }
        } else {
            considerNeutral(lm, frame)
        }
        return LivenessUpdate(step: .front, progress: min(max(diff / config.frontStayMs, 0), 1), faceVisible: true, bestNeutralFrame: nil)
    }

    private func updateTurn(_ lm: [Landmark2D]?, _ t: Double, _ faceVisible: Bool, left: Bool) -> LivenessUpdate {
        let stepNow: LivenessStep = left ? .turnLeft : .turnRight
        guard faceVisible, let lm else {
            holdStart = -1
            return LivenessUpdate(step: stepNow, progress: 0, faceVisible: false, bestNeutralFrame: nil)
        }
        let percent = headPose(lm)
        if holdStart < 0 { holdStart = t }
        let inRange = left ? (percent > config.thresholdTurnPercent) : (percent < -config.thresholdTurnPercent)
        if !inRange { holdStart = t }
        let stayMs = left ? config.leftStayMs : config.rightStayMs
        let diff = t - holdStart
        if diff > stayMs {
            step = left ? .turnRight : .doneSuccess
            holdStart = -1; phaseStart = -1
            return LivenessUpdate(step: step, progress: 1, faceVisible: true, bestNeutralFrame: nil)
        }
        return LivenessUpdate(step: stepNow, progress: min(max(diff / stayMs, 0), 1), faceVisible: true, bestNeutralFrame: nil)
    }

    private func successAnim(_ t: Double, next: LivenessStep, _ faceVisible: Bool) -> LivenessUpdate {
        if phaseStart < 0 { phaseStart = t }
        let diff = t - phaseStart
        if diff > config.successStayMs {
            let isFinal = next == .complete
            step = next; phaseStart = -1; holdStart = -1
            return LivenessUpdate(step: next, progress: isFinal ? 1 : 0, faceVisible: faceVisible,
                                  bestNeutralFrame: isFinal ? bestNeutral : nil)
        }
        let current: LivenessStep = next == .turnLeft ? .frontSuccess : .doneSuccess
        return LivenessUpdate(step: current, progress: min(max(diff / config.successStayMs, 0), 1), faceVisible: faceVisible, bestNeutralFrame: nil)
    }

    private func considerNeutral(_ lm: [Landmark2D], _ frame: UIImage) {
        let area = eyeArea(lm)
        if area > bestArea { bestArea = area; bestNeutral = frame }
    }

    /// percent = (dist(nose,leftCheek) - dist(nose,rightCheek)) / total * 100.
    private func headPose(_ lm: [Landmark2D]) -> Double {
        let pc = lm[4], pl = lm[137], pr = lm[366]
        let dL = hypot(pc.x - pl.x, pc.y - pl.y)
        let dR = hypot(pc.x - pr.x, pc.y - pr.y)
        let total = dL + dR
        guard total != 0 else { return 0 }
        return (dL / total) * 100 - (dR / total) * 100
    }

    private func eyeArea(_ lm: [Landmark2D]) -> Double {
        polygonArea(lm, Self.leftEye) + polygonArea(lm, Self.rightEye)
    }

    private func polygonArea(_ lm: [Landmark2D], _ idx: [Int]) -> Double {
        var area = 0.0
        let n = idx.count
        for k in 0..<n {
            let i = idx[k], j = idx[(k + 1) % n]
            guard i < lm.count, j < lm.count else { return 0 }
            area += lm[i].x * lm[j].y
            area -= lm[j].x * lm[i].y
        }
        return abs(area) / 2
    }

    static let leftEye = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
    static let rightEye = [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466]
}

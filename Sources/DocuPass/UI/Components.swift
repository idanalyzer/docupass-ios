import SwiftUI
import UIKit

/// SwiftUI wrapper around the CameraController preview layer.
struct CameraPreview: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> PreviewContainer {
        let view = PreviewContainer()
        view.backgroundColor = .black
        view.layer.addSublayer(controller.previewLayer)
        view.previewLayer = controller.previewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewContainer, context: Context) {}

    final class PreviewContainer: UIView {
        weak var previewLayer: CALayer?
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

/// A simple finger-drawing signature pad that emits a UIImage on each stroke end.
struct SignaturePad: UIViewRepresentable {
    var onCaptured: (UIImage) -> Void
    var onCleared: () -> Void
    @Binding var clearToken: Int

    func makeUIView(context: Context) -> SignatureCanvas {
        let v = SignatureCanvas()
        v.onCaptured = onCaptured
        v.backgroundColor = .white
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.lightGray.cgColor
        return v
    }

    func updateUIView(_ uiView: SignatureCanvas, context: Context) {
        if context.coordinator.lastClear != clearToken {
            context.coordinator.lastClear = clearToken
            uiView.clear()
            onCleared()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var lastClear = 0 }

    final class SignatureCanvas: UIView {
        var onCaptured: ((UIImage) -> Void)?
        private var paths: [UIBezierPath] = []
        private var current: UIBezierPath?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let p = touches.first?.location(in: self) else { return }
            let path = UIBezierPath()
            path.lineWidth = 3
            path.lineCapStyle = .round
            path.move(to: p)
            current = path
            paths.append(path)
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let p = touches.first?.location(in: self) else { return }
            current?.addLine(to: p)
            setNeedsDisplay()
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            onCaptured?(snapshot())
        }
        override func draw(_ rect: CGRect) {
            UIColor.black.setStroke()
            paths.forEach { $0.stroke() }
        }
        func clear() { paths.removeAll(); current = nil; setNeedsDisplay() }
        func snapshot() -> UIImage {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(bounds)
                UIColor.black.setStroke()
                paths.forEach { $0.stroke() }
            }
        }
    }
}

extension UIImage {
    /// PNG data URL (DocuPass signatures are sent this way, matching the web flow).
    func pngDataURL() -> String {
        guard let data = pngData() else { return "" }
        return "data:image/png;base64," + data.base64EncodedString()
    }
}

import SwiftUI

struct BiometricView: View {
    let actions: [KYCAction]
    let settings: KYCSettings
    let isBusy: Bool
    let onComplete: ([String]) -> Void
    @StateObject private var model: LivenessController

    init(actions: [KYCAction], settings: KYCSettings, isBusy: Bool, onComplete: @escaping ([String]) -> Void) {
        self.actions = actions; self.settings = settings; self.isBusy = isBusy; self.onComplete = onComplete
        _model = StateObject(wrappedValue: LivenessController(actions: actions, holdSeconds: settings.turnTimeSeconds, circleY: settings.maskCircleY, circleRadius: settings.maskCircleRadius, completion: onComplete))
    }

    var body: some View {
        ZStack {
            CameraPreview(session: model.camera.session).ignoresSafeArea()
            FaceMask(circleY: settings.maskCircleY, radius: settings.maskCircleRadius, warning: model.instruction.contains("KEEP") || model.instruction.contains("ALIGN"), progress: model.progress)
            VStack(spacing: 10) {
                Spacer()
                Text(model.instruction).font(.system(size: 19, weight: .black)).multilineTextAlignment(.center).padding(.horizontal, 20).padding(.vertical, 12).background(Color.black.opacity(0.55)).cornerRadius(6)
                Text("Captured faces: \(model.capturedCount)").font(.caption).foregroundColor(.white.opacity(0.8))
                if let error = model.errorMessage { Text(error).font(.caption).multilineTextAlignment(.center).padding(9).background(Color.red.opacity(0.78)).cornerRadius(5) }
                if model.instruction == "READY TO SCAN" || model.instruction == "ALIGN FACE TO CIRCLE" {
                    Button { model.initiate() } label: { Label("INITIATE SCAN", systemImage: "faceid") }.buttonStyle(PrimaryButtonStyle()).disabled(!model.isReady || isBusy)
                        .frame(maxWidth: 280).padding(.top, 8)
                }
            }.padding(.horizontal, 28).padding(.bottom, 54)
        }
        .task { await model.start() }
        .onDisappear { model.stop() }
    }
}

private struct FaceMask: View {
    let circleY: Double
    let radius: Double
    let warning: Bool
    let progress: Double
    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * circleY)
            let diameter = proxy.size.width * radius * 2
            let circle = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
            Canvas { context, size in
                var mask = Path(CGRect(origin: .zero, size: size)); mask.addEllipse(in: circle)
                context.fill(mask, with: .color(.black.opacity(0.68)), style: FillStyle(eoFill: true))
                context.stroke(Path(ellipseIn: circle), with: .color(warning ? .red : KYCTheme.accent.opacity(0.55)), lineWidth: 4)
                if progress > 0 {
                    var arc = Path(); arc.addArc(center: center, radius: diameter / 2, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
                    context.stroke(arc, with: .color(KYCTheme.accent), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}

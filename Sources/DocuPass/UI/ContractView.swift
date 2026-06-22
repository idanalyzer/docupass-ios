import SwiftUI
import WebKit

struct ContractView: View {
    let state: DocupassSessionState
    let signatureFields: [DocupassContractSignatureField]
    let isBusy: Bool
    let onSubmit: ([String: String]) -> Void
    @State private var strokes: [[CGPoint]] = []
    @State private var activeStroke: [CGPoint] = []
    @State private var padSize: CGSize = .zero

    private var hasSignature: Bool { !strokes.flatMap { $0 }.isEmpty || !activeStroke.isEmpty }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepLabel(text: "STEP: REVIEW CONTRACT")
            ContractHTMLView(html: cleanContractHTML(state.contractSource ?? "")).background(.white).cornerRadius(6)
            if !signatureFields.isEmpty {
                Text("\(signatureFields.count) signature field(s) required").font(.caption).foregroundColor(KYCTheme.muted)
                GeometryReader { geometry in
                    ZStack {
                        Color.white
                        SignatureDrawing(strokes: strokes, activeStroke: activeStroke)
                        if !hasSignature { Text("Draw signature here").foregroundColor(.gray) }
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        if activeStroke.isEmpty { activeStroke = [value.location] } else { activeStroke.append(value.location) }
                    }.onEnded { _ in if !activeStroke.isEmpty { strokes.append(activeStroke) }; activeStroke = [] })
                    .onAppear { padSize = geometry.size }.onChange(of: geometry.size) { padSize = $0 }
                }.frame(height: 160).overlay(RoundedRectangle(cornerRadius: 6).stroke(hasSignature ? KYCTheme.accent : Color.gray)).cornerRadius(6)
                HStack { Spacer(); Button { strokes = []; activeStroke = [] } label: { Label("CLEAR", systemImage: "eraser.fill") }.foregroundColor(.white).disabled(!hasSignature || isBusy) }
            } else { Text("No signature image is required for this contract.").font(.caption).foregroundColor(KYCTheme.muted) }
            Button { submit() } label: { Label("ACCEPT AND SUBMIT", systemImage: "checkmark.seal.fill") }.buttonStyle(PrimaryButtonStyle()).disabled(isBusy || (!signatureFields.isEmpty && !hasSignature))
        }.padding(.horizontal, 16).padding(.top, 72).padding(.bottom, 16)
    }

    private func submit() {
        guard !signatureFields.isEmpty else { onSubmit([:]); return }
        guard let dataURL = signatureDataURL(strokes: strokes + (activeStroke.isEmpty ? [] : [activeStroke]), size: padSize) else { return }
        onSubmit(Dictionary(uniqueKeysWithValues: signatureFields.map { ($0.uid, dataURL) }))
    }
}

private struct SignatureDrawing: View {
    let strokes: [[CGPoint]]
    let activeStroke: [CGPoint]
    var body: some View {
        Canvas { context, _ in
            for stroke in strokes + [activeStroke] where !stroke.isEmpty {
                var path = Path(); path.move(to: stroke[0]); for point in stroke.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }.allowsHitTesting(false)
    }
}

private struct ContractHTMLView: UIViewRepresentable {
    let html: String
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration(); configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration); view.isOpaque = false; view.backgroundColor = .white; view.scrollView.backgroundColor = .white
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) { if context.coordinator.lastHTML != html { context.coordinator.lastHTML = html; view.loadHTMLString(html, baseURL: nil) } }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var lastHTML = "" }
}

private func cleanContractHTML(_ source: String) -> String {
    let range = NSRange(source.startIndex..., in: source)
    let cleaned = (try? NSRegularExpression(pattern: #"%\{[0-9A-Za-z_.\-]+\}"#))?.stringByReplacingMatches(in: source, range: range, withTemplate: "") ?? source
    if cleaned.range(of: "<html", options: .caseInsensitive) != nil { return cleaned }
    return "<html><head><meta name='viewport' content='width=device-width,initial-scale=1'><style>body{font-family:-apple-system;color:#111;padding:12px;line-height:1.45}img[data-signature],div[data-signature]{display:none}</style></head><body>\(cleaned)</body></html>"
}

private func signatureDataURL(strokes: [[CGPoint]], size: CGSize) -> String? {
    guard size.width > 0, size.height > 0, strokes.contains(where: { !$0.isEmpty }) else { return nil }
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
        UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
        let path = UIBezierPath(); path.lineWidth = min(max(size.height * 0.025, 4), 12); path.lineCapStyle = .round; path.lineJoinStyle = .round
        for stroke in strokes where !stroke.isEmpty { path.move(to: stroke[0]); for point in stroke.dropFirst() { path.addLine(to: point) } }
        UIColor.black.setStroke(); path.stroke()
    }
    guard let data = image.pngData() else { return nil }
    return "data:image/png;base64,\(data.base64EncodedString())"
}

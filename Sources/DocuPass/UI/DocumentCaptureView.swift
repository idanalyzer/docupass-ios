import SwiftUI
import UIKit

private enum CaptureSide: String, Identifiable { case front, back; var id: String { rawValue } }

struct DocumentCaptureView: View {
    let documentType: KYCDocumentType?
    let documentSide: Int?
    let isBusy: Bool
    let onCaptured: (String, String?) -> Void
    @State private var camera = CameraController()
    @State private var activeSide: CaptureSide?
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var frontBase64: String?
    @State private var backBase64: String?
    @State private var cameraError: String?
    @State private var isCapturing = false
    @State private var portraitCard: Bool

    init(documentType: KYCDocumentType?, documentSide: Int?, isBusy: Bool, onCaptured: @escaping (String, String?) -> Void) {
        self.documentType = documentType; self.documentSide = documentSide; self.isBusy = isBusy; self.onCaptured = onCaptured
        _portraitCard = State(initialValue: documentType == .driverLicense)
    }

    private var requiresBack: Bool {
        switch documentSide { case 1: false; case 2: documentType != .passport; default: documentType?.requiresBackSide == true }
    }
    private var ready: Bool { frontBase64 != nil && (!requiresBack || backBase64 != nil) }

    var body: some View {
        Group { if activeSide == nil { reviewView } else { cameraView } }
            .onDisappear { camera.stop() }
    }

    private var reviewView: some View {
        ScrollView {
            VStack(spacing: 14) {
                StepLabel(text: "STEP: DOCUMENT UPLOAD")
                Text("Front: \(frontBase64 == nil ? "Pending" : "Done")  |  Back: \(!requiresBack ? "Not required" : backBase64 == nil ? "Pending" : "Done")")
                    .font(.caption).foregroundColor(KYCTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                preview(image: frontImage, placeholder: "No front photo yet")
                Button { activeSide = .front } label: { Label("CAPTURE DOCUMENT FRONT", systemImage: "camera.fill") }.buttonStyle(PrimaryButtonStyle()).disabled(isBusy)
                if requiresBack {
                    preview(image: backImage, placeholder: "No back photo yet")
                    Button { activeSide = .back } label: { Label("CAPTURE DOCUMENT BACK", systemImage: "camera.fill") }.buttonStyle(SecondaryButtonStyle()).disabled(isBusy)
                } else { Text("Back side is not required for passport.").font(.caption).foregroundColor(KYCTheme.muted).frame(maxWidth: .infinity, alignment: .leading) }
                Button { guard let frontBase64 else { return }; onCaptured(frontBase64, requiresBack ? backBase64 : nil) } label: { Label("UPLOAD DOCUMENT", systemImage: "arrow.up.circle.fill") }
                    .buttonStyle(PrimaryButtonStyle()).disabled(isBusy || !ready).padding(.top, 8)
            }.padding(.horizontal, 24).padding(.top, 90).padding(.bottom, 28)
        }
    }

    private var cameraView: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()
            DocumentMask(documentType: documentType, portraitCard: portraitCard)
            VStack {
                HStack {
                    Button { camera.stop(); activeSide = nil } label: { Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44).background(Color.black.opacity(0.55)).clipShape(Circle()) }.accessibilityLabel("Close camera")
                    Spacer()
                    Text(activeSide == .front ? "FRONT" : "BACK").font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 7).background(Color.black.opacity(0.55)).cornerRadius(5)
                }.padding(16)
                Spacer()
                if let cameraError { Text(cameraError).font(.caption).padding(10).background(Color.red.opacity(0.8)).cornerRadius(5).padding(.horizontal) }
                ZStack {
                    Button(action: capture) { ZStack { Circle().stroke(.white, lineWidth: 4).frame(width: 82, height: 82); Circle().fill(.white).frame(width: 64, height: 64) } }
                        .disabled(isCapturing).accessibilityLabel("Capture photo")
                    if documentType == .driverLicense || documentType == .identityCard {
                        HStack { Spacer(); Button { portraitCard.toggle() } label: { Image(systemName: "rectangle.rotate").frame(width: 46, height: 42).background(Color.black.opacity(0.55)).cornerRadius(6) }.accessibilityLabel("Toggle card orientation") }.padding(.trailing, 20)
                    }
                }.padding(.bottom, 32)
            }
        }
        .task(id: activeSide?.id) {
            guard activeSide != nil else { return }
            do { try await camera.start(mode: .document) } catch { cameraError = error.localizedDescription }
        }
    }

    @MainActor
    private func capture() {
        isCapturing = true
        Task { @MainActor in
            do {
                let image = try await camera.capturePhoto()
                let portraitDevice = UIScreen.main.bounds.height > UIScreen.main.bounds.width
                let cropped = ImageUtils.cropDocument(image, type: documentType, portraitCard: portraitCard, portraitDevice: portraitDevice)
                let encoded = ImageUtils.prepareUpload(cropped)
                if activeSide == .front { frontImage = cropped; frontBase64 = encoded } else { backImage = cropped; backBase64 = encoded }
                camera.stop(); activeSide = nil; isCapturing = false
            } catch {
                cameraError = error.localizedDescription
                isCapturing = false
            }
        }
    }

    private func preview(image: UIImage?, placeholder: String) -> some View {
        ZStack {
            Color.white.opacity(0.06)
            if let image { Image(uiImage: image).resizable().scaledToFit().padding(8) }
            else { VStack(spacing: 7) { Image(systemName: "doc.viewfinder").font(.title2); Text(placeholder).font(.caption) }.foregroundColor(KYCTheme.muted) }
        }.frame(height: 140).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.16))).cornerRadius(6)
    }
}

private struct DocumentMask: View {
    let documentType: KYCDocumentType?
    let portraitCard: Bool
    var body: some View {
        GeometryReader { proxy in
            let rect = maskFrame(in: proxy.size)
            Canvas { context, size in
                var path = Path(CGRect(origin: .zero, size: size)); path.addRoundedRect(in: rect, cornerSize: CGSize(width: 14, height: 14))
                context.fill(path, with: .color(.black.opacity(0.58)), style: FillStyle(eoFill: true))
                context.stroke(Path(roundedRect: rect, cornerRadius: 14), with: .color(KYCTheme.accent), lineWidth: 3)
                if documentType == .passport {
                    let y = rect.midY
                    context.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height / 2)), with: .color(.black.opacity(0.36)))
                    context.stroke(Path { $0.move(to: CGPoint(x: rect.minX, y: y)); $0.addLine(to: CGPoint(x: rect.maxX, y: y)) }, with: .color(.yellow), lineWidth: 2)
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false)
    }

    private func maskFrame(in size: CGSize) -> CGRect {
        let portraitDevice = size.height > size.width
        let aspect: CGFloat
        if documentType == .passport {
            aspect = portraitDevice ? 88.0 / 125.0 : 125.0 / 88.0
        } else {
            aspect = portraitCard && portraitDevice ? 53.98 / 85.60 : 85.60 / 53.98
        }
        var width = size.width * 0.9
        var height = width / aspect
        let maximumHeight = size.height * 0.82
        if height > maximumHeight {
            height = maximumHeight
            width = height * aspect
        }
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }
}

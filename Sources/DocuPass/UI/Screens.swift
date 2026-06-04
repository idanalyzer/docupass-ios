import SwiftUI
import UIKit
import WebKit

private let documentMaxSize: CGFloat = 1600
private let documentQuality: CGFloat = 0.9

/// Capture-requirement bullets driven by the session's verify-* flags (mirrors the web).
private func documentRequirements(_ session: DocuPassSession, _ str: DocuPassStrings) -> [String] {
    var r = [str.reqClear]
    if !session.verifyDocumentNo.isEmpty { r.append(str.reqDocumentNo) }
    if !session.verifyName.isEmpty { r.append(str.reqName) }
    if !session.verifyDob.isEmpty || !session.verifyAge.isEmpty { r.append(str.reqDob) }
    if !session.verifyAddress.isEmpty { r.append(str.reqAddress) }
    if !session.verifyPostCode.isEmpty { r.append(str.reqPostcode) }
    return r
}

// MARK: - Document

struct DocumentView: View {
    @ObservedObject var controller: DocuPassController
    let session: DocuPassSession

    var body: some View {
        if session.selectedDocumentType.isEmpty {
            DocumentSelection(controller: controller, session: session)
        } else {
            DocumentCapture(controller: controller, session: session)
        }
    }
}

private struct DocumentSelection: View {
    @Environment(\.docuPassStrings) private var strings
    @ObservedObject var controller: DocuPassController
    let session: DocuPassSession
    @State private var country: String = ""
    @State private var type: String = ""

    private var countries: [Country] { CountryCatalog.shared.countries(accepted: session.acceptedCountries) }
    private var types: [DocumentTypeOption] {
        CountryCatalog.shared.documentTypes(iso: country, accepted: session.acceptedTypes)
    }

    var body: some View {
        Form {
            Picker(strings.countryLabel, selection: $country) {
                Text("Select").tag("")
                ForEach(countries) { Text($0.name_en).tag($0.iso) }
            }
            Picker(strings.documentTypeLabel, selection: $type) {
                Text("Select").tag("")
                ForEach(types) { Text($0.label).tag($0.code) }
            }
            Section(strings.pleaseMakeSure) {
                ForEach(documentRequirements(session, strings), id: \.self) { Text("•  \($0)").font(.footnote) }
            }
            Button(strings.continueButton) {
                Task { await controller.submitDocumentSelection(country: country, type: type) }
            }.disabled(country.isEmpty || type.isEmpty)
        }
        .onAppear {
            if country.isEmpty { country = session.selectedDocumentCountry.isEmpty ? (countries.first?.iso ?? "") : session.selectedDocumentCountry }
        }
    }
}

private struct DocumentCapture: View {
    @Environment(\.docuPassStrings) private var strings
    @ObservedObject var controller: DocuPassController
    let session: DocuPassSession
    @State private var camera = CameraController()
    @State private var front: UIImage?
    @State private var capturing = false

    private var needBack: Bool { !session.isFrontOnly }

    private var captureLabel: String {
        if front == nil {
            return session.selectedDocumentType.uppercased() == "P" ? strings.capturePassport : strings.captureFront
        }
        return strings.captureBack
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreview(controller: camera).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(captureLabel)
                    .font(.headline).foregroundColor(.white)
                Button(capturing ? "…" : strings.capture) { capture() }
                    .buttonStyle(.borderedProminent).disabled(capturing)
            }.padding(24)
        }
        .onAppear { camera.startDocumentCapture() }
        .onDisappear { camera.stop() }
    }

    private func capture() {
        capturing = true
        Task {
            defer { capturing = false }
            guard let image = try? await camera.captureDocument() else { return }
            if front == nil {
                front = image
                if !needBack { await submit(front: image, back: nil) }
            } else {
                await submit(front: front!, back: image)
            }
        }
    }

    private func submit(front: UIImage, back: UIImage?) async {
        let f = ImageUtils.prepareUpload(front, maxSize: documentMaxSize, quality: documentQuality)
        let b = back.map { ImageUtils.prepareUpload($0, maxSize: documentMaxSize, quality: documentQuality) }
        await controller.submitDocument(frontBase64: f, backBase64: b)
    }
}

// MARK: - Face / liveness

@MainActor
final class LivenessCoordinator: ObservableObject {
    let camera = CameraController()
    @Published var update: LivenessUpdate?
    @Published var ready = false

    private var engine: FaceLandmarkerEngine?
    private let liveness: LivenessController
    private let config: LivenessConfig
    private var submitted = false
    var onComplete: ((String) -> Void)?

    init(config: LivenessConfig) {
        self.config = config
        self.liveness = LivenessController(config: config)
    }

    func start() {
        engine = FaceLandmarkerEngine()
        ready = engine != nil
        camera.startFaceAnalysis { [weak self] image, ts in self?.onFrame(image, ts) }
    }

    func stop() { camera.stop() }

    // Called on the camera queue; liveness state stays on this single thread.
    nonisolated private func onFrame(_ image: UIImage, _ ts: Int) {
        Task { @MainActor in
            guard let engine = self.engine, !self.submitted else { return }
            let scaled = ImageUtils.scale(image, maxSize: self.config.maxImageSize)
            let landmarks = engine.detect(image: scaled, timestampMs: ts)
            let u = self.liveness.update(landmarks: landmarks, frame: scaled)
            self.update = u
            if u.step == .complete, let best = u.bestNeutralFrame, !self.submitted {
                self.submitted = true
                self.onComplete?(ImageUtils.jpegBase64(best, quality: self.config.jpegQuality))
            }
        }
    }
}

struct FaceView: View {
    @Environment(\.docuPassStrings) private var strings
    @ObservedObject var controller: DocuPassController
    let session: DocuPassSession
    @StateObject private var coordinator: LivenessCoordinator

    init(controller: DocuPassController, session: DocuPassSession) {
        self.controller = controller
        self.session = session
        _coordinator = StateObject(wrappedValue: LivenessCoordinator(config: controller.config.liveness))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreview(controller: coordinator.camera).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(coordinator.ready ? instruction(coordinator.update?.step ?? .front) : strings.faceLoading)
                    .font(.headline).foregroundColor(.white).multilineTextAlignment(.center)
                if let u = coordinator.update {
                    ProgressView(value: u.progress)
                    if !u.faceVisible && coordinator.ready {
                        Text(strings.faceNoFace).font(.caption).foregroundColor(.white)
                    }
                }
            }.padding(24)
        }
        .onAppear {
            coordinator.onComplete = { base64 in Task { await controller.submitFace(frames: [base64]) } }
            coordinator.start()
        }
        .onDisappear { coordinator.stop() }
    }

    private func instruction(_ step: LivenessStep) -> String {
        switch step {
        case .front: return strings.faceForward
        case .frontSuccess: return strings.faceGreat
        case .turnLeft: return strings.faceTurnLeft
        case .turnRight: return strings.faceTurnRight
        case .doneSuccess, .complete: return strings.faceDone
        }
    }
}

// MARK: - Custom form

struct CustomFormView: View {
    @Environment(\.docuPassStrings) private var strings
    @ObservedObject var controller: DocuPassController
    let session: DocuPassSession
    @State private var answers: [String: String] = [:]

    var body: some View {
        Form {
            ForEach(session.customField) { field in
                switch field.parsedType {
                case .text, .multiline:
                    TextField(field.fieldLabel, text: binding(field.fieldId))
                case .dropdown:
                    Picker(field.fieldLabel, selection: binding(field.fieldId)) {
                        Text("Select").tag("")
                        ForEach(field.dropdownOptions) { Text($0.display).tag($0.value) }
                    }
                }
            }
            Button(strings.continueButton) {
                Task { await controller.submitForm(answers: answers) }
            }.disabled(!session.customField.allSatisfy { !(answers[$0.fieldId] ?? "").isEmpty })
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { answers[key] ?? "" }, set: { answers[key] = $0 })
    }
}

// MARK: - Phone

struct PhoneView: View {
    @Environment(\.docuPassStrings) private var strings
    @ObservedObject var controller: DocuPassController
    let session: DocuPassSession
    @State private var dialCode = ""
    @State private var localNumber = ""
    @State private var code = ""
    @State private var codeSent = false

    private var preset: Bool { !session.userPhone.isEmpty }
    private var number: String? { preset ? nil : dialCode + String(localNumber.drop(while: { $0 == "0" })) }

    var body: some View {
        Form {
            if preset {
                Text("\(strings.phonePresetPrefix)\(session.userPhone)")
            } else {
                HStack {
                    if !session.phoneCountryCode.isEmpty {
                        // Dial-code picker from the session (matches the web's <select>).
                        Menu {
                            ForEach(Array(session.phoneCountryCode.enumerated()), id: \.offset) { _, pc in
                                Button("\(pc.name) \(pc.dialCode)") { dialCode = pc.dialCode }
                            }
                        } label: {
                            Text(dialCode.isEmpty ? strings.phoneCodeLabel : dialCode).frame(width: 70, alignment: .leading)
                        }
                    } else {
                        TextField(strings.phoneCodeLabel, text: $dialCode).frame(width: 70)
                    }
                    TextField(strings.phoneNumberLabel, text: $localNumber).keyboardType(.phonePad)
                }
            }
            HStack {
                Button(strings.phoneSendSms) { Task { await controller.sendPhoneCode(number: number, channel: .sms); codeSent = true } }
                Spacer()
                Button(strings.phoneCall) { Task { await controller.sendPhoneCode(number: number, channel: .call); codeSent = true } }
            }
            if codeSent {
                TextField(strings.phoneCodeEntryLabel, text: $code).keyboardType(.numberPad)
                Button(strings.phoneVerify) {
                    Task { await controller.verifyPhoneCode(number: number, code: code) }
                }.disabled(code.count != 6)
            }
        }
        .onAppear { if dialCode.isEmpty { dialCode = session.phoneCountryCode.first?.dialCode ?? "+1" } }
    }
}

// MARK: - Contract

struct ContractView: View {
    @Environment(\.docuPassStrings) private var strings
    @ObservedObject var controller: DocuPassController
    let session: DocuPassSession
    @State private var signatures: [String: String] = [:]
    @State private var clearToken = 0

    // Signature fields are `<img data-signature …>` / `<div data-signature …>`
    // elements carrying a data-uid (matches the DocuPass v3 web client). Other
    // data-uid elements (e.g. data-image placeholders) are NOT signature fields.
    private var uids: [String] {
        let text = session.contractSource
        guard let tagRe = try? NSRegularExpression(
                pattern: "<[a-zA-Z][^>]*\\bdata-signature\\b[^>]*>", options: [.caseInsensitive]),
              let uidRe = try? NSRegularExpression(pattern: "data-uid=\"([^\"]+)\"") else { return [] }
        var seen: [String] = []
        for tagMatch in tagRe.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let tagRange = Range(tagMatch.range, in: text) else { continue }
            let tag = String(text[tagRange])
            if let uidMatch = uidRe.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
               let uidRange = Range(uidMatch.range(at: 1), in: tag) {
                let uid = String(tag[uidRange])
                if !seen.contains(uid) { seen.append(uid) }
            }
        }
        return seen
    }

    // Strip leftover unfilled prefill placeholders, like the web client does.
    private var displayHtml: String {
        session.contractSource.replacingOccurrences(
            of: "%\\{[0-9A-Za-z_.\\-]+\\}", with: "", options: .regularExpression)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(strings.contractTitle).font(.title3).bold()
                if !session.contractSource.isEmpty {
                    ContractWebView(html: displayHtml).frame(height: 360)
                }
                ForEach(uids, id: \.self) { uid in
                    Text(strings.contractSignature).font(.subheadline)
                    SignaturePad(
                        onCaptured: { signatures[uid] = $0.pngDataURL() },
                        onCleared: { signatures[uid] = nil },
                        clearToken: $clearToken
                    ).frame(height: 160)
                }
                Button(uids.isEmpty ? strings.contractAccept : strings.contractSubmit) {
                    Task { await controller.submitContract(signatures: signatures) }
                }.disabled(!uids.allSatisfy { signatures[$0] != nil })
            }.padding(16)
        }
    }
}

private struct ContractWebView: UIViewRepresentable {
    let html: String
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
}

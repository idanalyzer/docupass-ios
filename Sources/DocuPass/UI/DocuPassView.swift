import SwiftUI

/// The drop-in DocuPass verification UI. Give it a `DocuPassConfig` (just a
/// `reference`) and a result callback — it handles camera permission, the whole
/// server-driven flow, on-device liveness, and capture.
///
/// ```swift
/// DocuPassView(config: DocuPassConfig(reference: "US…")) { result in
///     // .completed / .failed / .cancelled / .error
/// }
/// ```
public struct DocuPassView: View {
    @StateObject private var controller: DocuPassController
    private let strings: DocuPassStrings
    private let theme: DocuPassTheme
    private let onResult: (DocuPassResult) -> Void

    @State private var permissionChecked = false
    @State private var cameraGranted = false
    @State private var welcomeAck = false
    @State private var delivered = false

    public init(
        config: DocuPassConfig,
        strings: DocuPassStrings = DocuPassStrings(),
        theme: DocuPassTheme = DocuPassTheme(),
        onResult: @escaping (DocuPassResult) -> Void
    ) {
        _controller = StateObject(wrappedValue: DocuPassController(config: config))
        self.strings = strings
        self.theme = theme
        self.onResult = onResult
    }

    public var body: some View {
        content
            .environment(\.docuPassStrings, strings)
            .environment(\.docuPassTheme, theme)
            .tint(theme.primaryColor)
            .task {
                guard !permissionChecked else { return }
                permissionChecked = true
                cameraGranted = await CameraController.requestPermission()
                if cameraGranted {
                    await controller.start()
                } else {
                    deliver(.cancelled(reference: controller.config.reference))
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch controller.state {
        case .idle, .loading:
            ProgressView()
        case .finished(let result):
            ProgressView().onAppear { deliver(result) }
        case .step(let session):
            if !welcomeAck && (!session.welcomeMessage.isEmpty || !session.companyName.isEmpty) {
                WelcomeView(session: session) { welcomeAck = true }
            } else {
                stepView(session)
            }
        }
    }

    @ViewBuilder private func stepView(_ session: DocuPassSession) -> some View {
        switch session.parsedTask {
        case .document: DocumentView(controller: controller, session: session)
        case .face: FaceView(controller: controller, session: session)
        case .customForm: CustomFormView(controller: controller, session: session)
        case .phone: PhoneView(controller: controller, session: session)
        case .contract: ContractView(controller: controller, session: session)
        case .partyPending: MessageView(title: strings.waitingTitle, message: strings.waitingBody)
        case .unknown: MessageView(title: strings.pleaseWaitTitle, message: strings.pleaseWaitBody)
        }
    }

    private func deliver(_ result: DocuPassResult) {
        guard !delivered else { return }
        delivered = true
        onResult(result)
    }
}

struct WelcomeView: View {
    @Environment(\.docuPassStrings) private var strings
    @Environment(\.docuPassTheme) private var theme
    let session: DocuPassSession
    let onContinue: () -> Void

    private var logoURL: URL? {
        guard theme.showLogo else { return nil }
        let raw = theme.logoURL ?? session.logoURL
        return raw.isEmpty ? nil : URL(string: raw)
    }

    var body: some View {
        VStack(spacing: 16) {
            if let logoURL {
                AsyncImage(url: logoURL) { $0.resizable().scaledToFit() } placeholder: { EmptyView() }
                    .frame(maxHeight: 96)
            }
            if !session.companyName.isEmpty { Text(session.companyName).font(.title2).bold() }
            Text(session.welcomeMessage.isEmpty ? strings.welcomeFallback : session.welcomeMessage)
                .multilineTextAlignment(.center)
            Button(strings.start, action: onContinue).buttonStyle(.borderedProminent)
        }.padding(24)
    }
}

struct MessageView: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.title3).bold()
            Text(message).multilineTextAlignment(.center)
        }.padding(24)
    }
}

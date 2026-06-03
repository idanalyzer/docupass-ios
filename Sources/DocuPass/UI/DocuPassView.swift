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
    private let onResult: (DocuPassResult) -> Void

    @State private var permissionChecked = false
    @State private var cameraGranted = false
    @State private var welcomeAck = false
    @State private var delivered = false

    public init(config: DocuPassConfig, onResult: @escaping (DocuPassResult) -> Void) {
        _controller = StateObject(wrappedValue: DocuPassController(config: config))
        self.onResult = onResult
    }

    public var body: some View {
        content
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
        case .partyPending: MessageView(title: "Waiting", message: "Waiting for another party to complete their part.")
        case .unknown: MessageView(title: "Please wait", message: "Preparing the next step…")
        }
    }

    private func deliver(_ result: DocuPassResult) {
        guard !delivered else { return }
        delivered = true
        onResult(result)
    }
}

struct WelcomeView: View {
    let session: DocuPassSession
    let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            if !session.companyName.isEmpty { Text(session.companyName).font(.title2).bold() }
            Text(session.welcomeMessage.isEmpty
                 ? "You'll be guided through a quick identity verification."
                 : session.welcomeMessage)
                .multilineTextAlignment(.center)
            Button("Start", action: onContinue).buttonStyle(.borderedProminent)
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

# DocuPass iOS SDK

Native iOS SDK for running an ID Analyzer DocuPass verification flow inside your
app. The SDK includes:

- A ready-to-use SwiftUI Quick UI through `KYCScreen`
- An event-driven session API for building your own UI
- Native document capture with AVFoundation in the Quick UI
- Active face verification with MediaPipe in the Quick UI
- Phone, custom form, document, face, contract, and pending-party flow handling

The mobile app only needs a short-lived DocuPass `reference`. Your ID Analyzer API
key must stay on your backend.

## Requirements

- iOS 15 or later
- Swift 5.9 or later
- Xcode 15.4 or later
- CocoaPods for the complete SDK, including MediaPipe active liveness

## Installation

### CocoaPods

CocoaPods is the supported installation path for the complete SDK because Google
distributes `MediaPipeTasksVision` as CocoaPods XCFrameworks.

Add DocuPass to your Podfile:

```ruby
platform :ios, '15.0'

use_frameworks! :linkage => :static

target 'YourApp' do
  pod 'DocuPass', '~> 0.2'
end
```

Install dependencies and open the generated workspace:

```bash
pod install
open YourApp.xcworkspace
```

The DocuPass pod:

- Installs `MediaPipeTasksVision ~> 0.10` transitively
- Integrates as a static framework to support MediaPipe's static XCFrameworks
- Bundles `face_landmarker.task` and `country.json` in `DocuPass.bundle`

### Required Info.plist Entry

The Quick UI requests camera access when a document or face capture step begins.
Add a camera usage description to the host app:

```xml
<key>NSCameraUsageDescription</key>
<string>Required to verify your identity.</string>
```

The SDK does not request location itself. If the DocuPass profile requires GPS,
obtain permission and location in the host app and pass it as
`geolocation = "lat,lng,accuracy"`. The host app must add its own location usage
description when it uses Core Location.

### Swift Package Manager

`Package.swift` builds the Swift API and UI surface and bundles SDK resources.
MediaPipe Tasks Vision does not currently provide an official SwiftPM package, so
active liveness cannot initialize unless the consuming app supplies a compatible
`MediaPipeTasksVision` binary.

Use CocoaPods when the verification flow includes face verification.

## Create a Reference

Create a DocuPass session on your server, then pass the returned `reference` to
your iOS app. Do not create DocuPass sessions from the mobile app, and do not put
your ID Analyzer API key in the application bundle.

Typical integration flow:

1. Your backend calls ID Analyzer to create a DocuPass session.
2. Your backend sends the returned `reference` to your iOS app.
3. The iOS app runs the SDK with that reference.
4. Your backend receives the final result through a webhook or server-side result
   lookup.

The SDK finish callback is a UI signal. Your backend remains the source of truth
for the final verification decision and verified identity data.

## Quick UI

Use `KYCScreen` when you want the SDK to render and manage the complete
verification flow.

```swift
import DocuPass
import SwiftUI

struct VerificationView: View {
    let reference: String
    let dismiss: () -> Void

    var body: some View {
        KYCScreen(
            reference: reference,
            onFinish: { result in
                // Called after the user taps FINISH on the terminal screen.
                // Fetch authoritative verification data from your backend.
                print(result.sessionId ?? "finished")
                dismiss()
            },
            onBackAtFirstStep: {
                dismiss()
            }
        )
    }
}
```

`KYCScreen` handles:

- Loading and routing the server-driven DocuPass task
- Document country and type selection
- Front and back document capture and upload
- MediaPipe face alignment and randomized liveness actions
- Phone verification through SMS or voice call OTP
- Custom form rendering and submission
- Contract review, signature drawing, and submission
- Pending-party refresh
- Back navigation between non-terminal steps
- Final success and failure screens

`onFinish` is called only after the user taps `FINISH` on the final screen. It is
not called immediately when the server reaches a terminal state.

Quick UI arguments:

| Argument | Type | When to use |
| --- | --- | --- |
| `reference` | `String` | Required. Short-lived DocuPass reference created by your backend. |
| `partyId` | `String?` | Optional party identifier for a multi-party signing flow. |
| `geolocation` | `String?` | Optional `"lat,lng,accuracy"` value when the profile requires GPS. |
| `onFinish` | `(KYCResult) -> Void` | Called after the user taps `FINISH` on success or failure. |
| `onBackAtFirstStep` | `() -> Void` | Called when the SDK back button is pressed on the first non-terminal step. |

### KYCSettings

Use `KYCSettings` to configure liveness geometry or construct the API config
yourself:

```swift
let settings = KYCSettings.fromReference(
    reference,
    partyId: partyId,
    geolocation: "25.0330,121.5654,10",
    onFinish: { result in
        handleCompletion(result)
    },
    onBackAtFirstStep: {
        dismissVerification()
    }
)

KYCScreen(settings: settings)
```

Advanced settings:

```swift
let settings = KYCSettings(
    apiConfig: .fromReference(reference),
    maskCircleRadius: 0.42,
    maskCircleY: 0.45,
    turnTimeSeconds: 2.0,
    onFinish: handleCompletion,
    onBackAtFirstStep: dismissVerification
)
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `apiConfig` | `DocupassApiConfig()` | API endpoint, authorization, reference, and transport configuration. |
| `maskCircleRadius` | `0.42` | Face guide radius relative to the screen width. |
| `maskCircleY` | `0.45` | Vertical center of the face guide relative to screen height. |
| `turnTimeSeconds` | `2.0` | Time that each liveness action must remain valid. |
| `onFinish` | Empty closure | Terminal UI completion callback. |
| `onBackAtFirstStep` | Empty closure | Host navigation callback for the first step. |

## Event API

Use `DocupassKycSession` when you want to build your own UI. The SDK owns the
DocuPass state machine and API calls; your app renders screens and supplies
captured data.

The event API does not provide a custom camera UI, custom liveness UI, contract
renderer, or signature pad. Those are included in `KYCScreen` only.

Put the session in an `ObservableObject`. This object owns the session,
subscription, lifecycle, and commands used by your custom views:

```swift
import Combine
import DocuPass

@MainActor
final class CustomKYCModel: ObservableObject {
    @Published private(set) var state = DocupassKycUiState()

    private let session: DocupassKycSession
    private var subscription: DocupassSubscription?
    private var started = false

    init(reference: String) {
        session = DocupassKycSession(
            config: .fromReference(reference)
        )

        subscription = session.subscribe { [weak self] state in
            self?.state = state
        }
    }

    func start() {
        guard !started else { return }
        started = true
        session.start()
    }

    func refresh() {
        session.refresh()
    }

    func back() {
        session.back()
    }

    func clearError() {
        session.clearError()
    }

    func selectCountry(_ country: KYCCountry) {
        session.selectDocumentCountry(country.code)
    }

    func selectDocumentType(_ type: KYCDocumentType) {
        session.selectDocumentType(type.apiTypeCode)
    }

    func uploadDocument(frontBase64: String, backBase64: String?) {
        session.uploadDocument(
            frontBase64: frontBase64,
            backBase64: backBase64
        )
    }

    func uploadFace(_ faceBase64Images: [String]) {
        session.uploadFace(faceBase64Images)
    }

    func sendPhoneCode(number: String?, type: String) {
        session.sendPhoneCode(number: number, type: type)
    }

    func verifyPhoneCode(number: String?, code: String) {
        session.verifyPhoneCode(number: number, code: code)
    }

    func saveCustomForm(_ answers: [String: String]) {
        session.saveCustomForm(answers: answers)
    }

    func submitContract(_ signatures: [String: String]) {
        session.submitContract(signatures)
    }

    func close() {
        subscription?.close()
        subscription = nil
        session.close()
    }
}
```

Put `switch model.state.event` inside the SwiftUI screen that renders your custom
flow. A convenient location is an `@ViewBuilder` property such as `eventContent`:

```swift
import DocuPass
import SwiftUI

@MainActor
struct CustomKYCView: View {
    @StateObject private var model: CustomKYCModel

    init(reference: String) {
        _model = StateObject(
            wrappedValue: CustomKYCModel(reference: reference)
        )
    }

    var body: some View {
        ZStack {
            eventContent

            if model.state.isBusy {
                ProgressView()
            }

            if let error = model.state.error {
                VStack(spacing: 12) {
                    Text(error.normalized?.title ?? "Verification error")
                        .font(.headline)
                    Text(error.message)
                    Button("Dismiss") {
                        model.clearError()
                    }
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
            }
        }
        .onAppear {
            model.start()
        }
        .onDisappear {
            model.close()
        }
    }

    @ViewBuilder
    private var eventContent: some View {
        switch model.state.event {
        case .loading:
            ProgressView("Loading verification")

        case let .documentCountrySelection(countries, selectedCountry):
            List(countries) { country in
                Button(country.name) {
                    model.selectCountry(country)
                }
            }
            .overlay(alignment: .bottom) {
                Text(selectedCountry?.name ?? "Select a country")
            }

        case let .documentSelection(country, documentTypes, selectedType):
            List(documentTypes) { type in
                Button(type.label) {
                    model.selectDocumentType(type)
                }
            }
            .navigationTitle(country.name)
            .overlay(alignment: .bottom) {
                Text(selectedType?.label ?? "Select a document")
            }

        case let .documentCapture(country, documentType, documentSide, allowFileUpload):
            VStack {
                Text("Build your document camera here")
                Text(country?.name ?? "")
                Text(documentType?.label ?? "")
                Text("documentSide: \(documentSide ?? 0)")
                Text("allowFileUpload: \(allowFileUpload.description)")

                // After capture:
                // model.uploadDocument(
                //     frontBase64: front,
                //     backBase64: back
                // )
            }

        case let .faceVerification(actions):
            VStack {
                Text("Build your liveness UI here")
                ForEach(actions) { action in
                    Text(action.instruction)
                }

                // After completing all actions:
                // model.uploadFace(faceBase64Images)
            }

        case let .phoneVerification(sessionState, codeSent, currentNumber):
            VStack {
                Text(sessionState.userPhone ?? "Enter a phone number")
                Text(codeSent ? "Enter the verification code" : "Send a code")
                Text(currentNumber ?? "")

                // model.sendPhoneCode(number: number, type: "sms")
                // model.verifyPhoneCode(number: currentNumber, code: otp)
            }

        case let .customForm(fields):
            VStack {
                Text("Build your form with \(fields.count) fields")

                // Submit answers keyed by fieldId:
                // model.saveCustomForm(answers)
            }

        case let .contract(sessionState, html, signatureFields):
            VStack {
                Text(sessionState.companyName ?? "Contract")
                Text("HTML length: \(html.count)")
                Text("Signatures required: \(signatureFields.count)")

                // Render HTML, collect signatures, then call:
                // model.submitContract(signatures)
            }

        case .partyPending:
            VStack {
                Text("Waiting for another party")
                Button("Refresh") {
                    model.refresh()
                }
            }

        case let .completed(result):
            VStack {
                Text("Verification complete")
                Text(result.sessionId ?? "")
            }

        case let .failed(result, error):
            VStack {
                Text("Verification failed")
                Text(error?.displayMessage() ?? "Unknown error")
                Text(result.sessionId ?? "")
            }
        }
    }
}
```

The `switch` belongs in the rendering layer because every case returns a different
SwiftUI view. Session commands remain in `CustomKYCModel`, so child views call model
methods instead of owning or recreating `DocupassKycSession`.

### Session Lifecycle

Create one `DocupassKycSession` for one verification screen or custom flow.
Subscribe before `start()` so your UI receives every state update.

```swift
let config = DocupassApiConfig.fromReference(
    reference,
    partyId: nil,
    geolocation: nil
)

let session = DocupassKycSession(config: config)
let subscription = session.subscribe { state in
    render(state)
}

session.start()
```

Retain both `session` and `subscription` for the lifetime of your UI. Call
`subscription.close()` and `session.close()` when the screen or owning model is
destroyed.

All session and controller APIs are isolated to `MainActor` because they publish
UI state.

### Configuration

Most apps should use `DocupassApiConfig.fromReference(...)` or
`docupassConfigFromReference(...)`.

| API | Use |
| --- | --- |
| `DocupassApiConfig.fromReference(...)` | Recommended configuration factory for normal app usage. |
| `docupassConfigFromReference(...)` | Top-level helper equivalent to `fromReference`. |
| `DocupassApiConfig(...)` | Advanced configuration for custom endpoints, authorization, or timeouts. |

`DocupassApiConfig` fields:

| Field | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Calls the DocuPass API. Set `false` only for local demos and tests. |
| `baseURL` | Resolved from reference | Optional API base URL override. `EU` references use the EU endpoint; all others use US. |
| `reference` | `nil` | DocuPass reference created by your backend. |
| `partyId` | `nil` | Optional party identifier for multi-party signing. |
| `sessionId` | `nil` | Optional existing session ID. Normally discovered from API responses. |
| `authorization` | `nil` | Optional complete Authorization header. Overrides generated DocuPass authorization. |
| `geolocation` | `nil` | Optional `"lat,lng,accuracy"` value sent through the `Geolocation` header. |
| `disableSSLValidation` | `false` | Disables server trust validation. Use only with controlled development endpoints. |
| `timeout` | `20` | Request and resource timeout in seconds. |

Authorization is generated automatically when `authorization` is not set:

```text
DOCUPASS <reference>
DOCUPASS <reference> <partyId>
DOCUPASS_SESSION <sessionId>
```

The first request uses the reference. After the server returns `sessionId`, all
subsequent requests use `DOCUPASS_SESSION` automatically.

### Session Methods

| Method | Call when | Parameters |
| --- | --- | --- |
| `subscribe(listener)` | Before `start()`, or when observing state changes. | Returns a `DocupassSubscription`; retain it and call `close()`. |
| `currentState` | When the UI needs the current synchronous state snapshot. | Read-only property. |
| `start()` | After subscribing, when verification should begin. | Loads the current server task. |
| `refresh()` | On `partyPending`, or when resynchronizing with the server. | Calls `get_action`. |
| `back()` | When `state.canGoBack && !state.isBusy`. | Returns to the previous non-terminal SDK event. |
| `clearError()` | After dismissing `state.error`. | Clears the current non-terminal error. |
| `restart()` | When intentionally resetting local SDK state. | Restarts the flow. |
| `sendPhoneCode(number:type:)` | Before OTP entry on phone verification. | `number` is optional; `type` is `"sms"` or `"call"`. |
| `verifyPhoneCode(number:code:)` | After the user enters an OTP. | Use the same number used for sending, or `nil` for a preset phone. |
| `saveCustomForm(answers:)` | After required custom fields are complete. | Dictionary keyed by field ID or fallback label. |
| `selectDocumentCountry(_:)` | When the user chooses an emitted country. | ISO-2 country code. |
| `selectDocumentType(_:)` | When the user chooses an emitted document type. | API type code `P`, `D`, or `I`. |
| `uploadDocument(frontBase64:backBase64:)` | After required document sides are captured. | Raw JPEG base64 without a data URL prefix. |
| `uploadFace(_:)` | After liveness captures face frames. | Non-empty raw JPEG base64 array. |
| `submitContract(_:)` | After every required signature is available. | Dictionary keyed by signature UID. |
| `close()` | When the UI owner is destroyed. | Cancels work and closes HTTP resources. |

Do not call step-specific methods before the matching event is emitted. Disable
custom UI controls while `state.isBusy` is `true`.

### State Model

Every state update is a `DocupassKycUiState`:

| Field | Meaning |
| --- | --- |
| `event` | Current flow step and its associated payload. |
| `result` | Local SDK data collected so far. Not the authoritative verification result. |
| `isBusy` | `true` while an API action is running. |
| `canGoBack` | `true` when custom UI may call `back()`. Always `false` on terminal screens. |
| `error` | Optional display error independent from the current event. |

Events:

| Event | Associated payload | What your UI should do |
| --- | --- | --- |
| `.loading` | None | Show loading UI. |
| `.phoneVerification` | Session state, code-sent flag, current number | Show phone entry and OTP UI. |
| `.customForm` | Custom fields | Render fields and submit answers. |
| `.documentCountrySelection` | Countries and selected country | Render country choices. |
| `.documentSelection` | Country, types, selected type | Render document type choices. |
| `.documentCapture` | Country, type, side rule, upload permission | Capture required document sides. |
| `.faceVerification` | Liveness actions | Run liveness and upload face images. |
| `.contract` | Session state, HTML, signature fields | Render contract and collect signatures. |
| `.partyPending` | None | Show pending UI and refresh later. |
| `.completed` | `KYCResult` | Show final success UI. |
| `.failed` | `KYCResult` and normalized error | Show final failure UI. |

The `event.kind` property returns the corresponding `DocupassKycEventKind` when
code prefers a non-associated event identifier.

## Parameter Reference

### Document Country

`selectDocumentCountry(_:)` accepts one ISO 3166-1 alpha-2 country code. Use the
countries emitted by the current event instead of maintaining a separate list:

```swift
if case let .documentCountrySelection(countries, _) = state.event,
   let country = countries.first {
    session.selectDocumentCountry(country.code)
}
```

The server may restrict countries through the DocuPass profile. Unknown server
codes are preserved as `KYCCountry(code: code, name: code)`.

The built-in known list currently contains:

| Code | Name |
| --- | --- |
| `AU` | Australia |
| `CA` | Canada |
| `DE` | Germany |
| `FR` | France |
| `GB` | United Kingdom |
| `HK` | Hong Kong |
| `JP` | Japan |
| `KR` | South Korea |
| `SG` | Singapore |
| `TH` | Thailand |
| `TW` | Taiwan |
| `US` | United States |

### Document Type

Use document types emitted by `.documentSelection`; the profile may restrict the
available list.

| Swift case | `apiTypeCode` | Label | Default back side requirement |
| --- | --- | --- | --- |
| `.passport` | `P` | Passport | No |
| `.driverLicense` | `D` | Driver License | Yes |
| `.identityCard` | `I` | Identity Card | Yes |

Server `documentSide` overrides the local default:

| `documentSide` | Meaning |
| --- | --- |
| `1` | Front only. |
| `2` | Front and back may be required. Passport remains front-only in Quick UI. |
| `0` or `nil` | Use the local document type default. |

For custom UI, check both the emitted `documentSide` and
`documentType?.requiresBackSide` before requesting a back image.

### Document Images

`uploadDocument(frontBase64:backBase64:)` expects:

| Parameter | Value |
| --- | --- |
| `frontBase64` | Required raw JPEG base64. Do not include a `data:image/...` prefix. |
| `backBase64` | Raw JPEG base64 for the reverse side, or `nil` for front-only documents. |

The Quick UI uses the back camera, displays document-specific masks, crops the
captured image to the mask, scales long edges to at most 2000 pixels, and encodes
JPEG at 0.9 quality.

### Face Verification

The `.faceVerification` event tells custom UI which actions to perform. The SDK
randomizes candidates and returns at least two unique actions when possible.

| Swift case | Instruction |
| --- | --- |
| `.turnLeft` | `TURN HEAD LEFT` |
| `.turnRight` | `TURN HEAD RIGHT` |
| `.turnUp` | `TURN HEAD UP` |
| `.mouthOpen` | `OPEN MOUTH O-SHAPE` |

`uploadFace(_:)` expects a non-empty array of raw JPEG base64 strings without a
`data:image/...` prefix.

#### Quick UI MediaPipe Behavior

The Quick UI follows MediaPipe's iOS live-stream integration pattern:

- Front camera through `AVCaptureVideoDataOutput`
- `kCMPixelFormat_32BGRA` sample buffers
- Mirrored portrait connection for front-camera interaction
- `MPImage(sampleBuffer:orientation:)`
- `FaceLandmarkerOptions.runningMode = .liveStream`
- Asynchronous `detectAsync` inference and `FaceLandmarkerLiveStreamDelegate`

Alignment checks landmarks `10`, `152`, `234`, and `454` inside the face guide.
Action checks use the normalized nose and mouth landmarks and require the action
to remain valid for `turnTimeSeconds`, which defaults to two seconds.

One JPEG image is captured for every completed action and uploaded after all
actions are complete.

### Phone Verification

The `.phoneVerification` event contains:

| Value | Meaning |
| --- | --- |
| `state` | Full `DocupassSessionState`, including preset phone and country codes. |
| `codeSent` | `true` after `sendPhoneCode` succeeds. |
| `currentNumber` | Number used by the last send request, when provided by the UI. |

`sendPhoneCode(number:type:)` parameters:

| Parameter | Value |
| --- | --- |
| `number` | `nil` when the server provides `userPhone`; otherwise an international number such as `+15551234567`. |
| `type` | `"sms"` or `"call"`. |

`verifyPhoneCode(number:code:)` uses the same number, or `nil` for a preset server
phone, plus the OTP entered by the user.

Available `phoneCountryCodes` contain:

| Field | Example | Meaning |
| --- | --- | --- |
| `name` | `United States` | Display name. |
| `dialCode` | `+1` | International dialing prefix. |
| `code` | `US` | ISO-2 country code. |

### Custom Form

The `.customForm` event contains `DocupassCustomField` values:

| Field | Meaning |
| --- | --- |
| `fieldId` | Preferred dictionary key for `saveCustomForm`. |
| `fieldLabel` | User-visible label and fallback key when `fieldId` is empty. |
| `fieldDescription` | Optional helper text. |
| `fieldType` | `0` text, `1` multiline text, `2` options. |
| `fieldData` | Raw option data supplied by the profile. |

Submit answers with:

```swift
let key = field.fieldId.isEmpty ? field.fieldLabel : field.fieldId
session.saveCustomForm(answers: [key: answer])
```

For option fields, Quick UI accepts one option per line and supports
`label;value`, `label<TAB>value`, and `label|value`. With no separator, the same
text is used for label and value.

### Contract

The `.contract` event contains:

| Value | Meaning |
| --- | --- |
| `state` | Full `DocupassSessionState`. |
| `html` | Contract HTML for rendering in a `WKWebView` or equivalent UI. |
| `signatureFields` | Placeholders extracted from `data-signature` HTML elements. |

`DocupassContractSignatureField` fields:

| Field | Meaning |
| --- | --- |
| `uid` | Required dictionary key for contract submission. |
| `label` | User-visible signature label. |
| `party` | Optional party identifier from the contract template. |

Submit PNG data URLs keyed by signature UID:

```swift
let signatures = Dictionary(
    uniqueKeysWithValues: signatureFields.map { field in
        (field.uid, "data:image/png;base64,...")
    }
)

session.submitContract(signatures)
```

Signature values must include the `data:image/png;base64,` prefix. Quick UI draws
one signature and associates that image with every required field.

## Error Handling

Non-terminal errors are published through `DocupassKycUiState.error` while the
current event remains visible. Display `error.message`, use `error.normalized` for
recovery UI, then call `clearError()` after dismissal.

`DocupassNormalizedError` contains:

| Field | Meaning |
| --- | --- |
| `code` | Main API error code. |
| `subCode` | Classified subcode or first warning code. |
| `title` | Short user-facing title. |
| `detail` | User-facing explanation. |
| `suggestion` | Recommended recovery action. |
| `action` | Structured `DocupassErrorAction`. |
| `warningCodes` | All document or face warning codes returned by the server. |
| `httpStatus` | HTTP status when available. |
| `rawMessage` | Original API message. |
| `rawBody` | Original response body for diagnostics. |

Recovery actions:

| Action | Meaning |
| --- | --- |
| `.showCompleted` | Route to the terminal completed event. |
| `.showFailed` | Route to the terminal failed event. |
| `.resyncSession` | Automatically call `get_action` and route to the latest task. |
| `.requestLocation` | Host app must acquire location and restart with `geolocation`. |
| `.retry` | Allow retrying the current request. |
| `.retakeDocument` | Return to document capture. |
| `.retakeFace` | Repeat face capture and liveness. |
| `.editInput` | Let the user correct submitted data. |
| `.fixSignature` | Clear and collect the signature again. |
| `.fatal` | Stop the current session. |
| `.contactSupport` | Preserve diagnostics and contact the issuer or support. |

`DOCUPASS_COMPLETED` and `DOCUPASS_FAILED` errors are converted into terminal
events. `DOCUPASS_INVALID_ACTION` automatically resynchronizes the session.

## Back Navigation

`KYCScreen` renders a back button on non-terminal screens. It returns to the
previous SDK event when possible. On the first non-terminal event it calls
`onBackAtFirstStep`, allowing the host app to dismiss its sheet, cover, or
navigation destination.

Final success and failure screens are terminal. The user completes them by
tapping `FINISH`.

For custom UI:

```swift
if state.canGoBack && !state.isBusy {
    session.back()
} else {
    // Dismiss the host screen or remain on the current event.
}
```

## Results

`KYCResult` contains local SDK flow details:

| Field | Meaning |
| --- | --- |
| `country` | Selected document country. |
| `documentType` | Selected document type. |
| `documentFrontBase64` | Locally captured front image. |
| `documentBackBase64` | Locally captured back image when required. |
| `faceBase64List` | Locally captured liveness images. |
| `isFaceVerified` | Local indication that face actions completed and images were submitted. |
| `serverTask` | Last server task. |
| `sessionId` | Current DocuPass session identifier. |
| `sessionState` | Last full server session state. |
| `terminalError` | Structured terminal or latest classified error. |

The locally collected images and `isFaceVerified` are useful for UI state only.
They do not replace server-side verification, face matching, fraud checks, or the
final profile decision.

Use your backend webhook or a server-side `GET /docupass/{reference}` request to
decide whether the user is accepted, rejected, or under review.

## Advanced API Client

`DocupassApiClient` is public for advanced integrations. Most apps should use
`DocupassKycSession`, which keeps API calls and state transitions synchronized.

Available client operations:

| Method | Endpoint |
| --- | --- |
| `getAction()` | `GET get_action` |
| `saveDocumentSelection(countryCode:documentType:)` | `POST save_document_selection` |
| `uploadDocument(frontDocumentBase64:backDocumentBase64:)` | `POST upload_document` |
| `uploadFace(_:)` | `POST upload_face` |
| `createPhoneVerification(number:type:)` | `POST create_phone_verification` |
| `checkPhoneVerification(number:code:)` | `POST check_phone_verification` |
| `saveForm(_:)` | `POST save_form` |
| `submitContract(_:)` | `POST submit_contract` |
| `logAuditData(action:data:)` | `POST audit` |

```swift
let client = DocupassApiClient(
    config: .fromReference(reference)
)

switch await client.getAction() {
case let .success(state):
    print(state.task ?? "completed")
case let .failure(error):
    let normalized = DocupassErrorNormalizer.normalize(error)
    print(normalized.displayMessage())
}
```

Do not mix direct client requests with an active `DocupassKycSession` for the same
flow. The session owns authorization progression and event routing.

## Server Task Routing

The state machine routes these server task values:

| Server task | SDK event |
| --- | --- |
| `phone` | `.phoneVerification` |
| `customform` | `.customForm` |
| `document` | Country selection, type selection, or document capture |
| `face` | `.faceVerification` |
| `contract` | `.contract` |
| `party_pending` | `.partyPending` |

Unknown or terminal task values produce `.completed`, matching the Android SDK.

## Security

- Never place an ID Analyzer API key in the iOS app.
- Create DocuPass sessions on your backend.
- Treat the DocuPass reference and session ID as short-lived credentials.
- Keep SSL validation enabled in production.
- Treat `onFinish`, `.completed`, and `.failed` as UI signals.
- Use webhook data or a server-side result lookup as the authoritative decision.
- Avoid logging raw image base64, signature images, or full API response bodies in
  production.

## License

[MIT](LICENSE) (c) [ID Analyzer](https://www.idanalyzer.com)

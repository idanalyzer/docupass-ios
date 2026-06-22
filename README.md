# DocuPass iOS SDK

Native SwiftUI identity verification for ID Analyzer DocuPass. The SDK follows the
server-driven Android SDK flow and supports phone verification, custom forms,
document selection and capture, MediaPipe active liveness, contracts, pending
sessions, and terminal results.

## Requirements

- iOS 15 or later
- Swift 5.9
- CocoaPods for active liveness (`MediaPipeTasksVision` has no official SwiftPM package)

## Installation

Add DocuPass to your Podfile:

```ruby
pod 'DocuPass', '~> 0.2'
```

Run `pod install`, open the generated workspace, and add camera permission text to
the host app's `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Required to verify your identity.</string>
```

The pod installs `MediaPipeTasksVision ~> 0.10` transitively. DocuPass is a static
framework because MediaPipe ships as static XCFrameworks. The face landmarker model
and country catalog are bundled in `DocuPass.bundle`.

Swift Package Manager can build the API and UI surface, but active liveness reports
an initialization error unless the consumer supplies a compatible
`MediaPipeTasksVision` binary. CocoaPods is the supported full SDK path.

## SwiftUI

```swift
import DocuPass
import SwiftUI

struct VerificationView: View {
    let reference: String

    var body: some View {
        KYCScreen(
            reference: reference,
            onFinish: { result in
                // This is a UI completion signal. Read the authoritative result
                // from your backend webhook or server-side DocuPass API call.
                print(result.sessionId ?? "finished")
            },
            onBackAtFirstStep: {
                // Dismiss your containing view.
            }
        )
    }
}
```

For a party-specific link or pre-acquired geolocation:

```swift
let settings = KYCSettings.fromReference(
    reference,
    partyId: partyId,
    geolocation: "25.0330,121.5654",
    onFinish: handleResult,
    onBackAtFirstStep: dismiss
)

KYCScreen(settings: settings)
```

The SDK does not request location itself. If the DocuPass profile requires GPS,
obtain consent and location in the host app, then pass the value through
`geolocation`.

## Event API

Use `DocupassKycSession` to build a custom UI while keeping the same state machine:

```swift
@MainActor
func startHeadless(reference: String) {
    let session = DocupassKycSession(
        config: .fromReference(reference)
    )

    let subscription = session.subscribe { state in
        switch state.event {
        case let .documentCountrySelection(countries, _):
            print(countries)
        case let .completed(result):
            print(result.sessionId ?? "completed")
        default:
            break
        }
    }

    session.start()
    _ = subscription // Retain while observing.
}
```

Available commands mirror the Android native session API:

- `start`, `refresh`, `back`, `clearError`, `restart`
- `sendPhoneCode`, `verifyPhoneCode`, `saveCustomForm`
- `selectDocumentCountry`, `selectDocumentType`
- `uploadDocument`, `uploadFace`, `submitContract`

## Session protocol

The client starts with one of these authorization headers:

```text
DOCUPASS <reference>
DOCUPASS <reference> <partyId>
```

After the API returns a session ID, subsequent requests use:

```text
DOCUPASS_SESSION <sessionId>
```

The SDK routes the server tasks `phone`, `customform`, `document`, `face`,
`contract`, and `party_pending`. Any terminal or unknown task is treated as a
completed flow, matching the Android SDK.

## Security

Create DocuPass sessions on your backend. Never put an ID Analyzer API key in the
app. `onFinish` is only a UI signal; webhook data or a server-side
`GET /docupass/{reference}` request is the authoritative verification result.

## License

[MIT](LICENSE), ID Analyzer.

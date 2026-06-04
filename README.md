# DocuPass iOS SDK — Native In-App ID Verification, KYC & Liveness for iOS

[![CocoaPods](https://img.shields.io/cocoapods/v/DocuPass)](https://cocoapods.org/pods/DocuPass)
[![Platform iOS 15+](https://img.shields.io/badge/iOS-15%2B-green)](#requirements)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![ID Analyzer](https://img.shields.io/badge/by-ID%20Analyzer-0b5cff)](https://www.idanalyzer.com)

Add **identity verification and KYC** to your iOS app in minutes. The DocuPass iOS
SDK runs the entire flow **natively, on-device** — ID document scanning, biometric
**face match**, and **active liveness detection** — with **no external browser and
no WebView**. Drop in one SwiftUI view, get a result callback.

Built by **[ID Analyzer](https://www.idanalyzer.com)** — the identity verification
platform trusted for [ID document recognition](https://www.idanalyzer.com/products/id-scanner-api.html),
[biometric verification](https://www.idanalyzer.com/products/biometric-verification.html),
and [AML screening](https://www.idanalyzer.com/products/aml-api.html) across 190+
countries and 14,000+ document types.

> **Why native instead of a WebView?** Wrapping the DocuPass web link in a
> `WKWebView` breaks the camera (`getUserMedia` is unreliable in embedded web views,
> liveness gets blocked). This SDK owns the camera with **AVFoundation** and runs
> liveness on-device with **Google MediaPipe**, so verification just works inside
> your app.

**📚 Full documentation:** [developer.idanalyzer.com/help/docupass-ios-sdk](https://developer.idanalyzer.com/help/docupass-ios-sdk)
· **🌐 Product:** [DocuPass](https://www.idanalyzer.com/products/docupass.html)
· **📦 Other platforms:** [Android](https://github.com/idanalyzer/docupass-android) ·
[React Native](https://github.com/idanalyzer/docupass-react-native) ·
[Flutter](https://github.com/idanalyzer/docupass-flutter)

---

## Features

- 📱 **Fully native capture** — AVFoundation document & selfie capture; no WebView.
- 🧠 **On-device active liveness** — MediaPipe face landmarks; hold still, then turn left/right.
- 🪪 **Global document support** — passports, driver licenses, and ID cards from 190+ countries.
- ✍️ **Full DocuPass flow** — document capture, face match, custom forms, phone (SMS/voice OTP) verification, and **e-signature contracts**.
- 🎨 **White-label** — override every label (any language) and set the brand color & logo. One-line drop-in *or* fully headless.
- 🔒 **Your API key never touches the device** — the app only holds a short-lived `reference`.
- 🌍 **US & EU data regions** — chosen automatically from the reference.

## How it works

DocuPass is server-driven. **Your API key is secret and lives only on your backend** —
the mobile app never creates a session or reads results directly. The device only
ever holds a short-lived `reference`.

1. **Server → create a session.** Call `POST /docupass` with your API key (any
   [ID Analyzer server SDK](https://developer.idanalyzer.com/help)) using a
   [KYC profile](https://developer.idanalyzer.com/help/profiles). Set a **webhook URL**
   on the profile so results are pushed to you. You get a **`reference`**.
2. **App → run the SDK.** Pass the `reference` to `DocuPassView`. The SDK runs capture
   + liveness on-device and fires `onResult` when the flow ends — a **UX signal**, not
   the authoritative result.
3. **Server → receive the verified result** (extracted identity data + the
   accept / review / reject decision):
   - **Recommended — webhook (push).** When verification concludes, ID Analyzer
     `POST`s the full transaction — name, date of birth, document number, face-match,
     AML, decision, warnings, images — to your webhook URL, with automatic retries.
   - **Or pull it server-side** with `GET /docupass/{reference}` (your API key) — it
     returns the DocuPass record including the final transaction with all verified data.

> 🔒 **Never ship your API key in the app, and never call `POST /docupass` or
> `GET /docupass/{reference}` from the mobile SDK** — both require your secret API
> key. Treat `onResult` purely as a UI cue; **your backend is the source of truth**.

## Requirements

- **iOS 15+**, Swift 5.9
- The MediaPipe liveness model + country/document catalog are **bundled**.

## Installation

### CocoaPods (recommended)

MediaPipe Tasks Vision ships via CocoaPods, so CocoaPods is the primary path:

```ruby
pod 'DocuPass', '~> 0.1'
```

Then `pod install`, and add a camera usage string to your **Info.plist**:

```xml
<key>NSCameraUsageDescription</key>
<string>Required to verify your identity.</string>
```

> **Swift Package Manager:** a `Package.swift` is included for the pure-Swift
> surface, but the liveness engine needs `MediaPipeTasksVision` (no official SPM
> yet) — supply it via a binary xcframework, or use CocoaPods.

## Quick start (drop-in UI)

```swift
import SwiftUI
import DocuPass

struct VerifyScreen: View {
    var body: some View {
        DocuPassView(config: DocuPassConfig(reference: "US...your-reference...")) { result in
            switch result {
            case .completed:
                break // Flow finished — update your UI. Verified data arrives on your
                       // server via webhook (or GET /docupass/{reference}), not here.
            case .failed:
                break // rejected
            case .cancelled:
                break // user dismissed
            case .error:
                break // network / fatal error
            }
        }
    }
}
```

### Getting a `reference` (server side)

Create the session on your backend, never in the app:

```javascript
import { DocuPass } from "idanalyzer2";

const docupass = new DocuPass("YOUR_API_KEY", "YOUR_PROFILE_ID", "US");
const session = await docupass.createDocuPass();
// Send session.reference to your app and pass it to DocuPassView.
```

## Customization — labels, languages & branding

Optional parameters on `DocuPassView`; one-line usage stays unchanged.

### Re-label or translate to any language

`DocuPassStrings` exposes **every** label as an overridable property. Override any
subset to re-word or localize — you provide the translations:

```swift
var strings = DocuPassStrings()
strings.selectDocumentTitle = "Sélectionnez votre document"
strings.phoneTitle = "Vérifiez votre téléphone"
strings.phoneSendSms = "Envoyer le SMS"
strings.faceForward = "Regardez droit devant et ne bougez pas"

DocuPassView(
    config: DocuPassConfig(reference: reference),
    strings: strings
) { result in /* ... */ }
```

### Brand color & logo

```swift
import SwiftUI

let theme = DocuPassTheme(
    primaryColor: Color(hex: "#1565C0"),
    logoURL: "https://yourbrand.example.com/logo.png"
)

DocuPassView(
    config: DocuPassConfig(reference: reference),
    theme: theme
) { result in /* ... */ }
```

## Headless API (build your own UI)

For full control, drive the protocol yourself — everything is public:
`DocuPassController` (an `ObservableObject` state machine), `DocuPassClient`
(async/await protocol client), `LivenessController` + `FaceLandmarkerEngine`, and
`CameraController`.

```swift
let controller = DocuPassController(config: DocuPassConfig(reference: reference))
// observe controller.state (@Published)

await controller.start()
await controller.submitDocumentSelection(country: "US", type: "D")
await controller.submitDocument(frontBase64: front, backBase64: back) // your capture
await controller.submitFace(frames: [faceBase64])                     // your liveness
```

## Handling the result

| Result | Meaning |
|---|---|
| `.completed(reference, redirectURL?, code?)` | Verification finished (accepted / under review). Fetch data via `GET /docupass/{reference}`. |
| `.failed(reference, code?, message?, redirectURL?)` | Rejected or failed. |
| `.cancelled(reference)` | The user dismissed the flow. |
| `.error(reference, error)` | Network or fatal session error. |

`onResult` only tells your **app** that the flow ended — it carries no verified
identity data. The verified data and decision arrive on your **server**: via the
**webhook** you configured on the DocuPass profile (recommended, with retries), or by
calling `GET /docupass/{reference}` server-side with your API key. Never use a
client-side result as the decision.

## Links

- 🌐 ID Analyzer: [www.idanalyzer.com](https://www.idanalyzer.com)
- 🪪 DocuPass product: [idanalyzer.com/products/docupass.html](https://www.idanalyzer.com/products/docupass.html)
- 📚 Developer docs & KB: [developer.idanalyzer.com/help](https://developer.idanalyzer.com/help)
- 📱 This SDK's guide: [developer.idanalyzer.com/help/docupass-ios-sdk](https://developer.idanalyzer.com/help/docupass-ios-sdk)
- 🔑 Get API keys / customer portal: [portal2.idanalyzer.com](https://portal2.idanalyzer.com)
- 🧩 Other SDKs: [Android](https://github.com/idanalyzer/docupass-android) · [React Native](https://github.com/idanalyzer/docupass-react-native) · [Flutter](https://github.com/idanalyzer/docupass-flutter)

## License

[MIT](LICENSE) © [ID Analyzer](https://www.idanalyzer.com)

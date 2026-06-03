# DocuPass iOS SDK — in-app ID verification & KYC for iOS

[![CocoaPods](https://img.shields.io/badge/pod-DocuPass-blue)](https://github.com/idanalyzer/docupass-ios)
[![Platform](https://img.shields.io/badge/iOS-15%2B-green)](#requirements)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Embed [ID Analyzer **DocuPass**](https://www.idanalyzer.com/products/docupass.html)
identity verification **natively inside your iOS app** — document scanning, face
match, and active liveness — with **no external browser and no WebView**. Drop in
one SwiftUI view, get a result callback.

This is the native answer to "the DocuPass web link doesn't work wrapped in a
`WKWebView`" (camera/permission failures): the SDK owns the camera (AVFoundation)
and runs liveness on-device (MediaPipe `FaceLandmarker`), talking directly to the
DocuPass session API.

- 📱 **Native camera + liveness** — no WebView `getUserMedia` issues.
- 🧩 **One-line SwiftUI drop-in**, plus a **headless API** for custom UIs.
- 🔒 **No API key on the device** — the app only holds a DocuPass `reference`.
- 🌍 **US & EU** regions auto-selected from the reference.

> Sibling SDKs: [Android](https://github.com/idanalyzer/docupass-android) ·
> [React Native](https://github.com/idanalyzer/docupass-react-native) ·
> [Flutter](https://github.com/idanalyzer/docupass-flutter).

## How it works

1. **Server-side**, create a DocuPass session with your API key (any
   [ID Analyzer v2 server SDK](https://developer.idanalyzer.com/help)):
   `POST /docupass` → you get a `reference`.
2. **In your app**, pass that `reference` to `DocuPassView`. The SDK runs the full
   verification on-device and returns a `DocuPassResult`.
3. **Server-side**, fetch the verified result: `GET /docupass/{reference}`.

## Install (CocoaPods — recommended)

MediaPipe Tasks Vision is distributed via CocoaPods, so CocoaPods is the primary
build path:

```ruby
pod 'DocuPass', '~> 0.1'
```

Add to your **Info.plist**:

```xml
<key>NSCameraUsageDescription</key>
<string>Required to verify your identity.</string>
```

> SwiftPM: a `Package.swift` is included for the pure-Swift surface, but the
> liveness engine requires `MediaPipeTasksVision` (no official SPM yet) — supply
> it via an xcframework binary target, or use CocoaPods.

## Quick start (drop-in UI)

```swift
import SwiftUI
import DocuPass

struct VerifyScreen: View {
    var body: some View {
        DocuPassView(config: DocuPassConfig(reference: "US…")) { result in
            switch result {
            case .completed: break   // verified — fetch result server-side
            case .failed:    break   // rejected
            case .cancelled: break   // user dismissed
            case .error:     break   // network / fatal
            }
        }
    }
}
```

That's the whole integration. The view requests camera permission, renders every
step the DocuPass session asks for, and runs liveness on-device.

## Headless usage (your own UI)

```swift
let controller = DocuPassController(config: DocuPassConfig(reference: "US…"))
await controller.start()
await controller.submitDocumentSelection(country: "US", type: "D")
await controller.submitDocument(frontBase64: front, backBase64: back)
await controller.submitFace(frames: [faceBase64])
// observe controller.state (@Published)
```

The liveness building blocks are reusable: `FaceLandmarkerEngine` (MediaPipe) and
`LivenessController` (the neutral → turn-left → turn-right state machine).

## Requirements

- **iOS 15+**, Swift 5.9
- Bundled: the MediaPipe `face_landmarker.task` model + country/document catalog.

## Links

- DocuPass: https://www.idanalyzer.com/products/docupass.html
- Developer docs: https://developer.idanalyzer.com/help

## License

[MIT](LICENSE) © ID Analyzer

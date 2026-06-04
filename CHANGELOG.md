# Changelog

## 0.1.2

GPS / location support.

- Fixed `DOCUPASS_FATAL_ERROR` (`LOCATION_HEADER_MISSING`) right after document
  selection on DocuPass profiles that have **location tracking enabled**. When the
  session sets `gps = true`, the drop-in `DocuPassView` now requests location
  authorization (CoreLocation), obtains a device fix, and sends the `Geolocation`
  header on every subsequent request. The flow is held on a brief "getting your
  location" screen until the fix is set. (Previously the `setGeolocation` plumbing
  existed but was never invoked, so any GPS-enabled profile failed on the second
  server call.)
- Adds three overridable strings: `locationTitle`, `locationBody`,
  `locationPermissionRequired`. **Host apps must add `NSLocationWhenInUseUsageDescription`
  to their Info.plist** (as with `NSCameraUsageDescription`).

## 0.1.1

Audit fixes, customization hooks, and documentation corrections.

- **Customization** — `DocuPassStrings` (override any user-facing label, in any
  language) and `DocuPassTheme` (`primaryColor`, `logoUrl`, `showLogo`) threaded
  through `DocuPassView` via the SwiftUI Environment; one-line usage unchanged,
  headless API unaffected. Adds a public `Color(hex:)` initializer.
- **E-signature** — contract fields are now detected by `data-signature` (reading
  each element's `data-uid`), matching the DocuPass v3 web flow; leftover `%{…}`
  prefill placeholders are stripped before display.
- **Phone** — the dialing code is now chosen from a country picker populated from
  `session.phoneCountryCode` (was free text).
- Internal-only comments scrubbed from the published sources.

## 0.1.0

Initial DocuPass iOS SDK — full parity with the Android core.

- `DocuPassClient` — full docupassappv3 protocol (9 endpoints, DOCUPASS/
  DOCUPASS_SESSION auth progression, US/EU region, Geolocation, error taxonomy),
  async/await over URLSession.
- `DocuPassController` — headless `ObservableObject` state machine.
- On-device active liveness — `FaceLandmarkerEngine` (MediaPipeTasksVision,
  bundled `face_landmarker.task`) + `LivenessController` (neutral → turn-left →
  turn-right; ported from the web flow).
- AVFoundation capture (`CameraController`) — front liveness stream + back
  document still capture.
- Bundled country / document-type catalog.
- Drop-in SwiftUI `DocuPassView` covering document / face / custom form / phone /
  contract (with signature pad).
- CocoaPods podspec (depends on MediaPipeTasksVision); SwiftPM manifest for the
  pure-Swift surface.

Built against the DocuPass v3 API and verified against the production service.

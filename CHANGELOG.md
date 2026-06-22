# Changelog

## 0.2.0

- Rebuilt the SDK around the Android event-driven DocuPass session protocol.
- Added phone, custom form, document, face, contract, pending, completed, and failed events.
- Added all DocuPass app v3 API operations and session authorization progression.
- Added normalized server error actions for retry, resync, retake, edit, signature, and terminal states.
- Replaced synchronous MediaPipe video inference with the official iOS live-stream pattern using `CMSampleBuffer` and `detectAsync`.
- Added native SwiftUI document capture, active liveness, contract review, and signature submission.
- Location is now caller-provided through `DocupassApiConfig.geolocation`, matching Android behavior.

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
- Terminal/display error-code classification: fixed an infinite resync loop where
  `DOCUPASS_ERROR_MESSAGE` (e.g. session expired) was treated as recoverable and
  re-ran `get_action` forever. It is now a terminal failure. `DOCUPASS_SUCCESS_MESSAGE`
  / `DOCUPASS_REVIEW_CONTRACT` are terminal; `DOCUPASS_ERROR_POPUP` (phone-step alerts)
  shows the message and stays on the current step so the user can retry.

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

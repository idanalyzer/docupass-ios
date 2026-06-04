# Changelog

## 0.1.0 (unreleased)

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

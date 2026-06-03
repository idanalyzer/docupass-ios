// swift-tools-version:5.9
import PackageDescription

// NOTE: MediaPipe Tasks Vision is distributed via CocoaPods, not SwiftPM. The
// primary, supported build path for this SDK is CocoaPods (see DocuPass.podspec).
// This Package.swift builds the pure-Swift surface and bundles resources; the
// liveness engine needs `MediaPipeTasksVision`, which a SwiftPM consumer must
// supply (e.g. via an xcframework binary target) until MediaPipe ships SPM.
let package = Package(
    name: "DocuPass",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "DocuPass", targets: ["DocuPass"]),
    ],
    targets: [
        .target(
            name: "DocuPass",
            resources: [.process("Resources")]
        ),
    ]
)

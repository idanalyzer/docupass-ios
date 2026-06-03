import Foundation

/// Resolves the bundle holding `face_landmarker.task` + `country.json` for both
/// SwiftPM (`Bundle.module`) and CocoaPods (a `DocuPass.bundle` resource bundle).
enum DocuPassBundle {
    static var resources: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        let base = Bundle(for: BundleToken.self)
        if let url = base.url(forResource: "DocuPass", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return base
        #endif
    }
}

private final class BundleToken {}

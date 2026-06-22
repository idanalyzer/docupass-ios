import Foundation

enum DocupassBundle {
    static var resources: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        let framework = Bundle(for: BundleToken.self)
        if let url = framework.url(forResource: "DocuPass", withExtension: "bundle"), let bundle = Bundle(url: url) { return bundle }
        return framework
        #endif
    }
}

private final class BundleToken {}

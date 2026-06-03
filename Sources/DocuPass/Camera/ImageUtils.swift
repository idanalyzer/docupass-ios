import Foundation
import UIKit
import CoreImage
import CoreMedia

enum ImageUtils {
    /// Scale so the longest side is at most `maxSize`, preserving aspect ratio.
    static func scale(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSize else { return image }
        let factor = maxSize / longest
        let newSize = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    /// Base64 JPEG with NO `data:` prefix (what upload_* expects).
    static func jpegBase64(_ image: UIImage, quality: CGFloat) -> String {
        image.jpegData(compressionQuality: quality)?.base64EncodedString() ?? ""
    }

    static func prepareUpload(_ image: UIImage, maxSize: CGFloat, quality: CGFloat) -> String {
        jpegBase64(scale(image, maxSize: maxSize), quality: quality)
    }

    /// CMSampleBuffer -> upright UIImage.
    static func image(from sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cg = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: orientation)
    }
}

import AVFoundation
import CoreImage
import UIKit

enum ImageUtils {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }

    static func scale(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let source = normalized(image)
        let longest = max(source.size.width, source.size.height)
        guard longest > maxSize else { return source }
        let factor = maxSize / longest
        let size = CGSize(width: source.size.width * factor, height: source.size.height * factor)
        return UIGraphicsImageRenderer(size: size).image { _ in source.draw(in: CGRect(origin: .zero, size: size)) }
    }

    static func prepareUpload(_ image: UIImage, maxSize: CGFloat = 2_000, quality: CGFloat = 0.9) -> String {
        scale(image, maxSize: maxSize).jpegData(compressionQuality: quality)?.base64EncodedString() ?? ""
    }

    static func image(from sampleBuffer: CMSampleBuffer, mirrored: Bool = false) -> UIImage? {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        // The video output connection delivers portrait buffers, matching the
        // official MediaPipe sample's `.up` portrait orientation.
        var image = CIImage(cvPixelBuffer: buffer)
        if mirrored { image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -image.extent.width, y: 0)) }
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func cropDocument(_ image: UIImage, type: KYCDocumentType?, portraitCard: Bool = false, portraitDevice: Bool = true) -> UIImage {
        let source = normalized(image)
        guard let cg = source.cgImage else { return source }
        let targetAspect: CGFloat
        if type == .passport { targetAspect = portraitDevice ? 88 / 125 : 125 / 88 }
        else { targetAspect = portraitCard && portraitDevice ? 53.98 / 85.60 : 85.60 / 53.98 }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        var cropWidth = width * 0.9
        var cropHeight = cropWidth / targetAspect
        if cropHeight > height * 0.9 {
            cropHeight = height * 0.9
            cropWidth = cropHeight * targetAspect
        }
        var rect = CGRect(x: (width - cropWidth) / 2, y: (height - cropHeight) / 2, width: cropWidth, height: cropHeight).integral
        if type == .passport {
            rect.origin.y += rect.height / 2
            rect.size.height /= 2
            rect = rect.integral
        }
        guard let cropped = cg.cropping(to: rect) else { return source }
        return UIImage(cgImage: cropped, scale: source.scale, orientation: .up)
    }
}

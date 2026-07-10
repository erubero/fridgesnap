import UIKit

// Client-side compression before upload (spec section 4.1): max 1568px on
// the long edge, JPEG quality 0.8. Keeps vision quality high and image
// tokens low.
enum ImagePipeline {
    static let maxLongEdge: CGFloat = 1568
    static let jpegQuality: CGFloat = 0.8

    static func targetSize(for size: CGSize, maxLongEdge: CGFloat = ImagePipeline.maxLongEdge) -> CGSize {
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge, longEdge > 0 else { return size }
        let scale = maxLongEdge / longEdge
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    static func compress(_ image: UIImage) -> Data? {
        let target = targetSize(for: image.size)
        if target == image.size {
            return image.jpegData(compressionQuality: jpegQuality)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: jpegQuality)
    }
}

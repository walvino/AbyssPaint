import AppKit
import CoreGraphics

/// A plain RGBA8, sRGB, premultiplied bitmap backed by a `CGContext`.
/// All painting is done in pixel coordinates, origin at the bottom-left.
final class Bitmap {
    let width: Int
    let height: Int
    let context: CGContext

    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }

    init?(width: Int, height: Int) {
        let w = max(1, width)
        let h = max(1, height)

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }

        self.width = w
        self.height = h
        self.context = ctx
        self.context.setShouldAntialias(true)
        self.context.interpolationQuality = .high
    }

    var image: CGImage? {
        context.makeImage()
    }

    func clear() {
        context.saveGState()
        context.setBlendMode(.normal)
        context.setAlpha(1)
        context.clear(bounds)
        context.restoreGState()
    }

    /// Draws an image over the whole surface at full opacity.
    func draw(_ image: CGImage) {
        context.saveGState()
        context.setBlendMode(.normal)
        context.setAlpha(1)
        context.draw(image, in: bounds)
        context.restoreGState()
    }
}

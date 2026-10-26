import AppKit
import CoreGraphics

/// Builds and caches soft round brush "dabs" (stamp textures).
enum BrushRenderer {
    private static let dimension = 512
    private static var cache: [String: CGImage] = [:]
    private static var keys: [String] = []

    static func dab(color: NSColor, hardness: CGFloat) -> CGImage? {
        let srgb = color.usingColorSpace(.sRGB) ?? NSColor.black
        let h = min(max(hardness, 0), 0.98)
        let key = String(
            format: "%.3f_%.3f_%.3f_%.2f",
            srgb.redComponent,
            srgb.greenComponent,
            srgb.blueComponent,
            h
        )

        if let cached = cache[key] {
            return cached
        }

        guard let image = makeDab(color: srgb, hardness: h) else {
            return nil
        }

        cache[key] = image
        keys.append(key)
        while keys.count > 24 {
            let oldest = keys.removeFirst()
            cache.removeValue(forKey: oldest)
        }

        return image
    }

    private static func makeDab(color: NSColor, hardness: CGFloat) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: dimension,
                height: dimension,
                bitsPerComponent: 8,
                bytesPerRow: dimension * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }

        let opaque = color.withAlphaComponent(1).cgColor
        let transparent = color.withAlphaComponent(0).cgColor
        let locations: [CGFloat] = [0, hardness, 1]

        guard let gradient = CGGradient(
            colorsSpace: space,
            colors: [opaque, opaque, transparent] as CFArray,
            locations: locations
        ) else {
            return nil
        }

        let center = CGPoint(x: CGFloat(dimension) / 2, y: CGFloat(dimension) / 2)
        ctx.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: CGFloat(dimension) / 2 - 2,
            options: [.drawsBeforeStartLocation]
        )

        return ctx.makeImage()
    }
}

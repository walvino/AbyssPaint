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

    // MARK: - Grain

    private static var grainCache: [String: CGImage] = [:]
    private static var grainKeys: [String] = []

    /// A full-canvas alpha mask used to break up brush edges (texture grain).
    static func grainMask(width: Int, height: Int, strength: CGFloat) -> CGImage? {
        guard width > 0, height > 0, strength > 0.01 else { return nil }

        let rounded = (min(max(strength, 0), 1) * 20).rounded() / 20
        let key = "\(width)x\(height)x\(rounded)"

        if let cached = grainCache[key] {
            return cached
        }

        guard let bitmap = Bitmap(width: width, height: height),
              let data = bitmap.context.data else {
            return nil
        }

        let bytesPerRow = bitmap.context.bytesPerRow
        let pointer = data.assumingMemoryBound(to: UInt8.self)
        let amount = Double(rounded) * 0.85

        for y in 0..<height {
            let row = y * bytesPerRow
            for x in 0..<width {
                let random = Double.random(in: 0...1)
                let alpha = 1.0 - pow(random, 2.2) * amount
                let value = UInt8((alpha * 255).rounded())
                let offset = row + x * 4
                pointer[offset] = value
                pointer[offset + 1] = value
                pointer[offset + 2] = value
                pointer[offset + 3] = value
            }
        }

        guard let image = bitmap.image else { return nil }

        grainCache[key] = image
        grainKeys.append(key)
        while grainKeys.count > 3 {
            let oldest = grainKeys.removeFirst()
            grainCache.removeValue(forKey: oldest)
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

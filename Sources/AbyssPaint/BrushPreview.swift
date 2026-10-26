import AppKit

/// Renders a small tapered stroke for each brush preset, like a brush library preview.
enum BrushPreview {
    private static var cache: [String: NSImage] = [:]

    static func image(for preset: BrushPreset) -> NSImage? {
        if let cached = cache[preset.id] {
            return cached
        }

        let width = 360
        let height = 84

        guard let bitmap = Bitmap(width: width, height: height),
              let dab = BrushRenderer.dab(color: .white, hardness: preset.hardness) else {
            return nil
        }

        let context = bitmap.context
        let baseSize = min(46, max(4, preset.size * 0.5))
        let spacing = max(0.6, baseSize * preset.spacing)

        var previous: CGPoint?

        for step in 0...180 {
            let t = CGFloat(step) / 180
            let point = CGPoint(
                x: 22 + t * CGFloat(width - 44),
                y: CGFloat(height) / 2 + sin(t * .pi * 1.9 - 0.9) * 15
            )

            // Taper in and out for a natural stroke.
            let taper = sin(min(1, t * 1.15) * .pi)
            let pressure = 0.22 + 0.78 * max(0.05, taper)
            let diameter = baseSize * (0.35 + 0.65 * pressure)

            if let last = previous {
                let distance = hypot(point.x - last.x, point.y - last.y)
                let steps = max(1, Int((distance / spacing).rounded(.up)))
                for index in 1...steps {
                    let fraction = CGFloat(index) / CGFloat(steps)
                    let spot = CGPoint(
                        x: last.x + (point.x - last.x) * fraction,
                        y: last.y + (point.y - last.y) * fraction
                    )
                    let rect = CGRect(x: spot.x - diameter / 2,
                                      y: spot.y - diameter / 2,
                                      width: diameter,
                                      height: diameter)
                    context.setAlpha(0.95)
                    context.draw(dab, in: rect)
                }
            }

            previous = point
        }

        guard let cgImage = bitmap.image else { return nil }

        let image = NSImage(cgImage: cgImage,
                            size: NSSize(width: width, height: height))
        cache[preset.id] = image
        return image
    }
}

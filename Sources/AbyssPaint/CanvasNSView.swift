import AppKit

/// The drawing surface. Everything is painted with Core Graphics in the
/// document's pixel space, so what you see is exactly what gets exported.
final class CanvasNSView: NSView {
    weak var store: DocumentStore? {
        didSet { needsDisplay = true }
    }

    // View transform (canvas pixels -> view points)
    private var scale: CGFloat = 1
    private var rotation: CGFloat = 0
    private var offset: CGPoint = .zero
    private var fitted = false
    private var userAdjusted = false

    // Input state
    private var isPainting = false
    private var isPanning = false
    private var spaceDown = false
    private var lastCanvasPoint: CGPoint?
    private var lastPressure: CGFloat = 1
    private var lastTilt: CGPoint = .zero
    private var smoothedPoint: CGPoint?
    private var lastDragPoint: CGPoint = .zero
    private var hoverPoint: CGPoint?
    private var trackingAreaRef: NSTrackingArea?
    private var strokeStartPoint: CGPoint = .zero
    private var strokeLastPoint: CGPoint = .zero
    private var strokeLastMove = Date()
    private var lastRawCanvasPoint: CGPoint?
    private var strokeErases = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        refitIfNeeded()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refitIfNeeded()
    }

    private func refitIfNeeded() {
        guard !userAdjusted else { return }
        guard bounds.width > 40, bounds.height > 40 else { return }
        fitToWindow()
        fitted = true
    }

    // MARK: - Transform

    private var canvasCenter: CGPoint {
        guard let store else { return .zero }
        return CGPoint(x: store.canvasSize.width / 2, y: store.canvasSize.height / 2)
    }

    private func localTransform() -> CGAffineTransform {
        let center = canvasCenter
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: center.x, y: center.y)
        transform = transform.rotated(by: rotation)
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: -center.x, y: -center.y)
        return transform
    }

    private var fullTransform: CGAffineTransform {
        localTransform().concatenating(
            CGAffineTransform(translationX: offset.x, y: offset.y)
        )
    }

    func fitToWindow() {
        guard let store, bounds.width > 20, bounds.height > 20 else { return }

        let sideInset: CGFloat = 62
        let topInset: CGFloat = 96
        let bottomInset: CGFloat = 96

        let availableWidth = max(20, bounds.width - sideInset * 2)
        let availableHeight = max(20, bounds.height - topInset - bottomInset)
        let canvas = store.canvasSize

        rotation = 0
        scale = min(availableWidth / canvas.width, availableHeight / canvas.height)
        scale = min(max(scale, 0.02), 8)

        let center = canvasCenter
        let bandCenterY = bottomInset + availableHeight / 2
        offset = CGPoint(x: bounds.midX - center.x, y: bandCenterY - center.y)

        userAdjusted = false
        needsDisplay = true
    }

    func applyRotationCommand(_ command: DocumentStore.CanvasRotationCommand) {
        switch command {
        case .rotate(let angle):
            rotation += angle
        case .reset:
            rotation = 0
        }
        userAdjusted = true
        needsDisplay = true
    }

    private func place(anchor: CGPoint, at viewPoint: CGPoint) {
        let moved = anchor.applying(localTransform())
        offset = CGPoint(x: viewPoint.x - moved.x, y: viewPoint.y - moved.y)
    }

    private func zoom(by factor: CGFloat, around viewPoint: CGPoint) {
        guard factor.isFinite, factor > 0 else { return }
        let anchor = viewPoint.applying(fullTransform.inverted())
        scale = min(max(scale * factor, 0.03), 16)
        place(anchor: anchor, at: viewPoint)
        userAdjusted = true
        needsDisplay = true
    }

    private func rotate(by angle: CGFloat, around viewPoint: CGPoint) {
        let anchor = viewPoint.applying(fullTransform.inverted())
        rotation += angle
        place(anchor: anchor, at: viewPoint)
        userAdjusted = true
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor(calibratedRed: 0.055, green: 0.058, blue: 0.065, alpha: 1).cgColor)
        context.fill(bounds)

        guard let store else { return }

        let paperPath = canvasPathInViewSpace(store: store)

        // Paper + shadow
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -4),
            blur: 28,
            color: NSColor.black.withAlphaComponent(0.65).cgColor
        )
        context.addPath(paperPath)
        context.setFillColor(store.paperColor.cgColor)
        context.fillPath()
        context.restoreGState()

        // Layers
        context.saveGState()
        context.concatenate(fullTransform)
        context.clip(to: store.canvasRect)
        context.interpolationQuality = .high

        let documentRect = store.canvasRect
        let activeIndex = store.activeLayerIndex

        for (index, layer) in store.layers.enumerated() {
            if layer.isVisible, let image = layer.bitmap.image {
                context.setAlpha(CGFloat(layer.opacity))
                context.setBlendMode(layer.blendMode.cgBlendMode)
                context.draw(image, in: documentRect)
                context.setBlendMode(.normal)
            }

            if index == activeIndex,
               store.isStroking,
               store.tool == .brush,
               !store.currentStrokeErases,
               let stroke = store.strokeBitmap.image {
                context.setAlpha(store.brushOpacity)
                context.setBlendMode(.normal)
                context.draw(stroke, in: documentRect)
            }
        }

        context.setAlpha(1)
        context.restoreGState()

        // Canvas border
        context.addPath(paperPath)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        context.setLineWidth(1)
        context.strokePath()

        drawBrushCursor(in: context, store: store)
    }

    private func canvasPathInViewSpace(store: DocumentStore) -> CGPath {
        let path = CGMutablePath()
        path.addRect(store.canvasRect)
        var transform = fullTransform
        return path.copy(using: &transform) ?? path
    }

    private func drawBrushCursor(in context: CGContext, store: DocumentStore) {
        guard let hover = hoverPoint,
              !isPainting,
              store.tool != .eyedropper,
              window?.isKeyWindow == true else { return }

        let diameter = max(6, store.brushSize * scale)
        let rect = CGRect(
            x: hover.x - diameter / 2,
            y: hover.y - diameter / 2,
            width: diameter,
            height: diameter
        )

        context.setStrokeColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: rect)

        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: rect)
    }

    // MARK: - Coordinates

    private func viewPoint(_ event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    private func canvasPoint(_ event: NSEvent) -> CGPoint? {
        let point = viewPoint(event)
        let canvas = point.applying(fullTransform.inverted())
        guard canvas.x.isFinite, canvas.y.isFinite else { return nil }
        return canvas
    }

    private func pressure(for event: NSEvent) -> CGFloat {
        if event.subtype == .tabletPoint || event.pointingDeviceType != .unknown {
            return min(max(CGFloat(event.pressure), 0.01), 1.0)
        }
        return 1.0
    }

    private func tilt(for event: NSEvent) -> CGPoint {
        guard event.subtype == .tabletPoint else { return .zero }
        return CGPoint(x: CGFloat(event.tilt.x), y: CGFloat(event.tilt.y))
    }

    private func isEraserDevice(_ event: NSEvent) -> Bool {
        event.pointingDeviceType == .eraser
    }

    // MARK: - Mouse / tablet input

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        hoverPoint = viewPoint(event)

        if spaceDown {
            beginPan(event)
            return
        }

        guard let store, let point = canvasPoint(event) else { return }

        if store.tool == .eyedropper || event.modifierFlags.contains(.option) {
            if let sampled = store.sampleColor(at: point) {
                store.setColor(sampled)
            }
            return
        }

        guard store.canvasRect.contains(point), store.activeLayerIndex != nil else { return }

        let value = pressure(for: event)
        let eventTilt = tilt(for: event)
        strokeErases = store.tool == .eraser || isEraserDevice(event)
        strokeStartPoint = point
        strokeLastPoint = point
        strokeLastMove = Date()
        lastRawCanvasPoint = point

        isPainting = store.beginStroke(at: point,
                                       pressure: value,
                                       tilt: eventTilt,
                                       erase: strokeErases)
        guard isPainting else { return }

        lastCanvasPoint = point
        lastPressure = value
        lastTilt = eventTilt
        smoothedPoint = point

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        if isPanning {
            continuePan(event)
            return
        }

        guard isPainting, let store, var point = canvasPoint(event) else { return }

        let rawPoint = point
        let smoothing = store.brushSmoothing
        if smoothing > 0.001 {
            if smoothedPoint == nil { smoothedPoint = point }
            let factor = max(0.06, 1 - smoothing * 0.92)
            let previous = smoothedPoint ?? point
            point = CGPoint(
                x: previous.x + (point.x - previous.x) * factor,
                y: previous.y + (point.y - previous.y) * factor
            )
            smoothedPoint = point
        }

        let value = pressure(for: event)
        let eventTilt = tilt(for: event)
        if let last = lastCanvasPoint {
            store.continueStroke(
                from: last,
                to: point,
                fromPressure: lastPressure,
                toPressure: value,
                fromTilt: lastTilt,
                toTilt: eventTilt
            )
        }

        lastCanvasPoint = point
        lastPressure = value
        lastTilt = eventTilt

        if let lastRaw = lastRawCanvasPoint {
            let mx = rawPoint.x - lastRaw.x
            let my = rawPoint.y - lastRaw.y
            if (mx * mx + my * my).squareRoot() > 0.5 {
                strokeLastPoint = point
                strokeLastMove = Date()
                lastRawCanvasPoint = rawPoint
            }
        } else {
            strokeLastPoint = point
            strokeLastMove = Date()
            lastRawCanvasPoint = rawPoint
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if isPanning {
            endPan()
            return
        }

        guard isPainting, let store else { return }

        // Hold still at the end of a brush stroke to snap it to a straight line.
        let held = Date().timeIntervalSince(strokeLastMove) > 0.25
        let dx = strokeLastPoint.x - strokeStartPoint.x
        let dy = strokeLastPoint.y - strokeStartPoint.y
        let length = (dx * dx + dy * dy).squareRoot()
        if held, !strokeErases, store.tool == .brush, length > 24 {
            store.quickShape(from: strokeStartPoint, to: strokeLastPoint)
        }

        store.endStroke()
        isPainting = false
        lastCanvasPoint = nil
        lastRawCanvasPoint = nil
        smoothedPoint = nil
        hoverPoint = viewPoint(event)
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        hoverPoint = viewPoint(event)
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent) {
        hoverPoint = viewPoint(event)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hoverPoint = nil
        needsDisplay = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    // MARK: - Pan

    override func otherMouseDown(with event: NSEvent) {
        beginPan(event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        continuePan(event)
    }

    override func otherMouseUp(with event: NSEvent) {
        endPan()
    }

    private func beginPan(_ event: NSEvent) {
        isPanning = true
        lastDragPoint = viewPoint(event)
        NSCursor.closedHand.set()
    }

    private func continuePan(_ event: NSEvent) {
        let point = viewPoint(event)
        offset.x += point.x - lastDragPoint.x
        offset.y += point.y - lastDragPoint.y
        lastDragPoint = point
        userAdjusted = true
        needsDisplay = true
    }

    private func endPan() {
        isPanning = false
        (spaceDown ? NSCursor.openHand : NSCursor.arrow).set()
    }

    // MARK: - Zoom & rotation

    override func scrollWheel(with event: NSEvent) {
        let point = viewPoint(event)

        if event.modifierFlags.contains(.option) || event.modifierFlags.contains(.command) {
            let factor = exp(-event.scrollingDeltaY * 0.01)
            zoom(by: factor, around: point)
        } else {
            offset.x += event.scrollingDeltaX
            offset.y += event.scrollingDeltaY
            userAdjusted = true
            needsDisplay = true
        }
    }

    override func magnify(with event: NSEvent) {
        zoom(by: 1 + event.magnification, around: viewPoint(event))
    }

    override func rotate(with event: NSEvent) {
        let angle = -CGFloat(event.rotation) * .pi / 180
        rotate(by: angle, around: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        guard let store else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 49 { // space
            spaceDown = true
            NSCursor.openHand.set()
            return
        }

        guard !event.modifierFlags.contains(.command),
              let characters = event.charactersIgnoringModifiers?.lowercased() else {
            super.keyDown(with: event)
            return
        }

        switch characters {
        case "b":
            store.tool = .brush
        case "e":
            store.tool = .eraser
        case "i":
            store.tool = .eyedropper
        case "[":
            store.brushSize = max(1, store.brushSize / 1.15)
        case "]":
            store.brushSize = min(400, store.brushSize * 1.15)
        case "0":
            store.fitCanvas()
        default:
            super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceDown = false
            NSCursor.arrow.set()
            return
        }
        super.keyUp(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}

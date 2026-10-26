import AppKit

/// The drawing surface. Everything is painted with Core Graphics in the
/// document's pixel space, so what you see is exactly what gets exported.
final class CanvasNSView: NSView {
    weak var store: DocumentStore? {
        didSet { needsDisplay = true }
    }

    // View transform (view points -> canvas pixels)
    private var scale: CGFloat = 1
    private var offset: CGPoint = .zero
    private var fitted = false
    private var userAdjusted = false

    // Input state
    private var isPainting = false
    private var isPanning = false
    private var spaceDown = false
    private var lastCanvasPoint: CGPoint?
    private var lastPressure: CGFloat = 1
    private var lastDragPoint: CGPoint = .zero
    private var hoverPoint: CGPoint?
    private var trackingAreaRef: NSTrackingArea?

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

    func fitToWindow() {
        guard let store, bounds.width > 10, bounds.height > 10 else { return }

        let margin: CGFloat = 48
        let availableWidth = max(10, bounds.width - margin * 2)
        let availableHeight = max(10, bounds.height - margin * 2)
        let canvas = store.canvasSize

        scale = min(availableWidth / canvas.width, availableHeight / canvas.height)
        scale = min(max(scale, 0.02), 8)

        offset = CGPoint(
            x: (bounds.width - canvas.width * scale) / 2,
            y: (bounds.height - canvas.height * scale) / 2
        )

        needsDisplay = true
    }

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

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor(calibratedRed: 0.075, green: 0.078, blue: 0.086, alpha: 1).cgColor)
        context.fill(bounds)

        guard let store else { return }

        let canvasRect = CGRect(
            origin: offset,
            size: CGSize(
                width: store.canvasSize.width * scale,
                height: store.canvasSize.height * scale
            )
        )

        // Paper + drop shadow
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -6),
            blur: 26,
            color: NSColor.black.withAlphaComponent(0.6).cgColor
        )
        context.setFillColor(NSColor.white.cgColor)
        context.fill(canvasRect)
        context.restoreGState()

        // Layers
        context.saveGState()
        context.translateBy(x: offset.x, y: offset.y)
        context.scaleBy(x: scale, y: scale)

        let documentRect = store.canvasRect
        context.clip(to: documentRect)
        context.interpolationQuality = .high

        let activeIndex = store.activeLayerIndex

        for (index, layer) in store.layers.enumerated() {
            if layer.isVisible, let image = layer.bitmap.image {
                context.setAlpha(CGFloat(layer.opacity))
                context.draw(image, in: documentRect)
            }

            if index == activeIndex,
               store.isStroking,
               store.tool == .brush,
               let stroke = store.strokeBitmap.image {
                context.setAlpha(store.brushOpacity)
                context.draw(stroke, in: documentRect)
            }
        }

        context.setAlpha(1)
        context.restoreGState()

        // Canvas border
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
        context.setLineWidth(1)
        context.stroke(canvasRect.insetBy(dx: -0.5, dy: -0.5))

        drawBrushCursor(in: context, store: store)
    }

    private func drawBrushCursor(in context: CGContext, store: DocumentStore) {
        guard let hover = hoverPoint, !isPainting, window?.isKeyWindow == true else { return }

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
        guard scale > 0 else { return nil }
        let point = viewPoint(event)
        return CGPoint(
            x: (point.x - offset.x) / scale,
            y: (point.y - offset.y) / scale
        )
    }

    private func pressure(for event: NSEvent) -> CGFloat {
        if event.subtype == .tabletPoint {
            return min(max(CGFloat(event.pressure), 0.01), 1.0)
        }
        return 1.0
    }

    // MARK: - Mouse / tablet input

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        hoverPoint = viewPoint(event)

        if event.clickCount == 2 {
            userAdjusted = false
            fitToWindow()
            return
        }

        if spaceDown {
            beginPan(event)
            return
        }

        guard let store,
              let point = canvasPoint(event),
              store.canvasRect.contains(point),
              store.activeLayerIndex != nil
        else { return }

        let value = pressure(for: event)
        isPainting = true
        lastCanvasPoint = point
        lastPressure = value

        store.beginStroke(at: point, pressure: value)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        if isPanning {
            continuePan(event)
            return
        }

        guard isPainting, let store, let point = canvasPoint(event) else { return }

        let value = pressure(for: event)
        if let last = lastCanvasPoint {
            store.continueStroke(
                from: last,
                to: point,
                fromPressure: lastPressure,
                toPressure: value
            )
        }

        lastCanvasPoint = point
        lastPressure = value
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if isPanning {
            endPan()
            return
        }

        guard isPainting, let store else { return }

        store.endStroke()
        isPainting = false
        lastCanvasPoint = nil
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

    // MARK: - Middle-button pan

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

    // MARK: - Zoom

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

    private func zoom(by factor: CGFloat, around point: CGPoint) {
        guard factor.isFinite, factor > 0, scale > 0 else { return }

        let canvasX = (point.x - offset.x) / scale
        let canvasY = (point.y - offset.y) / scale

        let newScale = min(max(scale * factor, 0.03), 16)
        scale = newScale
        offset = CGPoint(
            x: point.x - canvasX * newScale,
            y: point.y - canvasY * newScale
        )

        userAdjusted = true
        needsDisplay = true
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // space
            spaceDown = true
            NSCursor.openHand.set()
            return
        }
        super.keyDown(with: event)
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

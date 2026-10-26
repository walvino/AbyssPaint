import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - Tool

enum Tool: String, CaseIterable, Identifiable {
    case brush
    case eraser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brush: return "Brush"
        case .eraser: return "Eraser"
        }
    }

    var symbolName: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .eraser: return "eraser.fill"
        }
    }
}

// MARK: - Layer

struct Layer: Identifiable {
    let id = UUID()
    var name: String
    var isVisible: Bool = true
    var opacity: Double = 1
    let bitmap: Bitmap
}

// MARK: - Presets

struct BrushPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let symbolName: String
    let size: CGFloat
    let hardness: CGFloat
    let spacing: CGFloat
    let opacity: CGFloat

    static let builtIn: [BrushPreset] = [
        BrushPreset(id: "round", name: "Round", symbolName: "circle.fill",
                    size: 26, hardness: 0.85, spacing: 0.10, opacity: 1.0),
        BrushPreset(id: "soft", name: "Soft Airbrush", symbolName: "cloud.fill",
                    size: 90, hardness: 0.05, spacing: 0.06, opacity: 0.45),
        BrushPreset(id: "pencil", name: "Pencil", symbolName: "pencil.tip",
                    size: 6, hardness: 0.95, spacing: 0.08, opacity: 0.9),
        BrushPreset(id: "ink", name: "Ink", symbolName: "drop.fill",
                    size: 14, hardness: 1.0, spacing: 0.04, opacity: 1.0),
        BrushPreset(id: "marker", name: "Marker", symbolName: "highlighter",
                    size: 48, hardness: 0.7, spacing: 0.09, opacity: 0.8),
        BrushPreset(id: "eraser", name: "Eraser", symbolName: "eraser.fill",
                    size: 40, hardness: 0.7, spacing: 0.08, opacity: 1.0)
    ]
}

// MARK: - Document

final class DocumentStore: ObservableObject {
    static let shared = DocumentStore()

    @Published private(set) var canvasSize: CGSize
    @Published var layers: [Layer]
    @Published var activeLayerID: UUID?

    @Published var tool: Tool = .brush
    @Published var brushSize: CGFloat = 26
    @Published var brushOpacity: CGFloat = 1.0
    @Published var brushHardness: CGFloat = 0.85
    @Published var brushSpacing: CGFloat = 0.10
    @Published var color: NSColor = NSColor(srgbRed: 0.851, green: 0.227, blue: 0.157, alpha: 1)

    @Published var selectedPresetID: String = "round"
    @Published var fitRequest: Int = 0
    @Published var revision: Int = 0
    @Published private(set) var isStroking: Bool = false
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    let presets = BrushPreset.builtIn

    private(set) var strokeBitmap: Bitmap
    private var drawingContext: CGContext?
    private var lastDabPoint: CGPoint?
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    private struct Snapshot {
        let layerID: UUID
        let image: CGImage?
    }

    // MARK: Init

    private init() {
        let width = 1600
        let height = 1200

        canvasSize = CGSize(width: width, height: height)

        guard let stroke = Bitmap(width: width, height: height),
              let base = Bitmap(width: width, height: height) else {
            fatalError("Unable to allocate the canvas bitmap")
        }

        strokeBitmap = stroke
        let layer = Layer(name: "Layer 1", bitmap: base)
        layers = [layer]
        activeLayerID = layer.id
    }

    // MARK: Derived state

    var canvasRect: CGRect {
        CGRect(origin: .zero, size: canvasSize)
    }

    var activeLayerIndex: Int? {
        guard let activeLayerID else { return nil }
        return layers.firstIndex(where: { $0.id == activeLayerID })
    }

    var activeLayer: Layer? {
        guard let index = activeLayerIndex else { return nil }
        return layers[index]
    }

    private var thumbnailCache: [UUID: (revision: Int, image: NSImage)] = [:]

    func thumbnail(for layer: Layer) -> NSImage? {
        if let cached = thumbnailCache[layer.id], cached.revision == revision {
            return cached.image
        }

        guard let cgImage = layer.bitmap.image else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: 64, height: 64))
        thumbnailCache[layer.id] = (revision, image)
        return image
    }

    // MARK: Presets

    func selectPreset(_ preset: BrushPreset) {
        selectedPresetID = preset.id
        brushSize = preset.size
        brushHardness = preset.hardness
        brushSpacing = preset.spacing
        brushOpacity = preset.opacity
        tool = preset.id == "eraser" ? .eraser : .brush
    }

    // MARK: Strokes

    func beginStroke(at point: CGPoint, pressure: CGFloat) {
        guard let index = activeLayerIndex else { return }

        pushUndo(Snapshot(layerID: layers[index].id, image: layers[index].bitmap.image))
        lastDabPoint = nil
        isStroking = true

        switch tool {
        case .brush:
            strokeBitmap.clear()
            drawingContext = strokeBitmap.context
        case .eraser:
            layers[index].bitmap.context.setBlendMode(.destinationOut)
            drawingContext = layers[index].bitmap.context
        }

        stamp(at: point, pressure: pressure)
    }

    func continueStroke(from: CGPoint, to: CGPoint,
                        fromPressure: CGFloat, toPressure: CGFloat) {
        guard isStroking, drawingContext != nil else { return }

        let spacingPixels = max(0.75, brushSize * max(0.02, brushSpacing))
        guard let start = lastDabPoint else {
            stamp(at: to, pressure: toPressure)
            return
        }

        let dx = to.x - start.x
        let dy = to.y - start.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance >= spacingPixels * 0.35 else { return }

        let steps = max(1, Int((distance / spacingPixels).rounded(.up)))
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(x: start.x + dx * t, y: start.y + dy * t)
            let pressure = fromPressure + (toPressure - fromPressure) * t
            stamp(at: point, pressure: pressure)
        }
    }

    func endStroke() {
        guard isStroking else { return }

        isStroking = false
        drawingContext = nil
        lastDabPoint = nil

        defer { revision += 1 }

        if tool == .eraser {
            activeLayer?.bitmap.context.setBlendMode(.normal)
            return
        }

        guard let index = activeLayerIndex, let image = strokeBitmap.image else { return }
        let context = layers[index].bitmap.context

        context.saveGState()
        context.setBlendMode(.normal)
        context.setAlpha(brushOpacity)
        context.draw(image, in: canvasRect)
        context.restoreGState()

        strokeBitmap.clear()
    }

    private func stamp(at point: CGPoint, pressure: CGFloat) {
        guard let context = drawingContext else { return }

        let clamped = min(max(pressure, 0.01), 1.0)
        let curved = pow(clamped, 0.75)
        let diameter = max(1.0, brushSize * (0.25 + 0.75 * curved))

        let dabColor = tool == .brush ? color : NSColor.white
        guard let dab = BrushRenderer.dab(color: dabColor, hardness: brushHardness) else { return }

        let rect = CGRect(
            x: point.x - diameter / 2,
            y: point.y - diameter / 2,
            width: diameter,
            height: diameter
        )

        context.setAlpha(1)
        context.draw(dab, in: rect)

        lastDabPoint = point
    }

    // MARK: Undo

    private func pushUndo(_ snapshot: Snapshot) {
        undoStack.append(snapshot)
        if undoStack.count > 40 {
            undoStack.removeFirst(undoStack.count - 40)
        }
        redoStack.removeAll()
        updateUndoFlags()
    }

    func undo() {
        guard let snapshot = undoStack.popLast(),
              let index = layers.firstIndex(where: { $0.id == snapshot.layerID }) else {
            return
        }

        redoStack.append(Snapshot(layerID: snapshot.layerID, image: layers[index].bitmap.image))

        if let image = snapshot.image {
            layers[index].bitmap.clear()
            layers[index].bitmap.draw(image)
        } else {
            layers[index].bitmap.clear()
        }

        updateUndoFlags()
        revision += 1
    }

    func redo() {
        guard let snapshot = redoStack.popLast(),
              let index = layers.firstIndex(where: { $0.id == snapshot.layerID }) else {
            return
        }

        undoStack.append(Snapshot(layerID: snapshot.layerID, image: layers[index].bitmap.image))

        if let image = snapshot.image {
            layers[index].bitmap.clear()
            layers[index].bitmap.draw(image)
        } else {
            layers[index].bitmap.clear()
        }

        updateUndoFlags()
        revision += 1
    }

    private func updateUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    // MARK: Layers

    func addLayer() {
        guard let bitmap = Bitmap(width: Int(canvasSize.width),
                                  height: Int(canvasSize.height)) else { return }

        let layer = Layer(name: "Layer \(layers.count + 1)", bitmap: bitmap)
        let insertAt = activeLayerIndex.map { $0 + 1 } ?? layers.count
        layers.insert(layer, at: insertAt)
        activeLayerID = layer.id
        revision += 1
    }

    func duplicateActiveLayer() {
        guard let index = activeLayerIndex,
              let bitmap = Bitmap(width: Int(canvasSize.width),
                                  height: Int(canvasSize.height)) else { return }

        if let image = layers[index].bitmap.image {
            bitmap.draw(image)
        }

        let copy = Layer(name: layers[index].name + " copy",
                         isVisible: layers[index].isVisible,
                         opacity: layers[index].opacity,
                         bitmap: bitmap)

        layers.insert(copy, at: index + 1)
        activeLayerID = copy.id
        revision += 1
    }

    func deleteActiveLayer() {
        guard layers.count > 1, let index = activeLayerIndex else { return }
        layers.remove(at: index)
        let next = max(0, min(index, layers.count - 1))
        activeLayerID = layers[next].id
        revision += 1
    }

    func moveActiveLayer(up: Bool) {
        guard let index = activeLayerIndex else { return }
        let target = up ? index + 1 : index - 1
        guard layers.indices.contains(target) else { return }
        layers.swapAt(index, target)
        revision += 1
    }

    func clearActiveLayer() {
        guard let index = activeLayerIndex else { return }
        pushUndo(Snapshot(layerID: layers[index].id, image: layers[index].bitmap.image))
        layers[index].bitmap.clear()
        revision += 1
    }

    // MARK: Document

    func newDocument(size: CGSize = CGSize(width: 1600, height: 1200)) {
        let width = max(64, Int(size.width))
        let height = max(64, Int(size.height))

        guard let stroke = Bitmap(width: width, height: height),
              let layerBitmap = Bitmap(width: width, height: height) else { return }

        canvasSize = CGSize(width: width, height: height)
        strokeBitmap = stroke

        let layer = Layer(name: "Layer 1", bitmap: layerBitmap)
        layers = [layer]
        activeLayerID = layer.id

        undoStack.removeAll()
        redoStack.removeAll()
        isStroking = false
        drawingContext = nil
        lastDabPoint = nil
        updateUndoFlags()
        revision += 1
    }

    func flattenedImage() -> CGImage? {
        guard let flat = Bitmap(width: Int(canvasSize.width),
                                height: Int(canvasSize.height)) else { return nil }

        let context = flat.context
        context.setFillColor(NSColor.white.cgColor)
        context.fill(flat.bounds)

        for layer in layers where layer.isVisible {
            guard let image = layer.bitmap.image else { continue }
            context.saveGState()
            context.setAlpha(CGFloat(layer.opacity))
            context.draw(image, in: flat.bounds)
            context.restoreGState()
        }

        return flat.image
    }

    func exportPNG() {
        guard let image = flattenedImage() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "AbyssPaint.png"
        panel.canCreateDirectories = true
        panel.title = "Export artwork as PNG"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let rep = NSBitmapImageRep(cgImage: image)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
    }
}

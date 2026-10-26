import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - Tool

enum Tool: String, CaseIterable, Identifiable {
    case brush
    case eraser
    case eyedropper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brush: return "Brush"
        case .eraser: return "Eraser"
        case .eyedropper: return "Eyedropper"
        }
    }

    var symbolName: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .eraser: return "eraser.fill"
        case .eyedropper: return "eyedropper"
        }
    }
}

// MARK: - Symmetry

enum SymmetryMode: String, CaseIterable, Identifiable {
    case off
    case vertical
    case horizontal
    case quadrant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .vertical: return "Vertical"
        case .horizontal: return "Horizontal"
        case .quadrant: return "Quadrant"
        }
    }

    var symbolName: String {
        switch self {
        case .off: return "rectangle.split.1x1"
        case .vertical: return "rectangle.split.2x1"
        case .horizontal: return "rectangle.split.1x2"
        case .quadrant: return "rectangle.split.2x2"
        }
    }
}

// MARK: - Blend modes

enum LayerBlendMode: String, CaseIterable, Identifiable, Codable {
    case normal
    case multiply
    case screen
    case overlay
    case add
    case darken
    case lighten
    case colorDodge
    case colorBurn
    case softLight
    case hardLight
    case difference
    case exclusion
    case hue
    case saturation
    case color
    case luminosity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        case .overlay: return "Overlay"
        case .add: return "Add"
        case .darken: return "Darken"
        case .lighten: return "Lighten"
        case .colorDodge: return "Color Dodge"
        case .colorBurn: return "Color Burn"
        case .softLight: return "Soft Light"
        case .hardLight: return "Hard Light"
        case .difference: return "Difference"
        case .exclusion: return "Exclusion"
        case .hue: return "Hue"
        case .saturation: return "Saturation"
        case .color: return "Color"
        case .luminosity: return "Luminosity"
        }
    }

    var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .add: return .plusLighter
        case .darken: return .darken
        case .lighten: return .lighten
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        }
    }
}

// MARK: - Layer

struct Layer: Identifiable {
    let id: UUID
    var name: String
    var isVisible: Bool
    var isLocked: Bool
    var isAlphaLocked: Bool
    var opacity: Double
    var blendMode: LayerBlendMode
    let bitmap: Bitmap

    init(id: UUID = UUID(),
         name: String,
         isVisible: Bool = true,
         isLocked: Bool = false,
         isAlphaLocked: Bool = false,
         opacity: Double = 1,
         blendMode: LayerBlendMode = .normal,
         bitmap: Bitmap) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.isAlphaLocked = isAlphaLocked
        self.opacity = opacity
        self.blendMode = blendMode
        self.bitmap = bitmap
    }
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
    let flow: CGFloat
    let smoothing: CGFloat
    let grain: CGFloat

    static let builtIn: [BrushPreset] = [
        BrushPreset(id: "round", name: "Round Brush", symbolName: "circle.fill",
                    size: 26, hardness: 0.85, spacing: 0.10, opacity: 1.0, flow: 1.0, smoothing: 0.18, grain: 0.10),
        BrushPreset(id: "soft", name: "Soft Airbrush", symbolName: "cloud.fill",
                    size: 110, hardness: 0.02, spacing: 0.05, opacity: 0.55, flow: 0.16, smoothing: 0.3, grain: 0.0),
        BrushPreset(id: "pencil", name: "Pencil", symbolName: "pencil.tip",
                    size: 5, hardness: 0.95, spacing: 0.07, opacity: 0.95, flow: 0.7, smoothing: 0.1, grain: 0.45),
        BrushPreset(id: "ink", name: "Studio Ink", symbolName: "drop.fill",
                    size: 16, hardness: 1.0, spacing: 0.03, opacity: 1.0, flow: 1.0, smoothing: 0.45, grain: 0.0),
        BrushPreset(id: "marker", name: "Marker", symbolName: "highlighter",
                    size: 54, hardness: 0.72, spacing: 0.08, opacity: 0.85, flow: 0.5, smoothing: 0.2, grain: 0.12),
        BrushPreset(id: "eraser", name: "Soft Eraser", symbolName: "eraser.fill",
                    size: 46, hardness: 0.55, spacing: 0.06, opacity: 1.0, flow: 1.0, smoothing: 0.2, grain: 0.0)
    ]
}

// MARK: - Document

final class DocumentStore: ObservableObject {
    static let shared = DocumentStore()

    // Document
    @Published private(set) var canvasSize: CGSize
    @Published var layers: [Layer]
    @Published var activeLayerID: UUID?
    @Published private(set) var documentURL: URL?
    @Published private(set) var documentName: String = "Untitled"

    // Tools
    @Published var tool: Tool = .brush
    @Published var brushSize: CGFloat = 26
    @Published var brushOpacity: CGFloat = 1.0
    @Published var brushFlow: CGFloat = 1.0
    @Published var brushHardness: CGFloat = 0.85
    @Published var brushSpacing: CGFloat = 0.10
    @Published var brushSmoothing: CGFloat = 0.18
    @Published var brushGrain: CGFloat = 0.10
    @Published var brushTaper: CGFloat = 0.12
    @Published var pressureCurve: CGFloat = 1.0
    @Published var paperColor: NSColor = .white
    @Published var color: NSColor = NSColor(srgbRed: 0.851, green: 0.227, blue: 0.157, alpha: 1)
    @Published var recentColors: [NSColor] = [
        NSColor(srgbRed: 0.851, green: 0.227, blue: 0.157, alpha: 1),
        NSColor(srgbRed: 0.376, green: 0.804, blue: 0.451, alpha: 1),
        NSColor(srgbRed: 0.98, green: 0.75, blue: 0.18, alpha: 1),
        NSColor(srgbRed: 0.20, green: 0.55, blue: 0.95, alpha: 1),
        NSColor.white,
        NSColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1)
    ]
    @Published var selectedPresetID: String = "round"
    @Published var recentPresetIDs: [String] = UserDefaults.standard.stringArray(forKey: "AbyssRecentBrushes") ?? ["round", "soft", "pencil"]
    @Published var symmetry: SymmetryMode = .off

    // UI sync
    @Published var revision: Int = 0 {
        didSet {
            if suppressAutosave {
                suppressAutosave = false
                return
            }
            hasUnsavedEdits = true
            scheduleAutosave()
        }
    }
    @Published var fitRequest: Int = 0
    @Published private(set) var rotationCommandID: Int = 0
    private(set) var rotationCommand: CanvasRotationCommand = .reset
    @Published private(set) var isStroking: Bool = false
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    @Published private(set) var historyPosition: Int = 0
    @Published private(set) var historyLength: Int = 0
    @Published var toast: String?
    @Published var showsNewCanvasSheet: Bool = ProcessInfo.processInfo.environment["ABYSS_SHOW_NEW"] != nil
    @Published private(set) var recoveredAutosave: Bool = false

    let presets = BrushPreset.builtIn

    private(set) var strokeBitmap: Bitmap
    private var drawingContext: CGContext?
    private var lastDabPoint: CGPoint?
    private var strokeStartPoint: CGPoint = .zero
    private var strokeDistance: CGFloat = 0
    private var strokeErases = false
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []
    private var thumbnailCache: [UUID: (revision: Int, image: NSImage)] = [:]
    private var toastToken = 0
    private var autosaveWorkItem: DispatchWorkItem?
    private var suppressAutosave = false
    private(set) var hasUnsavedEdits = false
    let autosaveEnabled = ProcessInfo.processInfo.environment["ABYSS_SELFTEST"] == nil
        && ProcessInfo.processInfo.environment["ABYSS_SNAPSHOT"] == nil

    private struct Snapshot {
        struct Item {
            let id: UUID
            let name: String
            let isVisible: Bool
            let isLocked: Bool
            let isAlphaLocked: Bool
            let opacity: Double
            let blendMode: LayerBlendMode
            let image: CGImage?
        }

        let items: [Item]
        let activeLayerID: UUID?
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

    // MARK: Canvas view commands

    enum CanvasRotationCommand {
        case rotate(CGFloat)
        case reset
    }

    func fitCanvas() {
        rotationCommand = .reset
        rotationCommandID += 1
        fitRequest += 1
    }

    func rotateCanvas(by angle: CGFloat) {
        rotationCommand = .rotate(angle)
        rotationCommandID += 1
    }

    func resetCanvasRotation() {
        rotationCommand = .reset
        rotationCommandID += 1
    }

    var activeLayerIndex: Int? {
        guard let activeLayerID else { return nil }
        return layers.firstIndex(where: { $0.id == activeLayerID })
    }

    var activeLayer: Layer? {
        guard let index = activeLayerIndex else { return nil }
        return layers[index]
    }

    var currentStrokeErases: Bool { strokeErases }

    func thumbnail(for layer: Layer) -> NSImage? {
        if let cached = thumbnailCache[layer.id], cached.revision == revision {
            return cached.image
        }

        guard let cgImage = layer.bitmap.image else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: 64, height: 64))
        thumbnailCache[layer.id] = (revision, image)
        return image
    }

    // MARK: Presets & color

    func selectPreset(_ preset: BrushPreset) {
        selectedPresetID = preset.id
        brushSize = preset.size
        brushHardness = preset.hardness
        brushSpacing = preset.spacing
        brushOpacity = preset.opacity
        brushFlow = preset.flow
        brushSmoothing = preset.smoothing
        brushGrain = preset.grain
        tool = preset.id == "eraser" ? .eraser : .brush

        recentPresetIDs.removeAll { $0 == preset.id }
        recentPresetIDs.insert(preset.id, at: 0)
        if recentPresetIDs.count > 4 {
            recentPresetIDs.removeLast(recentPresetIDs.count - 4)
        }
        UserDefaults.standard.set(recentPresetIDs, forKey: "AbyssRecentBrushes")
    }

    func setColor(_ newColor: NSColor, remember: Bool = true) {
        let srgb = newColor.usingColorSpace(.sRGB) ?? NSColor.black
        color = srgb

        guard remember else { return }

        recentColors.removeAll { existing in
            abs(existing.redComponent - srgb.redComponent) < 0.004 &&
            abs(existing.greenComponent - srgb.greenComponent) < 0.004 &&
            abs(existing.blueComponent - srgb.blueComponent) < 0.004
        }
        recentColors.insert(srgb, at: 0)
        if recentColors.count > 10 {
            recentColors.removeLast(recentColors.count - 10)
        }
    }

    func sampleColor(at point: CGPoint) -> NSColor? {
        guard let image = flattenedImage() else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.interpolationQuality = .none
        context.translateBy(x: -point.x, y: -point.y)
        context.draw(image, in: CGRect(origin: .zero,
                                       size: CGSize(width: image.width, height: image.height)))

        let red = CGFloat(pixel[0]) / 255
        let green = CGFloat(pixel[1]) / 255
        let blue = CGFloat(pixel[2]) / 255

        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    // MARK: Strokes

    @discardableResult
    func beginStroke(at point: CGPoint, pressure: CGFloat, tilt: CGPoint = .zero, erase: Bool = false) -> Bool {
        guard let index = activeLayerIndex else { return false }
        guard !layers[index].isLocked else {
            showToast("Layer is locked")
            return false
        }
        guard layers[index].isVisible else {
            showToast("Layer is hidden")
            return false
        }

        strokeErases = erase || tool == .eraser

        if strokeErases, layers[index].isAlphaLocked {
            showToast("Alpha lock is on")
            return false
        }

        pushUndo()
        lastDabPoint = nil
        strokeStartPoint = point
        strokeDistance = 0
        isStroking = true

        if strokeErases {
            layers[index].bitmap.context.setBlendMode(.destinationOut)
            drawingContext = layers[index].bitmap.context
        } else {
            strokeBitmap.clear()
            drawingContext = strokeBitmap.context
        }

        stamp(at: point, pressure: pressure, tilt: tilt)
        return true
    }

    func continueStroke(from: CGPoint, to: CGPoint,
                        fromPressure: CGFloat, toPressure: CGFloat,
                        fromTilt: CGPoint = .zero, toTilt: CGPoint = .zero) {
        guard isStroking, drawingContext != nil else { return }

        let spacingPixels = max(0.75, brushSize * max(0.02, brushSpacing))
        guard let start = lastDabPoint else {
            stamp(at: to, pressure: toPressure, tilt: toTilt)
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
            let tilt = CGPoint(x: fromTilt.x + (toTilt.x - fromTilt.x) * t,
                               y: fromTilt.y + (toTilt.y - fromTilt.y) * t)
            strokeDistance += distance / CGFloat(steps)
            stamp(at: point, pressure: pressure, tilt: tilt)
        }
    }

    func endStroke() {
        guard isStroking else { return }

        isStroking = false
        drawingContext = nil
        lastDabPoint = nil

        defer { revision += 1 }

        if strokeErases {
            activeLayer?.bitmap.context.setBlendMode(.normal)
            return
        }

        applyGrain()

        guard let index = activeLayerIndex, let image = strokeBitmap.image else { return }
        let context = layers[index].bitmap.context

        context.saveGState()
        context.setBlendMode(layers[index].isAlphaLocked ? .sourceAtop : .normal)
        context.setAlpha(brushOpacity)
        context.draw(image, in: canvasRect)
        context.restoreGState()

        strokeBitmap.clear()
    }

    /// Replaces the freehand stroke with a straight line (QuickShape).
    func quickShape(from start: CGPoint, to end: CGPoint) {
        guard isStroking, !strokeErases, drawingContext != nil else { return }

        strokeBitmap.clear()
        lastDabPoint = nil
        strokeDistance = 0

        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = (dx * dx + dy * dy).squareRoot()
        let spacingPixels = max(0.75, brushSize * max(0.02, brushSpacing))
        let steps = max(1, Int((distance / spacingPixels).rounded(.up)))

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(x: start.x + dx * t, y: start.y + dy * t)
            strokeDistance += distance / CGFloat(steps)
            stamp(at: point, pressure: 0.85, tilt: .zero)
        }

        showToast("QuickShape: line")
    }

    private func applyGrain() {
        guard brushGrain > 0.01,
              let mask = BrushRenderer.grainMask(width: strokeBitmap.width,
                                                 height: strokeBitmap.height,
                                                 strength: brushGrain) else {
            return
        }

        let context = strokeBitmap.context
        context.saveGState()
        context.setBlendMode(.destinationIn)
        context.setAlpha(1)
        context.draw(mask, in: strokeBitmap.bounds)
        context.restoreGState()
    }

    private func stamp(at point: CGPoint, pressure: CGFloat, tilt: CGPoint) {
        guard let context = drawingContext else { return }

        let clamped = min(max(pressure, 0.01), 1.0)
        let curved = pow(clamped, 0.75 * max(0.2, pressureCurve))

        var taperFactor: CGFloat = 1
        if brushTaper > 0.001 {
            let taperLength = max(6, brushSize * 6) * brushTaper
            taperFactor = min(1, 0.18 + 0.82 * (strokeDistance / max(1, taperLength)))
        }

        let diameter = max(1.0, brushSize * (0.25 + 0.75 * curved) * taperFactor)
        let tiltMagnitude = min(1, (tilt.x * tilt.x + tilt.y * tilt.y).squareRoot())
        let tiltAngle = atan2(tilt.y, tilt.x)

        let dabColor = strokeErases ? NSColor.white : color
        guard let dab = BrushRenderer.dab(color: dabColor, hardness: brushHardness) else { return }

        context.setAlpha(strokeErases ? 1 : brushFlow)

        draw(dab: dab, at: point, diameter: diameter,
             angle: tiltAngle, magnitude: tiltMagnitude, in: context)

        if symmetry != .off {
            let width = canvasSize.width
            let height = canvasSize.height
            let mirroredX = CGPoint(x: width - point.x, y: point.y)
            let mirroredY = CGPoint(x: point.x, y: height - point.y)
            let mirroredXY = CGPoint(x: width - point.x, y: height - point.y)

            switch symmetry {
            case .off:
                break
            case .vertical:
                draw(dab: dab, at: mirroredX, diameter: diameter,
                     angle: .pi - tiltAngle, magnitude: tiltMagnitude, in: context)
            case .horizontal:
                draw(dab: dab, at: mirroredY, diameter: diameter,
                     angle: -tiltAngle, magnitude: tiltMagnitude, in: context)
            case .quadrant:
                draw(dab: dab, at: mirroredX, diameter: diameter,
                     angle: .pi - tiltAngle, magnitude: tiltMagnitude, in: context)
                draw(dab: dab, at: mirroredY, diameter: diameter,
                     angle: -tiltAngle, magnitude: tiltMagnitude, in: context)
                draw(dab: dab, at: mirroredXY, diameter: diameter,
                     angle: .pi + tiltAngle, magnitude: tiltMagnitude, in: context)
            }
        }

        lastDabPoint = point
    }

    private func draw(dab: CGImage, at point: CGPoint, diameter: CGFloat,
                      angle: CGFloat, magnitude: CGFloat, in context: CGContext) {
        if magnitude < 0.03 {
            let rect = CGRect(
                x: point.x - diameter / 2,
                y: point.y - diameter / 2,
                width: diameter,
                height: diameter
            )
            context.draw(dab, in: rect)
            return
        }

        let longSide = diameter * (1 + 0.8 * magnitude)
        let shortSide = max(1, diameter * (1 - 0.35 * magnitude))

        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)
        context.draw(dab, in: CGRect(x: -longSide / 2, y: -shortSide / 2,
                                     width: longSide, height: shortSide))
        context.restoreGState()
    }

    // MARK: Undo

    private func makeSnapshot() -> Snapshot {
        Snapshot(
            items: layers.map {
                Snapshot.Item(id: $0.id,
                              name: $0.name,
                              isVisible: $0.isVisible,
                              isLocked: $0.isLocked,
                              isAlphaLocked: $0.isAlphaLocked,
                              opacity: $0.opacity,
                              blendMode: $0.blendMode,
                              image: $0.bitmap.image)
            },
            activeLayerID: activeLayerID
        )
    }

    private func pushUndo() {
        undoStack.append(makeSnapshot())
        if undoStack.count > 24 {
            undoStack.removeFirst(undoStack.count - 24)
        }
        redoStack.removeAll()
        updateUndoFlags()
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(makeSnapshot())
        apply(snapshot)
        updateUndoFlags()
        revision += 1
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(makeSnapshot())
        apply(snapshot)
        updateUndoFlags()
        revision += 1
    }

    private func apply(_ snapshot: Snapshot) {
        var restored: [Layer] = []

        for item in snapshot.items {
            guard let bitmap = Bitmap(width: Int(canvasSize.width),
                                      height: Int(canvasSize.height)) else { continue }
            if let image = item.image {
                bitmap.draw(image)
            }
            restored.append(Layer(id: item.id,
                                  name: item.name,
                                  isVisible: item.isVisible,
                                  isLocked: item.isLocked,
                                  isAlphaLocked: item.isAlphaLocked,
                                  opacity: item.opacity,
                                  blendMode: item.blendMode,
                                  bitmap: bitmap))
        }

        guard !restored.isEmpty else { return }
        layers = restored
        activeLayerID = snapshot.activeLayerID ?? restored.first?.id
    }

    private func updateUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        historyPosition = undoStack.count
        historyLength = undoStack.count + redoStack.count
    }

    /// Jumps to an absolute position in the undo history (0 = oldest kept state).
    func jumpHistory(to position: Int) {
        let target = min(max(0, position), undoStack.count + redoStack.count)
        if target < undoStack.count {
            for _ in 0..<(undoStack.count - target) {
                guard canUndo else { break }
                undo()
            }
        } else if target > undoStack.count {
            for _ in 0..<(target - undoStack.count) {
                guard canRedo else { break }
                redo()
            }
        }
    }

    // MARK: Layers

    func addLayer() {
        guard let bitmap = makeBitmap() else { return }
        pushUndo()

        let layer = Layer(name: "Layer \(layers.count + 1)", bitmap: bitmap)
        let insertAt = activeLayerIndex.map { $0 + 1 } ?? layers.count
        layers.insert(layer, at: insertAt)
        activeLayerID = layer.id
        revision += 1
    }

    func duplicateActiveLayer() {
        guard let index = activeLayerIndex, let bitmap = makeBitmap() else { return }
        pushUndo()

        if let image = layers[index].bitmap.image {
            bitmap.draw(image)
        }

        let source = layers[index]
        let copy = Layer(name: source.name + " copy",
                         isVisible: source.isVisible,
                         isLocked: source.isLocked,
                         isAlphaLocked: source.isAlphaLocked,
                         opacity: source.opacity,
                         blendMode: source.blendMode,
                         bitmap: bitmap)

        layers.insert(copy, at: index + 1)
        activeLayerID = copy.id
        revision += 1
    }

    func deleteActiveLayer() {
        guard layers.count > 1, let index = activeLayerIndex else { return }
        guard !layers[index].isLocked else {
            showToast("Layer is locked")
            return
        }
        pushUndo()
        layers.remove(at: index)
        let next = max(0, min(index, layers.count - 1))
        activeLayerID = layers[next].id
        revision += 1
    }

    func mergeDown() {
        guard let index = activeLayerIndex, index > 0, let bitmap = makeBitmap() else { return }
        guard !layers[index].isLocked, !layers[index - 1].isLocked else {
            showToast("Layer is locked")
            return
        }
        pushUndo()

        let lower = layers[index - 1]
        let upper = layers[index]
        let context = bitmap.context

        if let image = lower.bitmap.image {
            context.setAlpha(lower.opacity)
            context.setBlendMode(.normal)
            context.draw(image, in: canvasRect)
        }

        if let image = upper.bitmap.image {
            context.setAlpha(upper.opacity)
            context.setBlendMode(upper.blendMode.cgBlendMode)
            context.draw(image, in: canvasRect)
        }

        layers[index - 1] = Layer(id: lower.id,
                                  name: lower.name,
                                  isVisible: true,
                                  isLocked: lower.isLocked,
                                  isAlphaLocked: lower.isAlphaLocked,
                                  opacity: 1,
                                  blendMode: .normal,
                                  bitmap: bitmap)
        layers.remove(at: index)
        activeLayerID = lower.id
        revision += 1
    }

    func flipActiveLayerHorizontally() {
        guard let index = activeLayerIndex, let bitmap = makeBitmap() else { return }
        guard !layers[index].isLocked else {
            showToast("Layer is locked")
            return
        }
        pushUndo()

        bitmap.context.translateBy(x: canvasSize.width, y: 0)
        bitmap.context.scaleBy(x: -1, y: 1)
        if let image = layers[index].bitmap.image {
            bitmap.context.draw(image, in: canvasRect)
        }

        let source = layers[index]
        layers[index] = Layer(id: source.id,
                              name: source.name,
                              isVisible: source.isVisible,
                              isLocked: source.isLocked,
                              isAlphaLocked: source.isAlphaLocked,
                              opacity: source.opacity,
                              blendMode: source.blendMode,
                              bitmap: bitmap)
        revision += 1
    }

    func clearActiveLayer() {
        guard let index = activeLayerIndex else { return }
        guard !layers[index].isLocked, !layers[index].isAlphaLocked else {
            showToast("Layer is locked")
            return
        }
        pushUndo()
        layers[index].bitmap.clear()
        revision += 1
    }

    func renameLayer(id: UUID, to newName: String) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != layers[index].name else { return }
        pushUndo()
        layers[index].name = trimmed
        revision += 1
    }

    func setLayerLocked(_ locked: Bool, id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].isLocked = locked
        revision += 1
    }

    func setLayerAlphaLocked(_ locked: Bool, id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].isAlphaLocked = locked
        revision += 1
    }

    func moveLayer(id: UUID, toIndex target: Int) {
        guard let from = layers.firstIndex(where: { $0.id == id }),
              layers.indices.contains(target),
              from != target else { return }
        pushUndo()
        let layer = layers.remove(at: from)
        let insert = min(max(0, target), layers.count)
        layers.insert(layer, at: insert)
        activeLayerID = layer.id
        revision += 1
    }

    func moveActiveLayer(up: Bool) {
        guard let index = activeLayerIndex else { return }
        let target = up ? index + 1 : index - 1
        guard layers.indices.contains(target) else { return }
        pushUndo()
        layers.swapAt(index, target)
        revision += 1
    }

    func setBlendMode(_ mode: LayerBlendMode, for index: Int) {
        guard layers.indices.contains(index) else { return }
        layers[index].blendMode = mode
        revision += 1
    }

    func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import image as new layer"

        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let bitmap = makeBitmap() else {
            return
        }

        pushUndo()

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let factor = min(canvasSize.width / imageWidth, canvasSize.height / imageHeight)
        let drawWidth = imageWidth * factor
        let drawHeight = imageHeight * factor
        let rect = CGRect(x: (canvasSize.width - drawWidth) / 2,
                          y: (canvasSize.height - drawHeight) / 2,
                          width: drawWidth,
                          height: drawHeight)

        bitmap.context.draw(cgImage, in: rect)

        let layer = Layer(name: url.deletingPathExtension().lastPathComponent, bitmap: bitmap)
        let insertAt = activeLayerIndex.map { $0 + 1 } ?? layers.count
        layers.insert(layer, at: insertAt)
        activeLayerID = layer.id
        revision += 1
        showToast("Imported \(url.lastPathComponent)")
    }

    private func makeBitmap() -> Bitmap? {
        Bitmap(width: Int(canvasSize.width), height: Int(canvasSize.height))
    }

    // MARK: Document lifecycle

    func newDocument(width: Int = 1600, height: Int = 1200) {
        let w = max(64, width)
        let h = max(64, height)

        guard let stroke = Bitmap(width: w, height: h),
              let layerBitmap = Bitmap(width: w, height: h) else { return }

        canvasSize = CGSize(width: w, height: h)
        strokeBitmap = stroke

        let layer = Layer(name: "Layer 1", bitmap: layerBitmap)
        layers = [layer]
        activeLayerID = layer.id

        undoStack.removeAll()
        redoStack.removeAll()
        isStroking = false
        drawingContext = nil
        lastDabPoint = nil
        documentURL = nil
        documentName = "Untitled"
        paperColor = .white
        recoveredAutosave = false
        clearAutosave()
        updateUndoFlags()
        suppressAutosave = true
        revision += 1
        hasUnsavedEdits = false
    }

    func flattenedImage(background: NSColor? = nil) -> CGImage? {
        guard let flat = makeBitmap() else { return nil }
        let context = flat.context

        if let background = background ?? paperColor as NSColor? {
            context.setFillColor(background.cgColor)
            context.fill(flat.bounds)
        }

        for layer in layers where layer.isVisible {
            guard let image = layer.bitmap.image else { continue }
            context.saveGState()
            context.setAlpha(CGFloat(layer.opacity))
            context.setBlendMode(layer.blendMode.cgBlendMode)
            context.draw(image, in: flat.bounds)
            context.restoreGState()
        }

        return flat.image
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case png
        case jpeg
        case tiff
        case pdf

        var id: String { rawValue }

        var title: String {
            switch self {
            case .png: return "PNG"
            case .jpeg: return "JPEG"
            case .tiff: return "TIFF"
            case .pdf: return "PDF"
            }
        }

        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .tiff: return "tiff"
            case .pdf: return "pdf"
            }
        }

        var contentType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .tiff: return .tiff
            case .pdf: return .pdf
            }
        }
    }

    /// Backwards-compatible entry point used by the toolbar.
    func exportPNG() {
        export(as: .png)
    }

    func export(as format: ExportFormat) {
        guard let image = flattenedImage() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = documentName + "." + format.fileExtension
        panel.canCreateDirectories = true
        panel.title = "Export artwork as \(format.title)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try exportData(image, as: format).write(to: url)
            showToast("Exported \(url.lastPathComponent)")
        } catch {
            showToast("Export failed: \(error.localizedDescription)")
        }
    }

    func exportData(_ image: CGImage, as format: ExportFormat) throws -> Data {
        switch format {
        case .png:
            guard let data = pngData(image) else { throw ProjectError.invalid }
            return data
        case .jpeg:
            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(using: .jpeg,
                                                properties: [.compressionFactor: 0.92]) else {
                throw ProjectError.invalid
            }
            return data
        case .tiff:
            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(using: .tiff, properties: [:]) else {
                throw ProjectError.invalid
            }
            return data
        case .pdf:
            let data = NSMutableData()
            guard let consumer = CGDataConsumer(data: data) else { throw ProjectError.invalid }
            var mediaBox = CGRect(origin: .zero, size: canvasSize)
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                throw ProjectError.invalid
            }
            context.beginPDFPage(nil)
            context.draw(image, in: mediaBox)
            context.endPDFPage()
            context.closePDF()
            return data as Data
        }
    }

    func showToast(_ message: String) {
        toast = message
        toastToken += 1
        let token = toastToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self, self.toastToken == token else { return }
            self.toast = nil
        }
    }

    // MARK: Project files

    func saveDocument() {
        if let url = documentURL {
            try? saveProject(to: url)
            return
        }
        saveDocumentAs()
    }

    func saveDocumentAs() {
        let panel = NSSavePanel()
        let type = UTType(filenameExtension: "abysspaint") ?? .data
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = documentName + ".abysspaint"
        panel.canCreateDirectories = true
        panel.title = "Save AbyssPaint project"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? saveProject(to: url)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        let type = UTType(filenameExtension: "abysspaint") ?? .data
        panel.allowedContentTypes = [type]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.title = "Open AbyssPaint project"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? openProject(from: url)
    }

    func saveProject(to url: URL) throws {
        try writeProject(to: url)

        documentURL = url
        documentName = url.deletingPathExtension().lastPathComponent
        recoveredAutosave = false
        hasUnsavedEdits = false
        clearAutosave()
        showToast("Saved \(documentName)")
    }

    private func writeProject(to url: URL) throws {
        let fm = FileManager.default
        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".abysspaint-\(UUID().uuidString)")

        try fm.createDirectory(at: temp, withIntermediateDirectories: true)

        var layerFiles: [ProjectFile.Layer] = []

        for (index, layer) in layers.enumerated() {
            let fileName = "layer-\(index).png"
            if let image = layer.bitmap.image, let data = pngData(image) {
                try data.write(to: temp.appendingPathComponent(fileName))
            }
            layerFiles.append(
                ProjectFile.Layer(name: layer.name,
                                  isVisible: layer.isVisible,
                                  isLocked: layer.isLocked,
                                  isAlphaLocked: layer.isAlphaLocked,
                                  opacity: layer.opacity,
                                  blendMode: layer.blendMode.rawValue,
                                  file: fileName)
            )
        }

        let project = ProjectFile(version: 2,
                                  width: Int(canvasSize.width),
                                  height: Int(canvasSize.height),
                                  activeIndex: activeLayerIndex ?? 0,
                                  paperColor: paperColor.abyssHex,
                                  layers: layerFiles)

        let data = try JSONEncoder().encode(project)
        try data.write(to: temp.appendingPathComponent("document.json"))

        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        try fm.moveItem(at: temp, to: url)
    }

    func openProject(from url: URL, restoring: Bool = false) throws {
        let data = try Data(contentsOf: url.appendingPathComponent("document.json"))
        let project = try JSONDecoder().decode(ProjectFile.self, from: data)

        guard let stroke = Bitmap(width: project.width, height: project.height) else {
            throw ProjectError.invalid
        }

        var newLayers: [Layer] = []

        for item in project.layers {
            guard let bitmap = Bitmap(width: project.width, height: project.height) else {
                continue
            }

            let fileURL = url.appendingPathComponent(item.file)
            if let image = NSImage(contentsOf: fileURL),
               let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                bitmap.draw(cgImage)
            }

            newLayers.append(
                Layer(name: item.name,
                      isVisible: item.isVisible,
                      isLocked: item.isLocked ?? false,
                      isAlphaLocked: item.isAlphaLocked ?? false,
                      opacity: item.opacity,
                      blendMode: LayerBlendMode(rawValue: item.blendMode) ?? .normal,
                      bitmap: bitmap)
            )
        }

        guard !newLayers.isEmpty else { throw ProjectError.invalid }

        canvasSize = CGSize(width: project.width, height: project.height)
        strokeBitmap = stroke
        layers = newLayers
        activeLayerID = newLayers[min(max(0, project.activeIndex), newLayers.count - 1)].id
        paperColor = project.paperColor.flatMap(NSColor.init(abyssHex:)) ?? .white

        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoFlags()

        if restoring {
            documentURL = nil
            documentName = "Recovered artwork"
            recoveredAutosave = true
            showToast("Recovered unsaved artwork")
        } else {
            documentURL = url
            documentName = url.deletingPathExtension().lastPathComponent
            recoveredAutosave = false
            clearAutosave()
            showToast("Opened \(documentName)")
        }

        suppressAutosave = true
        revision += 1
        hasUnsavedEdits = restoring
    }

    // MARK: Autosave & recovery

    static var autosaveURL: URL {
        if let override = ProcessInfo.processInfo.environment["ABYSS_AUTOSAVE_PATH"] {
            return URL(fileURLWithPath: override)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("AbyssPaint", isDirectory: true)
            .appendingPathComponent("Autosave.abysspaint", isDirectory: true)
    }

    var hasAutosave: Bool {
        FileManager.default.fileExists(atPath: Self.autosaveURL.path)
    }

    private func scheduleAutosave() {
        guard autosaveEnabled else { return }
        autosaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.writeAutosave() }
        autosaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func writeAutosave() {
        guard autosaveEnabled, hasUnsavedEdits else { return }
        let url = Self.autosaveURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try writeProject(to: url)
        } catch {
            // Autosave is best-effort; never interrupt the user's painting.
        }
    }

    func autosaveNow() {
        autosaveWorkItem?.cancel()
        autosaveWorkItem = nil
        writeAutosave()
    }

    @discardableResult
    func restoreAutosave() -> Bool {
        guard hasAutosave else { return false }
        do {
            try openProject(from: Self.autosaveURL, restoring: true)
            return true
        } catch {
            return false
        }
    }

    func clearAutosave() {
        autosaveWorkItem?.cancel()
        autosaveWorkItem = nil
        guard autosaveEnabled else { return }
        try? FileManager.default.removeItem(at: Self.autosaveURL)
    }

    private func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    enum ProjectError: Error {
        case invalid
    }
}

// MARK: - Project file

struct ProjectFile: Codable {
    struct Layer: Codable {
        var name: String
        var isVisible: Bool
        var isLocked: Bool?
        var isAlphaLocked: Bool?
        var opacity: Double
        var blendMode: String
        var file: String
    }

    var version: Int
    var width: Int
    var height: Int
    var activeIndex: Int
    var paperColor: String?
    var layers: [Layer]
}

extension NSColor {
    convenience init?(abyssHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                  green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255,
                  alpha: 1)
    }

    var abyssHex: String {
        let converted = usingColorSpace(.sRGB) ?? self
        return String(format: "%02X%02X%02X",
                      Int(round(converted.redComponent * 255)),
                      Int(round(converted.greenComponent * 255)),
                      Int(round(converted.blueComponent * 255)))
    }
}

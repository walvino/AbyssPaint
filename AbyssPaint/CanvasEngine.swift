import Foundation
import CoreData
import Metal
import MetalKit
import Combine

// MARK: - Canvas Engine
class CanvasEngine: ObservableObject {
    static let shared = CanvasEngine()
    
    @Published var currentCanvas: Canvas?
    @Published var currentLayer: Layer?
    @Published var layers: [Layer] = []
    @Published var brushes: [Brush] = []
    @Published var selectedBrush: Brush?
    @Published var currentColor: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 1)
    @Published var brushSize: Float = 50.0
    @Published var brushOpacity: Float = 1.0
    @Published var brushFlow: Float = 1.0
    @Published var zoom: Float = 1.0
    @Published var pan: SIMD2<Float> = SIMD2<Float>(0, 0)
    @Published var rotation: Float = 0.0
    @Published var isDrawing: Bool = false
    @Published var currentTool: Tool = .brush
    @Published var selection: SelectionRegion?
    @Published var transform: TransformState?
    @Published var showingAnimationTimeline: Bool = false
    @Published var showingReferenceWindow: Bool = false
    @Published var showingColorPicker: Bool = false
    @Published var showingBrushLibrary: Bool = false
    @Published var showingLayerPanel: Bool = true
    
    private var renderEngine: RenderEngine
    private var brushEngine: BrushEngine
    private var tabletInput: TabletInput
    private var fileIO: FileIO
    private var adjustmentEngine: AdjustmentEngine
    private var animationEngine: AnimationEngine
    private var preferences: Preferences
    private var undoManager: UndoManager
    private var currentStroke: Stroke?
    private var strokeHistory: [Stroke] = []
    private var redoStack: [Stroke] = []
    
    private init() {
        self.renderEngine = RenderEngine()
        self.brushEngine = BrushEngine()
        self.tabletInput = TabletInput()
        self.fileIO = FileIO()
        self.adjustmentEngine = AdjustmentEngine()
        self.animationEngine = AnimationEngine()
        self.preferences = Preferences.shared
        self.undoManager = UndoManager()
        self.undoManager.levelsOfUndo = 100
        
        setupNotifications()
        loadBuiltinBrushes()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewCanvas), name: .newCanvasRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenDocument), name: .openDocumentRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCanvasSize), name: .canvasSizeRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCropCanvas), name: .cropCanvasRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewLayer), name: .newLayerRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDuplicateLayer), name: .duplicateLayerRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMergeDown), name: .mergeDownRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewGroup), name: .newGroupRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAddMask), name: .addMaskRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleZoomIn), name: .zoomInRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleZoomOut), name: .zoomOutRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleActualSize), name: .actualSizeRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFitToScreen), name: .fitToScreenRequested, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleLayersPanel), name: .toggleLayersPanel, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleBrushesPanel), name: .toggleBrushesPanel, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleColorPanel), name: .toggleColorPanel, object: nil)
    }
    
    // MARK: - Canvas Management
    func createCanvas(name: String, width: Int, height: Int, dpi: Int = 300, colorProfile: ColorProfile = .sRGB) {
        let context = PersistenceController.shared.container.viewContext
        let canvas = Canvas.create(in: context, name: name, width: width, height: height, dpi: dpi, colorProfile: colorProfile)
        
        // Create background layer
        let bgLayer = Layer.create(in: context, name: "Background", type: .pixel, canvas: canvas, order: 0)
        bgLayer.locked = true
        
        // Create first drawing layer
        let layer1 = Layer.create(in: context, name: "Layer 1", type: .pixel, canvas: canvas, order: 1)
        
        do {
            try context.save()
            loadCanvas(canvas)
        } catch {
            print("Failed to create canvas: \(error)")
        }
    }
    
    func loadCanvas(_ canvas: Canvas) {
        currentCanvas = canvas
        currentLayer = canvas.layers?.toArray(ofType: Layer.self).sorted { $0.order < $1.order }.first
        layers = canvas.layers?.toArray(ofType: Layer.self).sorted { $0.order < $1.order } ?? []
        
        // Setup render engine
        renderEngine.setupCanvas(canvas)
        
        // Reset view
        zoom = 1.0
        pan = SIMD2<Float>(0, 0)
        rotation = 0.0
        
        // Clear history
        undoManager.removeAllActions()
        strokeHistory.removeAll()
        redoStack.removeAll()
        
        // Start time-lapse if enabled
        if canvas.timeLapseEnabled {
            startTimeLapseRecording()
        }
    }
    
    func saveCanvas() {
        guard let canvas = currentCanvas else { return }
        let context = PersistenceController.shared.container.viewContext
        canvas.modifiedAt = Date()
        
        do {
            try context.save()
        } catch {
            print("Failed to save canvas: \(error)")
        }
    }
    
    // MARK: - Layer Management
    func addLayer(name: String, type: LayerType = .pixel, above currentLayer: Layer? = nil) {
        guard let canvas = currentCanvas else { return }
        let context = PersistenceController.shared.container.viewContext
        
        var order: Int32 = 0
        if let current = currentLayer {
            order = current.order + 1
            // Shift layers above
            for layer in layers where layer.order >= order {
                layer.order += 1
            }
        } else {
            order = Int32(layers.count)
        }
        
        let layer = Layer.create(in: context, name: name, type: type, canvas: canvas, order: order)
        layers.append(layer)
        layers.sort { $0.order < $1.order }
        
        try? context.save()
        renderEngine.invalidateLayerCache()
        
        // Register undo
        undoManager.registerUndo(withTarget: self) { _ in
            self.deleteLayer(layer)
        }
    }
    
    func deleteLayer(_ layer: Layer) {
        guard let canvas = currentCanvas else { return }
        let context = PersistenceController.shared.container.viewContext
        
        // Remove from render engine
        renderEngine.removeLayer(layer.id)
        
        // Delete from Core Data
        context.delete(layer)
        
        // Update order
        for l in layers where l.order > layer.order {
            l.order -= 1
        }
        
        layers.removeAll { $0.id == layer.id }
        
        if currentLayer?.id == layer.id {
            currentLayer = layers.last
        }
        
        try? context.save()
        renderEngine.invalidateLayerCache()
    }
    
    func duplicateLayer(_ layer: Layer) {
        guard let canvas = currentCanvas else { return }
        let context = PersistenceController.shared.container.viewContext
        
        let newOrder = layer.order + 1
        for l in layers where l.order >= newOrder {
            l.order += 1
        }
        
        let newLayer = Layer.create(in: context, name: "\(layer.name) copy", type: layer.layerType, canvas: canvas, order: newOrder)
        newLayer.opacity = layer.opacity
        newLayer.blendMode = layer.blendMode
        newLayer.visible = layer.visible
        newLayer.locked = layer.locked
        newLayer.alphaLocked = layer.alphaLocked
        
        // Copy mask if exists
        if let maskData = layer.maskData {
            newLayer.maskData = maskData
        }
        
        layers.append(newLayer)
        layers.sort { $0.order < $1.order }
        
        try? context.save()
        renderEngine.duplicateLayerTexture(layer.id, to: newLayer.id)
    }
    
    func mergeDown(_ layer: Layer) {
        guard let canvas = currentCanvas,
              let index = layers.firstIndex(where: { $0.id == layer.id }),
              index > 0 else { return }
        
        let belowLayer = layers[index - 1]
        
        // Render merge in GPU
        renderEngine.mergeLayer(layer.id, into: belowLayer.id)
        
        // Remove merged layer
        deleteLayer(layer)
    }
    
    func moveLayer(_ layer: Layer, to newIndex: Int) {
        let oldIndex = layers.firstIndex(where: { $0.id == layer.id }) ?? 0
        guard oldIndex != newIndex, newIndex >= 0, newIndex < layers.count else { return }
        
        layers.remove(at: oldIndex)
        layers.insert(layer, at: newIndex)
        
        // Update orders
        for (i, l) in layers.enumerated() {
            l.order = Int32(i)
        }
        
        try? PersistenceController.shared.container.viewContext.save()
        renderEngine.invalidateLayerCache()
    }
    
    // MARK: - Drawing
    func beginStroke(at point: CGPoint, pressure: Float, tilt: SIMD2<Float>, azimuth: Float) {
        guard let canvas = currentCanvas,
              let layer = currentLayer,
              let brush = selectedBrush else { return }
        
        isDrawing = true
        
        let canvasPoint = viewToCanvas(point)
        let strokePoint = StrokePoint(
            position: canvasPoint,
            pressure: pressure,
            tilt: tilt,
            azimuth: azimuth,
            timestamp: Date().timeIntervalSinceReferenceDate,
            velocity: 0
        )
        
        currentStroke = Stroke(
            brushID: brush.id,
            layerID: layer.id,
            color: currentColor,
            blendMode: layer.blendModeEnum
        )
        currentStroke?.addPoint(strokePoint)
        
        // Record for time-lapse
        if canvas.timeLapseEnabled {
            recordTimeLapsePoint(strokePoint)
        }
    }
    
    func continueStroke(to point: CGPoint, pressure: Float, tilt: SIMD2<Float>, azimuth: Float) {
        guard var stroke = currentStroke else { return }
        
        let canvasPoint = viewToCanvas(point)
        let lastPoint = stroke.points.last!
        
        // Calculate velocity
        let distance = length(canvasPoint - lastPoint.position)
        let timeDelta = Date().timeIntervalSinceReferenceDate - lastPoint.timestamp
        let velocity = Float(distance) / Float(max(timeDelta, 0.001))
        
        let strokePoint = StrokePoint(
            position: canvasPoint,
            pressure: pressure,
            tilt: tilt,
            azimuth: azimuth,
            timestamp: Date().timeIntervalSinceReferenceDate,
            velocity: velocity
        )
        
        stroke.addPoint(strokePoint)
        currentStroke = stroke
        
        // Render stroke segment in real-time
        if stroke.points.count >= 2 {
            let segment = StrokeSegment(
                startPoint: stroke.points[stroke.points.count - 2],
                endPoint: strokePoint,
                stamps: []
            )
            brushEngine.generateStamps(for: segment, brush: selectedBrush!)
            renderEngine.drawStrokeSegment(segment, onLayer: stroke.layerID, withBrush: selectedBrush!, color: currentColor)
        }
        
        if canvas?.timeLapseEnabled == true {
            recordTimeLapsePoint(strokePoint)
        }
    }
    
    func endStroke(at point: CGPoint, pressure: Float, tilt: SIMD2<Float>, azimuth: Float) {
        guard var stroke = currentStroke else { return }
        
        let canvasPoint = viewToCanvas(point)
        let lastPoint = stroke.points.last!
        
        let distance = length(canvasPoint - lastPoint.position)
        let timeDelta = Date().timeIntervalSinceReferenceDate - lastPoint.timestamp
        let velocity = Float(distance) / Float(max(timeDelta, 0.001))
        
        let strokePoint = StrokePoint(
            position: canvasPoint,
            pressure: pressure,
            tilt: tilt,
            azimuth: azimuth,
            timestamp: Date().timeIntervalSinceReferenceDate,
            velocity: velocity
        )
        
        stroke.addPoint(strokePoint)
        stroke.finish()
        
        currentStroke = nil
        isDrawing = false
        
        // Add to history
        strokeHistory.append(stroke)
        redoStack.removeAll()
        
        // Register undo
        undoManager.registerUndo(withTarget: self) { _ in
            self.undoStroke()
        }
        
        // Save to time-lapse
        if let canvas = currentCanvas, canvas.timeLapseEnabled {
            saveTimeLapseStroke(stroke)
        }
        
        // Auto-save periodically
        if strokeHistory.count % 10 == 0 {
            saveCanvas()
        }
    }
    
    func cancelStroke() {
        currentStroke = nil
        isDrawing = false
    }
    
    private func undoStroke() {
        guard let stroke = strokeHistory.popLast() else { return }
        redoStack.append(stroke)
        
        // Remove stroke from layer texture
        renderEngine.removeStroke(stroke.id, fromLayer: stroke.layerID)
    }
    
    func redoStroke() {
        guard let stroke = redoStack.popLast() else { return }
        strokeHistory.append(stroke)
        
        // Re-render stroke
        renderEngine.redrawStroke(stroke, withBrush: brushEngine.brush(withID: stroke.brushID)!, color: stroke.color)
        
        undoManager.registerUndo(withTarget: self) { _ in
            self.undoStroke()
        }
    }
    
    // MARK: - Coordinate Conversion
    func viewToCanvas(_ point: CGPoint) -> SIMD2<Float> {
        let canvasSize = SIMD2<Float>(Float(currentCanvas?.width ?? 1000), Float(currentCanvas?.height ?? 1000))
        let viewSize = SIMD2<Float>(800, 600) // Would come from actual view
        
        let scaledPoint = SIMD2<Float>(Float(point.x), Float(point.y)) - pan
        let rotatedPoint = rotatePoint(scaledPoint, angle: -rotation)
        let canvasPoint = rotatedPoint / zoom
        
        return canvasPoint
    }
    
    func canvasToView(_ point: SIMD2<Float>) -> CGPoint {
        let rotatedPoint = rotatePoint(point * zoom, angle: rotation)
        let viewPoint = rotatedPoint + pan
        return CGPoint(x: CGFloat(viewPoint.x), y: CGFloat(viewPoint.y))
    }
    
    private func rotatePoint(_ point: SIMD2<Float>, angle: Float) -> SIMD2<Float> {
        let c = cos(angle)
        let s = sin(angle)
        return SIMD2<Float>(point.x * c - point.y * s, point.x * s + point.y * c)
    }
    
    // MARK: - View Controls
    func zoomIn() {
        zoom = min(zoom * 1.2, 16.0)
    }
    
    func zoomOut() {
        zoom = max(zoom / 1.2, 0.125)
    }
    
    func setZoom(_ newZoom: Float, at center: CGPoint? = nil) {
        zoom = clamp(newZoom, 0.125, 16.0)
    }
    
    func panBy(_ delta: SIMD2<Float>) {
        pan += delta
    }
    
    func rotateBy(_ angle: Float) {
        rotation += angle
    }
    
    func resetView() {
        zoom = 1.0
        pan = SIMD2<Float>(0, 0)
        rotation = 0.0
    }
    
    func fitToScreen(viewSize: CGSize) {
        guard let canvas = currentCanvas else { return }
        let canvasSize = SIMD2<Float>(Float(canvas.width), Float(canvas.height))
        let viewSizeF = SIMD2<Float>(Float(viewSize.width), Float(viewSize.height))
        
        let scaleX = viewSizeF.x / canvasSize.x * 0.9
        let scaleY = viewSizeF.y / canvasSize.y * 0.9
        zoom = min(scaleX, scaleY)
        pan = SIMD2<Float>(0, 0)
    }
    
    private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
    
    // MARK: - Selection
    func setSelection(_ selection: SelectionRegion?) {
        self.selection = selection
        renderEngine.updateSelection(selection)
    }
    
    func clearSelection() {
        selection = nil
        renderEngine.updateSelection(nil)
    }
    
    // MARK: - Transform
    func beginTransform(layerID: UUID, mode: TransformMode) {
        transform = TransformState(layerID: layerID, mode: mode)
    }
    
    func updateTransform(_ transform: TransformState) {
        self.transform = transform
        renderEngine.updateTransform(transform)
    }
    
    func commitTransform() {
        guard var t = transform else { return }
        t.isActive = false
        renderEngine.commitTransform(t)
        self.transform = nil
    }
    
    func cancelTransform() {
        transform = nil
        renderEngine.cancelTransform()
    }
    
    // MARK: - Time Lapse
    private func startTimeLapseRecording() {
        // Initialize time-lapse recording
    }
    
    private func recordTimeLapsePoint(_ point: StrokePoint) {
        // Record point for time-lapse
    }
    
    private func saveTimeLapseStroke(_ stroke: Stroke) {
        // Save stroke to time-lapse data
    }
    
    func exportTimeLapse() -> URL? {
        // Export time-lapse video
        return nil
    }
    
    // MARK: - Export
    func exportCanvas(format: ExportFormat, options: ExportOptions = ExportOptions()) -> Data? {
        return fileIO.exportCanvas(currentCanvas!, format: format, options: options)
    }
    
    // MARK: - Notifications
    @objc private func handleNewCanvas() {
        // Show new canvas dialog
    }
    
    @objc private func handleOpenDocument() {
        // Show open dialog
    }
    
    @objc private func handleCanvasSize() {
        // Show canvas size dialog
    }
    
    @objc private func handleCropCanvas() {
        // Show crop dialog
    }
    
    @objc private func handleNewLayer() {
        addLayer(name: "New Layer")
    }
    
    @objc private func handleDuplicateLayer() {
        if let layer = currentLayer {
            duplicateLayer(layer)
        }
    }
    
    @objc private func handleMergeDown() {
        if let layer = currentLayer {
            mergeDown(layer)
        }
    }
    
    @objc private func handleNewGroup() {
        addLayer(name: "New Group", type: .group)
    }
    
    @objc private func handleAddMask() {
        if let layer = currentLayer {
            addMask(to: layer)
        }
    }
    
    func addMask(to layer: Layer) {
        // Add layer mask
        renderEngine.addMask(to: layer.id)
    }
    
    @objc private func handleZoomIn() { zoomIn() }
    @objc private func handleZoomOut() { zoomOut() }
    @objc private func handleActualSize() { setZoom(1.0) }
    @objc private func handleFitToScreen() { /* Will be called with view size */ }
    
    @objc private func handleToggleLayersPanel() {
        showingLayerPanel.toggle()
    }
    
    @objc private func handleToggleBrushesPanel() {
        showingBrushLibrary.toggle()
    }
    
    @objc private func handleToggleColorPanel() {
        showingColorPicker.toggle()
    }
    
    // MARK: - Built-in Brushes
    private func loadBuiltinBrushes() {
        brushes = BrushLibrary.shared.allBrushes()
        selectedBrush = brushes.first
    }
}

// MARK: - Tool Enum
enum Tool {
    case brush
    case eraser
    case smudge
    case selection
    case transform
    case eyedropper
    case fill
    case text
    case gradient
    case blur
    case sharpen
    case clone
}

// MARK: - Selection Region
struct SelectionRegion {
    var type: SelectionType
    var path: [SIMD2<Float>]
    var feather: Float
    var inverted: Bool
    var bounds: (min: SIMD2<Float>, max: SIMD2<Float>)
}

// MARK: - Transform State
struct TransformState {
    var layerID: UUID
    var mode: TransformMode
    var transform: simd_float3x3 = simd_float3x3(diagonal: SIMD3<Float>(1, 1, 1))
    var warpMesh: [SIMD2<Float>] = []
    var isActive: Bool = true
    var originalBounds: (min: SIMD2<Float>, max: SIMD2<Float>)?
}

enum TransformMode {
    case freeform
    case uniform
    case distort
    case warp
    case perspective
}

// MARK: - Export Options
struct ExportOptions {
    var includeLayers: Bool = true
    var quality: Float = 1.0
    var dpi: Int = 300
    var colorProfile: ColorProfile = .sRGB
    var transparentBackground: Bool = false
    var exportArea: ExportArea = .fullCanvas
}

enum ExportArea {
    case fullCanvas
    case selection
    case cropBounds
    case layerBounds(UUID)
}
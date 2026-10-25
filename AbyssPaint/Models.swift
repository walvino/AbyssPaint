import CoreData
import Foundation

// MARK: - Canvas
@objc(Canvas)
public class Canvas: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var width: Int32
    @NSManaged public var height: Int32
    @NSManaged public var dpi: Int32
    @NSManaged public var colorProfile: Int16
    @NSManaged public var backgroundColor: Int32
    @NSManaged public var timeLapseEnabled: Bool
    @NSManaged public var timeLapseQuality: Int16
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date
    @NSManaged public var animationEnabled: Bool
    @NSManaged public var animationMode: Int16
    @NSManaged public var drawingGuideType: Int16
    @NSManaged public var drawingGuideData: Data?
    @NSManaged public var referenceImages: Data?
    @NSManaged public var layers: NSSet?
    @NSManaged public var animationFrames: NSSet?
    @NSManaged public var referenceImagesRel: NSSet?
    @NSManaged public var selections: NSSet?
    @NSManaged public var adjustments: NSSet?
    @NSManaged public var timeLapse: TimeLapse?
    @NSManaged public var exportJobs: NSSet?
    
    public var colorProfileEnum: ColorProfile {
        get { ColorProfile(rawValue: colorProfile) ?? .sRGB }
        set { colorProfile = newValue.rawValue }
    }
    
    public var animationModeEnum: AnimationMode {
        get { AnimationMode(rawValue: animationMode) ?? .loop }
        set { animationMode = newValue.rawValue }
    }
    
    public var drawingGuideTypeEnum: DrawingGuideType {
        get { DrawingGuideType(rawValue: drawingGuideType) ?? .none }
        set { drawingGuideType = newValue.rawValue }
    }
}

extension Canvas {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Canvas> {
        return NSFetchRequest<Canvas>(entityName: "Canvas")
    }
    
    static func create(in context: NSManagedObjectContext, name: String, width: Int, height: Int, dpi: Int = 300, colorProfile: ColorProfile = .sRGB) -> Canvas {
        let canvas = Canvas(context: context)
        canvas.id = UUID()
        canvas.name = name
        canvas.width = Int32(width)
        canvas.height = Int32(height)
        canvas.dpi = Int32(dpi)
        canvas.colorProfile = colorProfile.rawValue
        canvas.backgroundColor = 0xFFFFFFFF
        canvas.timeLapseEnabled = true
        canvas.timeLapseQuality = 1
        canvas.createdAt = Date()
        canvas.modifiedAt = Date()
        canvas.animationEnabled = false
        canvas.animationMode = AnimationMode.loop.rawValue
        canvas.drawingGuideType = DrawingGuideType.none.rawValue
        return canvas
    }
}

// MARK: - Layer
@objc(Layer)
public class Layer: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var type: Int16
    @NSManaged public var blendMode: Int16
    @NSManaged public var opacity: Double
    @NSManaged public var visible: Bool
    @NSManaged public var locked: Bool
    @NSManaged public var alphaLocked: Bool
    @NSManaged public var maskData: Data?
    @NSManaged public var transformData: Data?
    @NSManaged public var filters: Data?
    @NSManaged public var order: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var canvas: Canvas?
    @NSManaged public var parent: Layer?
    @NSManaged public var children: NSSet?
    @NSManaged public var clippingTo: Layer?
    @NSManaged public var clippedLayers: NSSet?
    @NSManaged public var animationFrames: NSSet?
    @NSManaged public var adjustments: NSSet?
    
    public var layerType: LayerType {
        get { LayerType(rawValue: type) ?? .pixel }
        set { type = newValue.rawValue }
    }
    
    public var blendModeEnum: BlendMode {
        get { BlendMode(rawValue: blendMode) ?? .normal }
        set { blendMode = newValue.rawValue }
    }
}

extension Layer {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Layer> {
        return NSFetchRequest<Layer>(entityName: "Layer")
    }
    
    static func create(in context: NSManagedObjectContext, name: String, type: LayerType = .pixel, canvas: Canvas, parent: Layer? = nil, order: Int32 = 0) -> Layer {
        let layer = Layer(context: context)
        layer.id = UUID()
        layer.name = name
        layer.type = type.rawValue
        layer.blendMode = BlendMode.normal.rawValue
        layer.opacity = 1.0
        layer.visible = true
        layer.locked = false
        layer.alphaLocked = false
        layer.order = order
        layer.createdAt = Date()
        layer.canvas = canvas
        layer.parent = parent
        return layer
    }
}

// MARK: - Brush
@objc(Brush)
public class Brush: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var source: Int16
    @NSManaged public var strokeData: Data
    @NSManaged public var taperData: Data
    @NSManaged public var shapeData: Data
    @NSManaged public var grainData: Data
    @NSManaged public var renderingData: Data
    @NSManaged public var wetMixData: Data?
    @NSManaged public var colorDynamicsData: Data?
    @NSManaged public var dynamicsData: Data?
    @NSManaged public var applePencilData: Data?
    @NSManaged public var propertiesData: Data
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var brushSet: BrushSet?
    
    public var sourceEnum: BrushSource {
        get { BrushSource(rawValue: source) ?? .builtin }
        set { source = newValue.rawValue }
    }
}

extension Brush {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Brush> {
        return NSFetchRequest<Brush>(entityName: "Brush")
    }
}

// MARK: - BrushSet
@objc(BrushSet)
public class BrushSet: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var source: Int16
    @NSManaged public var order: Int32
    @NSManaged public var brushes: NSSet?
    
    public var sourceEnum: BrushSource {
        get { BrushSource(rawValue: source) ?? .builtin }
        set { source = newValue.rawValue }
    }
}

extension BrushSet {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BrushSet> {
        return NSFetchRequest<BrushSet>(entityName: "BrushSet")
    }
}

// MARK: - ColorPalette
@objc(ColorPalette)
public class ColorPalette: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var source: Int16
    @NSManaged public var swatches: NSSet?
    
    public var sourceEnum: PaletteSource {
        get { PaletteSource(rawValue: source) ?? .manual }
        set { source = newValue.rawValue }
    }
}

extension ColorPalette {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ColorPalette> {
        return NSFetchRequest<ColorPalette>(entityName: "ColorPalette")
    }
}

// MARK: - Swatch
@objc(Swatch)
public class Swatch: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var color: Int32
    @NSManaged public var position: Int32
    @NSManaged public var name: String?
    @NSManaged public var palette: ColorPalette?
}

extension Swatch {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Swatch> {
        return NSFetchRequest<Swatch>(entityName: "Swatch")
    }
}

// MARK: - AnimationFrame
@objc(AnimationFrame)
public class AnimationFrame: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var frameIndex: Int32
    @NSManaged public var holdDuration: Int32
    @NSManaged public var canvas: Canvas?
    @NSManaged public var layer: Layer?
}

extension AnimationFrame {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AnimationFrame> {
        return NSFetchRequest<AnimationFrame>(entityName: "AnimationFrame")
    }
}

// MARK: - Adjustment
@objc(Adjustment)
public class Adjustment: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var type: Int16
    @NSManaged public var parameters: Data
    @NSManaged public var enabled: Bool
    @NSManaged public var order: Int32
    @NSManaged public var canvas: Canvas?
    @NSManaged public var layer: Layer?
    
    public var adjustmentType: AdjustmentType {
        get { AdjustmentType(rawValue: type) ?? .opacity }
        set { type = newValue.rawValue }
    }
}

extension Adjustment {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Adjustment> {
        return NSFetchRequest<Adjustment>(entityName: "Adjustment")
    }
}

// MARK: - Selection
@objc(Selection)
public class Selection: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var type: Int16
    @NSManaged public var pathData: Data
    @NSManaged public var feather: Double
    @NSManaged public var inverted: Bool
    @NSManaged public var canvas: Canvas?
    
    public var selectionType: SelectionType {
        get { SelectionType(rawValue: type) ?? .freehand }
        set { type = newValue.rawValue }
    }
}

extension Selection {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Selection> {
        return NSFetchRequest<Selection>(entityName: "Selection")
    }
}

// MARK: - ReferenceImage
@objc(ReferenceImage)
public class ReferenceImage: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var source: Int16
    @NSManaged public var imageData: Data
    @NSManaged public var positionData: Data
    @NSManaged public var visible: Bool
    @NSManaged public var canvas: Canvas?
    
    public var sourceEnum: ReferenceSource {
        get { ReferenceSource(rawValue: source) ?? .library }
        set { source = newValue.rawValue }
    }
}

extension ReferenceImage {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReferenceImage> {
        return NSFetchRequest<ReferenceImage>(entityName: "ReferenceImage")
    }
}

// MARK: - UserPreferences
@objc(UserPreferences)
public class UserPreferences: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var gestureMappings: Data?
    @NSManaged public var pressureCurve: Data?
    @NSManaged public var quickMenuProfiles: Data?
    @NSManaged public var brushCursor: Int16
    @NSManaged public var theme: Int16
    @NSManaged public var leftHanded: Bool
    @NSManaged public var defaultExportFormat: Int16
    @NSManaged public var autoSaveInterval: Int32
}

extension UserPreferences {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserPreferences> {
        return NSFetchRequest<UserPreferences>(entityName: "UserPreferences")
    }
    
    static func defaultPreferences(in context: NSManagedObjectContext) -> UserPreferences {
        let prefs = UserPreferences(context: context)
        prefs.id = UUID()
        prefs.brushCursor = 0
        prefs.theme = 0
        prefs.leftHanded = false
        prefs.defaultExportFormat = 0
        prefs.autoSaveInterval = 30
        return prefs
    }
}

// MARK: - ExportJob
@objc(ExportJob)
public class ExportJob: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var format: Int16
    @NSManaged public var options: Data
    @NSManaged public var status: Int16
    @NSManaged public var outputPath: String?
    @NSManaged public var error: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var canvas: Canvas?
    
    public var exportFormat: ExportFormat {
        get { ExportFormat(rawValue: format) ?? .png }
        set { format = newValue.rawValue }
    }
    
    public var exportStatus: ExportStatus {
        get { ExportStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }
}

extension ExportJob {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExportJob> {
        return NSFetchRequest<ExportJob>(entityName: "ExportJob")
    }
}

// MARK: - TimeLapse
@objc(TimeLapse)
public class TimeLapse: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var recording: Bool
    @NSManaged public var quality: Int16
    @NSManaged public var framesData: Data?
    @NSManaged public var purgedAt: Date?
    @NSManaged public var canvas: Canvas?
    
    public var qualityEnum: TimeLapseQuality {
        get { TimeLapseQuality(rawValue: quality) ?? .hd1080 }
        set { quality = newValue.rawValue }
    }
}

extension TimeLapse {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TimeLapse> {
        return NSFetchRequest<TimeLapse>(entityName: "TimeLapse")
    }
}

// MARK: - Enums
public enum ColorProfile: Int16, CaseIterable {
    case sRGB = 0
    case p3 = 1
    case cmyk = 2
}

public enum AnimationMode: Int16, CaseIterable {
    case loop = 0
    case pingPong = 1
    case oneShot = 2
}

public enum DrawingGuideType: Int16, CaseIterable {
    case none = 0
    case grid2D = 1
    case isometric = 2
    case perspective = 3
    case symmetryVertical = 4
    case symmetryHorizontal = 5
    case symmetryQuadrant = 6
    case symmetryRadial = 7
}

public enum LayerType: Int16, CaseIterable {
    case pixel = 0
    case group = 1
    case mask = 2
    case clipping = 3
    case reference = 4
}

public enum BlendMode: Int16, CaseIterable {
    case normal = 0
    case multiply = 1
    case screen = 2
    case overlay = 3
    case softLight = 4
    case hardLight = 5
    case colorDodge = 6
    case colorBurn = 7
    case darken = 8
    case lighten = 9
    case difference = 10
    case exclusion = 11
    case hue = 12
    case saturation = 13
    case color = 14
    case luminosity = 15
    case linearBurn = 16
    case linearDodge = 17
    case vividLight = 18
    case linearLight = 19
    case pinLight = 20
    case hardMix = 21
    case subtract = 22
    case divide = 23
    case darkerColor = 24
    case lighterColor = 25
}

public enum BrushSource: Int16, CaseIterable {
    case builtin = 0
    case imported = 1
    case custom = 2
}

public enum PaletteSource: Int16, CaseIterable {
    case manual = 0
    case photo = 1
    case file = 2
}

public enum SelectionType: Int16, CaseIterable {
    case automatic = 0
    case freehand = 1
    case rectangle = 2
    case ellipse = 3
    case polygon = 4
}

public enum ReferenceSource: Int16, CaseIterable {
    case library = 0
    case photo = 1
    case file = 2
}

public enum AdjustmentType: Int16, CaseIterable {
    case opacity = 0
    case gaussianBlur = 1
    case motionBlur = 2
    case perspectiveBlur = 3
    case sharpen = 4
    case noise = 5
    case liquify = 6
    case clone = 7
    case bloom = 8
    case glitch = 9
    case halftone = 10
    case chromaticAberration = 11
    case colorBalance = 12
    case curves = 13
    case gradientMap = 14
    case hueSaturationBrightness = 15
    case colorBalance2 = 16
    case recolor = 17
}

public enum ExportFormat: Int16, CaseIterable {
    case abyssPaint = 0
    case psd = 1
    case pdf = 2
    case jpeg = 3
    case png = 4
    case tiff = 5
    case heif = 6
    case gif = 7
    case mp4 = 8
    case hevc = 9
}

public enum ExportStatus: Int16, CaseIterable {
    case pending = 0
    case running = 1
    case done = 2
    case error = 3
}

public enum TimeLapseQuality: Int16, CaseIterable {
    case hd1080 = 0
    case uhd4k = 1
}

// MARK: - Helper Extensions
extension NSSet {
    func toArray<T>(ofType: T.Type) -> [T] {
        return self.compactMap { $0 as? T }
    }
}
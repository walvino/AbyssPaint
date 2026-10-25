import Foundation
import SwiftUI
import Combine

// MARK: - Preferences
class Preferences: ObservableObject {
    static let shared = Preferences()
    
    // General
    @Published var theme: AppTheme = .dark {
        didSet { save() }
    }
    
    @Published var language: String = "en" {
        didSet { save() }
    }
    
    @Published var autoSaveInterval: Int = 30 { // seconds
        didSet { save() }
    }
    
    @Published var showTouchPoints: Bool = false {
        didSet { save() }
    }
    
    // Canvas
    @Published var defaultCanvasWidth: Int = 3000 {
        didSet { save() }
    }
    
    @Published var defaultCanvasHeight: Int = 2000 {
        didSet { save() }
    }
    
    @Published var defaultDPI: Int = 300 {
        didSet { save() }
    }
    
    @Published var defaultColorProfile: ColorProfile = .sRGB {
        didSet { save() }
    }
    
    @Published var canvasBackgroundColor: Color = .white {
        didSet { save() }
    }
    
    // Interface
    @Published var leftHandedMode: Bool = false {
        didSet { save() }
    }
    
    @Published var brushCursorType: BrushCursorType = .outline {
        didSet { save() }
    }
    
    @Published var showCursorPreview: Bool = true {
        didSet { save() }
    }
    
    @Published var interfaceScale: Float = 1.0 {
        didSet { save() }
    }
    
    @Published var showScrollbars: Bool = true {
        didSet { save() }
    }
    
    // Gestures
    @Published var gestureMappings: [String: GestureAction] = [:] {
        didSet { save() }
    }
    
    @Published var enableTouchGestures: Bool = true {
        didSet { save() }
    }
    
    @Published var twoFingerTapAction: GestureAction = .undo {
        didSet { save() }
    }
    
    @Published var threeFingerTapAction: GestureAction = .redo {
        didSet { save() }
    }
    
    @Published var fourFingerTapAction: GestureAction = .toggleInterface {
        didSet { save() }
    }
    
    // Pressure & Smoothing
    @Published var pressureCurve: PressureCurve = .default {
        didSet { save() }
    }
    
    @Published var strokeSmoothing: Float = 0.5 {
        didSet { save() }
    }
    
    @Published var motionFiltering: Float = 0.0 {
        didSet { save() }
    }
    
    @Published var taperLength: Float = 0.5 {
        didSet { save() }
    }
    
    // QuickMenu
    @Published var quickMenuProfile: Int = 0 {
        didSet { save() }
    }
    
    @Published var quickMenuSlots: [[QuickMenuSlot]] = [
        Array(repeating: QuickMenuSlot(), count: 6), // Profile 1
        Array(repeating: QuickMenuSlot(), count: 6), // Profile 2
        Array(repeating: QuickMenuSlot(), count: 6), // Profile 3
        Array(repeating: QuickMenuSlot(), count: 6)  // Profile 4
    ] {
        didSet { save() }
    }
    
    // Tablet
    @Published var tabletButtonMappings: [Int: TabletAction] = [:] {
        didSet { save() }
    }
    
    @Published var useWindowsInk: Bool = false {
        didSet { save() }
    }
    
    @Published var tabletPressureSensitivity: Float = 1.0 {
        didSet { save() }
    }
    
    // Performance
    @Published var maxUndoSteps: Int = 100 {
        didSet { save() }
    }
    
    @Published var tileCacheSize: Int = 512 { // MB
        didSet { save() }
    }
    
    @Published var enableMetalValidation: Bool = false {
        didSet { save() }
    }
    
    @Published var useLowMemoryMode: Bool = false {
        didSet { save() }
    }
    
    // Export
    @Published var defaultExportFormat: ExportFormat = .png {
        didSet { save() }
    }
    
    @Published var exportQuality: Float = 1.0 {
        didSet { save() }
    }
    
    @Published var includeMetadata: Bool = true {
        didSet { save() }
    }
    
    @Published var defaultExportDPI: Int = 300 {
        didSet { save() }
    }
    
    @Published var exportColorProfile: ColorProfile = .sRGB {
        didSet { save() }
    }
    
    // Advanced
    @Published var enableExperimentalFeatures: Bool = false {
        didSet { save() }
    }
    
    @Published var showDebugOverlay: Bool = false {
        didSet { save() }
    }
    
    @Published var logLevel: LogLevel = .info {
        didSet { save() }
    }
    
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        load()
    }
    
    func load() {
        // General
        theme = AppTheme(rawValue: defaults.string(forKey: "theme") ?? "dark") ?? .dark
        language = defaults.string(forKey: "language") ?? "en"
        autoSaveInterval = defaults.integer(forKey: "autoSaveInterval") == 0 ? 30 : defaults.integer(forKey: "autoSaveInterval")
        showTouchPoints = defaults.bool(forKey: "showTouchPoints")
        
        // Canvas
        defaultCanvasWidth = defaults.integer(forKey: "defaultCanvasWidth") == 0 ? 3000 : defaults.integer(forKey: "defaultCanvasWidth")
        defaultCanvasHeight = defaults.integer(forKey: "defaultCanvasHeight") == 0 ? 2000 : defaults.integer(forKey: "defaultCanvasHeight")
        defaultDPI = defaults.integer(forKey: "defaultDPI") == 0 ? 300 : defaults.integer(forKey: "defaultDPI")
        defaultColorProfile = ColorProfile(rawValue: Int16(defaults.integer(forKey: "defaultColorProfile"))) ?? .sRGB
        if let colorData = defaults.data(forKey: "canvasBackgroundColor"),
           let color = try? decoder.decode(Color.self, from: colorData) {
            canvasBackgroundColor = color
        }
        
        // Interface
        leftHandedMode = defaults.bool(forKey: "leftHandedMode")
        brushCursorType = BrushCursorType(rawValue: defaults.integer(forKey: "brushCursorType")) ?? .outline
        showCursorPreview = defaults.object(forKey: "showCursorPreview") as? Bool ?? true
        interfaceScale = defaults.float(forKey: "interfaceScale") == 0 ? 1.0 : defaults.float(forKey: "interfaceScale")
        showScrollbars = defaults.object(forKey: "showScrollbars") as? Bool ?? true
        
        // Gestures
        if let data = defaults.data(forKey: "gestureMappings"),
           let mappings = try? decoder.decode([String: GestureAction].self, from: data) {
            gestureMappings = mappings
        }
        enableTouchGestures = defaults.object(forKey: "enableTouchGestures") as? Bool ?? true
        twoFingerTapAction = GestureAction(rawValue: defaults.string(forKey: "twoFingerTapAction") ?? "undo") ?? .undo
        threeFingerTapAction = GestureAction(rawValue: defaults.string(forKey: "threeFingerTapAction") ?? "redo") ?? .redo
        fourFingerTapAction = GestureAction(rawValue: defaults.string(forKey: "fourFingerTapAction") ?? "toggleInterface") ?? .toggleInterface
        
        // Pressure & Smoothing
        if let data = defaults.data(forKey: "pressureCurve"),
           let curve = try? decoder.decode(PressureCurve.self, from: data) {
            pressureCurve = curve
        }
        strokeSmoothing = defaults.float(forKey: "strokeSmoothing") == 0 ? 0.5 : defaults.float(forKey: "strokeSmoothing")
        motionFiltering = defaults.float(forKey: "motionFiltering")
        taperLength = defaults.float(forKey: "taperLength") == 0 ? 0.5 : defaults.float(forKey: "taperLength")
        
        // QuickMenu
        quickMenuProfile = defaults.integer(forKey: "quickMenuProfile")
        if let data = defaults.data(forKey: "quickMenuSlots"),
           let slots = try? decoder.decode([[QuickMenuSlot]].self, from: data) {
            quickMenuSlots = slots
        }
        
        // Tablet
        if let data = defaults.data(forKey: "tabletButtonMappings"),
           let mappings = try? decoder.decode([Int: TabletAction].self, from: data) {
            tabletButtonMappings = mappings
        }
        useWindowsInk = defaults.bool(forKey: "useWindowsInk")
        tabletPressureSensitivity = defaults.float(forKey: "tabletPressureSensitivity") == 0 ? 1.0 : defaults.float(forKey: "tabletPressureSensitivity")
        
        // Performance
        maxUndoSteps = defaults.integer(forKey: "maxUndoSteps") == 0 ? 100 : defaults.integer(forKey: "maxUndoSteps")
        tileCacheSize = defaults.integer(forKey: "tileCacheSize") == 0 ? 512 : defaults.integer(forKey: "tileCacheSize")
        enableMetalValidation = defaults.bool(forKey: "enableMetalValidation")
        useLowMemoryMode = defaults.bool(forKey: "useLowMemoryMode")
        
        // Export
        defaultExportFormat = ExportFormat(rawValue: Int16(defaults.integer(forKey: "defaultExportFormat"))) ?? .png
        exportQuality = defaults.float(forKey: "exportQuality") == 0 ? 1.0 : defaults.float(forKey: "exportQuality")
        includeMetadata = defaults.object(forKey: "includeMetadata") as? Bool ?? true
        defaultExportDPI = defaults.integer(forKey: "defaultExportDPI") == 0 ? 300 : defaults.integer(forKey: "defaultExportDPI")
        exportColorProfile = ColorProfile(rawValue: Int16(defaults.integer(forKey: "exportColorProfile"))) ?? .sRGB
        
        // Advanced
        enableExperimentalFeatures = defaults.bool(forKey: "enableExperimentalFeatures")
        showDebugOverlay = defaults.bool(forKey: "showDebugOverlay")
        logLevel = LogLevel(rawValue: defaults.string(forKey: "logLevel") ?? "info") ?? .info
    }
    
    func save() {
        // General
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(language, forKey: "language")
        defaults.set(autoSaveInterval, forKey: "autoSaveInterval")
        defaults.set(showTouchPoints, forKey: "showTouchPoints")
        
        // Canvas
        defaults.set(defaultCanvasWidth, forKey: "defaultCanvasWidth")
        defaults.set(defaultCanvasHeight, forKey: "defaultCanvasHeight")
        defaults.set(defaultDPI, forKey: "defaultDPI")
        defaults.set(defaultColorProfile.rawValue, forKey: "defaultColorProfile")
        if let data = try? encoder.encode(canvasBackgroundColor) {
            defaults.set(data, forKey: "canvasBackgroundColor")
        }
        
        // Interface
        defaults.set(leftHandedMode, forKey: "leftHandedMode")
        defaults.set(brushCursorType.rawValue, forKey: "brushCursorType")
        defaults.set(showCursorPreview, forKey: "showCursorPreview")
        defaults.set(interfaceScale, forKey: "interfaceScale")
        defaults.set(showScrollbars, forKey: "showScrollbars")
        
        // Gestures
        if let data = try? encoder.encode(gestureMappings) {
            defaults.set(data, forKey: "gestureMappings")
        }
        defaults.set(enableTouchGestures, forKey: "enableTouchGestures")
        defaults.set(twoFingerTapAction.rawValue, forKey: "twoFingerTapAction")
        defaults.set(threeFingerTapAction.rawValue, forKey: "threeFingerTapAction")
        defaults.set(fourFingerTapAction.rawValue, forKey: "fourFingerTapAction")
        
        // Pressure & Smoothing
        if let data = try? encoder.encode(pressureCurve) {
            defaults.set(data, forKey: "pressureCurve")
        }
        defaults.set(strokeSmoothing, forKey: "strokeSmoothing")
        defaults.set(motionFiltering, forKey: "motionFiltering")
        defaults.set(taperLength, forKey: "taperLength")
        
        // QuickMenu
        defaults.set(quickMenuProfile, forKey: "quickMenuProfile")
        if let data = try? encoder.encode(quickMenuSlots) {
            defaults.set(data, forKey: "quickMenuSlots")
        }
        
        // Tablet
        if let data = try? encoder.encode(tabletButtonMappings) {
            defaults.set(data, forKey: "tabletButtonMappings")
        }
        defaults.set(useWindowsInk, forKey: "useWindowsInk")
        defaults.set(tabletPressureSensitivity, forKey: "tabletPressureSensitivity")
        
        // Performance
        defaults.set(maxUndoSteps, forKey: "maxUndoSteps")
        defaults.set(tileCacheSize, forKey: "tileCacheSize")
        defaults.set(enableMetalValidation, forKey: "enableMetalValidation")
        defaults.set(useLowMemoryMode, forKey: "useLowMemoryMode")
        
        // Export
        defaults.set(defaultExportFormat.rawValue, forKey: "defaultExportFormat")
        defaults.set(exportQuality, forKey: "exportQuality")
        defaults.set(includeMetadata, forKey: "includeMetadata")
        defaults.set(defaultExportDPI, forKey: "defaultExportDPI")
        defaults.set(exportColorProfile.rawValue, forKey: "exportColorProfile")
        
        // Advanced
        defaults.set(enableExperimentalFeatures, forKey: "enableExperimentalFeatures")
        defaults.set(showDebugOverlay, forKey: "showDebugOverlay")
        defaults.set(logLevel.rawValue, forKey: "logLevel")
    }
    
    func resetToDefaults() {
        let defaultsToRemove = [
            "theme", "language", "autoSaveInterval", "showTouchPoints",
            "defaultCanvasWidth", "defaultCanvasHeight", "defaultDPI", "defaultColorProfile", "canvasBackgroundColor",
            "leftHandedMode", "brushCursorType", "showCursorPreview", "interfaceScale", "showScrollbars",
            "gestureMappings", "enableTouchGestures", "twoFingerTapAction", "threeFingerTapAction", "fourFingerTapAction",
            "pressureCurve", "strokeSmoothing", "motionFiltering", "taperLength",
            "quickMenuProfile", "quickMenuSlots",
            "tabletButtonMappings", "useWindowsInk", "tabletPressureSensitivity",
            "maxUndoSteps", "tileCacheSize", "enableMetalValidation", "useLowMemoryMode",
            "defaultExportFormat", "exportQuality", "includeMetadata", "defaultExportDPI", "exportColorProfile",
            "enableExperimentalFeatures", "showDebugOverlay", "logLevel"
        ]
        
        for key in defaultsToRemove {
            defaults.removeObject(forKey: key)
        }
        
        load()
    }
}

// MARK: - Supporting Types
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}

enum GestureAction: String, CaseIterable, Codable {
    case none = "none"
    case undo = "undo"
    case redo = "redo"
    case brushSizeUp = "brushSizeUp"
    case brushSizeDown = "brushSizeDown"
    case brushOpacityUp = "brushOpacityUp"
    case brushOpacityDown = "brushOpacityDown"
    case eyedropper = "eyedropper"
    case quickMenu = "quickMenu"
    case toggleInterface = "toggleInterface"
    case fullscreen = "fullscreen"
    case canvasRotateLeft = "canvasRotateLeft"
    case canvasRotateRight = "canvasRotateRight"
    case canvasZoomIn = "canvasZoomIn"
    case canvasZoomOut = "canvasZoomOut"
    case selectTool = "selectTool"
    case transformTool = "transformTool"
    case colorPicker = "colorPicker"
    case layerPanel = "layerPanel"
    case brushPanel = "brushPanel"
}

struct QuickMenuSlot: Codable {
    var action: GestureAction = .none
    var customAction: String?
    var icon: String?
    
    var isEmpty: Bool {
        return action == .none && customAction == nil
    }
}

enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
}

// MARK: - Color Codable
extension Color: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let components = try container.decode([Double].self)
        guard components.count >= 3 else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid color components")
        }
        let red = components[0]
        let green = components[1]
        let blue = components[2]
        let alpha = components.count > 3 ? components[3] : 1.0
        self = Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // Get components from Color
        // This is simplified - real implementation would use NSColor/UIColor
        let components: [Double] = [0, 0, 0, 1]
        try container.encode(components)
    }
}
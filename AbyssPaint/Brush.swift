import Foundation
import Metal

// MARK: - Brush
class Brush {
    let id: UUID
    var name: String
    var source: BrushSource
    
    // Stroke
    var spacing: Float = 0.05
    var streamline: Float = 0.5
    var jitter: Float = 0.0
    var fallOff: Float = 0.0
    var taperLength: Float = 0.5
    
    // Taper
    var taperOpacity: Float = 1.0
    var taperSize: Float = 1.0
    var taperPressure: Float = 1.0
    var tipShape: Float = 0.5
    var touchTaper: Float = 0.0
    
    // Shape
    var shapeTexture: MTLTexture?
    var grainTexture: MTLTexture?
    var shapeRotation: Float = 0.0
    var scatter: Float = 0.0
    var randomization: Float = 0.0
    
    // Grain
    var grainScale: Float = 1.0
    var grainZoom: Float = 1.0
    var grainRotation: Float = 0.0
    var grainDepth: Float = 0.5
    var grainBlendMode: GPUBlendMode = .multiply
    var grainBrightness: Float = 0.0
    var grainContrast: Float = 1.0
    
    // Rendering
    var renderingMode: RenderingMode = .normal
    var flow: Float = 1.0
    var wetness: Float = 0.0
    var dilution: Float = 0.0
    var charge: Float = 0.0
    var pull: Float = 0.0
    
    // Wet Mix
    var wetMixDilution: Float = 0.0
    var wetMixCharge: Float = 0.0
    var wetMixPull: Float = 0.0
    var wetMixGrade: Float = 0.5
    
    // Color Dynamics
    var stampColorJitter: Float = 0.0
    var strokeColorJitter: Float = 0.0
    var colorPressure: Float = 0.0
    var colorTilt: Float = 0.0
    var secondaryColor: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 1)
    var saturation: Float = 0.0
    var brightness: Float = 0.0
    var purity: Float = 0.0
    
    // Dynamics
    var speedSize: Float = 0.0
    var speedOpacity: Float = 0.0
    var speedJitter: Float = 0.0
    var flipX: Float = 0.0
    var flipY: Float = 0.0
    var rotationDynamics: Float = 0.0
    
    // Tablet/Apple Pencil
    var pressureSize: Float = 1.0
    var pressureOpacity: Float = 1.0
    var pressureFlow: Float = 1.0
    var pressureBleed: Float = 0.0
    var pressureSmoothing: Float = 0.0
    var tiltSize: Float = 0.0
    var tiltOpacity: Float = 0.0
    var tiltGradient: Float = 0.0
    var tiltBleed: Float = 0.0
    var azimuthSize: Float = 0.0
    var azimuthOpacity: Float = 0.0
    
    // Properties
    var maxSize: Float = 1000.0
    var minSize: Float = 1.0
    var maxOpacity: Float = 1.0
    var minOpacity: Float = 0.0
    var orientToScreen: Bool = false
    var classicTaper: Bool = false
    
    // Thumbnail
    var thumbnailData: Data?
    
    init(id: UUID = UUID(), name: String, source: BrushSource = .custom) {
        self.id = id
        self.name = name
        self.source = source
    }
    
    // MARK: - GPU Parameter Conversion
    func toGPUParameters() -> BrushParameters {
        return BrushParameters(
            spacing: spacing,
            streamline: streamline,
            jitter: jitter,
            fallOff: fallOff,
            taperLength: taperLength,
            taperOpacity: taperOpacity,
            taperSize: taperSize,
            taperPressure: taperPressure,
            tipShape: tipShape,
            touchTaper: touchTaper,
            shapeSource: shapeTexture != nil ? 1 : 0,
            grainSource: grainTexture != nil ? 1 : 0,
            shapeRotation: shapeRotation,
            scatter: scatter,
            randomization: randomization,
            grainScale: grainScale,
            grainZoom: grainZoom,
            grainRotation: grainRotation,
            grainDepth: grainDepth,
            grainBlendMode: grainBlendMode.rawValue,
            grainBrightness: grainBrightness,
            grainContrast: grainContrast,
            renderingMode: renderingMode.rawValue,
            flow: flow,
            wetness: wetness,
            dilution: dilution,
            charge: charge,
            pull: pull,
            wetMixDilution: wetMixDilution,
            wetMixCharge: wetMixCharge,
            wetMixPull: wetMixPull,
            wetMixGrade: wetMixGrade,
            stampColorJitter: stampColorJitter,
            strokeColorJitter: strokeColorJitter,
            colorPressure: colorPressure,
            colorTilt: colorTilt,
            secondaryColor: secondaryColor,
            saturation: saturation,
            brightness: brightness,
            purity: purity,
            speedSize: speedSize,
            speedOpacity: speedOpacity,
            speedJitter: speedJitter,
            flipX: flipX,
            flipY: flipY,
            rotationDynamics: rotationDynamics,
            pressureSize: pressureSize,
            pressureOpacity: pressureOpacity,
            pressureFlow: pressureFlow,
            pressureBleed: pressureBleed,
            pressureSmoothing: pressureSmoothing,
            tiltSize: tiltSize,
            tiltOpacity: tiltOpacity,
            tiltGradient: tiltGradient,
            tiltBleed: tiltBleed,
            azimuthSize: azimuthSize,
            azimuthOpacity: azimuthOpacity,
            maxSize: maxSize,
            minSize: minSize,
            maxOpacity: maxOpacity,
            minOpacity: minOpacity,
            orientToScreen: orientToScreen ? 1 : 0,
            classicTaper: classicTaper ? 1 : 0
        )
    }
    
    // MARK: - Serialization
    func encode() -> Data? {
        let dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "source": source.rawValue,
            "spacing": spacing,
            "streamline": streamline,
            "jitter": jitter,
            "fallOff": fallOff,
            "taperLength": taperLength,
            "taperOpacity": taperOpacity,
            "taperSize": taperSize,
            "taperPressure": taperPressure,
            "tipShape": tipShape,
            "touchTaper": touchTaper,
            "shapeRotation": shapeRotation,
            "scatter": scatter,
            "randomization": randomization,
            "grainScale": grainScale,
            "grainZoom": grainZoom,
            "grainRotation": grainRotation,
            "grainDepth": grainDepth,
            "grainBlendMode": grainBlendMode.rawValue,
            "grainBrightness": grainBrightness,
            "grainContrast": grainContrast,
            "renderingMode": renderingMode.rawValue,
            "flow": flow,
            "wetness": wetness,
            "dilution": dilution,
            "charge": charge,
            "pull": pull,
            "wetMixDilution": wetMixDilution,
            "wetMixCharge": wetMixCharge,
            "wetMixPull": wetMixPull,
            "wetMixGrade": wetMixGrade,
            "stampColorJitter": stampColorJitter,
            "strokeColorJitter": strokeColorJitter,
            "colorPressure": colorPressure,
            "colorTilt": colorTilt,
            "secondaryColor": [secondaryColor.x, secondaryColor.y, secondaryColor.z, secondaryColor.w],
            "saturation": saturation,
            "brightness": brightness,
            "purity": purity,
            "speedSize": speedSize,
            "speedOpacity": speedOpacity,
            "speedJitter": speedJitter,
            "flipX": flipX,
            "flipY": flipY,
            "rotationDynamics": rotationDynamics,
            "pressureSize": pressureSize,
            "pressureOpacity": pressureOpacity,
            "pressureFlow": pressureFlow,
            "pressureBleed": pressureBleed,
            "pressureSmoothing": pressureSmoothing,
            "tiltSize": tiltSize,
            "tiltOpacity": tiltOpacity,
            "tiltGradient": tiltGradient,
            "tiltBleed": tiltBleed,
            "azimuthSize": azimuthSize,
            "azimuthOpacity": azimuthOpacity,
            "maxSize": maxSize,
            "minSize": minSize,
            "maxOpacity": maxOpacity,
            "minOpacity": minOpacity,
            "orientToScreen": orientToScreen,
            "classicTaper": classicTaper
        ]
        
        return try? JSONSerialization.data(withJSONObject: dict)
    }
    
    static func decode(from data: Data) -> Brush? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = dict["name"] as? String,
              let sourceRaw = dict["source"] as? Int16,
              let source = BrushSource(rawValue: sourceRaw) else {
            return nil
        }
        
        let brush = Brush(id: id, name: name, source: source)
        
        // Populate all properties
        brush.spacing = dict["spacing"] as? Float ?? 0.05
        brush.streamline = dict["streamline"] as? Float ?? 0.5
        brush.jitter = dict["jitter"] as? Float ?? 0.0
        brush.fallOff = dict["fallOff"] as? Float ?? 0.0
        brush.taperLength = dict["taperLength"] as? Float ?? 0.5
        brush.taperOpacity = dict["taperOpacity"] as? Float ?? 1.0
        brush.taperSize = dict["taperSize"] as? Float ?? 1.0
        brush.taperPressure = dict["taperPressure"] as? Float ?? 1.0
        brush.tipShape = dict["tipShape"] as? Float ?? 0.5
        brush.touchTaper = dict["touchTaper"] as? Float ?? 0.0
        brush.shapeRotation = dict["shapeRotation"] as? Float ?? 0.0
        brush.scatter = dict["scatter"] as? Float ?? 0.0
        brush.randomization = dict["randomization"] as? Float ?? 0.0
        brush.grainScale = dict["grainScale"] as? Float ?? 1.0
        brush.grainZoom = dict["grainZoom"] as? Float ?? 1.0
        brush.grainRotation = dict["grainRotation"] as? Float ?? 0.0
        brush.grainDepth = dict["grainDepth"] as? Float ?? 0.5
        brush.grainBlendMode = GPUBlendMode(rawValue: dict["grainBlendMode"] as? UInt32 ?? 0) ?? .multiply
        brush.grainBrightness = dict["grainBrightness"] as? Float ?? 0.0
        brush.grainContrast = dict["grainContrast"] as? Float ?? 1.0
        brush.renderingMode = RenderingMode(rawValue: dict["renderingMode"] as? UInt32 ?? 0) ?? .normal
        brush.flow = dict["flow"] as? Float ?? 1.0
        brush.wetness = dict["wetness"] as? Float ?? 0.0
        brush.dilution = dict["dilution"] as? Float ?? 0.0
        brush.charge = dict["charge"] as? Float ?? 0.0
        brush.pull = dict["pull"] as? Float ?? 0.0
        brush.wetMixDilution = dict["wetMixDilution"] as? Float ?? 0.0
        brush.wetMixCharge = dict["wetMixCharge"] as? Float ?? 0.0
        brush.wetMixPull = dict["wetMixPull"] as? Float ?? 0.0
        brush.wetMixGrade = dict["wetMixGrade"] as? Float ?? 0.5
        brush.stampColorJitter = dict["stampColorJitter"] as? Float ?? 0.0
        brush.strokeColorJitter = dict["strokeColorJitter"] as? Float ?? 0.0
        brush.colorPressure = dict["colorPressure"] as? Float ?? 0.0
        brush.colorTilt = dict["colorTilt"] as? Float ?? 0.0
        
        if let secColor = dict["secondaryColor"] as? [Float], secColor.count == 4 {
            brush.secondaryColor = SIMD4<Float>(secColor[0], secColor[1], secColor[2], secColor[3])
        }
        
        brush.saturation = dict["saturation"] as? Float ?? 0.0
        brush.brightness = dict["brightness"] as? Float ?? 0.0
        brush.purity = dict["purity"] as? Float ?? 0.0
        brush.speedSize = dict["speedSize"] as? Float ?? 0.0
        brush.speedOpacity = dict["speedOpacity"] as? Float ?? 0.0
        brush.speedJitter = dict["speedJitter"] as? Float ?? 0.0
        brush.flipX = dict["flipX"] as? Float ?? 0.0
        brush.flipY = dict["flipY"] as? Float ?? 0.0
        brush.rotationDynamics = dict["rotationDynamics"] as? Float ?? 0.0
        brush.pressureSize = dict["pressureSize"] as? Float ?? 1.0
        brush.pressureOpacity = dict["pressureOpacity"] as? Float ?? 1.0
        brush.pressureFlow = dict["pressureFlow"] as? Float ?? 1.0
        brush.pressureBleed = dict["pressureBleed"] as? Float ?? 0.0
        brush.pressureSmoothing = dict["pressureSmoothing"] as? Float ?? 0.0
        brush.tiltSize = dict["tiltSize"] as? Float ?? 0.0
        brush.tiltOpacity = dict["tiltOpacity"] as? Float ?? 0.0
        brush.tiltGradient = dict["tiltGradient"] as? Float ?? 0.0
        brush.tiltBleed = dict["tiltBleed"] as? Float ?? 0.0
        brush.azimuthSize = dict["azimuthSize"] as? Float ?? 0.0
        brush.azimuthOpacity = dict["azimuthOpacity"] as? Float ?? 0.0
        brush.maxSize = dict["maxSize"] as? Float ?? 1000.0
        brush.minSize = dict["minSize"] as? Float ?? 1.0
        brush.maxOpacity = dict["maxOpacity"] as? Float ?? 1.0
        brush.minOpacity = dict["minOpacity"] as? Float ?? 0.0
        brush.orientToScreen = dict["orientToScreen"] as? Bool ?? false
        brush.classicTaper = dict["classicTaper"] as? Bool ?? false
        
        return brush
    }
    
    // MARK: - Built-in Brushes
    static func defaultBrushes() -> [Brush] {
        var brushes: [Brush] = []
        
        // Basic Round
        let basicRound = Brush(name: "Basic Round", source: .builtin)
        basicRound.spacing = 0.03
        basicRound.streamline = 0.7
        basicRound.pressureSize = 1.0
        basicRound.pressureOpacity = 1.0
        basicRound.maxSize = 500
        basicRound.renderingMode = .normal
        brushes.append(basicRound)
        
        // Hard Round
        let hardRound = Brush(name: "Hard Round", source: .builtin)
        hardRound.spacing = 0.02
        hardRound.streamline = 0.8
        hardRound.pressureSize = 1.0
        hardRound.pressureOpacity = 0.0
        hardRound.maxSize = 500
        hardRound.renderingMode = .normal
        brushes.append(hardRound)
        
        // Soft Round
        let softRound = Brush(name: "Soft Round", source: .builtin)
        softRound.spacing = 0.05
        softRound.streamline = 0.5
        softRound.pressureSize = 1.0
        softRound.pressureOpacity = 1.0
        softRound.taperSize = 1.0
        softRound.taperOpacity = 1.0
        softRound.maxSize = 800
        softRound.renderingMode = .glazed
        brushes.append(softRound)
        
        // Pencil (HB)
        let pencil = Brush(name: "HB Pencil", source: .builtin)
        pencil.spacing = 0.04
        pencil.streamline = 0.6
        pencil.pressureSize = 0.5
        pencil.pressureOpacity = 1.0
        pencil.tiltSize = 0.3
        pencil.tiltOpacity = 0.5
        pencil.grainScale = 2.0
        pencil.grainDepth = 0.3
        pencil.grainBlendMode = .multiply
        pencil.maxSize = 200
        pencil.renderingMode = .normal
        brushes.append(pencil)
        
        // Charcoal
        let charcoal = Brush(name: "Charcoal", source: .builtin)
        charcoal.spacing = 0.06
        charcoal.streamline = 0.3
        charcoal.jitter = 0.2
        charcoal.randomization = 0.3
        charcoal.pressureSize = 1.0
        charcoal.pressureOpacity = 0.8
        charcoal.tiltSize = 0.5
        charcoal.grainScale = 1.5
        charcoal.grainDepth = 0.7
        charcoal.grainBlendMode = .multiply
        charcoal.maxSize = 400
        charcoal.renderingMode = .glazed
        brushes.append(charcoal)
        
        // Watercolor
        let watercolor = Brush(name: "Watercolor", source: .builtin)
        watercolor.spacing = 0.04
        watercolor.streamline = 0.7
        watercolor.pressureSize = 1.0
        watercolor.pressureOpacity = 0.5
        watercolor.pressureFlow = 1.0
        watercolor.wetness = 0.8
        watercolor.dilution = 0.5
        watercolor.charge = 0.3
        watercolor.pull = 0.4
        watercolor.renderingMode = .wetMix
        watercolor.maxSize = 600
        brushes.append(watercolor)
        
        // Oil Paint
        let oilPaint = Brush(name: "Oil Paint", source: .builtin)
        oilPaint.spacing = 0.03
        oilPaint.streamline = 0.8
        oilPaint.pressureSize = 0.8
        oilPaint.pressureFlow = 1.0
        oilPaint.wetness = 0.6
        oilPaint.dilution = 0.2
        oilPaint.charge = 0.4
        oilPaint.pull = 0.6
        oilPaint.renderingMode = .intenseBlending
        oilPaint.maxSize = 500
        brushes.append(oilPaint)
        
        // Airbrush
        let airbrush = Brush(name: "Airbrush", source: .builtin)
        airbrush.spacing = 0.1
        airbrush.streamline = 0.9
        airbrush.jitter = 0.1
        airbrush.fallOff = 0.3
        airbrush.pressureSize = 0.3
        airbrush.pressureOpacity = 1.0
        airbrush.pressureFlow = 1.0
        airbrush.maxSize = 1000
        airbrush.renderingMode = .glazed
        brushes.append(airbrush)
        
        // Inking Pen
        let inkingPen = Brush(name: "Inking Pen", source: .builtin)
        inkingPen.spacing = 0.01
        inkingPen.streamline = 0.95
        inkingPen.pressureSize = 0.2
        inkingPen.pressureOpacity = 0.0
        inkingPen.taperSize = 1.0
        inkingPen.taperOpacity = 1.0
        inkingPen.taperPressure = 1.0
        inkingPen.maxSize = 300
        inkingPen.renderingMode = .normal
        brushes.append(inkingPen)
        
        // Marker
        let marker = Brush(name: "Marker", source: .builtin)
        marker.spacing = 0.02
        marker.streamline = 0.5
        marker.pressureSize = 0.5
        marker.pressureOpacity = 0.5
        marker.tiltSize = 0.4
        marker.tiltOpacity = 0.3
        marker.grainScale = 1.2
        marker.grainDepth = 0.4
        marker.grainBlendMode = .multiply
        marker.maxSize = 400
        marker.renderingMode = .glazed
        brushes.append(marker)
        
        // Blur/Smudge
        let smudge = Brush(name: "Smudge", source: .builtin)
        smudge.spacing = 0.05
        smudge.streamline = 0.7
        smudge.pressureSize = 1.0
        smudge.renderingMode = .normal
        // Smudge is a special tool, not a paint brush
        brushes.append(smudge)
        
        return brushes
    }
}

// MARK: - Rendering Mode
enum RenderingMode: UInt32, CaseIterable {
    case normal = 0
    case glazed = 1
    case wetMix = 2
    case intenseGlazed = 3
    case intenseBlending = 4
    case heavyGlazing = 5
}

// MARK: - Brush Library Manager
class BrushLibrary {
    static let shared = BrushLibrary()
    
    private var brushSets: [BrushSet] = []
    private var recentBrushes: [UUID] = []
    private let maxRecentBrushes = 10
    
    private init() {
        loadBuiltinBrushes()
    }
    
    private func loadBuiltinBrushes() {
        let defaultSet = BrushSet(name: "Default", brushes: Brush.defaultBrushes())
        defaultSet.isDefault = true
        brushSets.append(defaultSet)
        
        // Add more built-in sets
        let sketchingSet = BrushSet(name: "Sketching", brushes: [
            Brush(name: "6B Pencil", source: .builtin),
            Brush(name: "HB Pencil", source: .builtin),
            Brush(name: "Charcoal", source: .builtin),
            Brush(name: "Compressed Charcoal", source: .builtin)
        ])
        brushSets.append(sketchingSet)
        
        let inkingSet = BrushSet(name: "Inking", brushes: [
            Brush(name: "Studio Pen", source: .builtin),
            Brush(name: "Technical Pen", source: .builtin),
            Brush(name: "Brush Pen", source: .builtin),
            Brush(name: "Syrup", source: .builtin)
        ])
        brushSets.append(inkingSet)
        
        let paintingSet = BrushSet(name: "Painting", brushes: [
            Brush(name: "Oil Paint", source: .builtin),
            Brush(name: "Acrylic", source: .builtin),
            Brush(name: "Watercolor", source: .builtin),
            Brush(name: "Gouache", source: .builtin)
        ])
        brushSets.append(paintingSet)
        
        let airbrushSet = BrushSet(name: "Airbrushing", brushes: [
            Brush(name: "Soft Airbrush", source: .builtin),
            Brush(name: "Medium Airbrush", source: .builtin),
            Brush(name: "Hard Airbrush", source: .builtin)
        ])
        brushSets.append(airbrushSet)
        
        let textureSet = BrushSet(name: "Textures", brushes: [
            Brush(name: "Noise", source: .builtin),
            Brush(name: "Grain", source: .builtin),
            Brush(name: "Canvas", source: .builtin),
            Brush(name: "Paper", source: .builtin)
        ])
        brushSets.append(textureSet)
    }
    
    func allBrushes() -> [Brush] {
        return brushSets.flatMap { $0.brushes }
    }
    
    func brush(withID id: UUID) -> Brush? {
        return allBrushes().first { $0.id == id }
    }
    
    func addToRecent(_ brushID: UUID) {
        recentBrushes.removeAll { $0 == brushID }
        recentBrushes.insert(brushID, at: 0)
        if recentBrushes.count > maxRecentBrushes {
            recentBrushes.removeLast()
        }
    }
    
    func recentBrushesList() -> [Brush] {
        return recentBrushes.compactMap { brush(withID: $0) }
    }
    
    func importBrushSet(from data: Data) -> BrushSet? {
        // Implementation for importing .abyssbrushset files
        return nil
    }
}

// MARK: - BrushSet
class BrushSet {
    let id: UUID
    var name: String
    var isDefault: Bool = false
    var source: BrushSource = .custom
    var brushes: [Brush]
    
    init(id: UUID = UUID(), name: String, brushes: [Brush] = []) {
        self.id = id
        self.name = name
        self.brushes = brushes
    }
    
    func addBrush(_ brush: Brush) {
        brushes.append(brush)
    }
    
    func removeBrush(_ brush: Brush) {
        brushes.removeAll { $0.id == brush.id }
    }
}
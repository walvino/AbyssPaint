import Foundation
import simd

// MARK: - Stroke Point
struct StrokePoint {
    var position: SIMD2<Float>
    var pressure: Float
    var tilt: SIMD2<Float>
    var azimuth: Float
    var timestamp: TimeInterval
    var velocity: Float
}

// MARK: - Stroke
struct Stroke {
    var id: UUID
    var points: [StrokePoint]
    var brushID: UUID
    var layerID: UUID
    var color: SIMD4<Float>
    var blendMode: BlendMode
    var startTime: TimeInterval
    var endTime: TimeInterval
    
    init(brushID: UUID, layerID: UUID, color: SIMD4<Float>, blendMode: BlendMode) {
        self.id = UUID()
        self.points = []
        self.brushID = brushID
        self.layerID = layerID
        self.color = color
        self.blendMode = blendMode
        self.startTime = Date().timeIntervalSinceReferenceDate
        self.endTime = 0
    }
    
    mutating func addPoint(_ point: StrokePoint) {
        points.append(point)
    }
    
    mutating func finish() {
        endTime = Date().timeIntervalSinceReferenceDate
    }
    
    var duration: TimeInterval {
        return endTime - startTime
    }
    
    var pointCount: Int {
        return points.count
    }
    
    var boundingBox: (min: SIMD2<Float>, max: SIMD2<Float>)? {
        guard !points.isEmpty else { return nil }
        var minPt = points[0].position
        var maxPt = points[0].position
        for point in points.dropFirst() {
            minPt = simd_min(minPt, point.position)
            maxPt = simd_max(maxPt, point.position)
        }
        return (minPt, maxPt)
    }
}

// MARK: - Brush Stamp
struct BrushStamp {
    var position: SIMD2<Float>
    var size: Float
    var rotation: Float
    var opacity: Float
    var color: SIMD4<Float>
    var textureIndex: UInt32
}

// MARK: - Stroke Segment (for GPU)
struct StrokeSegment {
    var startPoint: StrokePoint
    var endPoint: StrokePoint
    var stamps: [BrushStamp]
}

// MARK: - Brush Parameters (GPU-friendly)
struct BrushParameters {
    // Stroke
    var spacing: Float
    var streamline: Float
    var jitter: Float
    var fallOff: Float
    var taperLength: Float
    
    // Taper
    var taperOpacity: Float
    var taperSize: Float
    var taperPressure: Float
    var tipShape: Float
    var touchTaper: Float
    
    // Shape
    var shapeSource: UInt32
    var grainSource: UInt32
    var shapeRotation: Float
    var scatter: Float
    var randomization: Float
    
    // Grain
    var grainScale: Float
    var grainZoom: Float
    var grainRotation: Float
    var grainDepth: Float
    var grainBlendMode: UInt32
    var grainBrightness: Float
    var grainContrast: Float
    
    // Rendering
    var renderingMode: UInt32
    var flow: Float
    var wetness: Float
    var dilution: Float
    var charge: Float
    var pull: Float
    
    // Wet Mix
    var wetMixDilution: Float
    var wetMixCharge: Float
    var wetMixPull: Float
    var wetMixGrade: Float
    
    // Color Dynamics
    var stampColorJitter: Float
    var strokeColorJitter: Float
    var colorPressure: Float
    var colorTilt: Float
    var secondaryColor: SIMD4<Float>
    var saturation: Float
    var brightness: Float
    var purity: Float
    
    // Dynamics
    var speedSize: Float
    var speedOpacity: Float
    var speedJitter: Float
    var flipX: Float
    var flipY: Float
    var rotationDynamics: Float
    
    // Apple Pencil / Tablet
    var pressureSize: Float
    var pressureOpacity: Float
    var pressureFlow: Float
    var pressureBleed: Float
    var pressureSmoothing: Float
    var tiltSize: Float
    var tiltOpacity: Float
    var tiltGradient: Float
    var tiltBleed: Float
    var azimuthSize: Float
    var azimuthOpacity: Float
    
    // Properties
    var maxSize: Float
    var minSize: Float
    var maxOpacity: Float
    var minOpacity: Float
    var orientToScreen: Float
    var classicTaper: Float
}

// MARK: - Pressure Curve
struct PressureCurve {
    var points: [SIMD2<Float>] // 4 control points for cubic bezier
    var smoothing: Float
    var motionFiltering: Float
    
    static let `default` = PressureCurve(
        points: [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(0.33, 0.33),
            SIMD2<Float>(0.66, 0.66),
            SIMD2<Float>(1, 1)
        ],
        smoothing: 0.5,
        motionFiltering: 0.0
    )
    
    func evaluate(_ pressure: Float) -> Float {
        let t = clamp(pressure, 0, 1)
        // Cubic bezier evaluation
        let u = 1 - t
        let uu = u * u
        let uuu = uu * u
        let tt = t * t
        let ttt = tt * t
        
        let p0 = points[0]
        let p1 = points[1]
        let p2 = points[2]
        let p3 = points[3]
        
        let y = uuu * p0.y +
                3 * uu * t * p1.y +
                3 * u * tt * p2.y +
                ttt * p3.y
        
        return clamp(y, 0, 1)
    }
    
    private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
}

// MARK: - Brush Cursor Type
enum BrushCursorType: Int {
    case outline = 0
    case shape = 1
    case crosshair = 2
}

// MARK: - Blend Mode (for GPU)
enum GPUBlendMode: UInt32 {
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

// MARK: - Layer Data (GPU)
struct LayerData {
    var id: UUID
    var textureIndex: UInt32
    var maskTextureIndex: UInt32
    var opacity: Float
    var blendMode: GPUBlendMode
    var visible: Bool
    var transform: simd_float3x3
    var isClippingMask: Bool
    var clippingToLayerID: UUID?
    var isReferenceLayer: Bool
    var filterStack: [FilterData]
}

struct FilterData {
    var type: UInt32
    var parameters: [Float]
    var enabled: Bool
}

// MARK: - Canvas Settings (GPU)
struct CanvasSettings {
    var width: UInt32
    var height: UInt32
    var dpi: UInt32
    var colorProfile: UInt32
    var backgroundColor: SIMD4<Float>
    var timeLapseEnabled: Bool
    var timeLapseQuality: UInt32
    var drawingGuideType: UInt32
    var drawingGuideData: Data?
}

// MARK: - Vertex for Full Screen Quad
struct QuadVertex {
    var position: SIMD2<Float>
    var texCoord: SIMD2<Float>
}

// MARK: - Uniforms
struct RenderUniforms {
    var projectionMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var canvasSize: SIMD2<Float>
    var zoom: Float
    var pan: SIMD2<Float>
    var rotation: Float
    var time: Float
}

// MARK: - Brush Uniforms
struct BrushUniforms {
    var brushParams: BrushParameters
    var canvasSize: SIMD2<Float>
    var zoom: Float
    var time: Float
    var stampCount: UInt32
}

// MARK: - Time Lapse Frame
struct TimeLapseFrame {
    var strokes: [Stroke]
    var timestamp: TimeInterval
    var canvasSize: SIMD2<UInt32>
}
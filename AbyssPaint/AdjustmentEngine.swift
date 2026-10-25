import Foundation
import Metal
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Adjustment Engine
class AdjustmentEngine {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var ciContext: CIContext
    private var adjustmentPipelines: [AdjustmentType: MTLComputePipelineState] = [:]
    
    init() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.commandQueue = device.makeCommandQueue()!
        self.ciContext = CIContext(mtlDevice: device)
        
        setupAdjustmentPipelines()
    }
    
    private func setupAdjustmentPipelines() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        let adjustments: [(AdjustmentType, String)] = [
            (.gaussianBlur, "adjustment_gaussianBlur"),
            (.motionBlur, "adjustment_motionBlur"),
            (.perspectiveBlur, "adjustment_perspectiveBlur"),
            (.sharpen, "adjustment_sharpen"),
            (.noise, "adjustment_noise"),
            (.colorBalance, "adjustment_colorBalance"),
            (.curves, "adjustment_curves"),
            (.hueSaturationBrightness, "adjustment_hueSaturationBrightness"),
            (.gradientMap, "adjustment_gradientMap"),
            (.recolor, "adjustment_recolor")
        ]
        
        for (type, functionName) in adjustments {
            if let function = library.makeFunction(name: functionName) {
                do {
                    adjustmentPipelines[type] = try device.makeComputePipelineState(function: function)
                } catch {
                    print("Failed to create pipeline for \(type): \(error)")
                }
            }
        }
    }
    
    // MARK: - Apply Adjustment
    func applyAdjustment(_ adjustment: Adjustment, to texture: MTLTexture, commandBuffer: MTLCommandBuffer) -> MTLTexture? {
        guard let pipeline = adjustmentPipelines[adjustment.adjustmentType],
              adjustment.enabled else { return texture }
        
        // Create output texture
        let outputTexture = createOutputTexture(matching: texture)
        
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        
        // Set adjustment parameters
        var params = adjustment.parametersData
        encoder.setBytes(&params, length: MemoryLayout<AdjustmentParameters>.stride, index: 0)
        
        let threadsPerGroup = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(
            width: (texture.width + 15) / 16,
            height: (texture.height + 15) / 16,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        
        return outputTexture
    }
    
    func applyAdjustmentStack(_ adjustments: [Adjustment], to texture: MTLTexture) -> MTLTexture? {
        var currentTexture = texture
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        for adjustment in adjustments.sorted(by: { $0.order < $1.order }) {
            if let result = applyAdjustment(adjustment, to: currentTexture, commandBuffer: commandBuffer) {
                currentTexture = result
            }
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return currentTexture
    }
    
    // MARK: - Core Image Fallbacks
    func applyCIFilter(_ filter: CIFilter, to texture: MTLTexture) -> MTLTexture? {
        let inputImage = CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let outputTexture = createOutputTexture(matching: texture)
        ciContext.render(outputImage, to: outputTexture, commandBuffer: nil, bounds: outputImage.extent, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        
        return outputTexture
    }
    
    // MARK: - Specific Adjustments
    func gaussianBlur(texture: MTLTexture, radius: Float) -> MTLTexture? {
        let filter = CIFilter.gaussianBlur()
        filter.radius = radius
        return applyCIFilter(filter, to: texture)
    }
    
    func motionBlur(texture: MTLTexture, radius: Float, angle: Float) -> MTLTexture? {
        let filter = CIFilter.motionBlur()
        filter.radius = radius
        filter.angle = angle
        return applyCIFilter(filter, to: texture)
    }
    
    func sharpen(texture: MTLTexture, sharpness: Float) -> MTLTexture? {
        let filter = CIFilter.sharpenLuminance()
        filter.sharpness = sharpness
        return applyCIFilter(filter, to: texture)
    }
    
    func noise(texture: MTLTexture, amount: Float) -> MTLTexture? {
        let filter = CIFilter.randomGenerator()
        // Composite noise over texture
        return nil
    }
    
    func colorBalance(texture: MTLTexture, shadows: SIMD3<Float>, midtones: SIMD3<Float>, highlights: SIMD3<Float>) -> MTLTexture? {
        let filter = CIFilter.colorControls()
        // Color balance would need custom implementation
        return nil
    }
    
    func curves(texture: MTLTexture, red: [Float], green: [Float], blue: [Float], alpha: [Float]) -> MTLTexture? {
        let filter = CIFilter.colorCurves()
        // Set curve points
        return applyCIFilter(filter, to: texture)
    }
    
    func hueSaturationBrightness(texture: MTLTexture, hue: Float, saturation: Float, brightness: Float) -> MTLTexture? {
        let filter = CIFilter.hueAdjust()
        filter.angle = hue
        // Saturation and brightness would need chaining filters
        return applyCIFilter(filter, to: texture)
    }
    
    func gradientMap(texture: MTLTexture, gradient: CGGradient) -> MTLTexture? {
        // Gradient map implementation
        return nil
    }
    
    func recolor(texture: MTLTexture, color: SIMD4<Float>) -> MTLTexture? {
        let filter = CIFilter.colorMatrix()
        // Recolor implementation
        return nil
    }
    
    // MARK: - Liquify (requires special handling)
    func liquify(texture: MTLTexture, warpMesh: [SIMD2<Float>], strength: Float) -> MTLTexture? {
        // Liquify uses a warp mesh - would need custom Metal shader
        guard let pipeline = adjustmentPipelines[.liquify] else { return nil }
        
        let outputTexture = createOutputTexture(matching: texture)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        
        // Pass warp mesh data
        // encoder.setBytes(...)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outputTexture
    }
    
    // MARK: - Helpers
    private func createOutputTexture(matching texture: MTLTexture) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)!
    }
}

// MARK: - Adjustment Parameters
struct AdjustmentParameters {
    // Common
    var intensity: Float = 1.0
    var blendMode: UInt32 = 0 // Normal
    
    // Gaussian Blur
    var blurRadius: Float = 10.0
    
    // Motion Blur
    var motionBlurRadius: Float = 10.0
    var motionBlurAngle: Float = 0.0
    
    // Perspective Blur
    var perspectiveBlurRadius: Float = 10.0
    var perspectiveBlurCenter: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    var perspectiveBlurFocalDistance: Float = 0.5
    
    // Sharpen
    var sharpenAmount: Float = 1.0
    var sharpenRadius: Float = 1.0
    
    // Noise
    var noiseAmount: Float = 0.1
    var noiseType: UInt32 = 0
    
    // Color Balance
    var shadows: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var midtones: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var highlights: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var preserveLuminosity: Bool = true
    
    // Curves
    var curvePoints: [Float] = Array(repeating: 0, count: 256 * 4) // RGBA curves
    
    // Hue/Saturation/Brightness
    var hueShift: Float = 0.0
    var saturationShift: Float = 0.0
    var brightnessShift: Float = 0.0
    var colorize: Bool = false
    var colorizeHue: Float = 0.0
    var colorizeSaturation: Float = 0.0
    
    // Gradient Map
    var gradientColors: [SIMD4<Float>] = []
    var gradientPositions: [Float] = []
    var gradientMode: UInt32 = 0
    var dither: Bool = true
    
    // Recolor
    var recolorColor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)
    var recolorMode: UInt32 = 0
    
    // Liquify
    var liquifyMesh: [SIMD2<Float>] = []
    var liquifyStrength: Float = 1.0
    var liquifySize: Float = 50.0
    var liquifyPressure: Float = 1.0
}

// MARK: - Adjustment Type Extension
extension AdjustmentType {
    var parameterStructSize: Int {
        return MemoryLayout<AdjustmentParameters>.stride
    }
    
    var defaultParameters: AdjustmentParameters {
        var params = AdjustmentParameters()
        
        switch self {
        case .gaussianBlur:
            params.blurRadius = 10.0
        case .motionBlur:
            params.motionBlurRadius = 10.0
            params.motionBlurAngle = 0.0
        case .perspectiveBlur:
            params.perspectiveBlurRadius = 10.0
            params.perspectiveBlurCenter = SIMD2<Float>(0.5, 0.5)
        case .sharpen:
            params.sharpenAmount = 1.0
            params.sharpenRadius = 1.0
        case .noise:
            params.noiseAmount = 0.1
        case .colorBalance:
            params.preserveLuminosity = true
        case .hueSaturationBrightness:
            params.colorize = false
        case .recolor:
            params.recolorColor = SIMD4<Float>(1, 1, 1, 1)
        case .liquify:
            params.liquifySize = 50.0
            params.liquifyStrength = 1.0
        default:
            break
        }
        
        return params
    }
}
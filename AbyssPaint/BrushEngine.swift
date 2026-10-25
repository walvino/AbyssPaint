import Foundation
import Metal
import simd

// MARK: - Brush Engine
class BrushEngine {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var stampPipelineState: MTLComputePipelineState!
    private var textureLoader: MTKTextureLoader
    
    // Brush cache
    private var brushCache: [UUID: CachedBrush] = [:]
    
    struct CachedBrush {
        let brush: Brush
        let paramsBuffer: MTLBuffer
        let shapeTexture: MTLTexture?
        let grainTexture: MTLTexture?
        var lastUsed: Date
    }
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported")
        }
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.textureLoader = MTKTextureLoader(device: device)
        
        setupComputePipeline()
    }
    
    private func setupComputePipeline() {
        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "generateBrushStamps") else {
            fatalError("Failed to load brush compute shader")
        }
        
        do {
            stampPipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            fatalError("Failed to create brush compute pipeline: \(error)")
        }
    }
    
    func getCachedBrush(_ brush: Brush) -> CachedBrush {
        if let cached = brushCache[brush.id] {
            brushCache[brush.id] = CachedBrush(
                brush: cached.brush,
                paramsBuffer: cached.paramsBuffer,
                shapeTexture: cached.shapeTexture,
                grainTexture: cached.grainTexture,
                lastUsed: Date()
            )
            return brushCache[brush.id]!
        }
        
        // Create new cache entry
        var params = brush.toGPUParameters()
        let paramsBuffer = device.makeBuffer(bytes: &params, length: MemoryLayout<BrushParameters>.stride, options: .storageModeShared)!
        
        let cached = CachedBrush(
            brush: brush,
            paramsBuffer: paramsBuffer,
            shapeTexture: brush.shapeTexture,
            grainTexture: brush.grainTexture,
            lastUsed: Date()
        )
        brushCache[brush.id] = cached
        return cached
    }
    
    func generateStamps(for segment: StrokeSegment, brush: Brush, color: SIMD4<Float>) -> [BrushStamp] {
        let cached = getCachedBrush(brush)
        let params = brush.toGPUParameters()
        
        // Calculate number of stamps based on spacing and distance
        let distance = length(segment.endPoint.position - segment.startPoint.position)
        let stampSpacing = params.spacing * params.maxSize
        let stampCount = max(1, Int(distance / stampSpacing) + 1)
        
        var stamps: [BrushStamp] = []
        stamps.reserveCapacity(stampCount)
        
        for i in 0..<stampCount {
            let t = stampCount == 1 ? 0.5 : Float(i) / Float(stampCount - 1)
            
            // Interpolate position
            let position = mix(segment.startPoint.position, segment.endPoint.position, t)
            
            // Interpolate pressure
            let pressure = mix(segment.startPoint.pressure, segment.endPoint.pressure, t)
            
            // Interpolate tilt
            let tilt = mix(segment.startPoint.tilt, segment.endPoint.tilt, t)
            
            // Interpolate azimuth
            let azimuth = mix(segment.startPoint.azimuth, segment.endPoint.azimuth, t)
            
            // Calculate size with pressure and taper
            var size = params.maxSize * pressure * params.pressureSize
            
            // Apply taper
            let taperFactor = calculateTaperFactor(t, params: params, pressure: pressure)
            size *= taperFactor
            
            // Clamp size
            size = clamp(size, params.minSize, params.maxSize)
            
            // Calculate opacity with pressure and taper
            var opacity = pressure * params.pressureOpacity * taperFactor
            opacity = clamp(opacity, params.minOpacity, params.maxOpacity)
            
            // Calculate rotation
            let direction = segment.endPoint.position - segment.startPoint.position
            let baseRotation = atan2(direction.y, direction.x)
            var rotation = baseRotation
            
            if !params.orientToScreen.isZero {
                // Add shape rotation
                rotation += params.shapeRotation
            }
            
            // Apply dynamics
            let velocity = mix(segment.startPoint.velocity, segment.endPoint.velocity, t)
            size *= 1.0 + velocity * params.speedSize
            opacity *= 1.0 - velocity * params.speedOpacity
            
            // Add jitter
            if params.jitter > 0 {
                let jitterX = Float.random(in: -1...1) * params.jitter * size
                let jitterY = Float.random(in: -1...1) * params.jitter * size
                // Apply jitter to position
            }
            
            // Add scatter
            if params.scatter > 0 {
                let scatterAngle = Float.random(in: 0...2 * Float.pi)
                let scatterDistance = Float.random(in: 0...1) * params.scatter * size
                // Apply scatter to position
            }
            
            // Calculate color with dynamics
            var stampColor = color
            if params.stampColorJitter > 0 {
                stampColor.x += Float.random(in: -params.stampColorJitter...params.stampColorJitter)
                stampColor.y += Float.random(in: -params.stampColorJitter...params.stampColorJitter)
                stampColor.z += Float.random(in: -params.stampColorJitter...params.stampColorJitter)
            }
            
            if params.colorPressure > 0 {
                let pressureInfluence = pressure * params.colorPressure
                stampColor = mix(stampColor, params.secondaryColor, pressureInfluence)
            }
            
            // Apply streamline (simplified - just use interpolated position)
            // Real streamline would use a moving average of recent points
            
            let stamp = BrushStamp(
                position: position,
                size: size,
                rotation: rotation,
                opacity: opacity,
                color: stampColor,
                textureIndex: 0 // Shape texture index
            )
            
            stamps.append(stamp)
        }
        
        return stamps
    }
    
    private func calculateTaperFactor(_ t: Float, params: BrushParameters, pressure: Float) -> Float {
        var factor: Float = 1.0
        
        // Start taper
        if t < params.taperLength {
            let taperT = t / params.taperLength
            if params.classicTaper > 0.5 {
                factor *= taperT * params.tipShape + (1 - params.tipShape)
            } else {
                factor *= pow(taperT, params.taperSize) * params.tipShape + (1 - params.tipShape)
            }
            factor *= taperT * params.taperOpacity + (1 - params.taperOpacity)
        }
        
        // End taper
        if t > 1.0 - params.taperLength {
            let taperT = (1.0 - t) / params.taperLength
            if params.classicTaper > 0.5 {
                factor *= taperT * params.tipShape + (1 - params.tipShape)
            } else {
                factor *= pow(taperT, params.taperSize) * params.tipShape + (1 - params.tipShape)
            }
            factor *= taperT * params.taperOpacity + (1 - params.taperOpacity)
        }
        
        // Pressure taper
        factor *= pow(pressure, params.taperPressure)
        
        // Touch taper
        if params.touchTaper > 0 {
            factor *= 1.0 - params.touchTaper * (1.0 - pressure)
        }
        
        return clamp(factor, 0, 1)
    }
    
    // MARK: - GPU-based Stamp Generation (for high performance)
    func generateStampsGPU(for segment: StrokeSegment, brush: Brush, color: SIMD4<Float>, maxStamps: Int = 1000) -> [BrushStamp] {
        let cached = getCachedBrush(brush)
        let params = brush.toGPUParameters()
        
        let distance = length(segment.endPoint.position - segment.startPoint.position)
        let stampSpacing = params.spacing * params.maxSize
        let stampCount = min(maxStamps, max(1, Int(distance / stampSpacing) + 1))
        
        // Create input buffer
        var input = StampGenerationInput(
            startPoint: segment.startPoint,
            endPoint: segment.endPoint,
            params: params,
            color: color,
            stampCount: UInt32(stampCount),
            canvasSize: SIMD2<UInt32>(2048, 2048) // Would come from canvas
        )
        
        let inputBuffer = device.makeBuffer(bytes: &input, length: MemoryLayout<StampGenerationInput>.stride, options: .storageModeShared)!
        
        // Create output buffer
        let outputBuffer = device.makeBuffer(length: stampCount * MemoryLayout<BrushStamp>.stride, options: .storageModeShared)!
        
        // Execute compute shader
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        
        encoder.setComputePipelineState(stampPipelineState)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(cached.paramsBuffer, offset: 0, index: 2)
        
        if let shapeTexture = cached.shapeTexture {
            encoder.setTexture(shapeTexture, index: 0)
        }
        if let grainTexture = cached.grainTexture {
            encoder.setTexture(grainTexture, index: 1)
        }
        
        let threadsPerGroup = MTLSize(width: 64, height: 1, depth: 1)
        let groups = MTLSize(width: (stampCount + 63) / 64, height: 1, depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Read back results
        var stamps: [BrushStamp] = []
        stamps.reserveCapacity(stampCount)
        let ptr = outputBuffer.contents().bindMemory(to: BrushStamp.self, capacity: stampCount)
        for i in 0..<stampCount {
            stamps.append(ptr[i])
        }
        
        return stamps
    }
    
    // MARK: - Cache Management
    func clearOldCacheEntries(maxAge: TimeInterval = 300) { // 5 minutes
        let now = Date()
        brushCache = brushCache.filter { now.timeIntervalSince($0.value.lastUsed) < maxAge }
    }
    
    func brush(withID id: UUID) -> Brush? {
        return brushCache[id]?.brush
    }
}

// MARK: - Stamp Generation Input (for GPU)
struct StampGenerationInput {
    var startPoint: StrokePoint
    var endPoint: StrokePoint
    var params: BrushParameters
    var color: SIMD4<Float>
    var stampCount: UInt32
    var canvasSize: SIMD2<UInt32>
}

// MARK: - Helper Functions
func mix<T: SIMDScalar>(_ a: T, _ b: T, _ t: T) -> T {
    return a + (b - a) * t
}

func mix(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ t: Float) -> SIMD2<Float> {
    return a + (b - a) * t
}

func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, _ t: Float) -> SIMD4<Float> {
    return a + (b - a) * t
}

func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
    return Swift.max(min, Swift.min(max, value))
}

func length(_ v: SIMD2<Float>) -> Float {
    return sqrt(v.x * v.x + v.y * v.y)
}

func normalize(_ v: SIMD3<Float>) -> SIMD3<Float> {
    let len = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    return len > 0 ? v / len : SIMD3<Float>(0, 0, 1)
}
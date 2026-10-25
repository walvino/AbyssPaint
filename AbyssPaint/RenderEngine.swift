import Foundation
import Metal
import MetalKit
import simd

// MARK: - Render Engine
class RenderEngine {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState!
    private var brushPipelineState: MTLRenderPipelineState!
    private var compositePipelineState: MTLRenderPipelineState!
    private var selectionPipelineState: MTLRenderPipelineState!
    
    // Tile-based rendering
    private let tileSize = 256
    private var tileGrid: TileGrid?
    private var canvasTexture: MTLTexture?
    private var canvasSize: SIMD2<UInt32> = SIMD2<UInt32>(1000, 1000)
    
    // Layer textures
    private var layerTextures: [UUID: MTLTexture] = [:]
    private var layerMaskTextures: [UUID: MTLTexture] = [:]
    private var layerData: [UUID: LayerRenderData] = [:]
    private var layerOrder: [UUID] = []
    
    // Selection
    private var selectionTexture: MTLTexture?
    private var selectionData: SelectionRegion?
    
    // Brush rendering
    private var stampVertexBuffer: MTLBuffer?
    private var stampInstanceBuffer: MTLBuffer?
    private var brushUniformBuffer: MTLBuffer?
    
    // Shaders
    private var shaderLibrary: MTLLibrary
    
    // Time
    private var frameTime: Float = 0
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        
        // Load shaders
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create default library")
        }
        self.shaderLibrary = library
        
        setupPipelines()
        setupBuffers()
    }
    
    private func setupPipelines() {
        // Main render pipeline
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = shaderLibrary.makeFunction(name: "vertex_main")
        renderPipelineDescriptor.fragmentFunction = shaderLibrary.makeFunction(name: "fragment_main")
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Failed to create render pipeline: \(error)")
        }
        
        // Brush pipeline
        let brushPipelineDescriptor = MTLRenderPipelineDescriptor()
        brushPipelineDescriptor.vertexFunction = shaderLibrary.makeFunction(name: "vertex_brush")
        brushPipelineDescriptor.fragmentFunction = shaderLibrary.makeFunction(name: "fragment_brush")
        brushPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        brushPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        brushPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        brushPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        brushPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        brushPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            brushPipelineState = try device.makeRenderPipelineState(descriptor: brushPipelineDescriptor)
        } catch {
            fatalError("Failed to create brush pipeline: \(error)")
        }
        
        // Composite pipeline
        let compositePipelineDescriptor = MTLRenderPipelineDescriptor()
        compositePipelineDescriptor.vertexFunction = shaderLibrary.makeFunction(name: "vertex_composite")
        compositePipelineDescriptor.fragmentFunction = shaderLibrary.makeFunction(name: "fragment_composite")
        compositePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        compositePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        
        do {
            compositePipelineState = try device.makeRenderPipelineState(descriptor: compositePipelineDescriptor)
        } catch {
            fatalError("Failed to create composite pipeline: \(error)")
        }
        
        // Selection pipeline
        let selectionPipelineDescriptor = MTLRenderPipelineDescriptor()
        selectionPipelineDescriptor.vertexFunction = shaderLibrary.makeFunction(name: "vertex_selection")
        selectionPipelineDescriptor.fragmentFunction = shaderLibrary.makeFunction(name: "fragment_selection")
        selectionPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        selectionPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        
        do {
            selectionPipelineState = try device.makeRenderPipelineState(descriptor: selectionPipelineDescriptor)
        } catch {
            fatalError("Failed to create selection pipeline: \(error)")
        }
    }
    
    private func setupBuffers() {
        // Quad vertices for full-screen rendering
        let quadVertices: [QuadVertex] = [
            QuadVertex(position: SIMD2<Float>(-1, -1), texCoord: SIMD2<Float>(0, 1)),
            QuadVertex(position: SIMD2<Float>(1, -1), texCoord: SIMD2<Float>(1, 1)),
            QuadVertex(position: SIMD2<Float>(-1, 1), texCoord: SIMD2<Float>(0, 0)),
            QuadVertex(position: SIMD2<Float>(1, 1), texCoord: SIMD2<Float>(1, 0))
        ]
        
        stampVertexBuffer = device.makeBuffer(bytes: quadVertices, length: MemoryLayout<QuadVertex>.stride * quadVertices.count, options: .storageModeShared)
    }
    
    func setupCanvas(_ canvas: Canvas) {
        canvasSize = SIMD2<UInt32>(UInt32(canvas.width), UInt32(canvas.height))
        
        // Create canvas texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(canvasSize.x),
            height: Int(canvasSize.y),
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private
        canvasTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // Initialize tile grid
        tileGrid = TileGrid(device: device, canvasSize: canvasSize, tileSize: tileSize)
        
        // Create background texture (white)
        clearCanvas()
    }
    
    private func clearCanvas() {
        guard let texture = canvasTexture else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        
        // Clear to white
        let clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        blitEncoder.clearTexture(texture, color: clearColor)
        blitEncoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    func render(to view: MTKView, canvasEngine: CanvasEngine) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        frameTime += 1.0 / 60.0
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // Update uniforms
        updateUniforms(canvasEngine: canvasEngine)
        
        // Composite all layers
        compositeLayers(commandBuffer: commandBuffer)
        
        // Final render to screen
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setFragmentTexture(canvasTexture, index: 0)
        renderEncoder.setVertexBuffer(stampVertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // Draw selection overlay
        if let selection = selectionData, selectionTexture != nil {
            let selectionPassDescriptor = renderPassDescriptor
            let selectionEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: selectionPassDescriptor)!
            selectionEncoder.setRenderPipelineState(selectionPipelineState)
            selectionEncoder.setFragmentTexture(selectionTexture, index: 0)
            selectionEncoder.setVertexBuffer(stampVertexBuffer, offset: 0, index: 0)
            selectionEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            selectionEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func updateUniforms(canvasEngine: CanvasEngine) {
        var uniforms = RenderUniforms(
            projectionMatrix: simd_float4x4.orthographic(
                left: 0, right: Float(canvasSize.x),
                bottom: Float(canvasSize.y), top: 0,
                near: -1, far: 1
            ),
            viewMatrix: canvasEngine.viewMatrix,
            canvasSize: SIMD2<Float>(Float(canvasSize.x), Float(canvasSize.y)),
            zoom: canvasEngine.zoom,
            pan: canvasEngine.pan,
            rotation: canvasEngine.rotation,
            time: frameTime
        )
        
        if brushUniformBuffer == nil {
            brushUniformBuffer = device.makeBuffer(length: MemoryLayout<RenderUniforms>.stride, options: .storageModeShared)
        }
        memcpy(brushUniformBuffer!.contents(), &uniforms, MemoryLayout<RenderUniforms>.stride)
    }
    
    private func compositeLayers(commandBuffer: MTLCommandBuffer) {
        guard let canvasTexture = canvasTexture else { return }
        
        // Clear canvas
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.clearTexture(canvasTexture, color: MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1))
        blitEncoder.endEncoding()
        
        // Composite each layer in order
        for layerID in layerOrder {
            guard let layerData = layerData[layerID],
                  let layerTexture = layerTextures[layerID],
                  layerData.visible else { continue }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = canvasTexture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            encoder.setRenderPipelineState(compositePipelineState)
            encoder.setFragmentTexture(layerTexture, index: 0)
            
            // Set blend mode
            encoder.setFragmentBytes(&layerData.blendMode, length: MemoryLayout<UInt32>.stride, index: 0)
            encoder.setFragmentBytes(&layerData.opacity, length: MemoryLayout<Float>.stride, index: 1)
            
            // Apply mask if present
            if let maskTexture = layerMaskTextures[layerID] {
                encoder.setFragmentTexture(maskTexture, index: 1)
            }
            
            encoder.setVertexBuffer(stampVertexBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }
    }
    
    // MARK: - Layer Management
    func addLayer(_ layerID: UUID, size: SIMD2<UInt32>, blendMode: GPUBlendMode = .normal, opacity: Float = 1.0) {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: Int(size.x),
            height: Int(size.y),
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return }
        
        layerTextures[layerID] = texture
        layerData[layerID] = LayerRenderData(
            id: layerID,
            blendMode: blendMode,
            opacity: opacity,
            visible: true,
            transform: simd_float3x3(diagonal: SIMD3<Float>(1, 1, 1)),
            isClippingMask: false
        )
        layerOrder.append(layerID)
        
        // Clear new layer
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.clearTexture(texture, color: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0))
        blitEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    func removeLayer(_ layerID: UUID) {
        layerTextures.removeValue(forKey: layerID)
        layerMaskTextures.removeValue(forKey: layerID)
        layerData.removeValue(forKey: layerID)
        layerOrder.removeAll { $0 == layerID }
    }
    
    func duplicateLayerTexture(_ fromID: UUID, to toID: UUID) {
        guard let sourceTexture = layerTextures[fromID],
              let sourceData = layerData[fromID] else { return }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: sourceTexture.width,
            height: sourceTexture.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private
        
        guard let newTexture = device.makeTexture(descriptor: textureDescriptor) else { return }
        
        // Copy texture
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.copy(from: sourceTexture, to: newTexture)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        
        layerTextures[toID] = newTexture
        layerData[toID] = sourceData
        layerData[toID]?.id = toID
    }
    
    func mergeLayer(_ fromID: UUID, into toID: UUID) {
        guard let fromTexture = layerTextures[fromID],
              let toTexture = layerTextures[toID],
              let fromData = layerData[fromID] else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = toTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        encoder.setRenderPipelineState(compositePipelineState)
        encoder.setFragmentTexture(fromTexture, index: 0)
        encoder.setFragmentBytes(&fromData.blendMode, length: MemoryLayout<UInt32>.stride, index: 0)
        encoder.setFragmentBytes(&fromData.opacity, length: MemoryLayout<Float>.stride, index: 1)
        encoder.setVertexBuffer(stampVertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Remove source layer
        removeLayer(fromID)
    }
    
    func addMask(to layerID: UUID) {
        guard let layerTexture = layerTextures[layerID] else { return }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: layerTexture.width,
            height: layerTexture.height,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .private
        
        guard let maskTexture = device.makeTexture(descriptor: textureDescriptor) else { return }
        
        // Clear mask to white (fully visible)
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.clearTexture(maskTexture, color: MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1))
        blitEncoder.endEncoding()
        commandBuffer.commit()
        
        layerMaskTextures[layerID] = maskTexture
        layerData[layerID]?.hasMask = true
    }
    
    func invalidateLayerCache() {
        // Invalidate any cached composite
    }
    
    // MARK: - Drawing
    func drawStrokeSegment(_ segment: StrokeSegment, onLayer layerID: UUID, withBrush brush: Brush, color: SIMD4<Float>) {
        guard let layerTexture = layerTextures[layerID] else { return }
        
        // Generate stamps for this segment
        let stamps = brushEngine.generateStamps(for: segment, brush: brush, color: color)
        
        // Render stamps to layer texture
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = layerTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        encoder.setRenderPipelineState(brushPipelineState)
        
        // Set brush parameters
        var brushParams = brush.toGPUParameters()
        encoder.setFragmentBytes(&brushParams, length: MemoryLayout<BrushParameters>.stride, index: 0)
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
        
        // Set shape/grain textures if available
        if let shapeTexture = brush.shapeTexture {
            encoder.setFragmentTexture(shapeTexture, index: 0)
        }
        if let grainTexture = brush.grainTexture {
            encoder.setFragmentTexture(grainTexture, index: 1)
        }
        
        // Render stamps as instanced quads
        if !stamps.isEmpty {
            // Update instance buffer
            if stampInstanceBuffer == nil || stampInstanceBuffer!.length < stamps.count * MemoryLayout<BrushStamp>.stride {
                stampInstanceBuffer = device.makeBuffer(length: stamps.count * MemoryLayout<BrushStamp>.stride, options: .storageModeShared)
            }
            memcpy(stampInstanceBuffer!.contents(), stamps, stamps.count * MemoryLayout<BrushStamp>.stride)
            
            encoder.setVertexBuffer(stampInstanceBuffer, offset: 0, index: 1)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: stamps.count)
        }
        
        encoder.endEncoding()
        commandBuffer.commit()
    }
    
    func removeStroke(_ strokeID: UUID, fromLayer layerID: UUID) {
        // Would need to re-render layer without this stroke
        // For now, mark layer as dirty
        invalidateLayerCache()
    }
    
    func redrawStroke(_ stroke: Stroke, withBrush brush: Brush, color: SIMD4<Float>) {
        // Reconstruct stroke from points and re-render
        for i in 1..<stroke.points.count {
            let segment = StrokeSegment(
                startPoint: stroke.points[i-1],
                endPoint: stroke.points[i],
                stamps: []
            )
            drawStrokeSegment(segment, onLayer: stroke.layerID, withBrush: brush, color: color)
        }
    }
    
    // MARK: - Selection
    func updateSelection(_ selection: SelectionRegion?) {
        selectionData = selection
        // Update selection texture
    }
    
    // MARK: - Transform
    func updateTransform(_ transform: TransformState) {
        layerData[transform.layerID]?.transform = transform.transform
    }
    
    func commitTransform(_ transform: TransformState) {
        // Bake transform into layer texture
        guard let layerTexture = layerTextures[transform.layerID] else { return }
        // Apply transform
    }
    
    func cancelTransform() {
        // Revert transform
    }
}

// MARK: - Tile Grid
class TileGrid {
    let device: MTLDevice
    let canvasSize: SIMD2<UInt32>
    let tileSize: Int
    var tiles: [Tile] = []
    
    init(device: MTLDevice, canvasSize: SIMD2<UInt32>, tileSize: Int) {
        self.device = device
        self.canvasSize = canvasSize
        self.tileSize = tileSize
        buildGrid()
    }
    
    private func buildGrid() {
        let tilesX = (Int(canvasSize.x) + tileSize - 1) / tileSize
        let tilesY = (Int(canvasSize.y) + tileSize - 1) / tileSize
        
        for y in 0..<tilesY {
            for x in 0..<tilesX {
                let tile = Tile(
                    x: x,
                    y: y,
                    bounds: calculateTileBounds(x: x, y: y),
                    dirty: true
                )
                tiles.append(tile)
            }
        }
    }
    
    private func calculateTileBounds(x: Int, y: Int) -> (min: SIMD2<UInt32>, max: SIMD2<UInt32>) {
        let minX = UInt32(x * tileSize)
        let minY = UInt32(y * tileSize)
        let maxX = Swift.min(UInt32((x + 1) * tileSize), canvasSize.x)
        let maxY = Swift.min(UInt32((y + 1) * tileSize), canvasSize.y)
        return (SIMD2<UInt32>(minX, minY), SIMD2<UInt32>(maxX, maxY))
    }
    
    func markDirty(_ rect: (min: SIMD2<UInt32>, max: SIMD2<UInt32>)) {
        for tile in tiles {
            if tile.bounds.min.x < rect.max.x && tile.bounds.max.x > rect.min.x &&
               tile.bounds.min.y < rect.max.y && tile.bounds.max.y > rect.min.y {
                tile.dirty = true
            }
        }
    }
    
    func uploadDirtyTiles() {
        for tile in tiles where tile.dirty {
            // Upload tile to GPU
            tile.dirty = false
        }
    }
}

struct Tile {
    let x: Int
    let y: Int
    let bounds: (min: SIMD2<UInt32>, max: SIMD2<UInt32>)
    var dirty: Bool
}

// MARK: - Layer Render Data
struct LayerRenderData {
    var id: UUID
    var blendMode: GPUBlendMode
    var opacity: Float
    var visible: Bool
    var transform: simd_float3x3
    var isClippingMask: Bool
    var clippingToLayerID: UUID?
    var hasMask: Bool = false
    var filterStack: [FilterData] = []
}

// MARK: - Simd Extensions
extension simd_float4x4 {
    static func orthographic(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
        let rl = right - left
        let tb = top - bottom
        let fn = far - near
        
        return simd_float4x4(
            SIMD4<Float>(2/rl, 0, 0, 0),
            SIMD4<Float>(0, 2/tb, 0, 0),
            SIMD4<Float>(0, 0, -2/fn, 0),
            SIMD4<Float>(-(right+left)/rl, -(top+bottom)/tb, -(far+near)/fn, 1)
        )
    }
}

extension CanvasEngine {
    var viewMatrix: simd_float4x4 {
        var matrix = simd_float4x4.identity
        matrix = matrix.translatedBy(x: -pan.x, y: -pan.y, z: 0)
        matrix = matrix.rotatedBy(angle: rotation, axis: SIMD3<Float>(0, 0, 1))
        matrix = matrix.scaledBy(x: zoom, y: zoom, z: 1)
        return matrix
    }
}

extension simd_float4x4 {
    static var identity: simd_float4x4 {
        return simd_float4x4(diagonal: SIMD4<Float>(1, 1, 1, 1))
    }
    
    func translatedBy(x: Float, y: Float, z: Float) -> simd_float4x4 {
        var result = self
        result.columns.3 = SIMD4<Float>(x, y, z, 1)
        return result
    }
    
    func rotatedBy(angle: Float, axis: SIMD3<Float>) -> simd_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        let n = normalize(axis)
        
        let rot = simd_float4x4(
            SIMD4<Float>(c + (1-c)*n.x*n.x, (1-c)*n.x*n.y - s*n.z, (1-c)*n.x*n.z + s*n.y, 0),
            SIMD4<Float>((1-c)*n.y*n.x + s*n.z, c + (1-c)*n.y*n.y, (1-c)*n.y*n.z - s*n.x, 0),
            SIMD4<Float>((1-c)*n.z*n.x - s*n.y, (1-c)*n.z*n.y + s*n.x, c + (1-c)*n.z*n.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        return self * rot
    }
    
    func scaledBy(x: Float, y: Float, z: Float) -> simd_float4x4 {
        var result = self
        result.columns.0 *= x
        result.columns.1 *= y
        result.columns.2 *= z
        return result
    }
}
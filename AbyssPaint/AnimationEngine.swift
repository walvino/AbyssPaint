import Foundation
import Metal
import CoreData

// MARK: - Animation Engine
class AnimationEngine: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentFrame: Int = 0
    @Published var fps: Int = 12
    @Published var onionSkinEnabled: Bool = true
    @Published var onionSkinFramesBefore: Int = 1
    @Published var onionSkinFramesAfter: Int = 1
    @Published var onionSkinOpacity: Float = 0.3
    @Published var onionSkinColorBefore: SIMD4<Float> = SIMD4<Float>(1, 0.5, 0, 1) // Orange
    @Published var onionSkinColorAfter: SIMD4<Float> = SIMD4<Float>(0, 0.5, 1, 1)  // Blue
    @Published var playbackMode: AnimationPlaybackMode = .loop
    @Published var holdDurations: [Int: Int] = [:] // frameIndex -> hold duration
    
    private var device: MTLDevice
    private var renderEngine: RenderEngine?
    private var canvasEngine: CanvasEngine?
    private var frameTimer: Timer?
    private var frameTextures: [Int: MTLTexture] = [:]
    private var frameLayers: [Int: UUID] = [:]
    
    init() {
        self.device = MTLCreateSystemDefaultDevice()!
    }
    
    func setup(canvasEngine: CanvasEngine, renderEngine: RenderEngine) {
        self.canvasEngine = canvasEngine
        self.renderEngine = renderEngine
    }
    
    // MARK: - Timeline Management
    func enableAnimation(for canvas: Canvas) {
        let context = PersistenceController.shared.container.viewContext
        canvas.animationEnabled = true
        try? context.save()
        rebuildTimeline()
    }
    
    func disableAnimation(for canvas: Canvas) {
        let context = PersistenceController.shared.container.viewContext
        canvas.animationEnabled = false
        try? context.save()
        frameLayers.removeAll()
        frameTextures.removeAll()
    }
    
    func rebuildTimeline() {
        guard let canvas = canvasEngine?.currentCanvas else { return }
        
        frameLayers.removeAll()
        frameTextures.removeAll()
        
        if let frames = canvas.animationFrames?.toArray(ofType: AnimationFrame.self).sorted(by: { $0.frameIndex < $1.frameIndex }) {
            for frame in frames {
                frameLayers[Int(frame.frameIndex)] = frame.layer?.id
                holdDurations[Int(frame.frameIndex)] = Int(frame.holdDuration)
            }
        }
        
        currentFrame = 0
        renderFrame(0)
    }
    
    func addFrame(at index: Int? = nil, layer: Layer? = nil, holdDuration: Int = 1) {
        guard let canvas = canvasEngine?.currentCanvas else { return }
        let context = PersistenceController.shared.container.viewContext
        
        let frameIndex = index ?? (frameLayers.keys.max() ?? -1) + 1
        let targetLayer = layer ?? canvasEngine?.currentLayer
        
        guard let targetLayer = targetLayer else { return }
        
        let frame = AnimationFrame(context: context)
        frame.id = UUID()
        frame.frameIndex = Int32(frameIndex)
        frame.holdDuration = Int32(holdDuration)
        frame.canvas = canvas
        frame.layer = targetLayer
        
        // Shift existing frames
        for (existingIndex, existingLayerID) in frameLayers where existingIndex >= frameIndex {
            frameLayers[existingIndex + 1] = existingLayerID
            holdDurations[existingIndex + 1] = holdDurations[existingIndex] ?? 1
        }
        
        frameLayers[frameIndex] = targetLayer.id
        holdDurations[frameIndex] = holdDuration
        
        try? context.save()
        renderFrame(frameIndex)
    }
    
    func removeFrame(at index: Int) {
        guard let canvas = canvasEngine?.currentCanvas else { return }
        let context = PersistenceController.shared.container.viewContext
        
        // Remove from Core Data
        if let frames = canvas.animationFrames?.toArray(ofType: AnimationFrame.self) {
            for frame in frames where frame.frameIndex == index {
                context.delete(frame)
            }
        }
        
        // Shift frames
        var newFrameLayers: [Int: UUID] = [:]
        var newHoldDurations: [Int: Int] = [:]
        
        for (existingIndex, layerID) in frameLayers.sorted(by: { $0.key < $1.key }) {
            if existingIndex < index {
                newFrameLayers[existingIndex] = layerID
                newHoldDurations[existingIndex] = holdDurations[existingIndex] ?? 1
            } else if existingIndex > index {
                newFrameLayers[existingIndex - 1] = layerID
                newHoldDurations[existingIndex - 1] = holdDurations[existingIndex] ?? 1
            }
        }
        
        frameLayers = newFrameLayers
        holdDurations = newHoldDurations
        frameTextures.removeValue(forKey: index)
        
        // Re-index in Core Data
        // Would need to update frameIndex for all frames > index
        
        try? context.save()
        
        if currentFrame >= frameLayers.count {
            currentFrame = max(0, frameLayers.count - 1)
        }
        
        renderFrame(currentFrame)
    }
    
    func duplicateFrame(at index: Int) {
        addFrame(at: index + 1, holdDuration: holdDurations[index] ?? 1)
    }
    
    func moveFrame(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex != toIndex,
              let layerID = frameLayers[fromIndex] else { return }
        
        var newFrameLayers: [Int: UUID] = [:]
        var newHoldDurations: [Int: Int] = [:]
        
        let sortedIndices = frameLayers.keys.sorted()
        
        for i in 0..<sortedIndices.count {
            let oldIndex = sortedIndices[i]
            var newIndex = oldIndex
            
            if oldIndex == fromIndex {
                newIndex = toIndex
            } else if fromIndex < toIndex && oldIndex > fromIndex && oldIndex <= toIndex {
                newIndex = oldIndex - 1
            } else if fromIndex > toIndex && oldIndex >= toIndex && oldIndex < fromIndex {
                newIndex = oldIndex + 1
            }
            
            newFrameLayers[newIndex] = frameLayers[oldIndex]!
            newHoldDurations[newIndex] = holdDurations[oldIndex] ?? 1
        }
        
        frameLayers = newFrameLayers
        holdDurations = newHoldDurations
        
        // Update Core Data
        // renderFrame for affected frames
    }
    
    func setHoldDuration(_ duration: Int, forFrame index: Int) {
        holdDurations[index] = max(1, duration)
        // Update Core Data
    }
    
    // MARK: - Frame Rendering
    func renderFrame(_ index: Int) {
        guard let canvasEngine = canvasEngine,
              let renderEngine = renderEngine,
              let layerID = frameLayers[index] else { return }
        
        // Show the layer for this frame
        canvasEngine.currentLayer = canvasEngine.layers.first { $0.id == layerID }
        
        // Render frame to texture for onion skinning
        if let texture = renderFrameToTexture() {
            frameTextures[index] = texture
        }
    }
    
    private func renderFrameToTexture() -> MTLTexture? {
        // Render current canvas state to texture
        // This would use the render engine
        return nil
    }
    
    func getFrameTexture(_ index: Int) -> MTLTexture? {
        if let texture = frameTextures[index] {
            return texture
        }
        renderFrame(index)
        return frameTextures[index]
    }
    
    // MARK: - Playback
    func play() {
        guard !frameLayers.isEmpty else { return }
        isPlaying = true
        
        let frameDuration = 1.0 / Double(fps)
        frameTimer = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
    }
    
    func pause() {
        isPlaying = false
        frameTimer?.invalidate()
        frameTimer = nil
    }
    
    func stop() {
        pause()
        currentFrame = 0
        canvasEngine?.currentLayer = canvasEngine?.layers.first { $0.id == frameLayers[0] }
    }
    
    private func advanceFrame() {
        let frameCount = frameLayers.count
        guard frameCount > 0 else { return }
        
        let holdDuration = holdDurations[currentFrame] ?? 1
        // For simplicity, advance by 1 frame per tick
        // Real implementation would track hold duration
        
        currentFrame += 1
        
        if currentFrame >= frameCount {
            switch playbackMode {
            case .loop:
                currentFrame = 0
            case .pingPong:
                // Would need direction tracking
                currentFrame = frameCount - 2
            case .oneShot:
                currentFrame = frameCount - 1
                pause()
                return
            }
        }
        
        renderFrame(currentFrame)
    }
    
    func gotoFrame(_ index: Int) {
        let clampedIndex = max(0, min(index, frameLayers.count - 1))
        currentFrame = clampedIndex
        renderFrame(clampedIndex)
    }
    
    // MARK: - Onion Skinning
    func getOnionSkinTextures() -> (before: [MTLTexture], after: [MTLTexture]) {
        var before: [MTLTexture] = []
        var after: [MTLTexture] = []
        
        for i in 1...onionSkinFramesBefore {
            let index = currentFrame - i
            if index >= 0, let texture = getFrameTexture(index) {
                before.append(texture)
            } else if playbackMode == .loop {
                let wrappedIndex = (frameLayers.count + index) % frameLayers.count
                if let texture = getFrameTexture(wrappedIndex) {
                    before.append(texture)
                }
            }
        }
        
        for i in 1...onionSkinFramesAfter {
            let index = currentFrame + i
            if index < frameLayers.count, let texture = getFrameTexture(index) {
                after.append(texture)
            } else if playbackMode == .loop {
                let wrappedIndex = index % frameLayers.count
                if let texture = getFrameTexture(wrappedIndex) {
                    after.append(texture)
                }
            }
        }
        
        return (before, after)
    }
    
    // MARK: - Export
    func exportAnimation(format: AnimationExportFormat, url: URL, progress: @escaping (Float) -> Void) {
        let frameCount = frameLayers.count
        guard frameCount > 0 else { return }
        
        switch format {
        case .gif:
            exportGIF(to: url, progress: progress)
        case .mp4:
            exportMP4(to: url, progress: progress)
        case .hevc:
            exportHEVC(to: url, progress: progress)
        case .pngSequence:
            exportPNGSequence(to: url, progress: progress)
        }
    }
    
    private func exportGIF(to url: URL, progress: @escaping (Float) -> Void) {
        // GIF export using ImageIO
        // Would render each frame and write to GIF
    }
    
    private func exportMP4(to url: URL, progress: @escaping (Float) -> Void) {
        // MP4 export using AVFoundation
    }
    
    private func exportHEVC(to url: URL, progress: @escaping (Float) -> Void) {
        // HEVC export using AVFoundation
    }
    
    private func exportPNGSequence(to url: URL, progress: @escaping (Float) -> Void) {
        let frameCount = frameLayers.count
        let directory = url.deletingLastPathComponent().appendingPathComponent(url.deletingPathExtension().lastPathComponent + "_frames")
        
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        for i in 0..<frameCount {
            if let texture = getFrameTexture(i),
               let data = renderEngine?.dataFromTexture(texture),
               let image = NSImage(data: data),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                
                let frameURL = directory.appendingPathComponent(String(format: "frame_%04d.png", i))
                try? pngData.write(to: frameURL)
            }
            
            progress(Float(i + 1) / Float(frameCount))
        }
    }
}

// MARK: - Animation Export Format
enum AnimationExportFormat {
    case gif
    case mp4
    case hevc
    case pngSequence
    case imageSequence
}

// MARK: - Animation Playback Mode
enum AnimationPlaybackMode: Int16, CaseIterable {
    case loop = 0
    case pingPong = 1
    case oneShot = 2
}

// MARK: - Animation Frame Data (for export)
struct AnimationFrameData {
    let index: Int
    let layerID: UUID
    let holdDuration: Int
    let texture: MTLTexture?
    let duration: TimeInterval // In seconds at current FPS
}
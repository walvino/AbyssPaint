import SwiftUI

struct AnimationTimeline: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @StateObject private var animationEngine = AnimationEngine()
    @State private var dragFrame: Int?
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("TIMELINE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Spacer()
                
                // Playback controls
                HStack(spacing: 4) {
                    Button(action: { animationEngine.gotoFrame(0) }) {
                        Image(systemName: "backward.end.fill")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if animationEngine.currentFrame > 0 {
                            animationEngine.gotoFrame(animationEngine.currentFrame - 1)
                        }
                    }) {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if animationEngine.isPlaying {
                            animationEngine.pause()
                        } else {
                            animationEngine.play()
                        }
                    }) {
                        Image(systemName: animationEngine.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(animationEngine.isPlaying ? .red : .primary)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])
                    
                    Button(action: {
                        if animationEngine.currentFrame < animationEngine.frameLayers.count - 1 {
                            animationEngine.gotoFrame(animationEngine.currentFrame + 1)
                        }
                    }) {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { animationEngine.gotoFrame(animationEngine.frameLayers.count - 1) }) {
                        Image(systemName: "forward.end.fill")
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .frame(height: 20)
                
                // FPS
                HStack(spacing: 4) {
                    Text("FPS")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("", value: $animationEngine.fps, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .font(.system(size: 11))
                }
                
                Divider()
                    .frame(height: 20)
                
                // Onion skin
                HStack(spacing: 4) {
                    Toggle("", isOn: $animationEngine.onionSkinEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                    Text("Onion Skin")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                if animationEngine.onionSkinEnabled {
                    HStack(spacing: 4) {
                        Text("Before")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Stepper("", value: $animationEngine.onionSkinFramesBefore, in: 0...5)
                            .frame(width: 60)
                        
                        Text("After")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Stepper("", value: $animationEngine.onionSkinFramesAfter, in: 0...5)
                            .frame(width: 60)
                        
                        Text("Opacity")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Slider(value: $animationEngine.onionSkinOpacity, in: 0...1)
                            .frame(width: 80)
                    }
                }
                
                Divider()
                    .frame(height: 20)
                
                Button(action: {
                    animationEngine.addFrame()
                }) {
                    Image(systemName: "plus.rectangle")
                }
                .buttonStyle(.plain)
                .help("Add Frame")
                
                Button(action: {
                    // Show settings
                }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    canvasEngine.showingAnimationTimeline = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Frame strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    // Add frame button
                    Button(action: {
                        animationEngine.addFrame()
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .foregroundColor(.secondary)
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Add")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 72)
                    }
                    .buttonStyle(.plain)
                    
                    // Frames
                    ForEach(Array(animationEngine.frameLayers.keys.sorted()), id: \.self) { index in
                        FrameCell(
                            index: index,
                            layerID: animationEngine.frameLayers[index] ?? UUID(),
                            holdDuration: animationEngine.holdDurations[index] ?? 1,
                            isCurrent: animationEngine.currentFrame == index,
                            isSelected: animationEngine.currentFrame == index,
                            onTap: { animationEngine.gotoFrame(index) },
                            onDrag: { dragFrame = index },
                            onDrop: { targetIndex in
                                animationEngine.moveFrame(from: index, to: targetIndex)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(height: 120)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Onion skin preview (when playing)
            if animationEngine.onionSkinEnabled && animationEngine.isPlaying {
                OnionSkinPreview()
                    .environmentObject(animationEngine)
                    .frame(height: 60)
            }
        }
        .frame(height: 200)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct FrameCell: View {
    let index: Int
    let layerID: UUID
    let holdDuration: Int
    let isCurrent: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDrag: () -> Void
    let onDrop: (Int) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Frame thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                isCurrent ? Color.accentColor : (isSelected ? Color.accentColor.opacity(0.5) : Color.clear),
                                lineWidth: isCurrent || isSelected ? 2 : 0
                            )
                    )
                
                // Frame number
                Text("\(index + 1)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                // Hold duration badge
                if holdDuration > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(holdDuration)x")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor)
                                .cornerRadius(3)
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
            .onTapGesture { onTap() }
            .onDrag {
                onDrag()
                return NSItemProvider(object: "\(index)" as NSString)
            }
            .onDrop(of: [.text], delegate: FrameDropDelegate(targetIndex: index, onDrop: onDrop))
            
            // Layer name
            Text("Layer")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 72)
        }
        .frame(width: 72)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Duplicate") {
                // Duplicate frame
            }
            .keyboardShortcut("d", modifiers: .command)
            
            Button("Delete") {
                // Delete frame
            }
            
            Divider()
            
            Button("Hold Duration") {
                // Show hold duration picker
            }
            
            Divider()
            
            Button("Add Frame Before") {
                // Add frame before
            }
            
            Button("Add Frame After") {
                // Add frame after
            }
        }
    }
}

struct FrameDropDelegate: DropDelegate {
    let targetIndex: Int
    let onDrop: (Int) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        if let item = info.itemProviders(for: [.text]).first {
            item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                if let data = data as? Data,
                   let string = String(data: data, encoding: .utf8),
                   let sourceIndex = Int(string) {
                    DispatchQueue.main.async {
                        if sourceIndex != targetIndex {
                            onDrop(sourceIndex)
                        }
                    }
                }
            }
            return true
        }
        return false
    }
}

struct OnionSkinPreview: View {
    @EnvironmentObject var animationEngine: AnimationEngine
    @State private var previewFrames: [(before: [MTLTexture], after: [MTLTexture])] = []
    
    var body: some View {
        HStack(spacing: 4) {
            // Before frames
            ForEach(0..<animationEngine.onionSkinFramesBefore, id: \.self) { i in
                if let texture = animationEngine.getFrameTexture(animationEngine.currentFrame - i - 1) {
                    MTLTextureView(texture: texture)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                        )
                        .opacity(animationEngine.onionSkinOpacity * (1 - Double(i) * 0.2))
                }
            }
            
            // Current frame
            if let texture = animationEngine.getFrameTexture(animationEngine.currentFrame) {
                MTLTextureView(texture: texture)
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
            }
            
            // After frames
            ForEach(0..<animationEngine.onionSkinFramesAfter, id: \.self) { i in
                if let texture = animationEngine.getFrameTexture(animationEngine.currentFrame + i + 1) {
                    MTLTextureView(texture: texture)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                        )
                        .opacity(animationEngine.onionSkinOpacity * (1 - Double(i) * 0.2))
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

struct MTLTextureView: NSViewRepresentable {
    let texture: MTLTexture
    
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = false
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        return view
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        guard let drawable = nsView.currentDrawable else { return }
        
        let commandBuffer = nsView.device!.makeCommandQueue()!.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1), to: drawable.texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blitEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
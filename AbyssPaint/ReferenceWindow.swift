import SwiftUI
import MetalKit

struct ReferenceWindow: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var referenceImage: NSImage?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @State private var showingImagePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("REFERENCE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Spacer()
                
                Button(action: { showingImagePicker = true }) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Load Image")
                .fileImporter(isPresented: $showingImagePicker, allowedContentTypes: [.image]) { result in
                    if case .success(let url) = result,
                       let image = NSImage(contentsOf: url) {
                        referenceImage = image
                    }
                }
                
                Button(action: {
                    canvasEngine.showingReferenceWindow = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Canvas
            GeometryReader { geometry in
                ZStack {
                    // Checkerboard background
                    CheckerboardPattern()
                    
                    if let image = referenceImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = max(0.125, min(16.0, scale * value))
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            if !isDragging {
                                                isDragging = true
                                            }
                                            offset = CGSize(
                                                width: offset.width + value.translation.width,
                                                height: offset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            isDragging = false
                                        }
                                )
                            )
                            .onTapGesture(count: 2) {
                                // Double-click to fit
                                fitImage(in: geometry.size, image: image)
                            }
                    } else {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Drop an image here\nor click + to load")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Eyedropper indicator
                    if canvasEngine.currentTool == .eyedropper,
                       let image = referenceImage {
                        EyedropperOverlay(image: image, scale: scale, offset: offset, geometry: geometry)
                    }
                }
            }
            .frame(minWidth: 200, minHeight: 200)
            
            Divider()
            
            // Controls
            HStack {
                Button(action: { scale = 1.0; offset = .zero }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .help("Reset View")
                
                Button(action: { fitImageIfPossible() }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .help("Fit to Window")
                
                Slider(value: $scale, in: 0.125...16.0) {
                    Text("Zoom")
                } minimumValueLabel: {
                    Text("12.5%")
                } maximumValueLabel: {
                    Text("1600%")
                }
                .frame(width: 120)
                
                Spacer()
                
                Text("\(Int(scale * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func fitImageIfPossible() {
        // Would need access to geometry and image
    }
    
    private func fitImage(in size: CGSize, image: NSImage) {
        let imageSize = image.size
        let scaleX = size.width / imageSize.width * 0.9
        let scaleY = size.height / imageSize.height * 0.9
        scale = min(scaleX, scaleY)
        offset = .zero
    }
}

struct CheckerboardPattern: View {
    let squareSize: CGFloat = 16
    
    var body: some View {
        GeometryReader { geometry in
            let columns = Int(geometry.size.width / squareSize) + 1
            let rows = Int(geometry.size.height / squareSize) + 1
            
            ForEach(0..<columns, id: \.self) { col in
                ForEach(0..<rows, id: \.self) { row in
                    Rectangle()
                        .fill((col + row) % 2 == 0 ? Color(NSColor.controlBackgroundColor) : Color(NSColor.windowBackgroundColor))
                        .frame(width: squareSize, height: squareSize)
                        .position(
                            x: CGFloat(col) * squareSize + squareSize/2,
                            y: CGFloat(row) * squareSize + squareSize/2
                        )
                }
            }
        }
    }
}

struct EyedropperOverlay: View {
    let image: NSImage
    let scale: CGFloat
    let offset: CGSize
    let geometry: GeometryProxy
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var sampleColor: Color = .clear
    @State private var samplePosition: CGPoint = .zero
    
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            samplePosition = value.location
                            sampleColor = sampleColorAt(value.location)
                        }
                        .onEnded { _ in
                            // Set color on release
                            if let nsColor = NSColor(sampleColor).usingColorSpace(.sRGB) {
                                canvasEngine.currentColor = SIMD4<Float>(
                                    Float(nsColor.redComponent),
                                    Float(nsColor.greenComponent),
                                    Float(nsColor.blueComponent),
                                    Float(nsColor.alphaComponent)
                                )
                                canvasEngine.currentTool = .brush
                            }
                        }
                )
            
            // Eyedropper cursor
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .stroke(Color.black, lineWidth: 1)
                    .frame(width: 40, height: 40)
                
                // Sample preview
                Circle()
                    .fill(sampleColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: 25, y: -25)
            }
            .position(samplePosition)
            .allowsHitTesting(false)
        }
    }
    
    private func sampleColorAt(_ point: CGPoint) -> Color {
        // Convert point to image coordinates
        let imageSize = image.size
        let viewSize = geometry.size
        
        let imagePoint = CGPoint(
            x: (point.x - viewSize.width/2 - offset.width) / scale + imageSize.width/2,
            y: (point.y - viewSize.height/2 - offset.height) / scale + imageSize.height/2
        )
        
        // Sample from image (simplified)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return .clear
        }
        
        let x = Int(imagePoint.x)
        let y = Int(imagePoint.y)
        let width = cgImage.width
        let height = cgImage.height
        
        guard x >= 0, x < width, y >= 0, y < height else { return .clear }
        
        let bytesPerRow = cgImage.bytesPerRow
        let pixelIndex = y * bytesPerRow + x * 4
        
        let r = bytes[pixelIndex]
        let g = bytes[pixelIndex + 1]
        let b = bytes[pixelIndex + 2]
        let a = bytes[pixelIndex + 3]
        
        return Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}
import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var canvasEngine = CanvasEngine.shared
    @StateObject private var preferences = Preferences.shared
    @StateObject private var tabletInput = TabletInput()
    
    @State private var showingNewCanvasSheet = false
    @State private var showingPreferences = false
    @State private var showingBrushLibrary = false
    @State private var showingColorPicker = false
    @State private var showingLayerPanel = true
    @State private var showingReferenceWindow = false
    @State private var showingAnimationTimeline = false
    
    var body: some View {
        ZStack {
            // Main canvas area
            CanvasView()
                .environmentObject(canvasEngine)
                .environmentObject(tabletInput)
            
            // Floating panels
            if showingLayerPanel {
                LayerPanel()
                    .environmentObject(canvasEngine)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            if showingBrushLibrary {
                BrushLibraryPanel()
                    .environmentObject(canvasEngine)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            if showingColorPicker {
                ColorPickerPanel()
                    .environmentObject(canvasEngine)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            
            if showingReferenceWindow {
                ReferenceWindow()
                    .environmentObject(canvasEngine)
                    .transition(.scale.combined(with: .opacity))
            }
            
            if showingAnimationTimeline && canvasEngine.currentCanvas?.animationEnabled == true {
                AnimationTimeline()
                    .environmentObject(canvasEngine)
                    .environmentObject(AnimationEngine())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Toolbar
            VStack {
                TopToolbar()
                    .environmentObject(canvasEngine)
                    .environmentObject(preferences)
                
                Spacer()
                
                BottomToolbar()
                    .environmentObject(canvasEngine)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingNewCanvasSheet) {
            NewCanvasSheet()
                .environmentObject(canvasEngine)
        }
        .sheet(isPresented: $showingPreferences) {
            SettingsView()
                .environmentObject(preferences)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newCanvasRequested)) { _ in
            showingNewCanvasSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleLayersPanel)) { _ in
            withAnimation { showingLayerPanel.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleBrushesPanel)) { _ in
            withAnimation { showingBrushLibrary.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleColorPanel)) { _ in
            withAnimation { showingColorPicker.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDocumentRequested)) { _ in
            openDocument()
        }
    }
    
    private func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "abysspaint")!,
            UTType(filenameExtension: "psd")!,
            UTType.png,
            UTType.jpeg,
            UTType.tiff
        ]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            if let canvas = FileIO().importCanvas(from: url) {
                canvasEngine.loadCanvas(canvas)
            }
        }
    }
}

// MARK: - Top Toolbar
struct TopToolbar: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @EnvironmentObject var preferences: Preferences
    @State private var showingFileMenu = false
    @State private var showingEditMenu = false
    @State private var showingCanvasMenu = false
    @State private var showingLayerMenu = false
    @State private var showingViewMenu = false
    @State private var showingWindowMenu = false
    @State private var showingHelpMenu = false
    
    var body: some View {
        HStack(spacing: 0) {
            // App menu
            Menu("AbyssPaint") {
                Button("About AbyssPaint") {}
                Divider()
                Button("Preferences...") {
                    NotificationCenter.default.post(name: .showPreferences, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
                Divider()
                Button("Hide AbyssPaint") {}
                    .keyboardShortcut("h", modifiers: .command)
                Button("Hide Others") {}
                    .keyboardShortcut("h", modifiers: [.command, .option])
                Button("Show All") {}
                Divider()
                Button("Quit AbyssPaint") {}
                    .keyboardShortcut("q", modifiers: .command)
            }
            .menuStyle(.borderlessButton)
            
            // File menu
            Menu("File") {
                Button("New Canvas...") {
                    NotificationCenter.default.post(name: .newCanvasRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Open...") {
                    NotificationCenter.default.post(name: .openDocumentRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Save") {
                    canvasEngine.saveCanvas()
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Save As...") {}
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Export...") {}
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Import...") {}
                Button("Import Brushes...") {}
                Button("Import Palette...") {}
            }
            
            // Edit menu
            Menu("Edit") {
                Button("Undo") {
                    NotificationCenter.default.post(name: .undoRequested, object: nil)
                }
                .keyboardShortcut("z", modifiers: .command)
                
                Button("Redo") {
                    NotificationCenter.default.post(name: .redoRequested, object: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Cut") {}
                    .keyboardShortcut("x", modifiers: .command)
                Button("Copy") {}
                    .keyboardShortcut("c", modifiers: .command)
                Button("Paste") {}
                    .keyboardShortcut("v", modifiers: .command)
                Button("Duplicate") {
                    if let layer = canvasEngine.currentLayer {
                        canvasEngine.duplicateLayer(layer)
                    }
                }
                .keyboardShortcut("j", modifiers: .command)
                Button("Delete") {}
                    .keyboardShortcut(.delete, modifiers: .command)
                
                Divider()
                
                Button("Select All") {}
                    .keyboardShortcut("a", modifiers: .command)
                Button("Deselect") {
                    canvasEngine.clearSelection()
                }
                .keyboardShortcut("d", modifiers: .command)
                Button("Invert Selection") {}
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            
            // Canvas menu
            Menu("Canvas") {
                Button("Canvas Size...") {
                    NotificationCenter.default.post(name: .canvasSizeRequested, object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .option])
                
                Button("Crop...") {
                    NotificationCenter.default.post(name: .cropCanvasRequested, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Divider()
                
                Button("Canvas Info") {
                    NotificationCenter.default.post(name: .canvasInfoRequested, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                
                Divider()
                
                Button("Animation Assist") {
                    canvasEngine.showingAnimationTimeline.toggle()
                }
                
                Button("Reference") {
                    canvasEngine.showingReferenceWindow.toggle()
                }
                
                Button("Drawing Guide") {}
            }
            
            // Layer menu
            Menu("Layer") {
                Button("New Layer") {
                    canvasEngine.addLayer(name: "New Layer")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("New Group") {
                    canvasEngine.addLayer(name: "New Group", type: .group)
                }
                .keyboardShortcut("g", modifiers: .command)
                
                Divider()
                
                Button("Duplicate Layer") {
                    if let layer = canvasEngine.currentLayer {
                        canvasEngine.duplicateLayer(layer)
                    }
                }
                .keyboardShortcut("j", modifiers: .command)
                
                Button("Merge Down") {
                    if let layer = canvasEngine.currentLayer {
                        canvasEngine.mergeDown(layer)
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
                
                Divider()
                
                Button("Add Mask") {
                    if let layer = canvasEngine.currentLayer {
                        canvasEngine.addMask(to: layer)
                    }
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                
                Button("Add Clipping Mask") {}
                
                Divider()
                
                Button("Lock Layer") {}
                Button("Alpha Lock") {}
            }
            
            // View menu
            Menu("View") {
                Button("Zoom In") {
                    canvasEngine.zoomIn()
                }
                .keyboardShortcut("=", modifiers: .command)
                
                Button("Zoom Out") {
                    canvasEngine.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Actual Size") {
                    canvasEngine.setZoom(1.0)
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Button("Fit to Screen") {
                    canvasEngine.fitToScreen(viewSize: NSScreen.main?.visibleFrame.size ?? CGSize(width: 800, height: 600))
                }
                .keyboardShortcut("9", modifiers: .command)
                
                Divider()
                
                Button("Show Layers") {
                    withAnimation { canvasEngine.showingLayerPanel.toggle() }
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("Show Brushes") {
                    withAnimation { canvasEngine.showingBrushLibrary.toggle() }
                }
                .keyboardShortcut("b", modifiers: .command)
                
                Button("Show Color") {
                    withAnimation { canvasEngine.showingColorPicker.toggle() }
                }
                .keyboardShortcut("c", modifiers: .command)
                
                Divider()
                
                Button("Fullscreen") {}
                    .keyboardShortcut("f", modifiers: [.command, .control])
            }
            
            // Window menu
            Menu("Window") {
                Button("Minimize") {}
                    .keyboardShortcut("m", modifiers: .command)
                
                Button("Zoom") {}
                
                Divider()
                
                Button("Bring All to Front") {}
            }
            
            // Help menu
            Menu("Help") {
                Button("AbyssPaint Help") {}
                Button("Keyboard Shortcuts") {}
                Button("Report an Issue") {}
                Button("Check for Updates...") {}
            }
            
            Spacer()
            
            // Canvas info
            if let canvas = canvasEngine.currentCanvas {
                HStack(spacing: 16) {
                    Text("\(canvas.width) × \(canvas.height) px • \(canvas.dpi) DPI")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text(canvas.colorProfileEnum.rawValue.uppercased())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                    
                    if canvas.timeLapseEnabled {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Bottom Toolbar
struct BottomToolbar: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    
    var body: some View {
        HStack(spacing: 8) {
            // Tool selector
            ToolSelector()
                .environmentObject(canvasEngine)
            
            Divider()
                .frame(height: 24)
            
            // Brush controls
            BrushControls()
                .environmentObject(canvasEngine)
            
            Divider()
                .frame(height: 24)
            
            // Layer blend mode & opacity
            if let layer = canvasEngine.currentLayer {
                LayerControls(layer: layer)
            }
            
            Spacer()
            
            // Canvas info
            CanvasInfoView()
                .environmentObject(canvasEngine)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Tool Selector
struct ToolSelector: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    
    let tools: [(Tool, String, String)] = [
        (.brush, "paintbrush.fill", "Brush"),
        (.eraser, "eraser.fill", "Eraser"),
        (.smudge, "hand.wave.fill", "Smudge"),
        (.selection, "selection.pin.in.out", "Selection"),
        (.transform, "arrow.up.left.and.arrow.down.right", "Transform"),
        (.eyedropper, "eyedropper.halffull", "Eyedropper"),
        (.fill, "paintbucket.fill", "Fill"),
        (.text, "textformat", "Text"),
        (.gradient, "gradient", "Gradient"),
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(tools, id: \.0) { tool, icon, name in
                Button(action: {
                    canvasEngine.currentTool = tool
                }) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32)
                        .foregroundColor(canvasEngine.currentTool == tool ? .white : .primary)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(canvasEngine.currentTool == tool ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(name)
            }
        }
    }
}

// MARK: - Brush Controls
struct BrushControls: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    
    var body: some View {
        HStack(spacing: 12) {
            // Brush size
            VStack(spacing: 2) {
                Slider(value: $canvasEngine.brushSize, in: 1...1000, step: 1) {
                    Text("Size")
                } minimumValueLabel: {
                    Text("1")
                } maximumValueLabel: {
                    Text("1000")
                }
                .frame(width: 120)
                
                Text("\(Int(canvasEngine.brushSize)) px")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Brush opacity
            VStack(spacing: 2) {
                Slider(value: $canvasEngine.brushOpacity, in: 0...1, step: 0.01) {
                    Text("Opacity")
                } minimumValueLabel: {
                    Text("0%")
                } maximumValueLabel: {
                    Text("100%")
                }
                .frame(width: 100)
                
                Text("\(Int(canvasEngine.brushOpacity * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Brush flow
            VStack(spacing: 2) {
                Slider(value: $canvasEngine.brushFlow, in: 0...1, step: 0.01) {
                    Text("Flow")
                } minimumValueLabel: {
                    Text("0%")
                } maximumValueLabel: {
                    Text("100%")
                }
                .frame(width: 100)
                
                Text("\(Int(canvasEngine.brushFlow * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Layer Controls
struct LayerControls: View {
    let layer: Layer
    @EnvironmentObject var canvasEngine: CanvasEngine
    
    var body: some View {
        HStack(spacing: 8) {
            // Blend mode
            Menu {
                ForEach(BlendMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue.capitalized) {
                        layer.blendMode = mode.rawValue
                        try? PersistenceController.shared.container.viewContext.save()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(layer.blendModeEnum.rawValue.capitalized)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 100)
            
            // Opacity
            Slider(value: Binding(
                get: { layer.opacity },
                set: { layer.opacity = $0; try? PersistenceController.shared.container.viewContext.save() }
            ), in: 0...1)
            .frame(width: 80)
        }
    }
}

// MARK: - Canvas Info View
struct CanvasInfoView: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    
    var body: some View {
        HStack(spacing: 16) {
            // Zoom
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                Text("\(Int(canvasEngine.zoom * 100))%")
                    .font(.system(size: 11, design: .monospaced))
            }
            .foregroundColor(.secondary)
            
            // Rotation
            if canvasEngine.rotation != 0 {
                HStack(spacing: 4) {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 11))
                    Text("\(Int(canvasEngine.rotation * 180 / .pi))°")
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }
            
            // Current color
            Circle()
                .fill(Color(red: Double(canvasEngine.currentColor.x),
                           green: Double(canvasEngine.currentColor.y),
                           blue: Double(canvasEngine.currentColor.z),
                           opacity: Double(canvasEngine.currentColor.w)))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let showPreferences = Notification.Name("showPreferences")
}
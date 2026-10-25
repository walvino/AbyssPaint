import SwiftUI
import CoreData

struct LayerPanel: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var showingLayerOptions = false
    @State private var selectedLayer: Layer?
    @State private var dragOverLayer: Layer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LAYERS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Spacer()
                
                Button(action: {
                    canvasEngine.addLayer(name: "New Layer")
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("New Layer (⇧⌘N)")
                
                Button(action: {
                    canvasEngine.addLayer(name: "New Group", type: .group)
                }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("New Group (⌘G)")
                
                Button(action: {
                    showingLayerOptions = true
                }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Layer Options")
                .popover(isPresented: $showingLayerOptions) {
                    LayerOptionsView()
                        .environmentObject(canvasEngine)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Layer list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(canvasEngine.layers.reversed(), id: \.id) { layer in
                        LayerRow(layer: layer, isSelected: canvasEngine.currentLayer?.id == layer.id)
                            .environmentObject(canvasEngine)
                            .onTapGesture {
                                canvasEngine.currentLayer = layer
                            }
                            .onDrag {
                                return NSItemProvider(object: layer.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: LayerDropDelegate(targetLayer: layer, canvasEngine: canvasEngine))
                    }
                }
            }
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct LayerRow: View {
    let layer: Layer
    let isSelected: Bool
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var isHovering = false
    @State private var showingRename = false
    @State private var newName = ""
    
    var body: some View {
        HStack(spacing: 8) {
            // Visibility
            Button(action: {
                layer.visible.toggle()
                try? PersistenceController.shared.container.viewContext.save()
                canvasEngine.renderEngine?.invalidateLayerCache()
            }) {
                Image(systemName: layer.visible ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 13))
                    .foregroundColor(layer.visible ? .primary : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(layer.visible ? "Hide" : "Show")
            
            // Layer thumbnail (placeholder)
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(layerVisibleColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
                
                if layer.locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                if layer.alphaLocked {
                    Image(systemName: "checkerboard.rectangle")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
                
                if layer.clippingTo != nil {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
                
                if layer.layerType == .group {
                    Image(systemName: layer.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            // Layer name
            Text(layer.name)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(layer.visible ? .primary : .secondary)
            
            Spacer()
            
            // Blend mode
            if layer.layerType != .group {
                Menu {
                    ForEach(BlendMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue.capitalized) {
                            layer.blendMode = mode.rawValue
                            try? PersistenceController.shared.container.viewContext.save()
                        }
                    }
                } label: {
                    Text(layer.blendModeEnum.rawValue.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(3)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            
            // Opacity
            if layer.layerType != .group {
                Slider(value: Binding(
                    get: { layer.opacity },
                    set: { layer.opacity = $0; try? PersistenceController.shared.container.viewContext.save() }
                ), in: 0...1)
                .frame(width: 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.secondary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Duplicate") {
                canvasEngine.duplicateLayer(layer)
            }
            .keyboardShortcut("j", modifiers: .command)
            
            Button("Delete") {
                canvasEngine.deleteLayer(layer)
            }
            .keyboardShortcut(.delete, modifiers: .command)
            
            Divider()
            
            Button("Merge Down") {
                canvasEngine.mergeDown(layer)
            }
            .keyboardShortcut("e", modifiers: .command)
            
            Button("Add Mask") {
                canvasEngine.addMask(to: layer)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Lock") {
                layer.locked.toggle()
                try? PersistenceController.shared.container.viewContext.save()
            }
            
            Button("Alpha Lock") {
                layer.alphaLocked.toggle()
                try? PersistenceController.shared.container.viewContext.save()
            }
            
            Divider()
            
            Button("Rename") {
                newName = layer.name
                showingRename = true
            }
            .keyboardShortcut("r", modifiers: .command)
            
            Divider()
            
            Button("Select Contents") {}
            
            Button("Invert") {}
            
            Button("Copy") {}
            
            Button("Paste") {}
        }
        .alert("Rename Layer", isPresented: $showingRename) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                layer.name = newName
                try? PersistenceController.shared.container.viewContext.save()
            }
        }
    }
    
    private var layerVisibleColor: Color {
        switch layer.layerType {
        case .group:
            return Color.accentColor.opacity(0.1)
        case .mask:
            return Color.red.opacity(0.1)
        case .clipping:
            return Color.green.opacity(0.1)
        case .reference:
            return Color.blue.opacity(0.1)
        default:
            return Color(NSColor.controlBackgroundColor)
        }
    }
}

struct LayerDropDelegate: DropDelegate {
    let targetLayer: Layer
    @ObservedObject var canvasEngine: CanvasEngine
    
    func performDrop(info: DropInfo) -> Bool {
        // Handle layer reordering
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Visual feedback
    }
    
    func dropExited(info: DropInfo) {
        // Remove visual feedback
    }
}

struct LayerOptionsView: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Layer Options")
                .font(.headline)
            
            Divider()
            
            Button("Merge Down") {
                if let layer = canvasEngine.currentLayer {
                    canvasEngine.mergeDown(layer)
                }
                dismiss()
            }
            
            Button("Merge Visible") {
                // Merge all visible layers
                dismiss()
            }
            
            Button("Flatten Image") {
                // Flatten all layers
                dismiss()
            }
            
            Divider()
            
            Button("Convert to Smart Object") {
                // Convert layer to smart object
                dismiss()
            }
            
            Button("Rasterize Layer Style") {
                // Rasterize effects
                dismiss()
            }
            
            Divider()
            
            Button("Copy Layer Style") {
                // Copy layer effects
                dismiss()
            }
            
            Button("Paste Layer Style") {
                // Paste layer effects
                dismiss()
            }
            
            Button("Clear Layer Style") {
                // Remove layer effects
                dismiss()
            }
        }
        .padding()
        .frame(width: 200)
    }
}

// Extension for Layer to check if group is expanded
extension Layer {
    var isExpanded: Bool {
        get {
            // Would store this in user data or separate state
            return true
        }
    }
}
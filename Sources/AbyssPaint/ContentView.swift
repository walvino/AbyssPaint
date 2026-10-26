import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: DocumentStore

    @State private var showBrushes = true
    @State private var showLayers = true
    @State private var showColor = ProcessInfo.processInfo.environment["ABYSS_SHOW_COLOR"] != nil

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            CanvasRepresentable(store: store)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(showBrushes: $showBrushes,
                       showLayers: $showLayers,
                       showColor: $showColor)
                    .padding(.top, 10)
                    .padding(.leading, 86)
                    .padding(.trailing, 14)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    BottomDock()
                    Spacer()
                }
                .padding(.bottom, 14)
            }
        }
        .sheet(isPresented: $store.showsNewCanvasSheet) {
            NewCanvasSheet()
                .preferredColorScheme(.dark)
        }
        .overlay(alignment: .topLeading) {
            if showBrushes {
                BrushPanel(onClose: { showBrushes = false })
                    .frame(maxHeight: 660)
                    .padding(.leading, 16)
                    .padding(.top, 72)
                    .padding(.bottom, 74)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            if showLayers {
                LayersPanel(onClose: { showLayers = false })
                    .frame(maxHeight: 520)
                    .padding(.trailing, 16)
                    .padding(.top, 72)
                    .padding(.bottom, 74)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            if showColor {
                ColorPanel()
                    .padding(.top, 72)
                    .padding(.trailing, showLayers ? 340 : 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                Text(toast)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule(style: .continuous)
                                    .fill(Color(red: 0.09, green: 0.095, blue: 0.105).opacity(0.9))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Theme.hairline, lineWidth: 1)
                            )
                    )
                    .padding(.bottom, 74)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.toast)
        .animation(.easeOut(duration: 0.18), value: showBrushes)
        .animation(.easeOut(duration: 0.18), value: showLayers)
        .animation(.easeOut(duration: 0.15), value: showColor)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject private var store: DocumentStore

    @Binding var showBrushes: Bool
    @Binding var showLayers: Bool
    @Binding var showColor: Bool

    @State private var showHistory = ProcessInfo.processInfo.environment["ABYSS_SHOW_HISTORY"] != nil

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)

                Text("ABYSSPAINT")
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Theme.text)
            }

            separator

            HStack(spacing: 2) {
                ForEach(Tool.allCases) { tool in
                    ToolButton(tool: tool)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.black.opacity(0.28))
            )

            separator

            HStack(spacing: 3) {
                IconButton(symbol: "arrow.uturn.backward", help: "Undo (⌘Z)") {
                    store.undo()
                }
                .disabled(!store.canUndo)

                IconButton(symbol: "arrow.uturn.forward", help: "Redo (⇧⌘Z)") {
                    store.redo()
                }
                .disabled(!store.canRedo)

                IconButton(symbol: "clock.arrow.circlepath", help: "History") {
                    showHistory.toggle()
                }
                .disabled(store.historyLength == 0)
                .popover(isPresented: $showHistory, arrowEdge: .bottom) {
                    HistoryPopover()
                        .environmentObject(store)
                }
            }

            Spacer(minLength: 4)

            VStack(spacing: 0) {
                Text(store.documentName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text("\(Int(store.canvasSize.width)) × \(Int(store.canvasSize.height))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }

            Spacer(minLength: 4)

            IconButton(symbol: "paintbrush.pointed",
                       help: "Brush library",
                       active: showBrushes) {
                showBrushes.toggle()
            }

            IconButton(symbol: "square.3.layers.3d",
                       help: "Layers",
                       active: showLayers) {
                showLayers.toggle()
            }

            colorButton

            paperMenu

            symmetryMenu

            exportMenu

            IconButton(symbol: "plus", help: "New canvas") {
                store.showsNewCanvasSheet = true
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(Color(red: 0.075, green: 0.08, blue: 0.09).opacity(0.86))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 20)
    }

    private var symmetryMenu: some View {
        Menu {
            ForEach(SymmetryMode.allCases) { mode in
                Button {
                    store.symmetry = mode
                } label: {
                    if store.symmetry == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.symmetry.symbolName)
                    .font(.system(size: 12, weight: .semibold))

                if store.symmetry != .off {
                    Text(store.symmetry.title)
                        .font(.system(size: 9.5, weight: .bold))
                }
            }
            .foregroundStyle(store.symmetry == .off ? Theme.text : Color.white)
            .padding(.horizontal, store.symmetry == .off ? 0 : 8)
            .frame(minWidth: 30, minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(store.symmetry == .off ? Color.white.opacity(0.06) : Theme.accent.opacity(0.30))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(store.symmetry == .off ? Color.clear : Theme.accent.opacity(0.85),
                                  lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Symmetry drawing guide")
    }

    private var paperMenu: some View {
        Menu {
            ForEach(paperPresets) { preset in
                Button {
                    store.paperColor = preset.color
                } label: {
                    if store.paperColor.abyssHex == preset.color.abyssHex {
                        Label(preset.id, systemImage: "checkmark")
                    } else {
                        Text(preset.id)
                    }
                }
            }

            Divider()

            Button {
                store.paperColor = store.color
            } label: {
                Label("Use current color", systemImage: "eyedropper")
            }

            Button {
                store.paperColor = .white
            } label: {
                Label("Reset to white", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Image(systemName: "rectangle.portrait.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(nsColor: store.paperColor))
                .frame(width: 30, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Paper color")
    }

    private var paperPresets: [PaperPreset] {
        [
            PaperPreset(id: "White", color: .white),
            PaperPreset(id: "Warm paper", color: NSColor(srgbRed: 0.965, green: 0.937, blue: 0.863, alpha: 1)),
            PaperPreset(id: "Cool grey", color: NSColor(srgbRed: 0.867, green: 0.890, blue: 0.910, alpha: 1)),
            PaperPreset(id: "Kraft", color: NSColor(srgbRed: 0.847, green: 0.765, blue: 0.647, alpha: 1)),
            PaperPreset(id: "Charcoal", color: NSColor(srgbRed: 0.106, green: 0.110, blue: 0.118, alpha: 1))
        ]
    }

    private var exportMenu: some View {
        Menu {
            ForEach(DocumentStore.ExportFormat.allCases) { format in
                Button("Export as \(format.title)…") {
                    store.export(as: format)
                }
            }

            Divider()

            Button("Save Project…") { store.saveDocumentAs() }
            Button("Open Project…") { store.openDocument() }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 30, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Export artwork (⌘E for PNG)")
    }

    private var colorButton: some View {
        Button {
            showColor.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(Color(nsColor: store.color))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )

                Circle()
                    .strokeBorder(showColor ? Theme.accent : Color.clear, lineWidth: 2)
                    .frame(width: 27, height: 27)
            }
            .frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .help("Color")
    }
}

// MARK: - Bottom dock

struct BottomDock: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        HStack(spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: store.tool.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)

                Circle()
                    .fill(Color(nsColor: store.color))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            }
            .frame(width: 46)

            DockSlider(title: "Size",
                       value: $store.brushSize,
                       range: 1...400,
                       display: "\(Int(store.brushSize))")

            dockSeparator

            DockSlider(title: "Opacity",
                       value: $store.brushOpacity,
                       range: 0.02...1,
                       display: "\(Int(store.brushOpacity * 100))%")

            dockSeparator

            IconButton(symbol: "arrow.uturn.backward", help: "Undo") {
                store.undo()
            }
            .disabled(!store.canUndo)

            IconButton(symbol: "arrow.uturn.forward", help: "Redo") {
                store.redo()
            }
            .disabled(!store.canRedo)

            dockSeparator

            IconButton(symbol: "rotate.left", help: "Rotate canvas left") {
                store.rotateCanvas(by: -.pi / 12)
            }

            IconButton(symbol: "rotate.right", help: "Rotate canvas right") {
                store.rotateCanvas(by: .pi / 12)
            }

            IconButton(symbol: "arrow.up.left.and.arrow.down.right", help: "Fit canvas") {
                store.fitCanvas()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(DockBackground())
    }

    private var dockSeparator: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 18)
    }
}

// MARK: - History

struct HistoryPopover: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: "History")
                Spacer()
                Text("Step \(store.historyPosition) of \(store.historyLength)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }

            Slider(
                value: Binding(
                    get: { Double(store.historyPosition) },
                    set: { store.jumpHistory(to: Int($0.rounded())) }
                ),
                in: 0...Double(max(1, store.historyLength))
            )
            .tint(Theme.accent)
            .disabled(store.historyLength == 0)

            HStack(spacing: 6) {
                IconButton(symbol: "arrow.uturn.backward", help: "Undo") { store.undo() }
                    .disabled(!store.canUndo)

                IconButton(symbol: "arrow.uturn.forward", help: "Redo") { store.redo() }
                    .disabled(!store.canRedo)

                Spacer()

                Text("⌘Z / ⇧⌘Z")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(12)
        .frame(width: 260)
        .background(Theme.panel)
        .preferredColorScheme(.dark)
    }
}

private struct PaperPreset: Identifiable {
    let id: String
    let color: NSColor
}

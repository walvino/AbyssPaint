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

            IconButton(symbol: "square.and.arrow.up", help: "Export PNG (⌘E)") {
                store.exportPNG()
            }

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

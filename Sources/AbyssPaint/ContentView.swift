import SwiftUI

enum Theme {
    static let background = Color(red: 0.10, green: 0.10, blue: 0.11)
    static let panel = Color(red: 0.125, green: 0.128, blue: 0.14)
    static let raised = Color(red: 0.17, green: 0.175, blue: 0.19)
    static let accent = Color(red: 0.851, green: 0.227, blue: 0.157)
    static let accentDeep = Color(red: 0.62, green: 0.13, blue: 0.09)
    static let green = Color(red: 0.376, green: 0.804, blue: 0.451)
    static let text = Color.white.opacity(0.92)
    static let dim = Color.white.opacity(0.52)
}

// MARK: - Content

struct ContentView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            Divider().overlay(Color.black.opacity(0.6))

            HStack(spacing: 0) {
                BrushSidebar()
                    .frame(width: 238)

                Divider().overlay(Color.black.opacity(0.6))

                CanvasRepresentable(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(Color.black.opacity(0.6))

                LayersPanel()
                    .frame(width: 270)
            }

            Divider().overlay(Color.black.opacity(0.6))
            StatusBar()
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("ABYSSPAINT")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Theme.text)
            }

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 20)

            HStack(spacing: 2) {
                ForEach(Tool.allCases) { tool in
                    Button {
                        store.tool = tool
                    } label: {
                        Image(systemName: tool.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 36, height: 26)
                            .foregroundStyle(store.tool == tool ? Color.white : Theme.dim)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(store.tool == tool ? Theme.accent : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(tool.title)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.raised)
            )

            HStack(spacing: 4) {
                IconButton(symbol: "arrow.uturn.backward", help: "Undo (⌘Z)") {
                    store.undo()
                }
                .disabled(!store.canUndo)

                IconButton(symbol: "arrow.uturn.forward", help: "Redo (⇧⌘Z)") {
                    store.redo()
                }
                .disabled(!store.canRedo)
            }

            Spacer(minLength: 8)

            ColorSwatch()

            IconButton(symbol: "arrow.up.left.and.arrow.down.right", help: "Fit canvas to window") {
                store.fitRequest += 1
            }

            Button {
                store.newDocument()
            } label: {
                Label("New", systemImage: "plus.square")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)

            Button {
                store.exportPNG()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.panel)
    }
}

// MARK: - Small pieces

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 26)
                .background(Theme.raised)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ColorSwatch: View {
    @EnvironmentObject private var store: DocumentStore

    private var binding: Binding<Color> {
        Binding(
            get: { Color(nsColor: store.color) },
            set: { newValue in
                let converted = NSColor(newValue).usingColorSpace(.sRGB)
                store.color = converted ?? .white
            }
        )
    }

    var body: some View {
        ColorPicker("Color", selection: binding, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 34, height: 26)
            .help("Brush color")
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let display: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.dim)
                Spacer()
                Text(display)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text)
            }
            Slider(value: $value, in: range)
                .tint(Theme.accent)
                .controlSize(.small)
        }
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Theme.dim)
    }
}

// MARK: - Status bar

struct StatusBar: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        HStack(spacing: 14) {
            Text("\(Int(store.canvasSize.width)) × \(Int(store.canvasSize.height)) px")
            Text("•")
            Text("\(store.layers.count) layer\(store.layers.count == 1 ? "" : "s")")
            Text("•")
            Text(store.tool.title)

            Spacer()

            Text("Space + drag to pan  ·  ⌥ scroll to zoom  ·  double-click to fit")
                .foregroundStyle(Theme.dim)
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(Theme.text.opacity(0.75))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Theme.panel)
    }
}

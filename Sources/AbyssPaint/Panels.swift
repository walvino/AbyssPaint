import SwiftUI
import AppKit

// MARK: - Left sidebar

struct BrushSidebar: View {
    @EnvironmentObject private var store: DocumentStore

    private let swatches: [NSColor] = [
        NSColor(srgbRed: 0.851, green: 0.227, blue: 0.157, alpha: 1),
        NSColor(srgbRed: 0.376, green: 0.804, blue: 0.451, alpha: 1),
        NSColor(srgbRed: 0.98, green: 0.75, blue: 0.18, alpha: 1),
        NSColor(srgbRed: 0.20, green: 0.55, blue: 0.95, alpha: 1),
        NSColor(srgbRed: 0.65, green: 0.35, blue: 0.90, alpha: 1),
        NSColor(srgbRed: 0.55, green: 0.36, blue: 0.22, alpha: 1),
        NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1),
        NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: "Brushes")

                    ForEach(store.presets) { preset in
                        Button {
                            store.selectPreset(preset)
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: preset.symbolName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 16)
                                    .foregroundStyle(store.selectedPresetID == preset.id ? Color.white : Theme.dim)

                                Text(preset.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(store.selectedPresetID == preset.id ? Color.white : Theme.text)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(store.selectedPresetID == preset.id
                                          ? Theme.accent.opacity(0.85)
                                          : Theme.raised.opacity(0.7))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().overlay(Color.black.opacity(0.5))

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(text: "Brush settings")

                    SliderRow(
                        title: "Size",
                        value: $store.brushSize,
                        range: 1...400,
                        display: "\(Int(store.brushSize)) px"
                    )

                    SliderRow(
                        title: "Opacity",
                        value: $store.brushOpacity,
                        range: 0.02...1,
                        display: "\(Int(store.brushOpacity * 100))%"
                    )

                    SliderRow(
                        title: "Hardness",
                        value: $store.brushHardness,
                        range: 0...1,
                        display: "\(Int(store.brushHardness * 100))%"
                    )

                    SliderRow(
                        title: "Spacing",
                        value: $store.brushSpacing,
                        range: 0.02...0.6,
                        display: "\(Int(store.brushSpacing * 100))%"
                    )
                }

                Divider().overlay(Color.black.opacity(0.5))

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Color")

                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(Array(swatches.enumerated()), id: \.offset) { _, swatch in
                            Button {
                                store.color = swatch
                            } label: {
                                Circle()
                                    .fill(Color(nsColor: swatch))
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(Theme.panel)
    }
}

// MARK: - Right sidebar

struct LayersPanel: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                SectionTitle(text: "Layers")
                Spacer()

                IconButton(symbol: "plus", help: "Add layer") {
                    store.addLayer()
                }

                IconButton(symbol: "doc.on.doc", help: "Duplicate layer") {
                    store.duplicateActiveLayer()
                }

                IconButton(symbol: "trash", help: "Delete layer") {
                    store.deleteActiveLayer()
                }
                .disabled(store.layers.count <= 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().overlay(Color.black.opacity(0.5))

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(store.layers.indices.reversed()), id: \.self) { index in
                        LayerRow(index: index)
                    }
                }
                .padding(8)
            }

            Divider().overlay(Color.black.opacity(0.5))

            if let index = store.activeLayerIndex {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        IconButton(symbol: "chevron.up", help: "Move layer up") {
                            store.moveActiveLayer(up: true)
                        }
                        IconButton(symbol: "chevron.down", help: "Move layer down") {
                            store.moveActiveLayer(up: false)
                        }

                        Spacer()

                        Button {
                            store.clearActiveLayer()
                        } label: {
                            Text("Clear")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.dim)
                        }
                        .buttonStyle(.plain)
                        .help("Clear this layer")
                    }

                    SliderRow(
                        title: "Layer opacity",
                        value: Binding(
                            get: { CGFloat(store.layers[index].opacity) },
                            set: { store.layers[index].opacity = Double($0) }
                        ),
                        range: 0...1,
                        display: "\(Int(store.layers[index].opacity * 100))%"
                    )
                }
                .padding(12)
            }
        }
        .background(Theme.panel)
    }
}

struct LayerRow: View {
    @EnvironmentObject private var store: DocumentStore
    let index: Int

    private var layer: Layer {
        store.layers[index]
    }

    private var isActive: Bool {
        store.activeLayerID == layer.id
    }

    var body: some View {
        HStack(spacing: 9) {
            Button {
                store.layers[index].isVisible.toggle()
                store.revision += 1
            } label: {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(layer.isVisible ? Theme.green : Theme.dim)
                    .frame(width: 18, height: 20)
            }
            .buttonStyle(.plain)
            .help(layer.isVisible ? "Hide layer" : "Show layer")

            thumbnail

            VStack(alignment: .leading, spacing: 1) {
                Text(layer.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text("\(Int(layer.opacity * 100))%")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.dim)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Theme.accent.opacity(0.22) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isActive ? Theme.accent.opacity(0.7) : Color.white.opacity(0.06),
                              lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            store.activeLayerID = layer.id
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)

            if let image = store.thumbnail(for: layer) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
        )
    }
}

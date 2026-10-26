import SwiftUI

struct LayersPanel: View {
    @EnvironmentObject private var store: DocumentStore
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                SectionTitle(text: "Layers")
                Spacer()
                IconButton(symbol: "xmark", help: "Close", action: onClose)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().overlay(Theme.hairline)

            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(Array(store.layers.indices.reversed()), id: \.self) { index in
                        LayerRow(index: index)
                    }
                }
                .padding(10)
            }

            Divider().overlay(Theme.hairline)

            if let index = store.activeLayerIndex, store.layers.indices.contains(index) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Blend")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.dim)

                        Spacer()

                        Menu {
                            ForEach(LayerBlendMode.allCases) { mode in
                                Button {
                                    store.setBlendMode(mode, for: index)
                                } label: {
                                    if store.layers[index].blendMode == mode {
                                        Label(mode.title, systemImage: "checkmark")
                                    } else {
                                        Text(mode.title)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(store.layers[index].blendMode.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.text)

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Theme.dim)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }

                    SliderRow(title: "Layer opacity",
                              value: opacityBinding(index),
                              range: 0...1,
                              display: "\(Int(store.layers[index].opacity * 100))%")

                    HStack(spacing: 4) {
                        IconButton(symbol: "plus", help: "Add layer") { store.addLayer() }
                        IconButton(symbol: "doc.on.doc", help: "Duplicate layer") { store.duplicateActiveLayer() }
                        IconButton(symbol: "arrow.triangle.merge", help: "Merge down") { store.mergeDown() }
                        IconButton(symbol: "arrow.left.and.right", help: "Flip layer horizontally") {
                            store.flipActiveLayerHorizontally()
                        }
                        IconButton(symbol: "photo", help: "Import image as layer") { store.importImage() }

                        Spacer()

                        IconButton(symbol: "chevron.up", help: "Move layer up") { store.moveActiveLayer(up: true) }
                        IconButton(symbol: "chevron.down", help: "Move layer down") { store.moveActiveLayer(up: false) }
                        IconButton(symbol: "trash", help: "Delete layer") { store.deleteActiveLayer() }
                            .disabled(store.layers.count <= 1)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 312)
        .background(PanelBackground())
    }

    private func opacityBinding(_ index: Int) -> Binding<CGFloat> {
        Binding(
            get: { CGFloat(store.layers[index].opacity) },
            set: { newValue in
                guard store.layers.indices.contains(index) else { return }
                store.layers[index].opacity = Double(newValue)
                store.revision += 1
            }
        )
    }

    private func blendBinding(_ index: Int) -> Binding<LayerBlendMode> {
        Binding(
            get: {
                store.layers.indices.contains(index) ? store.layers[index].blendMode : .normal
            },
            set: { newValue in
                store.setBlendMode(newValue, for: index)
            }
        )
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
                    .frame(width: 18, height: 22)
            }
            .buttonStyle(.plain)
            .help(layer.isVisible ? "Hide layer" : "Show layer")

            thumbnail

            VStack(alignment: .leading, spacing: 1) {
                Text(layer.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text("\(layer.blendMode.title) · \(Int(layer.opacity * 100))%")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isActive ? Theme.accent.opacity(0.22) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isActive ? Theme.accent.opacity(0.7) : Color.white.opacity(0.05),
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
        .frame(width: 38, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
        )
    }
}

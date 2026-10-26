import SwiftUI

struct BrushPanel: View {
    @EnvironmentObject private var store: DocumentStore
    let onClose: () -> Void

    private enum Tab: String, CaseIterable {
        case brushes
        case settings
    }

    @State private var tab: Tab = ProcessInfo.processInfo.environment["ABYSS_BRUSH_TAB"] == "settings" ? .settings : .brushes

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                SectionTitle(text: tab == .brushes ? "Brush Library" : "Brush Studio")
                Spacer()
                IconButton(symbol: "xmark", help: "Close", action: onClose)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().overlay(Theme.hairline)

            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue.capitalized).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider().overlay(Theme.hairline)

            ScrollView {
                if tab == .brushes {
                    brushes
                } else {
                    settings
                }
            }
        }
        .frame(width: 300)
        .background(PanelBackground())
    }

    private var brushes: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !recentBrushes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        SectionTitle(text: "Recent")
                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(recentBrushes) { preset in
                                Button {
                                    store.selectPreset(preset)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: preset.symbolName)
                                            .font(.system(size: 9, weight: .semibold))

                                        Text(preset.name)
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundStyle(store.selectedPresetID == preset.id
                                                     ? Color.white : Theme.text)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(store.selectedPresetID == preset.id
                                                  ? Theme.accent.opacity(0.32)
                                                  : Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(store.selectedPresetID == preset.id
                                                          ? Theme.accent.opacity(0.8)
                                                          : Theme.hairline,
                                                          lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }

            VStack(spacing: 7) {
                ForEach(store.presets) { preset in
                    BrushRow(preset: preset)
                }
            }
        }
        .padding(12)
    }

    private var recentBrushes: [BrushPreset] {
        var seen = Set<String>()
        return store.recentPresetIDs.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return store.presets.first { $0.id == id }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: "Brush settings")

                Spacer()

                Button {
                    if let preset = store.presets.first(where: { $0.id == store.selectedPresetID }) {
                        store.selectPreset(preset)
                    }
                } label: {
                    Text("Reset")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.green)
                }
                .buttonStyle(.plain)
                .help("Reset to the preset values")
            }

            SliderRow(title: "Size",
                      value: $store.brushSize,
                      range: 1...400,
                      display: "\(Int(store.brushSize)) px")

            SliderRow(title: "Opacity",
                      value: $store.brushOpacity,
                      range: 0.02...1,
                      display: "\(Int(store.brushOpacity * 100))%")

            SliderRow(title: "Flow",
                      value: $store.brushFlow,
                      range: 0.02...1,
                      display: "\(Int(store.brushFlow * 100))%")

            SliderRow(title: "Hardness",
                      value: $store.brushHardness,
                      range: 0...1,
                      display: "\(Int(store.brushHardness * 100))%")

            SliderRow(title: "Spacing",
                      value: $store.brushSpacing,
                      range: 0.02...0.6,
                      display: "\(Int(store.brushSpacing * 100))%")

            SliderRow(title: "Grain",
                      value: $store.brushGrain,
                      range: 0...1,
                      display: "\(Int(store.brushGrain * 100))%")

            SliderRow(title: "Taper",
                      value: $store.brushTaper,
                      range: 0...0.8,
                      display: "\(Int(store.brushTaper * 100))%")

            SliderRow(title: "Pressure curve",
                      value: $store.pressureCurve,
                      range: 0.2...2,
                      display: String(format: "%.1f×", store.pressureCurve))

            SliderRow(title: "Stabilization",
                      value: $store.brushSmoothing,
                      range: 0...0.9,
                      display: "\(Int(store.brushSmoothing * 100))%")

            Text("Taper thins the start of each stroke. Pressure curve shapes how tablet pressure maps to brush size.")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(12)
    }
}

struct BrushRow: View {
    @EnvironmentObject private var store: DocumentStore
    let preset: BrushPreset

    private var isSelected: Bool {
        store.selectedPresetID == preset.id
    }

    var body: some View {
        Button {
            store.selectPreset(preset)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(preset.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Theme.text)

                    Spacer()

                    Text("\(Int(preset.size)) px")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
                .padding(.horizontal, 10)
                .padding(.top, 7)

                if let image = BrushPreview.image(for: preset) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)
                        .opacity(isSelected ? 1 : 0.85)
                }
            }
            .frame(height: 62)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.30) : Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.85) : Color.white.opacity(0.05),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

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
        VStack(spacing: 7) {
            ForEach(store.presets) { preset in
                BrushRow(preset: preset)
            }
        }
        .padding(12)
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

            SliderRow(title: "Stabilization",
                      value: $store.brushSmoothing,
                      range: 0...0.9,
                      display: "\(Int(store.brushSmoothing * 100))%")
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

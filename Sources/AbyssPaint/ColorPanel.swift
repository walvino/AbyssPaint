import SwiftUI
import AppKit

struct ColorPanel: View {
    @EnvironmentObject private var store: DocumentStore

    @State private var hue: CGFloat = 0.02
    @State private var saturation: CGFloat = 0.83
    @State private var brightness: CGFloat = 0.85
    @State private var isSyncing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SectionTitle(text: "Color")

                Spacer()

                Text(hexString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.dim)

                Circle()
                    .fill(Color(nsColor: store.color))
                    .frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            }

            saturationBrightnessSquare

            hueSlider

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(text: "Recent")

                HStack(spacing: 6) {
                    ForEach(Array(store.recentColors.enumerated()), id: \.offset) { _, color in
                        Button {
                            store.setColor(color, remember: false)
                            syncFromStore()
                        } label: {
                            Circle()
                                .fill(Color(nsColor: color))
                                .frame(width: 19, height: 19)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 272)
        .background(PanelBackground())
        .onAppear { syncFromStore() }
        .onChange(of: store.color) {
            syncFromStore()
        }
    }

    // MARK: Components

    private var saturationBrightnessSquare: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [.white, Color(hue: Double(hue), saturation: 1, brightness: 1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness)))
                    .frame(width: 15, height: 15)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .position(x: min(max(saturation * geometry.size.width, 8), geometry.size.width - 8),
                              y: min(max((1 - brightness) * geometry.size.height, 8), geometry.size.height - 8))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        saturation = clamp(value.location.x / max(1, geometry.size.width))
                        brightness = 1 - clamp(value.location.y / max(1, geometry.size.height))
                        apply()
                    }
            )
        }
        .frame(height: 150)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var hueSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 0.08).map {
                        Color(hue: $0, saturation: 1, brightness: 1)
                    },
                    startPoint: .leading,
                    endPoint: .trailing
                )

                Capsule()
                    .fill(Color(hue: Double(hue), saturation: 1, brightness: 1))
                    .frame(width: 12, height: 20)
                    .overlay(Capsule().strokeBorder(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .position(x: min(max(hue * geometry.size.width, 7), geometry.size.width - 7),
                              y: geometry.size.height / 2)
            }
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        hue = clamp(value.location.x / max(1, geometry.size.width))
                        apply()
                    }
            )
        }
        .frame(height: 22)
    }

    // MARK: State

    private var hexString: String {
        let color = store.color.usingColorSpace(.sRGB) ?? .black
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }

    private func apply() {
        guard !isSyncing else { return }
        let newColor = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        store.setColor(newColor)
    }

    private func syncFromStore() {
        let color = store.color.usingColorSpace(.sRGB) ?? .black
        var newHue: CGFloat = 0
        var newSaturation: CGFloat = 0
        var newBrightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&newHue, saturation: &newSaturation, brightness: &newBrightness, alpha: &alpha)

        guard abs(newHue - hue) > 0.0015
                || abs(newSaturation - saturation) > 0.0015
                || abs(newBrightness - brightness) > 0.0015 else {
            return
        }

        isSyncing = true
        hue = newHue
        saturation = newSaturation
        brightness = newBrightness
        isSyncing = false
    }
}

import SwiftUI
import AppKit

struct Palette: Identifiable, Equatable {
    let name: String
    let colors: [NSColor]

    var id: String { name }
}

enum Palettes {
    static func c(_ hexes: [Int]) -> [NSColor] {
        hexes.map(NSColor.init(hex:))
    }

    static let all: [Palette] = [
        Palette(name: "Default", colors: c([
            0x0A0A0B, 0x26262A, 0x3F3F46, 0x585860, 0x73737C, 0x8E8E97, 0xB4B4BB, 0xD9D9DE, 0xFFFFFF,
            0xD93A28, 0xE8702A, 0xF2B93B, 0x9BCB3C, 0x60A83E, 0x2E9E7E, 0x33A8C7, 0x3B6FD4, 0x8C4FC4
        ])),
        Palette(name: "Skin", colors: c([
            0xFDE9DC, 0xF9D7C4, 0xF3C4AC, 0xEBAF93, 0xE09A7C, 0xD38667, 0xC17355, 0xAC6146, 0x96533A,
            0x7F4630, 0x693A27, 0x54301F, 0x41251A, 0xB4523F, 0xA8452F, 0x8E3A2B, 0x6E2C22, 0x4E2019
        ])),
        Palette(name: "Nature", colors: c([
            0x1F3A2B, 0x2E5B3E, 0x3F7A4C, 0x5B9A5E, 0x86B96A, 0xB7D48B, 0xDDE6B4, 0xF2EAD3, 0xC9A16B,
            0xA97C4B, 0x855E36, 0x5F4326, 0x7FB3C9, 0x5B93B0, 0x3D6F8C, 0x27506B, 0x8C6F5A, 0x5C4738
        ])),
        Palette(name: "Neon", colors: c([
            0xFF2D95, 0xFF5E5B, 0xFF9F1C, 0xFFD60A, 0xC6F91B, 0x6EEB2E, 0x2EEB9B, 0x2EEBD6, 0x2EC5FF,
            0x2E7BFF, 0x6B4BFF, 0xB14BFF, 0xFF4BD6, 0xFF7AE0, 0xB9FF6B, 0x6BFFB9, 0xFFFFFF, 0x101014
        ]))
    ]
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct ColorPanel: View {
    @EnvironmentObject private var store: DocumentStore

    @State private var hue: CGFloat = 0.02
    @State private var saturation: CGFloat = 0.83
    @State private var brightness: CGFloat = 0.85
    @State private var isSyncing = false
    @State private var paletteIndex = 0

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

            Divider().overlay(Theme.hairline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionTitle(text: "Palettes")

                    Spacer()

                    Menu {
                        ForEach(Palettes.all) { palette in
                            Button(palette.name) {
                                paletteIndex = Palettes.all.firstIndex(of: palette) ?? 0
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(Palettes.all[paletteIndex].name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.text)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 7.5, weight: .bold))
                                .foregroundStyle(Theme.dim)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 9),
                          spacing: 6) {
                    ForEach(Array(Palettes.all[paletteIndex].colors.enumerated()), id: \.offset) { _, color in
                        Button {
                            store.setColor(color)
                            syncFromStore()
                        } label: {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(nsColor: color))
                                .frame(height: 18)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                )
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

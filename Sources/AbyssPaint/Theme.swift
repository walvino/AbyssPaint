import SwiftUI

enum Theme {
    static let background = Color(red: 0.055, green: 0.058, blue: 0.065)
    static let panel = Color(red: 0.105, green: 0.11, blue: 0.12)
    static let raised = Color(red: 0.17, green: 0.175, blue: 0.19)
    static let accent = Color(red: 0.851, green: 0.227, blue: 0.157)
    static let accentDeep = Color(red: 0.60, green: 0.12, blue: 0.08)
    static let green = Color(red: 0.376, green: 0.804, blue: 0.451)
    static let text = Color.white.opacity(0.93)
    static let dim = Color.white.opacity(0.52)
    static let hairline = Color.white.opacity(0.08)
}

struct PanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.085, blue: 0.095).opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
    }
}

struct DockBackground: View {
    var body: some View {
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
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }
}

// MARK: - Controls

struct IconButton: View {
    let symbol: String
    let help: String
    var active: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 28)
                .foregroundStyle(active ? Color.white : Theme.text)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(active ? Theme.accent.opacity(0.30) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(active ? Theme.accent.opacity(0.85) : Color.clear,
                                      lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ToolButton: View {
    let tool: Tool

    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        Button {
            store.tool = tool
        } label: {
            Image(systemName: tool.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 38, height: 28)
                .foregroundStyle(store.tool == tool ? Color.white : Theme.dim)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(store.tool == tool ? Theme.accent : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tool.title)
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(Theme.dim)
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
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text)
            }

            Slider(value: $value, in: range)
                .tint(Theme.accent)
                .controlSize(.small)
        }
    }
}

struct DockSlider: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let display: String
    var width: CGFloat = 132

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.dim)
                .frame(width: 46, alignment: .leading)

            Slider(value: $value, in: range)
                .tint(Theme.accent)
                .controlSize(.mini)
                .frame(width: width)

            Text(display)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.text)
                .frame(width: 38, alignment: .trailing)
        }
    }
}

import SwiftUI

struct NewCanvasSheet: View {
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    @State private var widthText = "1600"
    @State private var heightText = "1200"

    private let presets: [(title: String, width: Int, height: Int)] = [
        ("Square 2048", 2048, 2048),
        ("Classic 1600 × 1200", 1600, 1200),
        ("HD 1920 × 1080", 1920, 1080),
        ("Portrait 1200 × 1600", 1200, 1600),
        ("Print 3000 × 2000", 3000, 2000),
        ("Wide 2560 × 1080", 2560, 1080)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("New Canvas")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.text)

                    Text("Choose a size for your artwork")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.dim)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(0..<((presets.count + 1) / 2), id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { column in
                            let index = row * 2 + column
                            if presets.indices.contains(index) {
                                presetButton(presets[index])
                            }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                field(title: "Width", text: $widthText)
                Text("×").foregroundStyle(Theme.dim)
                field(title: "Height", text: $heightText)
            }

            HStack {
                Text("Maximum 8000 px per side")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.dim)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.dim)
                .padding(.trailing, 6)

                Button {
                    create()
                } label: {
                    Text("Create")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 430)
        .background(Theme.panel)
        .preferredColorScheme(.dark)
    }

    private func field(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.dim)

            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private func presetButton(_ preset: (title: String, width: Int, height: Int)) -> some View {
        Button {
            widthText = "\(preset.width)"
            heightText = "\(preset.height)"
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.text)

                Text("\(preset.width) × \(preset.height) px")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.dim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected(preset) ? Theme.accent : Color.white.opacity(0.06),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func isSelected(_ preset: (title: String, width: Int, height: Int)) -> Bool {
        Int(widthText) == preset.width && Int(heightText) == preset.height
    }

    private func create() {
        let width = min(max(Int(widthText) ?? 1600, 64), 8000)
        let height = min(max(Int(heightText) ?? 1200, 64), 8000)
        store.newDocument(width: width, height: height)
        dismiss()
    }
}

import SwiftUI

struct NewCanvasSheet: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @Environment(\.dismiss) var dismiss
    @StateObject private var preferences = Preferences.shared
    
    @State private var name = "Untitled"
    @State private var width: Int = 3000
    @State private var height: Int = 2000
    @State private var dpi: Int = 300
    @State private var colorProfile: ColorProfile = .sRGB
    @State private var backgroundColor: Color = .white
    @State private var timeLapseEnabled = true
    @State private var timeLapseQuality: TimeLapseQuality = .uhd4k
    @State private var selectedPreset: CanvasPreset = .custom
    
    private let presets: [CanvasPreset] = CanvasPreset.allCases
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Canvas")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Presets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Presets")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                            ForEach(presets, id: \.self) { preset in
                                PresetButton(
                                    preset: preset,
                                    isSelected: selectedPreset == preset
                                ) {
                                    selectedPreset = preset
                                    applyPreset(preset)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Custom dimensions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dimensions")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Width")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                TextField("Width", value: $width, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            Text("×")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Height")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                TextField("Height", value: $height, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DPI")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                TextField("DPI", value: $dpi, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Color Profile")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $colorProfile) {
                                    ForEach(ColorProfile.allCases, id: \.self) { profile in
                                        Text(profile.rawValue.uppercased()).tag(profile)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 140)
                            }
                            
                            Spacer()
                        }
                        
                        // Layer count estimate
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("Estimated layers: \(estimateMaxLayers())")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    Divider()
                    
                    // Canvas settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        Toggle("Time-lapse Recording", isOn: $timeLapseEnabled)
                            .toggleStyle(.switch)
                        
                        if timeLapseEnabled {
                            Picker("Quality", selection: $timeLapseQuality) {
                                Text("1080p HD").tag(TimeLapseQuality.hd1080)
                                Text("4K UHD").tag(TimeLapseQuality.uhd4k)
                            }
                            .pickerStyle(.segmented)
                            .padding(.leading, 20)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Background Color")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            ColorPicker("", selection: $backgroundColor)
                                .labelsHidden()
                                .frame(width: 40, height: 24)
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create") {
                    createCanvas()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || width <= 0 || height <= 0)
            }
            .padding()
        }
        .frame(width: 480, height: 580)
        .onAppear {
            loadDefaults()
        }
    }
    
    private func loadDefaults() {
        width = preferences.defaultCanvasWidth
        height = preferences.defaultCanvasHeight
        dpi = preferences.defaultDPI
        colorProfile = preferences.defaultColorProfile
        backgroundColor = preferences.canvasBackgroundColor
    }
    
    private func applyPreset(_ preset: CanvasPreset) {
        switch preset {
        case .custom:
            break
        case .screen:
            width = 1920; height = 1080; dpi = 72
        case .printA4:
            width = 2480; height = 3508; dpi = 300
        case .printLetter:
            width = 2550; height = 3300; dpi = 300
        case .squareSmall:
            width = 1080; height = 1080; dpi = 72
        case .squareLarge:
            width = 3000; height = 3000; dpi = 300
        case .hd:
            width = 1920; height = 1080; dpi = 72
        case .uhd4k:
            width = 3840; height = 2160; dpi = 72
        case .iphone:
            width = 1170; height = 2532; dpi = 326
        case .ipad:
            width = 2048; height = 2732; dpi = 264
        case .wallpaper:
            width = 5120; height = 2880; dpi = 72
        }
    }
    
    private func estimateMaxLayers() -> Int {
        let pixels = width * height
        let bytesPerLayer = pixels * 8 // RGBA16 = 8 bytes per pixel
        let availableMemory = 8_000_000_000 // 8 GB estimate
        return max(1, availableMemory / bytesPerLayer)
    }
    
    private func createCanvas() {
        canvasEngine.createCanvas(
            name: name,
            width: width,
            height: height,
            dpi: dpi,
            colorProfile: colorProfile
        )
        dismiss()
    }
}

enum CanvasPreset: String, CaseIterable {
    case custom = "Custom"
    case screen = "Screen"
    case printA4 = "A4 Print"
    case printLetter = "Letter Print"
    case squareSmall = "Square (1080)"
    case squareLarge = "Square (3000)"
    case hd = "HD (1920×1080)"
    case uhd4k = "4K (3840×2160)"
    case iphone = "iPhone"
    case ipad = "iPad"
    case wallpaper = "5K Wallpaper"
}

struct PresetButton: View {
    let preset: CanvasPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(preset.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                if preset != .custom {
                    Text(dimensionsForPreset(preset))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func dimensionsForPreset(_ preset: CanvasPreset) -> String {
        switch preset {
        case .screen: return "1920 × 1080 @ 72 DPI"
        case .printA4: return "2480 × 3508 @ 300 DPI"
        case .printLetter: return "2550 × 3300 @ 300 DPI"
        case .squareSmall: return "1080 × 1080 @ 72 DPI"
        case .squareLarge: return "3000 × 3000 @ 300 DPI"
        case .hd: return "1920 × 1080 @ 72 DPI"
        case .uhd4k: return "3840 × 2160 @ 72 DPI"
        case .iphone: return "1170 × 2532 @ 326 DPI"
        case .ipad: return "2048 × 2732 @ 264 DPI"
        case .wallpaper: return "5120 × 2880 @ 72 DPI"
        default: return ""
        }
    }
}
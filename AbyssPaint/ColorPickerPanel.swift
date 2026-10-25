import SwiftUI

struct ColorPickerPanel: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var selectedTab = 0
    
    private let tabs = ["Disc", "Classic", "Harmony", "Value", "Palettes"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("COLOR")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Spacer()
                
                // Current color swatch
                Button(action: {
                    canvasEngine.showingColorPicker.toggle()
                }) {
                    Circle()
                        .fill(Color(
                            red: Double(canvasEngine.currentColor.x),
                            green: Double(canvasEngine.currentColor.y),
                            blue: Double(canvasEngine.currentColor.z),
                            opacity: Double(canvasEngine.currentColor.w)
                        ))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Tab selector
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        selectedTab = index
                    }) {
                        Text(tabs[index])
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedTab == index ? Color.accentColor.opacity(0.1) : Color.clear
                            )
                            .foregroundColor(selectedTab == index ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            Divider()
            
            // Tab content
            Group {
                switch selectedTab {
                case 0:
                    ColorDiscView()
                case 1:
                    ColorClassicView()
                case 2:
                    ColorHarmonyView()
                case 3:
                    ColorValueView()
                case 4:
                    ColorPalettesView()
                default:
                    ColorDiscView()
                }
            }
            .environmentObject(canvasEngine)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ColorDiscView: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Color disc
            GeometryReader { geometry in
                ZStack {
                    // Hue ring
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: hueColors),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            lineWidth: geometry.size.width * 0.3
                        )
                    
                    // Saturation/Brightness disc
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(hue: hue, saturation: 0, brightness: brightness),
                                    Color(hue: hue, saturation: saturation, brightness: brightness)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.35
                            )
                        )
                        .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                    
                    // Picker indicator
                    Circle()
                        .fill(Color(
                            hue: hue,
                            saturation: saturation,
                            brightness: brightness
                        ))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                        )
                        .position(
                            x: geometry.size.width/2 + cos(hue * 2 * .pi - .pi/2) * saturation * geometry.size.width * 0.35 + geometry.size.width * 0.15,
                            y: geometry.size.height/2 + sin(hue * 2 * .pi - .pi/2) * saturation * geometry.size.width * 0.35 + geometry.size.width * 0.15
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            updateColor(from: value.location, in: geometry.size)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 200)
            .padding(12)
            
            // Brightness slider
            VStack(spacing: 4) {
                HStack {
                    Text("Brightness")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(brightness * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $brightness, in: 0...1) { _ in
                    updateCurrentColor()
                }
                .accentColor(.clear)
            }
            .padding(.horizontal, 12)
            
            // Color history
            if !canvasEngine.colorHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Colors")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(canvasEngine.colorHistory.prefix(20), id: \.self) { color in
                                Circle()
                                    .fill(Color(
                                        red: Double(color.x),
                                        green: Double(color.y),
                                        blue: Double(color.z),
                                        opacity: Double(color.w)
                                    ))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        canvasEngine.currentColor = color
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
        }
    }
    
    private var hueColors: [Color] {
        var colors: [Color] = []
        for i in 0...360 {
            colors.append(Color(hue: Double(i) / 360.0, saturation: 1, brightness: 1))
        }
        return colors
    }
    
    private func updateColor(from location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width/2, y: size.height/2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx*dx + dy*dy)
        let maxRadius = size.width * 0.35
        
        let angle = atan2(dy, dx) + .pi/2
        hue = (angle < 0 ? angle + 2 * .pi : angle) / (2 * .pi)
        saturation = min(distance / maxRadius, 1.0)
        
        updateCurrentColor()
    }
    
    private func updateCurrentColor() {
        let color = Color(hue: hue, saturation: saturation, brightness: brightness)
        let nsColor = NSColor(color).usingColorSpace(.sRGB)!
        canvasEngine.currentColor = SIMD4<Float>(
            Float(nsColor.redComponent),
            Float(nsColor.greenComponent),
            Float(nsColor.blueComponent),
            Float(nsColor.alphaComponent)
        )
        
        // Add to history
        if !canvasEngine.colorHistory.contains(where: { simd_equal($0, canvasEngine.currentColor) }) {
            canvasEngine.colorHistory.insert(canvasEngine.currentColor, at: 0)
            if canvasEngine.colorHistory.count > 50 {
                canvasEngine.colorHistory.removeLast()
            }
        }
    }
}

struct ColorClassicView: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var red: Double = 1
    @State private var green: Double = 0
    @State private var blue: Double = 0
    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    
    var body: some View {
        VStack(spacing: 16) {
            // RGB Sliders
            VStack(spacing: 12) {
                ColorSlider(label: "R", value: $red, color: .red) { updateFromRGB() }
                ColorSlider(label: "G", value: $green, color: .green) { updateFromRGB() }
                ColorSlider(label: "B", value: $blue, color: .blue) { updateFromRGB() }
            }
            
            Divider()
            
            // HSB Sliders
            VStack(spacing: 12) {
                ColorSlider(label: "H", value: $hue, range: 0...360, color: .orange) { updateFromHSB() }
                ColorSlider(label: "S", value: $saturation, color: .purple) { updateFromHSB() }
                ColorSlider(label: "B", value: $brightness, color: .yellow) { updateFromHSB() }
            }
            
            Divider()
            
            // Hex input
            HStack {
                Text("#")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                TextField("Hex", text: Binding(
                    get: { String(format: "%02X%02X%02X", Int(red*255), Int(green*255), Int(blue*255)) },
                    set: { newValue in
                        if newValue.count == 6,
                           let value = UInt32(newValue, radix: 16) {
                            red = Double((value >> 16) & 0xFF) / 255.0
                            green = Double((value >> 8) & 0xFF) / 255.0
                            blue = Double(value & 0xFF) / 255.0
                            updateFromRGB()
                        }
                    }
                })
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 80)
            }
            .padding(.horizontal, 12)
        }
        .onAppear {
            syncFromCurrentColor()
        }
    }
    
    private func syncFromCurrentColor() {
        red = Double(canvasEngine.currentColor.x)
        green = Double(canvasEngine.currentColor.y)
        blue = Double(canvasEngine.currentColor.z)
        
        let color = Color(red: red, green: green, blue: blue)
        let nsColor = NSColor(color).usingColorSpace(.sRGB)!
        hue = nsColor.hueComponent * 360
        saturation = nsColor.saturationComponent
        brightness = nsColor.brightnessComponent
    }
    
    private func updateFromRGB() {
        let color = Color(red: red, green: green, blue: blue)
        let nsColor = NSColor(color).usingColorSpace(.sRGB)!
        
        hue = nsColor.hueComponent * 360
        saturation = nsColor.saturationComponent
        brightness = nsColor.brightnessComponent
        
        updateCurrentColor()
    }
    
    private func updateFromHSB() {
        let color = Color(hue: hue/360, saturation: saturation, brightness: brightness)
        let nsColor = NSColor(color).usingColorSpace(.sRGB)!
        
        red = nsColor.redComponent
        green = nsColor.greenComponent
        blue = nsColor.blueComponent
        
        updateCurrentColor()
    }
    
    private func updateCurrentColor() {
        canvasEngine.currentColor = SIMD4<Float>(Float(red), Float(green), Float(blue), 1)
    }
}

struct ColorSlider: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    let color: Color
    let onChange: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
                .frame(width: 16)
            
            Slider(value: $value, in: range) { _ in
                onChange()
            }
            .accentColor(color)
            
            Text(String(format: range.upperBound > 1 ? "%.0f" : "%.0f%%", value * (range.upperBound > 1 ? 1 : 100)))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 45, alignment: .trailing)
        }
        .padding(.horizontal, 12)
    }
}

struct ColorHarmonyView: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var harmonyType = 0
    
    private let harmonyTypes = ["Complementary", "Analogous", "Triadic", "Tetradic", "Split Complementary"]
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("Harmony", selection: $harmonyType) {
                ForEach(0..<harmonyTypes.count, id: \.self) { index in
                    Text(harmonyTypes[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            
            // Harmony colors
            VStack(spacing: 12) {
                let baseColor = Color(
                    red: Double(canvasEngine.currentColor.x),
                    green: Double(canvasEngine.currentColor.y),
                    blue: Double(canvasEngine.currentColor.z)
                )
                let nsColor = NSColor(baseColor).usingColorSpace(.sRGB)!
                let baseHue = nsColor.hueComponent
                
                let harmonyColors = getHarmonyColors(baseHue: baseHue, type: harmonyType)
                
                ForEach(Array(harmonyColors.enumerated()), id: \.offset) { index, color in
                    HStack {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .onTapGesture {
                                let nsC = NSColor(color).usingColorSpace(.sRGB)!
                                canvasEngine.currentColor = SIMD4<Float>(
                                    Float(nsC.redComponent),
                                    Float(nsC.greenComponent),
                                    Float(nsC.blueComponent),
                                    1
                                )
                            }
                        
                        Text(String(format: "#%02X%02X%02X",
                                   Int(color.redComponent * 255),
                                   Int(color.greenComponent * 255),
                                   Int(color.blueComponent * 255)))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .padding(.horizontal, 12)
                }
            }
        }
    }
    
    private func getHarmonyColors(baseHue: CGFloat, type: Int) -> [Color] {
        var colors: [Color] = []
        let base = baseHue
        
        switch type {
        case 0: // Complementary
            colors = [base, (base + 0.5).truncatingRemainder(dividingBy: 1.0)]
        case 1: // Analogous
            colors = [base, (base + 0.083).truncatingRemainder(dividingBy: 1.0), (base - 0.083 + 1.0).truncatingRemainder(dividingBy: 1.0)]
        case 2: // Triadic
            colors = [base, (base + 1.0/3.0).truncatingRemainder(dividingBy: 1.0), (base + 2.0/3.0).truncatingRemainder(dividingBy: 1.0)]
        case 3: // Tetradic
            colors = [base, (base + 0.25).truncatingRemainder(dividingBy: 1.0), (base + 0.5).truncatingRemainder(dividingBy: 1.0), (base + 0.75).truncatingRemainder(dividingBy: 1.0)]
        case 4: // Split Complementary
            colors = [base, (base + 0.416).truncatingRemainder(dividingBy: 1.0), (base + 0.583).truncatingRemainder(dividingBy: 1.0)]
        default:
            colors = [base]
        }
        
        return colors.map { Color(hue: Double($0), saturation: 1, brightness: 1) }
    }
}

struct ColorValueView: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var r: Double = 1
    @State private var g: Double = 0
    @State private var b: Double = 0
    @State private var a: Double = 1
    
    var body: some View {
        VStack(spacing: 16) {
            // RGBA Sliders (0-255)
            VStack(spacing: 12) {
                ValueSlider(label: "R", value: $r, range: 0...255, color: .red) { updateFromRGBA() }
                ValueSlider(label: "G", value: $g, range: 0...255, color: .green) { updateFromRGBA() }
                ValueSlider(label: "B", value: $b, range: 0...255, color: .blue) { updateFromRGBA() }
                ValueSlider(label: "A", value: $a, range: 0...255, color: .gray) { updateFromRGBA() }
            }
            .padding(.horizontal, 12)
            
            Divider()
            
            // CMYK (read-only for reference)
            if canvasEngine.currentCanvas?.colorProfileEnum == .cmyk {
                VStack(spacing: 12) {
                    Text("CMYK (Reference)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    let cmyk = rgbToCmyk(r: r/255, g: g/255, b: b/255)
                    ValueSlider(label: "C", value: .constant(cmyk.c * 100), range: 0...100, color: .cyan) {}
                    ValueSlider(label: "M", value: .constant(cmyk.m * 100), range: 0...100, color: .magenta) {}
                    ValueSlider(label: "Y", value: .constant(cmyk.y * 100), range: 0...100, color: .yellow) {}
                    ValueSlider(label: "K", value: .constant(cmyk.k * 100), range: 0...100, color: .black) {}
                }
                .padding(.horizontal, 12)
            }
        }
        .onAppear {
            syncFromCurrentColor()
        }
    }
    
    private func syncFromCurrentColor() {
        r = Double(canvasEngine.currentColor.x) * 255
        g = Double(canvasEngine.currentColor.y) * 255
        b = Double(canvasEngine.currentColor.z) * 255
        a = Double(canvasEngine.currentColor.w) * 255
    }
    
    private func updateFromRGBA() {
        canvasEngine.currentColor = SIMD4<Float>(
            Float(r/255),
            Float(g/255),
            Float(b/255),
            Float(a/255)
        )
    }
    
    private func rgbToCmyk(r: Double, g: Double, b: Double) -> (c: Double, m: Double, y: Double, k: Double) {
        let k = 1 - max(r, max(g, b))
        if k == 1 { return (0, 0, 0, 1) }
        let c = (1 - r - k) / (1 - k)
        let m = (1 - g - k) / (1 - k)
        let y = (1 - b - k) / (1 - k)
        return (c, m, y, k)
    }
}

struct ValueSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    let onChange: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
                .frame(width: 16)
            
            Slider(value: $value, in: range) { _ in
                onChange()
            }
            .accentColor(color)
            
            Text(String(format: range.upperBound > 1 ? "%.0f" : "%.2f", value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

struct ColorPalettesView: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var showingNewPalette = false
    @State private var newPaletteName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Palette list
            List {
                ForEach(Array(BrushLibrary.shared.colorPalettes.enumerated()), id: \.element.id) { index, palette in
                    PaletteRow(palette: palette, isDefault: palette.isDefault)
                        .environmentObject(canvasEngine)
                }
                .onDelete { indexSet in
                    // Delete palettes
                }
            }
            .listStyle(.plain)
            
            Divider()
            
            // Footer
            HStack {
                Button(action: { showingNewPalette = true }) {
                    Label("New Palette", systemImage: "plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingNewPalette) {
                    NewPaletteSheet(name: $newPaletteName)
                        .environmentObject(canvasEngine)
                }
                
                Spacer()
                
                Button("Import") {
                    importPalette()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
            }
            .padding()
        }
    }
    
    private func importPalette() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "swatches")!,
            UTType(filenameExtension: "ase")!,
            UTType(filenameExtension: "aco")!
        ]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            if let palette = FileIO().importPalette(from: url) {
                // Add palette
            }
        }
    }
}

struct PaletteRow: View {
    let palette: ColorPalette
    let isDefault: Bool
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Swatches
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 28), spacing: 4)], spacing: 4) {
                ForEach(Array(palette.swatches?.toArray(ofType: Swatch.self).sorted { $0.position < $1.position } ?? []), id: \.id) { swatch in
                    ColorSwatch(swatch: swatch)
                        .environmentObject(canvasEngine)
                }
            }
            .padding(.vertical, 8)
        } label: {
            HStack {
                if isDefault {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
                
                Text(palette.name)
                    .font(.system(size: 13))
                
                Spacer()
                
                Text("\(palette.swatches?.count ?? 0)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ColorSwatch: View {
    let swatch: Swatch
    @EnvironmentObject var canvasEngine: CanvasEngine
    
    var body: some View {
        let color = Color(
            red: Double((swatch.color >> 24) & 0xFF) / 255.0,
            green: Double((swatch.color >> 16) & 0xFF) / 255.0,
            blue: Double((swatch.color >> 8) & 0xFF) / 255.0,
            opacity: Double(swatch.color & 0xFF) / 255.0
        )
        
        Circle()
            .fill(color)
            .frame(width: 28, height: 28)
            .overlay(
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .onTapGesture {
                canvasEngine.currentColor = SIMD4<Float>(
                    Float(color.redComponent),
                    Float(color.greenComponent),
                    Float(color.blueComponent),
                    Float(color.opacity)
                )
            }
            .contextMenu {
                Button("Set as Color") {
                    canvasEngine.currentColor = SIMD4<Float>(
                        Float(color.redComponent),
                        Float(color.greenComponent),
                        Float(color.blueComponent),
                        Float(color.opacity)
                    )
                }
                
                Button("Delete") {
                    // Delete swatch
                }
            }
    }
}

struct NewPaletteSheet: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @Environment(\.dismiss) var dismiss
    @Binding var name: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Palette")
                .font(.headline)
            
            TextField("Palette Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            
            HStack {
                Button("Cancel") { dismiss() }
                Button("Create") {
                    // Create palette
                    dismiss()
                }
                .disabled(name.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
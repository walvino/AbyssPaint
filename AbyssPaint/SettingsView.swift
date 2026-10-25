import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var preferences: Preferences
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    
    private let tabs = [
        ("General", "gear"),
        ("Canvas", "doc.text"),
        ("Interface", "paintbrush"),
        ("Gestures", "hand.tap"),
        ("Pressure", "slider.horizontal.3"),
        ("QuickMenu", "circle.lefthalf.filled"),
        ("Tablet", "tablet"),
        ("Performance", "speedometer"),
        ("Export", "square.and.arrow.up"),
        ("Advanced", "wrench.and.screwdriver")
    ]
    
    var body: some View {
        HSplitView {
            // Sidebar
            List(selection: $selectedTab) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Label(tabs[index].0, systemImage: tabs[index].1)
                        .tag(index)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180, maxWidth: 220)
            
            // Content
            Group {
                switch selectedTab {
                case 0: GeneralSettings()
                case 1: CanvasSettings()
                case 2: InterfaceSettings()
                case 3: GesturesSettings()
                case 4: PressureSettings()
                case 5: QuickMenuSettings()
                case 6: TabletSettings()
                case 7: PerformanceSettings()
                case 8: ExportSettings()
                case 9: AdvancedSettings()
                default: GeneralSettings()
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .frame(width: 720, height: 540)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct GeneralSettings: View {
    @EnvironmentObject var preferences: Preferences
    
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $preferences.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Language", selection: $preferences.language) {
                    Text("English").tag("en")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                    Text("Japanese").tag("ja")
                    Text("Chinese (Simplified)").tag("zh-Hans")
                    Text("Chinese (Traditional)").tag("zh-Hant")
                    Text("Korean").tag("ko")
                    Text("Portuguese").tag("pt")
                    Text("Russian").tag("ru")
                }
            }
            
            Section("Behavior") {
                Stepper("Auto-save Interval: \(preferences.autoSaveInterval)s", value: $preferences.autoSaveInterval, in: 10...300, step: 10)
                
                Toggle("Show Touch Points", isOn: $preferences.showTouchPoints)
            }
            
            Section("Startup") {
                // New canvas on launch, restore windows, etc.
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct CanvasSettings: View {
    @EnvironmentObject var preferences: Preferences
    
    var body: some View {
        Form {
            Section("New Canvas Defaults") {
                HStack {
                    Text("Width")
                    Spacer()
                    TextField("", value: $preferences.defaultCanvasWidth, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("", value: $preferences.defaultCanvasHeight, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                
                HStack {
                    Text("DPI")
                    Spacer()
                    TextField("", value: $preferences.defaultDPI, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                HStack {
                    Text("Color Profile")
                    Spacer()
                    Picker("", selection: $preferences.defaultColorProfile) {
                        ForEach(ColorProfile.allCases, id: \.self) { profile in
                            Text(profile.rawValue.uppercased()).tag(profile)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                
                ColorPicker("Background Color", selection: $preferences.canvasBackgroundColor)
            }
            
            Section("Color Management") {
                Toggle("Soft Proof on Export", isOn: .constant(false))
                Toggle("Warn on Profile Mismatch", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct InterfaceSettings: View {
    @EnvironmentObject var preferences: Preferences
    
    var body: some View {
        Form {
            Section("Layout") {
                Toggle("Left-handed Mode", isOn: $preferences.leftHandedMode)
                
                Picker("Brush Cursor", selection: $preferences.brushCursorType) {
                    ForEach(BrushCursorType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                
                Toggle("Show Cursor Preview", isOn: $preferences.showCursorPreview)
                
                HStack {
                    Text("Interface Scale")
                    Spacer()
                    Slider(value: $preferences.interfaceScale, in: 0.75...2.0, step: 0.05) {
                        Text("Scale")
                    } minimumValueLabel: {
                        Text("75%")
                    } maximumValueLabel: {
                        Text("200%")
                    }
                    .frame(width: 150)
                    Text("\(Int(preferences.interfaceScale * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50)
                }
                
                Toggle("Show Scrollbars", isOn: $preferences.showScrollbars)
            }
            
            Section("Panels") {
                // Panel behavior settings
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct GesturesSettings: View {
    @EnvironmentObject var preferences: Preferences
    
    var body: some View {
        Form {
            Section("Touch Gestures") {
                Toggle("Enable Touch Gestures", isOn: $preferences.enableTouchGestures)
                
                GesturePicker(label: "Two-finger Tap", action: $preferences.twoFingerTapAction)
                GesturePicker(label: "Three-finger Tap", action: $preferences.threeFingerTapAction)
                GesturePicker(label: "Four-finger Tap", action: $preferences.fourFingerTapAction)
            }
            
            Section("Custom Gestures") {
                // Custom gesture mappings
                ForEach(Array(preferences.gestureMappings.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { preferences.gestureMappings[key] ?? .none },
                            set: { preferences.gestureMappings[key] = $0 }
                        )) {
                            ForEach(GestureAction.allCases, id: \.self) { action in
                                Text(action.rawValue).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct GesturePicker: View {
    let label: String
    @Binding var action: GestureAction
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Picker("", selection: $action) {
                ForEach(GestureAction.allCases, id: \.self) { action in
                    Text(action.rawValue).tag(action)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
        }
    }
}

struct PressureSettings: View {
    @EnvironmentObject var preferences: Preferences
    
    var body: some View {
        Form {
            Section("Pressure Curve") {
                PressureCurveEditor(curve: $preferences.pressureCurve)
                    .frame(height: 200)
                
                HStack {
                    Button("Linear") {
                        preferences.pressureCurve = PressureCurve(
                            points: [
                                SIMD2<Float>(0, 0),
                                SIMD2<Float>(0.5, 0.5),
                                SIMD2<Float>(0.5, 0.5),
                                SIMD2<Float>(1, 1)
                            ],
                            smoothing: preferences.pressureCurve.smoothing,
                            motionFiltering: preferences.pressureCurve.motionFiltering
                        )
                    }
                    
                    Button("Soft") {
                        preferences.pressureCurve = PressureCurve(
                            points: [
                                SIMD2<Float>(0, 0),
                                SIMD2<Float>(0.25, 0.15),
                                SIMD2<Float>(0.75, 0.85),
                                SIMD2<Float>(1, 1)
                            ],
                            smoothing: preferences.pressureCurve.smoothing,
                            motionFiltering: preferences.pressureCurve.motionFiltering
                        )
                    }
                    
                    Button("Hard") {
                        preferences.pressureCurve = PressureCurve(
                            points: [
                                SIMD2<Float>(0, 0),
                                SIMD2<Float>(0.25, 0.35),
                                SIMD2<Float>(0.75, 0.65),
                                SIMD2<Float>(1, 1)
                            ],
                            smoothing: preferences.pressureCurve.smoothing,
                            motionFiltering: preferences.pressureCurve.motionFiltering
                        )
                    }
                    
                    Button("Reset") {
                        preferences.pressureCurve = .default
                    }
                }
            }
            
            Section("Stroke Smoothing") {
                HStack {
                    Text("Streamline")
                    Spacer()
                    Slider(value: $preferences.strokeSmoothing, in: 0...1, step: 0.01) {
                        Text("Smoothing")
                    } minimumValueLabel: {
                        Text("0%")
                    } maximumValueLabel: {
                        Text("100%")
                    }
                    .frame(width: 200)
                    Text("\(Int(preferences.strokeSmoothing * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Motion Filtering")
                    Spacer()
                    Slider(value: $preferences.motionFiltering, in: 0...1, step: 0.01) {
                        Text("Filtering")
                    } minimumValueLabel: {
                        Text("Off")
                    } maximumValueLabel: {
                        Text("Max")
                    }
                    .frame(width: 200)
                    Text("\(Int(preferences.motionFiltering * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Taper Length")
                    Spacer()
                    Slider(value: $preferences.taperLength, in: 0...1, step: 0.01) {
                        Text("Taper")
                    } minimumValueLabel: {
                        Text("0%")
                    } maximumValueLabel: {
                        Text("100%")
                    }
                    .frame(width: 200)
                    Text("\(Int(preferences.taperLength * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PressureCurveEditor: View {
    @Binding var curve: PressureCurve
    @State private var draggedPoint: Int?
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Grid
                Path { path in
                    for i in 0...4 {
                        let x = width * CGFloat(i) / 4
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                        
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                
                // Curve
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    
                    for i in 0...100 {
                        let t = Float(i) / 100.0
                        let y = curve.evaluate(t)
                        let x = width * CGFloat(t)
                        let py = height - height * CGFloat(y)
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: py))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: py))
                        }
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)
                
                // Control points
                ForEach(0..<curve.points.count, id: \.self) { index in
                    let point = curve.points[index]
                    let x = width * CGFloat(point.x)
                    let y = height - height * CGFloat(point.y)
                    
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .position(x: x, y: y)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggedPoint = index
                                    let newX = clamp(value.location.x / width, 0, 1)
                                    let newY = 1 - clamp(value.location.y / height, 0, 1)
                                    curve.points[index] = SIMD2<Float>(Float(newX), Float(newY))
                                    // Keep points ordered by x
                                    curve.points.sort { $0.x < $1.x }
                                }
                                .onEnded { _ in
                                    draggedPoint = nil
                                }
                        )
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func clamp(_ value: CGFloat, _ min: CGFloat, _ max: CGFloat) -> CGFloat {
        return Swift.max(min, Swift.min(max, value))
    }
}

struct QuickMenuSettings: View {
    @EnvironmentObject var preferences: Preferences
    @State private var selectedProfile = 0
    
    var body: some View {
        Form {
            Section("Profiles") {
                Picker("Active Profile", selection: $preferences.quickMenuProfile) {
                    ForEach(0..<preferences.quickMenuSlots.count, id: \.self) { index in
                        Text("Profile \(index + 1)").tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Slots") {
                ForEach(0..<6, id: \.self) { slotIndex in
                    HStack {
                        Text("Slot \(slotIndex + 1)")
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("", selection: Binding(
                            get: { preferences.quickMenuSlots[selectedProfile][slotIndex].action },
                            set: { preferences.quickMenuSlots[selectedProfile][slotIndex].action = $0 }
                        )) {
                            ForEach(GestureAction.allCases, id: \.self) { action in
                                Text(action.rawValue).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct TabletSettings: View {
    @EnvironmentObject var preferences: Preferences
    @StateObject private var tabletInput = TabletInput()
    
    var body: some View {
        Form {
            Section("Connected Tablets") {
                if tabletInput.connectedTablets.isEmpty {
                    Text("No tablets detected")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(tabletInput.connectedTablets, id: \.vendorID) { tablet in
                        HStack {
                            Image(systemName: tablet.isWacom ? "circle.fill" : tablet.isHuion ? "h.circle.fill" : "x.circle.fill")
                                .foregroundColor(tablet.isWacom ? .blue : tablet.isHuion ? .orange : .green)
                            VStack(alignment: .leading) {
                                Text(tablet.displayName)
                                    .font(.system(size: 13))
                                Text("VID: \(tablet.vendorID), PID: \(tablet.productID)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Label(tablet.supportsPressure ? "Pressure" : "No Pressure", systemImage: tablet.supportsPressure ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Label(tablet.supportsTiltX && tablet.supportsTiltY ? "Tilt" : "No Tilt", systemImage: tablet.supportsTiltX && tablet.supportsTiltY ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Label(tablet.supportsRotation ? "Rotation" : "No Rotation", systemImage: tablet.supportsRotation ? "checkmark.circle.fill" : "xmark.circle.fill")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("Button Mapping") {
                ForEach(0..<10, id: \.self) { button in
                    HStack {
                        Text("Button \(button + 1)")
                            .frame(width: 100, alignment: .leading)
                        
                        Picker("", selection: Binding(
                            get: { preferences.tabletButtonMappings[button] ?? .none },
                            set: { preferences.tabletButtonMappings[button] = $0 }
                        )) {
                            ForEach(TabletAction.allCases, id: \.self) { action in
                                Text(String(describing: action)).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                }
            }
            
            Section("Pressure") {
                HStack {
                    Text("Sensitivity")
                    Spacer()
                    Slider(value: $preferences.tabletPressureSensitivity, in: 0.5...2.0, step: 0.1) {
                        Text("Sensitivity")
                    } minimumValueLabel: {
                        Text("Low")
                    } maximumValueLabel: {
                        Text("High")
                    }
                    .frame(width: 200)
                    Text(String(format: "%.1fx", preferences.tabletPressureSensitivity))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50)
                }
                
                Toggle("Use Windows Ink (Windows)", isOn: $preferences.useWindowsInk)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PerformanceSettings: View {
    @EnvironmentObject var preferences: Preferences
    
    var body: some View {
        Form {
            Section("Memory") {
                HStack {
                    Text("Max Undo Steps")
                    Spacer()
                    Stepper("", value: $preferences.maxUndoSteps, in: 20...500, step: 10)
                    Text("\(preferences.maxUndoSteps)")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Tile Cache Size")
                    Spacer()
                    Stepper("", value: $preferences.tileCacheSize, in: 128...4096, step: 128)
                    Text("\(preferences.tileCacheSize) MB")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 80)
                }
                
                Toggle("Low Memory Mode", isOn: $preferences.useLowMemoryMode)
            }
            
            Section("Rendering") {
                Toggle("Metal Validation Layer", isOn: $preferences.enableMetalValidation)
                
                // GPU info
                if let device = MTLCreateSystemDefaultDevice() {
                    HStack {
                        Text("GPU")
                        Spacer()
                        Text(device.name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Threads")
                        Spacer()
                        Text("\(device.maxThreadsPerThreadgroup)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ExportSettings: View {
    @EnvironmentObject var preferences: Preferences
    
    var body: some View {
        Form {
            Section("Defaults") {
                Picker("Format", selection: $preferences.defaultExportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(String(describing: format).uppercased()).tag(format)
                    }
                }
                .pickerStyle(.menu)
                
                HStack {
                    Text("Quality")
                    Spacer()
                    Slider(value: $preferences.exportQuality, in: 0.1...1.0, step: 0.05) {
                        Text("Quality")
                    } minimumValueLabel: {
                        Text("Low")
                    } maximumValueLabel: {
                        Text("Max")
                    }
                    .frame(width: 200)
                    Text("\(Int(preferences.exportQuality * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50)
                }
                
                Toggle("Include Metadata", isOn: $preferences.includeMetadata)
                
                HStack {
                    Text("DPI")
                    Spacer()
                    TextField("", value: $preferences.defaultExportDPI, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                Picker("Color Profile", selection: $preferences.exportColorProfile) {
                    ForEach(ColorProfile.allCases, id: \.self) { profile in
                        Text(profile.rawValue.uppercased()).tag(profile)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            
            Section("File Naming") {
                // Naming template
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AdvancedSettings: View {
    @EnvironmentObject var preferences: Preferences
    
    var body: some View {
        Form {
            Section("Experimental") {
                Toggle("Enable Experimental Features", isOn: $preferences.enableExperimentalFeatures)
                
                Toggle("Show Debug Overlay", isOn: $preferences.showDebugOverlay)
                
                Picker("Log Level", selection: $preferences.logLevel) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Reset") {
                Button("Reset All Settings to Defaults") {
                    preferences.resetToDefaults()
                }
                .foregroundColor(.red)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("2026.1")
                        .foregroundColor(.secondary)
                }
                
                Link("AbyssPaint Website", destination: URL(string: "https://abysspaint.app")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/AbyssPaint/issues")!)
                Link("Privacy Policy", destination: URL(string: "https://abysspaint.app/privacy")!)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
import SwiftUI

struct BrushLibraryPanel: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var selectedSetIndex = 0
    @State private var searchText = ""
    @State private var showingImportSheet = false
    @State private var showingNewBrushSheet = false
    
    var filteredBrushes: [Brush] {
        let brushes = canvasEngine.brushes
        if searchText.isEmpty {
            return brushes
        }
        return brushes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("BRUSHES")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Spacer()
                
                Button(action: { showingNewBrushSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("New Brush")
                .sheet(isPresented: $showingNewBrushSheet) {
                    NewBrushSheet()
                        .environmentObject(canvasEngine)
                }
                
                Button(action: { showingImportSheet = true }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Import Brushes")
                .sheet(isPresented: $showingImportSheet) {
                    ImportBrushSheet()
                        .environmentObject(canvasEngine)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Brush set selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(BrushLibrary.shared.brushSets.enumerated()), id: \.element.id) { index, set in
                        Button(action: {
                            selectedSetIndex = index
                        }) {
                            Text(set.name)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(selectedSetIndex == index ? Color.accentColor : Color.clear)
                                )
                                .foregroundColor(selectedSetIndex == index ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search brushes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Brush grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 8)], spacing: 8) {
                    ForEach(filteredBrushes, id: \.id) { brush in
                        BrushThumbnail(brush: brush, isSelected: canvasEngine.selectedBrush?.id == brush.id)
                            .environmentObject(canvasEngine)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct BrushThumbnail: View {
    let brush: Brush
    let isSelected: Bool
    @EnvironmentObject var canvasEngine: CanvasEngine
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Brush preview
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                
                // Brush stroke preview
                if let thumbnailData = brush.thumbnailData,
                   let nsImage = NSImage(data: thumbnailData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 40)
                        .cornerRadius(4)
                } else {
                    // Generated preview
                    BrushPreviewShape(brush: brush)
                        .stroke(Color.primary.opacity(0.6), lineWidth: 2)
                        .frame(height: 40)
                        .padding(8)
                }
                
                // Source indicator
                VStack {
                    HStack {
                        Spacer()
                        sourceIndicator
                    }
                    Spacer()
                }
                .padding(4)
            }
            .onTapGesture {
                canvasEngine.selectedBrush = brush
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .contextMenu {
                Button("Select") {
                    canvasEngine.selectedBrush = brush
                }
                
                Button("Duplicate") {
                    // Duplicate brush
                }
                
                Button("Delete") {
                    // Delete brush (if custom)
                }
                .disabled(brush.source == .builtin)
                
                Divider()
                
                Button("Rename") {
                    // Rename brush
                }
                
                Button("Export") {
                    // Export brush
                }
            }
            
            // Brush name
            Text(brush.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var sourceIndicator: some View {
        Group {
            switch brush.source {
            case .builtin:
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.yellow)
            case .imported:
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.blue)
            case .custom:
                Image(systemName: "pencil.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.green)
            }
        }
    }
}

struct BrushPreviewShape: Shape {
    let brush: Brush
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * 0.8
        
        // Draw a sample stroke based on brush properties
        path.move(to: CGPoint(x: center.x - radius, y: center.y))
        
        // Simulate pressure curve
        for i in 0...20 {
            let t = Float(i) / 20.0
            let x = center.x - radius + CGFloat(t) * radius * 2
            
            // Apply taper
            var pressure: Float = 1.0
            if t < brush.taperLength {
                pressure *= t / brush.taperLength
            }
            if t > 1.0 - brush.taperLength {
                pressure *= (1.0 - t) / brush.taperLength
            }
            
            let y = center.y + sin(CGFloat(t) * 4 * .pi) * radius * 0.3 * CGFloat(pressure)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
}

struct NewBrushSheet: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var basedOnBrush: Brush?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Brush")
                .font(.headline)
            
            TextField("Brush Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            
            Picker("Based On", selection: $basedOnBrush) {
                Text("Basic Round").tag(nil as Brush?)
                ForEach(BrushLibrary.shared.allBrushes(), id: \.id) { brush in
                    Text(brush.name).tag(brush as Brush?)
                }
            }
            .frame(width: 200)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Button("Create") {
                    // Create new brush based on selection
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

struct ImportBrushSheet: View {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Import Brushes")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button(".abyssbrush") {
                    importBrushes(fileType: "abyssbrush")
                }
                
                Button(".abyssbrushset") {
                    importBrushes(fileType: "abyssbrushset")
                }
                
                Button(".brush (Procreate)") {
                    importBrushes(fileType: "brush")
                }
                
                Button(".brushset (Procreate)") {
                    importBrushes(fileType: "brushset")
                }
            }
            
            Button("Cancel") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func importBrushes(fileType: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: fileType)!]
        panel.allowsMultipleSelection = true
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let data = try? Data(contentsOf: url),
                   let brush = FileIO().importBrush(from: data) {
                    BrushLibrary.shared.addBrush(brush)
                }
            }
            dismiss()
        }
    }
}
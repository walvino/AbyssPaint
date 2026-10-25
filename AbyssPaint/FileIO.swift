import Foundation
import CoreData
import Metal
import MetalKit
import UniformTypeIdentifiers

// MARK: - File IO
class FileIO {
    private let device: MTLDevice
    private let textureLoader: MTKTextureLoader
    
    init() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.textureLoader = MTKTextureLoader(device: device)
    }
    
    // MARK: - AbyssPaint Format
    func exportCanvas(_ canvas: Canvas, format: ExportFormat, options: ExportOptions) -> Data? {
        switch format {
        case .abyssPaint:
            return exportAbyssPaintFormat(canvas, options: options)
        case .psd:
            return exportPSDFormat(canvas, options: options)
        case .png:
            return exportImageFormat(canvas, format: .png, options: options)
        case .jpeg:
            return exportImageFormat(canvas, format: .jpeg, options: options)
        case .tiff:
            return exportImageFormat(canvas, format: .tiff, options: options)
        case .pdf:
            return exportPDFFormat(canvas, options: options)
        default:
            return nil
        }
    }
    
    private func exportAbyssPaintFormat(_ canvas: Canvas, options: ExportOptions) -> Data? {
        var file = AbyssPaintFile()
        file.header = FileHeader(
            magic: "ABYSSPAINT",
            version: 1,
            canvasWidth: UInt32(canvas.width),
            canvasHeight: UInt32(canvas.height),
            dpi: UInt32(canvas.dpi),
            colorProfile: UInt16(canvas.colorProfile),
            backgroundColor: UInt32(canvas.backgroundColor),
            layerCount: UInt32(canvas.layers?.count ?? 0),
            hasTimeLapse: canvas.timeLapseEnabled
        )
        
        // Layers
        if let layers = canvas.layers?.toArray(ofType: Layer.self).sorted(by: { $0.order < $1.order }) {
            for layer in layers {
                var layerData = LayerFileData()
                layerData.id = layer.id
                layerData.name = layer.name
                layerData.type = UInt16(layer.type)
                layerData.blendMode = UInt16(layer.blendMode)
                layerData.opacity = layer.opacity
                layerData.visible = layer.visible
                layerData.locked = layer.locked
                layerData.alphaLocked = layer.alphaLocked
                layerData.order = layer.order
                layerData.parentID = layer.parent?.id
                layerData.clippingToID = layer.clippingTo?.id
                
                // Export layer texture (would come from render engine)
                // layerData.textureData = renderEngine.exportLayerTexture(layer.id)
                
                file.layers.append(layerData)
            }
        }
        
        // Brushes (only custom ones)
        // file.brushes = ...
        
        // Palettes
        // file.palettes = ...
        
        // Time-lapse
        // file.timeLapseData = ...
        
        // Serialize
        return try? JSONEncoder().encode(file)
    }
    
    private func exportPSDFormat(_ canvas: Canvas, options: ExportOptions) -> Data? {
        // PSD export implementation
        // This would use a PSD library or custom implementation
        // For now, return placeholder
        return nil
    }
    
    private func exportImageFormat(_ canvas: Canvas, format: ImageFormat, options: ExportOptions) -> Data? {
        // Get composite texture from render engine
        // Convert to target format
        return nil
    }
    
    private func exportPDFFormat(_ canvas: Canvas, options: ExportOptions) -> Data? {
        // PDF export with vector data where possible
        return nil
    }
    
    // MARK: - Import
    func importCanvas(from url: URL) -> Canvas? {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "abysspaint":
            return importAbyssPaintFormat(from: url)
        case "psd":
            return importPSDFormat(from: url)
        case "png", "jpg", "jpeg", "tiff", "heic":
            return importImageFormat(from: url)
        default:
            return nil
        }
    }
    
    private func importAbyssPaintFormat(from url: URL) -> Canvas? {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(AbyssPaintFile.self, from: data) else {
            return nil
        }
        
        let context = PersistenceController.shared.container.viewContext
        let canvas = Canvas.create(
            in: context,
            name: url.deletingPathExtension().lastPathComponent,
            width: Int(file.header.canvasWidth),
            height: Int(file.header.canvasHeight),
            dpi: Int(file.header.dpi),
            colorProfile: ColorProfile(rawValue: Int16(file.header.colorProfile)) ?? .sRGB
        )
        canvas.backgroundColor = Int32(bitPattern: file.header.backgroundColor)
        
        // Recreate layers
        for layerFileData in file.layers {
            let layer = Layer.create(
                in: context,
                name: layerFileData.name,
                type: LayerType(rawValue: Int16(layerFileData.type)) ?? .pixel,
                canvas: canvas,
                order: layerFileData.order
            )
            layer.blendMode = Int16(layerFileData.blendMode)
            layer.opacity = layerFileData.opacity
            layer.visible = layerFileData.visible
            layer.locked = layerFileData.locked
            layer.alphaLocked = layerFileData.alphaLocked
            
            if let parentID = layerFileData.parentID,
               let parent = canvas.layers?.toArray(ofType: Layer.self).first(where: { $0.id == parentID }) {
                layer.parent = parent
            }
            
            if let clippingID = layerFileData.clippingToID,
               let clipping = canvas.layers?.toArray(ofType: Layer.self).first(where: { $0.id == clippingID }) {
                layer.clippingTo = clipping
            }
            
            // Import texture data
            // renderEngine.importLayerTexture(layer.id, data: layerFileData.textureData)
        }
        
        try? context.save()
        return canvas
    }
    
    private func importPSDFormat(from url: URL) -> Canvas? {
        // PSD import implementation
        return nil
    }
    
    private func importImageFormat(from url: URL) -> Canvas? {
        // Import as single-layer canvas
        return nil
    }
    
    // MARK: - Brush Import/Export
    func exportBrush(_ brush: Brush) -> Data? {
        return brush.encode()
    }
    
    func importBrush(from data: Data) -> Brush? {
        return Brush.decode(from: data)
    }
    
    func exportBrushSet(_ brushSet: BrushSet) -> Data? {
        var file = BrushSetFile()
        file.name = brushSet.name
        file.brushes = brushSet.brushes.map { $0.encode()! }
        return try? JSONEncoder().encode(file)
    }
    
    func importBrushSet(from data: Data) -> BrushSet? {
        guard let file = try? JSONDecoder().decode(BrushSetFile.self, from: data) else { return nil }
        let brushSet = BrushSet(name: file.name)
        for brushData in file.brushes {
            if let brush = Brush.decode(from: brushData) {
                brushSet.addBrush(brush)
            }
        }
        return brushSet
    }
    
    // MARK: - Palette Import/Export
    func exportPalette(_ palette: ColorPalette) -> Data? {
        // Export as .swatches, .ase, .aco
        return nil
    }
    
    func importPalette(from url: URL) -> ColorPalette? {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "swatches":
            return importSwatchesFormat(from: url)
        case "ase":
            return importASEFormat(from: url)
        case "aco":
            return importACOFormat(from: url)
        default:
            return nil
        }
    }
    
    private func importSwatchesFormat(from url: URL) -> ColorPalette? { return nil }
    private func importASEFormat(from url: URL) -> ColorPalette? { return nil }
    private func importACOFormat(from url: URL) -> ColorPalette? { return nil }
    
    // MARK: - Texture Helpers
    func textureFromData(_ data: Data, width: Int, height: Int, pixelFormat: MTLPixelFormat = .rgba16Float) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        
        let bytesPerRow = width * MemoryLayout<Float>.stride * 4
        data.withUnsafeBytes { bytes in
            texture.replace(region: MTLRegionMake2D(0, 0, width, height),
                          mipmapLevel: 0,
                          withBytes: bytes.baseAddress!,
                          bytesPerRow: bytesPerRow)
        }
        return texture
    }
    
    func dataFromTexture(_ texture: MTLTexture) -> Data? {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * MemoryLayout<Float>.stride * 4
        let data = Data(count: height * bytesPerRow)
        
        data.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        
        return data
    }
}

// MARK: - File Structures
struct AbyssPaintFile: Codable {
    var header: FileHeader = FileHeader()
    var layers: [LayerFileData] = []
    var brushes: [Data] = []
    var palettes: [Data] = []
    var timeLapseData: Data?
    var metadata: [String: String] = [:]
}

struct FileHeader: Codable {
    var magic: String = ""
    var version: UInt16 = 1
    var canvasWidth: UInt32 = 0
    var canvasHeight: UInt32 = 0
    var dpi: UInt32 = 300
    var colorProfile: UInt16 = 0
    var backgroundColor: UInt32 = 0xFFFFFFFF
    var layerCount: UInt32 = 0
    var hasTimeLapse: Bool = false
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var appVersion: String = "1.0.0"
}

struct LayerFileData: Codable {
    var id: UUID = UUID()
    var name: String = ""
    var type: UInt16 = 0
    var blendMode: UInt16 = 0
    var opacity: Float = 1.0
    var visible: Bool = true
    var locked: Bool = false
    var alphaLocked: Bool = false
    var order: Int32 = 0
    var parentID: UUID?
    var clippingToID: UUID?
    var textureData: Data?
    var maskData: Data?
    var transformData: Data?
    var filtersData: Data?
}

struct BrushSetFile: Codable {
    var name: String = ""
    var brushes: [Data] = []
}

// MARK: - Image Format Helper
enum ImageFormat {
    case png
    case jpeg
    case tiff
    case heif
}
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AbyssPaint")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let storeURL = PersistenceController.storeURL
            container.persistentStoreDescriptions.first?.url = storeURL
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    static var storeURL: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0].appendingPathComponent("AbyssPaint", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        
        return appSupportURL.appendingPathComponent("AbyssPaint.sqlite")
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
}

// MARK: - Preview Helper
extension PersistenceController {
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Create sample data for previews
        let canvas = Canvas(context: context)
        canvas.id = UUID()
        canvas.name = "Sample Artwork"
        canvas.width = 3000
        canvas.height = 2000
        canvas.dpi = 300
        canvas.colorProfile = 0 // sRGB
        canvas.createdAt = Date()
        canvas.modifiedAt = Date()
        canvas.timeLapseEnabled = true
        canvas.timeLapseQuality = 1
        
        let backgroundLayer = Layer(context: context)
        backgroundLayer.id = UUID()
        backgroundLayer.name = "Background"
        backgroundLayer.type = 0 // pixel
        backgroundLayer.opacity = 1.0
        backgroundLayer.visible = true
        backgroundLayer.locked = false
        backgroundLayer.alphaLocked = false
        backgroundLayer.blendMode = 0 // normal
        backgroundLayer.order = 0
        backgroundLayer.canvas = canvas
        
        let layer1 = Layer(context: context)
        layer1.id = UUID()
        layer1.name = "Sketch"
        layer1.type = 0 // pixel
        layer1.opacity = 1.0
        layer1.visible = true
        layer1.locked = false
        layer1.alphaLocked = false
        layer1.blendMode = 1 // multiply
        layer1.order = 1
        layer1.canvas = canvas
        
        let layer2 = Layer(context: context)
        layer2.id = UUID()
        layer2.name = "Line Art"
        layer2.type = 0 // pixel
        layer2.opacity = 1.0
        layer2.visible = true
        layer2.locked = false
        layer2.alphaLocked = false
        layer2.blendMode = 0 // normal
        layer2.order = 2
        layer2.canvas = canvas
        
        do {
            try context.save()
        } catch {
            fatalError("Preview data creation failed: \(error)")
        }
        
        return controller
    }()
}
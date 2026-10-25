import SwiftUI

@main
struct AbyssPaintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("AbyssPaint") {
            ContentView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Canvas...") {
                    NotificationCenter.default.post(name: .newCanvasRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button("Open...") {
                    NotificationCenter.default.post(name: .openDocumentRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            CommandMenu("Canvas") {
                Button("Canvas Size...") {
                    NotificationCenter.default.post(name: .canvasSizeRequested, object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .option])
                
                Button("Crop...") {
                    NotificationCenter.default.post(name: .cropCanvasRequested, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Divider()
                
                Button("Canvas Info") {
                    NotificationCenter.default.post(name: .canvasInfoRequested, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
            
            CommandMenu("Layer") {
                Button("New Layer") {
                    NotificationCenter.default.post(name: .newLayerRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("Duplicate Layer") {
                    NotificationCenter.default.post(name: .duplicateLayerRequested, object: nil)
                }
                .keyboardShortcut("j", modifiers: .command)
                
                Button("Merge Down") {
                    NotificationCenter.default.post(name: .mergeDownRequested, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
                
                Divider()
                
                Button("New Group") {
                    NotificationCenter.default.post(name: .newGroupRequested, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)
                
                Button("Add Mask") {
                    NotificationCenter.default.post(name: .addMaskRequested, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
            
            CommandMenu("View") {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .zoomInRequested, object: nil)
                }
                .keyboardShortcut("=", modifiers: .command)
                
                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .zoomOutRequested, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Actual Size") {
                    NotificationCenter.default.post(name: .actualSizeRequested, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Button("Fit to Screen") {
                    NotificationCenter.default.post(name: .fitToScreenRequested, object: nil)
                }
                .keyboardShortcut("9", modifiers: .command)
                
                Divider()
                
                Button("Show/Hide Layers") {
                    NotificationCenter.default.post(name: .toggleLayersPanel, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("Show/Hide Brushes") {
                    NotificationCenter.default.post(name: .toggleBrushesPanel, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)
                
                Button("Show/Hide Color") {
                    NotificationCenter.default.post(name: .toggleColorPanel, object: nil)
                }
                .keyboardShortcut("c", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
    }
}

extension Notification.Name {
    static let newCanvasRequested = Notification.Name("newCanvasRequested")
    static let openDocumentRequested = Notification.Name("openDocumentRequested")
    static let canvasSizeRequested = Notification.Name("canvasSizeRequested")
    static let cropCanvasRequested = Notification.Name("cropCanvasRequested")
    static let canvasInfoRequested = Notification.Name("canvasInfoRequested")
    static let newLayerRequested = Notification.Name("newLayerRequested")
    static let duplicateLayerRequested = Notification.Name("duplicateLayerRequested")
    static let mergeDownRequested = Notification.Name("mergeDownRequested")
    static let newGroupRequested = Notification.Name("newGroupRequested")
    static let addMaskRequested = Notification.Name("addMaskRequested")
    static let zoomInRequested = Notification.Name("zoomInRequested")
    static let zoomOutRequested = Notification.Name("zoomOutRequested")
    static let actualSizeRequested = Notification.Name("actualSizeRequested")
    static let fitToScreenRequested = Notification.Name("fitToScreenRequested")
    static let toggleLayersPanel = Notification.Name("toggleLayersPanel")
    static let toggleBrushesPanel = Notification.Name("toggleBrushesPanel")
    static let toggleColorPanel = Notification.Name("toggleColorPanel")
}
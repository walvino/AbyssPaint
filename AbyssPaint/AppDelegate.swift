import Cocoa
import SwiftUI
import CoreData

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var canvasViewController: CanvasViewController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar
        setupMenuBar()
        
        // Register for tablet events
        TabletManager.shared.startMonitoring()
        
        // Restore windows
        NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: ""))
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            NotificationCenter.default.post(name: .openDocumentWithURL, object: url)
        }
    }
    
    private func setupMenuBar() {
        // Ensure we have a proper menu bar for macOS
        NSApp.mainMenu = NSMenu()
    }
}

extension Notification.Name {
    static let openDocumentWithURL = Notification.Name("openDocumentWithURL")
}

class CanvasViewController: NSViewController {
    private var canvasView: CanvasView?
    private var document: CanvasDocument?
    
    override func loadView() {
        canvasView = CanvasView()
        view = canvasView!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        canvasView?.setupCanvas()
    }
    
    func loadDocument(_ document: CanvasDocument) {
        self.document = document
        canvasView?.loadDocument(document)
    }
}

@objc
class CanvasDocument: NSDocument {
    var canvasEngine: CanvasEngine?
    
    override class var autosavesInPlace: Bool { true }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let windowController = storyboard.instantiateInitialController() as? NSWindowController,
           let viewController = windowController.contentViewController as? CanvasViewController {
            viewController.loadDocument(self)
            addWindowController(windowController)
        }
    }
    
    override func data(ofType typeName: String) throws -> Data {
        guard let engine = canvasEngine else { throw NSError(domain: "AbyssPaint", code: -1, userInfo: [NSLocalizedDescriptionKey: "No canvas engine"]) }
        return try engine.exportToAbyssPaintFormat()
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        canvasEngine = CanvasEngine()
        try canvasEngine?.importFromAbyssPaintFormat(data)
    }
}
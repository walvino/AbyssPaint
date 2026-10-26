import SwiftUI
import AppKit

@main
struct AbyssPaintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DocumentStore.shared

    var body: some Scene {
        WindowGroup("AbyssPaint") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1000, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 860)
        .commands {
            AbyssPaintCommands()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Diagnostics used during development.
        if let path = ProcessInfo.processInfo.environment["ABYSS_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if ProcessInfo.processInfo.environment["ABYSS_DEMO"] != nil {
                    SelfTest.paintDemo(DocumentStore.shared)
                }
                let windows = NSApp.windows.filter { ($0.contentView?.bounds.width ?? 0) > 200 }
                print("SNAPSHOT windows=\(windows.count) all=\(NSApp.windows.count)")
                for (index, window) in windows.enumerated() {
                    guard let view = window.contentView,
                          let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                        print("SNAPSHOT no rep for window \(index)")
                        continue
                    }
                    view.cacheDisplay(in: view.bounds, to: rep)
                    guard let data = rep.representation(using: .png, properties: [:]) else {
                        print("SNAPSHOT no data for window \(index)")
                        continue
                    }
                    let out = index == 0 ? path : path.replacingOccurrences(of: ".png", with: "-\(index).png")
                    do {
                        try data.write(to: URL(fileURLWithPath: out))
                        print("SNAPSHOT wrote \(out) \(data.count) bytes")
                    } catch {
                        print("SNAPSHOT write failed \(out): \(error)")
                    }
                }
                exit(0)
            }
        }

        if ProcessInfo.processInfo.environment["ABYSS_SELFTEST"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SelfTest.run()
                NSApp.terminate(nil)
            }
        }

        if let mode = ProcessInfo.processInfo.environment["ABYSS_AUTOSAVE_TEST"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                let store = DocumentStore.shared
                switch mode {
                case "write":
                    store.newDocument(width: 320, height: 240)
                    store.paperColor = NSColor(srgbRed: 0.16, green: 0.17, blue: 0.19, alpha: 1)
                    store.color = NSColor(srgbRed: 0.9, green: 0.2, blue: 0.15, alpha: 1)
                    store.brushSize = 40
                    store.brushHardness = 1
                    store.beginStroke(at: CGPoint(x: 60, y: 120), pressure: 1)
                    store.continueStroke(from: CGPoint(x: 60, y: 120),
                                        to: CGPoint(x: 260, y: 120),
                                        fromPressure: 1, toPressure: 1)
                    store.endStroke()
                    store.autosaveNow()
                    print("AUTOSAVE write exists=\(store.hasAutosave) edits=\(store.hasUnsavedEdits)")
                case "read":
                    let restored = store.restoreAutosave()
                    let sampled = store.sampleColor(at: CGPoint(x: 160, y: 120))?
                        .usingColorSpace(.sRGB)
                    print("AUTOSAVE read restored=\(restored) layers=\(store.layers.count) size=\(store.canvasSize) name=\(store.documentName) paper=\(store.paperColor.abyssHex)")
                    print("AUTOSAVE read sampled=\(sampled ?? .clear)")
                    store.clearAutosave()
                default:
                    print("AUTOSAVE unknown mode")
                }
                exit(0)
            }
        }

        if DocumentStore.shared.autosaveEnabled, DocumentStore.shared.hasAutosave {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.offerAutosave()
            }
        }
    }

    private func offerAutosave() {
        let store = DocumentStore.shared
        guard store.hasAutosave, store.documentURL == nil else { return }

        let alert = NSAlert()
        alert.messageText = "Recover unsaved artwork?"
        alert.informativeText = "AbyssPaint found artwork from your last session that was not saved to a project."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Recover")
        alert.addButton(withTitle: "Discard")

        if alert.runModal() == .alertFirstButtonReturn {
            if !store.restoreAutosave() {
                store.showToast("Could not recover the autosaved artwork")
                store.clearAutosave()
            }
        } else {
            store.clearAutosave()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DocumentStore.shared.autosaveNow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: { $0.pathExtension == "abysspaint" }) else { return }
        do {
            try DocumentStore.shared.openProject(from: url)
        } catch {
            DocumentStore.shared.showToast("Could not open \(url.lastPathComponent)")
        }
    }
}

enum SelfTest {
    static func run() {
        let store = DocumentStore.shared
        paintDemo(store)

        // Eyedropper sample
        if let sampled = store.sampleColor(at: CGPoint(x: 250, y: 930)) {
            print("SELFTEST sampled color: \(sampled.usingColorSpace(.sRGB) ?? sampled)")
        } else {
            print("SELFTEST sampled color: FAILED")
        }

        // Save and reopen the project
        let projectURL = URL(fileURLWithPath: "/tmp/abyss-selftest.abysspaint")
        try? FileManager.default.removeItem(at: projectURL)
        do {
            try store.saveProject(to: projectURL)
            store.newDocument(width: 640, height: 480)
            try store.openProject(from: projectURL)
            print("SELFTEST project roundtrip layers=\(store.layers.count) size=\(store.canvasSize)")
        } catch {
            print("SELFTEST project roundtrip FAILED: \(error)")
        }

        // Eraser pass through the green line
        store.tool = .eraser
        store.brushSize = 60
        var previous = CGPoint(x: 800, y: 1000)
        store.beginStroke(at: previous, pressure: 1)
        for step in 1...30 {
            let t = CGFloat(step) / 30
            let point = CGPoint(x: 800 + t * 200, y: 1000 - t * 220)
            store.continueStroke(from: previous, to: point, fromPressure: 1, toPressure: 1)
            previous = point
        }
        store.endStroke()
        store.tool = .brush

        if let image = store.flattenedImage() {
            let rep = NSBitmapImageRep(cgImage: image)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: "/tmp/abyss-selftest.png"))
            }
        }

        // Symmetry check on a scratch canvas
        store.newDocument(width: 400, height: 400)
        store.symmetry = .vertical
        store.tool = .brush
        store.brushSize = 24
        store.brushHardness = 1
        store.color = NSColor(srgbRed: 0.376, green: 0.804, blue: 0.451, alpha: 1)
        store.beginStroke(at: CGPoint(x: 60, y: 200), pressure: 1)
        store.continueStroke(from: CGPoint(x: 60, y: 200),
                            to: CGPoint(x: 140, y: 200),
                            fromPressure: 1,
                            toPressure: 1)
        store.endStroke()
        store.symmetry = .off

        let mirroredLeft = store.sampleColor(at: CGPoint(x: 80, y: 200))
        let mirroredRight = store.sampleColor(at: CGPoint(x: 320, y: 200))
        print("SELFTEST symmetry left=\(mirroredLeft?.usingColorSpace(.sRGB) ?? .clear) right=\(mirroredRight?.usingColorSpace(.sRGB) ?? .clear)")

        faseAChecks(store)
    }

    private static func faseAChecks(_ store: DocumentStore) {
        store.newDocument(width: 320, height: 240)
        store.paperColor = NSColor(srgbRed: 0.9, green: 0.8, blue: 0.7, alpha: 1)
        store.brushTaper = 0
        store.pressureCurve = 1

        // Layer rename
        let baseID = store.layers[0].id
        store.renameLayer(id: baseID, to: "Ink")
        print("SELFTEST rename=\(store.layers[0].name)")

        // Locked layers refuse paint
        store.setLayerLocked(true, id: baseID)
        let locked = store.beginStroke(at: CGPoint(x: 40, y: 40), pressure: 1)
        store.endStroke()
        store.setLayerLocked(false, id: baseID)
        print("SELFTEST lockedStrokeAccepted=\(locked)")

        // Alpha lock keeps paint inside existing pixels
        store.color = NSColor(srgbRed: 0.1, green: 0.8, blue: 0.2, alpha: 1)
        store.brushSize = 30
        store.brushHardness = 1
        store.beginStroke(at: CGPoint(x: 80, y: 120), pressure: 1)
        store.continueStroke(from: CGPoint(x: 80, y: 120),
                             to: CGPoint(x: 120, y: 120),
                             fromPressure: 1, toPressure: 1)
        store.endStroke()

        store.setLayerAlphaLocked(true, id: baseID)
        store.color = NSColor(srgbRed: 0.9, green: 0.1, blue: 0.1, alpha: 1)
        store.beginStroke(at: CGPoint(x: 80, y: 120), pressure: 1)
        store.continueStroke(from: CGPoint(x: 80, y: 120),
                             to: CGPoint(x: 200, y: 120),
                             fromPressure: 1, toPressure: 1)
        store.endStroke()
        store.setLayerAlphaLocked(false, id: baseID)
        let inside = store.sampleColor(at: CGPoint(x: 82, y: 120))?.usingColorSpace(.sRGB)
        let outside = store.sampleColor(at: CGPoint(x: 190, y: 120))?.usingColorSpace(.sRGB)
        print("SELFTEST alphaLock inside=\(inside ?? .clear) outside=\(outside ?? .clear)")

        // Reordering
        store.addLayer()
        let topID = store.layers[1].id
        store.renameLayer(id: topID, to: "Top")
        store.moveLayer(id: topID, toIndex: 0)
        print("SELFTEST reorder=\(store.layers.map(\.name))")

        // Paper colour reaches the flattened image
        store.activeLayerID = baseID
        if let flattened = store.flattenedImage() {
            let rep = NSBitmapImageRep(cgImage: flattened)
            if let pixel = rep.colorAt(x: 300, y: 20)?.usingColorSpace(.sRGB) {
                print("SELFTEST paper=\(pixel) hex=\(store.paperColor.abyssHex)")
            }
        }

        // Export encoders
        if let image = store.flattenedImage() {
            for format in DocumentStore.ExportFormat.allCases {
                let bytes = (try? store.exportData(image, as: format))?.count ?? -1
                print("SELFTEST export \(format.title)=\(bytes) bytes")
            }
        }

        // History slider
        print("SELFTEST history position=\(store.historyPosition) length=\(store.historyLength)")
        store.jumpHistory(to: 0)
        print("SELFTEST history after jump position=\(store.historyPosition) canRedo=\(store.canRedo)")
        store.jumpHistory(to: store.historyLength)
        print("SELFTEST history restored position=\(store.historyPosition) layers=\(store.layers.map(\.name))")

        // Project persistence for the new Fase A fields
        let savedURL = URL(fileURLWithPath: "/tmp/abyss-fasea-selftest.abysspaint")
        try? FileManager.default.removeItem(at: savedURL)
        store.paperColor = NSColor(srgbRed: 0.2, green: 0.3, blue: 0.4, alpha: 1)
        if let ink = store.layers.first(where: { $0.name == "Ink" }) {
            store.setLayerLocked(true, id: ink.id)
            store.setLayerAlphaLocked(true, id: ink.id)
        }
        do {
            try store.saveProject(to: savedURL)
            store.newDocument(width: 64, height: 64)
            try store.openProject(from: savedURL)
            let ink = store.layers.first(where: { $0.name == "Ink" })
            print("SELFTEST faseA project paper=\(store.paperColor.abyssHex) names=\(store.layers.map(\.name)) locked=\(ink?.isLocked ?? false) alpha=\(ink?.isAlphaLocked ?? false)")
        } catch {
            print("SELFTEST faseA project FAILED: \(error)")
        }
        try? FileManager.default.removeItem(at: savedURL)

        // Restore a neutral document for later use.
        store.newDocument(width: 400, height: 400)
    }

    static func paintDemo(_ store: DocumentStore) {
        // Red pressure ramp
        store.color = NSColor(srgbRed: 0.851, green: 0.227, blue: 0.157, alpha: 1)
        store.brushSize = 46
        store.brushHardness = 0.85
        store.brushOpacity = 1
        var previous = CGPoint(x: 160, y: 500)
        store.beginStroke(at: previous, pressure: 0.15)
        for step in 1...140 {
            let t = CGFloat(step) / 140
            let point = CGPoint(x: 160 + t * 1280, y: 500 + sin(t * .pi * 2.2) * 240)
            store.continueStroke(from: previous, to: point,
                                 fromPressure: 0.15 + t * 0.85,
                                 toPressure: 0.15 + t * 0.85)
            previous = point
        }
        store.endStroke()

        // Green ink
        store.color = NSColor(srgbRed: 0.376, green: 0.804, blue: 0.451, alpha: 1)
        store.brushSize = 18
        store.brushHardness = 1.0
        previous = CGPoint(x: 220, y: 900)
        store.beginStroke(at: previous, pressure: 0.9)
        for step in 1...90 {
            let t = CGFloat(step) / 90
            let point = CGPoint(x: 220 + t * 1100, y: 900 + sin(t * .pi * 3) * 120)
            store.continueStroke(from: previous, to: point, fromPressure: 0.9, toPressure: 0.9)
            previous = point
        }
        store.endStroke()

        // Soft airbrush
        store.color = NSColor(srgbRed: 0.20, green: 0.55, blue: 0.95, alpha: 1)
        store.brushSize = 160
        store.brushHardness = 0.02
        store.brushOpacity = 0.5
        previous = CGPoint(x: 300, y: 260)
        store.beginStroke(at: previous, pressure: 1)
        for step in 1...60 {
            let t = CGFloat(step) / 60
            let point = CGPoint(x: 300 + t * 900, y: 260 + sin(t * .pi) * 60)
            store.continueStroke(from: previous, to: point, fromPressure: 1, toPressure: 1)
            previous = point
        }
        store.endStroke()

    }
}

struct AbyssPaintCommands: Commands {
    private let store = DocumentStore.shared

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Canvas") {
                store.showsNewCanvasSheet = true
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                store.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!store.canUndo)

            Button("Redo") {
                store.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!store.canRedo)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                store.saveDocument()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Save As…") {
                store.saveDocumentAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Open…") {
                store.openDocument()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Export as PNG…") {
                store.exportPNG()
            }
            .keyboardShortcut("e", modifiers: .command)

            Menu("Export As") {
                ForEach(DocumentStore.ExportFormat.allCases) { format in
                    Button("\(format.title)…") {
                        store.export(as: format)
                    }
                }
            }

            Button("Import Image as Layer…") {
                store.importImage()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Divider()

            Button("Bigger Brush") {
                store.brushSize = min(400, store.brushSize * 1.2)
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("Smaller Brush") {
                store.brushSize = max(1, store.brushSize / 1.2)
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Toggle Eraser") {
                store.tool = store.tool == .brush ? .eraser : .brush
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Fit Canvas") {
                store.fitCanvas()
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("Reset Canvas Rotation") {
                store.resetCanvasRotation()
            }
            .keyboardShortcut("0", modifiers: [.command, .option])

            Button("Rotate Canvas Left") {
                store.rotateCanvas(by: -.pi / 12)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

            Button("Rotate Canvas Right") {
                store.rotateCanvas(by: .pi / 12)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
        }
    }
}

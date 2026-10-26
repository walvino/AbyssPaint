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
                for (index, window) in windows.enumerated() {
                    guard let view = window.contentView,
                          let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                    view.cacheDisplay(in: view.bounds, to: rep)
                    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
                    let out = index == 0 ? path : path.replacingOccurrences(of: ".png", with: "-\(index).png")
                    try? data.write(to: URL(fileURLWithPath: out))
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

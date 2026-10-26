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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let window = NSApp.windows.first { ($0.contentView?.bounds.width ?? 0) > 300 }
                if let view = window?.contentView,
                   let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    if let data = rep.representation(using: .png, properties: [:]) {
                        try? data.write(to: URL(fileURLWithPath: path))
                    }
                }
                NSApp.terminate(nil)
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
}

enum SelfTest {
    static func run() {
        let store = DocumentStore.shared

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

        // Eraser pass through the green line
        store.tool = .eraser
        store.brushSize = 60
        previous = CGPoint(x: 800, y: 1000)
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
}

struct AbyssPaintCommands: Commands {
    private let store = DocumentStore.shared

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Canvas") {
                store.newDocument()
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

        CommandGroup(after: .saveItem) {
            Button("Export as PNG…") {
                store.exportPNG()
            }
            .keyboardShortcut("e", modifiers: .command)

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
        }
    }
}

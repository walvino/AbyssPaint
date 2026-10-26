import SwiftUI
import AppKit

struct CanvasRepresentable: NSViewRepresentable {
    @ObservedObject var store: DocumentStore

    final class Coordinator {
        var lastFitRequest = 0
        var lastRotationCommand = 0
        var lastCanvasSize: CGSize = .zero
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.store = store
        return view
    }

    func updateNSView(_ nsView: CanvasNSView, context: Context) {
        nsView.store = store

        if context.coordinator.lastRotationCommand != store.rotationCommandID {
            context.coordinator.lastRotationCommand = store.rotationCommandID
            nsView.applyRotationCommand(store.rotationCommand)
        }

        if context.coordinator.lastFitRequest != store.fitRequest {
            context.coordinator.lastFitRequest = store.fitRequest
            nsView.fitToWindow()
        }

        if context.coordinator.lastCanvasSize != store.canvasSize {
            context.coordinator.lastCanvasSize = store.canvasSize
            nsView.fitToWindow()
        }

        nsView.needsDisplay = true
    }
}

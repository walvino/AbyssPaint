import SwiftUI
import MetalKit

struct CanvasView: NSViewRepresentable {
    @EnvironmentObject var canvasEngine: CanvasEngine
    @EnvironmentObject var tabletInput: TabletInput
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.sampleCount = 1
        mtkView.preferredFramesPerSecond = 120
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        
        mtkView.delegate = context.coordinator
        
        // Setup gesture recognizers
        setupGestures(mtkView, coordinator: context.coordinator)
        
        // Setup tablet/mouse tracking
        setupInputTracking(mtkView, coordinator: context.coordinator)
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.canvasEngine = canvasEngine
        context.coordinator.tabletInput = tabletInput
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func setupGestures(_ view: MTKView, coordinator: Coordinator) {
        // Pan gesture (two-finger or space+drag)
        let panGesture = NSPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.buttonMask = 0x2 // Right mouse / two-finger
        view.addGestureRecognizer(panGesture)
        
        // Zoom gesture (pinch)
        let zoomGesture = NSMagnificationGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleZoom(_:)))
        view.addGestureRecognizer(zoomGesture)
        
        // Rotation gesture
        let rotationGesture = NSRotationGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleRotation(_:)))
        view.addGestureRecognizer(rotationGesture)
        
        // Click gestures for tools
        let clickGesture = NSClickGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleClick(_:)))
        clickGesture.numberOfClicksRequired = 1
        view.addGestureRecognizer(clickGesture)
        
        // Double-click
        let doubleClickGesture = NSClickGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        view.addGestureRecognizer(doubleClickGesture)
        
        // Right-click for context menu
        let rightClickGesture = NSClickGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleRightClick(_:)))
        rightClickGesture.buttonMask = 0x2
        view.addGestureRecognizer(rightClickGesture)
    }
    
    private func setupInputTracking(_ view: MTKView, coordinator: Coordinator) {
        // Track mouse/tablet events
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: coordinator,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var canvasEngine: CanvasEngine?
        var tabletInput: TabletInput?
        var renderEngine: RenderEngine?
        var lastMouseLocation: CGPoint = .zero
        var isSpacePressed = false
        var isDrawing = false
        var lastTabletEvent: TabletEvent?
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size change
        }
        
        func draw(in view: MTKView) {
            guard let canvasEngine = canvasEngine,
                  let renderEngine = renderEngine else { return }
            
            renderEngine.render(to: view, canvasEngine: canvasEngine)
        }
        
        // MARK: - Gesture Handlers
        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let canvasEngine = canvasEngine else { return }
            
            let translation = gesture.translation(in: gesture.view)
            
            if isSpacePressed || gesture.buttonMask == 0x2 {
                // Pan canvas
                let delta = SIMD2<Float>(Float(-translation.x), Float(-translation.y)) / canvasEngine.zoom
                canvasEngine.panBy(delta)
                gesture.setTranslation(.zero, in: gesture.view)
            }
        }
        
        @objc func handleZoom(_ gesture: NSMagnificationGestureRecognizer) {
            guard let canvasEngine = canvasEngine else { return }
            
            let zoomFactor = 1.0 + gesture.magnification
            canvasEngine.setZoom(canvasEngine.zoom * Float(zoomFactor))
            gesture.magnification = 0
        }
        
        @objc func handleRotation(_ gesture: NSRotationGestureRecognizer) {
            guard let canvasEngine = canvasEngine else { return }
            
            canvasEngine.rotateBy(Float(gesture.rotation))
            gesture.rotation = 0
        }
        
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let canvasEngine = canvasEngine,
                  let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            
            switch canvasEngine.currentTool {
            case .brush, .eraser, .smudge:
                handleBrushTool(at: location, view: view)
            case .eyedropper:
                handleEyedropper(at: location, view: view)
            case .fill:
                handleFill(at: location)
            case .selection:
                handleSelectionStart(at: location)
            case .transform:
                handleTransformStart(at: location)
            default:
                break
            }
        }
        
        @objc func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
            // Reset zoom/rotation on double-click
            if let canvasEngine = canvasEngine {
                canvasEngine.resetView()
            }
        }
        
        @objc func handleRightClick(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            showContextMenu(at: location, in: view)
        }
        
        // MARK: - Tool Handlers
        private func handleBrushTool(at location: CGPoint, view: NSView) {
            guard let canvasEngine = canvasEngine,
                  let tabletInput = tabletInput else { return }
            
            // Get pressure from tablet or use mouse pressure
            let pressure = lastTabletEvent?.pressure ?? (tabletInput.currentEvent?.isMouse == true ? 1.0 : 0.5)
            let tilt = lastTabletEvent?.tilt ?? SIMD2<Float>(0, 0)
            let azimuth = lastTabletEvent?.rotation ?? 0
            
            // Start stroke
            canvasEngine.beginStroke(at: location, pressure: pressure, tilt: tilt, azimuth: azimuth)
            isDrawing = true
            
            // Track mouse drag
            NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged]) { event in
                let dragLocation = view.convert(event.locationInWindow, from: nil)
                let dragPressure = self.lastTabletEvent?.pressure ?? 1.0
                let dragTilt = self.lastTabletEvent?.tilt ?? SIMD2<Float>(0, 0)
                let dragAzimuth = self.lastTabletEvent?.rotation ?? 0
                
                canvasEngine.continueStroke(to: dragLocation, pressure: dragPressure, tilt: dragTilt, azimuth: dragAzimuth)
                return event
            }
            
            // Track mouse up
            NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { event in
                let upLocation = view.convert(event.locationInWindow, from: nil)
                let upPressure = self.lastTabletEvent?.pressure ?? 0.0
                let upTilt = self.lastTabletEvent?.tilt ?? SIMD2<Float>(0, 0)
                let upAzimuth = self.lastTabletEvent?.rotation ?? 0
                
                canvasEngine.endStroke(at: upLocation, pressure: upPressure, tilt: upTilt, azimuth: upAzimuth)
                self.isDrawing = false
                return event
            }
        }
        
        private func handleEyedropper(at location: CGPoint, view: NSView) {
            // Sample color from canvas at location
            // Would need to read pixel from render texture
        }
        
        private func handleFill(at location: CGPoint) {
            // Flood fill at location
        }
        
        private func handleSelectionStart(at location: CGPoint) {
            // Start selection
        }
        
        private func handleTransformStart(at location: CGPoint) {
            // Start transform
        }
        
        private func showContextMenu(at location: CGPoint, in view: NSView) {
            let menu = NSMenu()
            
            menu.addItem(NSMenuItem(title: "Cut", action: nil, keyEquivalent: "x"))
            menu.addItem(NSMenuItem(title: "Copy", action: nil, keyEquivalent: "c"))
            menu.addItem(NSMenuItem(title: "Paste", action: nil, keyEquivalent: "v"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Duplicate", action: nil, keyEquivalent: "j"))
            menu.addItem(NSMenuItem(title: "Delete", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Layer Options...", action: nil, keyEquivalent: ""))
            
            menu.popUp(positioning: nil, at: location, in: view)
        }
        
        // MARK: - Mouse/Tablet Tracking
        func mouseMoved(with event: NSEvent) {
            let location = event.locationInWindow
            lastMouseLocation = location
            
            // Update cursor position for brush preview
        }
        
        func mouseEntered(with event: NSEvent) {}
        
        func mouseExited(with event: NSEvent) {}
        
        // MARK: - Key Events
        func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 49: // Space
                isSpacePressed = true
            case 0: // A - Select all
                if event.modifierFlags.contains(.command) {
                    // Select all
                }
            case 2: // D - Deselect
                if event.modifierFlags.contains(.command) {
                    canvasEngine?.clearSelection()
                }
            case 8: // C - Copy
                if event.modifierFlags.contains(.command) {
                    // Copy
                }
            case 9: // V - Paste
                if event.modifierFlags.contains(.command) {
                    // Paste
                }
            case 7: // X - Cut
                if event.modifierFlags.contains(.command) {
                    // Cut
                }
            case 6: // Z - Undo
                if event.modifierFlags.contains(.command) {
                    if event.modifierFlags.contains(.shift) {
                        NotificationCenter.default.post(name: .redoRequested, object: nil)
                    } else {
                        NotificationCenter.default.post(name: .undoRequested, object: nil)
                    }
                }
            case 43: // [ - Brush size down
                canvasEngine?.brushSize = max(1, canvasEngine!.brushSize - 10)
            case 47: // ] - Brush size up
                canvasEngine?.brushSize = min(1000, canvasEngine!.brushSize + 10)
            case 27: // , - Brush opacity down
                canvasEngine?.brushOpacity = max(0, canvasEngine!.brushOpacity - 0.1)
            case 24: // . - Brush opacity up
                canvasEngine?.brushOpacity = min(1, canvasEngine!.brushOpacity + 0.1)
            case 35: // P - Toggle brush/eraser
                if let engine = canvasEngine {
                    engine.currentTool = engine.currentTool == .brush ? .eraser : .brush
                }
            default:
                break
            }
        }
        
        func keyUp(with event: NSEvent) {
            if event.keyCode == 49 { // Space
                isSpacePressed = false
            }
        }
    }
}

// MARK: - NSView Extension for Key Events
extension CanvasView.Coordinator {
    func setupKeyHandling() {
        // Would need to make the view first responder
    }
}
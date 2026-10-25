import Foundation
import IOKit
import IOKit.hid
import AppKit

// MARK: - Tablet Input Manager
class TabletManager {
    static let shared = TabletManager()
    
    private var manager: IOHIDManager?
    private var devices: [IOHIDDevice] = []
    private var deviceProperties: [IOHIDDevice: TabletDeviceInfo] = [:]
    private var eventCallback: ((TabletEvent) -> Void)?
    
    private init() {}
    
    func startMonitoring() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        // Match tablet devices (Wacom, Huion, XP-Pen, etc.)
        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Digitizer
        ]
        
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)
        
        // Set callbacks
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, sender, device in
            let manager = Unmanaged<TabletManager>.fromOpaque(context!).takeUnretainedValue()
            manager.deviceConnected(device)
        }, Unmanaged.passUnretained(self).toOpaque())
        
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, result, sender, device in
            let manager = Unmanaged<TabletManager>.fromOpaque(context!).takeUnretainedValue()
            manager.deviceDisconnected(device)
        }, Unmanaged.passUnretained(self).toOpaque())
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    func stopMonitoring() {
        if let manager = manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        }
        manager = nil
        devices.removeAll()
        deviceProperties.removeAll()
    }
    
    func setEventCallback(_ callback: @escaping (TabletEvent) -> Void) {
        self.eventCallback = callback
    }
    
    private func deviceConnected(_ device: IOHIDDevice) {
        devices.append(device)
        
        // Get device info
        let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let manufacturer = IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String ?? "Unknown"
        let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"
        
        let info = TabletDeviceInfo(
            vendorID: vendorID,
            productID: productID,
            manufacturer: manufacturer,
            product: product,
            supportsPressure: hasCapability(device, usage: 0x30), // Tip Pressure
            supportsTiltX: hasCapability(device, usage: 0x3D), // Tilt X
            supportsTiltY: hasCapability(device, usage: 0x3E), // Tilt Y
            supportsRotation: hasCapability(device, usage: 0x3F), // Rotation
            supportsEraser: hasCapability(device, usage: 0x21), // In Range / Tip Switch
            maxPressure: getMaxPressure(device)
        )
        
        deviceProperties[device] = info
        
        // Register for input reports
        IOHIDDeviceRegisterInputReportCallback(device, nil, 0, { context, result, sender, type, report, reportLength in
            let manager = Unmanaged<TabletManager>.fromOpaque(context!).takeUnretainedValue()
            manager.handleInputReport(device: sender, report: report, length: reportLength)
        }, Unmanaged.passUnretained(self).toOpaque())
        
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        
        print("Tablet connected: \(manufacturer) \(product) (VID: \(vendorID), PID: \(productID))")
    }
    
    private func deviceDisconnected(_ device: IOHIDDevice) {
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        
        devices.removeAll { $0 === device }
        deviceProperties.removeValue(forKey: device)
        
        print("Tablet disconnected")
    }
    
    private func handleInputReport(device: IOHIDDevice, report: UnsafePointer<UInt8>, length: CFIndex) {
        guard let info = deviceProperties[device] else { return }
        
        // Parse HID report
        // This is a simplified parser - real implementation would use HID report descriptors
        var event = TabletEvent()
        event.deviceID = ObjectIdentifier(device)
        event.timestamp = Date().timeIntervalSinceReferenceDate
        event.vendorID = info.vendorID
        event.productID = info.productID
        
        // Parse common tablet report format (varies by manufacturer)
        if length >= 8 {
            // Typical Wacom/Huion report format
            event.pressure = Float(report[2]) / 255.0 // Simplified
            event.x = Float(UInt16(report[4]) | (UInt16(report[5]) << 8))
            event.y = Float(UInt16(report[6]) | (UInt16(report[7]) << 8))
            
            // Normalize coordinates
            if let maxX = getMaxX(device), let maxY = getMaxY(device) {
                event.x = event.x / Float(maxX)
                event.y = event.y / Float(maxY)
            }
            
            // Check buttons
            event.buttonStates = parseButtonStates(report: report, length: length)
            
            // Check eraser
            event.isEraser = (report[1] & 0x02) != 0 // Tip switch inverted for eraser
            
            // Tilt (if supported)
            if info.supportsTiltX && length > 8 {
                event.tiltX = (Float(Int16(bitPattern: UInt16(report[8]) | (UInt16(report[9]) << 8))) / 32767.0) * 0.5 // ±0.5 rad
            }
            if info.supportsTiltY && length > 10 {
                event.tiltY = (Float(Int16(bitPattern: UInt16(report[10]) | (UInt16(report[11]) << 8))) / 32767.0) * 0.5
            }
            
            // Rotation (if supported)
            if info.supportsRotation && length > 12 {
                event.rotation = Float(UInt16(report[12]) | (UInt16(report[13]) << 8)) / 65535.0 * 2 * Float.pi
            }
        }
        
        // Normalize pressure using pressure curve
        event.pressure = Preferences.shared.pressureCurve.evaluate(event.pressure)
        
        DispatchQueue.main.async {
            self.eventCallback?(event)
        }
    }
    
    private func hasCapability(_ device: IOHIDDevice, usage: Int) -> Bool {
        // Check if device supports this usage
        // Would need to parse report descriptor
        return true // Simplified
    }
    
    private func getMaxPressure(_ device: IOHIDDevice) -> Float {
        return 1024.0 // Typical Wacom
    }
    
    private func getMaxX(_ device: IOHIDDevice) -> Int? {
        return 32767
    }
    
    private func getMaxY(_ device: IOHIDDevice) -> Int? {
        return 32767
    }
    
    private func parseButtonStates(report: UnsafePointer<UInt8>, length: CFIndex) -> [Bool] {
        // Parse button states from report
        // Simplified - would depend on device
        var states: [Bool] = []
        if length > 1 {
            let buttonByte = report[1]
            for i in 0..<8 {
                states.append((buttonByte & (1 << i)) != 0)
            }
        }
        return states
    }
    
    // Fallback: NSEvent monitoring for mouse/trackpad
    func startMouseMonitoring() {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseDown, .rightMouseDragged, .rightMouseUp, .mouseMoved]) { event in
            // Convert mouse events to tablet events
            var tabletEvent = TabletEvent()
            tabletEvent.deviceID = ObjectIdentifier("mouse" as AnyObject)
            tabletEvent.timestamp = Date().timeIntervalSinceReferenceDate
            tabletEvent.x = Float(event.locationInWindow.x)
            tabletEvent.y = Float(event.locationInWindow.y)
            tabletEvent.pressure = event.type == .leftMouseDragged ? 1.0 : 0.0
            tabletEvent.isMouse = true
            
            self.eventCallback?(tabletEvent)
        }
    }
    
    var connectedDevices: [TabletDeviceInfo] {
        return Array(deviceProperties.values)
    }
}

// MARK: - Tablet Device Info
struct TabletDeviceInfo {
    let vendorID: Int
    let productID: Int
    let manufacturer: String
    let product: String
    let supportsPressure: Bool
    let supportsTiltX: Bool
    let supportsTiltY: Bool
    let supportsRotation: Bool
    let supportsEraser: Bool
    let maxPressure: Float
    
    var displayName: String {
        return "\(manufacturer) \(product)"
    }
    
    var isWacom: Bool {
        return vendorID == 0x056A // Wacom VID
    }
    
    var isHuion: Bool {
        return vendorID == 0x256C // Huion VID
    }
    
    var isXPPen: Bool {
        return vendorID == 0x28BD // XP-Pen VID
    }
}

// MARK: - Tablet Event
struct TabletEvent {
    var deviceID: ObjectIdentifier
    var timestamp: TimeInterval
    var vendorID: Int = 0
    var productID: Int = 0
    var x: Float = 0
    var y: Float = 0
    var pressure: Float = 0
    var tiltX: Float = 0
    var tiltY: Float = 0
    var rotation: Float = 0
    var buttonStates: [Bool] = []
    var isEraser: Bool = false
    var isMouse: Bool = false
    
    var position: SIMD2<Float> {
        get { SIMD2<Float>(x, y) }
        set { x = newValue.x; y = newValue.y }
    }
    
    var tilt: SIMD2<Float> {
        get { SIMD2<Float>(tiltX, tiltY) }
        set { tiltX = newValue.x; tiltY = newValue.y }
    }
}

// MARK: - Tablet Input (High-level wrapper)
class TabletInput: ObservableObject {
    @Published var currentEvent: TabletEvent?
    @Published var connectedTablets: [TabletDeviceInfo] = []
    @Published var isTabletConnected: Bool = false
    
    private var manager = TabletManager.shared
    private var pressureCurve = PressureCurve.default
    private var buttonMappings: [Int: TabletAction] = [:]
    
    init() {
        manager.setEventCallback { [weak self] event in
            self?.handleTabletEvent(event)
        }
        manager.startMonitoring()
        manager.startMouseMonitoring()
        
        connectedTablets = manager.connectedDevices
        isTabletConnected = !connectedTablets.isEmpty
        
        // Load button mappings from preferences
        loadButtonMappings()
    }
    
    private func handleTabletEvent(_ event: TabletEvent) {
        currentEvent = event
        
        // Update connected tablets
        if connectedTablets.isEmpty != manager.connectedDevices.isEmpty {
            connectedTablets = manager.connectedDevices
            isTabletConnected = !connectedTablets.isEmpty
        }
        
        // Check button presses
        for (index, pressed) in event.buttonStates.enumerated() {
            if pressed, let action = buttonMappings[index] {
                executeAction(action)
            }
        }
    }
    
    func setPressureCurve(_ curve: PressureCurve) {
        pressureCurve = curve
    }
    
    func mapButton(_ buttonIndex: Int, to action: TabletAction) {
        buttonMappings[buttonIndex] = action
        saveButtonMappings()
    }
    
    func removeButtonMapping(_ buttonIndex: Int) {
        buttonMappings.removeValue(forKey: buttonIndex)
        saveButtonMappings()
    }
    
    private func executeAction(_ action: TabletAction) {
        switch action {
        case .undo:
            NotificationCenter.default.post(name: .undoRequested, object: nil)
        case .redo:
            NotificationCenter.default.post(name: .redoRequested, object: nil)
        case .brushSizeUp:
            NotificationCenter.default.post(name: .brushSizeUpRequested, object: nil)
        case .brushSizeDown:
            NotificationCenter.default.post(name: .brushSizeDownRequested, object: nil)
        case .brushOpacityUp:
            NotificationCenter.default.post(name: .brushOpacityUpRequested, object: nil)
        case .brushOpacityDown:
            NotificationCenter.default.post(name: .brushOpacityDownRequested, object: nil)
        case .eyedropper:
            NotificationCenter.default.post(name: .eyedropperRequested, object: nil)
        case .quickMenu:
            NotificationCenter.default.post(name: .quickMenuRequested, object: nil)
        case .toggleInterface:
            NotificationCenter.default.post(name: .toggleInterfaceRequested, object: nil)
        case .fullscreen:
            NotificationCenter.default.post(name: .fullscreenRequested, object: nil)
        case .canvasRotateLeft:
            NotificationCenter.default.post(name: .canvasRotateLeftRequested, object: nil)
        case .canvasRotateRight:
            NotificationCenter.default.post(name: .canvasRotateRightRequested, object: nil)
        case .canvasZoomIn:
            NotificationCenter.default.post(name: .zoomInRequested, object: nil)
        case .canvasZoomOut:
            NotificationCenter.default.post(name: .zoomOutRequested, object: nil)
        case .custom(let selector):
            NotificationCenter.default.post(name: NSNotification.Name(selector), object: nil)
        }
    }
    
    private func loadButtonMappings() {
        // Load from UserDefaults or Preferences
        if let data = UserDefaults.standard.data(forKey: "tabletButtonMappings"),
           let mappings = try? JSONDecoder().decode([Int: TabletAction].self, from: data) {
            buttonMappings = mappings
        } else {
            // Default mappings
            buttonMappings = [
                0: .undo,           // Button 1
                1: .redo,           // Button 2
                2: .brushSizeUp,    // Button 3
                3: .brushSizeDown,  // Button 4
                4: .eyedropper,     // Button 5
                5: .quickMenu       // Button 6
            ]
        }
    }
    
    private func saveButtonMappings() {
        if let data = try? JSONEncoder().encode(buttonMappings) {
            UserDefaults.standard.set(data, forKey: "tabletButtonMappings")
        }
    }
}

// MARK: - Tablet Actions
enum TabletAction: Codable {
    case undo
    case redo
    case brushSizeUp
    case brushSizeDown
    case brushOpacityUp
    case brushOpacityDown
    case eyedropper
    case quickMenu
    case toggleInterface
    case fullscreen
    case canvasRotateLeft
    case canvasRotateRight
    case canvasZoomIn
    case canvasZoomOut
    case custom(String)
}

// MARK: - Pressure Curve (duplicate from Stroke.swift for accessibility)
struct PressureCurve: Codable {
    var points: [SIMD2<Float>]
    var smoothing: Float
    var motionFiltering: Float
    
    static let `default` = PressureCurve(
        points: [
            SIMD2<Float>(0, 0),
            SIMD2<Float>(0.33, 0.33),
            SIMD2<Float>(0.66, 0.66),
            SIMD2<Float>(1, 1)
        ],
        smoothing: 0.5,
        motionFiltering: 0.0
    )
    
    func evaluate(_ pressure: Float) -> Float {
        let t = clamp(pressure, 0, 1)
        let u = 1 - t
        let uu = u * u
        let uuu = uu * u
        let tt = t * t
        let ttt = tt * t
        
        let p0 = points[0]
        let p1 = points[1]
        let p2 = points[2]
        let p3 = points[3]
        
        let y = uuu * p0.y +
                3 * uu * t * p1.y +
                3 * u * tt * p2.y +
                ttt * p3.y
        
        return clamp(y, 0, 1)
    }
    
    private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let undoRequested = Notification.Name("undoRequested")
    static let redoRequested = Notification.Name("redoRequested")
    static let brushSizeUpRequested = Notification.Name("brushSizeUpRequested")
    static let brushSizeDownRequested = Notification.Name("brushSizeDownRequested")
    static let brushOpacityUpRequested = Notification.Name("brushOpacityUpRequested")
    static let brushOpacityDownRequested = Notification.Name("brushOpacityDownRequested")
    static let eyedropperRequested = Notification.Name("eyedropperRequested")
    static let quickMenuRequested = Notification.Name("quickMenuRequested")
    static let toggleInterfaceRequested = Notification.Name("toggleInterfaceRequested")
    static let fullscreenRequested = Notification.Name("fullscreenRequested")
    static let canvasRotateLeftRequested = Notification.Name("canvasRotateLeftRequested")
    static let canvasRotateRightRequested = Notification.Name("canvasRotateRightRequested")
}
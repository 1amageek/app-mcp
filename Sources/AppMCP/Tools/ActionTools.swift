import Foundation
import AppKit
import ApplicationServices

public class ActionTools {
    private let registry: AppRegistry
    private let coordinateConverter: CoordinateConverter
    
    public init(registry: AppRegistry, coordinateConverter: CoordinateConverter) {
        self.registry = registry
        self.coordinateConverter = coordinateConverter
    }
    
    // MARK: - Data Structures
    
    public struct MouseClickParameters: Codable {
        let windowHandle: String
        let x: Double
        let y: Double
        let coordinateSpace: String?
        let button: String?
        let clickCount: Int?
        let screenId: Int?
    }
    
    public struct TypeTextParameters: Codable {
        let windowHandle: String
        let text: String
    }
    
    public struct PerformGestureParameters: Codable {
        let windowHandle: String
        let gestureType: String
        let direction: String?
        let scale: Double?
        let angleDeg: Double?
        let distancePx: Int?
        let durationMs: Int?
        let fingers: Int?
    }
    
    public struct ActionResult: Codable {
        let success: Bool
        let message: String
        
        init(success: Bool, message: String) {
            self.success = success
            self.message = message
        }
    }
    
    public enum MouseButton: String, CaseIterable {
        case left = "left"
        case right = "right"
        case center = "center"
        
        var cgMouseButton: CGMouseButton {
            switch self {
            case .left: return .left
            case .right: return .right
            case .center: return .center
            }
        }
        
        var downEventType: CGEventType {
            switch self {
            case .left: return .leftMouseDown
            case .right: return .rightMouseDown
            case .center: return .otherMouseDown
            }
        }
        
        var upEventType: CGEventType {
            switch self {
            case .left: return .leftMouseUp
            case .right: return .rightMouseUp
            case .center: return .otherMouseUp
            }
        }
    }
    
    public enum CoordinateSpace: String, CaseIterable {
        case window = "window"
        case global = "global"
        case screen = "screen"
    }
    
    public enum GestureType: String, CaseIterable {
        case swipe = "swipe"
        case pinch = "pinch"
        case rotate = "rotate"
        case smartMagnify = "smart_magnify"
    }
    
    public enum SwipeDirection: String, CaseIterable {
        case left = "left"
        case right = "right"
        case up = "up"
        case down = "down"
    }
    
    // MARK: - Tool Implementations
    
    public func mouseClick(arguments: [String: Any]) async throws -> ActionResult {
        // Parse arguments
        guard let windowHandle = arguments["window_handle"] as? String,
              let x = arguments["x"] as? Double,
              let y = arguments["y"] as? Double else {
            throw MCPError.invalidParameters("window_handle, x, and y are required")
        }
        
        let coordinateSpaceStr = arguments["coordinate_space"] as? String ?? "window"
        let buttonStr = arguments["button"] as? String ?? "left"
        let clickCount = arguments["click_count"] as? Int ?? 1
        let screenId = arguments["screen_id"] as? Int
        
        // Validate parameters
        guard let coordinateSpace = CoordinateSpace(rawValue: coordinateSpaceStr) else {
            throw MCPError.invalidParameters("Invalid coordinate_space: \(coordinateSpaceStr)")
        }
        
        guard let button = MouseButton(rawValue: buttonStr) else {
            throw MCPError.invalidParameters("Invalid button: \(buttonStr)")
        }
        
        guard clickCount >= 1 && clickCount <= 10 else {
            throw MCPError.invalidParameters("click_count must be between 1 and 10")
        }
        
        // Get window data
        let windowData = try await registry.getWindow(handle: windowHandle)
        
        // Convert coordinates to global
        let space: CoordinateConverter.CoordinateSpace
        switch coordinateSpace {
        case .window:
            space = .window
        case .global:
            space = .global
        case .screen:
            guard let screenId = screenId else {
                throw MCPError.invalidParameters("screen_id required for screen coordinate space")
            }
            space = .screen(displayId: CGDirectDisplayID(screenId))
        }
        
        let globalPoint = try await coordinateConverter.toGlobal(
            x: x,
            y: y,
            from: space,
            window: windowData.axWindow,
            screenId: screenId.map { CGDirectDisplayID($0) }
        )
        
        // Perform click
        try performClick(at: globalPoint, button: button, clickCount: clickCount)
        
        return ActionResult(
            success: true,
            message: "Clicked at (\(globalPoint.x), \(globalPoint.y)) with \(button.rawValue) button \(clickCount) times"
        )
    }
    
    public func typeText(arguments: [String: Any]) async throws -> ActionResult {
        // Parse arguments
        guard let windowHandle = arguments["window_handle"] as? String,
              let text = arguments["text"] as? String else {
            throw MCPError.invalidParameters("window_handle and text are required")
        }
        
        guard !text.isEmpty else {
            throw MCPError.invalidParameters("text cannot be empty")
        }
        
        // Get window data to verify it exists
        _ = try await registry.getWindow(handle: windowHandle)
        
        // Type the text
        try performTextInput(text: text)
        
        return ActionResult(
            success: true,
            message: "Typed text: \(text.prefix(50))\(text.count > 50 ? "..." : "")"
        )
    }
    
    public func performGesture(arguments: [String: Any]) async throws -> ActionResult {
        // Parse arguments
        guard let windowHandle = arguments["window_handle"] as? String,
              let gestureTypeStr = arguments["gesture_type"] as? String else {
            throw MCPError.invalidParameters("window_handle and gesture_type are required")
        }
        
        guard let gestureType = GestureType(rawValue: gestureTypeStr) else {
            throw MCPError.invalidParameters("Invalid gesture_type: \(gestureTypeStr)")
        }
        
        let directionStr = arguments["direction"] as? String
        let scale = arguments["scale"] as? Double
        let angleDeg = arguments["angle_deg"] as? Double
        let distancePx = arguments["distance_px"] as? Int
        let durationMs = arguments["duration_ms"] as? Int ?? 150
        let fingers = arguments["fingers"] as? Int ?? 2
        
        // Get window data
        let windowData = try await registry.getWindow(handle: windowHandle)
        
        // Get window center for gesture
        let windowFrame = try await coordinateConverter.getWindowFrame(from: windowData.axWindow)
        let centerPoint = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        
        // Perform gesture based on type
        let message: String
        switch gestureType {
        case .swipe:
            guard let directionStr = directionStr,
                  let direction = SwipeDirection(rawValue: directionStr) else {
                throw MCPError.invalidParameters("direction is required for swipe gesture")
            }
            
            let distance = distancePx ?? 100
            try await performSwipe(
                at: centerPoint,
                direction: direction,
                distance: distance,
                duration: durationMs,
                fingers: fingers
            )
            message = "Performed \(direction.rawValue) swipe with \(fingers) fingers"
            
        case .pinch:
            let pinchScale = scale ?? 1.0
            try await performPinch(
                at: centerPoint,
                scale: pinchScale,
                duration: durationMs
            )
            message = "Performed pinch gesture with scale \(pinchScale)"
            
        case .rotate:
            let angle = angleDeg ?? 0.0
            try await performRotate(
                at: centerPoint,
                angle: angle,
                duration: durationMs
            )
            message = "Performed rotate gesture with angle \(angle)°"
            
        case .smartMagnify:
            try await performSmartMagnify(at: centerPoint)
            message = "Performed smart magnify gesture"
        }
        
        return ActionResult(
            success: true,
            message: message
        )
    }
    
    // MARK: - Private Implementation Methods
    
    private func performClick(at point: CGPoint, button: MouseButton, clickCount: Int) throws {
        for i in 0..<clickCount {
            // Mouse down
            guard let downEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: button.downEventType,
                mouseCursorPosition: point,
                mouseButton: button.cgMouseButton
            ) else {
                throw MCPError.internalError("Failed to create mouse down event")
            }
            
            if clickCount > 1 {
                downEvent.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
            }
            
            downEvent.post(tap: .cghidEventTap)
            
            // Small delay between down and up
            Thread.sleep(forTimeInterval: 0.05)
            
            // Mouse up
            guard let upEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: button.upEventType,
                mouseCursorPosition: point,
                mouseButton: button.cgMouseButton
            ) else {
                throw MCPError.internalError("Failed to create mouse up event")
            }
            
            if clickCount > 1 {
                upEvent.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
            }
            
            upEvent.post(tap: .cghidEventTap)
            
            // Delay between clicks for multi-click
            if i < clickCount - 1 {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    private func performTextInput(text: String) throws {
        for character in text {
            let string = String(character)
            
            // Handle special characters
            if character == "\n" {
                // Return key
                let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x24, keyDown: true)
                let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x24, keyDown: false)
                
                keyDownEvent?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.01)
                keyUpEvent?.post(tap: .cghidEventTap)
                
            } else if character == "\t" {
                // Tab key
                let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x30, keyDown: true)
                let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x30, keyDown: false)
                
                keyDownEvent?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.01)
                keyUpEvent?.post(tap: .cghidEventTap)
                
            } else {
                // Regular character
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
                    throw MCPError.internalError("Failed to create keyboard event")
                }
                
                event.keyboardSetUnicodeString(stringLength: string.count, unicodeString: Array(string.utf16))
                event.post(tap: .cghidEventTap)
            }
            
            // Small delay between characters
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
    
    private func performSwipe(
        at point: CGPoint,
        direction: SwipeDirection,
        distance: Int,
        duration: Int,
        fingers: Int
    ) async throws {
        // For swipe gestures, we simulate mouse drag
        let startPoint = point
        let endPoint: CGPoint
        
        switch direction {
        case .left:
            endPoint = CGPoint(x: startPoint.x - Double(distance), y: startPoint.y)
        case .right:
            endPoint = CGPoint(x: startPoint.x + Double(distance), y: startPoint.y)
        case .up:
            endPoint = CGPoint(x: startPoint.x, y: startPoint.y - Double(distance))
        case .down:
            endPoint = CGPoint(x: startPoint.x, y: startPoint.y + Double(distance))
        }
        
        try performDrag(from: startPoint, to: endPoint, duration: duration)
    }
    
    private func performPinch(at point: CGPoint, scale: Double, duration: Int) async throws {
        // Pinch is complex to simulate with CGEvents
        // For now, we'll simulate it as a scroll event
        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(scale > 1.0 ? 10 : -10),
            wheel2: 0,
            wheel3: 0
        ) else {
            throw MCPError.internalError("Failed to create scroll event for pinch")
        }
        
        scrollEvent.location = point
        scrollEvent.post(tap: .cghidEventTap)
    }
    
    private func performRotate(at point: CGPoint, angle: Double, duration: Int) async throws {
        // Rotation is complex to simulate directly
        // This is a simplified implementation
        let radians = angle * .pi / 180.0
        let radius = 50.0
        
        let startPoint = CGPoint(
            x: point.x + radius * cos(0),
            y: point.y + radius * sin(0)
        )
        let endPoint = CGPoint(
            x: point.x + radius * cos(radians),
            y: point.y + radius * sin(radians)
        )
        
        try performDrag(from: startPoint, to: endPoint, duration: duration)
    }
    
    private func performSmartMagnify(at point: CGPoint) async throws {
        // Smart magnify is typically a double-tap with two fingers
        // Simulate as a double-click for now
        try performClick(at: point, button: .left, clickCount: 2)
    }
    
    private func performDrag(from startPoint: CGPoint, to endPoint: CGPoint, duration: Int) throws {
        // Mouse down at start point
        guard let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: startPoint,
            mouseButton: .left
        ) else {
            throw MCPError.internalError("Failed to create mouse down event")
        }
        downEvent.post(tap: .cghidEventTap)
        
        // Calculate steps for smooth drag
        let steps = max(10, duration / 10) // At least 10 steps
        let stepDuration = Double(duration) / Double(steps) / 1000.0 // Convert to seconds
        
        for i in 1...steps {
            let progress = Double(i) / Double(steps)
            let currentPoint = CGPoint(
                x: startPoint.x + (endPoint.x - startPoint.x) * progress,
                y: startPoint.y + (endPoint.y - startPoint.y) * progress
            )
            
            guard let dragEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: currentPoint,
                mouseButton: .left
            ) else {
                throw MCPError.internalError("Failed to create mouse drag event")
            }
            
            dragEvent.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: stepDuration)
        }
        
        // Mouse up at end point
        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: endPoint,
            mouseButton: .left
        ) else {
            throw MCPError.internalError("Failed to create mouse up event")
        }
        upEvent.post(tap: .cghidEventTap)
    }
}
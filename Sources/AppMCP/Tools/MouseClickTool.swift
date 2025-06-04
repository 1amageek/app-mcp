import Foundation
import MCP
@preconcurrency import ApplicationServices
import AppKit

/// Tool executor that performs mouse click operations in specified applications
public final class MouseClickTool: MCPToolExecutor, @unchecked Sendable {
    
    public let name = "mouse_click"
    private let appSelector: AppSelector
    private let tccManager: TCCManager
    
    public init(appSelector: AppSelector, tccManager: TCCManager) {
        self.appSelector = appSelector
        self.tccManager = tccManager
    }
    
    public func handle(params: MCP.Value) async throws -> MCP.Value {
        // Ensure accessibility permission
        try await tccManager.ensureAccessibilityPermission()
        
        // Parse parameters from Value
        guard case let .object(paramsDict) = params else {
            throw MCPError.invalidParameters("Parameters must be an object")
        }
        
        let x: Double
        let y: Double
        
        if case let .double(xValue) = paramsDict["x"] {
            x = xValue
        } else if case let .int(xValue) = paramsDict["x"] {
            x = Double(xValue)
        } else {
            throw MCPError.invalidParameters("Missing x coordinate")
        }
        
        if case let .double(yValue) = paramsDict["y"] {
            y = yValue
        } else if case let .int(yValue) = paramsDict["y"] {
            y = Double(yValue)
        } else {
            throw MCPError.invalidParameters("Missing y coordinate")
        }
        
        let button = (paramsDict["button"].flatMap { if case let .string(b) = $0 { return b } else { return nil } }) ?? "left"
        let clickCount = (paramsDict["click_count"].flatMap { if case let .int(c) = $0 { return c } else { return nil } }) ?? 1
        
        // Validate button type
        let mouseButton: CGMouseButton
        switch button.lowercased() {
        case "left":
            mouseButton = .left
        case "right":
            mouseButton = .right
        case "center", "middle":
            mouseButton = .center
        default:
            throw MCPError.invalidParameters("Invalid button type. Use 'left', 'right', or 'center'")
        }
        
        // If target app is specified, bring it to front first
        if case let .object(targetApp) = paramsDict["target_app"] {
            try await bringAppToFront(targetApp: targetApp)
        }
        
        // Perform the click
        try performMouseClick(at: CGPoint(x: x, y: y), button: mouseButton, clickCount: clickCount)
        
        return .object([
            "success": .bool(true),
            "action": .string("mouse_click"),
            "coordinates": .object([
                "x": .double(x),
                "y": .double(y)
            ]),
            "button": .string(button),
            "click_count": .int(clickCount)
        ])
    }
    
    private func bringAppToFront(targetApp: [String: MCP.Value]) async throws {
        if case let .string(bundleId) = targetApp["bundle_id"] {
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) {
                app.activate()
                // Wait a bit for the app to come to front
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        } else if case let .string(processName) = targetApp["process_name"] {
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.localizedName == processName }) {
                app.activate()
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    private func performMouseClick(at point: CGPoint, button: CGMouseButton, clickCount: Int) throws {
        // Create mouse down event
        let mouseDownEventType: CGEventType
        let mouseUpEventType: CGEventType
        
        switch button {
        case .left:
            mouseDownEventType = .leftMouseDown
            mouseUpEventType = .leftMouseUp
        case .right:
            mouseDownEventType = .rightMouseDown
            mouseUpEventType = .rightMouseUp
        case .center:
            mouseDownEventType = .otherMouseDown
            mouseUpEventType = .otherMouseUp
        @unknown default:
            throw MCPError.invalidParameters("Unsupported mouse button")
        }
        
        for _ in 0..<clickCount {
            // Create mouse down event
            guard let mouseDownEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: mouseDownEventType,
                mouseCursorPosition: point,
                mouseButton: button
            ) else {
                throw MCPError.systemError("Failed to create mouse down event")
            }
            
            // Create mouse up event
            guard let mouseUpEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: mouseUpEventType,
                mouseCursorPosition: point,
                mouseButton: button
            ) else {
                throw MCPError.systemError("Failed to create mouse up event")
            }
            
            // Post the events
            mouseDownEvent.post(tap: .cghidEventTap)
            mouseUpEvent.post(tap: .cghidEventTap)
            
            // Small delay between clicks for multiple clicks
            if clickCount > 1 {
                usleep(100_000) // 0.1 seconds
            }
        }
    }
}

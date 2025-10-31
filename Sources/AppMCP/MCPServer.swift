import Foundation
import MCP
import AppPilot
import AppKit
import AXUI

// Note: Both AppPilot and AXUI define Role types
// We need to be explicit about which Role to use in each context

// MARK: - AppPilot Compatibility Notes
// AppPilot v3.0+ removed the UIElement.id property
// Use element.identifier for accessibility identifiers
// Use getElementDescription() for user-friendly element descriptions

/// Modern MCP Server for macOS UI automation powered by AppPilot
public final class AppMCPServer: @unchecked Sendable {

    private let server: MCP.Server
    private let pilot: AppPilot

    // Performance metrics tracker (using Actor for concurrency safety)
    private actor MetricsTracker {
        private var totalToolCalls: Int = 0
        private var totalExecutionTime: TimeInterval = 0

        func recordToolCall(duration: TimeInterval) {
            totalToolCalls += 1
            totalExecutionTime += duration
        }

        func getMetrics() -> (calls: Int, time: TimeInterval) {
            (totalToolCalls, totalExecutionTime)
        }
    }

    private let metricsTracker = MetricsTracker()

    // MARK: - Constants

    private enum Constants {
        static let maxWaitDuration: TimeInterval = 60.0  // Maximum wait time in seconds
        static let defaultKeyDelay: TimeInterval = 0.05  // 50ms between keystrokes
        static let focusDelay: TimeInterval = 0.05  // 50ms after focusing element
        static let keyPressDuration: TimeInterval = 0.01  // 10ms key hold
        static let maxSnapshotDimension: Int = 240  // Max image dimension for MCP
        static let snapshotJPEGQuality: CGFloat = 0.2  // 20% JPEG compression
        static let maxResponseSize: Int = 50_000  // 50KB max response size
    }

    public init() {
        // Initialize AppPilot with default drivers
        self.pilot = AppPilot()

        // Initialize server
        self.server = MCP.Server(
            name: "AppMCP",
            version: AppMCP.version,
            capabilities: .init(
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            )
        )

        Task { await setupHandlers() }
    }

    /// Clean up resources on deinitialization
    deinit {
        // NOTE: Cannot access actor from deinit (synchronous context)
        // Metrics can be retrieved via Resource during runtime if needed
        print("📊 AppMCP server shutting down")
    }

    /// Check if required AppPilot capabilities are available
    private func validateAppPilotCapabilities() async throws {
        // Verify we can list applications (basic capability check)
        do {
            _ = try await pilot.listApplications()
        } catch {
            throw AppMCPError.systemError("AppPilot initialization failed. Ensure accessibility permissions are granted: \(error.localizedDescription)")
        }
    }


    private func setupHandlers() async {
        await setupToolHandlers()
        await setupResourceHandlers()
    }

    // MARK: - Tool Handlers
    
    private func setupToolHandlers() async {
        await server.withMethodHandler(ListTools.self) { _ in
            // IMPORTANT: MCP Tools are for ACTIONS (state changes), not data queries
            // Read-only operations should be Resources, not Tools

            let tools: [MCP.Tool] = [
                // UI Action Tools (state-mutating operations)
                MCP.Tool(
                    name: "click_element",
                    description: "Click UI elements using element IDs from appmcp://ui/snapshot/{bundleID} resource",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "elementId": [
                                "type": "string",
                                "description": "Element ID from UI snapshot resource"
                            ],
                            "button": [
                                "type": "string",
                                "enum": ["left", "right", "center"],
                                "description": "Mouse button (default: left)"
                            ],
                            "count": [
                                "type": "number",
                                "description": "Click count (default: 1)"
                            ]
                        ],
                        "required": ["elementId"]
                    ]
                ),
                
                MCP.Tool(
                    name: "input_text",
                    description: "Input text into elements using element IDs from appmcp://ui/snapshot/{bundleID} resource",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "elementId": [
                                "type": "string",
                                "description": "Element ID from UI snapshot resource"
                            ],
                            "text": [
                                "type": "string",
                                "description": "Text to input"
                            ],
                            "method": [
                                "type": "string",
                                "enum": ["type", "setValue"],
                                "description": "Input method - 'setValue': directly sets the value (fast, reliable) | 'type': simulates actual keystrokes (triggers input events, works with auto-complete) (default: setValue)"
                            ]
                        ],
                        "required": ["elementId", "text"]
                    ]
                ),
                
                MCP.Tool(
                    name: "drag_drop",
                    description: "Perform drag and drop operations using element IDs from appmcp://ui/snapshot/{bundleID} resource",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "fromElementId": [
                                "type": "string",
                                "description": "Source element ID"
                            ],
                            "toElementId": [
                                "type": "string",
                                "description": "Target element ID"
                            ],
                            "duration": [
                                "type": "number",
                                "description": "Duration in seconds (default: 1.0)"
                            ]
                        ],
                        "required": ["fromElementId", "toElementId"]
                    ]
                ),
                
                MCP.Tool(
                    name: "scroll_window",
                    description: "Scroll at element location using element ID from appmcp://ui/snapshot/{bundleID} resource",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "elementId": [
                                "type": "string",
                                "description": "Element ID for scroll location"
                            ],
                            "deltaX": [
                                "type": "number",
                                "description": "Horizontal scroll amount (default: 0)"
                            ],
                            "deltaY": [
                                "type": "number",
                                "description": "Vertical scroll amount"
                            ]
                        ],
                        "required": ["elementId", "deltaY"]
                    ]
                ),
                
                MCP.Tool(
                    name: "keyboard_input",
                    description: "Send keyboard input including shortcuts (Cmd+C), special keys (Enter, Tab), and key combinations",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "elementId": [
                                "type": "string",
                                "description": "Element ID to focus before sending keys (optional)"
                            ],
                            "keys": [
                                "type": "array",
                                "description": "Array of key inputs to send",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "key": [
                                            "type": "string",
                                            "description": "Key to press (e.g., 'c', 'enter', 'tab', 'escape')"
                                        ],
                                        "modifiers": [
                                            "type": "array",
                                            "items": [
                                                "type": "string",
                                                "enum": ["cmd", "shift", "alt", "ctrl", "option"]
                                            ],
                                            "description": "Modifier keys to hold (optional)"
                                        ]
                                    ],
                                    "required": ["key"]
                                ]
                            ],
                            "delay": [
                                "type": "number",
                                "description": "Delay between key inputs in milliseconds (default: 50)"
                            ]
                        ],
                        "required": ["keys"]
                    ]
                ),

                // Synchronization Tool
                MCP.Tool(
                    name: "wait_time",
                    description: "Wait for a specified duration (useful after network operations, UI animations, or async operations)",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "duration": [
                                "type": "number",
                                "description": "Duration to wait in seconds"
                            ]
                        ],
                        "required": ["duration"]
                    ]
                )
            ]

            // NOTE: Read-only operations (listing apps, capturing UI)
            // have been moved to Resources for proper MCP semantic separation.
            // Use ReadResource with URIs like:
            // - appmcp://resources/running_applications
            // - appmcp://ui/snapshot/{bundleID}

            return ListTools.Result(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            let arguments = params.arguments ?? [:]

            switch params.name {
            case "click_element":
                return await self.handleClickElement(arguments)
            case "input_text":
                return await self.handleInputText(arguments)
            case "drag_drop":
                return await self.handleDragDrop(arguments)
            case "scroll_window":
                return await self.handleScrollWindow(arguments)
            case "keyboard_input":
                return await self.handleKeyboardInput(arguments)
            case "wait_time":
                return await self.handleWaitTime(arguments)
            default:
                return CallTool.Result(
                    content: [.text("""
                    Unknown tool: \(params.name)

                    Available tools (UI actions only):
                    - click_element
                    - input_text
                    - drag_drop
                    - scroll_window
                    - keyboard_input
                    - wait_time

                    For read-only operations, use Resources:
                    - appmcp://resources/running_applications
                    - appmcp://ui/snapshot/{bundleID}
                    (See ListResources for complete list)
                    """)],
                    isError: true
                )
            }
        }
    }

    // MARK: - Tool Handler Methods

    internal func handleClickElement(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        let startTime = Date()

        do {
            let result = try await performClick(arguments)
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return CallTool.Result(content: [.text(result)])
        } catch {
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return handleToolError(error, toolName: "click_element")
        }
    }
    
    internal func handleInputText(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        let startTime = Date()

        do {
            let result = try await performSetText(arguments)
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return CallTool.Result(content: [.text(result)])
        } catch {
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return handleToolError(error, toolName: "input_text")
        }
    }
    
    internal func handleDragDrop(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        let startTime = Date()

        do {
            let result = try await performDrag(arguments)
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return CallTool.Result(content: [.text(result)])
        } catch {
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return handleToolError(error, toolName: "drag_drop")
        }
    }
    
    internal func handleScrollWindow(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        let startTime = Date()

        do {
            let result = try await performScroll(arguments)
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return CallTool.Result(content: [.text(result)])
        } catch {
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return handleToolError(error, toolName: "scroll_window")
        }
    }
    
    internal func handleKeyboardInput(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        let startTime = Date()

        do {
            let result = try await performKeyboardInput(arguments)
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return CallTool.Result(content: [.text(result)])
        } catch {
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return handleToolError(error, toolName: "keyboard_input")
        }
    }
    
    internal func handleWaitTime(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        let startTime = Date()

        do {
            let result = try await performWaitTime(arguments)
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return CallTool.Result(content: [.text(result)])
        } catch {
            await metricsTracker.recordToolCall(duration: Date().timeIntervalSince(startTime))
            return handleToolError(error, toolName: "wait_time")
        }
    }

    // NOTE: Handlers for read-only operations have been removed.
    // These operations are now available as Resources via ReadResource:
    // - UI capture: appmcp://ui/snapshot/{bundleID}
    // - Elements: appmcp://ui/elements/{bundleID}
    // - App list: appmcp://resources/running_applications
    // - Windows: appmcp://resources/application_windows

    // MARK: - Action Implementations
    
    private func performClick(_ arguments: [String: MCP.Value]) async throws -> String {
        do {
            let elementId = try extractRequiredString(from: arguments, key: "elementId")
            let buttonType = extractOptionalString(from: arguments, key: "button") ?? "left"
            let count = extractOptionalDouble(from: arguments, key: "count").map { Int($0) } ?? 1

            // Convert button type to MouseButton
            let mouseButton: MouseButton = {
                switch buttonType {
                case "right": return .right
                case "center": return .center
                default: return .left
                }
            }()

            // Use AppPilot's element ID method
            let result = try await pilot.click(elementID: elementId)

            // For non-default button/count, use coordinate-based clicking
            if buttonType != "left" || count != 1 {
                guard let element = result.element else {
                    throw AppMCPError.systemError("Failed to get element info for advanced click")
                }

                // Use coordinate-based click with specified button and count
                _ = try await pilot.click(at: element.centerPoint, button: mouseButton, count: count)

                let buttonDesc = buttonType == "left" ? "" : " (\(buttonType) button)"
                let countDesc = count == 1 ? "" : " \(count) times"

                return "Clicked\(buttonDesc) element ID '\(elementId)'\(countDesc) at (\(element.centerPoint.x), \(element.centerPoint.y))"
            }

            return "Clicked element ID '\(elementId)'"
        } catch {
            // Convert AppPilot errors to AppMCP errors
            throw convertPilotError(error)
        }
    }
    
    private func extractRequiredDouble(from arguments: [String: MCP.Value], key: String) throws -> Double {
        guard let value = arguments[key] else {
            throw AppMCPError.missingParameter(key)
        }

        switch value {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        default:
            throw AppMCPError.invalidParameterType(key, expected: "number", got: "\(value)")
        }
    }

    private func extractRequiredInt(from arguments: [String: MCP.Value], key: String) throws -> Int {
        guard let value = arguments[key] else {
            throw AppMCPError.missingParameter(key)
        }

        switch value {
        case .int(let i):
            return i
        case .double(let d):
            guard d.rounded() == d else {
                throw AppMCPError.invalidParameterType(key, expected: "integer", got: "decimal \(d)")
            }
            guard d >= Double(Int.min) && d <= Double(Int.max) else {
                throw AppMCPError.invalidParameters("Integer overflow for parameter '\(key)': \(d)")
            }
            return Int(d)
        default:
            throw AppMCPError.invalidParameterType(key, expected: "integer", got: "\(value)")
        }
    }

    private func extractOptionalInt(from arguments: [String: MCP.Value], key: String) -> Int? {
        guard let value = arguments[key] else { return nil }

        switch value {
        case .int(let i):
            return i
        case .double(let d):
            // Validate range to prevent overflow and ensure it's a whole number
            guard d >= Double(Int.min) && d <= Double(Int.max),
                  d.rounded() == d else {
                return nil
            }
            return Int(d)
        default:
            return nil
        }
    }

    private func performSetText(_ arguments: [String: MCP.Value]) async throws -> String {
        do {
            let elementId = try extractRequiredString(from: arguments, key: "elementId")
            let text = try extractRequiredString(from: arguments, key: "text")
            let method = extractOptionalString(from: arguments, key: "method") ?? "setValue"

            if method == "setValue" {
                // Use AppPilot's direct setValue method (efficient)
                _ = try await pilot.setValue(text, for: elementId)
                return "Set text '\(text)' in element ID '\(elementId)' using setValue method"
            } else {
                // Use AppPilot's input method (keyboard simulation)
                _ = try await pilot.input(text: text, into: elementId)
                return "Typed text '\(text)' into element ID '\(elementId)'"
            }
        } catch {
            // Convert AppPilot errors to AppMCP errors
            throw convertPilotError(error)
        }
    }
    
    
    
    
    private func performDrag(_ arguments: [String: MCP.Value]) async throws -> String {
        do {
            let fromElementId = try extractRequiredString(from: arguments, key: "fromElementId")
            let toElementId = try extractRequiredString(from: arguments, key: "toElementId")
            let duration = extractOptionalDouble(from: arguments, key: "duration") ?? 1.0

            // TODO: SIDE EFFECT - Currently clicks elements just to get their coordinates.
            // This causes unwanted click actions before the drag operation.
            // AppPilot should provide a coordinate inspection API (e.g., getElementBounds/getElementCenter)
            // to retrieve element positions without triggering click events.
            let fromResult = try await pilot.click(elementID: fromElementId)
            let toResult = try await pilot.click(elementID: toElementId)

            guard let fromElement = fromResult.element, let toElement = toResult.element else {
                throw AppMCPError.systemError("Failed to get element coordinates for drag operation")
            }

            let fromPoint = fromElement.centerPoint
            let toPoint = toElement.centerPoint

            // Perform drag operation using AppPilot
            _ = try await pilot.drag(from: fromPoint, to: toPoint, duration: duration)

            return "Dragged from element '\(fromElementId)' at (\(fromPoint.x), \(fromPoint.y)) to element '\(toElementId)' at (\(toPoint.x), \(toPoint.y)) over \(duration) seconds"
        } catch {
            // Convert AppPilot errors to AppMCP errors
            throw convertPilotError(error)
        }
    }
    
    private func performScroll(_ arguments: [String: MCP.Value]) async throws -> String {
        do {
            let elementId = try extractRequiredString(from: arguments, key: "elementId")
            let deltaX = extractOptionalDouble(from: arguments, key: "deltaX") ?? 0
            let deltaY = try extractRequiredDouble(from: arguments, key: "deltaY")

            // TODO: SIDE EFFECT - Currently clicks the element just to get its coordinates.
            // This causes an unwanted click action before the scroll operation.
            // AppPilot should provide a coordinate inspection API (e.g., getElementBounds/getElementCenter)
            // to retrieve element position without triggering click events.
            let result = try await pilot.click(elementID: elementId)

            guard let element = result.element else {
                throw AppMCPError.systemError("Failed to get element coordinates for scroll operation")
            }

            let scrollPoint = element.centerPoint

            // Perform scroll operation using AppPilot
            _ = try await pilot.scroll(deltaX: deltaX, deltaY: deltaY, at: scrollPoint)

            return "Scrolled at element '\(elementId)' location (\(scrollPoint.x), \(scrollPoint.y)) with delta (\(deltaX), \(deltaY))"
        } catch {
            // Convert AppPilot errors to AppMCP errors
            throw convertPilotError(error)
        }
    }
    
    private func performWaitTime(_ arguments: [String: MCP.Value]) async throws -> String {
        let duration = try extractRequiredDouble(from: arguments, key: "duration")

        guard duration.isFinite && duration > 0 && duration <= Constants.maxWaitDuration else {
            throw AppMCPError.invalidParameters("Duration must be a positive number up to \(Constants.maxWaitDuration) seconds, got: \(duration)")
        }

        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        return "Waited for \(duration) seconds"
    }

    private func performKeyboardInput(_ arguments: [String: MCP.Value]) async throws -> String {
        do {
            let keys = try extractRequiredArray(from: arguments, key: "keys")
            let elementId = extractOptionalString(from: arguments, key: "elementId")
            let delay = extractOptionalDouble(from: arguments, key: "delay") ?? (Constants.defaultKeyDelay * 1000)  // Convert to ms

            // Focus element if specified
            if let elementId = elementId {
                // Check if element exists
                guard try await pilot.elementExists(elementID: elementId) else {
                    throw AppMCPError.elementNotAccessible("Element '\(elementId)' not found or not accessible")
                }

                // Click to focus the element
                _ = try await pilot.click(elementID: elementId)

                // Small delay after focusing
                try await Task.sleep(nanoseconds: UInt64(Constants.focusDelay * 1_000_000_000))
            }

            var sentKeys: [String] = []

            // Process each key input
            for (index, keyValue) in keys.enumerated() {
                guard case .object(let keyObj) = keyValue else {
                    throw AppMCPError.invalidParameterType("keys[\(index)]", expected: "object", got: "\(keyValue)")
                }

                let key = try extractRequiredString(from: keyObj, key: "key")
                let modifiers = extractOptionalStringArray(from: keyObj, key: "modifiers") ?? []

                // Send the key combination
                try await sendKeyCombination(key: key, modifiers: modifiers)

                // Build description for this key
                var keyDesc = ""
                if !modifiers.isEmpty {
                    keyDesc = modifiers.joined(separator: "+") + "+"
                }
                keyDesc += key
                sentKeys.append(keyDesc)

                // Delay between key inputs (except after the last one)
                if index < keys.count - 1 && delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000))
                }
            }

            var result = "Sent keyboard input: \(sentKeys.joined(separator: ", "))"
            if let elementId = elementId {
                result += " to element '\(elementId)'"
            }

            return result
        } catch {
            // Convert AppPilot errors to AppMCP errors
            throw convertPilotError(error)
        }
    }
    
    /// Send a key combination with modifiers
    private func sendKeyCombination(key: String, modifiers: [String]) async throws {
        // Convert key and modifiers to CGKeyCode and CGEventFlags
        let keyCode = try keyStringToKeyCode(key)
        let modifierFlags = try modifiersToEventFlags(modifiers)
        
        // Use AppPilot's keyboard functionality if available
        // For now, we'll use CGEvent directly
        
        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw AppMCPError.systemError("Failed to create key down event")
        }
        
        // Set modifier flags
        keyDownEvent.flags = modifierFlags
        
        // Post key down event
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Small delay for key press duration
        try await Task.sleep(nanoseconds: UInt64(Constants.keyPressDuration * 1_000_000_000))
        
        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw AppMCPError.systemError("Failed to create key up event")
        }
        
        // Set modifier flags for key up
        keyUpEvent.flags = modifierFlags
        
        // Post key up event
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    /// Convert key string to CGKeyCode
    private func keyStringToKeyCode(_ key: String) throws -> CGKeyCode {
        // Map common keys to CGKeyCodes
        switch key.lowercased() {
        // Letters
        case "a": return 0x00
        case "b": return 0x0B
        case "c": return 0x08
        case "d": return 0x02
        case "e": return 0x0E
        case "f": return 0x03
        case "g": return 0x05
        case "h": return 0x04
        case "i": return 0x22
        case "j": return 0x26
        case "k": return 0x28
        case "l": return 0x25
        case "m": return 0x2E
        case "n": return 0x2D
        case "o": return 0x1F
        case "p": return 0x23
        case "q": return 0x0C
        case "r": return 0x0F
        case "s": return 0x01
        case "t": return 0x11
        case "u": return 0x20
        case "v": return 0x09
        case "w": return 0x0D
        case "x": return 0x07
        case "y": return 0x10
        case "z": return 0x06
        
        // Numbers
        case "0": return 0x1D
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "5": return 0x17
        case "6": return 0x16
        case "7": return 0x1A
        case "8": return 0x1C
        case "9": return 0x19
        
        // Special keys
        case "enter", "return": return 0x24
        case "tab": return 0x30
        case "space": return 0x31
        case "delete", "backspace": return 0x33
        case "escape", "esc": return 0x35
        case "left": return 0x7B
        case "right": return 0x7C
        case "down": return 0x7D
        case "up": return 0x7E
        
        // Function keys
        case "f1": return 0x7A
        case "f2": return 0x78
        case "f3": return 0x63
        case "f4": return 0x76
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f8": return 0x64
        case "f9": return 0x65
        case "f10": return 0x6D
        case "f11": return 0x67
        case "f12": return 0x6F
        
        default:
            throw AppMCPError.invalidParameters("Unknown key: '\(key)'")
        }
    }
    
    /// Convert modifier strings to CGEventFlags
    private func modifiersToEventFlags(_ modifiers: [String]) throws -> CGEventFlags {
        var flags = CGEventFlags()
        
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "cmd", "command":
                flags.insert(.maskCommand)
            case "shift":
                flags.insert(.maskShift)
            case "alt", "option":
                flags.insert(.maskAlternate)
            case "ctrl", "control":
                flags.insert(.maskControl)
            default:
                throw AppMCPError.invalidParameters("Unknown modifier: '\(modifier)'")
            }
        }
        
        return flags
    }

    /// Build AXQuery from MCP query parameters
    private func buildAXQuery(from queryOptions: [String: MCP.Value]?) throws -> AXUI.AXQuery? {
        guard let queryOptions = queryOptions else {
            return nil // Return nil for no filtering (all elements)
        }

        var query = AXUI.AXQuery()
        var hasFilters = false

        // Role filter - use roleQuery for proper role matching
        if let roleStr = extractOptionalString(from: queryOptions, key: "role") {
            guard let role = AXUI.Role(rawValue: roleStr.capitalized) else {
                throw AppMCPError.invalidParameters("Invalid role '\(roleStr)'. Must be a valid AXRole name.")
            }
            var roleQuery = AXUI.RoleQuery()
            roleQuery.equals = role
            query.roleQuery = roleQuery
            hasFilters = true
        }

        // Title filter - map to descriptionContains for partial match
        if let title = extractOptionalString(from: queryOptions, key: "title") {
            query.descriptionContains = title
            hasFilters = true
        }

        // Identifier filter - exact match
        // Note: This maps to query.identifier field, not to AIElement.name
        if let identifier = extractOptionalString(from: queryOptions, key: "identifier") {
            query.identifier = identifier
            hasFilters = true
        }

        // Enabled state filter
        if let enabled = extractOptionalBool(from: queryOptions, key: "enabled") {
            query.enabled = enabled
            hasFilters = true
        }

        // Return nil if no supported filters were specified
        return hasFilters ? query : nil
    }

    // MARK: - Image Processing Utilities
    
    private func resizeImageIfNeeded(_ image: CGImage, maxDimension: Int) -> CGImage {
        let width = image.width
        let height = image.height
        let maxDim = max(width, height)
        
        // Return original if already small enough
        if maxDim <= maxDimension {
            return image
        }
        
        // Calculate new dimensions maintaining aspect ratio
        let scale = Double(maxDimension) / Double(maxDim)
        let newWidth = Int(Double(width) * scale)
        let newHeight = Int(Double(height) * scale)
        
        // Create resized image
        guard let colorSpace = image.colorSpace,
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
              ) else {
            // Return original if resize fails
            return image
        }
        
        // Set high quality interpolation
        context.interpolationQuality = .high
        
        // Draw resized image
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        // Return resized image or original if creation fails
        return context.makeImage() ?? image
    }
    
    // MARK: - Resource Handlers

    /// Parse URI and query parameters
    private struct ResourceURI {
        let scheme: String
        let path: String
        let pathComponents: [String]
        let queryParameters: [String: String]

        init(uri: String) {
            // Parse URI: appmcp://path/to/resource?param1=value1&param2=value2
            let components = uri.split(separator: "?", maxSplits: 1).map(String.init)
            let mainPart = components[0]
            let queryString = components.count > 1 ? components[1] : ""

            // Parse scheme and path
            let schemeSplit = mainPart.split(separator: "://", maxSplits: 1).map(String.init)
            self.scheme = schemeSplit.count > 1 ? schemeSplit[0] : ""
            let pathPart = schemeSplit.count > 1 ? schemeSplit[1] : mainPart

            self.path = pathPart
            self.pathComponents = pathPart.split(separator: "/").map(String.init)

            // Parse query parameters
            var params: [String: String] = [:]
            if !queryString.isEmpty {
                for pair in queryString.split(separator: "&") {
                    let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    if kv.count == 2 {
                        params[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
                    }
                }
            }
            self.queryParameters = params
        }
    }

    private func setupResourceHandlers() async {
        await server.withMethodHandler(ListResources.self) { _ in
            let resources: [MCP.Resource] = [
                // Application Discovery
                MCP.Resource(
                    name: "running_applications",
                    uri: "appmcp://resources/running_applications",
                    description: "List of all running applications with metadata",
                    mimeType: "application/json"
                ),
                MCP.Resource(
                    name: "application_windows",
                    uri: "appmcp://resources/application_windows",
                    description: "All application windows with bounds and visibility info",
                    mimeType: "application/json"
                ),

                // UI Capture Resources
                MCP.Resource(
                    name: "ui_snapshot",
                    uri: "appmcp://ui/snapshot/{bundleID}",
                    description: "Capture UI screenshot and element hierarchy for an application. Supports query parameters: window (title or index)",
                    mimeType: "application/json"
                ),
                MCP.Resource(
                    name: "ui_elements",
                    uri: "appmcp://ui/elements/{bundleID}",
                    description: "Extract UI element hierarchy for an application. Supports query parameters: window, role, title, identifier, enabled",
                    mimeType: "application/json"
                )
            ]

            return ListResources.Result(resources: resources)
        }

        await server.withMethodHandler(ReadResource.self) { params in
            return await self.handleResource(uri: params.uri)
        }
    }
    
    internal func handleResource(uri: String) async -> ReadResource.Result {
        do {
            let parsedURI = ResourceURI(uri: uri)
            let content: String

            switch parsedURI.pathComponents.first {
            case "resources":
                // Legacy resources
                if parsedURI.path == "resources/running_applications" {
                    content = try await getApplications()
                } else if parsedURI.path == "resources/application_windows" {
                    content = try await getWindows()
                } else {
                    throw AppMCPError.invalidParameters("Unknown resource: \(uri)")
                }

            case "ui":
                // UI capture resources
                guard parsedURI.pathComponents.count >= 3 else {
                    throw AppMCPError.invalidParameters("Invalid UI resource URI. Expected: appmcp://ui/{type}/{bundleID}")
                }

                let resourceType = parsedURI.pathComponents[1]
                let bundleID = parsedURI.pathComponents[2]

                switch resourceType {
                case "snapshot":
                    content = try await getUISnapshot(bundleID: bundleID, params: parsedURI.queryParameters)
                case "elements":
                    content = try await getUIElements(bundleID: bundleID, params: parsedURI.queryParameters)
                default:
                    throw AppMCPError.invalidParameters("Unknown UI resource type: \(resourceType)")
                }

            default:
                throw AppMCPError.invalidParameters("Unknown resource: \(uri)")
            }

            return ReadResource.Result(contents: [
                .text(content, uri: uri, mimeType: "application/json")
            ])

        } catch {
            // Use proper JSON serialization to avoid escaping issues
            let errorData: [String: String] = ["error": error.localizedDescription]
            let errorJSON: String
            if let jsonData = try? JSONEncoder().encode(errorData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                errorJSON = jsonString
            } else {
                // Fallback: manually escape with JSONSerialization
                errorJSON = "{\"error\":\"Failed to encode error message\"}"
            }

            return ReadResource.Result(contents: [
                .text(errorJSON, uri: uri, mimeType: "application/json")
            ])
        }
    }
    
    private func getApplications() async throws -> String {
        // Use AppPilot to get real running applications
        let apps: [AppInfo]
        do {
            apps = try await pilot.listApplications()
        } catch {
            // If we can't list applications at all, return error information
            throw AppMCPError.permissionDenied("Cannot list applications: \(error.localizedDescription)")
        }

        var appData: [[String: Any]] = []

        for app in apps {
            // Skip processing apps that may cause permission errors
            // Only include basic information for all apps
            var appInfo: [String: Any] = [
                "name": app.name,
                "bundleID": app.bundleIdentifier ?? "unknown",
                "handle": app.id.id,
                "isActive": app.isActive,
                "windows": [],
                "windowCount": 0
            ]

            // Try to get windows, but don't fail if we can't access this specific app
            do {
                let windows = try await pilot.listWindows(app: app.id)
                let windowData = windows.map { window in
                    [
                        "title": window.title ?? "Untitled",
                        "handle": window.id.id,
                        "bounds": [
                            "x": window.bounds.origin.x,
                            "y": window.bounds.origin.y,
                            "width": window.bounds.size.width,
                            "height": window.bounds.size.height
                        ],
                        "isVisible": window.isVisible,
                        "isMain": window.isMain
                    ] as [String: Any]
                }
                appInfo["windows"] = windowData
                appInfo["windowCount"] = windows.count
            } catch {
                // Only suppress expected permission errors
                let convertedError = convertPilotError(error)
                if case .permissionDenied = convertedError {
                    // Keep the empty windows array and 0 count for permission-denied apps
                } else {
                    // Log unexpected errors for debugging
                    print("⚠️ Unexpected error listing windows for \(app.name): \(error)")
                    // Continue processing other apps
                }
            }

            appData.append(appInfo)
        }

        let data = try JSONSerialization.data(withJSONObject: ["applications": appData])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    private func getWindows() async throws -> String {
        // Get windows from all accessible applications
        let apps = try await pilot.listApplications()
        var allWindows: [[String: Any]] = []

        for app in apps {
            do {
                let windows = try await pilot.listWindows(app: app.id)
                let windowData = windows.map { window in
                    [
                        "title": window.title ?? "Untitled",
                        "handle": window.id.id,
                        "app": app.name,
                        "appHandle": app.id.id,
                        "bounds": [
                            "x": window.bounds.origin.x,
                            "y": window.bounds.origin.y,
                            "width": window.bounds.size.width,
                            "height": window.bounds.size.height
                        ],
                        "isVisible": window.isVisible,
                        "isMain": window.isMain
                    ] as [String: Any]
                }
                allWindows.append(contentsOf: windowData)
            } catch {
                // Only suppress expected permission errors
                let convertedError = convertPilotError(error)
                if case .permissionDenied = convertedError {
                    // Skip permission-denied apps
                    continue
                } else {
                    // Log unexpected errors for debugging
                    print("⚠️ Unexpected error listing windows for \(app.name): \(error)")
                    continue
                }
            }
        }

        let data = try JSONSerialization.data(withJSONObject: ["windows": allWindows])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - UI Resource Handlers

    private func getUISnapshot(bundleID: String, params: [String: String]) async throws -> String {
        let app = try await pilot.findApplication(bundleID: bundleID)

        // Build arguments for resolveWindow
        var arguments: [String: MCP.Value] = [:]
        if let windowParam = params["window"], let windowIndex = Int(windowParam) {
            guard windowIndex >= 0 else {
                throw AppMCPError.invalidParameters("Window index must be non-negative, got: \(windowIndex)")
            }
            arguments["window"] = .int(windowIndex)
        }

        // Resolve window using existing method
        let window = try await resolveWindow(from: arguments, for: app)

        // Capture UI snapshot using AppPilot
        let snapshot = try await pilot.snapshot(window: window)

        // Resize image for MCP compatibility
        guard let originalImage = snapshot.image else {
            throw AppMCPError.systemError("Failed to extract image from snapshot")
        }
        let resizedImage = resizeImageIfNeeded(originalImage, maxDimension: Constants.maxSnapshotDimension)

        // Convert to JPEG for efficiency
        guard let imageData = ScreenCaptureUtility.convertToJPEG(resizedImage, quality: Constants.snapshotJPEGQuality) else {
            throw AppMCPError.systemError("Failed to convert snapshot to JPEG")
        }

        // Build element hierarchy with IDs
        let elementsJson = try AXUI.AIFormatHelpers.convertToAIFormat(elements: snapshot.elements)

        // Build metadata
        let windowTitle = snapshot.windowInfo.title ?? "Unknown Window"
        let dimensions = "\(resizedImage.width)x\(resizedImage.height)"
        let fileSizeKB = String(format: "%.1f", Double(imageData.count) / 1024.0)
        let elementCount = snapshot.elements.count
        let base64Data = imageData.base64EncodedString()

        // Check response size
        let totalSize = base64Data.count + elementsJson.count
        if totalSize > Constants.maxResponseSize {
            return """
            UI Snapshot captured successfully:
            - Window: \(windowTitle)
            - Dimensions: \(dimensions)
            - Format: JPEG
            - Size: \(fileSizeKB) KB (screenshot omitted due to size)
            - Elements found: \(elementCount)
            - Captured: \(Date().formatted())

            Note: Screenshot omitted from response due to size (\(String(format: "%.1f", Double(totalSize) / 1024.0)) KB). UI elements included below.

            UI Elements:
            \(elementsJson)
            """
        }

        return """
        UI Snapshot captured successfully:
        - Window: \(windowTitle)
        - Dimensions: \(dimensions)
        - Format: JPEG
        - Size: \(fileSizeKB) KB
        - Elements found: \(elementCount)
        - Captured: \(Date().formatted())

        Screenshot:
        data:image/jpeg;base64,\(base64Data)

        UI Elements:
        \(elementsJson)
        """
    }

    private func getUIElements(bundleID: String, params: [String: String]) async throws -> String {
        let app = try await pilot.findApplication(bundleID: bundleID)

        // Build arguments for resolveWindow
        var arguments: [String: MCP.Value] = [:]
        if let windowParam = params["window"], let windowIndex = Int(windowParam) {
            guard windowIndex >= 0 else {
                throw AppMCPError.invalidParameters("Window index must be non-negative, got: \(windowIndex)")
            }
            arguments["window"] = .int(windowIndex)
        }

        // Resolve window using existing method
        let window = try await resolveWindow(from: arguments, for: app)

        // Build query object from parameters
        var queryObj: [String: MCP.Value] = [:]
        if let role = params["role"] {
            queryObj["role"] = .string(role)
        }
        if let title = params["title"] {
            queryObj["title"] = .string(title)
        }
        if let identifier = params["identifier"] {
            queryObj["identifier"] = .string(identifier)
        }
        if let enabled = params["enabled"] {
            queryObj["enabled"] = .bool(enabled == "true")
        }

        // Build AXQuery from parameters
        let axQuery = try buildAXQuery(from: queryObj.isEmpty ? nil : queryObj)

        // Capture UI snapshot using AppPilot with AXQuery filtering
        let snapshot = try await pilot.snapshot(window: window, query: axQuery)

        // Build element hierarchy with IDs
        let elementsJson = try AXUI.AIFormatHelpers.convertToAIFormat(elements: snapshot.elements)

        // Build metadata
        let windowTitle = snapshot.windowInfo.title ?? "Unknown Window"
        let elementCount = snapshot.elements.count

        return """
        Elements Snapshot extracted successfully:
        - Application: \(bundleID)
        - Window: \(windowTitle)
        - Elements found: \(elementCount)
        - Captured: \(Date().formatted())

        UI Elements:
        \(elementsJson)
        """
    }


    // MARK: - Type-Safe Parameter Extraction
    
    private func extractRequiredString(from arguments: [String: MCP.Value], key: String) throws -> String {
        guard let value = arguments[key] else {
            throw AppMCPError.missingParameter(key)
        }
        
        guard case .string(let str) = value else {
            throw AppMCPError.invalidParameterType(key, expected: "string", got: "\(value)")
        }
        
        return str
    }
    
    private func extractOptionalString(from arguments: [String: MCP.Value], key: String) -> String? {
        guard let value = arguments[key] else { return nil }
        guard case .string(let str) = value else { return nil }
        return str
    }
    
    private func extractRequiredObject(from arguments: [String: MCP.Value], key: String) throws -> [String: MCP.Value] {
        guard let value = arguments[key] else {
            throw AppMCPError.missingParameter(key)
        }
        
        guard case .object(let obj) = value else {
            throw AppMCPError.invalidParameterType(key, expected: "object", got: "\(value)")
        }
        
        return obj
    }
    
    private func extractOptionalObject(from arguments: [String: MCP.Value], key: String) -> [String: MCP.Value]? {
        guard let value = arguments[key] else { return nil }
        guard case .object(let obj) = value else { return nil }
        return obj
    }
    
    private func extractOptionalDouble(from arguments: [String: MCP.Value], key: String) -> Double? {
        guard let value = arguments[key] else { return nil }
        
        switch value {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        default:
            return nil
        }
    }
    
    private func extractOptionalBool(from arguments: [String: MCP.Value], key: String) -> Bool? {
        guard let value = arguments[key] else { return nil }
        guard case .bool(let bool) = value else { return nil }
        return bool
    }
    
    private func extractOptionalStringArray(from arguments: [String: MCP.Value], key: String) -> [String]? {
        guard let value = arguments[key] else { return nil }
        guard case .array(let array) = value else { return nil }
        
        var strings: [String] = []
        for item in array {
            if case .string(let str) = item {
                strings.append(str)
            }
        }
        
        return strings.isEmpty ? nil : strings
    }
    
    private func extractRequiredArray(from arguments: [String: MCP.Value], key: String) throws -> [MCP.Value] {
        guard let value = arguments[key] else {
            throw AppMCPError.missingParameter(key)
        }
        
        guard case .array(let array) = value else {
            throw AppMCPError.invalidParameterType(key, expected: "array", got: "\(value)")
        }
        
        return array
    }

    // MARK: - User-Friendly Element Type Mapping
    
    private func resolveWindow(from arguments: [String: MCP.Value], for app: AppHandle) async throws -> WindowHandle {
        // NOTE: Type-safe extraction ensures correct routing based on MCP.Value type:
        // - MCP.Value.string("Main Window") → title-based search (first check)
        // - MCP.Value.int(0) → index-based search (second check, since extractOptionalString returns nil for int)
        // This design allows both string titles and numeric indices using the same "window" parameter key.

        // Check for explicit window parameter (string title)
        if let windowTitle = extractOptionalString(from: arguments, key: "window") {
            guard let window = try await pilot.findWindow(app: app, title: windowTitle) else {
                throw AppMCPError.windowNotFound("Window with title '\(windowTitle)' not found")
            }
            return window
        }
        
        // Check for window index
        if let windowIndex = extractOptionalDouble(from: arguments, key: "window") {
            let index = Int(windowIndex)
            guard let window = try await pilot.findWindow(app: app, index: index) else {
                throw AppMCPError.windowNotFound("Window at index \(index) not found")
            }
            return window
        }
        
        // Default to main window, then first available window (revert to original approach)
        let windows = try await pilot.listWindows(app: app)
        
        // For Chrome and other browsers, don't pre-validate with capture
        // as they may have special security restrictions
        if let mainWindow = windows.first(where: { $0.isMain }) {
            return mainWindow.id
        }
        
        if let firstWindow = windows.first {
            return firstWindow.id
        }
        
        throw AppMCPError.windowNotFound("No windows found for application")
    }
    
    // MARK: - Error Handling Helpers
    
    /// Convert AppPilot errors to AppMCP errors for better error reporting
    private func convertPilotError(_ error: Swift.Error) -> AppMCPError {
        // Check if it's already an AppMCP error
        if let appMcpError = error as? AppMCPError {
            return appMcpError
        }
        
        // Convert common AppPilot error patterns
        let errorString = error.localizedDescription.lowercased()

        // NOTE: Order conditions from specific to general to avoid incorrect matches.
        // Example: "Window not found in application Finder" should match windowNotFound, not applicationNotFound.

        // Window-related errors (check before generic application errors)
        if errorString.contains("window not found") || errorString.contains("no window found") {
            return .windowNotFound(error.localizedDescription)
        }

        // Element-related errors (check before generic "not found" patterns)
        if errorString.contains("element not found") || errorString.contains("no element found") ||
           errorString.contains("failed to find element") {
            return .elementNotFound(error.localizedDescription)
        }

        // Application-related errors (now safe to check)
        if errorString.contains("application not found") || errorString.contains("no application found") {
            return .applicationNotFound(error.localizedDescription)
        }
        
        // Accessibility errors
        if errorString.contains("element not accessible") || errorString.contains("not accessible") ||
           errorString.contains("accessibility disabled") {
            return .elementNotAccessible(error.localizedDescription)
        }
        
        // Permission errors
        if errorString.contains("permission denied") || errorString.contains("accessibility") ||
           errorString.contains("not authorized") || errorString.contains("requires permission") {
            return .permissionDenied(error.localizedDescription)
        }
        
        // Coordinate/bounds errors
        if (errorString.contains("coordinate") && errorString.contains("bounds")) ||
           errorString.contains("out of bounds") || errorString.contains("invalid coordinates") {
            return .coordinateOutOfBounds(error.localizedDescription)
        }
        
        // Timeout errors
        if errorString.contains("timeout") || errorString.contains("timed out") ||
           errorString.contains("operation took too long") {
            return .timeout(error.localizedDescription)
        }
        
        // Default to system error
        return .systemError(error.localizedDescription)
    }
    
    /// Enhanced error handling for tool operations
    private func handleToolError(_ error: Swift.Error, toolName: String) -> CallTool.Result {
        let convertedError = convertPilotError(error)
        return CallTool.Result(
            content: [.text("Error in \(toolName): \(convertedError.localizedDescription)")],
            isError: true
        )
    }
    
    // MARK: - Server Lifecycle
    
    public func start() async throws {
        print("🚀 AppMCP Server starting...")
        print("   Version: \(AppMCP.version)")
        print("   MCP Protocol: \(AppMCP.mcpVersion)")
        print("   Powered by: AppPilot")
        print("   Essential automation actions available")
        
        // Validate AppPilot capabilities on startup
        do {
            try await validateAppPilotCapabilities()
            print("✅ AppPilot capabilities verified")
        } catch {
            print("⚠️  AppPilot capability check failed: \(error.localizedDescription)")
            print("   Some features may not work without proper permissions")
        }
        
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
    
    public func stop() async {
        await server.stop()
    }
}

// MARK: - Extensions for convenience

extension AppMCPServer {
    /// Create a server for Weather app automation
    public static func forWeatherApp() -> AppMCPServer {
        return AppMCPServer()
    }
}

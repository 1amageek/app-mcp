import Foundation
import MCP
import AppPilot
import AppKit

/// Modern MCP Server for macOS UI automation powered by AppPilot
public final class AppMCPServer: @unchecked Sendable {
    
    private let server: MCP.Server
    private let pilot: AppPilot
    
    public init() {
        // Initialize AppPilot with default drivers
        self.pilot = AppPilot()
        
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
    
    private func setupHandlers() async {
        await setupToolHandlers()
        await setupResourceHandlers()
    }
    
    // MARK: - Tool Handlers
    
    private func setupToolHandlers() async {
        await server.withMethodHandler(ListTools.self) { _ in
            return ListTools.Result(tools: [
                MCP.Tool(
                    name: "automation",
                    description: "Essential automation actions for macOS applications",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "action": [
                                "type": "string",
                                "enum": ["click", "type", "setText", "drag", "scroll", "wait", "find", "screenshot"],
                                "description": "Action to perform"
                            ],
                            "appName": [
                                "type": "string", 
                                "description": "Target application name (e.g., 'Calculator', 'TextEdit')"
                            ],
                            "bundleID": [
                                "type": "string", 
                                "description": "Target application bundle ID (e.g., 'com.apple.calculator')"
                            ],
                            "window": [
                                "type": ["string", "number"],
                                "description": "Target window (title or index, optional for some actions)"
                            ],
                            "element": [
                                "type": "object",
                                "properties": [
                                    "role": ["type": "string", "description": "UI element role (AXButton, AXTextField, etc.)"],
                                    "title": ["type": "string", "description": "Element title or label"],
                                    "identifier": ["type": "string", "description": "Element accessibility identifier"]
                                ],
                                "description": "Target UI element (for click, type, setText, find actions)"
                            ],
                            "coordinates": [
                                "type": "object",
                                "properties": [
                                    "x": ["type": "number", "description": "X coordinate"],
                                    "y": ["type": "number", "description": "Y coordinate"]
                                ],
                                "description": "Screen coordinates (fallback when element not available)"
                            ],
                            "text": [
                                "type": "string",
                                "description": "Text content (for type: keystroke simulation, setText: direct value setting)"
                            ],
                            "startPoint": [
                                "type": "object",
                                "properties": [
                                    "x": ["type": "number", "description": "Start X coordinate"],
                                    "y": ["type": "number", "description": "Start Y coordinate"]
                                ],
                                "description": "Start point for drag action"
                            ],
                            "endPoint": [
                                "type": "object",
                                "properties": [
                                    "x": ["type": "number", "description": "End X coordinate"],
                                    "y": ["type": "number", "description": "End Y coordinate"]
                                ],
                                "description": "End point for drag action"
                            ],
                            "deltaX": [
                                "type": "number",
                                "description": "Horizontal scroll amount (positive = right, negative = left)"
                            ],
                            "deltaY": [
                                "type": "number",
                                "description": "Vertical scroll amount (positive = down, negative = up)"
                            ],
                            "duration": [
                                "type": "number",
                                "description": "Duration in seconds (for wait action, default: 1.0)"
                            ]
                        ],
                        "required": ["action"]
                    ]
                )
            ])
        }
        
        await server.withMethodHandler(CallTool.self) { params in
            guard params.name == "automation" else {
                return CallTool.Result(
                    content: [.text("Unknown tool: \(params.name)")],
                    isError: true
                )
            }
            
            return await self.handleAutomation(params.arguments ?? [:])
        }
    }
    
    private func handleAutomation(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            guard let actionValue = arguments["action"],
                  case .string(let action) = actionValue else {
                throw AppMCPError.invalidParameters("Missing 'action' parameter")
            }
            
            let result = try await performAction(action, arguments: arguments)
            return CallTool.Result(content: [.text(result)])
            
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    private func performAction(_ action: String, arguments: [String: MCP.Value]) async throws -> String {
        switch action {
        case "click":
            return try await performClick(arguments)
        case "setText":
            return try await performSetText(arguments)
        case "type":
            return try await performType(arguments)
        case "drag":
            return try await performDrag(arguments)
        case "scroll":
            return try await performScroll(arguments)
        case "wait":
            return try await performWait(arguments)
        case "find":
            return try await performFind(arguments)
        case "screenshot":
            return try await performScreenshot(arguments)
        default:
            throw AppMCPError.invalidParameters("Unknown action: \(action)")
        }
    }
    
    // MARK: - Action Implementations
    
    private func performClick(_ arguments: [String: MCP.Value]) async throws -> String {
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        if let elementValue = arguments["element"] {
            // Element-based click
            let element = try await findElement(in: window, using: elementValue)
            _ = try await pilot.clickElement(element, in: window)
            return "Clicked element \(element.role.rawValue) '\(element.title ?? element.id)' at (\(element.centerPoint.x), \(element.centerPoint.y))"
        } else if case .object(let coords) = arguments["coordinates"],
                  case .double(let x) = coords["x"],
                  case .double(let y) = coords["y"] {
            // Coordinate-based click
            let point = Point(x: x, y: y)
            _ = try await pilot.click(window: window, at: point)
            return "Clicked at coordinates (\(x), \(y))"
        } else {
            throw AppMCPError.invalidParameters("Missing 'element' or 'coordinates' parameter for click action")
        }
    }
    
    private func performSetText(_ arguments: [String: MCP.Value]) async throws -> String {
        guard case .string(let text) = arguments["text"] else {
            throw AppMCPError.invalidParameters("Missing 'text' parameter")
        }
        
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        if let elementValue = arguments["element"] {
            // Set text directly using AppPilot's setValue method (fast, direct)
            let element = try await findElement(in: window, using: elementValue)
            let result = try await pilot.setValue(text, for: element)
            let actualText: String
            if case .setValue(_, let actual) = result.data {
                actualText = actual ?? "unknown"
            } else {
                actualText = "unknown"
            }
            return "Set text '\(text)' in \(element.role.rawValue) '\(element.title ?? element.id)'. Actual text: \(actualText)"
        } else {
            throw AppMCPError.invalidParameters("setText action requires 'element' parameter")
        }
    }
    
    private func performType(_ arguments: [String: MCP.Value]) async throws -> String {
        guard case .string(let text) = arguments["text"] else {
            throw AppMCPError.invalidParameters("Missing 'text' parameter")
        }
        
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        if let elementValue = arguments["element"] {
            // Type into specific element using AppPilot's input method (realistic keystroke simulation)
            let element = try await findElement(in: window, using: elementValue)
            let result = try await pilot.input(text: text, into: element)
            let actualText: String
            if case .type(_, let actual, _, _) = result.data {
                actualText = actual ?? "unknown"
            } else {
                actualText = "unknown"
            }
            return "Typed '\(text)' into \(element.role.rawValue) '\(element.title ?? element.id)'. Actual text: \(actualText)"
        } else {
            // Type into focused element with window context (keystroke simulation)
            _ = try await pilot.type(text, window: window)
            return "Typed '\(text)' into focused element"
        }
    }
    
    private func performDrag(_ arguments: [String: MCP.Value]) async throws -> String {
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        guard case .object(let startCoords) = arguments["startPoint"],
              case .double(let startX) = startCoords["x"],
              case .double(let startY) = startCoords["y"],
              case .object(let endCoords) = arguments["endPoint"],
              case .double(let endX) = endCoords["x"],
              case .double(let endY) = endCoords["y"] else {
            throw AppMCPError.invalidParameters("Missing 'startPoint' and 'endPoint' parameters for drag action")
        }
        
        let startPoint = Point(x: startX, y: startY)
        let endPoint = Point(x: endX, y: endY)
        
        let duration: TimeInterval
        if case .double(let d) = arguments["duration"] {
            duration = d
        } else {
            duration = 1.0
        }
        
        _ = try await pilot.drag(from: startPoint, to: endPoint, duration: duration, window: window)
        return "Dragged from (\(startX), \(startY)) to (\(endX), \(endY)) over \(duration) seconds"
    }
    
    private func performScroll(_ arguments: [String: MCP.Value]) async throws -> String {
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        let deltaX: Double
        if case .double(let dx) = arguments["deltaX"] {
            deltaX = dx
        } else if case .int(let dx) = arguments["deltaX"] {
            deltaX = Double(dx)
        } else {
            deltaX = 0.0
        }
        
        let deltaY: Double
        if case .double(let dy) = arguments["deltaY"] {
            deltaY = dy
        } else if case .int(let dy) = arguments["deltaY"] {
            deltaY = Double(dy)
        } else {
            deltaY = 0.0
        }
        
        // Get scroll position - use window center if no coordinates specified
        let point: Point
        if case .object(let coords) = arguments["coordinates"],
           case .double(let x) = coords["x"],
           case .double(let y) = coords["y"] {
            point = Point(x: x, y: y)
        } else {
            // Use window center for scroll
            let windows = try await pilot.listWindows(app: try await resolveApp(arguments))
            if let windowInfo = windows.first(where: { $0.id == window }) {
                let bounds = windowInfo.bounds
                point = Point(x: bounds.midX, y: bounds.midY)
            } else {
                point = Point(x: 400.0, y: 400.0) // Default center
            }
        }
        
        // Use AppPilot's safe scroll method with window context
        _ = try await pilot.scroll(deltaX: deltaX, deltaY: deltaY, at: point, window: window)
        
        return "Scrolled deltaX: \(deltaX), deltaY: \(deltaY) at (\(point.x), \(point.y))"
    }
    
    private func performWait(_ arguments: [String: MCP.Value]) async throws -> String {
        let duration: Double
        if case .double(let d) = arguments["duration"] {
            duration = d
        } else if case .int(let i) = arguments["duration"] {
            duration = Double(i)
        } else {
            duration = 1.0 // Default 1 second
        }
        
        try await pilot.wait(.time(seconds: duration))
        return "Waited \(duration) seconds"
    }
    
    private func performFind(_ arguments: [String: MCP.Value]) async throws -> String {
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        if let elementValue = arguments["element"] {
            // Find specific element
            let element = try await findElement(in: window, using: elementValue)
            return "Found element: \(element.role.rawValue) '\(element.title ?? element.id)' at (\(element.centerPoint.x), \(element.centerPoint.y))"
        } else {
            // List all elements
            let elements = try await pilot.findElements(in: window)
            let summary = elements.prefix(10).map { "\($0.role.rawValue) '\($0.title ?? $0.id)'" }.joined(separator: ", ")
            return "Found \(elements.count) elements: \(summary)\(elements.count > 10 ? "..." : "")"
        }
    }
    
    private func performScreenshot(_ arguments: [String: MCP.Value]) async throws -> String {
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        // Use AppPilot's screenshot capability
        let cgImage = try await pilot.capture(window: window)
        
        // Convert CGImage to PNG data
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw AppMCPError.systemError("Failed to convert screenshot to PNG")
        }
        
        return "data:image/png;base64,\(pngData.base64EncodedString())"
    }
    
    // MARK: - Resource Handlers
    
    private func setupResourceHandlers() async {
        await server.withMethodHandler(ListResources.self) { _ in
            return ListResources.Result(resources: [
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
                )
            ])
        }
        
        await server.withMethodHandler(ReadResource.self) { params in
            return await self.handleResource(uri: params.uri)
        }
    }
    
    private func handleResource(uri: String) async -> ReadResource.Result {
        do {
            let content: String
            
            switch uri {
            case "appmcp://resources/running_applications":
                content = try await getApplications()
            case "appmcp://resources/application_windows":
                content = try await getWindows()
            default:
                throw AppMCPError.invalidParameters("Unknown resource: \(uri)")
            }
            
            return ReadResource.Result(contents: [
                .text(content, uri: uri, mimeType: "application/json")
            ])
            
        } catch {
            return ReadResource.Result(contents: [
                .text("{\"error\": \"\(error.localizedDescription)\"}", uri: uri, mimeType: "application/json")
            ])
        }
    }
    
    private func getApplications() async throws -> String {
        // Use AppPilot to get real running applications
        let apps = try await pilot.listApplications()
        
        let appData = apps.map { app in
            [
                "name": app.name,
                "bundleID": app.bundleIdentifier ?? "unknown",
                "handle": app.id.id,
                "isActive": app.isActive
            ] as [String: Any]
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
                // Skip apps that can't be queried (permission issues)
                continue
            }
        }
        
        let data = try JSONSerialization.data(withJSONObject: ["windows": allWindows])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - Helper Methods
    
    private func resolveApp(_ arguments: [String: MCP.Value]) async throws -> AppHandle {
        // Try bundle ID first (more specific)
        if case .string(let bundleID) = arguments["bundleID"] {
            return try await pilot.findApplication(bundleId: bundleID)
        }
        
        // Then try app name
        if case .string(let appName) = arguments["appName"] {
            return try await pilot.findApplication(name: appName)
        }
        
        throw AppMCPError.invalidParameters("Missing 'appName' or 'bundleID' parameter")
    }
    
    private func resolveAppAndWindow(_ arguments: [String: MCP.Value]) async throws -> (AppHandle, WindowHandle) {
        // Get application
        let app = try await resolveApp(arguments)
        
        // Get window (optional for some actions)
        let window: WindowHandle
        if case .string(let windowTitle) = arguments["window"] {
            guard let foundWindow = try await pilot.findWindow(app: app, title: windowTitle) else {
                throw AppMCPError.windowNotFound("Window with title '\(windowTitle)' not found")
            }
            window = foundWindow
        } else if case .int(let index) = arguments["window"] {
            guard let foundWindow = try await pilot.findWindow(app: app, index: index) else {
                throw AppMCPError.windowNotFound("Window at index \(index) not found")
            }
            window = foundWindow
        } else {
            // Default to first window
            guard let foundWindow = try await pilot.findWindow(app: app, index: 0) else {
                throw AppMCPError.windowNotFound("No windows found for application")
            }
            window = foundWindow
        }
        
        return (app, window)
    }
    
    private func findElement(in window: WindowHandle, using elementValue: MCP.Value?) async throws -> UIElement {
        guard case .object(let elementParams) = elementValue else {
            throw AppMCPError.invalidParameters("Missing element parameters")
        }
        
        // Extract search criteria
        let role: ElementRole?
        if case .string(let roleStr) = elementParams["role"] {
            role = ElementRole(rawValue: roleStr) ?? ElementRole.allCases.first { $0.rawValue.lowercased().contains(roleStr.lowercased()) }
        } else {
            role = nil
        }
        
        let title: String?
        if case .string(let titleStr) = elementParams["title"] {
            title = titleStr
        } else {
            title = nil
        }
        
        let identifier: String?
        if case .string(let idStr) = elementParams["identifier"] {
            identifier = idStr
        } else {
            identifier = nil
        }
        
        // Use AppPilot's element finding capabilities
        if let role = role, let title = title {
            // Find specific element by role and title
            return try await pilot.findElement(in: window, role: role, title: title)
        } else {
            // Find elements by criteria and return first match
            let elements = try await pilot.findElements(in: window, role: role, title: title, identifier: identifier)
            guard let element = elements.first else {
                let criteria = [role?.rawValue, title, identifier].compactMap { $0 }.joined(separator: ", ")
                throw AppMCPError.elementNotFound("No element found matching criteria: \(criteria)")
            }
            return element
        }
    }
    
    // MARK: - Server Lifecycle
    
    public func start() async throws {
        print("🚀 AppMCP Server starting...")
        print("   Version: \(AppMCP.version)")
        print("   MCP Protocol: \(AppMCP.mcpVersion)")
        print("   Powered by: AppPilot")
        print("   Essential automation actions available")
        
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
    
    // MARK: - Test Support
    
    /// Test helper for resource calls (public for testing)  
    public func testHandleResource(uri: String) async -> (success: Bool, content: String) {
        let result = await self.handleResource(uri: uri)
        
        if let firstContent = result.contents.first {
            if let text = firstContent.text {
                return (success: true, content: text)
            } else if let blob = firstContent.blob,
                      let data = Data(base64Encoded: blob),
                      let string = String(data: data, encoding: .utf8) {
                return (success: true, content: string)
            } else {
                return (success: false, content: "No readable content")
            }
        } else {
            return (success: false, content: "No content")
        }
    }
    
    /// Test helper for automation calls (public for testing)
    public func testHandleAutomation(_ arguments: [String: MCP.Value]) async -> (success: Bool, content: String, isError: Bool) {
        let result = await self.handleAutomation(arguments)
        
        if let firstContent = result.content.first {
            switch firstContent {
            case .text(let text):
                return (success: true, content: text, isError: result.isError ?? false)
            case .image(data: let base64, mimeType: _, metadata: _):
                return (success: true, content: base64, isError: result.isError ?? false)
            case .resource(uri: let uri, mimeType: _, text: let text):
                let content = text ?? "Resource: \(uri)"
                return (success: true, content: content, isError: result.isError ?? false)
            case .audio(data: let base64, mimeType: _):
                return (success: true, content: base64, isError: result.isError ?? false)
            }
        } else {
            return (success: false, content: "No content", isError: true)
        }
    }
}
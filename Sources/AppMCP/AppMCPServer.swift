import Foundation
import MCP
import AppKit
import ApplicationServices

public class AppMCPServer: @unchecked Sendable {
    private let server: Server
    private let registry: AppRegistry
    private let tccManager: EnhancedTCCManager
    private let coordinateConverter: CoordinateConverter
    private let applicationResources: ApplicationResources
    private let resolveTools: ResolveTools
    private let actionTools: ActionTools
    private let waitTool: WaitTool
    
    public init() {
        self.registry = AppRegistry()
        self.tccManager = EnhancedTCCManager()
        self.coordinateConverter = CoordinateConverter()
        
        // Initialize component classes
        self.applicationResources = ApplicationResources(registry: registry, tccManager: tccManager)
        self.resolveTools = ResolveTools(registry: registry, tccManager: tccManager)
        self.actionTools = ActionTools(registry: registry, coordinateConverter: coordinateConverter)
        self.waitTool = WaitTool(registry: registry)
        
        // Create MCP server with capabilities
        self.server = Server(
            name: "AppMCP",
            version: "0.2.0",
            capabilities: .init(
                prompts: nil, // Not using prompts
                resources: .init(
                    subscribe: false,  // v0.2 doesn't support subscription
                    listChanged: false
                ),
                tools: .init(
                    listChanged: false // v0.2 doesn't support dynamic tool changes
                )
            )
        )
        
        Task {
            await setupResourceHandlers()
            await setupToolHandlers()
        }
    }
    
    // MARK: - Resource Handlers
    
    private func setupResourceHandlers() async {
        // List Resources
        await server.withMethodHandler(ListResources.self) { _ in
            ListResources.Result(resources: [
                Resource(
                    name: "installed_applications",
                    uri: "appmcp://resources/installed_applications",
                    description: "List of all installed .app bundles on the system",
                    mimeType: "application/json"
                ),
                Resource(
                    name: "running_applications", 
                    uri: "appmcp://resources/running_applications",
                    description: "List of currently running applications",
                    mimeType: "application/json"
                ),
                Resource(
                    name: "accessible_applications",
                    uri: "appmcp://resources/accessible_applications", 
                    description: "List of applications with accessibility permissions and their windows",
                    mimeType: "application/json"
                ),
                Resource(
                    name: "list_windows",
                    uri: "appmcp://resources/list_windows",
                    description: "List all windows for a specific app handle (requires ?app_handle= parameter)",
                    mimeType: "application/json"
                )
            ])
        }
        
        // Read Resource
        await server.withMethodHandler(ReadResource.self) { [weak self] request in
            guard let self = self else {
                throw MCPError.internalError("Server instance unavailable")
            }
            
            let uri = request.uri
            let urlComponents = URLComponents(string: uri)
            
            guard let scheme = urlComponents?.scheme, scheme == "appmcp",
                  let path = urlComponents?.path else {
                throw MCPError.invalidParameters("Invalid URI format: \(uri)")
            }
            
            switch path {
            case "/resources/installed_applications":
                let content = try await self.applicationResources.getInstalledApplications()
                return ReadResource.Result(contents: [.text(content, uri: uri)])
                
            case "/resources/running_applications":
                let content = try await self.applicationResources.getRunningApplications()
                return ReadResource.Result(contents: [.text(content, uri: uri)])
                
            case "/resources/accessible_applications":
                let content = try await self.applicationResources.getAccessibleApplications()
                return ReadResource.Result(contents: [.text(content, uri: uri)])
                
            case "/resources/list_windows":
                let queryItems = urlComponents?.queryItems
                guard let appHandle = queryItems?.first(where: { $0.name == "app_handle" })?.value else {
                    throw MCPError.invalidParameters("app_handle parameter required for list_windows")
                }
                let content = try await self.applicationResources.getListWindows(appHandle: appHandle)
                return ReadResource.Result(contents: [.text(content, uri: uri)])
                
            default:
                throw MCPError.resourceUnavailable("Unknown resource: \(path)")
            }
        }
    }
    
    // MARK: - Tool Handlers
    
    private func setupToolHandlers() async {
        // List Tools
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: [
                Tool(
                    name: "resolve_app",
                    description: "Resolve application to app_handle by bundle ID, name, or PID",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "bundle_id": .object([
                                "type": .string("string"),
                                "description": .string("Application bundle identifier (e.g., com.apple.Safari)")
                            ]),
                            "process_name": .object([
                                "type": .string("string"), 
                                "description": .string("Process name to search for")
                            ]),
                            "pid": .object([
                                "type": .string("integer"),
                                "description": .string("Process ID")
                            ])
                        ]),
                        "oneOf": .array([
                            .object(["required": .array([.string("bundle_id")])]),
                            .object(["required": .array([.string("process_name")])]),
                            .object(["required": .array([.string("pid")])])
                        ])
                    ])
                ),
                Tool(
                    name: "resolve_window", 
                    description: "Resolve window to window_handle within an app",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "app_handle": .object([
                                "type": .string("string"),
                                "description": .string("App handle from resolve_app")
                            ]),
                            "title_regex": .object([
                                "type": .string("string"),
                                "description": .string("Regular expression to match window title")
                            ]),
                            "index": .object([
                                "type": .string("integer"),
                                "description": .string("Zero-based window index")
                            ])
                        ]),
                        "required": .array([.string("app_handle")]),
                        "oneOf": .array([
                            .object(["required": .array([.string("title_regex")])]),
                            .object(["required": .array([.string("index")])])
                        ])
                    ])
                ),
                Tool(
                    name: "mouse_click",
                    description: "Perform mouse click at specified coordinates", 
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "window_handle": .object([
                                "type": .string("string"),
                                "description": .string("Target window handle")
                            ]),
                            "x": .object([
                                "type": .string("number"),
                                "description": .string("X coordinate")
                            ]),
                            "y": .object([
                                "type": .string("number"), 
                                "description": .string("Y coordinate")
                            ]),
                            "coordinate_space": .object([
                                "type": .string("string"),
                                "enum": .array([.string("window"), .string("global"), .string("screen")]),
                                "default": .string("window"),
                                "description": .string("Coordinate system reference")
                            ]),
                            "button": .object([
                                "type": .string("string"),
                                "enum": .array([.string("left"), .string("right"), .string("center")]),
                                "default": .string("left")
                            ]),
                            "click_count": .object([
                                "type": .string("integer"),
                                "minimum": .int(1),
                                "default": .int(1)
                            ]),
                            "screen_id": .object([
                                "type": .string("integer"),
                                "description": .string("Display ID for screen coordinate space")
                            ])
                        ]),
                        "required": .array([.string("window_handle"), .string("x"), .string("y")])
                    ])
                ),
                Tool(
                    name: "type_text",
                    description: "Type text into the focused element",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "window_handle": .object([
                                "type": .string("string"),
                                "description": .string("Target window handle")
                            ]),
                            "text": .object([
                                "type": .string("string"),
                                "description": .string("Text to type")
                            ])
                        ]),
                        "required": .array([.string("window_handle"), .string("text")])
                    ])
                ),
                Tool(
                    name: "perform_gesture",
                    description: "Perform gesture on window (swipe, pinch, rotate)",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "window_handle": .object([
                                "type": .string("string"),
                                "description": .string("Target window handle")
                            ]),
                            "gesture_type": .object([
                                "type": .string("string"),
                                "enum": .array([.string("swipe"), .string("pinch"), .string("rotate"), .string("smart_magnify")])
                            ]),
                            "direction": .object([
                                "type": .string("string"),
                                "enum": .array([.string("left"), .string("right"), .string("up"), .string("down")])
                            ]),
                            "scale": .object([
                                "type": .string("number")
                            ]),
                            "angle_deg": .object([
                                "type": .string("number")
                            ]),
                            "distance_px": .object([
                                "type": .string("integer")
                            ]),
                            "duration_ms": .object([
                                "type": .string("integer"),
                                "default": .int(150)
                            ]),
                            "fingers": .object([
                                "type": .string("integer"),
                                "minimum": .int(1),
                                "maximum": .int(4),
                                "default": .int(2)
                            ])
                        ]),
                        "required": .array([.string("window_handle"), .string("gesture_type")])
                    ])
                ),
                Tool(
                    name: "wait",
                    description: "Wait for specified condition or duration",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "condition": .object([
                                "type": .string("string"),
                                "enum": .array([.string("time"), .string("ui_change"), .string("window_appear"), .string("window_disappear"), .string("gesture_complete")]),
                                "default": .string("time")
                            ]),
                            "duration_ms": .object([
                                "type": .string("integer"),
                                "minimum": .int(1),
                                "maximum": .int(30000),
                                "default": .int(1000)
                            ]),
                            "window_handle": .object([
                                "type": .string("string"),
                                "description": .string("Window to monitor for conditions")
                            ]),
                            "title_regex": .object([
                                "type": .string("string"),
                                "description": .string("Window title pattern for appear/disappear conditions")
                            ])
                        ]),
                        "required": .array([.string("duration_ms")])
                    ])
                )
            ])
        }
        
        // Call Tool
        await server.withMethodHandler(CallTool.self) { [weak self] request in
            guard let self = self else {
                throw MCPError.internalError("Server instance unavailable")
            }
            
            let toolName = request.name
            let arguments = request.arguments ?? [:]
            
            do {
                switch toolName {
                case "resolve_app":
                    let result = try await self.handleResolveApp(arguments: arguments)
                    return self.convertToCallResult(result: result)
                case "resolve_window":
                    let result = try await self.handleResolveWindow(arguments: arguments)
                    return self.convertToCallResult(result: result)
                case "mouse_click":
                    let result = try await self.handleMouseClick(arguments: arguments)
                    return self.convertToCallResult(result: result)
                case "type_text":
                    let result = try await self.handleTypeText(arguments: arguments)
                    return self.convertToCallResult(result: result)
                case "perform_gesture":
                    let result = try await self.handlePerformGesture(arguments: arguments)
                    return self.convertToCallResult(result: result)
                case "wait":
                    let result = try await self.handleWait(arguments: arguments)
                    return self.convertToCallResult(result: result)
                default:
                    return CallTool.Result(
                        content: [.text("Unknown tool: \(toolName)")],
                        isError: true
                    )
                }
            } catch let error as MCPError {
                return CallTool.Result(
                    content: [.text(error.description)],
                    isError: true
                )
            } catch {
                return CallTool.Result(
                    content: [.text("Unexpected error: \(error.localizedDescription)")],
                    isError: true
                )
            }
        }
    }
    
    // MARK: - Tool Handler Methods
    
    private func handleResolveApp(arguments: [String: Value]) async throws -> ResolveTools.ResolveAppResult {
        let args = convertToStringAny(arguments)
        return try await resolveTools.resolveApp(arguments: args)
    }
    
    private func handleResolveWindow(arguments: [String: Value]) async throws -> ResolveTools.ResolveWindowResult {
        let args = convertToStringAny(arguments)
        return try await resolveTools.resolveWindow(arguments: args)
    }
    
    private func handleMouseClick(arguments: [String: Value]) async throws -> ActionTools.ActionResult {
        let args = convertToStringAny(arguments)
        return try await actionTools.mouseClick(arguments: args)
    }
    
    private func handleTypeText(arguments: [String: Value]) async throws -> ActionTools.ActionResult {
        let args = convertToStringAny(arguments)
        return try await actionTools.typeText(arguments: args)
    }
    
    private func handlePerformGesture(arguments: [String: Value]) async throws -> ActionTools.ActionResult {
        let args = convertToStringAny(arguments)
        return try await actionTools.performGesture(arguments: args)
    }
    
    private func handleWait(arguments: [String: Value]) async throws -> WaitTool.WaitResult {
        let args = convertToStringAny(arguments)
        return try await waitTool.wait(arguments: args)
    }
    
    // MARK: - Public Interface
    
    public func start(transport: Transport) async throws {
        // Check permissions before starting
        try await checkPermissions()
        
        // Start cleanup task
        Task {
            await startCleanupTask()
        }
        
        print("🚀 AppMCP Server starting...")
        try await server.start(transport: transport)
    }
    
    public func stop() async {
        await server.stop()
    }
    
    // MARK: - Helper Methods
    
    private func checkPermissions() async throws {
        let permissions = await tccManager.getPermissionStatus()
        
        print("🔍 Permission Status:")
        print("   • Accessibility: \(permissions.accessibility)")
        print("   • Screen Recording: \(permissions.screenRecording)")
        
        if !permissions.accessibility {
            print("⚠️  Warning: Accessibility permission not granted. Some features may not work.")
            print("   Please grant access in System Settings > Privacy & Security > Accessibility")
        }
        
        if !permissions.screenRecording {
            print("⚠️  Warning: Screen Recording permission not granted. Screenshot features may not work.")
            print("   Please grant access in System Settings > Privacy & Security > Screen Recording")
        }
        
        if permissions.accessibility && permissions.screenRecording {
            print("✅ All permissions granted")
        }
    }
    
    private func startCleanupTask() async {
        while true {
            try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            await registry.cleanupExpiredHandles()
        }
    }
    
    private func convertToStringAny(_ value: [String: Value]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, val) in value {
            result[key] = valueToAny(val)
        }
        return result
    }
    
    private func valueToAny(_ value: Value) -> Any {
        switch value {
        case .null:
            return NSNull()
        case .bool(let bool):
            return bool
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .string(let string):
            return string
        case .data(_, let data):
            return data.base64EncodedString()
        case .array(let array):
            return array.map { valueToAny($0) }
        case .object(let object):
            var result: [String: Any] = [:]
            for (key, value) in object {
                result[key] = valueToAny(value)
            }
            return result
        }
    }
    
    private func convertToCallResult<T: Codable>(result: T) -> CallTool.Result {
        do {
            let data = try JSONEncoder().encode(result)
            let jsonString = String(data: data, encoding: .utf8) ?? "{}"
            return CallTool.Result(content: [.text(jsonString)])
        } catch {
            return CallTool.Result(
                content: [.text("Failed to encode result: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
}
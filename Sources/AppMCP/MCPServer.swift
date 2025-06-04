import Foundation
import MCP
@preconcurrency import ApplicationServices
import AppKit

/// The central coordinator for Model Context Protocol operations in AppMCP.
///
/// MCPServer serves as the main entry point for AppMCP functionality, implementing
/// the MCP v0.7.1 specification for macOS GUI automation. It coordinates between
/// resource providers (data extraction) and tool executors (action execution),
/// while managing permissions, application discovery, and MCP protocol communication.
///
/// The server handles JSON-RPC communication with MCP clients (typically AI models)
/// and routes requests to appropriate handlers based on the MCP protocol specification.
///
/// ## Topics
///
/// ### Creating a Server
/// - ``init()``
/// - ``init(resources:tools:)``
/// - ``weatherAppPoC()``
///
/// ### Server Lifecycle
/// - ``start()``
/// - ``stop()``
/// - ``waitUntilCompleted()``
///
/// ### Configuration and Validation
/// - ``validateConfiguration()``
/// - ``getResourceInfo()``
/// - ``getToolInfo()``
///
/// ### Usage
///
/// ```swift
/// // Create server with default configuration
/// let server = MCPServer()
///
/// // Validate configuration
/// try await server.validateConfiguration()
///
/// // Start the server
/// try await server.start()
/// ```
///
/// ### Weather App Example
///
/// ```swift
/// // Create server optimized for Weather app automation
/// let server = MCPServer.weatherAppPoC()
/// try await server.start()
/// ```
public final class MCPServer: @unchecked Sendable {
    
    private let server: MCP.Server
    private let resources: [any MCPResourceProvider]
    private let tools: [any MCPToolExecutor]
    private let appSelector: AppSelector
    private let tccManager: TCCManager
    
    public init() {
        self.appSelector = AppSelector()
        self.tccManager = TCCManager()
        
        // Initialize resources
        self.resources = [
            RunningAppsProvider(appSelector: appSelector),
            AppScreenshotProvider(appSelector: appSelector, tccManager: tccManager),
            AppAXTreeProvider(appSelector: appSelector, tccManager: tccManager)
        ]
        
        // Initialize tools
        self.tools = [
            MouseClickTool(appSelector: appSelector, tccManager: tccManager),
            KeyboardTool(appSelector: appSelector, tccManager: tccManager),
            WaitTool()
        ]
        
        // Create MCP server
        self.server = MCP.Server(
            name: "AppMCP",
            version: "0.1.0",
            capabilities: .init(
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            ),
            configuration: .default
        )
        
        Task { await setupHandlers() }
    }
    
    public init(resources: [any MCPResourceProvider], tools: [any MCPToolExecutor]) {
        self.appSelector = AppSelector()
        self.tccManager = TCCManager()
        self.resources = resources
        self.tools = tools
        
        self.server = MCP.Server(
            name: "AppMCP",
            version: "0.1.0",
            capabilities: .init(
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            )
        )
        
        Task { await setupHandlers() }
    }
    
    private func setupHandlers() async {
        // Set up tools handlers
        await server.withMethodHandler(ListTools.self) { _ in
            let toolDescriptions = self.tools.map { tool in
                MCP.Tool(
                    name: tool.name,
                    description: self.getToolDescription(tool.name)
                )
            }
            return ListTools.Result(tools: toolDescriptions)
        }
        
        await server.withMethodHandler(CallTool.self) { params in
            guard let tool = self.tools.first(where: { $0.name == params.name }) else {
                return CallTool.Result(
                    content: [.text("Unknown tool: \(params.name)")],
                    isError: true
                )
            }
            
            do {
                let arguments = params.arguments ?? [:]
                let result = try await tool.handle(params: MCP.Value.object(arguments))
                let jsonString = self.valueToJsonString(result)
                return CallTool.Result(content: [.text(jsonString)])
            } catch {
                return CallTool.Result(
                    content: [.text("Tool error: \(error.localizedDescription)")],
                    isError: true
                )
            }
        }
        
        // Set up resources handlers
        await server.withMethodHandler(ListResources.self) { _ in
            let resourceDescriptions = self.resources.map { resource in
                MCP.Resource(
                    name: resource.name,
                    uri: "app://\(resource.name)",
                    description: self.getResourceDescription(resource.name),
                    mimeType: "application/json"
                )
            }
            return ListResources.Result(resources: resourceDescriptions)
        }
        
        await server.withMethodHandler(ReadResource.self) { params in
            print("🔍 ReadResource handler called with URI: \(params.uri)")
            let resourceName = String(params.uri.dropFirst(6)) // Remove "app://" prefix
            print("🔍 Extracted resource name: '\(resourceName)'")
            guard let resource = self.resources.first(where: { $0.name == resourceName }) else {
                print("❌ Resource '\(resourceName)' not found in: \(self.resources.map { $0.name })")
                throw MCPError.invalidParameters("Unknown resource: \(resourceName)")
            }
            print("✅ Found resource: \(resource.name)")
            
            do {
                // For now, hardcode Weather app parameters for testing
                var resourceParams: [String: MCP.Value] = [:]
                if resourceName == "app_screenshot" {
                    resourceParams["bundle_id"] = .string("com.apple.weather")
                } else if resourceName == "app_accessibility_tree" {
                    resourceParams["bundle_id"] = .string("com.apple.weather")
                }
                
                print("🔍 MCPServer calling resource '\(resourceName)' with params: \(resourceParams)")
                let result = try await resource.handle(params: .object(resourceParams))
                let jsonString = self.valueToJsonString(result)
                return ReadResource.Result(contents: [
                    .text(jsonString, uri: params.uri, mimeType: "application/json")
                ])
            } catch {
                throw MCPError.systemError("Resource error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Start the MCP server with STDIO transport
    public func start() async throws {
        // Check permissions before starting
        await checkInitialPermissions()
        
        let transport = StdioTransport()
        try await server.start(transport: transport)
        
        // Keep the server running indefinitely
        await server.waitUntilCompleted()
    }
    
    /// Stop the server
    public func stop() async {
        await server.stop()
    }
    
    /// Wait until the server completes
    public func waitUntilCompleted() async {
        await server.waitUntilCompleted()
    }
    
    /// Check initial permissions and provide guidance if needed
    @MainActor
    private func checkInitialPermissions() async {
        let permissionStatus = await tccManager.getPermissionStatus()
        
        print("🔍 Permission Debug Info:")
        print("   • Accessibility: \(permissionStatus["accessibility"]?.description ?? "unknown")")
        print("   • Screen Recording: \(permissionStatus["screenRecording"]?.description ?? "unknown")")
        
        var missingPermissions: [String] = []
        
        if permissionStatus["accessibility"] != .granted {
            missingPermissions.append("Accessibility")
        }
        
        if permissionStatus["screenRecording"] != .granted {
            missingPermissions.append("Screen Recording")
        }
        
        if !missingPermissions.isEmpty {
            print("⚠️  AppMCP requires the following permissions:")
            for permission in missingPermissions {
                print("   • \(permission)")
            }
            print("\nPlease grant these permissions in System Preferences > Privacy & Security")
            print("The server will continue to run, but some features may not work until permissions are granted.\n")
        } else {
            print("✅ All required permissions are granted")
        }
    }
    
    /// Get tool description based on tool name
    private func getToolDescription(_ name: String) -> String {
        switch name {
        case "mouse_click":
            return "Click at specified screen coordinates"
        case "type_text":
            return "Type text using keyboard input"
        case "wait":
            return "Wait for a specified duration or condition"
        default:
            return "Unknown tool"
        }
    }
    
    /// Get tool input schema based on tool name
    private func getToolInputSchema(_ name: String) -> [String: Any] {
        switch name {
        case "mouse_click":
            return [
                "type": "object",
                "properties": [
                    "x": ["type": "number", "description": "X coordinate"],
                    "y": ["type": "number", "description": "Y coordinate"],
                    "button": ["type": "string", "description": "Mouse button (left, right, center)"],
                    "click_count": ["type": "integer", "description": "Number of clicks"]
                ],
                "required": ["x", "y"]
            ]
        case "type_text":
            return [
                "type": "object",
                "properties": [
                    "text": ["type": "string", "description": "Text to type"],
                    "target_app": [
                        "type": "object",
                        "properties": [
                            "bundle_id": ["type": "string", "description": "Bundle ID of target app"],
                            "process_name": ["type": "string", "description": "Process name of target app"]
                        ]
                    ]
                ],
                "required": ["text"]
            ]
        case "wait":
            return [
                "type": "object",
                "properties": [
                    "duration_ms": ["type": "integer", "description": "Duration in milliseconds"],
                    "condition": ["type": "string", "description": "Wait condition (time, ui_change)"]
                ]
            ]
        default:
            return ["type": "object", "properties": [:]]
        }
    }
    
    /// Get resource description based on resource name
    private func getResourceDescription(_ name: String) -> String {
        switch name {
        case "running_applications":
            return "List of currently running applications"
        case "app_screenshot":
            return "Screenshot of specified application"
        case "app_accessibility_tree":
            return "Accessibility tree of specified application"
        default:
            return "Unknown resource"
        }
    }
    
    /// Convert MCP.Value to JSON string
    private func valueToJsonString(_ value: MCP.Value) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: valueToAny(value))
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to serialize value\"}"
        }
    }
    
    /// Convert MCP.Value to Any for JSON serialization
    private func valueToAny(_ value: MCP.Value) -> Any {
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
    
    /// Get information about available resources
    public func getResourceInfo() -> [String: String] {
        var info: [String: String] = [:]
        for resource in resources {
            info[resource.name] = String(describing: type(of: resource))
        }
        return info
    }
    
    /// Get information about available tools
    public func getToolInfo() -> [String: String] {
        var info: [String: String] = [:]
        for tool in tools {
            info[tool.name] = String(describing: type(of: tool))
        }
        return info
    }
}

// MARK: - Server Extensions

extension MCPServer {
    
    /// Create a server with default configuration for weather app PoC
    public static func weatherAppPoC() -> MCPServer {
        return MCPServer()
    }
    
    /// Validate that all required components are available
    public func validateConfiguration() async throws {
        // Check that we have the minimum required resources
        let requiredResources = ["running_applications", "app_screenshot", "app_accessibility_tree"]
        let availableResources = Set(resources.map { $0.name })
        
        for required in requiredResources {
            guard availableResources.contains(required) else {
                throw MCPError.systemError("Missing required resource: \(required)")
            }
        }
        
        // Check that we have the minimum required tools
        let requiredTools = ["mouse_click", "type_text", "wait"]
        let availableTools = Set(tools.map { $0.name })
        
        for required in requiredTools {
            guard availableTools.contains(required) else {
                throw MCPError.systemError("Missing required tool: \(required)")
            }
        }
        
        print("✅ Server configuration validated successfully")
    }
}
# Architecture

Understand the design principles and component architecture of AppMCP.

## Overview

AppMCP is built on a modular, protocol-based architecture that separates data collection (resources) from action execution (tools). This design enables flexible composition of automation capabilities while maintaining clean separation of concerns.

## Core Design Principles

### Protocol-Based Design

AppMCP uses Swift protocols to define clear contracts between components:

- **MCPResourceProvider**: Defines the interface for components that provide data
- **MCPToolExecutor**: Defines the interface for components that perform actions
- **Sendable Conformance**: All protocols conform to `Sendable` for safe concurrency

### Actor-Based Concurrency

Key components use Swift's actor model to ensure thread safety:

- **AppSelector**: Actor-based application discovery and management
- **Async/Await**: All operations use modern Swift concurrency patterns

### Transport Agnostic

The MCP server supports multiple transport mechanisms:

- **STDIO Transport**: For command-line integration
- **HTTP+SSE Transport**: For web-based clients
- **Extensible**: Easy to add new transport types

## Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        MCP Client                           │
│                    (AI Model/Agent)                         │
└─────────────────────┬───────────────────────────────────────┘
                      │ JSON-RPC over Transport
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                     MCPServer                               │
│  ┌─────────────────┐ ┌─────────────────┐ ┌───────────────┐ │
│  │   Resources     │ │     Tools       │ │   AppSelector │ │
│  │   Registry      │ │    Registry     │ │               │ │
│  └─────────────────┘ └─────────────────┘ └───────────────┘ │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   macOS APIs                                │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │ Accessibility│ │ AppKit/Cocoa │ │ Core Graphics        │ │
│  │     APIs     │ │     APIs     │ │       APIs           │ │
│  └──────────────┘ └──────────────┘ └──────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### MCPServer

The central coordinator that:
- Manages resource providers and tool executors
- Handles MCP protocol communication
- Routes requests to appropriate handlers
- Manages server lifecycle and configuration

```swift
public final class MCPServer: @unchecked Sendable {
    private let server: MCP.Server
    private let resources: [any MCPResourceProvider]
    private let tools: [any MCPToolExecutor]
    private let appSelector: AppSelector
    private let tccManager: TCCManager
}
```

### AppSelector

An actor responsible for application discovery and management:
- Finds applications by Bundle ID, process name, or PID
- Provides thread-safe access to running application information
- Converts between different application identification methods

```swift
public actor AppSelector: @unchecked Sendable {
    func findApp(bundleId: String) async throws -> AXUIElement?
    func findApp(processName: String) async throws -> AXUIElement?
    func findApp(pid: pid_t) async throws -> AXUIElement?
    func listRunningApps() async -> [AppInfo]
}
```

### Resource Providers

Components that extract data from the system:

#### RunningAppsProvider
- Lists all currently running applications
- Provides Bundle ID, process name, PID, and active status
- No special permissions required

#### AppScreenshotProvider
- Captures PNG screenshots of specified applications
- Requires Screen Recording permission
- Returns base64-encoded image data

#### AppAXTreeProvider
- Extracts accessibility tree structure as JSON
- Requires Accessibility permission
- Provides UI element hierarchy and properties

### Tool Executors

Components that perform automation actions:

#### MouseClickTool
- Performs mouse clicks at specified coordinates
- Supports left, right, and center mouse buttons
- Configurable click count for double/triple clicks

#### KeyboardTool
- Types text using keyboard input simulation
- Supports special keys and modifiers
- Can target specific applications

#### WaitTool
- Provides time-based delays
- Supports condition-based waiting
- Useful for UI state synchronization

## Permission Management

### TCCManager

Handles macOS Transparency, Consent, and Control (TCC) permissions:

- **Accessibility Permission**: Required for UI element inspection and automation
- **Screen Recording Permission**: Required for capturing application screenshots
- **Permission Checking**: Validates current permission status
- **User Guidance**: Provides clear instructions for granting permissions

```swift
public final class TCCManager: @unchecked Sendable {
    func getPermissionStatus() async -> [String: PermissionStatus]
    func checkAccessibilityPermission() async -> PermissionStatus
    func checkScreenRecordingPermission() async -> PermissionStatus
}
```

## Model Context Protocol Integration

### MCP Protocol Implementation

AppMCP implements MCP v0.7.1 specification:

- **JSON-RPC Communication**: All messages use JSON-RPC 2.0 format
- **Resource Discovery**: Dynamic listing of available data sources
- **Tool Execution**: Structured action invocation with parameters
- **Error Handling**: Standardized error responses and recovery

### Message Flow

1. **Client Request**: AI model sends JSON-RPC request
2. **Server Routing**: MCPServer routes to appropriate handler
3. **Permission Check**: TCCManager validates required permissions
4. **Action Execution**: Resource provider or tool executor processes request
5. **Response**: JSON-formatted result returned to client

### Transport Abstraction

```swift
// STDIO Transport (default)
let transport = StdioTransport()
try await server.start(transport: transport)

// HTTP+SSE Transport (future)
let httpTransport = HTTPTransport(port: 8080)
try await server.start(transport: httpTransport)
```

## Error Handling

### Standardized Error Types

```swift
public enum MCPError: Swift.Error, Sendable {
    case permissionDenied(String)
    case systemError(String)
    case invalidParameters(String)
    case resourceUnavailable(String)
    case appNotFound(String)
    case timeout(String)
}
```

### Error Recovery

- **Permission Errors**: Provide clear guidance for granting permissions
- **App Not Found**: Suggest alternative identification methods
- **System Errors**: Include detailed diagnostic information
- **Graceful Degradation**: Continue operation when possible

## Performance Considerations

### Asynchronous Design

- All operations use `async/await` for non-blocking execution
- Resource-intensive operations (screenshots, accessibility trees) run on background queues
- Concurrent request handling for multiple clients

### Memory Management

- Automatic reference counting with `@unchecked Sendable` where needed
- Base64 encoding for binary data transmission
- Efficient JSON serialization/deserialization

### Caching Strategy

- No persistent caching to ensure real-time data accuracy
- In-memory caching for application discovery results
- Screenshot capture on-demand to minimize memory usage

## Extensibility

### Adding New Resource Providers

```swift
struct CustomResourceProvider: MCPResourceProvider {
    var name: String { "custom_resource" }
    
    func handle(params: MCP.Value) async throws -> MCP.Value {
        // Implementation
    }
}
```

### Adding New Tool Executors

```swift
struct CustomToolExecutor: MCPToolExecutor {
    var name: String { "custom_tool" }
    
    func handle(params: MCP.Value) async throws -> MCP.Value {
        // Implementation
    }
}
```

### Configuration Flexibility

```swift
// Custom server configuration
let server = MCPServer(
    resources: [CustomResourceProvider()],
    tools: [CustomToolExecutor()]
)
```

## Security Considerations

### Permission Model

- Principle of least privilege
- Explicit permission requests
- Runtime permission validation
- User consent requirements

### Data Handling

- No persistent storage of sensitive data
- Secure transmission of screenshot data
- Sanitized error messages to prevent information leakage

### Access Control

- Bundle ID-based application targeting
- Process isolation through macOS APIs
- Controlled UI automation scope
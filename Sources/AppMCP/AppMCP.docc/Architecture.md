# Architecture

Understand the design principles and component architecture of AppMCP.

## Overview

AppMCP is built on a layered architecture that cleanly separates MCP protocol handling from macOS automation. The framework follows the Model Context Protocol (MCP) v0.7.1 specification, providing Resources for read-only data access and Tools for state-mutating actions.

## Core Design Principles

### Resource vs Tool Separation

AppMCP strictly separates read-only data access from state-mutating operations:

- **Resources**: URI-based read-only access to system state (applications, windows, UI snapshots)
- **Tools**: Action-based operations that modify state (clicks, text input, keyboard shortcuts)

This separation enables:
- Clear API contracts for AI models
- Safe exploration of UI state without side effects
- Efficient workflows (capture once, operate multiple times)

### ElementID-Based Operations

All UI automation follows an ElementID-based workflow:

1. **Capture**: Use Resources to capture UI state with unique element IDs
2. **Identify**: AI analyzes screenshots and element data to find targets
3. **Act**: Use Tools with element IDs for reliable operations
4. **Reuse**: Same element IDs valid for multiple operations without re-capture

### Fail-Fast Philosophy

AppMCP uses explicit error propagation without fallback mechanisms:

- **No Silent Failures**: All errors propagate up the call stack
- **Clear Error Messages**: Every error provides actionable information
- **Type-Safe Parameters**: Swift type system prevents runtime errors
- **Validated Inputs**: Parameter validation at API boundaries only

### Async/Await Throughout

All operations use modern Swift concurrency:

- Non-blocking I/O with async/await
- Actor-based metrics tracking for thread safety
- Sendable types for safe concurrency
- No callbacks or completion handlers

## Component Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    AI Model/Agent                        │
│                    (MCP Client)                          │
└────────────────────┬─────────────────────────────────────┘
                     │ JSON-RPC over STDIO
                     │
┌────────────────────▼─────────────────────────────────────┐
│                  AppMCPServer                            │
│  ┌──────────────────────────────────────────────────┐   │
│  │           MCP SDK v0.7.1                         │   │
│  │  ┌─────────────────┐  ┌─────────────────┐      │   │
│  │  │   Resources     │  │     Tools       │      │   │
│  │  │   (4 URIs)      │  │   (6 Actions)   │      │   │
│  │  └─────────────────┘  └─────────────────┘      │   │
│  └──────────────────────────────────────────────────┘   │
└────────────────────┬─────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────┐
│                   AppPilot                               │
│  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │
│  │Accessibility │ │  CGEvent     │ │ Screen Capture │  │
│  │   Driver     │ │   Driver     │ │    Driver      │  │
│  └──────────────┘ └──────────────┘ └────────────────┘  │
└────────────────────┬─────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────┐
│                   macOS APIs                             │
│  AXUIElement • CGEvent • ScreenCaptureKit • NSWorkspace  │
└──────────────────────────────────────────────────────────┘
```

## Core Components

### AppMCPServer

The main MCP server that:
- Implements MCP protocol v0.7.1 specification
- Registers 4 Resources and 6 Tools with MCP SDK
- Handles JSON-RPC communication over STDIO transport
- Routes requests to AppPilot for actual automation
- Tracks performance metrics with MetricsTracker actor

**Implementation**:
```swift
public final class AppMCPServer: @unchecked Sendable {
    private let server: MCP.Server
    private let pilot: AppPilot
    private let metricsTracker: MetricsTracker

    init() async throws {
        pilot = AppPilot()
        metricsTracker = MetricsTracker()

        server = MCP.Server(
            name: "AppMCP",
            version: "1.0.0"
        )

        // Register 4 Resources
        server.addResource(...)

        // Register 6 Tools
        server.addTool(...)
    }
}
```

### AppPilot Integration

AppPilot is the core automation framework that provides:

**Element-Based Automation**:
- UI element discovery via Accessibility API
- Role-based element filtering (buttons, text fields, etc.)
- Title and identifier-based element search

**Driver Architecture**:
- `AccessibilityDriver`: Element discovery and tree traversal
- `CGEventDriver`: Low-level mouse and keyboard events
- `ScreenDriver`: Screenshot capture with permission management

**Window Context Management**:
- Application resolution by Bundle ID or name
- Window resolution by title or index
- Automatic focus management
- Coordinate validation within window bounds

### MetricsTracker Actor

Thread-safe performance tracking:
```swift
private actor MetricsTracker {
    private var totalToolCalls: Int = 0
    private var totalExecutionTime: TimeInterval = 0

    func recordToolCall(duration: TimeInterval) async {
        totalToolCalls += 1
        totalExecutionTime += duration
    }
}
```

## MCP Resources (Read-Only Data)

### `running_applications`
**URI**: `appmcp://resources/running_applications`

Returns JSON array of all running applications:
```json
{
  "name": "Weather",
  "bundleID": "com.apple.weather",
  "processID": 12345,
  "isActive": true
}
```

### `application_windows`
**URI**: `appmcp://resources/application_windows`

Returns JSON array of all windows across all applications:
```json
{
  "application": "Weather",
  "title": "Weather",
  "bounds": {"x": 100, "y": 100, "width": 800, "height": 600},
  "isVisible": true
}
```

### `ui_snapshot`
**URI**: `appmcp://ui/snapshot/{bundleID}`

Captures screenshot + element hierarchy:
```json
{
  "screenshot": "iVBORw0KGgoAAAANS...",
  "elements": [
    {
      "id": "elem_123",
      "role": "button",
      "title": "Search",
      "bounds": {"x": 10, "y": 20, "width": 100, "height": 40}
    }
  ]
}
```

### `ui_elements`
**URI**: `appmcp://ui/elements/{bundleID}`

Returns element hierarchy without screenshot (faster):
```json
[
  {
    "id": "elem_123",
    "role": "textfield",
    "title": "Search",
    "bounds": {...}
  }
]
```

## MCP Tools (State-Mutating Actions)

### `click_element`
Click UI elements by ID:
```json
{
  "elementId": "elem_123",
  "button": "left",
  "clickCount": 1
}
```

### `input_text`
Input text into elements:
```json
{
  "elementId": "elem_456",
  "text": "Tokyo",
  "method": "setValue"
}
```

### `drag_drop`
Drag between elements:
```json
{
  "fromElementId": "elem_100",
  "toElementId": "elem_200",
  "duration": 0.5
}
```

### `scroll_window`
Scroll at element location:
```json
{
  "elementId": "elem_300",
  "deltaX": 0,
  "deltaY": -100
}
```

### `keyboard_input`
Execute keyboard shortcuts:
```json
{
  "keys": ["a"],
  "modifiers": ["command"]
}
```

### `wait_time`
Time-based wait:
```json
{
  "duration": 2.0
}
```

## Parameter Validation

### Type-Safe Extraction

All tool parameters are validated using type-safe extraction methods:

```swift
private func extractRequiredString(from arguments: [String: MCP.Value], key: String) throws -> String {
    guard let value = arguments[key] else {
        throw AppMCPError.missingParameter(key)
    }

    guard case .string(let str) = value else {
        throw AppMCPError.invalidParameterType(key, expected: "string", got: "\(value)")
    }

    return str
}
```

### Validation Rules

1. **Validate at API entry points** (tool handlers)
2. **Use type-safe extraction** with explicit error types
3. **Validate business logic constraints** (e.g., duration limits)
4. **Propagate AppPilot errors** without modification
5. **Never assume default values** unless documented

## Error Handling

### AppMCPError Enum

```swift
public enum AppMCPError: Swift.Error, Sendable {
    case permissionDenied(String)
    case applicationNotFound(String)
    case windowNotFound(String)
    case elementNotFound(String)
    case invalidParameters(String)
    case automationFailed(String)
}
```

### Error Conversion

AppPilot errors are converted to AppMCPError with specific patterns:
```swift
private func convertPilotError(_ error: Error) -> AppMCPError {
    let errorString = error.localizedDescription.lowercased()

    // Order from specific to general to avoid incorrect matches
    if errorString.contains("window not found") {
        return .windowNotFound(error.localizedDescription)
    }

    if errorString.contains("element not found") {
        return .elementNotFound(error.localizedDescription)
    }

    return .automationFailed(error.localizedDescription)
}
```

## Permission Management

### Required Permissions

1. **Accessibility**: Required for UI element discovery and interaction
2. **Screen Recording**: Required for screenshot capture

### Permission Flow

1. User launches AppMCP
2. AppMCPServer attempts operation
3. macOS displays permission prompt if not granted
4. User grants permission in System Settings
5. Operation retries automatically

**Note**: AppMCP does not include explicit permission checking code. Permissions are requested automatically by macOS when attempting protected operations.

## Performance Considerations

### Async Design

- All operations use `async/await` for non-blocking execution
- Resource-intensive operations run asynchronously
- No thread blocking in main server loop

### Memory Management

- Screenshots encoded as base64 for JSON transport
- Maximum snapshot dimension: 240px (configurable)
- JPEG compression at 20% quality for efficiency
- No persistent caching of UI state

### Constants

All magic numbers extracted to Constants enum:
```swift
private enum Constants {
    static let maxWaitDuration: TimeInterval = 60.0
    static let defaultKeyDelay: TimeInterval = 0.05
    static let maxSnapshotDimension: Int = 240
    static let snapshotJPEGQuality: CGFloat = 0.2
    static let maxResponseSize: Int = 50_000
}
```

## Security Considerations

### Bundle ID Validation

All operations require explicit Bundle ID targeting:
- Prevents accidental automation of wrong applications
- Enables permission-based access control
- Provides audit trail for automation actions

### Element ID Verification

Element IDs include validation:
- IDs generated during snapshot capture
- Elements verified accessible before operations
- Invalid IDs result in clear error messages

### No Credential Storage

- No passwords or tokens stored
- No persistent state maintained
- All data transient in memory only

## Extensibility

AppMCP's architecture allows future extensions:

### Additional Resources

New resource URIs can be added:
```swift
server.addResource(
    uri: "appmcp://custom/data",
    handler: { uri in
        // Custom data extraction
    }
)
```

### Additional Tools

New tools can be registered:
```swift
server.addTool(
    name: "custom_action",
    handler: { arguments in
        // Custom automation action
    }
)
```

### Transport Options

While currently STDIO-only, MCP SDK supports:
- HTTP + Server-Sent Events
- WebSocket
- Custom transports

## Testing Strategy

### Swift Testing Framework

All tests use Swift Testing (built-in to Swift 6.1+):
- `@Test` for test functions
- `@Suite` for test groups
- `#expect()` for non-fatal assertions
- `#require()` for fatal assertions

### Test Categories

1. **Unit Tests**: Parameter validation, error conversion
2. **Integration Tests**: End-to-end Resource and Tool operations
3. **Performance Tests**: Metrics tracking and response times

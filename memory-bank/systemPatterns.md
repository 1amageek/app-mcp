# System Patterns & Architecture

## Overall Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   MCP Client    │◄──►│   AppMCP Server  │◄──►│   macOS System  │
│ (ChatGPT/Claude)│    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────┐
                       │ Swift Package│
                       │   Library    │
                       └──────────────┘
```

## Core Design Patterns

### 1. Protocol-Oriented Architecture
```swift
// Resource Provider Pattern
public protocol MCPResourceProvider: Sendable {
    var name: String { get }
    func handle(request: MCP.Request) async throws -> MCP.JSON
}

// Tool Executor Pattern  
public protocol MCPToolExecutor: Sendable {
    var name: String { get }
    func handle(request: MCP.Request) async throws -> MCP.JSON
}
```

**Benefits:**
- Clean separation of concerns
- Easy to test and mock
- Extensible for future resource/tool types
- Type-safe with Swift's protocol system

### 2. Dependency Injection Pattern
```swift
public final class MCPServer {
    private let resources: [any MCPResourceProvider]
    private let tools: [any MCPToolExecutor]
    
    public init(resources: [any MCPResourceProvider],
                tools: [any MCPToolExecutor]) {
        self.resources = resources
        self.tools = tools
    }
}
```

**Benefits:**
- Testable (inject mocks)
- Configurable (different resource/tool combinations)
- Follows SOLID principles
- Clear dependencies

### 3. Actor-Based Concurrency
```swift
@MainActor
final class ScreenshotProvider: MCPResourceProvider {
    // UI operations must be on main thread
}

actor PermissionManager {
    // Thread-safe permission state management
}
```

**Benefits:**
- Thread-safe by design
- Prevents data races
- Leverages Swift 6 concurrency
- Clear isolation boundaries

## Component Relationships

### Core Components
```
MCPServer
├── Resources/
│   ├── ScreenshotProvider (MainActor)
│   └── AXTreeProvider (MainActor)
├── Tools/
│   ├── MouseTool (MainActor)
│   └── KeyboardTool (MainActor)
├── Permissions/
│   └── TCCManager (Actor)
└── Logging/
    └── Logger (Sendable)
```

### Data Flow Patterns

#### Resource Request Flow
```
1. MCP Client → JSON-RPC Request
2. MCPServer → Route to ResourceProvider
3. ResourceProvider → Capture/Generate Data
4. ResourceProvider → Return MCP.JSON
5. MCPServer → JSON-RPC Response
```

#### Tool Execution Flow
```
1. MCP Client → Tool Request with Parameters
2. MCPServer → Validate Permissions
3. MCPServer → Route to ToolExecutor
4. ToolExecutor → Execute System Action
5. ToolExecutor → Return Result/Status
6. MCPServer → JSON-RPC Response
```

## Error Handling Strategy

### Error Types Hierarchy
```swift
public enum MCPError: Error, Sendable {
    case permissionDenied(String)
    case systemError(String)
    case invalidParameters(String)
    case resourceUnavailable(String)
}
```

### Error Propagation Pattern
- **Immediate Validation**: Check permissions before execution
- **Graceful Degradation**: Return partial results when possible
- **Clear Messages**: Human-readable error descriptions
- **Structured Logging**: All errors logged with context

## Security Patterns

### Permission-First Design
```swift
// Every operation checks permissions first
func handle(request: MCP.Request) async throws -> MCP.JSON {
    try await permissionManager.checkScreenRecording()
    // ... actual implementation
}
```

### Principle of Least Privilege
- Request only necessary permissions
- Scope permissions to specific operations
- Clear permission boundaries
- User consent for each permission type

## Performance Patterns

### Lazy Loading
```swift
// Screenshot only captured when requested
lazy var screenshotProvider = ScreenshotProvider()
```

### Caching Strategy
- Screenshot caching with TTL
- Accessibility tree caching
- Permission status caching
- Invalidation on system changes

### Resource Management
- Automatic cleanup of temporary files
- Memory-efficient image handling
- Connection pooling for HTTP transport
- Graceful shutdown procedures

## Testing Patterns

### Mock-Based Testing
```swift
struct MockScreenshotProvider: MCPResourceProvider {
    func handle(request: MCP.Request) async throws -> MCP.JSON {
        // Return test data
    }
}
```

### Integration Testing
- Process-based testing for CLI binary
- Real system interaction in controlled environment
- Permission state simulation
- Transport layer testing

## Extensibility Patterns

### Plugin Architecture (Future)
```swift
protocol MCPPlugin {
    var resources: [MCPResourceProvider] { get }
    var tools: [MCPToolExecutor] { get }
}
```

### Configuration-Driven Behavior
- JSON-based tool whitelisting
- Runtime feature toggles
- Environment-specific settings
- User preference integration

## Key Architectural Decisions

### 1. Swift-First Design
- **Decision**: Use Swift 6 with modern concurrency
- **Rationale**: Type safety, performance, macOS integration
- **Trade-offs**: Platform-specific, learning curve

### 2. MCP Protocol Compliance
- **Decision**: Strict adherence to MCP specification
- **Rationale**: Interoperability with any MCP client
- **Trade-offs**: Less flexibility for custom extensions

### 3. Permission-Gated Access
- **Decision**: All system access requires explicit permissions
- **Rationale**: Security, user trust, App Store compliance
- **Trade-offs**: Setup complexity, user friction

### 4. Library + Binary Distribution
- **Decision**: Provide both reusable library and standalone binary
- **Rationale**: Maximum flexibility for different use cases
- **Trade-offs**: Increased maintenance burden

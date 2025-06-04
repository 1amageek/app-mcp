# Active Context

## Current Project State
**Status**: PoC planning phase - Weather app automation target defined
**Last Updated**: 2025-06-04
**Active Work**: Implementing Phase 1 PoC for weather app automation

## Current Implementation Status

### ✅ Completed
- Basic Swift Package structure created
- Package.swift configured with MCP dependency
- Memory bank documentation system established
- Project architecture and patterns documented

### 🔄 In Progress
- Core library implementation (not started)
- MCP server implementation (not started)
- Resource providers implementation (not started)
- Tool executors implementation (not started)

### ❌ Not Started
- Screenshot capture functionality
- Accessibility tree parsing
- Mouse/keyboard automation
- Permission management system
- CLI binary implementation
- Test suite development

## Current File Structure Analysis

### Existing Files
```
AppMCP/
├── Package.swift ✅ (Basic structure, needs executable target)
├── Sources/AppMCP/AppMCP.swift ✅ (Placeholder file)
├── Tests/AppMCPTests/AppMCPTests.swift ✅ (Placeholder test)
└── memory-bank/ ✅ (Complete documentation)
```

### Missing Critical Files
```
Sources/AppMCP/
├── MCPServer.swift ❌
├── Resources/
│   ├── ScreenshotProvider.swift ❌
│   └── AXTreeProvider.swift ❌
├── Tools/
│   ├── MouseTool.swift ❌
│   └── KeyboardTool.swift ❌
├── Permissions/
│   └── TCCManager.swift ❌
└── Logging/
    └── Logger.swift ❌

Sources/appmcpd/
└── main.swift ❌
```

## PoC Target: Weather App Automation

### Specific Goal
Demonstrate AI-driven automation by retrieving weather forecasts from macOS Weather app for arbitrary locations using Bundle ID-based app targeting.

### Target Workflow
1. Identify Weather app (`com.apple.weather`) programmatically
2. Capture current app state via screenshot
3. Locate search field using accessibility tree
4. Click search field and input location (e.g., "Tokyo, Japan")
5. Select search result from dropdown
6. Extract weather information from displayed forecast

## Phase 1 PoC Implementation Plan

### Step 1: Foundation (1-2 days)
- Update Package.swift with executable target
- Define core protocols (MCPResourceProvider, MCPToolExecutor)
- Implement MCPError enum
- Create AppSelector for Bundle ID-based app targeting

### Step 2: Permission Management (1 day)
- Implement TCCManager for accessibility and screen recording permissions
- Basic permission checking and user guidance

### Step 3: Resource Providers (2-3 days)
- **RunningAppsProvider**: List all running applications with Bundle IDs
- **AppScreenshotProvider**: Capture screenshots of specified apps
- **AppAXTreeProvider**: Extract accessibility tree from specified apps

### Step 4: Tool Executors (2 days)
- **MouseClickTool**: Click at specified coordinates in target app
- **KeyboardTool**: Type text in target app (NEW - required for weather search)
- **WaitTool**: Simple wait functionality for UI state changes (NEW)

### Step 5: MCP Integration (1-2 days)
- MCPServer implementation with swift-sdk v0.7.1
- CLI binary (appmcpd) for running the server
- Transport layer integration (STDIO)

### Step 6: Weather App Validation (1-2 days)
- End-to-end testing with Weather app
- Validation of complete workflow from search to data extraction
- Performance and reliability testing

## Success Criteria for PoC

### Technical Success
- ✅ Weather app can be identified by Bundle ID (`com.apple.weather`)
- ✅ Search field can be located and clicked via accessibility tree
- ✅ Location text can be typed into search field
- ✅ Search results can be selected programmatically
- ✅ Weather information can be extracted from the display

### Concept Validation Success
- ✅ AI can fully automate weather forecast retrieval for any location
- ✅ No manual user intervention required during automation
- ✅ MCP protocol enables practical GUI automation workflows
- ✅ Bundle ID-based app targeting works reliably

## Current Challenges & Decisions Needed

### Technical Decisions
1. **MCP SDK Integration**: Need to understand swift-sdk v0.7.1 API patterns
2. **Permission Flow**: Design user experience for TCC permission requests
3. **Error Handling**: Standardize error responses across all components
4. **Testing Strategy**: Set up proper test infrastructure

### Implementation Questions
1. Should we use `@MainActor` for all UI-related operations?
2. How to handle permission state changes during runtime?
3. What's the optimal caching strategy for screenshots/AX trees?
4. How to structure the CLI argument parsing?

## Development Environment Status

### Current Setup
- macOS development environment ✅
- Swift 6.1 toolchain ✅
- Basic package structure ✅
- MCP dependency declared ✅

### Missing Setup
- Actual MCP SDK integration testing ❌
- Permission testing environment ❌
- CI/CD pipeline ❌
- Documentation generation ❌

## Key Insights from Specification

### Critical Requirements
1. **MCP Compliance**: Must strictly follow MCP protocol patterns
2. **Permission-First**: Every system operation must check TCC permissions
3. **Performance**: Screenshot capture < 100ms, total response < 300ms
4. **Security**: Sandboxed execution with audit logging

### Architecture Patterns
1. **Protocol-Oriented**: Use Swift protocols for extensibility
2. **Actor-Based**: Leverage Swift 6 concurrency for thread safety
3. **Dependency Injection**: Clean separation of concerns
4. **Error-First**: Comprehensive error handling strategy

## Focus Areas for Next Session

### High Priority
1. **Package.swift Updates**: Add executable target and proper configuration
2. **Core Protocols**: Define the foundational interfaces
3. **MCPServer Implementation**: Basic server structure with transport
4. **Permission System**: TCC management foundation

### Medium Priority
1. **Resource Providers**: Screenshot and accessibility implementations
2. **Tool Executors**: Mouse and keyboard automation
3. **Error Handling**: Comprehensive error types and propagation
4. **Logging System**: Structured logging with os_log

### Low Priority
1. **CLI Interface**: Command-line argument parsing
2. **Test Infrastructure**: Unit and integration test setup
3. **Documentation**: API documentation and examples
4. **CI/CD**: GitHub Actions workflow

## Notes for Future Sessions

### Important Reminders
- Always check permissions before system operations
- Use `@MainActor` for UI-related code
- Follow MCP protocol specifications exactly
- Maintain backward compatibility in public APIs

### Code Patterns to Follow
- Protocol-oriented design for extensibility
- Actor isolation for thread safety
- Async/await for all I/O operations
- Structured error handling with context

### Testing Approach
- Mock-based unit testing
- Process-based integration testing
- Real system testing in controlled environment
- Performance benchmarking for latency targets

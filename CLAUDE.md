# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build
```bash
# Debug build
swift build

# Release build
swift build -c release

# Clean build
swift build --clean
```

### Test
```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test target
swift test --filter AppMCPTests

# Run with coverage
swift test --enable-code-coverage
```

### Lint & Format
```bash
# Format Swift code (requires swift-format)
swift-format -i -r Sources/ Tests/

# Lint Swift code
swift-format lint -r Sources/ Tests/
```

### Package Management
```bash
# Update dependencies
swift package update

# Resolve dependencies
swift package resolve

# Show dependencies
swift package show-dependencies
```

## Architecture

### Project Structure
AppMCP is a Swift Package implementing Model Context Protocol (MCP) SDK v0.7.1 for macOS app automation. The package enables AI models to visually inspect, interpret, and control macOS applications through:

1. **Resource Providers**: Capture screen content and accessibility tree information
   - `ScreenshotProvider`: Returns base64-encoded PNG screenshots of active windows
   - `AXTreeProvider`: Provides accessibility tree structure as JSON

2. **Tool Executors**: Perform UI automation actions
   - `MouseTool`: Mouse movement and click operations
   - `KeyboardTool`: Text input and keyboard shortcuts

3. **Permission Management**: Handles macOS TCC (Transparency, Consent, and Control) permissions
   - `TCCManager`: Checks and guides users through accessibility and screen recording permissions

### Key Design Patterns
- **Protocol-based Architecture**: `MCPResourceProvider` and `MCPToolExecutor` protocols define the contract for extensions
- **MCP Transport Abstraction**: Supports both STDIO and HTTP+SSE transports through swift-sdk
- **Async/Await**: All resource and tool operations are async for non-blocking execution
- **JSON-RPC Communication**: Uses MCP's JSON-RPC protocol for client-server communication

### Planned Components (per specification)
- `MCPServer`: Main server class coordinating resources and tools
- `appmcpd`: CLI daemon executable for running the MCP server
- Endpoint registry using swift-sdk's DSL for defining available operations

### Dependencies
- `modelcontextprotocol/swift-sdk` >= 0.7.1: Core MCP protocol implementation
- macOS 15+: Required for latest accessibility and screen capture APIs
- Swift 6.1+: Language requirements

## Current Development Focus

### Weather App PoC (Phase 1)
**Target**: Demonstrate AI-driven automation by retrieving weather forecasts from macOS Weather app for arbitrary locations.

**Key Components for PoC**:
- `AppSelector`: Bundle ID-based app targeting (`com.apple.weather`)
- `RunningAppsProvider`: List applications with Bundle IDs
- `AppScreenshotProvider`: Capture screenshots of specified apps
- `AppAXTreeProvider`: Extract accessibility trees from specified apps
- `MouseClickTool`: Click coordinates in target app
- `KeyboardTool`: Type text in target app (for location search)
- `WaitTool`: Simple wait functionality for UI state changes

**Success Criteria**:
- AI can identify Weather app programmatically
- AI can locate and interact with search field
- AI can input location and select search results
- AI can extract weather information from display
- Complete workflow works via MCP protocol

## Future Development Phases
- v0.1.0: Weather app PoC with Bundle ID targeting and basic automation
- v0.2.0: Extended app support and DevTools integration
- v0.3.0: Shortcuts.app bridge and streaming screenshot capability
- v1.0.0: External HTTP authentication and plugin SDK

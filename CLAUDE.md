# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

AppMCP is now designed with clear separation of concerns:

- **AppMCP (MCP Layer)**: Model Context Protocol interface and JSON-RPC handling
- **AppPilot (Core Automation)**: Actual macOS UI automation with element-based operations

AppMCP depends on AppPilot for all automation functionality, providing a clean MCP interface layer.

## Important: How to Use AppMCP Tools Correctly

### Modern AppMCP Tool Usage
AppMCP now provides a single unified `automation` tool with these actions:
- `click`: Element-based or coordinate-based clicking (window context required)
- `type`: Text input with element targeting or into focused element
- `drag`: Drag operations between coordinates 
- `scroll`: Scrolling with delta values
- `wait`: Time-based waiting
- `find`: Element discovery and listing
- `screenshot`: Window capture

### Security Features - Window Context Required
All operations now require window context for security:
- **bundleID** or **appName** parameter required for app targeting
- **window** parameter (title or index) for window targeting
- Element-based operations are preferred over raw coordinates
- AppPilot automatically validates coordinates within window bounds
- Target application focus is ensured before operations

### Listing Available Applications
When asked to "list available apps" or "show running applications":
- **DO** use the `running_applications` resource: `appmcp://resources/running_applications`
- This returns ALL running apps with names, bundle IDs, handles, and active status

### Tools vs Resources
- **Resources**: Use to GET information (list apps, check windows)
- **Tools**: Use to PERFORM actions (click, type, find, etc.)

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

### Testing Framework Notes
**Swift Testing Usage**:
- Use Swift Testing framework for all tests (Swift 6.1+ built-in support)
- Import with `import Testing` (no Package.swift dependencies needed)
- Use `@Test` for test functions and `@Suite` for test groups
- Use `#expect()` for non-fatal assertions and `#require()` for fatal assertions
- Swift Testing provides better async support, parameterized tests, and parallel execution
- **DO NOT** use XCTest unless specifically required for legacy compatibility

**CRITICAL RULE - Swift Testing Package Dependency**:
- **NEVER add swift-testing package dependency to Package.swift**
- Swift 6.1+ has built-in Swift Testing support - external dependencies cause conflicts and warnings
- If you see deprecation warnings about "swift-testing package dependency", immediately remove it from Package.swift
- Only use `import Testing` in test files - no Package.swift changes needed
- The testTarget should only depend on the main module: `dependencies: ["AppMCP"]`

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
AppMCP is a Swift Package implementing Model Context Protocol (MCP) SDK v0.7.1 for macOS app automation. The architecture follows a clear separation of concerns:

#### AppMCP Layer (MCP Interface)
- **AppMCPServer**: Main MCP server implementing JSON-RPC automation tool
- **Single Tool Design**: Unified `automation` tool with action-based dispatch
- **Resource Providers**: 
  - `running_applications`: List all running applications with metadata
  - `application_windows`: All application windows with bounds and visibility
- **MCP Transport**: STDIO transport for AI model communication

#### AppPilot Layer (Core Automation)
AppMCP depends on AppPilot for all actual automation functionality:

1. **Element-Based Automation**: Priority given to UI element discovery and interaction
   - Accessibility API integration for reliable element targeting
   - Role-based element filtering (buttons, text fields, etc.)
   - Title and identifier-based element search

2. **Window Context Operations**: All operations require explicit window targeting
   - Application resolution by bundle ID or name
   - Window resolution by title or index
   - Automatic target application focus management
   - Coordinate validation within window bounds

3. **Driver Architecture**: Modular driver system for different automation aspects
   - `AccessibilityDriver`: UI element discovery and accessibility tree traversal
   - `CGEventDriver`: Low-level mouse/keyboard event generation
   - `ScreenDriver`: Screen capture and recording permission management

### Key Design Patterns
- **Layered Architecture**: Clean separation between MCP protocol layer and automation core
- **Element-First Approach**: Prefer UI element targeting over raw coordinates for reliability
- **Window Context Security**: All operations require explicit window context to prevent unintended actions
- **Async/Await**: Full async support throughout the stack
- **Protocol-Based Drivers**: Pluggable driver architecture for testing and extensibility

### Current Components
- **AppMCPServer**: MCP protocol server with unified automation tool
- **AppPilot Integration**: Seamless integration with AppPilot automation core
- **appmcpd**: CLI daemon executable for running the MCP server

### Dependencies
- `modelcontextprotocol/swift-sdk` >= 0.7.1: Core MCP protocol implementation
- **AppPilot**: Core macOS UI automation library (separate dependency)
- macOS 15+: Required for latest accessibility and screen capture APIs
- Swift 6.1+: Language requirements

## TestApp for Tool Validation

### TestApp Overview
A dedicated SwiftUI application for validating AppMCP tool functionality. Located in `TestApp/` directory.

**Purpose**: Programmatic validation of all AppMCP tools with HTTP API for automated testing.

**Bundle ID**: `com.example.TestApp` (for AppMCP targeting)
**Window Title**: "AppMCP Test App" 
**Window Size**: 800x600px (fixed, non-resizable)
**API Server**: HTTP server on port 8765 for programmatic state access

### TestApp Commands
```bash
# Build TestApp (SwiftUI app)
cd TestApp
xcodebuild -scheme TestApp -configuration Release

# Run TestApp from Xcode or Finder
open TestApp.xcodeproj

# Alternatively, build and run from command line
cd TestApp && swift run

# Run automated tests (requires TestApp to be running)
swift TestApp/TestRunner/main.swift --test full --output results.xml

# Check TestApp API status
curl http://localhost:8765/api/health

# Get test state programmatically
curl http://localhost:8765/api/state | jq '.summary'
```

### Test Categories

#### 1. Mouse Click Tests
- **Target Elements**: 5 circular buttons (四隅 + center, 100x100px each)
- **Button States**: Red (unclicked) → Green (clicked)
- **Parameters**: Button type (left/right/center), click count (1-3)
- **Validation**: Coordinate accuracy, button type detection, multi-click handling

#### 2. Keyboard Input Tests
- **Input Field**: Multi-line text area with expected vs actual comparison
- **Test Cases**: 
  - Basic: "Hello123"
  - Special chars: "!@#$%^&*()"
  - Japanese: "こんにちは世界"
  - Control chars: "Line1\nLine2\tTab"
  - Shortcuts: Cmd+A, Cmd+C, Cmd+V
- **Validation**: Character accuracy, encoding, timing

#### 3. Wait Tool Tests
- **Time Range**: 100ms - 5000ms (slider control)
- **Progress**: Real-time progress bar
- **Accuracy**: Calculated error percentage between expected and actual duration
- **UI Change**: Dynamic elements for change detection testing

#### 4. App/Window Resolution Tests
- **Search Methods**: Bundle ID, process name, PID
- **Results Display**: Found apps with metadata (Bundle ID, PID, window count)
- **Window Search**: By title regex and index
- **Validation**: Correct app targeting and window identification

#### 5. Integration Tests
- **Workflows**: Multi-step automation scenarios
- **Progress**: Step-by-step execution with success/failure indicators
- **Scenarios**: App launch → window focus → click → type → verify

### TestApp Usage in AppMCP Development
When testing AppMCP tools:
1. Launch TestApp (HTTP API starts automatically)
2. Use AppMCP to target TestApp via Bundle ID: `com.example.TestApp`
3. Navigate to appropriate test screen
4. Execute tool operations
5. Verify results programmatically via HTTP API endpoints
6. Use visual UI for debugging and manual verification

### Automated Testing with AppMCP Integration Tests
- **Test Suite**: `/Tests/AppMCPTests/AppMCPIntegrationTests.swift` (Swift Testing)
- **Helper Classes**: TestAppController, AppMCPClient, TestValidator
- **Test Coverage**: Discovery, click automation, keyboard input, timing, workflows
- **Framework**: Swift Testing with `@Test`, `@Suite`, `#expect`, `#require`
- **Features**: Async/await support, parameterized tests, parallel execution

### Development Guidelines for TestApp
- Keep UI simple and predictable for automation
- Use consistent element IDs and accessibility labels
- Provide clear visual feedback for all interactions
- Log all interactions with timestamps
- Support reset/clear operations for repeated testing

## Current Development Focus

### Modern AppMCP with AppPilot Integration (v1.0)
**Target**: Provide robust, secure macOS UI automation through MCP protocol with element-based operations.

**Key Components Implemented**:
- **Unified Automation Tool**: Single `automation` tool with action dispatch (click, type, drag, scroll, wait, find, screenshot)
- **AppPilot Integration**: Full integration with AppPilot core for reliable automation
- **Element-Based Operations**: Priority on UI element discovery and interaction over raw coordinates
- **Window Context Security**: All operations require explicit app and window targeting
- **Resource Providers**: Real-time application and window discovery

**Success Criteria** (Achieved):
- ✅ AI can identify and target applications by bundle ID or name
- ✅ AI can discover and interact with UI elements reliably
- ✅ AI can perform text input with proper element targeting
- ✅ AI can capture screenshots of specific windows
- ✅ All operations are secured with window context validation
- ✅ Complete workflow works via MCP protocol with AppPilot backend

### Weather App PoC Example Usage
With the current implementation, Weather app automation works as follows:

```json
{
  "action": "click",
  "bundleID": "com.apple.weather",
  "window": 0,
  "element": {
    "role": "AXTextField",
    "title": "Search"
  }
}
```

**Core Features Available**:
- Application targeting by bundle ID (`com.apple.weather`)
- Window resolution by title or index
- Element-based clicking and typing
- Screenshot capture of specific windows
- Wait operations for UI state changes


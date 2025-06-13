# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

AppMCP is now designed with clear separation of concerns:

- **AppMCP (MCP Layer)**: Model Context Protocol interface and JSON-RPC handling
- **AppPilot (Core Automation)**: Actual macOS UI automation with element-based operations

AppMCP depends on AppPilot for all automation functionality, providing a clean MCP interface layer.

## Important: How to Use AppMCP Tools Correctly

### Modern AppMCP Tool Usage
AppMCP now provides 6 specialized MCP tools (redesigned December 2024):
- `capture_ui_snapshot`: Unified UI state capture (screenshot + element hierarchy with IDs)
- `click_element`: Element ID-based clicking with multi-button support
- `input_text`: Element ID-based text input with method selection (type/setValue)
- `drag_drop`: Element ID-based drag operations between elements
- `scroll_window`: Element ID-based scrolling at specific element locations
- `wait_time`: Time-based waiting operations

### Modern ElementID-Based Design
All operations now use element IDs from `capture_ui_snapshot` for maximum efficiency:
- **ElementID-First Approach**: No more bundleID/window parameters needed
- **Snapshot-Driven Workflow**: Capture UI state once, operate multiple times
- **AI-Optimized**: Visual screenshot + element IDs enable intelligent automation
- **Performance**: Direct element operations without search overhead
- **Reliability**: Elements validated and accessible when snapshot captured

### Listing Available Applications
When asked to "list available apps" or "show running applications":
- **DO** use the `running_applications` resource: `appmcp://resources/running_applications`
- This returns ALL running apps with names, bundle IDs, handles, and active status

### AI Workflow for UI Automation
1. **Discover**: Use `running_applications` resource to find target app
2. **Capture**: Use `capture_ui_snapshot` to get screenshot + element IDs  
3. **Analyze**: AI visually identifies target elements from screenshot
4. **Act**: Use element IDs with operation tools (click, input, drag, scroll)
5. **Repeat**: Additional operations use same element IDs (no re-capture needed)

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
- **AppMCPServer**: Main MCP server implementing JSON-RPC automation tools
- **Specialized Tool Design**: 6 dedicated MCP tools with user-friendly element specification
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
- **AppMCPServer**: MCP protocol server with 6 specialized automation tools
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

### Modern AppMCP with Specialized MCP Tools (v1.0)
**Target**: Provide robust, secure macOS UI automation through MCP protocol with specialized tools and user-friendly element specification.

**Major Architecture Redesign** (December 2024):
AppMCP underwent a complete tool architecture redesign based on user feedback that the original unified tool was "too abstracted." The redesign focused on creating specialized tools with user-friendly element specification.

#### Key Changes Implemented:
1. **Tool Specialization**: Replaced single `automation` tool with 6 specialized MCP tools
2. **User-Friendly Element Types**: Eliminated requirement for users to know internal AX role names
3. **Element Type Mapping**: Automatic conversion from user types to internal accessibility roles
4. **Test Code Separation**: Moved test helper methods from production to test-only code
5. **Efficiency Prioritization**: Emphasized direct value setting over user simulation for performance

#### Specialized MCP Tools:
- **`click_element`**: UI element and coordinate-based clicking with multi-button support
- **`input_text`**: Text input with method selection (type/setValue) and element targeting
- **`drag_drop`**: Drag and drop operations with configurable duration
- **`scroll_window`**: Window scrolling with delta values and position targeting
- **`find_elements`**: UI element discovery with filtering and user-friendly criteria
- **`capture_screenshot`**: Window screenshot capture with format selection
- **`wait_time`**: Time-based waiting operations

#### User-Friendly Element Specification:
**Before** (Internal AX Roles):
```json
{
  "element": {
    "role": "AXTextField",
    "title": "Search"
  }
}
```

**After** (User-Friendly Types):
```json
{
  "element": {
    "type": "textfield",
    "text": "Search"
  }
}
```

#### Element Type Mapping System:
- **`button`** → `.button`, `.popUpButton`, `.menuBarItem`
- **`textfield`** → `.textField`, `.searchField`
- **`text`** → `.staticText`
- **`image`** → `.image`
- **`menu`** → `.menuBar`, `.menuItem`
- **`list`** → `.list`
- **`table`** → `.table`, `.cell`
- **`checkbox`** → `.checkBox`
- **`radio`** → `.radioButton`
- **`slider`** → `.slider`

#### Input Method Selection:
- **`setValue`**: Direct value setting for efficiency (default for AppMCP)
- **`type`**: Keystroke simulation for user-like behavior

### Weather App Example Usage (Modern ElementID-Based)
With the new ElementID-based design, Weather app automation is much more efficient:

```javascript
// Step 1: Capture UI state
const snapshot = await tools.capture_ui_snapshot({
  bundleID: "com.apple.weather"
});

// Step 2: AI analyzes screenshot and finds search field element ID
// (e.g., "elem_search_12345" from the elements list)

// Step 3: Direct operations using element IDs
await tools.click_element({
  elementId: "elem_search_12345"
});

await tools.input_text({
  elementId: "elem_search_12345",
  text: "Tokyo",
  method: "setValue"  // Efficient direct setting
});

// Find and click search button from same snapshot
await tools.click_element({
  elementId: "elem_search_btn_67890"
});
```

**Benefits over legacy approach:**
- 90% fewer parameters (elementId vs bundleID + window + element criteria)
- AI can visually verify target before clicking
- Multiple operations from single snapshot
- No repeated element searches

**Core Features Available**:
- Unified UI snapshot capture (screenshot + element hierarchy)
- Direct element operations via IDs (no search overhead)
- AI-optimized workflow (visual + programmatic)
- Efficient text input with setValue method
- Element-based drag and drop operations
- Context-aware scrolling at element locations
- Time-based wait operations

### Implementation Quality Focus:
- **AI-First Design**: Visual screenshots + programmatic element IDs
- **Maximum Efficiency**: ElementID operations eliminate search overhead
- **Simplified API**: Minimal parameters (elementId only) for most operations
- **Snapshot Workflow**: Capture once, operate multiple times
- **AppPilot Integration**: Direct element operations with coordinate fallback

## CRITICAL: Error Handling and Development Principles

### Fail-Fast Philosophy
**NEVER implement fallback mechanisms or catch-all error handling that masks bugs.**

#### Core Principles:
1. **Explicit Error Propagation**: All errors must be explicitly handled and propagated up the call stack
2. **No Silent Failures**: Never catch exceptions and continue execution without proper error handling
3. **Clear Error Messages**: Every error must provide specific, actionable information about what went wrong
4. **Type Safety First**: Use Swift's type system to prevent runtime errors at compile time
5. **Defensive Programming**: Validate inputs at API boundaries, but don't add redundant checks deeper in the stack

#### Prohibited Patterns:
```swift
// ❌ NEVER DO THIS - Hides bugs
func findElement() -> UIElement? {
    do {
        return try performFind()
    } catch {
        print("Error occurred: \(error)")
        return nil  // Silent failure masks the real problem
    }
}

// ❌ NEVER DO THIS - Overly defensive
func processValue(_ value: MCP.Value?) -> String {
    guard let value = value else { return "default" }
    if case .string(let str) = value {
        return str.isEmpty ? "fallback" : str
    }
    return "another_fallback"  // Masks type mismatches
}
```

#### Correct Patterns:
```swift
// ✅ CORRECT - Explicit error propagation
func findElement(criteria: ElementCriteria) throws -> UIElement {
    guard !criteria.isEmpty else {
        throw AppMCPError.invalidParameters("Element criteria cannot be empty")
    }
    
    let elements = try performSearch(criteria)
    guard let element = elements.first else {
        throw AppMCPError.elementNotFound("No element found matching: \(criteria)")
    }
    
    return element
}

// ✅ CORRECT - Type-safe parameter handling
func extractRequiredString(from arguments: [String: MCP.Value], key: String) throws -> String {
    guard let value = arguments[key] else {
        throw AppMCPError.missingParameter(key)
    }
    
    guard case .string(let str) = value else {
        throw AppMCPError.invalidParameterType(key, expected: "string", got: "\(value)")
    }
    
    return str
}
```

### MCP Parameter Validation Strategy

#### Input Validation Rules:
1. **Validate at API entry points** (tool handlers)
2. **Use type-safe extraction** methods with explicit error types
3. **Validate business logic constraints** (e.g., non-empty criteria)
4. **Propagate AppPilot errors** without modification
5. **Never assume default values** unless explicitly documented in the API

#### Tool Handler Pattern:
```swift
// ✅ CORRECT - Clean error propagation
internal func handleClickElement(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
    do {
        let result = try await performClick(arguments)
        return CallTool.Result(content: [.text(result)])
    } catch {
        return CallTool.Result(
            content: [.text("Error: \(error.localizedDescription)")],
            isError: true
        )
    }
}

private func performClick(_ arguments: [String: MCP.Value]) async throws -> String {
    let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
    let app = try await pilot.findApplication(bundleId: bundleID)
    // ... rest of implementation with explicit error propagation
}
```

### Testing Philosophy
1. **Test error paths explicitly** - Every error condition must have a corresponding test
2. **Use integration tests** to verify end-to-end behavior with real AppPilot
3. **Mock only external dependencies** - Never mock internal AppMCP logic
4. **Verify error messages** in tests to ensure they provide actionable information

### Debugging Guidelines
1. **Add structured logging** at key decision points, not as error recovery
2. **Use breakpoints and debugger** instead of try-catch blocks for investigation
3. **Log successful operations** at appropriate log levels for traceability
4. **Include relevant context** in error messages (element criteria, app state, etc.)

This approach ensures bugs are discovered quickly during development and provides clear error information to users, rather than masking problems with fallback behavior.


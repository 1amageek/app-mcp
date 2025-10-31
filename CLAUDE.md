# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

AppMCP is now designed with clear separation of concerns:

- **AppMCP (MCP Layer)**: Model Context Protocol interface and JSON-RPC handling
- **AppPilot (Core Automation)**: Actual macOS UI automation with element-based operations

AppMCP depends on AppPilot for all automation functionality, providing a clean MCP interface layer.

## Important: MCP Tools and Resources

### MCP Tools (6 State-Mutating Actions)
AppMCP provides specialized tools for UI automation actions:
- `click_element`: Click UI elements by element ID with multi-button support
- `input_text`: Input text with type or setValue methods
- `drag_drop`: Drag and drop operations between elements
- `scroll_window`: Scroll operations at element locations
- `keyboard_input`: Execute keyboard shortcuts and key sequences
- `wait_time`: Time-based waiting operations

**Key Principle**: Tools modify state (clicks, typing, etc.)

### MCP Resources (4 Read-Only Data Sources)
AppMCP provides resources for querying UI state:
- `running_applications` (`appmcp://resources/running_applications`): List all running apps
- `application_windows` (`appmcp://resources/application_windows`): List windows for an app
- `ui_snapshot` (`appmcp://ui/snapshot/{bundleID}`): Screenshot + element hierarchy with IDs
- `ui_elements` (`appmcp://ui/elements/{bundleID}`): Element hierarchy without screenshot

**Key Principle**: Resources are read-only (no state changes)

### Modern ElementID-Based Design
All operations use element IDs from Resources for maximum efficiency:
- **Resource-Driven Workflow**: Read UI state via Resources, act via Tools
- **ElementID-First Approach**: No bundleID/window parameters needed in Tools
- **AI-Optimized**: Visual screenshots + element IDs enable intelligent automation
- **Snapshot Reuse**: Capture once, operate multiple times with same IDs
- **Reliability**: Elements validated when snapshot captured

### CRITICAL: Tool vs Resource Distinction

**Resources** (read-only data via `resources/read`):
- Accessed with URI: `appmcp://category/resource_name`
- Return structured JSON data
- Never modify system state
- Examples: `running_applications`, `ui_snapshot`

**Tools** (actions via `tools/call`):
- Take arguments object
- Modify system state (clicks, typing)
- Return success/error results
- Examples: `click_element`, `input_text`

**Common Mistake**:
- ❌ DON'T treat `ui_snapshot` as a tool
- ✅ DO use `resources/read` with URI `appmcp://ui/snapshot/{bundleID}`

### AI Workflow for UI Automation
1. **Discover Apps**: Read `running_applications` resource to find target app
2. **Capture UI State**: Read `ui_snapshot` resource to get screenshot + element IDs
3. **AI Analyzes**: LLM examines screenshot to visually identify target elements
4. **Execute Actions**: Call tools with element IDs from snapshot
5. **Repeat**: Re-read resources for updated state, or reuse existing element IDs

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

## Testing and Examples Policy

### Python Test Client Policy
**CRITICAL RULE - Single Test Client Only**:
- **Use ONLY `Examples/test_client.py` for all Python testing**
- **DO NOT create multiple test files in Examples directory**
- All test scenarios should be implemented as methods in the unified test client
- Add new test functionality by extending the existing `AppMCPTestClient` class
- This prevents Examples directory from becoming cluttered with numerous files

**Test Client Usage**:
```bash
# Run basic functionality tests
python3 Examples/test_client.py basic

# Run comprehensive test suite  
python3 Examples/test_client.py comprehensive

# Run demonstration of text recognition improvements
python3 Examples/test_client.py demo
```

**Adding New Tests**:
- Add new test methods to `AppMCPTestClient` class
- Follow naming convention: `test_[functionality_name](self)`
- Add to appropriate test suite in `run_basic_tests()` or `run_comprehensive_tests()`
- Include proper error handling and result reporting
- Document test purpose and expected behavior

**Prohibited Examples**:
- ❌ Creating separate files like `test_chrome.py`, `test_weather.py`, etc.
- ❌ Multiple standalone test scripts
- ❌ Demo files that should be part of the main test client
- ❌ Temporary test files that are not cleaned up

**Approved Examples Structure**:
```
Examples/
├── test_client.py          # ONLY Python test file allowed
└── README.md              # Documentation only
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

### Modern AppMCP with Resource-Driven UI Automation (v1.0)
**Target**: Provide robust, secure macOS UI automation through MCP protocol with clear Resource/Tool separation and ElementID-based operations.

**Core Architecture**:
- **Resources**: Read-only UI state inspection (applications, windows, UI snapshots with element IDs)
- **Tools**: State-mutating operations (click, input, drag, scroll, keyboard, wait)
- **ElementID Workflow**: Capture UI state once via Resources, operate multiple times via Tools

### Weather App Example Usage (Modern Resource + Tool Pattern)
With the Resource-driven design, Weather app automation is efficient and clear:

```javascript
// Step 1: Capture UI state via Resource
const snapshotResponse = await mcp.readResource("appmcp://ui/snapshot/com.apple.weather");
const snapshot = JSON.parse(snapshotResponse.contents[0].text);

// snapshot contains:
// - screenshot: base64-encoded PNG image
// - elements: [{id, role, title, bounds, ...}, ...]

// Step 2: AI analyzes screenshot and finds search field element ID
// LLM examines screenshot visually and matches to elements array
const searchField = snapshot.elements.find(el =>
  el.role === "textfield" && el.title?.includes("Search")
);
// Example: searchField.id = "elem_search_12345"

// Step 3: Use Tools with element IDs for actions
await mcp.callTool("click_element", {
  elementId: searchField.id
});

await mcp.callTool("input_text", {
  elementId: searchField.id,
  text: "Tokyo",
  method: "setValue"  // Efficient direct setting
});

// Find search button from same snapshot (no re-capture needed)
const searchButton = snapshot.elements.find(el =>
  el.role === "button" && el.title?.includes("Search")
);

await mcp.callTool("click_element", {
  elementId: searchButton.id
});
```

**Benefits of Resource-Driven Design:**
- **Clear separation**: Resources for reading, Tools for acting
- **Efficient**: Capture once, operate multiple times with same snapshot
- **AI-optimized**: Visual verification via screenshot + programmatic access via element IDs
- **Minimal parameters**: Only element ID needed for most operations
- **No repeated searches**: Element IDs from initial snapshot remain valid

**Core Features**:
- Resource-based UI inspection (screenshot + element hierarchy)
- Tool-based element operations (click, input, drag, scroll)
- ElementID workflow (IDs from Resources, used by Tools)
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


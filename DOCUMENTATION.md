# AppMCP Documentation

This document provides an overview of the comprehensive DocC documentation system added to the AppMCP project.

## Documentation Structure

The AppMCP project now includes a complete Swift-DocC documentation catalog located at:
```
Sources/AppMCP/AppMCP.docc/
```

### Core Documentation Files

1. **AppMCP.md** - Main documentation landing page
   - Framework overview and key features
   - Architecture summary
   - Topic organization and navigation
   - Requirements and setup information

2. **GettingStarted.md** - Installation and setup guide
   - Swift Package Manager integration
   - Xcode project setup
   - Permission configuration
   - Basic usage examples
   - Command-line usage
   - Troubleshooting common issues

3. **Architecture.md** - Technical architecture overview
   - Component design patterns
   - MCP protocol integration details
   - Performance considerations
   - Security and permission model
   - Extensibility guidelines

4. **WeatherAppTutorial.md** - Complete automation tutorial
   - End-to-end Weather app automation
   - MCP client interaction examples
   - JSON-RPC protocol usage
   - Error handling strategies
   - Advanced automation techniques

5. **Resources/README.md** - Documentation build and maintenance guide
   - Build commands and options
   - Publishing workflows
   - Content organization
   - Contribution guidelines

## Package Configuration

### Updated Package.swift
- Added Swift-DocC plugin dependency
- Configured for Swift 6.1 and macOS 15.0+
- Maintains existing MCP SDK and ArgumentParser dependencies

### Build Commands

```bash
# Generate and preview documentation locally
swift package generate-documentation --target AppMCP

# Preview with custom port
swift package preview-documentation --target AppMCP --port 8080

# Generate static documentation for hosting
swift package generate-documentation \
    --target AppMCP \
    --output-path ./docs \
    --hosting-base-path /AppMCP
```

## API Documentation

### Comprehensive Inline Documentation
All public APIs now include detailed DocC-compatible documentation:

#### Core Protocols
- **MCPResourceProvider** - Interface for data extraction components
- **MCPToolExecutor** - Interface for automation action components

#### Main Classes
- **MCPServer** - Central MCP protocol coordinator with lifecycle management
- **AppSelector** - Thread-safe application discovery actor
- **TCCManager** - macOS permission management system

#### Resource Providers
- **RunningAppsProvider** - Application discovery and enumeration
- **AppScreenshotProvider** - Application screenshot capture with base64 encoding
- **AppAXTreeProvider** - Accessibility tree extraction as JSON

#### Tool Executors
- **MouseClickTool** - Mouse automation with precise coordinate clicking
- **KeyboardTool** - Text input and keyboard shortcut simulation
- **WaitTool** - Time-based and condition-based waiting utilities

#### Data Types
- **AppInfo** - Application metadata structure with Bundle ID, name, PID, and active status
- **MCPError** - Comprehensive error enumeration with detailed descriptions

### Documentation Features

1. **Rich API References**
   - Complete parameter documentation
   - Return value descriptions
   - Error condition explanations
   - Usage examples with working code
   - Cross-references between related APIs

2. **Code Examples**
   - Real-world usage patterns
   - Error handling best practices
   - Complete automation workflows
   - Copy-paste ready snippets

3. **Cross-Linking**
   - Automatic symbol resolution
   - Article cross-references
   - Topic-based organization
   - Navigation between related concepts

## Tutorial Content

### Weather App Automation Tutorial
The comprehensive tutorial demonstrates:
- Complete MCP server setup
- AI-driven application control
- Visual inspection and UI automation
- JSON-RPC protocol communication
- Error recovery and debugging
- Advanced automation patterns

### Example Workflows
```swift
// Basic server setup
let server = MCPServer.weatherAppPoC()
try await server.validateConfiguration()
try await server.start()

// Application discovery
let appSelector = AppSelector()
let apps = await appSelector.listRunningApps()
let weatherApp = try await appSelector.findApp(bundleId: "com.apple.weather")
```

## Architecture Documentation

### MCP Protocol Integration
- JSON-RPC 2.0 communication
- Resource discovery and access
- Tool execution framework
- Transport abstraction (STDIO, HTTP+SSE)

### Component Design
- Protocol-based architecture
- Actor-based concurrency
- Permission management
- Error handling strategies

### Performance Considerations
- Asynchronous operation design
- Memory management patterns
- Caching strategies
- Concurrent request handling

## Getting Started Workflow

1. **Installation**
   - Add AppMCP to Package.swift or Xcode project
   - Resolve dependencies including DocC plugin

2. **Permission Setup**
   - Grant Accessibility permissions in System Preferences
   - Enable Screen Recording permissions if needed
   - Verify permissions with TCCManager

3. **Basic Usage**
   - Create MCPServer instance
   - Validate configuration
   - Start server with chosen transport
   - Handle MCP protocol communication

4. **Documentation Access**
   - Build documentation locally for development
   - Generate static documentation for hosting
   - Access comprehensive API reference

## Publishing and Hosting

The documentation can be published to:
- GitHub Pages (recommended)
- Netlify, Vercel, or similar static hosting
- Custom web servers
- Internal documentation portals

Build artifacts include:
- Static HTML documentation
- Searchable API reference
- Interactive tutorials
- Cross-linked navigation

## Maintenance

### Updating Documentation
- Inline documentation updates automatically reflect in API reference
- Tutorial content requires manual updates for workflow changes
- Architecture documentation should be updated for significant design changes

### Quality Assurance
- All code examples are tested for compilation
- Cross-references are validated during build
- Documentation warnings are treated as build errors
- Accessibility standards are maintained

## Benefits

1. **Developer Experience**
   - Comprehensive API documentation reduces learning curve
   - Working examples accelerate development
   - Clear architecture guidance enables proper usage

2. **Project Quality**
   - Professional documentation increases adoption
   - Detailed error documentation improves debugging
   - Consistent documentation standards improve maintainability

3. **AI Integration**
   - Well-documented APIs enable better AI code generation
   - Clear examples demonstrate proper usage patterns
   - Comprehensive error documentation helps with troubleshooting

This documentation system establishes AppMCP as a professional, well-documented framework for macOS GUI automation with the Model Context Protocol.
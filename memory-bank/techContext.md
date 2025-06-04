# Technical Context

## Technology Stack

### Core Technologies
- **Swift 6.1+**: Modern concurrency, type safety, performance
- **Model Context Protocol**: Standardized AI-computer interaction
- **macOS 15+**: Latest system APIs and security features
- **Xcode 16+**: Development environment and toolchain

### Key Dependencies
```swift
dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.7.1")
]
```

### System Frameworks
- **ApplicationServices**: Screen capture, accessibility
- **CoreGraphics**: Image processing, coordinate systems
- **AppKit**: macOS UI integration
- **Foundation**: Core Swift functionality
- **os.log**: System logging integration

## Development Environment

### Required Setup
- **macOS 15+** (Sonoma or later)
- **Xcode 16+** with Swift 6.1 support
- **Command Line Tools** for Swift Package Manager
- **System Permissions**: Accessibility, Screen Recording

### Build Configuration
```swift
// Package.swift
platforms: [.macOS(.v15)]
swiftSettings: [.unsafeFlags(["-enable-bare-slash-regex"])]
```

### Compiler Features
- **Swift 6 Concurrency**: Actor isolation, async/await
- **Sendable Protocol**: Thread-safe data sharing
- **Regex Literals**: Pattern matching with bare slash syntax
- **Type Inference**: Reduced boilerplate code

## System Integration

### macOS APIs Used

#### Screen Capture
```swift
// CGDisplayCreateImage for screenshots
// CGPreflightScreenCaptureAccess for permissions
```

#### Accessibility
```swift
// AXUIElementCreateApplication
// AXUIElementCopyAttributeNames
// AXUIElementCopyAttributeValue
```

#### Input Simulation
```swift
// CGEventCreateMouseEvent
// CGEventCreateKeyboardEvent
// CGEventPost
```

#### Permission Management
```swift
// AccessibilityIsProcessTrustedWithOptions
// CGPreflightScreenCaptureAccess
// TCCAccessRequest
```

### Transport Mechanisms

#### STDIO Transport (Primary)
- JSON-RPC over stdin/stdout
- Process-based communication
- Suitable for CLI integration
- Low overhead, high reliability

#### HTTP Transport (Future)
- RESTful API with Server-Sent Events
- Web-based integration
- CORS support for browser clients
- Authentication and rate limiting

## Performance Characteristics

### Latency Targets
- **Screenshot Capture**: < 100ms
- **Accessibility Tree**: < 200ms
- **Mouse/Keyboard Actions**: < 50ms
- **MCP Response Time**: < 300ms total

### Memory Usage
- **Base Memory**: < 50MB resident
- **Screenshot Buffer**: ~10MB per capture
- **AX Tree Cache**: ~5MB typical
- **Total Working Set**: < 100MB

### CPU Usage
- **Idle State**: < 1% CPU
- **Active Capture**: < 10% CPU burst
- **Sustained Load**: < 5% CPU average

## Security Model

### Permission Requirements
1. **Screen Recording**: Required for screenshots
2. **Accessibility**: Required for UI tree and input simulation
3. **Network** (future): Required for HTTP transport

### Security Boundaries
- **Sandboxed Execution**: No file system access beyond temp
- **Permission Validation**: Every operation checks TCC status
- **Input Validation**: All MCP requests validated
- **Audit Logging**: All actions logged with timestamps

### Threat Model
- **Malicious MCP Client**: Mitigated by permission gates
- **Privilege Escalation**: Prevented by system boundaries
- **Data Exfiltration**: Limited to screen content only
- **DoS Attacks**: Rate limiting and resource bounds

## Testing Infrastructure

### Test Types
```swift
// Unit Tests
@Test func screenshotCaptureTest() async throws { }

// Integration Tests  
@Test func mcpServerIntegrationTest() async throws { }

// UI Tests (Xcode UI Testing)
func testMouseClickIntegration() throws { }
```

### Test Environment
- **GitHub Actions**: macOS runners for CI
- **Local Testing**: Xcode Test Navigator
- **Mock Objects**: Protocol-based mocking
- **Test Doubles**: Fake system responses

### Coverage Targets
- **Unit Tests**: 90%+ line coverage
- **Integration Tests**: All MCP endpoints
- **UI Tests**: Critical user flows
- **Performance Tests**: Latency benchmarks

## Build & Distribution

### Build Process
```bash
# Development build
swift build

# Release build
swift build -c release

# Testing
swift test

# Package validation
swift package resolve
```

### Distribution Channels
1. **Swift Package Manager**: Primary distribution
2. **GitHub Releases**: Tagged versions with binaries
3. **Homebrew** (future): Package manager integration
4. **Mac App Store** (future): Sandboxed distribution

### Versioning Strategy
- **Semantic Versioning**: MAJOR.MINOR.PATCH
- **API Compatibility**: Maintain backward compatibility
- **Breaking Changes**: Only in major versions
- **Release Cadence**: Monthly minor releases

## Development Workflow

### Code Organization
```
Sources/AppMCP/           # Library code
├── MCPServer.swift       # Main server class
├── Resources/            # Resource providers
├── Tools/                # Tool executors
├── Permissions/          # TCC management
└── Logging/              # Logging utilities

Sources/appmcpd/          # CLI binary
└── main.swift            # Entry point

Tests/AppMCPTests/        # Test suite
├── ResourceTests.swift   # Resource testing
└── ToolTests.swift       # Tool testing
```

### Quality Gates
- **Linting**: SwiftLint integration
- **Formatting**: swift-format consistency
- **Testing**: All tests must pass
- **Documentation**: Public APIs documented

### Continuous Integration
```yaml
# .github/workflows/ci.yml
- name: Build and Test
  run: swift test
- name: Build Release
  run: swift build -c release
```

## Deployment Considerations

### System Requirements
- **Minimum**: macOS 15.0
- **Recommended**: macOS 15.1+
- **Architecture**: Universal (Intel + Apple Silicon)
- **Memory**: 4GB+ available RAM

### Installation Process
1. Download from GitHub Releases
2. Grant required system permissions
3. Run `appmcpd --stdio` or integrate library
4. Configure MCP client connection

### Monitoring & Observability
- **System Logging**: os_log integration
- **Performance Metrics**: Built-in timing
- **Error Tracking**: Structured error reporting
- **Health Checks**: Self-diagnostic capabilities

## Future Technical Roadmap

### v0.2.0 - Enhanced Transport
- HTTP/SSE transport implementation
- WebSocket support for real-time updates
- Authentication and authorization

### v0.3.0 - Advanced Features
- Shortcuts app integration
- Streaming screenshot updates
- Multi-display support

### v1.0.0 - Production Ready
- Plugin architecture
- Advanced caching strategies
- Enterprise security features
- Performance optimizations

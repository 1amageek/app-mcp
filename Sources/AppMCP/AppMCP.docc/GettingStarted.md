# Getting Started

Learn how to set up and use AppMCP for macOS GUI automation.

## Installation

### Swift Package Manager

Add AppMCP to your project using Swift Package Manager by adding the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/AppMCP.git", from: "0.1.0")
]
```

Then add AppMCP to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        "AppMCP"
    ]
)
```

### Xcode Integration

1. Open your Xcode project
2. Go to **File** → **Add Package Dependencies**
3. Enter the repository URL: `https://github.com/your-org/AppMCP.git`
4. Select the version and add to your project

## Prerequisites

### System Requirements

- macOS 15.0 or later
- Swift 6.1 or later
- Xcode 16.0 or later

### Required Permissions

AppMCP requires specific macOS permissions to function properly:

1. **Accessibility Permission**: Required for UI element inspection and automation
2. **Screen Recording Permission**: Required for capturing application screenshots

### Granting Permissions

1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Accessibility** from the sidebar
3. Click the lock icon and enter your password
4. Add your application to the list of allowed apps
5. Repeat for **Screen Recording** if screenshot functionality is needed

## Basic Usage

### Creating an MCP Server

```swift
import AppMCP

// Create a server with default configuration
let server = MCPServer()

// Start the server with STDIO transport
try await server.start()
```

### Custom Configuration

```swift
// Create custom resource providers and tools
let resources: [any MCPResourceProvider] = [
    RunningAppsProvider(appSelector: AppSelector()),
    AppScreenshotProvider(appSelector: AppSelector(), tccManager: TCCManager())
]

let tools: [any MCPToolExecutor] = [
    MouseClickTool(appSelector: AppSelector(), tccManager: TCCManager()),
    KeyboardTool(appSelector: AppSelector(), tccManager: TCCManager())
]

// Create server with custom configuration
let server = MCPServer(resources: resources, tools: tools)
```

### Finding Applications

```swift
let appSelector = AppSelector()

// Find app by Bundle ID
let weatherApp = try await appSelector.findApp(bundleId: "com.apple.weather")

// Find app by process name
let finderApp = try await appSelector.findApp(processName: "Finder")

// List all running applications
let runningApps = await appSelector.listRunningApps()
```

## Weather App Example

Here's a complete example showing how to automate the macOS Weather app:

```swift
import AppMCP

@main
struct WeatherAutomation {
    static func main() async throws {
        // Create MCP server
        let server = MCPServer.weatherAppPoC()
        
        // Validate configuration
        try await server.validateConfiguration()
        
        // Start server (this will handle MCP protocol communication)
        try await server.start()
    }
}
```

## Command Line Usage

AppMCP includes a command-line daemon for running the MCP server:

```bash
# Build the project
swift build

# Run the MCP daemon
./.build/debug/appmcpd

# Or run with release configuration
swift build -c release
./.build/release/appmcpd
```

## Testing Your Setup

Create a simple test to verify AppMCP is working:

```swift
import AppMCP

func testBasicFunctionality() async throws {
    let appSelector = AppSelector()
    
    // Test app discovery
    let apps = await appSelector.listRunningApps()
    print("Found \(apps.count) running applications")
    
    // Test permissions
    let tccManager = TCCManager()
    let permissions = await tccManager.getPermissionStatus()
    print("Accessibility: \(permissions["accessibility"] ?? .unknown)")
    print("Screen Recording: \(permissions["screenRecording"] ?? .unknown)")
}
```

## Next Steps

- Learn about the <doc:Architecture> of AppMCP
- Follow the <doc:WeatherAppTutorial> for a complete automation example
- Explore the API documentation for detailed usage information

## Troubleshooting

### Common Issues

**Permission Denied Errors**
- Ensure your application has Accessibility and Screen Recording permissions
- Check that permissions are granted for the correct executable

**App Not Found**
- Verify the Bundle ID or process name is correct
- Ensure the target application is running

**MCP Communication Issues**
- Check that the MCP transport is properly configured
- Verify JSON-RPC message formatting

### Getting Help

- Check the API documentation for detailed method descriptions
- Review the example code in the tutorials
- File issues on the project repository for bugs or feature requests
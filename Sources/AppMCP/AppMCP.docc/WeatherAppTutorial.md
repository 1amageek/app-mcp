# Weather App Tutorial

Learn how to automate the macOS Weather app using AppMCP for AI-driven weather retrieval.

## Overview

This tutorial demonstrates how to use AppMCP to create an AI-powered automation that retrieves weather information from the macOS Weather app for any location. This serves as a practical example of how AI models can interact with native macOS applications through the Model Context Protocol.

## What You'll Build

By the end of this tutorial, you'll have:
- A working MCP server that can control the Weather app
- An AI agent capable of searching for locations and extracting weather data
- Understanding of how to combine visual recognition with UI automation

## Prerequisites

Before starting, ensure you have:
- macOS 15.0 or later
- The macOS Weather app installed (comes with macOS)
- AppMCP integrated into your project
- Required permissions granted (Accessibility and Screen Recording)

## Step 1: Setting Up the MCP Server

First, create a basic MCP server configured for Weather app automation:

```swift
import AppMCP

@main
struct WeatherAppMCPServer {
    static func main() async throws {
        // Create server with weather app configuration
        let server = MCPServer.weatherAppPoC()
        
        // Validate that all required components are available
        try await server.validateConfiguration()
        
        print("🌦️ Weather App MCP Server starting...")
        print("📋 Available resources: \(server.getResourceInfo().keys.joined(separator: ", "))")
        print("🛠️ Available tools: \(server.getToolInfo().keys.joined(separator: ", "))")
        
        // Start the server with STDIO transport
        try await server.start()
    }
}
```

## Step 2: Understanding the Automation Workflow

The Weather app automation follows this sequence:

1. **App Discovery**: Find and focus the Weather app
2. **Visual Inspection**: Capture screenshot and accessibility tree
3. **Location Search**: Interact with the search field
4. **Input Location**: Type the desired location
5. **Result Selection**: Click on search results
6. **Data Extraction**: Capture weather information

## Step 3: MCP Client Interaction

Here's how an AI model would interact with the MCP server to get weather data:

### List Available Resources

```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "resources/list"
}
```

**Response:**
```json
{
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
        "resources": [
            {
                "name": "running_applications",
                "uri": "app://running_applications",
                "description": "List of currently running applications",
                "mimeType": "application/json"
            },
            {
                "name": "app_screenshot",
                "uri": "app://app_screenshot",
                "description": "Screenshot of specified application",
                "mimeType": "application/json"
            },
            {
                "name": "app_accessibility_tree",
                "uri": "app://app_accessibility_tree",
                "description": "Accessibility tree of specified application",
                "mimeType": "application/json"
            }
        ]
    }
}
```

### Get Weather App Screenshot

```json
{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "resources/read",
    "params": {
        "uri": "app://app_screenshot"
    }
}
```

**Response:**
```json
{
    "jsonrpc": "2.0",
    "id": 2,
    "result": {
        "contents": [
            {
                "text": "{\"image_data\": \"iVBORw0KGgoAAAANSUhEUgAA...\", \"bundle_id\": \"com.apple.weather\"}",
                "uri": "app://app_screenshot",
                "mimeType": "application/json"
            }
        ]
    }
}
```

### Get Accessibility Tree

```json
{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "resources/read",
    "params": {
        "uri": "app://app_accessibility_tree"
    }
}
```

## Step 4: Performing UI Automation

### Click on Search Field

```json
{
    "jsonrpc": "2.0",
    "id": 4,
    "method": "tools/call",
    "params": {
        "name": "mouse_click",
        "arguments": {
            "x": 300,
            "y": 100,
            "button": "left",
            "click_count": 1
        }
    }
}
```

### Type Location Name

```json
{
    "jsonrpc": "2.0",
    "id": 5,
    "method": "tools/call",
    "params": {
        "name": "type_text",
        "arguments": {
            "text": "San Francisco, CA",
            "target_app": {
                "bundle_id": "com.apple.weather"
            }
        }
    }
}
```

### Wait for Results

```json
{
    "jsonrpc": "2.0",
    "id": 6,
    "method": "tools/call",
    "params": {
        "name": "wait",
        "arguments": {
            "duration_ms": 2000,
            "condition": "ui_change"
        }
    }
}
```

## Step 5: Complete Automation Example

Here's a complete Python script that demonstrates the full workflow:

```python
import json
import subprocess
import base64
import time

class WeatherAppAutomation:
    def __init__(self):
        # Start the MCP server process
        self.server_process = subprocess.Popen(
            ['./.build/debug/appmcpd'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
    
    def send_request(self, method, params=None):
        """Send JSON-RPC request to MCP server"""
        request = {
            "jsonrpc": "2.0",
            "id": int(time.time() * 1000),
            "method": method
        }
        if params:
            request["params"] = params
        
        request_json = json.dumps(request) + '\n'
        self.server_process.stdin.write(request_json)
        self.server_process.stdin.flush()
        
        # Read response
        response_line = self.server_process.stdout.readline()
        return json.loads(response_line)
    
    def get_weather(self, location):
        """Get weather for specified location"""
        
        # 1. Get current Weather app screenshot
        screenshot_response = self.send_request(
            "resources/read",
            {"uri": "app://app_screenshot"}
        )
        
        # 2. Get accessibility tree
        tree_response = self.send_request(
            "resources/read",
            {"uri": "app://app_accessibility_tree"}
        )
        
        # 3. Analyze UI and find search field coordinates
        # (In real implementation, AI would analyze the screenshot and tree)
        search_field_coords = self.find_search_field(screenshot_response, tree_response)
        
        # 4. Click on search field
        self.send_request(
            "tools/call",
            {
                "name": "mouse_click",
                "arguments": {
                    "x": search_field_coords["x"],
                    "y": search_field_coords["y"],
                    "button": "left"
                }
            }
        )
        
        # 5. Type location
        self.send_request(
            "tools/call",
            {
                "name": "type_text",
                "arguments": {
                    "text": location,
                    "target_app": {"bundle_id": "com.apple.weather"}
                }
            }
        )
        
        # 6. Wait for search results
        self.send_request(
            "tools/call",
            {
                "name": "wait",
                "arguments": {"duration_ms": 2000}
            }
        )
        
        # 7. Click on first result
        # (Implementation would analyze updated screenshot)
        
        # 8. Extract weather data
        final_screenshot = self.send_request(
            "resources/read",
            {"uri": "app://app_screenshot"}
        )
        
        return self.extract_weather_data(final_screenshot)
    
    def find_search_field(self, screenshot_response, tree_response):
        """Analyze screenshot and tree to find search field"""
        # This is where AI vision would analyze the UI
        # For demo purposes, return hardcoded coordinates
        return {"x": 300, "y": 100}
    
    def extract_weather_data(self, screenshot_response):
        """Extract weather information from screenshot"""
        # AI would analyze the screenshot to extract:
        # - Current temperature
        # - Weather conditions
        # - Forecast data
        # - Location confirmation
        return {
            "location": "San Francisco, CA",
            "temperature": "72°F",
            "condition": "Sunny",
            "humidity": "65%"
        }

# Usage
if __name__ == "__main__":
    automation = WeatherAppAutomation()
    weather_data = automation.get_weather("San Francisco, CA")
    print(f"Weather: {weather_data}")
```

## Step 6: Error Handling and Troubleshooting

### Common Issues

**Weather App Not Found**
```swift
// Ensure Weather app is running
let apps = await appSelector.listRunningApps()
let weatherApp = apps.first { $0.bundleId == "com.apple.weather" }
if weatherApp == nil {
    // Launch Weather app programmatically
    NSWorkspace.shared.launchApplication(
        withBundleIdentifier: "com.apple.weather",
        additionalEventParamDescriptor: nil,
        launchIdentifier: nil
    )
}
```

**Permission Denied**
```swift
let tccManager = TCCManager()
let permissions = await tccManager.getPermissionStatus()

if permissions["accessibility"] != .granted {
    print("⚠️ Accessibility permission required")
    print("Go to System Preferences > Security & Privacy > Accessibility")
}

if permissions["screenRecording"] != .granted {
    print("⚠️ Screen Recording permission required")
    print("Go to System Preferences > Security & Privacy > Screen Recording")
}
```

### Debugging Tips

1. **Enable Verbose Logging**: Add debug prints to track automation flow
2. **Screenshot Verification**: Save screenshots to verify UI state
3. **Accessibility Inspector**: Use Xcode's Accessibility Inspector to verify element properties
4. **Step-by-Step Execution**: Add delays between actions for manual verification

## Step 7: Advanced Features

### Location Validation

```swift
func validateLocation(_ location: String) async throws -> Bool {
    // Type location and check for search results
    // Return false if no results found
}
```

### Multiple Weather Data Points

```swift
struct WeatherData {
    let location: String
    let currentTemperature: String
    let condition: String
    let humidity: String
    let windSpeed: String
    let forecast: [ForecastDay]
}
```

### Error Recovery

```swift
func performWeatherSearchWithRetry(location: String, maxRetries: Int = 3) async throws -> WeatherData {
    for attempt in 1...maxRetries {
        do {
            return try await performWeatherSearch(location: location)
        } catch {
            if attempt == maxRetries {
                throw error
            }
            // Wait before retry
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
}
```

## Next Steps

- Extend the automation to handle different weather apps
- Add support for multiple locations in a single request
- Implement weather data comparison across different sources
- Create a voice interface using Speech framework integration

## Summary

This tutorial demonstrated how to:
- Set up an MCP server for GUI automation
- Implement AI-driven application control
- Handle macOS permissions and security
- Create robust error handling and recovery
- Extract structured data from visual interfaces

The Weather app example showcases the power of combining AI vision with programmatic automation, enabling sophisticated workflows that bridge the gap between AI models and native macOS applications.
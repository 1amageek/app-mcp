# Getting Started

Learn how to set up and use AppMCP for macOS GUI automation.

## Installation

### Building from Source

Clone the repository and build the project:

```bash
# Clone the repository
git clone https://github.com/your-org/AppMCP.git
cd AppMCP

# Build the project
swift build

# Run the MCP server
./.build/debug/appmcpd --stdio
```

### Release Build

For production use, build with optimizations:

```bash
swift build -c release
./.build/release/appmcpd --stdio
```

## Prerequisites

### System Requirements

- macOS 15.0 or later (Sequoia)
- Swift 6.1 or later
- Xcode 16.0 or later
- AppPilot framework (automatically fetched by SPM)

### Required Permissions

AppMCP requires specific macOS permissions to function properly:

1. **Accessibility Permission**: Required for UI element inspection and interaction
2. **Screen Recording Permission**: Required for capturing application screenshots

### Granting Permissions

1. Open **System Settings** → **Privacy & Security**
2. Select **Accessibility** from the left sidebar
3. Click the lock icon and authenticate
4. Add `appmcpd` (or your app) to the list of allowed apps
5. Repeat for **Screen Recording** if screenshot functionality is needed

**Note**: macOS will automatically prompt for permissions when AppMCP first attempts to use a protected feature.

## Basic Usage

### Starting the MCP Server

AppMCP runs as an MCP server that communicates via JSON-RPC over STDIO:

```bash
# Start the server
./appmcpd --stdio

# The server will wait for JSON-RPC requests on stdin
# and send responses on stdout
```

### Understanding Resources and Tools

AppMCP provides two types of MCP capabilities:

**Resources (Read-Only)**:
- `running_applications`: List all running apps
- `application_windows`: List all windows
- `ui_snapshot`: Capture screenshot + element IDs
- `ui_elements`: Get element hierarchy (no screenshot)

**Tools (State-Mutating)**:
- `click_element`: Click UI elements
- `input_text`: Input text
- `drag_drop`: Drag between elements
- `scroll_window`: Scroll operations
- `keyboard_input`: Keyboard shortcuts
- `wait_time`: Time-based wait

## Python Client Example

Here's how to use AppMCP from Python:

```python
import json
import subprocess
import sys

class AppMCPClient:
    def __init__(self):
        self.process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        self.request_id = 0

    def read_resource(self, uri):
        """Read a resource by URI"""
        self.request_id += 1
        request = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": "resources/read",
            "params": {"uri": uri}
        }

        self.process.stdin.write(json.dumps(request) + "\n")
        self.process.stdin.flush()

        response = json.loads(self.process.stdout.readline())
        return response

    def call_tool(self, name, arguments):
        """Call a tool with arguments"""
        self.request_id += 1
        request = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": "tools/call",
            "params": {
                "name": name,
                "arguments": arguments
            }
        }

        self.process.stdin.write(json.dumps(request) + "\n")
        self.process.stdin.flush()

        response = json.loads(self.process.stdout.readline())
        return response

# Example usage
client = AppMCPClient()

# List running applications
apps_response = client.read_resource("appmcp://resources/running_applications")
apps = json.loads(apps_response['result']['contents'][0]['text'])
print(f"Found {len(apps)} running applications")

# Capture UI snapshot
snapshot_response = client.read_resource("appmcp://ui/snapshot/com.apple.weather")
snapshot = json.loads(snapshot_response['result']['contents'][0]['text'])
print(f"Captured {len(snapshot['elements'])} elements")

# Click an element
click_response = client.call_tool("click_element", {
    "elementId": snapshot['elements'][0]['id']
})
print(f"Click result: {click_response}")
```

## Weather App Automation Example

Here's a complete example automating the macOS Weather app:

```python
import json
import time
from appmcp_client import AppMCPClient

def automate_weather_app():
    client = AppMCPClient()

    # Step 1: Capture UI state
    print("📸 Capturing Weather app UI...")
    snapshot_response = client.read_resource("appmcp://ui/snapshot/com.apple.weather")
    snapshot = json.loads(snapshot_response['result']['contents'][0]['text'])

    # Step 2: Find search field element
    search_field = None
    for element in snapshot['elements']:
        if element['role'] == 'textfield' and 'search' in element.get('title', '').lower():
            search_field = element
            break

    if not search_field:
        print("❌ Search field not found")
        return

    print(f"✅ Found search field: {search_field['id']}")

    # Step 3: Click search field
    print("🖱 Clicking search field...")
    client.call_tool("click_element", {
        "elementId": search_field['id']
    })
    time.sleep(0.5)

    # Step 4: Input city name
    print("⌨️ Typing 'Tokyo'...")
    client.call_tool("input_text", {
        "elementId": search_field['id'],
        "text": "Tokyo",
        "method": "setValue"
    })
    time.sleep(0.5)

    # Step 5: Find and click search button
    search_button = None
    for element in snapshot['elements']:
        if element['role'] == 'button' and 'search' in element.get('title', '').lower():
            search_button = element
            break

    if search_button:
        print("🔍 Clicking search button...")
        client.call_tool("click_element", {
            "elementId": search_button['id']
        })

    print("✅ Weather app automation complete!")

if __name__ == "__main__":
    automate_weather_app()
```

## Command Line Usage

### Running the Daemon

```bash
# Debug build with verbose output
./build/debug/appmcpd --stdio

# Release build for production
./build/release/appmcpd --stdio
```

### Testing with curl (HTTP transport not yet supported)

AppMCP currently only supports STDIO transport. HTTP transport is planned for future releases.

## MCP Protocol Details

### Resource URI Format

Resources are accessed using URIs:

```
appmcp://resources/running_applications
appmcp://resources/application_windows
appmcp://ui/snapshot/{bundleID}
appmcp://ui/elements/{bundleID}
```

### Tool Call Format

Tools are called with name and arguments:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "click_element",
    "arguments": {
      "elementId": "elem_123"
    }
  }
}
```

### Response Format

All responses follow JSON-RPC 2.0 format:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {"type": "text", "text": "Operation successful"}
    ]
  }
}
```

Error responses:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {"type": "text", "text": "Error: Element not found"}
    ],
    "isError": true
  }
}
```

## Testing Your Setup

### Verify Permissions

1. Run AppMCP: `./appmcpd --stdio`
2. Try capturing a screenshot: send a `ui_snapshot` resource read request
3. If prompted, grant Accessibility and Screen Recording permissions
4. Restart AppMCP after granting permissions

### Quick Test

Create a test script to verify basic functionality:

```python
from appmcp_client import AppMCPClient

client = AppMCPClient()

# Test 1: List running apps
apps = client.read_resource("appmcp://resources/running_applications")
print("✅ Can list running applications")

# Test 2: Capture UI snapshot
snapshot = client.read_resource("appmcp://ui/snapshot/com.apple.Finder")
print("✅ Can capture UI snapshots")

# Test 3: Wait operation
result = client.call_tool("wait_time", {"duration": 1.0})
print("✅ Tools are working")

print("\n🎉 All tests passed!")
```

## Next Steps

- Learn about the <doc:Architecture> of AppMCP
- Follow the <doc:WeatherAppTutorial> for a complete automation example
- Explore the API documentation for detailed Resource and Tool specifications

## Troubleshooting

### Common Issues

**Permission Denied Errors**
- Grant Accessibility permission in System Settings → Privacy & Security → Accessibility
- Grant Screen Recording permission for screenshot features
- Restart AppMCP after granting permissions

**Element Not Found**
- Verify the element ID comes from a recent `ui_snapshot` capture
- Check that the target application is in the foreground
- Ensure the UI hasn't changed since the snapshot was captured

**Application Not Found**
- Verify the Bundle ID is correct (e.g., `com.apple.weather`)
- Ensure the target application is running
- Use `running_applications` resource to list available apps

**JSON-RPC Communication Issues**
- Check that requests are properly formatted JSON-RPC 2.0 messages
- Ensure each request ends with a newline character
- Verify STDIO pipes are not buffered incorrectly

### Getting Help

- Check the API documentation for detailed Resource and Tool specifications
- Review the example code in <doc:WeatherAppTutorial>
- File issues on the project repository for bugs or feature requests
- See CLAUDE.md for development guidelines

# Weather App Tutorial

Learn how to automate the macOS Weather app using AppMCP with ElementID-based operations.

## Overview

This tutorial demonstrates how to use AppMCP to create an automation that retrieves weather information from the macOS Weather app for any location. This serves as a practical example of how AI models can interact with native macOS applications through the Model Context Protocol.

##  What You'll Build

By the end of this tutorial, you'll have:
- Understanding of the Resource + Tool pattern
- ElementID-based automation workflow
- Complete Weather app automation example in Python
- Error handling and troubleshooting strategies

## Prerequisites

Before starting, ensure you have:
- macOS 15.0 or later
- The macOS Weather app installed (comes with macOS)
- AppMCP built and ready: `./.build/debug/appmcpd`
- Required permissions granted (Accessibility and Screen Recording)

## Step 1: Understanding the Modern AppMCP Workflow

AppMCP uses a two-phase approach:

### Phase 1: Capture (Resources)
Use Resources to capture UI state without making changes:
1. List running applications to find target app
2. Capture UI snapshot with screenshot + element IDs
3. AI analyzes screenshot visually
4. AI matches visual features to element IDs

### Phase 2: Act (Tools)
Use Tools with element IDs to perform actions:
1. Click elements by ID
2. Input text by ID
3. Wait for UI changes
4. Repeat with same IDs or capture new snapshot

## Step 2: Setting Up the Python Client

Create a reusable MCP client class:

```python
import json
import subprocess
import time

class AppMCPClient:
    def __init__(self, appmcpd_path='./.build/debug/appmcpd'):
        """Initialize MCP client with STDIO transport"""
        self.process = subprocess.Popen(
            [appmcpd_path, '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
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

    def cleanup(self):
        """Clean up resources"""
        self.process.terminate()
        self.process.wait()
```

## Step 3: Discovering the Weather App

First, verify the Weather app is running:

```python
def find_weather_app(client):
    """Find Weather app in running applications"""
    print("📱 Finding Weather app...")

    # Read running applications resource
    response = client.read_resource("appmcp://resources/running_applications")
    apps = json.loads(response['result']['contents'][0]['text'])

    # Find Weather app
    weather_app = None
    for app in apps:
        if app['bundleID'] == 'com.apple.weather':
            weather_app = app
            break

    if not weather_app:
        print("❌ Weather app not found. Please launch it first.")
        return None

    print(f"✅ Found Weather app (PID: {weather_app['processID']})")
    return weather_app

# Usage
client = AppMCPClient()
weather_app = find_weather_app(client)
```

## Step 4: Capturing UI State with Element IDs

Capture the Weather app's UI:

```python
def capture_weather_ui(client):
    """Capture Weather app UI snapshot"""
    print("📸 Capturing Weather app UI...")

    # Capture UI snapshot with screenshot + element IDs
    response = client.read_resource("appmcp://ui/snapshot/com.apple.weather")
    snapshot = json.loads(response['result']['contents'][0]['text'])

    print(f"✅ Captured snapshot:")
    print(f"   - Screenshot: {len(snapshot['screenshot'])} bytes (base64)")
    print(f"   - Elements: {len(snapshot['elements'])} UI elements")

    # Display sample elements
    print("\n🔍 Sample elements:")
    for i, elem in enumerate(snapshot['elements'][:5]):
        print(f"   {i+1}. {elem['role']}: {elem.get('title', '(no title)')}")
        print(f"      ID: {elem['id']}")
        print(f"      Bounds: x={elem['bounds']['x']}, y={elem['bounds']['y']}, "
              f"w={elem['bounds']['width']}, h={elem['bounds']['height']}")

    return snapshot

# Usage
snapshot = capture_weather_ui(client)
```

## Step 5: Finding UI Elements

In real AI scenarios, the AI would analyze the screenshot visually. For this tutorial, we'll use programmatic search:

```python
def find_search_field(snapshot):
    """Find the search text field in the UI snapshot"""
    print("\n🔍 Finding search field...")

    # Look for text field with "search" in title or description
    for element in snapshot['elements']:
        role = element['role'].lower()
        title = element.get('title', '').lower()

        if 'textfield' in role or 'searchfield' in role:
            if 'search' in title or 'location' in title or title == '':
                print(f"✅ Found search field: {element['id']}")
                print(f"   Title: {element.get('title', '(empty)')}")
                print(f"   Role: {element['role']}")
                return element

    print("❌ Search field not found")
    return None

def find_element_by_role_and_title(snapshot, role_keyword, title_keyword=None):
    """Generic element finder"""
    for element in snapshot['elements']:
        role_match = role_keyword.lower() in element['role'].lower()

        if title_keyword:
            title = element.get('title', '').lower()
            title_match = title_keyword.lower() in title
            if role_match and title_match:
                return element
        else:
            if role_match:
                return element

    return None

# Usage
search_field = find_search_field(snapshot)
```

## Step 6: Automating the Weather Search

Now perform the actual automation:

```python
def automate_weather_search(client, location):
    """Automate weather search for a location"""
    print(f"\n🌦️ Searching weather for: {location}")

    # Step 1: Capture UI snapshot
    snapshot = capture_weather_ui(client)

    # Step 2: Find search field
    search_field = find_search_field(snapshot)
    if not search_field:
        print("❌ Cannot proceed without search field")
        return False

    # Step 3: Click search field to focus it
    print(f"\n🖱 Clicking search field...")
    response = client.call_tool("click_element", {
        "elementId": search_field['id']
    })

    if response.get('result', {}).get('isError'):
        print(f"❌ Click failed: {response['result']['content'][0]['text']}")
        return False

    print("✅ Clicked search field")
    time.sleep(0.3)  # Brief pause for UI to respond

    # Step 4: Input location text
    print(f"\n⌨️ Typing '{location}'...")
    response = client.call_tool("input_text", {
        "elementId": search_field['id'],
        "text": location,
        "method": "setValue"  # Efficient direct setting
    })

    if response.get('result', {}).get('isError'):
        print(f"❌ Input failed: {response['result']['content'][0]['text']}")
        return False

    print("✅ Input text completed")

    # Step 5: Wait for search results to appear
    print("\n⏱ Waiting for search results...")
    client.call_tool("wait_time", {"duration": 1.5})

    # Step 6: Capture updated UI to find search results
    print("\n📸 Capturing search results...")
    results_snapshot = client.read_resource("appmcp://ui/snapshot/com.apple.weather")
    results_snapshot = json.loads(results_snapshot['result']['contents'][0]['text'])

    # Step 7: Find and click first search result
    # In real scenario, AI would analyze screenshot to find result
    # For demo, find button/cell with location name
    result_button = find_element_by_role_and_title(
        results_snapshot,
        'button',
        location.split(',')[0]  # Match city name
    )

    if result_button:
        print(f"\n🔍 Found search result: {result_button['id']}")
        response = client.call_tool("click_element", {
            "elementId": result_button['id']
        })
        print("✅ Clicked search result")
    else:
        print("⚠️ Could not find search result button, trying Enter key...")
        # Alternative: Press Enter key
        client.call_tool("keyboard_input", {
            "keys": ["return"]
        })

    # Step 8: Wait for weather data to load
    print("\n⏱ Loading weather data...")
    client.call_tool("wait_time", {"duration": 2.0})

    print("\n✅ Weather search automation complete!")
    return True

# Usage
success = automate_weather_search(client, "Tokyo, Japan")
```

## Step 7: Complete Weather Automation Script

Here's the complete script combining all steps:

```python
#!/usr/bin/env python3
"""
Complete Weather App automation example using AppMCP
"""

import json
import subprocess
import time
import sys

class AppMCPClient:
    """AppMCP client with STDIO transport"""
    # [Class implementation from Step 2]
    pass

def automate_weather_for_location(location):
    """
    Complete workflow to search weather for a location

    Args:
        location: City name (e.g., "Tokyo, Japan")

    Returns:
        bool: True if successful
    """
    client = None
    try:
        # Initialize client
        client = AppMCPClient()
        print(f"🚀 AppMCP Client initialized")

        # Verify Weather app is running
        apps_response = client.read_resource("appmcp://resources/running_applications")
        apps = json.loads(apps_response['result']['contents'][0]['text'])

        weather_app_found = any(app['bundleID'] == 'com.apple.weather' for app in apps)
        if not weather_app_found:
            print("❌ Weather app is not running. Please launch it first.")
            return False

        print("✅ Weather app is running")

        # Capture initial UI state
        snapshot_response = client.read_resource("appmcp://ui/snapshot/com.apple.weather")
        snapshot = json.loads(snapshot_response['result']['contents'][0]['text'])
        print(f"📸 Captured {len(snapshot['elements'])} UI elements")

        # Find search field
        search_field = None
        for element in snapshot['elements']:
            if 'textfield' in element['role'].lower() or 'searchfield' in element['role'].lower():
                search_field = element
                break

        if not search_field:
            print("❌ Search field not found in UI")
            return False

        print(f"🔍 Found search field: {search_field['id']}")

        # Click search field
        print("🖱 Clicking search field...")
        client.call_tool("click_element", {"elementId": search_field['id']})
        time.sleep(0.3)

        # Input location
        print(f"⌨️ Typing '{location}'...")
        client.call_tool("input_text", {
            "elementId": search_field['id'],
            "text": location,
            "method": "setValue"
        })
        time.sleep(0.5)

        # Press Enter to search
        print("↵ Pressing Enter...")
        client.call_tool("keyboard_input", {"keys": ["return"]})

        # Wait for results
        print("⏱ Waiting for weather data...")
        client.call_tool("wait_time", {"duration": 2.0})

        # Capture final state
        final_response = client.read_resource("appmcp://ui/snapshot/com.apple.weather")
        final_snapshot = json.loads(final_response['result']['contents'][0]['text'])

        print(f"\n✅ Weather search completed successfully!")
        print(f"📊 Final UI has {len(final_snapshot['elements'])} elements")
        print(f"📸 Screenshot captured: {len(final_snapshot['screenshot'])} bytes")

        # In real scenario, AI would analyze screenshot to extract weather data
        print("\n💡 AI would now analyze the screenshot to extract:")
        print("   - Current temperature")
        print("   - Weather conditions")
        print("   - Forecast data")

        return True

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        if client:
            client.cleanup()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        location = " ".join(sys.argv[1:])
    else:
        location = "Tokyo, Japan"

    print(f"🌦️ Weather App Automation Tutorial")
    print(f"📍 Location: {location}\n")

    success = automate_weather_for_location(location)
    sys.exit(0 if success else 1)
```

## Step 8: Error Handling and Troubleshooting

### Common Issues

**Permission Denied Errors**
```python
# Catch permission errors
response = client.read_resource("appmcp://ui/snapshot/com.apple.weather")
result = response.get('result', {})

if result.get('isError'):
    error_msg = result['content'][0]['text']
    if 'permission' in error_msg.lower():
        print("⚠️ Permission denied!")
        print("Grant Accessibility and Screen Recording permissions:")
        print("System Settings → Privacy & Security → Accessibility/Screen Recording")
```

**Element Not Found**
```python
# Robust element finding with fallback
def find_element_robust(snapshot, primary_criteria, fallback_criteria=None):
    """Find element with fallback criteria"""
    # Try primary criteria
    element = find_element_by_role_and_title(snapshot, **primary_criteria)

    if not element and fallback_criteria:
        # Try fallback
        element = find_element_by_role_and_title(snapshot, **fallback_criteria)

    return element
```

**Weather App Not Running**
```python
# Check and notify user
apps = json.loads(client.read_resource("appmcp://resources/running_applications")['result']['contents'][0]['text'])

if not any(app['bundleID'] == 'com.apple.weather' for app in apps):
    print("❌ Weather app not running")
    print("💡 Launch Weather app: open -a Weather")
    sys.exit(1)
```

### Debugging Tips

1. **Save Screenshots**: Save base64 screenshot to file for visual inspection
   ```python
   import base64

   with open('weather_ui.png', 'wb') as f:
       f.write(base64.b64decode(snapshot['screenshot']))
   ```

2. **Print Element Tree**: Dump all elements for analysis
   ```python
   for i, elem in enumerate(snapshot['elements']):
       print(f"{i}: {elem['role']} - {elem.get('title', '(no title)')} - {elem['id']}")
   ```

3. **Add Delays**: Use longer waits to observe automation
   ```python
   client.call_tool("wait_time", {"duration": 3.0})  # 3 second delay
   ```

## Next Steps

- Add temperature extraction using AI vision models
- Support multiple cities in batch
- Compare weather across different apps
- Create scheduled weather monitoring
- Integrate with notification system

## Summary

This tutorial demonstrated:
- Modern ElementID-based automation workflow
- Resource + Tool separation pattern
- Python client implementation for AppMCP
- Complete Weather app automation example
- Error handling and troubleshooting

The Weather app example showcases the power of AppMCP's ElementID-based approach, enabling efficient and reliable macOS application automation through the Model Context Protocol.

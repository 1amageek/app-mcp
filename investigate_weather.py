#!/usr/bin/env python3

import json
import subprocess
import sys

def send_mcp_request(method, params=None):
    """Send MCP request via stdio to appmcpd"""
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params or {}
    }
    
    # Use the built appmcpd binary
    process = subprocess.Popen(
        ["/Users/1amageek/Desktop/AppMCP/.build/debug/appmcpd"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    # Send request
    process.stdin.write(json.dumps(request) + '\n')
    process.stdin.flush()
    
    # Read response
    response_line = process.stdout.readline()
    process.terminate()
    process.wait()
    
    if response_line:
        return json.loads(response_line)
    return None

def investigate_weather_app():
    """Investigate Weather app UI elements"""
    print("🔍 Investigating Weather app UI elements...")
    
    # 1. List running applications
    print("\n📱 Running applications:")
    response = send_mcp_request("resources/list", {"uri": "appmcp://resources/running_applications"})
    if response and "result" in response:
        apps = response["result"].get("contents", [])
        for app in apps:
            if "weather" in app.get("text", "").lower() or "天気" in app.get("text", ""):
                print(f"  ✅ Found Weather app: {app.get('text', '')[:100]}")
    
    # 2. Find all UI elements in Weather app
    print("\n🔍 Finding all UI elements in Weather app...")
    response = send_mcp_request("tools/call", {
        "name": "automation", 
        "arguments": {
            "action": "find",
            "bundleID": "com.apple.weather"
        }
    })
    
    if response and "result" in response:
        content = response["result"].get("content", [])
        if content:
            elements_text = content[0].get("text", "")
            print(f"  📋 UI Elements: {elements_text[:500]}...")
            
            # Look for specific element types
            if "AXTextField" in elements_text:
                print("  ✅ Found AXTextField elements")
            if "AXSearchField" in elements_text:
                print("  ✅ Found AXSearchField elements")
            if "AXButton" in elements_text:
                print("  ✅ Found AXButton elements")
                # Look for button titles
                if "Add" in elements_text:
                    print("    - Found 'Add' button")
                if "Search" in elements_text:
                    print("    - Found 'Search' button")
                if "+" in elements_text:
                    print("    - Found '+' button")
            
            return elements_text
    
    return None

def test_search_elements():
    """Test different search element approaches"""
    print("\n🧪 Testing search element approaches...")
    
    # Try to find search-related elements specifically
    search_roles = ["AXTextField", "AXSearchField", "AXButton"]
    
    for role in search_roles:
        print(f"\n  🔍 Testing {role}...")
        response = send_mcp_request("tools/call", {
            "name": "automation",
            "arguments": {
                "action": "find",
                "bundleID": "com.apple.weather",
                "element": {"role": role}
            }
        })
        
        if response and "result" in response:
            content = response["result"].get("content", [])
            if content:
                result_text = content[0].get("text", "")
                if "Found" in result_text and "Error" not in result_text:
                    print(f"    ✅ {role}: {result_text[:100]}")
                else:
                    print(f"    ❌ {role}: {result_text[:100]}")

if __name__ == "__main__":
    try:
        elements = investigate_weather_app()
        test_search_elements()
        
        if elements:
            # Save elements to file for analysis
            with open("/Users/1amageek/Desktop/AppMCP/weather_ui_elements.txt", "w") as f:
                f.write(elements)
            print(f"\n💾 UI elements saved to weather_ui_elements.txt")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
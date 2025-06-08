#!/usr/bin/env python3

import json
import subprocess
import time

def send_mcp_request(method, params=None):
    """Send MCP request via stdio to appmcpd"""
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params or {}
    }
    
    process = subprocess.Popen(
        ["/Users/1amageek/Desktop/AppMCP/.build/debug/appmcpd"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    process.stdin.write(json.dumps(request) + '\n')
    process.stdin.flush()
    
    response_line = process.stdout.readline()
    process.terminate()
    process.wait()
    
    if response_line:
        return json.loads(response_line)
    return None

def test_weather_menu_interaction():
    """Test Weather app menu and keyboard shortcuts"""
    print("🔍 Testing Weather app menu interactions...")
    
    # Try keyboard shortcut Cmd+F for search
    print("\n⌨️  Testing Cmd+F (Find/Search)...")
    response = send_mcp_request("tools/call", {
        "name": "automation",
        "arguments": {
            "action": "type",
            "bundleID": "com.apple.weather",
            "text": "⌘f"  # Cmd+F
        }
    })
    
    if response and "result" in response:
        print(f"  Cmd+F result: {response['result']}")
    
    time.sleep(2)
    
    # Check what elements are available after Cmd+F
    print("\n🔍 Checking elements after Cmd+F...")
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
            print(f"  Elements after Cmd+F: {elements_text[:500]}")
    
    # Try other common shortcuts
    shortcuts_to_test = [
        ("⌘+", "Cmd+Plus (Add location)"),
        ("⌘l", "Cmd+L (Location)"),
        ("⌘n", "Cmd+N (New)")
    ]
    
    for shortcut, description in shortcuts_to_test:
        print(f"\n⌨️  Testing {description}...")
        response = send_mcp_request("tools/call", {
            "name": "automation",
            "arguments": {
                "action": "type",
                "bundleID": "com.apple.weather",
                "text": shortcut
            }
        })
        
        if response and "result" in response:
            print(f"  {description} result: {response['result']}")
        
        time.sleep(1)

if __name__ == "__main__":
    test_weather_menu_interaction()
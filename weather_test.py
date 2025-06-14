#!/usr/bin/env python3
"""
Weather App Test - Connect to running appmcpd and get weather data
"""

import json
import sys

def send_mcp_message(message):
    """Send message to appmcpd via stdin/stdout"""
    print(json.dumps(message), flush=True)
    response = input()
    return json.loads(response)

def main():
    # Initialize connection
    init_response = send_mcp_message({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {"roots": {"listChanged": True}, "sampling": {}},
            "clientInfo": {"name": "Weather Test", "version": "1.0.0"}
        }
    })
    
    print("✅ Connected to AppMCP", file=sys.stderr)
    
    # Capture Weather app UI
    snapshot_response = send_mcp_message({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": "capture_ui_snapshot",
            "arguments": {"bundleID": "com.apple.weather"}
        }
    })
    
    if "result" in snapshot_response:
        content = snapshot_response["result"]["content"][0]["text"]
        data = json.loads(content)
        
        print("🌤️ Weather App UI Data:", file=sys.stderr)
        print(f"Screenshot saved: {data.get('screenshot_path', 'N/A')}", file=sys.stderr)
        print(f"Elements found: {len(data.get('elements', []))}", file=sys.stderr)
        
        # Extract weather-related text elements
        elements = data.get('elements', [])
        weather_info = []
        
        for element in elements:
            if element.get('role') == 'Text' and element.get('value'):
                text = element['value'].strip()
                if text and (any(char.isdigit() for char in text) or 
                           any(word in text.lower() for word in ['°', '℃', '℉', '曇', '晴', '雨', '雪'])):
                    weather_info.append(text)
        
        print("\n🌡️ Weather Information Found:", file=sys.stderr)
        for info in weather_info[:10]:  # Show first 10 relevant items
            print(f"  - {info}", file=sys.stderr)
    
    else:
        print("❌ Failed to capture Weather app UI", file=sys.stderr)

if __name__ == "__main__":
    main()
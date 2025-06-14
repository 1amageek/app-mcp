#!/usr/bin/env python3
"""
AppMCP Client - Connect to running appmcpd process
"""

import json
import subprocess
import sys
import os
import signal

class AppMCPClient:
    def __init__(self):
        self.process = None
    
    def connect_to_running_appmcpd(self):
        """Connect to the already running appmcpd process via subprocess"""
        try:
            # Start appmcpd as subprocess to communicate via stdin/stdout
            self.process = subprocess.Popen(
                ['./.build/arm64-apple-macosx/debug/appmcpd'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=0
            )
            print("✅ Connected to appmcpd process")
            return True
        except Exception as e:
            print(f"❌ Failed to connect: {e}")
            return False
    
    def send_message(self, message):
        """Send MCP message and get response"""
        if not self.process:
            print("❌ Not connected to appmcpd")
            return None
        
        try:
            # Send message
            json_message = json.dumps(message)
            print(f"→ Sending: {json_message}")
            self.process.stdin.write(json_message + '\n')
            self.process.stdin.flush()
            
            # Read response
            response_line = self.process.stdout.readline()
            if response_line:
                print(f"← Received: {response_line.strip()}")
                return json.loads(response_line.strip())
            else:
                print("❌ No response received")
                return None
                
        except Exception as e:
            print(f"❌ Communication error: {e}")
            return None
    
    def initialize(self):
        """Initialize MCP connection"""
        init_message = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "roots": {"listChanged": True},
                    "sampling": {}
                },
                "clientInfo": {
                    "name": "AppMCP Test Client",
                    "version": "1.0.0"
                }
            }
        }
        return self.send_message(init_message)
    
    def capture_weather_ui(self):
        """Capture Weather app UI"""
        capture_message = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "capture_ui_snapshot",
                "arguments": {
                    "bundleID": "com.apple.weather"
                }
            }
        }
        return self.send_message(capture_message)
    
    def disconnect(self):
        """Disconnect from appmcpd"""
        if self.process:
            self.process.terminate()
            self.process.wait()
            print("✅ Disconnected from appmcpd")

def main():
    client = AppMCPClient()
    
    try:
        # Connect to appmcpd
        if not client.connect_to_running_appmcpd():
            return 1
        
        # Initialize connection
        print("\n🔧 Initializing MCP connection...")
        init_response = client.initialize()
        if init_response and "result" in init_response:
            server_info = init_response["result"].get("serverInfo", {})
            print(f"✅ Connected to {server_info.get('name', 'AppMCP')} v{server_info.get('version', '1.0.0')}")
        
        # Capture Weather app UI
        print("\n🌤️ Capturing Weather app UI...")
        weather_response = client.capture_weather_ui()
        
        if weather_response and "result" in weather_response:
            content = weather_response["result"]["content"][0]["text"]
            data = json.loads(content)
            
            print(f"📸 Screenshot: {data.get('screenshot_path', 'N/A')}")
            print(f"🔢 Elements found: {len(data.get('elements', []))}")
            
            # Extract weather information
            elements = data.get('elements', [])
            weather_texts = []
            
            for element in elements:
                if element.get('role') == 'Text' and element.get('value'):
                    text = element['value'].strip()
                    if text:
                        weather_texts.append(text)
            
            print(f"\n🌡️ Weather Information:")
            for i, text in enumerate(weather_texts[:15]):  # Show first 15 text elements
                print(f"  {i+1}. {text}")
        
        else:
            print("❌ Failed to capture Weather app UI")
    
    except KeyboardInterrupt:
        print("\n⏹️  Interrupted by user")
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        client.disconnect()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
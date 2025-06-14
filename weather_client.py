#!/usr/bin/env python3
"""
Weather Client - Connect to existing appmcpd and get weather info
"""

import json
import subprocess
import sys
import time

def main():
    try:
        # Start a new appmcpd process to connect to
        process = subprocess.Popen(
            ['./.build/arm64-apple-macosx/debug/appmcpd'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0
        )
        
        print("✅ Connected to appmcpd")
        
        # Initialize
        init_msg = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"roots": {"listChanged": True}, "sampling": {}},
                "clientInfo": {"name": "Weather Client", "version": "1.0.0"}
            }
        }
        
        print("→ Initializing...")
        process.stdin.write(json.dumps(init_msg) + '\n')
        process.stdin.flush()
        
        init_response = process.stdout.readline()
        print(f"← {init_response.strip()}")
        
        # Get weather data
        weather_msg = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "capture_ui_snapshot",
                "arguments": {
                    "bundleID": "com.apple.weather",
                    "query": {"role": "text"}
                }
            }
        }
        
        print("→ Getting weather data...")
        process.stdin.write(json.dumps(weather_msg) + '\n')
        process.stdin.flush()
        
        weather_response = process.stdout.readline()
        print(f"← Weather response received ({len(weather_response)} chars)")
        
        # Parse response
        try:
            data = json.loads(weather_response)
            if "result" in data and "content" in data["result"]:
                content = data["result"]["content"][0]["text"]
                snapshot_data = json.loads(content)
                
                print(f"\n🌤️ Weather App Data:")
                print(f"Elements found: {len(snapshot_data.get('elements', []))}")
                
                # Extract weather text elements
                weather_texts = []
                for element in snapshot_data.get('elements', []):
                    if element.get('role') == 'Text' and element.get('value'):
                        text = element['value'].strip()
                        if text and len(text) > 0:
                            weather_texts.append(text)
                
                print(f"\n📊 Weather Information:")
                for i, text in enumerate(weather_texts[:20]):  # Show first 20 text elements
                    print(f"  {i+1:2d}. {text}")
                    
                # Look for temperature and weather condition
                temperature = None
                condition = None
                location = None
                
                for text in weather_texts:
                    if '°' in text and any(c.isdigit() for c in text):
                        temperature = text
                    elif any(word in text.lower() for word in ['晴', '曇', '雨', '雪', 'sunny', 'cloudy', 'rain']):
                        condition = text
                    elif len(text) > 1 and not any(c.isdigit() for c in text) and '°' not in text:
                        if not location:
                            location = text
                
                print(f"\n🌡️ Current Weather Summary:")
                if location:
                    print(f"   Location: {location}")
                if temperature:
                    print(f"   Temperature: {temperature}")
                if condition:
                    print(f"   Condition: {condition}")
                    
            else:
                print("❌ No weather data in response")
                
        except json.JSONDecodeError as e:
            print(f"❌ Failed to parse response: {e}")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'process' in locals():
            process.terminate()
            process.wait()
            print("✅ Disconnected")

if __name__ == "__main__":
    main()
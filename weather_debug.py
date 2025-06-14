#!/usr/bin/env python3
"""
Weather Debug Client - Get raw weather response
"""

import json
import subprocess
import sys

def main():
    try:
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
                "clientInfo": {"name": "Weather Debug", "version": "1.0.0"}
            }
        }
        
        process.stdin.write(json.dumps(init_msg) + '\n')
        process.stdin.flush()
        
        init_response = process.stdout.readline()
        print("✅ Initialized")
        
        # Get weather data
        weather_msg = {
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
        
        process.stdin.write(json.dumps(weather_msg) + '\n')
        process.stdin.flush()
        
        weather_response = process.stdout.readline()
        
        # Save raw response to file for analysis
        with open('/Users/1amageek/Desktop/AppMCP/weather_raw.json', 'w') as f:
            f.write(weather_response)
        
        print(f"✅ Raw weather response saved to weather_raw.json ({len(weather_response)} chars)")
        
        # Try to parse and extract weather info
        try:
            data = json.loads(weather_response)
            if "result" in data and "content" in data["result"]:
                content = data["result"]["content"][0]["text"]
                
                # Look for lines that contain weather info
                lines = content.split('\n')
                weather_info = []
                
                for line in lines:
                    line = line.strip()
                    if any(keyword in line for keyword in ['°', '℃', '℉', '晴', '曇', '雨', '雪', 'Sunny', 'Cloudy']):
                        weather_info.append(line)
                    elif any(c.isdigit() for c in line) and len(line) < 20:
                        weather_info.append(line)
                
                print(f"\n🌤️ Weather Information Found:")
                for info in weather_info[:10]:
                    print(f"  - {info}")
                    
                # Also check if it's JSON with elements
                try:
                    snapshot_data = json.loads(content)
                    if 'elements' in snapshot_data:
                        print(f"\n📊 UI Elements: {len(snapshot_data['elements'])}")
                        
                        weather_texts = []
                        for element in snapshot_data.get('elements', []):
                            if element.get('role') == 'Text' and element.get('value'):
                                text = element['value'].strip()
                                if text and (any(c.isdigit() for c in text) or 
                                           any(keyword in text for keyword in ['°', '℃', '℉', '晴', '曇', '雨'])):
                                    weather_texts.append(text)
                        
                        print(f"\n🌡️ Weather Text Elements:")
                        for text in weather_texts[:15]:
                            print(f"  - {text}")
                            
                except json.JSONDecodeError:
                    pass
                    
        except json.JSONDecodeError as e:
            print(f"❌ JSON parse error: {e}")
            print(f"First 200 chars: {weather_response[:200]}")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'process' in locals():
            process.terminate()
            process.wait()

if __name__ == "__main__":
    main()
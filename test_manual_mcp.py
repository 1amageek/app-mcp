#!/usr/bin/env python3

import json
import subprocess
import base64
import time
from datetime import datetime
import os

def send_mcp_request(request):
    """Send a single MCP request and get response"""
    try:
        process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Send the request
        stdout, stderr = process.communicate(input=json.dumps(request) + '\n', timeout=15)
        
        # Print all output for debugging
        print(f"🔍 stdout: {stdout}")
        print(f"🔍 stderr: {stderr}")
        
        # Parse response - look for JSON lines after the startup banner
        lines = stdout.strip().split('\n')
        json_response = None
        
        for line in lines:
            if line.startswith('{'):
                try:
                    json_response = json.loads(line)
                    break
                except:
                    continue
        
        return json_response, stderr
        
    except subprocess.TimeoutExpired:
        process.kill()
        return None, "Request timed out"
    except Exception as e:
        return None, f"Error: {e}"

def test_weather_screenshot():
    print("🧪 Testing Weather App Screenshot via MCP")
    print("==========================================")
    
    # Test screenshot capture
    print("\n📸 Requesting Weather app screenshot...")
    
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "resources/read",
        "params": {
            "uri": "app://app_screenshot"
        }
    }
    
    response, error = send_mcp_request(request)
    
    if error:
        print(f"❌ Error: {error}")
        return False
    
    if response is None:
        print("❌ No response received")
        return False
    
    if "error" in response:
        print(f"❌ MCP Error: {response['error']}")
        return False
    
    if "result" not in response:
        print("❌ No result in response")
        return False
    
    # Parse the result
    result = response["result"]
    if "contents" not in result or not result["contents"]:
        print("❌ No contents in result")
        return False
    
    content = result["contents"][0]
    if "text" not in content:
        print("❌ No text in content")
        return False
    
    # Parse the screenshot data
    try:
        screenshot_data = json.loads(content["text"])
        
        image_data = screenshot_data.get("image_data")
        format_type = screenshot_data.get("format", "unknown")
        width = screenshot_data.get("width", 0)
        height = screenshot_data.get("height", 0)
        capture_method = screenshot_data.get("capture_method", "unknown")
        
        print(f"✅ Screenshot captured successfully!")
        print(f"   Format: {format_type}")
        print(f"   Size: {width} x {height}")
        print(f"   Capture method: {capture_method}")
        print(f"   Data size: {len(image_data) if image_data else 0} characters")
        
        # Save to file
        if image_data and len(image_data) > 100:  # Basic sanity check
            try:
                image_bytes = base64.b64decode(image_data)
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"weather_mcp_screenshot_{timestamp}.png"
                desktop_path = os.path.expanduser("~/Desktop")
                filepath = os.path.join(desktop_path, filename)
                
                with open(filepath, 'wb') as f:
                    f.write(image_bytes)
                
                print(f"   💾 Screenshot saved to: {filepath}")
                print(f"   💾 File size: {len(image_bytes)} bytes")
                
                # Check if it's a real image or placeholder
                if len(image_bytes) < 1000:
                    print("   ⚠️  Warning: Image seems very small, might be a placeholder")
                else:
                    print("   ✅ Image size looks reasonable")
                
                return True
                
            except Exception as e:
                print(f"   ❌ Failed to save screenshot: {e}")
                return False
        else:
            print("   ❌ Invalid or missing image data")
            return False
            
    except json.JSONDecodeError as e:
        print(f"❌ Failed to parse screenshot JSON: {e}")
        return False
    except Exception as e:
        print(f"❌ Error processing screenshot: {e}")
        return False

if __name__ == "__main__":
    success = test_weather_screenshot()
    print(f"\n{'🎉 Test passed!' if success else '❌ Test failed!'}")
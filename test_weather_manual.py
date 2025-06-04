#!/usr/bin/env python3

import json
import subprocess
import base64
import sys
from datetime import datetime

def run_mcp_command(command):
    """Send MCP command to AppMCP server via stdio"""
    try:
        # Start AppMCP server
        process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Send command
        stdout, stderr = process.communicate(input=command, timeout=10)
        
        if stderr:
            print(f"Error: {stderr}")
            return None
            
        return stdout
        
    except subprocess.TimeoutExpired:
        process.kill()
        print("Command timed out")
        return None
    except Exception as e:
        print(f"Error running command: {e}")
        return None

def test_weather_app():
    """Test Weather app screenshot and accessibility tree capture"""
    
    print("🧪 Testing Weather App Initial Screen Capture")
    print("=" * 50)
    
    # Test 1: List running applications to verify Weather app
    print("\n1️⃣ Checking if Weather app is running...")
    
    list_apps_command = json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "resources/read",
        "params": {
            "uri": "running_applications://list"
        }
    }) + "\n"
    
    result = run_mcp_command(list_apps_command)
    if result:
        try:
            response = json.loads(result)
            if "result" in response:
                apps_data = response["result"].get("contents", [])
                if apps_data:
                    apps_text = apps_data[0].get("text", "")
                    apps = json.loads(apps_text)
                    
                    weather_app = None
                    for app in apps:
                        if app.get("bundleId") == "com.apple.weather":
                            weather_app = app
                            break
                    
                    if weather_app:
                        print(f"✅ Weather app found:")
                        print(f"   Name: {weather_app.get('name')}")
                        print(f"   Bundle ID: {weather_app.get('bundleId')}")
                        print(f"   PID: {weather_app.get('pid')}")
                        print(f"   Active: {weather_app.get('isActive')}")
                    else:
                        print("❌ Weather app not found in running applications")
                        return False
                        
        except Exception as e:
            print(f"❌ Error parsing apps response: {e}")
            return False
    else:
        print("❌ Failed to get running applications")
        return False
    
    # Test 2: Capture Weather app screenshot
    print("\n2️⃣ Capturing Weather app screenshot...")
    
    screenshot_command = json.dumps({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "resources/read",
        "params": {
            "uri": "app_screenshot://capture",
            "arguments": {
                "bundle_id": "com.apple.weather"
            }
        }
    }) + "\n"
    
    result = run_mcp_command(screenshot_command)
    if result:
        try:
            response = json.loads(result)
            if "result" in response:
                screenshot_data = response["result"].get("contents", [])
                if screenshot_data:
                    screenshot_text = screenshot_data[0].get("text", "")
                    screenshot_json = json.loads(screenshot_text)
                    
                    format_type = screenshot_json.get("format")
                    width = screenshot_json.get("width")
                    height = screenshot_json.get("height")
                    image_data = screenshot_json.get("image_data")
                    capture_method = screenshot_json.get("capture_method", "unknown")
                    
                    print(f"✅ Screenshot captured successfully:")
                    print(f"   Format: {format_type}")
                    print(f"   Size: {width} x {height}")
                    print(f"   Capture method: {capture_method}")
                    print(f"   Data size: {len(image_data) if image_data else 0} characters (base64)")
                    
                    # Save screenshot to Desktop
                    if image_data:
                        try:
                            image_bytes = base64.b64decode(image_data)
                            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                            filename = f"weather_screenshot_{timestamp}.png"
                            
                            import os
                            desktop_path = os.path.expanduser("~/Desktop")
                            filepath = os.path.join(desktop_path, filename)
                            
                            with open(filepath, 'wb') as f:
                                f.write(image_bytes)
                            
                            print(f"   💾 Screenshot saved to: {filepath}")
                            
                        except Exception as e:
                            print(f"   ⚠️  Could not save screenshot: {e}")
                    
                else:
                    print("❌ No screenshot data received")
                    return False
            else:
                print(f"❌ Screenshot error: {response.get('error', 'Unknown error')}")
                return False
                
        except Exception as e:
            print(f"❌ Error parsing screenshot response: {e}")
            return False
    else:
        print("❌ Failed to capture screenshot")
        return False
    
    # Test 3: Get accessibility tree
    print("\n3️⃣ Extracting accessibility tree...")
    
    ax_tree_command = json.dumps({
        "jsonrpc": "2.0",
        "id": 3,
        "method": "resources/read",
        "params": {
            "uri": "app_accessibility_tree://tree",
            "arguments": {
                "bundle_id": "com.apple.weather"
            }
        }
    }) + "\n"
    
    result = run_mcp_command(ax_tree_command)
    if result:
        try:
            response = json.loads(result)
            if "result" in response:
                ax_data = response["result"].get("contents", [])
                if ax_data:
                    ax_text = ax_data[0].get("text", "")
                    ax_json = json.loads(ax_text)
                    
                    tree_data = ax_json.get("tree")
                    if tree_data:
                        tree_json = json.loads(tree_data)
                        
                        print(f"✅ Accessibility tree extracted:")
                        print(f"   Tree size: {len(tree_data)} characters")
                        
                        # Show tree root info
                        root_role = tree_json.get("role", "unknown")
                        root_title = tree_json.get("title", "")
                        print(f"   Root role: {root_role}")
                        if root_title:
                            print(f"   Root title: {root_title}")
                        
                        # Save AX tree to file
                        try:
                            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                            filename = f"weather_ax_tree_{timestamp}.json"
                            
                            import os
                            desktop_path = os.path.expanduser("~/Desktop")
                            filepath = os.path.join(desktop_path, filename)
                            
                            with open(filepath, 'w', encoding='utf-8') as f:
                                json.dump(tree_json, f, indent=2, ensure_ascii=False)
                            
                            print(f"   💾 AX tree saved to: {filepath}")
                            
                        except Exception as e:
                            print(f"   ⚠️  Could not save AX tree: {e}")
                    
                else:
                    print("❌ No accessibility tree data received")
                    return False
            else:
                print(f"❌ AX tree error: {response.get('error', 'Unknown error')}")
                return False
                
        except Exception as e:
            print(f"❌ Error parsing AX tree response: {e}")
            return False
    else:
        print("❌ Failed to extract accessibility tree")
        return False
    
    print("\n🎉 Weather app initial screen capture test completed successfully!")
    print("Check your Desktop for saved screenshot and accessibility tree files.")
    return True

if __name__ == "__main__":
    success = test_weather_app()
    sys.exit(0 if success else 1)
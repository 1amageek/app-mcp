#!/usr/bin/env python3

import json
import subprocess
import time

def test_weather_mouse_click():
    """Test mouse click functionality with Weather app"""
    
    print("🖱️  Testing Weather App Mouse Click")
    print("==================================")
    
    try:
        process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Test mouse click at center of screen (safe test position)
        # This should be somewhere in the Weather app window
        click_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "mouse_click",
                "arguments": {
                    "x": 400,
                    "y": 300,
                    "button": "left",
                    "click_count": 1
                }
            }
        }
        
        print(f"🎯 Testing mouse click at (400, 300)")
        stdout, stderr = process.communicate(input=json.dumps(click_request) + '\n', timeout=10)
        
        # Print raw output for debugging
        print(f"📋 Raw output: {stdout}")
        if stderr:
            print(f"⚠️ stderr: {stderr}")
        
        # Parse response
        lines = stdout.strip().split('\n')
        json_response = None
        
        for line in lines:
            if line.startswith('{'):
                try:
                    json_response = json.loads(line)
                    break
                except:
                    continue
        
        if not json_response:
            print("❌ No valid JSON response found")
            return False
        
        if "error" in json_response:
            print(f"❌ MCP Error: {json_response['error']}")
            return False
        
        if "result" not in json_response:
            print("❌ No result in response")
            return False
        
        result = json_response["result"]
        
        if result.get("isError", False):
            error_content = result.get("content", [{}])[0].get("text", "Unknown error")
            print(f"❌ Tool Error: {error_content}")
            return False
        
        # Success
        success_content = result.get("content", [{}])[0].get("text", "")
        print(f"✅ Mouse click successful!")
        print(f"   Response: {success_content}")
        
        return True
        
    except subprocess.TimeoutExpired:
        process.kill()
        print("❌ Request timed out")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_keyboard_input():
    """Test keyboard input functionality"""
    
    print(f"\n⌨️  Testing Keyboard Input")
    print("=========================")
    
    try:
        process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Test typing text (this should work if a text field is focused)
        type_request = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "type_text",
                "arguments": {
                    "text": "Tokyo"
                }
            }
        }
        
        print(f"⌨️  Testing typing 'Tokyo'")
        stdout, stderr = process.communicate(input=json.dumps(type_request) + '\n', timeout=10)
        
        # Parse response
        lines = stdout.strip().split('\n')
        json_response = None
        
        for line in lines:
            if line.startswith('{'):
                try:
                    json_response = json.loads(line)
                    break
                except:
                    continue
        
        if not json_response:
            print("❌ No valid JSON response found")
            return False
        
        if "error" in json_response:
            print(f"❌ MCP Error: {json_response['error']}")
            return False
        
        result = json_response["result"]
        
        if result.get("isError", False):
            error_content = result.get("content", [{}])[0].get("text", "Unknown error")
            print(f"❌ Tool Error: {error_content}")
            return False
        
        # Success
        success_content = result.get("content", [{}])[0].get("text", "")
        print(f"✅ Keyboard input successful!")
        print(f"   Response: {success_content}")
        
        return True
        
    except subprocess.TimeoutExpired:
        process.kill()
        print("❌ Request timed out")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Testing Weather App Automation Tools")
    print("=======================================")
    
    # Test mouse click
    click_success = test_weather_mouse_click()
    
    # Test keyboard input  
    keyboard_success = test_keyboard_input()
    
    # Summary
    print(f"\n📊 Test Results:")
    print(f"   Mouse Click: {'✅ PASS' if click_success else '❌ FAIL'}")
    print(f"   Keyboard Input: {'✅ PASS' if keyboard_success else '❌ FAIL'}")
    
    overall_success = click_success and keyboard_success
    print(f"\n{'🎉 All automation tools working!' if overall_success else '⚠️  Some tools need attention'}")
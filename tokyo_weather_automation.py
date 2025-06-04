#!/usr/bin/env python3

import json
import subprocess
import time
from datetime import datetime
import os

class WeatherAppAutomation:
    """Complete automation workflow for Weather app"""
    
    def __init__(self):
        self.process = None
        self.request_id = 1
    
    def start_server(self):
        """Start the MCP server"""
        print("🚀 Starting AppMCP server...")
        self.process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        time.sleep(2)  # Give server time to initialize
        print("✅ Server started")
    
    def send_request(self, method, params):
        """Send MCP request and get response"""
        # Start fresh process for each request to avoid communication issues
        process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        request = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
            "params": params
        }
        self.request_id += 1
        
        stdout, stderr = process.communicate(input=json.dumps(request) + '\n', timeout=15)
        
        # Parse response
        lines = stdout.strip().split('\n')
        for line in lines:
            if line.startswith('{'):
                try:
                    return json.loads(line)
                except:
                    continue
        raise Exception("No valid JSON response found")
    
    def take_screenshot(self):
        """Take screenshot of Weather app"""
        print("📸 Taking screenshot of Weather app...")
        response = self.send_request("resources/read", {
            "uri": "app://app_screenshot"
        })
        
        print(f"🔍 Screenshot response: {json.dumps(response, indent=2)[:500]}...")
        
        if "error" in response:
            raise Exception(f"Screenshot error: {response['error']}")
        
        if "result" not in response:
            raise Exception("No result in screenshot response")
        
        result = response["result"]
        if "contents" not in result or not result["contents"]:
            raise Exception("No contents in screenshot result")
        
        content = result["contents"][0]["text"]
        screenshot_data = json.loads(content)
        
        print(f"🔍 Screenshot data keys: {list(screenshot_data.keys())}")
        
        if screenshot_data.get("success"):
            print("✅ Screenshot captured successfully")
            return screenshot_data
        else:
            print(f"❌ Screenshot failed: {screenshot_data}")
            raise Exception("Screenshot failed")
    
    def get_accessibility_tree(self):
        """Get accessibility tree of Weather app"""
        print("🌳 Getting accessibility tree...")
        response = self.send_request("resources/read", {
            "uri": "app://app_accessibility_tree"
        })
        
        if "error" in response:
            raise Exception(f"Accessibility tree error: {response['error']}")
        
        content = response["result"]["contents"][0]["text"]
        tree_data = json.loads(content)
        
        if "tree" in tree_data:
            print("✅ Accessibility tree retrieved")
            return tree_data["tree"]
        else:
            raise Exception("No tree in accessibility data")
    
    def find_search_field(self, tree):
        """Find the search text field in the accessibility tree"""
        print("🔍 Looking for search field...")
        
        def find_text_fields(node):
            fields = []
            if node.get("role") == "AXTextField":
                fields.append(node)
            for child in node.get("children", []):
                fields.extend(find_text_fields(child))
            return fields
        
        text_fields = find_text_fields(tree)
        if text_fields:
            field = text_fields[0]  # Use first text field
            print(f"✅ Found text field: {field.get('title', 'No title')}")
            return field
        else:
            print("⚠️ No text field found, will try center screen click")
            return None
    
    def click_search_field(self, field=None):
        """Click on the search field or center of screen"""
        if field and field.get("position") and field.get("size"):
            pos = field["position"]
            size = field["size"]
            # Check if position and size have valid values
            if pos.get("x") is not None and pos.get("y") is not None and size.get("width") is not None and size.get("height") is not None:
                x = pos.get("x") + size.get("width") / 2
                y = pos.get("y") + size.get("height") / 2
                print(f"🎯 Clicking search field at ({x}, {y})")
            else:
                # Use estimated position if coordinates are None
                x, y = 400, 200
                print(f"🎯 Position data incomplete, using estimated search area at ({x}, {y})")
        else:
            # Use estimated position for search area
            x, y = 400, 200  # Top center area where search is likely
            print(f"🎯 Clicking estimated search area at ({x}, {y})")
        
        response = self.send_request("tools/call", {
            "name": "mouse_click",
            "arguments": {
                "x": int(x),
                "y": int(y),
                "button": "left",
                "click_count": 1
            }
        })
        
        if response.get("result", {}).get("isError"):
            raise Exception("Mouse click failed")
        
        print("✅ Search field clicked")
        time.sleep(1)  # Wait for UI response
    
    def type_location(self, location):
        """Type the location name"""
        print(f"⌨️ Typing '{location}'...")
        
        response = self.send_request("tools/call", {
            "name": "type_text",
            "arguments": {
                "text": location
            }
        })
        
        if response.get("result", {}).get("isError"):
            raise Exception("Typing failed")
        
        print(f"✅ Typed '{location}'")
        time.sleep(2)  # Wait for search results
    
    def press_enter(self):
        """Press Enter to confirm search"""
        print("⏎ Pressing Enter to search...")
        
        # Type return character to submit search
        response = self.send_request("tools/call", {
            "name": "type_text",
            "arguments": {
                "text": "\n"
            }
        })
        
        if response.get("result", {}).get("isError"):
            raise Exception("Enter key failed")
        
        print("✅ Enter pressed")
        time.sleep(3)  # Wait for weather data to load
    
    def extract_weather_info(self, tree):
        """Extract weather information from the accessibility tree"""
        print("🌤️ Extracting weather information...")
        
        def find_weather_elements(node, weather_info=None):
            if weather_info is None:
                weather_info = []
            
            # Look for elements with weather-related content
            description = node.get("description", "")
            title = node.get("title", "")
            value = node.get("value", "")
            
            content = f"{description} {title} {value}".strip()
            
            # Check for weather indicators
            if any(indicator in content for indicator in ["°", "温度", "風", "湿度", "気温", "天気", "曇り", "晴れ", "雨"]):
                weather_info.append({
                    "role": node.get("role"),
                    "content": content,
                    "description": description,
                    "title": title,
                    "value": value
                })
            
            # Recursively check children
            for child in node.get("children", []):
                find_weather_elements(child, weather_info)
            
            return weather_info
        
        weather_elements = find_weather_elements(tree)
        
        if weather_elements:
            print(f"✅ Found {len(weather_elements)} weather elements")
            return weather_elements
        else:
            print("⚠️ No weather information found")
            return []
    
    def save_results(self, location, weather_info, screenshot_data):
        """Save automation results"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        results = {
            "timestamp": timestamp,
            "location": location,
            "weather_elements": weather_info,
            "screenshot": {
                "has_data": "image_data" in screenshot_data,
                "app_found": screenshot_data.get("app_found", False),
                "success": screenshot_data.get("success", False)
            }
        }
        
        # Save to desktop
        desktop_path = os.path.expanduser("~/Desktop")
        filename = f"tokyo_weather_automation_{timestamp}.json"
        filepath = os.path.join(desktop_path, filename)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        
        print(f"💾 Results saved to: {filepath}")
        return results
    
    def run_complete_workflow(self, location="Tokyo"):
        """Run the complete weather automation workflow"""
        print("🌟 Starting Complete Weather App Automation Workflow")
        print("=" * 55)
        print(f"🎯 Target Location: {location}")
        print()
        
        try:
            # Step 1: Start server
            self.start_server()
            
            # Step 2: Take initial screenshot
            initial_screenshot = self.take_screenshot()
            
            # Step 3: Get accessibility tree
            tree = self.get_accessibility_tree()
            
            # Step 4: Find and click search field
            search_field = self.find_search_field(tree)
            self.click_search_field(search_field)
            
            # Step 5: Type location
            self.type_location(location)
            
            # Step 6: Press Enter to search
            self.press_enter()
            
            # Step 7: Take screenshot after search
            final_screenshot = self.take_screenshot()
            
            # Step 8: Get updated accessibility tree
            updated_tree = self.get_accessibility_tree()
            
            # Step 9: Extract weather information
            weather_info = self.extract_weather_info(updated_tree)
            
            # Step 10: Save results
            results = self.save_results(location, weather_info, final_screenshot)
            
            # Step 11: Display summary
            self.display_summary(location, weather_info)
            
            print("\n🎉 Weather automation workflow completed successfully!")
            return True
            
        except Exception as e:
            print(f"\n❌ Workflow failed: {e}")
            return False
        finally:
            if self.process:
                self.process.terminate()
    
    def display_summary(self, location, weather_info):
        """Display weather information summary"""
        print(f"\n🌤️ Weather Summary for {location}:")
        print("-" * 35)
        
        if weather_info:
            for i, element in enumerate(weather_info[:5], 1):  # Show first 5 elements
                content = element["content"]
                if content and len(content.strip()) > 0:
                    # Clean up content
                    content = content.replace("\n", " ").strip()
                    if len(content) > 80:
                        content = content[:77] + "..."
                    print(f"   {i}. {content}")
        else:
            print("   No weather information found in accessibility tree")

def main():
    automation = WeatherAppAutomation()
    success = automation.run_complete_workflow("Tokyo")
    
    if success:
        print("\n✨ Tokyo weather automation completed successfully!")
    else:
        print("\n💥 Tokyo weather automation failed!")

if __name__ == "__main__":
    main()
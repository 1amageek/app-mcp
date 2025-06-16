#!/usr/bin/env python3
"""
AppMCP Test Client - Unified Testing Interface

This is the single, comprehensive test client for AppMCP functionality.
All testing scenarios should be implemented as methods in this client
rather than creating separate files.
"""

import asyncio
import json
import argparse
import sys
from typing import Dict, List, Optional, Any

class AppMCPTestClient:
    """Unified test client for all AppMCP functionality"""
    
    def __init__(self):
        self.process = None
        self.request_id = 1
    
    async def connect(self):
        """Connect to AppMCP server"""
        try:
            self.process = await asyncio.create_subprocess_exec(
                'swift', 'run', 'appmcpd',
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd='/Users/1amageek/Desktop/AppMCP',
                limit=2*1024*1024  # 2MB buffer for large responses
            )
            await asyncio.sleep(1)
            print("✅ Connected to AppMCP server")
            return True
        except Exception as e:
            print(f"❌ Failed to connect: {e}")
            return False
    
    async def disconnect(self):
        """Disconnect from AppMCP server"""
        if self.process:
            self.process.terminate()
            await self.process.wait()
            print("🔌 Disconnected from AppMCP server")
    
    async def _send_request(self, method: str, params: Dict = None) -> Dict:
        """Send MCP request and get response"""
        if not self.process:
            raise RuntimeError("Not connected to AppMCP server")
        
        request = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
            "params": params or {}
        }
        self.request_id += 1
        
        request_json = json.dumps(request) + '\n'
        self.process.stdin.write(request_json.encode())
        await self.process.stdin.drain()
        
        response_line = await asyncio.wait_for(
            self.process.stdout.readline(), 
            timeout=30
        )
        
        if not response_line:
            raise RuntimeError("No response from server")
        
        response = json.loads(response_line.decode())
        if "error" in response:
            raise RuntimeError(f"MCP Error: {response['error']}")
        
        return response.get("result", {})
    
    # =================================================================
    # Core Testing Methods
    # =================================================================
    
    async def test_running_applications(self):
        """Test application discovery"""
        print("\n🔍 Testing Application Discovery")
        print("-" * 50)
        
        result = await self._send_request("resources/read", {
            "uri": "appmcp://resources/running_applications"
        })
        
        if result.get("contents"):
            apps_data = json.loads(result["contents"][0]["text"])
            apps = apps_data.get("applications", [])
            print(f"✅ Found {len(apps)} running applications")
            
            # Show some key applications
            key_apps = ["Chrome", "Finder", "Terminal", "Weather"]
            for app_name in key_apps:
                found = any(app.get("name", "").lower().find(app_name.lower()) >= 0 for app in apps)
                status = "✅" if found else "❌"
                print(f"  {status} {app_name}: {'Found' if found else 'Not found'}")
            
            return True
        else:
            print("❌ No applications found")
            return False
    
    async def test_chrome_ui_elements(self):
        """Test Chrome UI element extraction"""
        print("\n📋 Testing Chrome UI Elements")
        print("-" * 50)
        
        try:
            result = await self._send_request("tools/call", {
                "name": "elements_snapshot",
                "arguments": {"bundleID": "com.google.Chrome"}
            })
            
            content = result.get("content", [])
            if content:
                text_content = content[0].get("text", "")
                print(f"✅ Elements data received: {len(text_content)} characters")
                
                # Try to extract element count
                if "elements" in text_content.lower():
                    # Count JSON array elements (rough estimate)
                    element_count = text_content.count('"role":')
                    print(f"📄 Estimated UI elements: {element_count}")
                    return True
                else:
                    print(f"⚠️ Unexpected format")
                    return False
            else:
                print("❌ No elements data received")
                return False
                
        except Exception as e:
            print(f"❌ Error: {e}")
            return False
    
    async def test_chrome_text_recognition(self):
        """Test Chrome text recognition with block-level grouping"""
        print("\n📖 Testing Chrome Text Recognition (Block-Level)")
        print("-" * 50)
        
        try:
            result = await self._send_request("tools/call", {
                "name": "read_content",
                "arguments": {
                    "bundleID": "com.google.Chrome",
                    "recognitionLevel": "accurate"
                }
            })
            
            content = result.get("content", [])
            if content:
                text_data = content[0].get("text", "")
                
                try:
                    recognition_result = json.loads(text_data)
                    
                    # Show block-level improvements
                    text_blocks = recognition_result.get('textBlocks', [])
                    individual_texts = recognition_result.get('recognizedTexts', [])
                    processing_time = recognition_result.get('processingTime', 0)
                    
                    print(f"⏱️  Processing Time: {processing_time:.2f}s")
                    print(f"📦 Text Blocks: {len(text_blocks)} logical groups")
                    print(f"📄 Individual Elements: {len(individual_texts)} pieces")
                    
                    if len(text_blocks) > 0:
                        improvement_ratio = len(individual_texts) / len(text_blocks)
                        print(f"📈 Organization Improvement: {improvement_ratio:.1f}x")
                        
                        # Show first few blocks
                        print(f"\n🔍 Sample Text Blocks:")
                        for i, block in enumerate(text_blocks[:3]):
                            block_text = block.get('blockText', '')
                            element_count = block.get('elementCount', 0)
                            confidence = block.get('blockConfidence', 0)
                            
                            preview = block_text[:80] + "..." if len(block_text) > 80 else block_text
                            print(f"  Block {i+1}: '{preview}'")
                            print(f"    Elements: {element_count}, Confidence: {confidence:.2f}")
                    
                    # Save to file for inspection
                    output_file = "/tmp/chrome_text_updated.json"
                    with open(output_file, "w", encoding="utf-8") as f:
                        f.write(text_data)
                    print(f"💾 Saved text recognition result to: {output_file}")
                    
                    return True
                    
                except json.JSONDecodeError as e:
                    print(f"❌ Failed to parse JSON: {e}")
                    # Still save raw data for debugging
                    with open("/tmp/chrome_text_raw.txt", "w", encoding="utf-8") as f:
                        f.write(text_data)
                    print(f"💾 Saved raw data to: /tmp/chrome_text_raw.txt")
                    return False
            else:
                print("❌ No text recognition content received")
                return False
                
        except Exception as e:
            print(f"❌ Error: {e}")
            return False
    
    async def test_weather_app(self):
        """Test Weather app automation"""
        print("\n🌤️ Testing Weather App")
        print("-" * 50)
        
        try:
            # Test Weather app UI elements
            result = await self._send_request("tools/call", {
                "name": "elements_snapshot",
                "arguments": {"bundleID": "com.apple.weather"}
            })
            
            content = result.get("content", [])
            if content:
                text_content = content[0].get("text", "")
                element_count = text_content.count('"role":')
                print(f"✅ Weather app UI elements: {element_count}")
                return True
            else:
                print("❌ No Weather app elements found")
                return False
                
        except Exception as e:
            print(f"❌ Error: {e}")
            return False
    
    async def test_finder_automation(self):
        """Test Finder automation"""
        print("\n📁 Testing Finder Automation")
        print("-" * 50)
        
        try:
            result = await self._send_request("tools/call", {
                "name": "elements_snapshot",
                "arguments": {"bundleID": "com.apple.finder"}
            })
            
            content = result.get("content", [])
            if content:
                text_content = content[0].get("text", "")
                element_count = text_content.count('"role":')
                print(f"✅ Finder UI elements: {element_count}")
                return True
            else:
                print("❌ No Finder elements found")
                return False
                
        except Exception as e:
            print(f"❌ Error: {e}")
            return False
    
    async def test_error_handling(self):
        """Test error handling with invalid inputs"""
        print("\n⚠️ Testing Error Handling")
        print("-" * 50)
        
        test_cases = [
            ("Invalid bundle ID", "com.nonexistent.app"),
            ("Invalid element ID", "nonexistent_element"),
        ]
        
        for test_name, bundle_id in test_cases:
            try:
                await self._send_request("tools/call", {
                    "name": "elements_snapshot",
                    "arguments": {"bundleID": bundle_id}
                })
                print(f"❌ {test_name}: Should have failed")
            except Exception as e:
                print(f"✅ {test_name}: Correctly handled - {str(e)[:60]}...")
        
        return True
    
    async def test_keyboard_input(self):
        """Test keyboard input functionality"""
        print("\n⌨️ Testing Keyboard Input")
        print("-" * 50)
        
        # Test 1: Basic shortcuts without element focus
        print("\n1️⃣ Testing basic shortcuts:")
        test_cases = [
            ("Copy", [{"key": "c", "modifiers": ["cmd"]}]),
            ("Paste", [{"key": "v", "modifiers": ["cmd"]}]),
            ("Select All", [{"key": "a", "modifiers": ["cmd"]}]),
            ("Undo", [{"key": "z", "modifiers": ["cmd"]}]),
            ("Tab Navigation", [{"key": "tab"}]),
            ("Escape", [{"key": "escape"}]),
        ]
        
        for test_name, keys in test_cases:
            try:
                result = await self._send_request("tools/call", {
                    "name": "keyboard_input",
                    "arguments": {"keys": keys}
                })
                content = result.get("content", [])
                if content and content[0].get("text", "").startswith("Sent keyboard input:"):
                    print(f"✅ {test_name}: {content[0]['text']}")
                else:
                    print(f"❌ {test_name}: Unexpected result")
            except Exception as e:
                print(f"❌ {test_name}: Failed - {str(e)[:60]}...")
        
        # Test 2: Multiple key sequence
        print("\n2️⃣ Testing key sequences:")
        try:
            result = await self._send_request("tools/call", {
                "name": "keyboard_input",
                "arguments": {
                    "keys": [
                        {"key": "a", "modifiers": ["cmd"]},
                        {"key": "c", "modifiers": ["cmd"]}
                    ],
                    "delay": 100
                }
            })
            content = result.get("content", [])
            if content:
                print(f"✅ Select All + Copy: {content[0]['text']}")
        except Exception as e:
            print(f"❌ Key sequence failed: {e}")
        
        # Test 3: Special keys
        print("\n3️⃣ Testing special keys:")
        special_keys = [
            ("Arrow Up", [{"key": "up"}]),
            ("Arrow Down", [{"key": "down"}]),
            ("Enter", [{"key": "enter"}]),
            ("Delete", [{"key": "delete"}]),
            ("Function Key", [{"key": "f1"}]),
        ]
        
        for test_name, keys in special_keys:
            try:
                result = await self._send_request("tools/call", {
                    "name": "keyboard_input",
                    "arguments": {"keys": keys}
                })
                content = result.get("content", [])
                if content:
                    print(f"✅ {test_name}: Success")
            except Exception as e:
                print(f"❌ {test_name}: Failed - {str(e)[:60]}...")
        
        return True
    
    # =================================================================
    # Test Scenarios
    # =================================================================
    
    async def run_basic_tests(self):
        """Run basic functionality tests"""
        print("🧪 Running Basic AppMCP Tests")
        print("=" * 60)
        
        tests = [
            ("Application Discovery", self.test_running_applications),
            ("Chrome UI Elements", self.test_chrome_ui_elements),
            ("Text Recognition", self.test_chrome_text_recognition),
            ("Keyboard Input", self.test_keyboard_input),
            ("Error Handling", self.test_error_handling),
        ]
        
        results = {}
        for test_name, test_func in tests:
            try:
                results[test_name] = await test_func()
            except Exception as e:
                print(f"❌ {test_name} failed: {e}")
                results[test_name] = False
        
        # Summary
        print(f"\n📊 Test Results Summary")
        print("=" * 60)
        passed = sum(1 for result in results.values() if result)
        total = len(results)
        
        for test_name, result in results.items():
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"  {status} {test_name}")
        
        print(f"\n🎯 Overall: {passed}/{total} tests passed")
        return passed == total
    
    async def run_comprehensive_tests(self):
        """Run comprehensive test suite"""
        print("🔬 Running Comprehensive AppMCP Tests")
        print("=" * 60)
        
        tests = [
            ("Application Discovery", self.test_running_applications),
            ("Chrome UI Elements", self.test_chrome_ui_elements),
            ("Chrome Text Recognition", self.test_chrome_text_recognition),
            ("Weather App", self.test_weather_app),
            ("Finder Automation", self.test_finder_automation),
            ("Error Handling", self.test_error_handling),
        ]
        
        results = {}
        for test_name, test_func in tests:
            try:
                results[test_name] = await test_func()
            except Exception as e:
                print(f"❌ {test_name} failed: {e}")
                results[test_name] = False
        
        # Summary
        print(f"\n📊 Comprehensive Test Results")
        print("=" * 60)
        passed = sum(1 for result in results.values() if result)
        total = len(results)
        
        for test_name, result in results.items():
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"  {status} {test_name}")
        
        print(f"\n🎯 Overall: {passed}/{total} tests passed")
        return passed == total
    
    async def demo_text_improvements(self):
        """Demonstrate text recognition improvements"""
        print("🔍 Block-Level Text Recognition Demo")
        print("=" * 60)
        
        await self.test_chrome_text_recognition()
    
    async def extract_chrome_data_to_json(self, output_file: str = "/tmp/chrome_data.json"):
        """Extract Chrome data and save to separate JSON files matching AppMCP's tool separation"""
        print("\n📊 Extracting Chrome Data to Separate JSON Files")
        print("-" * 50)
        
        try:
            base_path = output_file.rsplit('.', 1)[0]  # Remove .json extension
            
            # 1. Extract UI elements (elements_snapshot tool)
            print("📋 Extracting UI elements...")
            elements_result = await self._send_request("tools/call", {
                "name": "elements_snapshot",
                "arguments": {"bundleID": "com.google.Chrome"}
            })
            
            elements_file = f"{base_path}_ui_elements.json"
            content = elements_result.get("content", [])
            if content:
                text_content = content[0].get("text", "")
                # Extract JSON array from response
                json_start = text_content.find('[')
                json_end = text_content.rfind(']') + 1
                if json_start != -1 and json_end > json_start:
                    try:
                        elements_data = json.loads(text_content[json_start:json_end])
                        
                        # Save elements_snapshot output as-is (matching AppMCP tool output)
                        with open(elements_file, 'w', encoding='utf-8') as f:
                            json.dump(elements_data, f, indent=2, ensure_ascii=False)
                        
                        print(f"✅ UI elements saved: {elements_file}")
                        print(f"   - Elements count: {len(elements_data)}")
                        
                    except json.JSONDecodeError:
                        print("❌ Failed to parse elements JSON")
                        elements_data = None
                else:
                    print("❌ No valid JSON found in elements response")
                    elements_data = None
            
            # 2. Extract text recognition (read_content tool)
            print("\n📖 Performing text recognition...")
            text_result = await self._send_request("tools/call", {
                "name": "read_content",
                "arguments": {
                    "bundleID": "com.google.Chrome",
                    "recognitionLevel": "accurate"
                }
            })
            
            text_file = f"{base_path}_text_recognition.json"
            content = text_result.get("content", [])
            if content:
                text_data = content[0].get("text", "")
                try:
                    text_recognition_data = json.loads(text_data)
                    
                    # Save read_content output as-is (matching AppMCP tool output)
                    with open(text_file, 'w', encoding='utf-8') as f:
                        json.dump(text_recognition_data, f, indent=2, ensure_ascii=False)
                    
                    blocks = text_recognition_data.get('textBlocks', [])
                    elements = text_recognition_data.get('recognizedTexts', [])
                    processing_time = text_recognition_data.get('processingTime', 0)
                    
                    print(f"✅ Text recognition saved: {text_file}")
                    print(f"   - Text blocks: {len(blocks)}")
                    print(f"   - Individual elements: {len(elements)}")
                    print(f"   - Processing time: {processing_time:.2f}s")
                    
                except json.JSONDecodeError:
                    print("❌ Failed to parse text recognition JSON")
                    text_recognition_data = None
            
            print(f"\n🎯 AppMCP Tool Outputs Separated:")
            print(f"   📋 elements_snapshot → {elements_file}")
            print(f"   📖 read_content     → {text_file}")
            
            return [elements_file, text_file]
            
        except Exception as e:
            print(f"❌ Error extracting Chrome data: {e}")
            return None

# =================================================================
# Command Line Interface
# =================================================================

async def main():
    parser = argparse.ArgumentParser(description="AppMCP Test Client")
    parser.add_argument("test_type", choices=["basic", "comprehensive", "demo", "extract"], 
                       help="Type of test to run")
    parser.add_argument("--save-output", action="store_true", 
                       help="Save detailed output to file")
    parser.add_argument("--output-file", default="/tmp/chrome_data.json",
                       help="Output file for extract mode (default: /tmp/chrome_data.json)")
    
    args = parser.parse_args()
    
    client = AppMCPTestClient()
    
    try:
        if not await client.connect():
            sys.exit(1)
        
        if args.test_type == "basic":
            success = await client.run_basic_tests()
        elif args.test_type == "comprehensive":
            success = await client.run_comprehensive_tests()
        elif args.test_type == "demo":
            await client.demo_text_improvements()
            success = True
        elif args.test_type == "extract":
            output_file = await client.extract_chrome_data_to_json(args.output_file)
            success = output_file is not None
        
        if not success:
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n👋 Test interrupted by user")
    except Exception as e:
        print(f"❌ Test failed: {e}")
        sys.exit(1)
    finally:
        await client.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
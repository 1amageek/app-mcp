#!/usr/bin/env python3

import json
import subprocess
from datetime import datetime
import os

def test_weather_accessibility():
    """Test Weather app accessibility tree extraction"""
    
    print("🌳 Testing Weather App Accessibility Tree")
    print("=========================================")
    
    try:
        process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Request accessibility tree
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "resources/read",
            "params": {
                "uri": "app://app_accessibility_tree"
            }
        }
        
        stdout, stderr = process.communicate(input=json.dumps(request) + '\n', timeout=15)
        
        # Print raw output for debugging
        print(f"📋 Raw output length: {len(stdout)} characters")
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
        
        # Extract accessibility tree
        result = json_response["result"]
        if "contents" not in result or not result["contents"]:
            print("❌ No contents in result")
            return False
        
        content = result["contents"][0]
        if "text" not in content:
            print("❌ No text in content")
            return False
        
        # Parse the accessibility data
        try:
            ax_data = json.loads(content["text"])
            
            if "tree" not in ax_data:
                print("❌ No tree in accessibility data")
                print(f"Available keys: {list(ax_data.keys())}")
                return False
            
            tree = ax_data["tree"]  # Tree is already a dict, not a JSON string
            
            print(f"✅ Accessibility tree extracted successfully!")
            print(f"   Tree keys: {list(tree.keys()) if isinstance(tree, dict) else 'not a dict'}")
            
            # Analyze tree structure
            print(f"\n📊 Tree Analysis:")
            print(f"   Root role: {tree.get('role', 'unknown')}")
            print(f"   Root title: {tree.get('title', 'no title')}")
            
            # Count different UI elements
            def count_elements(node, counts=None):
                if counts is None:
                    counts = {}
                
                role = node.get('role', 'unknown')
                counts[role] = counts.get(role, 0) + 1
                
                for child in node.get('children', []):
                    count_elements(child, counts)
                
                return counts
            
            element_counts = count_elements(tree)
            
            print(f"\n🔍 UI Element Types Found:")
            for role, count in sorted(element_counts.items()):
                print(f"   {role}: {count}")
            
            # Look for key elements we need for weather automation
            def find_elements_by_role(node, target_role, found=None):
                if found is None:
                    found = []
                
                if node.get('role') == target_role:
                    found.append({
                        'title': node.get('title', ''),
                        'value': node.get('value', ''),
                        'position': node.get('position'),
                        'size': node.get('size')
                    })
                
                for child in node.get('children', []):
                    find_elements_by_role(child, target_role, found)
                
                return found
            
            # Look for common UI elements
            buttons = find_elements_by_role(tree, 'AXButton')
            text_fields = find_elements_by_role(tree, 'AXTextField')
            static_texts = find_elements_by_role(tree, 'AXStaticText')
            
            print(f"\n🎯 Key UI Elements for Weather Automation:")
            print(f"   Buttons: {len(buttons)}")
            for i, btn in enumerate(buttons[:5]):  # Show first 5
                title = btn['title'] or 'untitled'
                print(f"     {i+1}. {title}")
            
            print(f"   Text Fields: {len(text_fields)}")
            for i, field in enumerate(text_fields[:3]):  # Show first 3
                title = field['title'] or field['value'] or 'no title'
                print(f"     {i+1}. {title}")
            
            print(f"   Static Texts: {len(static_texts)}")
            for i, text in enumerate(static_texts[:5]):  # Show first 5
                title = text['title'] or text['value'] or 'no title'
                if len(title) > 50:
                    title = title[:47] + "..."
                print(f"     {i+1}. {title}")
            
            # Save complete tree for analysis
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"weather_accessibility_tree_{timestamp}.json"
            desktop_path = os.path.expanduser("~/Desktop")
            filepath = os.path.join(desktop_path, filename)
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(tree, f, indent=2, ensure_ascii=False)
            
            print(f"\n💾 Complete accessibility tree saved to: {filepath}")
            
            return True
            
        except json.JSONDecodeError as e:
            print(f"❌ Failed to parse accessibility JSON: {e}")
            return False
        except Exception as e:
            print(f"❌ Error processing accessibility tree: {e}")
            return False
        
    except subprocess.TimeoutExpired:
        process.kill()
        print("❌ Request timed out")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = test_weather_accessibility()
    print(f"\n{'🎉 Accessibility test passed!' if success else '❌ Accessibility test failed!'}")
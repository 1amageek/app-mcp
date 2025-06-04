#!/usr/bin/env python3

import json
import subprocess
from datetime import datetime
import os

def analyze_weather_ui_elements():
    """Analyze Weather app UI elements using the accessibility tree"""
    
    print("🔍 Analyzing Weather App UI Elements")
    print("====================================")
    
    try:
        # Get accessibility tree
        process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "resources/read",
            "params": {
                "uri": "app://app_accessibility_tree"
            }
        }
        
        stdout, stderr = process.communicate(input=json.dumps(request) + '\n', timeout=15)
        
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
        
        if not json_response or "error" in json_response:
            print(f"❌ Failed to get accessibility tree")
            return False
        
        # Extract tree
        result = json_response["result"]
        content = result["contents"][0]
        tree = json.loads(content["text"])["tree"]
        
        print("✅ Accessibility tree loaded successfully")
        
        # Analyze different types of UI elements
        analyze_actionable_elements(tree)
        analyze_text_elements(tree)
        analyze_weather_specific_elements(tree)
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def analyze_actionable_elements(tree):
    """Find and analyze actionable UI elements"""
    print(f"\n🎯 Actionable UI Elements:")
    print("-" * 30)
    
    # Find buttons
    buttons = find_elements_by_role(tree, "AXButton")
    print(f"📱 Buttons ({len(buttons)}):")
    for i, btn in enumerate(buttons):
        title = btn.get('title', 'No title')
        position = btn.get('position', {})
        enabled = btn.get('enabled', True)
        status = "✅" if enabled else "❌"
        pos_str = f"({position.get('x', '?')}, {position.get('y', '?')})" if position else "No position"
        print(f"   {i+1}. {status} '{title}' at {pos_str}")
    
    # Find text fields  
    text_fields = find_elements_by_role(tree, "AXTextField")
    print(f"\n📝 Text Fields ({len(text_fields)}):")
    for i, field in enumerate(text_fields):
        title = field.get('title', 'No title')
        value = field.get('value', 'No value')
        position = field.get('position', {})
        enabled = field.get('enabled', True)
        status = "✅" if enabled else "❌"
        pos_str = f"({position.get('x', '?')}, {position.get('y', '?')})" if position else "No position"
        print(f"   {i+1}. {status} '{title}' (value: '{value}') at {pos_str}")

def analyze_text_elements(tree):
    """Find and analyze text elements that might contain weather info"""
    print(f"\n📄 Text Elements:")
    print("-" * 20)
    
    static_texts = find_elements_by_role(tree, "AXStaticText")
    print(f"📖 Static Texts ({len(static_texts)}):")
    
    # Group texts by likely content type
    weather_keywords = ['°', 'temperature', 'wind', 'humidity', 'precipitation', '風', '湿度', '降水']
    location_keywords = ['city', 'location', 'place', '都市', '場所', '地域']
    
    weather_texts = []
    location_texts = []
    other_texts = []
    
    for text in static_texts:
        title = text.get('title', '')
        value = text.get('value', '')
        content = f"{title} {value}".strip()
        
        if any(keyword in content.lower() for keyword in weather_keywords):
            weather_texts.append((content, text.get('position', {})))
        elif any(keyword in content.lower() for keyword in location_keywords):
            location_texts.append((content, text.get('position', {})))
        elif content and len(content.strip()) > 0:
            other_texts.append((content, text.get('position', {})))
    
    print(f"   🌡️  Weather-related: {len(weather_texts)}")
    for content, pos in weather_texts[:5]:  # Show first 5
        pos_str = f"({pos.get('x', '?')}, {pos.get('y', '?')})" if pos else "No pos"
        print(f"      '{content[:50]}...' at {pos_str}")
    
    print(f"   📍 Location-related: {len(location_texts)}")
    for content, pos in location_texts[:3]:
        pos_str = f"({pos.get('x', '?')}, {pos.get('y', '?')})" if pos else "No pos"
        print(f"      '{content[:50]}...' at {pos_str}")
    
    print(f"   📝 Other texts: {len(other_texts)}")
    for content, pos in other_texts[:3]:
        pos_str = f"({pos.get('x', '?')}, {pos.get('y', '?')})" if pos else "No pos"
        print(f"      '{content[:30]}...' at {pos_str}")

def analyze_weather_specific_elements(tree):
    """Find elements specifically useful for weather automation"""
    print(f"\n🌤️  Weather Automation Elements:")
    print("-" * 35)
    
    # Look for search-related elements
    search_elements = find_search_elements(tree)
    print(f"🔍 Search Elements ({len(search_elements)}):")
    for i, elem in enumerate(search_elements):
        role = elem.get('role', 'unknown')
        title = elem.get('title', 'No title')
        position = elem.get('position', {})
        size = elem.get('size', {})
        pos_str = f"({position.get('x', '?')}, {position.get('y', '?')})" if position else "No position"
        size_str = f"{size.get('width', '?')}x{size.get('height', '?')}" if size else "No size"
        print(f"   {i+1}. {role} '{title}' at {pos_str} size {size_str}")
        
        # Calculate center point for clicking
        if position and size and position.get('x') is not None and position.get('y') is not None:
            center_x = position.get('x', 0) + size.get('width', 0) / 2
            center_y = position.get('y', 0) + size.get('height', 0) / 2
            print(f"      → Click center: ({center_x:.0f}, {center_y:.0f})")
        else:
            print(f"      → No valid position/size data")
    
    # Look for navigation elements
    nav_elements = find_navigation_elements(tree)
    print(f"\n🧭 Navigation Elements ({len(nav_elements)}):")
    for i, elem in enumerate(nav_elements[:5]):  # Show first 5
        role = elem.get('role', 'unknown')
        title = elem.get('title', 'No title')
        position = elem.get('position', {})
        pos_str = f"({position.get('x', '?')}, {position.get('y', '?')})" if position else "No position"
        print(f"   {i+1}. {role} '{title}' at {pos_str}")

def find_elements_by_role(node, target_role, found=None):
    """Recursively find all elements with specific role"""
    if found is None:
        found = []
    
    if node.get('role') == target_role:
        found.append(node)
    
    for child in node.get('children', []):
        find_elements_by_role(child, target_role, found)
    
    return found

def find_search_elements(tree):
    """Find elements that might be used for search"""
    search_elements = []
    
    # Look for text fields (likely search boxes)
    text_fields = find_elements_by_role(tree, "AXTextField")
    search_elements.extend(text_fields)
    
    # Look for search fields specifically
    search_fields = find_elements_by_role(tree, "AXSearchField")
    search_elements.extend(search_fields)
    
    # Look for combo boxes (dropdowns)
    combo_boxes = find_elements_by_role(tree, "AXComboBox")
    search_elements.extend(combo_boxes)
    
    return search_elements

def find_navigation_elements(tree):
    """Find elements that might be used for navigation"""
    nav_elements = []
    
    # Buttons that might be for navigation
    buttons = find_elements_by_role(tree, "AXButton")
    nav_elements.extend(buttons)
    
    # Menu items
    menu_items = find_elements_by_role(tree, "AXMenuItem")
    nav_elements.extend(menu_items)
    
    # Menu bar items
    menu_bar_items = find_elements_by_role(tree, "AXMenuBarItem")
    nav_elements.extend(menu_bar_items)
    
    return nav_elements

if __name__ == "__main__":
    success = analyze_weather_ui_elements()
    print(f"\n{'🎉 UI analysis completed!' if success else '❌ UI analysis failed!'}")
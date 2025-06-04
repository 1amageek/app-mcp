#!/usr/bin/env python3

import json
import subprocess

def test_list_resources():
    """Test basic resource listing"""
    print("🧪 Testing MCP Resource Listing")
    print("===============================")
    
    try:
        process = subprocess.Popen(
            ['./appmcpd', '--stdio'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Send list resources request
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "resources/list"
        }
        
        stdout, stderr = process.communicate(input=json.dumps(request) + '\n', timeout=10)
        
        print(f"🔍 stdout: {stdout}")
        print(f"🔍 stderr: {stderr}")
        
        # Parse response
        lines = stdout.strip().split('\n')
        for line in lines:
            if line.startswith('{'):
                try:
                    response = json.loads(line)
                    if "result" in response:
                        resources = response["result"].get("resources", [])
                        print(f"✅ Found {len(resources)} resources:")
                        for resource in resources:
                            print(f"   - {resource.get('name')} ({resource.get('uri')})")
                        return True
                    elif "error" in response:
                        print(f"❌ Error: {response['error']}")
                        return False
                except json.JSONDecodeError:
                    continue
        
        print("❌ No valid JSON response found")
        return False
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    test_list_resources()
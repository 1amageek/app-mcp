#!/usr/bin/env python3
"""
Direct test using echo to send MCP requests
"""
import subprocess
import json
import time
import os

def test_direct_communication():
    """Test direct communication with server"""
    print("🔍 Testing Direct MCP Communication")
    print("=" * 40)
    
    # Create test requests file
    requests = [
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"resources": {}, "tools": {}},
                "clientInfo": {"name": "test", "version": "1.0"}
            }
        },
        {
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        },
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "resources/list"
        }
    ]
    
    # Write requests to temporary file
    temp_file = "/tmp/mcp_requests.json"
    with open(temp_file, 'w') as f:
        for req in requests:
            f.write(json.dumps(req) + '\n')
    
    print(f"📝 Created test file: {temp_file}")
    
    try:
        # Test using cat to pipe requests
        print("1️⃣ Testing with file input...")
        
        result = subprocess.run(
            ['swift', 'run', 'appmcpd'],
            stdin=open(temp_file, 'r'),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=15
        )
        
        print(f"📥 Exit code: {result.returncode}")
        print(f"📥 stderr: {result.stderr[:500]}")
        print(f"📥 stdout lines: {len(result.stdout.split(chr(10)))}")
        
        # Parse stdout for JSON responses
        lines = result.stdout.split('\n')
        json_responses = []
        
        for i, line in enumerate(lines):
            line = line.strip()
            if line.startswith('{"jsonrpc"'):
                try:
                    resp = json.loads(line)
                    json_responses.append(resp)
                    print(f"✅ JSON Response {len(json_responses)}: {resp}")
                except json.JSONDecodeError:
                    print(f"❌ Invalid JSON on line {i}: {line}")
        
        print(f"📊 Found {len(json_responses)} JSON responses")
        
        # Check for resources list
        for resp in json_responses:
            if resp.get('id') == 2 and 'result' in resp:
                resources = resp['result'].get('resources', [])
                print(f"✅ Resources found: {len(resources)}")
                for res in resources:
                    print(f"   • {res.get('name')}")
                
                # Try to read applications
                return test_read_applications()
        
        print("❌ No resources list response found")
        return False
        
    except subprocess.TimeoutExpired:
        print("❌ Request timed out")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    finally:
        # Clean up
        if os.path.exists(temp_file):
            os.remove(temp_file)

def test_read_applications():
    """Test reading applications"""
    print("\n2️⃣ Testing application reading...")
    
    # Create requests for reading applications
    requests = [
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"resources": {}, "tools": {}},
                "clientInfo": {"name": "test", "version": "1.0"}
            }
        },
        {
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        },
        {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "resources/read",
            "params": {
                "uri": "appmcp://resources/running_applications"
            }
        }
    ]
    
    temp_file = "/tmp/mcp_apps_request.json"
    try:
        with open(temp_file, 'w') as f:
            for req in requests:
                f.write(json.dumps(req) + '\n')
        
        result = subprocess.run(
            ['swift', 'run', 'appmcpd'],
            stdin=open(temp_file, 'r'),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=20
        )
        
        # Parse for application data
        lines = result.stdout.split('\n')
        for line in lines:
            line = line.strip()
            if line.startswith('{"jsonrpc"'):
                try:
                    resp = json.loads(line)
                    if resp.get('id') == 3 and 'result' in resp:
                        contents = resp['result'].get('contents', [])
                        if contents and 'text' in contents[0]:
                            app_data = json.loads(contents[0]['text'])
                            apps = app_data.get('applications', [])
                            
                            print(f"✅ Found {len(apps)} running applications:")
                            for i, app in enumerate(apps[:8]):  # Show first 8
                                bundle_id = app.get('bundleId', 'N/A')
                                is_active = app.get('isActive', False)
                                window_count = app.get('windowCount', 0)
                                status = '🟢' if is_active else '⚫'
                                print(f"   {status} {app['name']}")
                                print(f"      Bundle: {bundle_id}")
                                print(f"      Windows: {window_count}")
                                print()
                            
                            if len(apps) > 8:
                                print(f"   ... and {len(apps) - 8} more applications")
                            
                            return True
                except:
                    continue
        
        print("❌ No application data found")
        return False
        
    except Exception as e:
        print(f"❌ Error reading applications: {e}")
        return False
    finally:
        if os.path.exists(temp_file):
            os.remove(temp_file)

if __name__ == "__main__":
    success = test_direct_communication()
    if success:
        print("\n🎉 Direct communication test successful!")
        print("✅ AppMCP server can list running applications!")
    else:
        print("\n❌ Direct communication test failed!")
    
    exit(0 if success else 1)
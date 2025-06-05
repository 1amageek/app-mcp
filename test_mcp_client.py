#!/usr/bin/env python3
"""
Simple MCP client to test AppMCP server functionality
"""
import json
import subprocess
import sys
import time

def send_mcp_request(process, request):
    """Send a JSON-RPC request to the MCP server"""
    request_str = json.dumps(request) + '\n'
    print(f"📤 Sending: {request_str.strip()}")
    
    process.stdin.write(request_str)
    process.stdin.flush()
    
    # Read response
    response_line = process.stdout.readline()
    if response_line:
        try:
            response = json.loads(response_line.strip())
            print(f"📥 Response: {json.dumps(response, indent=2)}")
            return response
        except json.JSONDecodeError as e:
            print(f"❌ JSON decode error: {e}")
            print(f"Raw response: {response_line}")
            return None
    else:
        print("❌ No response received")
        return None

def test_appMCP():
    """Test AppMCP server functionality"""
    print("🚀 Starting AppMCP server test...")
    
    # Start the AppMCP server
    process = subprocess.Popen(
        ['swift', 'run', 'appmcpd'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=0
    )
    
    try:
        # Wait for server to initialize
        time.sleep(2)
        
        # 1. Initialize the MCP connection
        print("\n1️⃣ Initializing MCP connection...")
        init_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "resources": {"subscribe": False},
                    "tools": {}
                },
                "clientInfo": {
                    "name": "test-client",
                    "version": "1.0.0"
                }
            }
        }
        
        init_response = send_mcp_request(process, init_request)
        if not init_response or 'error' in init_response:
            print("❌ Failed to initialize MCP connection")
            return False
        
        # Send initialized notification
        print("\n2️⃣ Sending initialized notification...")
        notification = {
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        }
        send_mcp_request(process, notification)
        
        # 3. List available resources
        print("\n3️⃣ Listing available resources...")
        list_resources_request = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "resources/list"
        }
        
        resources_response = send_mcp_request(process, list_resources_request)
        if resources_response and 'result' in resources_response:
            resources = resources_response['result'].get('resources', [])
            print(f"✅ Found {len(resources)} resources:")
            for resource in resources:
                print(f"   • {resource['name']}: {resource['description']}")
        
        # 4. Test reading running applications resource
        print("\n4️⃣ Testing running_applications resource...")
        read_request = {
            "jsonrpc": "2.0", 
            "id": 3,
            "method": "resources/read",
            "params": {
                "uri": "appmcp://resources/running_applications"
            }
        }
        
        read_response = send_mcp_request(process, read_request)
        if read_response and 'result' in read_response:
            content = read_response['result'].get('contents', [])
            if content and len(content) > 0:
                app_data = json.loads(content[0]['text'])
                apps = app_data.get('applications', [])
                print(f"✅ Found {len(apps)} running applications:")
                for app in apps[:5]:  # Show first 5 apps
                    print(f"   • {app['name']} ({app.get('bundleId', 'unknown')})")
                if len(apps) > 5:
                    print(f"   ... and {len(apps) - 5} more")
            else:
                print("❌ No application data received")
        
        # 5. Test accessible applications (with permissions)
        print("\n5️⃣ Testing accessible_applications resource...")
        accessible_request = {
            "jsonrpc": "2.0",
            "id": 4, 
            "method": "resources/read",
            "params": {
                "uri": "appmcp://resources/accessible_applications"
            }
        }
        
        accessible_response = send_mcp_request(process, accessible_request)
        if accessible_response and 'result' in accessible_response:
            content = accessible_response['result'].get('contents', [])
            if content and len(content) > 0:
                app_data = json.loads(content[0]['text'])
                apps = app_data.get('applications', [])
                accessible_apps = [app for app in apps if app.get('accessibilityOk', False)]
                print(f"✅ Found {len(accessible_apps)} accessible applications:")
                for app in accessible_apps[:3]:  # Show first 3 accessible apps
                    windows = app.get('windows', [])
                    print(f"   • {app['name']} - {len(windows)} windows")
                    if app.get('appHandle'):
                        print(f"     Handle: {app['appHandle']}")
            else:
                print("❌ No accessible application data received")
        
        # 6. List available tools
        print("\n6️⃣ Listing available tools...")
        list_tools_request = {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/list"
        }
        
        tools_response = send_mcp_request(process, list_tools_request)
        if tools_response and 'result' in tools_response:
            tools = tools_response['result'].get('tools', [])
            print(f"✅ Found {len(tools)} tools:")
            for tool in tools:
                print(f"   • {tool['name']}: {tool['description']}")
        
        print("\n🎉 AppMCP server test completed successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False
    
    finally:
        # Clean up
        try:
            process.terminate()
            process.wait(timeout=5)
        except:
            process.kill()

if __name__ == "__main__":
    success = test_appMCP()
    sys.exit(0 if success else 1)
#!/usr/bin/env python3
"""
Test AppMCP server to verify it can list available applications
"""
import json
import subprocess
import sys
import time

def test_appMCP_applications():
    """Test AppMCP server to list applications"""
    print("🚀 Testing AppMCP v0.2 - Application Listing")
    print("=" * 50)
    
    try:
        # Start the AppMCP server
        print("Starting AppMCP server...")
        process = subprocess.Popen(
            ['swift', 'run', 'appmcpd'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0
        )
        
        # Wait for server initialization
        time.sleep(3)
        
        print("\n1️⃣ Initializing MCP connection...")
        
        # Initialize the connection
        init_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "resources": {},
                    "tools": {}
                },
                "clientInfo": {
                    "name": "test-client",
                    "version": "1.0.0"
                }
            }
        }
        
        # Send initialization
        request_str = json.dumps(init_request) + '\n'
        process.stdin.write(request_str)
        process.stdin.flush()
        
        # Read and skip server banner/startup messages
        startup_lines = []
        for _ in range(10):  # Read up to 10 lines of startup output
            try:
                line = process.stdout.readline()
                if not line:
                    break
                startup_lines.append(line.strip())
                if line.strip().startswith('{"jsonrpc"'):
                    init_response = json.loads(line.strip())
                    print(f"✅ Initialization response: {init_response.get('result', {}).get('serverInfo', {}).get('name', 'Unknown')}")
                    break
            except:
                continue
        
        # Send initialized notification
        notification = {
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        }
        
        notif_str = json.dumps(notification) + '\n'
        process.stdin.write(notif_str)
        process.stdin.flush()
        
        print("\n2️⃣ Listing available resources...")
        
        # List resources
        list_request = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "resources/list"
        }
        
        request_str = json.dumps(list_request) + '\n'
        process.stdin.write(request_str)
        process.stdin.flush()
        
        # Read response
        response_line = process.stdout.readline()
        if response_line.strip():
            try:
                response = json.loads(response_line.strip())
                if 'result' in response:
                    resources = response['result'].get('resources', [])
                    print(f"✅ Found {len(resources)} resources:")
                    for res in resources:
                        print(f"   • {res['name']}: {res['description']}")
                else:
                    print(f"❌ Error in resources list: {response}")
                    return False
            except json.JSONDecodeError as e:
                print(f"❌ Failed to parse response: {e}")
                print(f"Raw response: {response_line}")
                return False
        
        print("\n3️⃣ Testing running applications resource...")
        
        # Request running applications
        apps_request = {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "resources/read",
            "params": {
                "uri": "appmcp://resources/running_applications"
            }
        }
        
        request_str = json.dumps(apps_request) + '\n'
        process.stdin.write(request_str)
        process.stdin.flush()
        
        # Read response
        response_line = process.stdout.readline()
        if response_line.strip():
            try:
                response = json.loads(response_line.strip())
                if 'result' in response:
                    contents = response['result'].get('contents', [])
                    if contents:
                        app_data = json.loads(contents[0]['text'])
                        applications = app_data.get('applications', [])
                        print(f"✅ Found {len(applications)} running applications:")
                        
                        # Show first 10 applications
                        for i, app in enumerate(applications[:10]):
                            status = "🟢" if app.get('isActive') else "⚪"
                            bundle_id = app.get('bundleId', 'Unknown')
                            print(f"   {status} {app['name']} ({bundle_id})")
                        
                        if len(applications) > 10:
                            print(f"   ... and {len(applications) - 10} more applications")
                        
                        return True
                    else:
                        print("❌ No content in response")
                        return False
                else:
                    print(f"❌ Error reading applications: {response}")
                    return False
            except json.JSONDecodeError as e:
                print(f"❌ Failed to parse applications response: {e}")
                print(f"Raw response: {response_line}")
                return False
        
        print("❌ No response received for applications request")
        return False
        
    except Exception as e:
        print(f"❌ Test failed with exception: {e}")
        return False
    
    finally:
        # Clean up
        try:
            process.terminate()
            process.wait(timeout=3)
        except:
            process.kill()

if __name__ == "__main__":
    success = test_appMCP_applications()
    if success:
        print("\n🎉 Application listing test completed successfully!")
    else:
        print("\n❌ Application listing test failed!")
    
    sys.exit(0 if success else 1)
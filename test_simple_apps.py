#!/usr/bin/env python3
"""
Simple test to check if AppMCP can list applications
"""
import json
import subprocess
import sys

def test_simple():
    """Simple test without complex MCP protocol"""
    print("🧪 Simple AppMCP Application Test")
    print("=" * 35)
    
    try:
        # Test 1: Just run the server with list capabilities
        print("1️⃣ Testing server capabilities...")
        result = subprocess.run(
            ['swift', 'run', 'appmcpd', '--list-capabilities'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            print("✅ Server capabilities:")
            lines = result.stdout.split('\n')
            in_resources = False
            in_tools = False
            
            for line in lines:
                if 'Available Resources:' in line:
                    in_resources = True
                    in_tools = False
                    continue
                elif 'Available Tools:' in line:
                    in_resources = False
                    in_tools = True
                    continue
                elif line.startswith('💡'):
                    break
                
                if in_resources and line.strip().startswith('•'):
                    print(f"   📋 {line.strip()}")
                elif in_tools and line.strip().startswith('•'):
                    print(f"   🔧 {line.strip()}")
        else:
            print(f"❌ Server failed: {result.stderr}")
            return False
        
        # Test 2: Try a direct resource request with timeout
        print("\n2️⃣ Testing MCP resource request...")
        
        # Create MCP requests
        init_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "test", "version": "1.0"}
            }
        }
        
        list_request = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "resources/list"
        }
        
        # Prepare input
        requests = [
            json.dumps(init_request),
            json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}),
            json.dumps(list_request)
        ]
        input_data = '\n'.join(requests) + '\n'
        
        print(f"📤 Sending requests...")
        
        process = subprocess.Popen(
            ['swift', 'run', 'appmcpd'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        try:
            stdout, stderr = process.communicate(input=input_data, timeout=15)
            
            print(f"📥 Server output received")
            print(f"🔍 stderr: {stderr[:500]}")  # First 500 chars
            
            # Look for JSON responses in stdout
            lines = stdout.split('\n')
            responses = []
            
            for line in lines:
                line = line.strip()
                if line.startswith('{"jsonrpc"'):
                    try:
                        resp = json.loads(line)
                        responses.append(resp)
                    except:
                        continue
            
            print(f"✅ Found {len(responses)} JSON responses")
            
            # Look for resources list response
            for resp in responses:
                if resp.get('id') == 2 and 'result' in resp:
                    resources = resp['result'].get('resources', [])
                    print(f"✅ Found {len(resources)} resources:")
                    for res in resources:
                        print(f"   • {res.get('name', 'Unknown')}")
                    
                    # Try to read applications
                    return test_read_apps()
            
            print("❌ No resources list found in responses")
            return False
            
        except subprocess.TimeoutExpired:
            process.kill()
            print("❌ Request timed out")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_read_apps():
    """Test reading running applications"""
    print("\n3️⃣ Testing application reading...")
    
    try:
        # Create request sequence
        requests = [
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
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
        
        input_data = '\n'.join(json.dumps(req) for req in requests) + '\n'
        
        process = subprocess.Popen(
            ['swift', 'run', 'appmcpd'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        stdout, stderr = process.communicate(input=input_data, timeout=20)
        
        # Parse responses
        lines = stdout.split('\n')
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
                            
                            print(f"✅ Successfully read {len(apps)} running applications:")
                            for i, app in enumerate(apps[:5]):  # Show first 5
                                bundle_id = app.get('bundleId', 'Unknown')
                                is_active = app.get('isActive', False)
                                status = '🟢 Active' if is_active else '⚪ Background'
                                print(f"   {i+1}. {app['name']} ({bundle_id}) - {status}")
                            
                            if len(apps) > 5:
                                print(f"   ... and {len(apps) - 5} more applications")
                            
                            return True
                except:
                    continue
        
        print("❌ No application data found in response")
        return False
        
    except Exception as e:
        print(f"❌ Error reading applications: {e}")
        return False

if __name__ == "__main__":
    success = test_simple()
    if success:
        print("\n🎉 Application listing test successful!")
    else:
        print("\n❌ Application listing test failed!")
    
    sys.exit(0 if success else 1)
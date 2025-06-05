#!/usr/bin/env python3
"""
Debug AppMCP server communication
"""
import json
import subprocess
import time

def debug_mcp_communication():
    """Debug MCP communication step by step"""
    print("🔍 Debugging AppMCP Communication")
    print("=" * 35)
    
    try:
        print("1️⃣ Starting server...")
        process = subprocess.Popen(
            ['swift', 'run', 'appmcpd'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0
        )
        
        # Give server time to start
        time.sleep(2)
        
        print("2️⃣ Sending initialize request...")
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
                    "name": "debug-client",
                    "version": "1.0.0"
                }
            }
        }
        
        request_json = json.dumps(init_request) + '\n'
        print(f"📤 Sending: {request_json.strip()}")
        
        process.stdin.write(request_json)
        process.stdin.flush()
        
        print("3️⃣ Reading server response...")
        
        # Read server startup output
        for i in range(20):  # Read up to 20 lines
            try:
                line = process.stdout.readline()
                if not line:
                    print(f"   Line {i}: EOF reached")
                    break
                
                line = line.strip()
                print(f"   Line {i}: {line}")
                
                # Check if it's a JSON response
                if line.startswith('{"jsonrpc"'):
                    try:
                        response = json.loads(line)
                        print(f"✅ Found JSON response: {response}")
                        
                        if 'result' in response:
                            server_info = response['result'].get('serverInfo', {})
                            print(f"   Server: {server_info.get('name', 'Unknown')} v{server_info.get('version', '?')}")
                            
                            # Send initialized notification
                            print("\n4️⃣ Sending initialized notification...")
                            notif = {
                                "jsonrpc": "2.0",
                                "method": "notifications/initialized"
                            }
                            
                            notif_json = json.dumps(notif) + '\n'
                            process.stdin.write(notif_json)
                            process.stdin.flush()
                            
                            # Request resources
                            print("\n5️⃣ Requesting resources list...")
                            list_req = {
                                "jsonrpc": "2.0",
                                "id": 2,
                                "method": "resources/list"
                            }
                            
                            list_json = json.dumps(list_req) + '\n'
                            process.stdin.write(list_json)
                            process.stdin.flush()
                            
                            # Read response
                            resp_line = process.stdout.readline()
                            print(f"📥 Resources response: {resp_line.strip()}")
                            
                            if resp_line.strip():
                                try:
                                    resp = json.loads(resp_line.strip())
                                    if 'result' in resp:
                                        resources = resp['result'].get('resources', [])
                                        print(f"✅ Found {len(resources)} resources")
                                        return True
                                except json.JSONDecodeError as e:
                                    print(f"❌ JSON error: {e}")
                            
                            return False
                        
                    except json.JSONDecodeError as e:
                        print(f"   ❌ JSON decode error: {e}")
                        continue
                        
            except Exception as e:
                print(f"   Error reading line {i}: {e}")
                break
        
        print("❌ No valid JSON response received")
        
        # Check if process is still running
        if process.poll() is None:
            print("   Server is still running")
        else:
            print(f"   Server exited with code {process.returncode}")
            stderr = process.stderr.read()
            print(f"   stderr: {stderr}")
        
        return False
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False
    
    finally:
        if 'process' in locals():
            try:
                process.terminate()
                process.wait(timeout=3)
            except:
                process.kill()

if __name__ == "__main__":
    success = debug_mcp_communication()
    print(f"\n{'✅ Debug successful' if success else '❌ Debug failed'}")
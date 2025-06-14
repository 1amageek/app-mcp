#!/usr/bin/env python3
"""
AppMCP Test Client

A Python client to test the AppMCP server functionality.
This client connects to the appmcpd process via STDIO and tests MCP protocol communication.
"""

import json
import subprocess
import sys
import asyncio
from typing import Dict, Any, Optional, List
import uuid


class MCPClient:
    """MCP Protocol Client for testing AppMCP"""
    
    def __init__(self, executable_path: str = "./.build/arm64-apple-macosx/debug/appmcpd"):
        self.executable_path = executable_path
        self.process: Optional[subprocess.Popen] = None
        self.request_id = 0
    
    async def start(self):
        """Connect to existing AppMCP daemon process via stdin/stdout"""
        try:
            # Connect to already running appmcpd via stdin/stdout
            self.process = subprocess.Popen(
                ["cat"],  # Use cat as a pass-through for stdin/stdout
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=0
            )
            print(f"✅ Connected to appmcpd via stdin/stdout")
        except Exception as e:
            print(f"❌ Failed to connect to appmcpd: {e}")
            raise
    
    def stop(self):
        """Stop the AppMCP daemon process"""
        if self.process:
            self.process.terminate()
            self.process.wait()
            print("✅ Stopped appmcpd process")
    
    def _get_next_id(self) -> int:
        """Get next request ID"""
        self.request_id += 1
        return self.request_id
    
    def _send_request(self, method: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Send MCP request and get response"""
        if not self.process:
            raise RuntimeError("Process not started")
        
        request = {
            "jsonrpc": "2.0",
            "id": self._get_next_id(),
            "method": method
        }
        
        if params:
            request["params"] = params
        
        # Send request
        request_json = json.dumps(request) + "\n"
        print(f"→ Sending: {request_json.strip()}")
        
        self.process.stdin.write(request_json)
        self.process.stdin.flush()
        
        # Read response
        response_line = self.process.stdout.readline()
        print(f"← Received: {response_line.strip()}")
        
        if not response_line:
            raise RuntimeError("No response received")
        
        try:
            response = json.loads(response_line)
            return response
        except json.JSONDecodeError as e:
            raise RuntimeError(f"Invalid JSON response: {e}")
    
    def initialize(self) -> Dict[str, Any]:
        """Initialize MCP connection"""
        params = {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "roots": {
                    "listChanged": True
                },
                "sampling": {}
            },
            "clientInfo": {
                "name": "AppMCP Test Client",
                "version": "1.0.0"
            }
        }
        return self._send_request("initialize", params)
    
    def list_tools(self) -> Dict[str, Any]:
        """List available tools"""
        return self._send_request("tools/list")
    
    def list_resources(self) -> Dict[str, Any]:
        """List available resources"""
        return self._send_request("resources/list")
    
    def call_tool(self, name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Call a specific tool"""
        params = {
            "name": name,
            "arguments": arguments
        }
        return self._send_request("tools/call", params)
    
    def read_resource(self, uri: str) -> Dict[str, Any]:
        """Read a resource"""
        params = {
            "uri": uri
        }
        return self._send_request("resources/read", params)


def print_separator(title: str):
    """Print a section separator"""
    print("\n" + "="*60)
    print(f" {title}")
    print("="*60)


def print_json(data: Dict[str, Any], title: str = ""):
    """Pretty print JSON data"""
    if title:
        print(f"\n{title}:")
    print(json.dumps(data, indent=2, ensure_ascii=False))


async def test_basic_protocol(client: MCPClient):
    """Test basic MCP protocol functionality"""
    print_separator("Testing Basic MCP Protocol")
    
    # Initialize
    print("\n🔧 Initializing MCP connection...")
    init_response = client.initialize()
    print_json(init_response, "Initialize Response")
    
    # List tools
    print("\n🛠️ Listing available tools...")
    tools_response = client.list_tools()
    print_json(tools_response, "Tools Response")
    
    # List resources
    print("\n📦 Listing available resources...")
    resources_response = client.list_resources()
    print_json(resources_response, "Resources Response")
    
    return tools_response, resources_response


async def test_resources(client: MCPClient):
    """Test resource reading functionality"""
    print_separator("Testing Resources")
    
    # Test running applications resource
    print("\n📱 Reading running applications...")
    try:
        apps_response = client.read_resource("appmcp://resources/running_applications")
        print_json(apps_response, "Running Applications")
    except Exception as e:
        print(f"❌ Error reading running applications: {e}")
    
    # Test application windows resource
    print("\n🪟 Reading application windows...")
    try:
        windows_response = client.read_resource("appmcp://resources/application_windows")
        print_json(windows_response, "Application Windows")
    except Exception as e:
        print(f"❌ Error reading application windows: {e}")


async def test_tools(client: MCPClient):
    """Test tool calling functionality"""
    print_separator("Testing Tools")
    
    # Test capture_ui_snapshot
    print("\n📸 Testing capture_ui_snapshot...")
    try:
        snapshot_response = client.call_tool("capture_ui_snapshot", {
            "bundleID": "com.apple.finder"
        })
        print_json(snapshot_response, "UI Snapshot Response")
    except Exception as e:
        print(f"❌ Error capturing UI snapshot: {e}")
    
    # Test wait_time
    print("\n⏰ Testing wait_time...")
    try:
        wait_response = client.call_tool("wait_time", {
            "duration": 1000
        })
        print_json(wait_response, "Wait Response")
    except Exception as e:
        print(f"❌ Error with wait_time: {e}")


async def main():
    """Main test function"""
    print_separator("AppMCP Test Client")
    print("Testing connection to appmcpd...")
    
    client = MCPClient()
    
    try:
        # Start the daemon
        await client.start()
        
        # Test basic protocol
        tools_response, resources_response = await test_basic_protocol(client)
        
        # Test resources
        await test_resources(client)
        
        # Test tools
        await test_tools(client)
        
        print_separator("Test Summary")
        print("✅ All tests completed successfully!")
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        return 1
    
    finally:
        client.stop()
    
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
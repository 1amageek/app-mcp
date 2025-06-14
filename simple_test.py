#!/usr/bin/env python3
"""
Simple AppMCP Test - for use with already running appmcpd

This script sends MCP messages to stdin and reads responses from stdout.
Use it when appmcpd is already running and listening on stdin/stdout.
"""

import json
import sys


def send_mcp_request(method: str, params=None, request_id=1):
    """Send MCP request to stdin and read response from stdout"""
    request = {
        "jsonrpc": "2.0",
        "id": request_id,
        "method": method
    }
    
    if params:
        request["params"] = params
    
    # Send request
    request_json = json.dumps(request)
    print(f"→ Sending: {request_json}", file=sys.stderr)
    print(request_json, flush=True)
    
    # Read response
    response_line = input()
    print(f"← Received: {response_line}", file=sys.stderr)
    
    try:
        response = json.loads(response_line)
        return response
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON response: {e}", file=sys.stderr)
        return None


def main():
    """Main test function"""
    print("=== AppMCP Simple Test ===", file=sys.stderr)
    print("Testing connection to running appmcpd...", file=sys.stderr)
    
    # Test 1: Initialize
    print("\n🔧 Initializing MCP connection...", file=sys.stderr)
    init_params = {
        "protocolVersion": "2024-11-05",
        "capabilities": {
            "roots": {"listChanged": True},
            "sampling": {}
        },
        "clientInfo": {
            "name": "Simple AppMCP Test",
            "version": "1.0.0"
        }
    }
    
    init_response = send_mcp_request("initialize", init_params, 1)
    if init_response:
        print(f"✅ Initialize successful: {init_response.get('result', {}).get('serverInfo', {}).get('name', 'Unknown')}", file=sys.stderr)
    
    # Test 2: List tools
    print("\n🛠️ Listing tools...", file=sys.stderr)
    tools_response = send_mcp_request("tools/list", None, 2)
    if tools_response and "result" in tools_response:
        tools = tools_response["result"].get("tools", [])
        print(f"✅ Found {len(tools)} tools:", file=sys.stderr)
        for tool in tools:
            print(f"  - {tool['name']}: {tool.get('description', 'No description')}", file=sys.stderr)
    
    # Test 3: List resources
    print("\n📦 Listing resources...", file=sys.stderr)
    resources_response = send_mcp_request("resources/list", None, 3)
    if resources_response and "result" in resources_response:
        resources = resources_response["result"].get("resources", [])
        print(f"✅ Found {len(resources)} resources:", file=sys.stderr)
        for resource in resources:
            print(f"  - {resource['uri']}: {resource.get('description', 'No description')}", file=sys.stderr)
    
    # Test 4: Test a simple tool
    print("\n⏰ Testing wait_time tool...", file=sys.stderr)
    wait_params = {
        "name": "wait_time",
        "arguments": {"duration": 0.5}
    }
    wait_response = send_mcp_request("tools/call", wait_params, 4)
    if wait_response and "result" in wait_response:
        print("✅ wait_time tool executed successfully", file=sys.stderr)
    
    print("\n=== Test Complete ===", file=sys.stderr)


if __name__ == "__main__":
    main()
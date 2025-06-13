#!/usr/bin/env python3
import subprocess
import json
import sys

def send_find_elements():
    """Find all elements in Weather app"""
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "find_elements",
            "arguments": {
                "bundleID": "com.apple.weather",
                "limit": 30
            }
        }
    }
    
    try:
        process = subprocess.Popen(
            ['swift', 'run', 'appmcpd'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd='/Users/1amageek/Desktop/AppMCP'
        )
        
        request_json = json.dumps(request) + '\n'
        stdout, stderr = process.communicate(input=request_json, timeout=10)
        
        if stderr:
            print(f"Error: {stderr}", file=sys.stderr)
        
        if stdout.strip():
            try:
                lines = stdout.strip().split('\n')
                for line in lines:
                    if line.strip() and line.startswith('{'):
                        response = json.loads(line)
                        return response
            except json.JSONDecodeError as e:
                print(f"JSON decode error: {e}")
                print(f"Raw output: {stdout}")
                return None
        
        return None
        
    except subprocess.TimeoutExpired:
        process.kill()
        print("Request timed out")
        return None
    except Exception as e:
        print(f"Error: {e}")
        return None

if __name__ == "__main__":
    print("=== Checking Weather App Elements ===")
    response = send_find_elements()
    
    if response:
        result = response.get("result", {})
        if "content" in result and len(result["content"]) > 0:
            content = result["content"][0].get("text", "No content")
            print("Elements found in Weather app:")
            print(content)
        else:
            print("No content found in response")
            print("Full response:", response)
    else:
        print("No response received")
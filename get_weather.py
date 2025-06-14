#!/usr/bin/env python3
import json
import sys

# Initialize
init_msg = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize", 
    "params": {
        "protocolVersion": "2024-11-05",
        "capabilities": {"roots": {"listChanged": True}, "sampling": {}},
        "clientInfo": {"name": "Weather Reader", "version": "1.0.0"}
    }
}

# Get weather text
weather_msg = {
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
        "name": "capture_ui_snapshot",
        "arguments": {
            "bundleID": "com.apple.weather",
            "query": {"role": "text"}
        }
    }
}

print(json.dumps(init_msg))
print(json.dumps(weather_msg))
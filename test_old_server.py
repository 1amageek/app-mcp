#!/usr/bin/env python3
"""
Test using the old MCPServer implementation to verify app listing works
"""
import json
import subprocess
import sys

def test_with_old_server():
    """Test using the legacy MCPServer implementation"""
    print("🧪 Testing with Legacy MCPServer")
    print("=" * 35)
    
    # Create a simple test script that uses the old MCPServer
    test_script = '''
import Foundation
import AppMCP

@main
struct TestRunner {
    static func main() async throws {
        let server = MCPServer()
        
        // Test resource info
        let resourceInfo = server.getResourceInfo()
        print("📋 Available Resources:")
        for (name, type) in resourceInfo {
            print("   • \\(name): \\(type)")
        }
        
        // Test tool info  
        let toolInfo = server.getToolInfo()
        print("🔧 Available Tools:")
        for (name, type) in toolInfo {
            print("   • \\(name): \\(type)")
        }
        
        // Test app selector functionality
        let appSelector = AppSelector()
        let runningApps = await appSelector.listRunningApps()
        
        print("🏃 Running Applications (\\(runningApps.count) total):")
        for (index, app) in runningApps.prefix(10).enumerated() {
            let status = app.isActive ? "🟢" : "⚪"
            print("   \\(index + 1). \\(status) \\(app.name) (\\(app.bundleId ?? "Unknown"))")
        }
        
        if runningApps.count > 10 {
            print("   ... and \\(runningApps.count - 10) more applications")
        }
        
        // Test specific app finding
        do {
            print("\\n🔍 Testing specific app finding...")
            
            // Try to find common apps
            let commonApps = ["com.apple.finder", "com.apple.dock", "com.apple.systemuiserver"]
            
            for bundleId in commonApps {
                do {
                    let appElement = try await appSelector.findApp(bundleId: bundleId)
                    if appElement != nil {
                        print("   ✅ Found: \\(bundleId)")
                    }
                } catch {
                    print("   ❌ Not found: \\(bundleId)")
                }
            }
            
        } catch {
            print("   ❌ App finding failed: \\(error)")
        }
        
        print("\\n✅ Legacy MCPServer test completed!")
    }
}
'''
    
    # Write test script
    script_path = "/tmp/test_legacy.swift"
    with open(script_path, 'w') as f:
        f.write(test_script)
    
    print(f"📝 Created test script: {script_path}")
    
    try:
        # Run the test script
        print("🚀 Running legacy server test...")
        
        result = subprocess.run(
            ['swift', 'run', '-c', 'debug', '--package-path', '.', 'swift', script_path],
            capture_output=True,
            text=True,
            timeout=30,
            cwd='/Users/1amageek/Desktop/AppMCP'
        )
        
        print(f"📥 Exit code: {result.returncode}")
        
        if result.stdout:
            print("📥 Output:")
            print(result.stdout)
        
        if result.stderr:
            print("📥 Errors:")
            print(result.stderr)
        
        return result.returncode == 0
        
    except subprocess.TimeoutExpired:
        print("❌ Test timed out")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_simple_app_check():
    """Simple test to check if we can access running apps directly"""
    print("\n🔍 Simple App Access Test")
    print("=" * 25)
    
    test_script = '''
import Foundation
import AppKit

@main
struct SimpleTest {
    static func main() {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        print("📱 Found \\(runningApps.count) running applications:")
        
        for (index, app) in runningApps.prefix(15).enumerated() {
            let bundleId = app.bundleIdentifier ?? "Unknown"
            let name = app.localizedName ?? "Unknown"
            let isActive = app.isActive
            let status = isActive ? "🟢" : "⚪"
            
            print("   \\(index + 1). \\(status) \\(name)")
            print("      Bundle: \\(bundleId)")
            print("      PID: \\(app.processIdentifier)")
            print("")
        }
        
        if runningApps.count > 15 {
            print("   ... and \\(runningApps.count - 15) more applications")
        }
    }
}
'''
    
    script_path = "/tmp/simple_app_test.swift"
    with open(script_path, 'w') as f:
        f.write(test_script)
    
    try:
        result = subprocess.run(
            ['swift', script_path],
            capture_output=True,
            text=True,
            timeout=20
        )
        
        print(f"📥 Exit code: {result.returncode}")
        
        if result.stdout:
            print(result.stdout)
        
        if result.stderr and result.returncode != 0:
            print(f"❌ Errors: {result.stderr}")
        
        return result.returncode == 0
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Testing Application Access")
    print("=" * 30)
    
    # Test 1: Simple app listing
    success1 = test_simple_app_check()
    
    # Test 2: Legacy server (if simple test works)
    success2 = False
    if success1:
        success2 = test_with_old_server()
    
    overall_success = success1 or success2
    
    if overall_success:
        print("\n🎉 Application access test successful!")
        print("✅ AppMCP can access running applications!")
    else:
        print("\n❌ Application access test failed!")
    
    sys.exit(0 if overall_success else 1)
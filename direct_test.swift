import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

// Direct test without MCP protocol to verify basic functionality
func testWeatherAppDirectly() async {
    print("🧪 Direct Weather App Test")
    print("===========================")
    
    // Check if Weather app is running
    print("\n1️⃣ Checking Weather app status...")
    let runningApps = NSWorkspace.shared.runningApplications
    let weatherApp = runningApps.first { $0.bundleIdentifier == "com.apple.weather" }
    
    if let weather = weatherApp {
        print("✅ Weather app found:")
        print("   Bundle ID: \(weather.bundleIdentifier ?? "unknown")")
        print("   Name: \(weather.localizedName ?? "unknown")")
        print("   PID: \(weather.processIdentifier)")
        print("   Active: \(weather.isActive)")
        print("   Hidden: \(weather.isHidden)")
    } else {
        print("❌ Weather app not found")
        return
    }
    
    // Test accessibility access
    print("\n2️⃣ Testing accessibility access...")
    let trusted = AXIsProcessTrusted()
    print("   Accessibility trusted: \(trusted)")
    
    if trusted {
        let appElement = AXUIElementCreateApplication(weatherApp!.processIdentifier)
        
        // Get windows
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        if result == .success, let windows = windowsRef as? [AXUIElement], !windows.isEmpty {
            print("✅ Found \(windows.count) window(s)")
            
            // Get first window properties
            let window = windows[0]
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            
            if let title = titleRef as? String {
                print("   Main window title: '\(title)'")
            }
            
            // Get window position and size
            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            
            if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
               AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success {
                
                var point = CGPoint.zero
                var windowSize = CGSize.zero
                
                if let position = positionRef,
                   let size = sizeRef,
                   AXValueGetValue(position as! AXValue, .cgPoint, &point),
                   AXValueGetValue(size as! AXValue, .cgSize, &windowSize) {
                    
                    print("   Window bounds: (\(Int(point.x)), \(Int(point.y))) \(Int(windowSize.width))x\(Int(windowSize.height))")
                }
            }
        } else {
            print("❌ No windows found or accessibility access failed")
        }
    }
    
    // Test screen recording permission
    print("\n3️⃣ Testing screen recording permission...")
    let hasScreenRecording = CGPreflightScreenCaptureAccess()
    print("   Screen recording permission: \(hasScreenRecording)")
    
    print("\n🎉 Direct test completed!")
}

// Run the test
await testWeatherAppDirectly()
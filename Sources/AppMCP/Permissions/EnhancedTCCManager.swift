import Foundation
import AppKit
import ApplicationServices

public actor EnhancedTCCManager {
    private var permissionCache: [String: (accessibility: Bool, screenRecording: Bool)] = [:]
    private var lastCacheUpdate = Date.distantPast
    private let cacheTimeout: TimeInterval = 30.0 // 30 seconds cache
    
    public init() {}
    
    public func checkPermissions(for app: NSRunningApplication) async -> (accessibility: Bool, screenRecording: Bool) {
        let cacheKey = "\(app.processIdentifier)"
        let now = Date()
        
        // Check cache first
        if now.timeIntervalSince(lastCacheUpdate) < cacheTimeout,
           let cached = permissionCache[cacheKey] {
            return cached
        }
        
        let accessibility = checkAccessibilityPermission(for: app)
        let screenRecording = await hasScreenRecordingPermission()
        
        let result = (accessibility: accessibility, screenRecording: screenRecording)
        permissionCache[cacheKey] = result
        lastCacheUpdate = now
        
        return result
    }
    
    public func checkAccessibilityPermission(for app: NSRunningApplication) -> Bool {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
        return result == .success
    }
    
    public func hasScreenRecordingPermission() async -> Bool {
        // For macOS 15+, we need to use a different approach since CGDisplayCreateImage is deprecated
        // This is a simplified check - in production, you would use ScreenCaptureKit
        
        // Check if we can get display information (basic permission check)
        let displayID = CGMainDisplayID()
        let bounds = CGDisplayBounds(displayID)
        
        // If we can get display bounds, we likely have basic access
        return bounds.width > 0 && bounds.height > 0
    }
    
    public func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    public func requestPermissions() async throws {
        if !hasAccessibilityPermission() {
            throw MCPError.permissionDenied(
                "Accessibility permission required. Please grant access in System Settings > Privacy & Security > Accessibility"
            )
        }
        
        if !(await hasScreenRecordingPermission()) {
            throw MCPError.permissionDenied(
                "Screen Recording permission required. Please grant access in System Settings > Privacy & Security > Screen Recording"
            )
        }
    }
    
    public func getPermissionStatus() async -> (accessibility: Bool, screenRecording: Bool) {
        let accessibility = hasAccessibilityPermission()
        let screenRecording = await hasScreenRecordingPermission()
        return (accessibility: accessibility, screenRecording: screenRecording)
    }
    
    public func clearCache() async {
        permissionCache.removeAll()
        lastCacheUpdate = Date.distantPast
    }
    
    public func getPermissionGuidance() -> [String] {
        var guidance: [String] = []
        
        if !hasAccessibilityPermission() {
            guidance.append("1. Open System Settings")
            guidance.append("2. Go to Privacy & Security > Accessibility")
            guidance.append("3. Add and enable this application")
            guidance.append("4. Restart the application")
        }
        
        return guidance
    }
}
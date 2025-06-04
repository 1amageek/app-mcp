import Foundation
import AppKit
@preconcurrency import ApplicationServices

public actor AppRegistry {
    private var appHandles: [String: AppHandleData] = [:]
    private var windowHandles: [String: WindowHandleData] = [:]
    private var handleCounter = 0
    
    public struct AppHandleData: @unchecked Sendable {
        let handle: String
        let bundleId: String?
        let pid: pid_t
        let axApp: AXUIElement
        let createdAt: Date
        let ttl: TimeInterval = 3600
        
        var isExpired: Bool {
            Date().timeIntervalSince(createdAt) > ttl
        }
    }
    
    public struct WindowHandleData: @unchecked Sendable {
        let handle: String
        let appHandle: String
        let axWindow: AXUIElement
        let createdAt: Date
        
        var isValid: Bool {
            // Check if window still exists
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &value)
            return result == .success
        }
    }
    
    public init() {}
    
    public func generateAppHandle(for app: NSRunningApplication) async throws -> String {
        // Check if we already have a handle for this app
        for (handle, data) in appHandles {
            if data.pid == app.processIdentifier && !data.isExpired {
                return handle
            }
        }
        
        handleCounter += 1
        let handle = "ah_\(String(format: "%04X", handleCounter))"
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        // Verify accessibility
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
        guard result == .success else {
            throw MCPError.permissionDenied("Cannot access application \(app.localizedName ?? "Unknown"). Please grant accessibility permissions.")
        }
        
        appHandles[handle] = AppHandleData(
            handle: handle,
            bundleId: app.bundleIdentifier,
            pid: app.processIdentifier,
            axApp: axApp,
            createdAt: Date()
        )
        
        return handle
    }
    
    public func generateWindowHandle(for window: AXUIElement, appHandle: String) async throws -> String {
        guard appHandles[appHandle] != nil else {
            throw MCPError.invalidParameters("Invalid app handle: \(appHandle)")
        }
        
        handleCounter += 1
        let handle = "wh_\(String(format: "%04X", handleCounter))"
        
        windowHandles[handle] = WindowHandleData(
            handle: handle,
            appHandle: appHandle,
            axWindow: window,
            createdAt: Date()
        )
        
        return handle
    }
    
    public func getApp(handle: String) async throws -> AppHandleData {
        guard let data = appHandles[handle] else {
            throw MCPError.appNotFound(bundleId: nil, name: nil, pid: nil)
        }
        
        if data.isExpired {
            appHandles.removeValue(forKey: handle)
            throw MCPError.appNotFound(bundleId: data.bundleId, name: nil, pid: data.pid)
        }
        
        return data
    }
    
    public func getWindow(handle: String) async throws -> WindowHandleData {
        guard let data = windowHandles[handle] else {
            throw MCPError.windowNotFound(handle: handle)
        }
        
        if !data.isValid {
            windowHandles.removeValue(forKey: handle)
            throw MCPError.windowNotFound(handle: handle)
        }
        
        return data
    }
    
    public func cleanupExpiredHandles() async {
        let now = Date()
        
        // Remove expired app handles
        let expiredAppHandles = appHandles.filter { now.timeIntervalSince($0.value.createdAt) > $0.value.ttl }
        for (handle, _) in expiredAppHandles {
            appHandles.removeValue(forKey: handle)
        }
        
        // Remove window handles for non-existent apps
        let validAppHandles = Set(appHandles.keys)
        windowHandles = windowHandles.filter { validAppHandles.contains($0.value.appHandle) }
        
        // Remove invalid window handles
        let invalidWindowHandles = windowHandles.filter { !$0.value.isValid }
        for (handle, _) in invalidWindowHandles {
            windowHandles.removeValue(forKey: handle)
        }
    }
    
    public func getAllAppHandles() async -> [String: AppHandleData] {
        await cleanupExpiredHandles()
        return appHandles
    }
    
    public func getAllWindowHandles() async -> [String: WindowHandleData] {
        await cleanupExpiredHandles()
        return windowHandles
    }
}
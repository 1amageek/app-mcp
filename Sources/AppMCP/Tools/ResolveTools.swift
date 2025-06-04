import Foundation
import AppKit
@preconcurrency import ApplicationServices

public class ResolveTools {
    private let registry: AppRegistry
    private let tccManager: EnhancedTCCManager
    
    public init(registry: AppRegistry, tccManager: EnhancedTCCManager) {
        self.registry = registry
        self.tccManager = tccManager
    }
    
    // MARK: - Data Structures
    
    public struct ResolveAppParameters: Codable {
        let bundleId: String?
        let processName: String?
        let pid: Int32?
    }
    
    public struct ResolveAppResult: Codable {
        let appHandle: String
        let bundleId: String?
        let name: String
        let pid: Int32
        let windowCount: Int
    }
    
    public struct ResolveWindowParameters: Codable {
        let appHandle: String
        let titleRegex: String?
        let index: Int?
    }
    
    public struct ResolveWindowResult: Codable {
        let windowHandle: String
        let appHandle: String
        let title: String?
        let index: Int
        let frame: CGRect
    }
    
    // MARK: - Tool Implementations
    
    public func resolveApp(arguments: [String: Any]) async throws -> ResolveAppResult {
        // Parse arguments
        let bundleId = arguments["bundle_id"] as? String
        let processName = arguments["process_name"] as? String
        let pid = arguments["pid"] as? Int32
        
        // Validate that at least one parameter is provided
        guard bundleId != nil || processName != nil || pid != nil else {
            throw MCPError.invalidParameters("At least one of bundle_id, process_name, or pid must be provided")
        }
        
        // Find the application
        let app = try findApplication(bundleId: bundleId, processName: processName, pid: pid)
        
        // Check permissions
        let permissions = await tccManager.checkPermissions(for: app)
        guard permissions.accessibility else {
            throw MCPError.permissionDenied("Accessibility permission required for app: \(app.localizedName ?? "Unknown")")
        }
        
        // Generate app handle
        let appHandle = try await registry.generateAppHandle(for: app)
        
        // Get window count
        let windowCount = await getWindowCount(for: app)
        
        return ResolveAppResult(
            appHandle: appHandle,
            bundleId: app.bundleIdentifier,
            name: app.localizedName ?? "Unknown",
            pid: app.processIdentifier,
            windowCount: windowCount
        )
    }
    
    public func resolveWindow(arguments: [String: Any]) async throws -> ResolveWindowResult {
        // Parse arguments
        guard let appHandle = arguments["app_handle"] as? String else {
            throw MCPError.invalidParameters("app_handle is required")
        }
        
        let titleRegex = arguments["title_regex"] as? String
        let index = arguments["index"] as? Int
        
        // Validate that either titleRegex or index is provided
        guard titleRegex != nil || index != nil else {
            throw MCPError.invalidParameters("Either title_regex or index must be provided")
        }
        
        // Get app data
        let appData = try await registry.getApp(handle: appHandle)
        
        // Get windows
        let windows = try getWindows(from: appData.axApp)
        
        guard !windows.isEmpty else {
            throw MCPError.resourceUnavailable("No windows found for application")
        }
        
        // Find the target window
        let (targetWindow, windowIndex) = try findTargetWindow(
            windows: windows,
            titleRegex: titleRegex,
            index: index
        )
        
        // Generate window handle
        let windowHandle = try await registry.generateWindowHandle(for: targetWindow, appHandle: appHandle)
        
        // Get window title and frame
        let title = getWindowTitle(from: targetWindow)
        let frame = try getWindowFrame(from: targetWindow)
        
        return ResolveWindowResult(
            windowHandle: windowHandle,
            appHandle: appHandle,
            title: title,
            index: windowIndex,
            frame: frame
        )
    }
    
    // MARK: - Helper Methods
    
    private func findApplication(bundleId: String?, processName: String?, pid: Int32?) throws -> NSRunningApplication {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Search by PID first (most specific)
        if let pid = pid {
            for app in runningApps {
                if app.processIdentifier == pid {
                    return app
                }
            }
            throw MCPError.appNotFound(bundleId: bundleId, name: processName, pid: pid)
        }
        
        // Search by bundle ID
        if let bundleId = bundleId {
            for app in runningApps {
                if app.bundleIdentifier == bundleId {
                    return app
                }
            }
            throw MCPError.appNotFound(bundleId: bundleId, name: processName, pid: pid)
        }
        
        // Search by process name
        if let processName = processName {
            let matchingApps = runningApps.filter { app in
                return app.localizedName?.localizedCaseInsensitiveContains(processName) == true ||
                       app.bundleURL?.lastPathComponent.localizedCaseInsensitiveContains(processName) == true
            }
            
            if matchingApps.isEmpty {
                throw MCPError.appNotFound(bundleId: bundleId, name: processName, pid: pid)
            }
            
            // If multiple matches, prefer the active one
            if let activeApp = matchingApps.first(where: { $0.isActive }) {
                return activeApp
            }
            
            // Otherwise, return the first match
            return matchingApps[0]
        }
        
        throw MCPError.invalidParameters("At least one search parameter must be provided")
    }
    
    private func getWindows(from axApp: AXUIElement) throws -> [AXUIElement] {
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue)
        
        guard result == .success else {
            throw MCPError.resourceUnavailable("Cannot access windows. Check accessibility permissions.")
        }
        
        guard let windows = windowsValue as? [AXUIElement] else {
            throw MCPError.resourceUnavailable("Invalid windows data")
        }
        
        return windows
    }
    
    private func findTargetWindow(
        windows: [AXUIElement],
        titleRegex: String?,
        index: Int?
    ) throws -> (AXUIElement, Int) {
        
        if let index = index {
            // Find by index
            guard index >= 0 && index < windows.count else {
                throw MCPError.invalidParameters("Window index \(index) out of range (0-\(windows.count - 1))")
            }
            return (windows[index], index)
        }
        
        if let titleRegex = titleRegex {
            // Find by title regex
            let regex = try NSRegularExpression(pattern: titleRegex, options: [.caseInsensitive])
            
            for (index, window) in windows.enumerated() {
                if let title = getWindowTitle(from: window) {
                    let range = NSRange(location: 0, length: title.utf16.count)
                    if regex.firstMatch(in: title, options: [], range: range) != nil {
                        return (window, index)
                    }
                }
            }
            
            throw MCPError.resourceUnavailable("No window found matching regex: \(titleRegex)")
        }
        
        throw MCPError.invalidParameters("Either title_regex or index must be provided")
    }
    
    private func getWindowTitle(from window: AXUIElement) -> String? {
        var titleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
        guard result == .success else { return nil }
        return titleValue as? String
    }
    
    private func getWindowFrame(from window: AXUIElement) throws -> CGRect {
        // Get position
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        
        guard positionResult == .success, let position = positionValue as! AXValue? else {
            throw MCPError.resourceUnavailable("Cannot get window position")
        }
        
        var windowOrigin = CGPoint.zero
        guard AXValueGetValue(position, .cgPoint, &windowOrigin) else {
            throw MCPError.resourceUnavailable("Cannot extract window position")
        }
        
        // Get size
        var sizeValue: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
        
        guard sizeResult == .success, let size = sizeValue as! AXValue? else {
            throw MCPError.resourceUnavailable("Cannot get window size")
        }
        
        var windowSize = CGSize.zero
        guard AXValueGetValue(size, .cgSize, &windowSize) else {
            throw MCPError.resourceUnavailable("Cannot extract window size")
        }
        
        return CGRect(origin: windowOrigin, size: windowSize)
    }
    
    private func getWindowCount(for app: NSRunningApplication) async -> Int {
        guard await tccManager.checkAccessibilityPermission(for: app) else { return 0 }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue)
        
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return 0
        }
        
        return windows.count
    }
}
import Foundation
import AppKit
@preconcurrency import ApplicationServices

public class ApplicationResources {
    private let registry: AppRegistry
    private let tccManager: EnhancedTCCManager
    
    public init(registry: AppRegistry, tccManager: EnhancedTCCManager) {
        self.registry = registry
        self.tccManager = tccManager
    }
    
    // MARK: - Data Structures
    
    public struct InstalledApplication: Codable {
        let bundleId: String
        let name: String
        let path: String
        let version: String?
        let isSandboxed: Bool
    }
    
    public struct RunningApplication: Codable {
        let bundleId: String?
        let name: String
        let pid: Int32
        let windowCount: Int
        let isActive: Bool
        let isHidden: Bool
        let activationPolicy: String
    }
    
    public struct AccessibleApplication: Codable {
        let bundleId: String?
        let name: String
        let pid: Int32
        let appHandle: String?
        let accessibilityOk: Bool
        let screenRecordingOk: Bool
        let isActive: Bool
        let isHidden: Bool
        let activationPolicy: String
        let windows: [WindowInfo]
    }
    
    public struct WindowInfo: Codable {
        let windowHandle: String?
        let title: String?
        let isMain: Bool
        let isKey: Bool
        let isMinimized: Bool
        let frame: CGRect
    }
    
    public struct WindowDetail: Codable {
        let windowHandle: String
        let title: String?
        let isMain: Bool
        let isKey: Bool
        let isMinimized: Bool
        let isVisible: Bool
        let frame: CGRect
        let role: String?
        let subrole: String?
    }
    
    // MARK: - Resource Implementations
    
    public func getInstalledApplications() async throws -> String {
        _ = NSWorkspace.shared
        
        // Get Applications folder URLs
        let applicationDirectories = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
        var applications: [InstalledApplication] = []
        
        for directory in applicationDirectories {
            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ).filter { $0.pathExtension == "app" }
                
                for url in urls {
                    if let bundle = Bundle(url: url) {
                        let app = InstalledApplication(
                            bundleId: bundle.bundleIdentifier ?? "unknown",
                            name: bundle.infoDictionary?["CFBundleDisplayName"] as? String ??
                                  bundle.infoDictionary?["CFBundleName"] as? String ??
                                  url.lastPathComponent,
                            path: url.path,
                            version: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
                            isSandboxed: bundle.object(forInfoDictionaryKey: "com.apple.security.app-sandbox") != nil
                        )
                        applications.append(app)
                    }
                }
            } catch {
                // Continue with other directories if one fails
                continue
            }
        }
        
        applications.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        let result = ["applications": applications]
        let data = try JSONEncoder().encode(result)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    public func getRunningApplications() async throws -> String {
        let runningApps = NSWorkspace.shared.runningApplications
        var applications: [RunningApplication] = []
        
        for app in runningApps {
            // Skip system processes
            guard app.activationPolicy != .prohibited else { continue }
            
            let windowCount = await getWindowCount(for: app)
            
            let runningApp = RunningApplication(
                bundleId: app.bundleIdentifier,
                name: app.localizedName ?? "Unknown",
                pid: app.processIdentifier,
                windowCount: windowCount,
                isActive: app.isActive,
                isHidden: app.isHidden,
                activationPolicy: activationPolicyString(app.activationPolicy)
            )
            applications.append(runningApp)
        }
        
        applications.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        let result = ["applications": applications]
        let data = try JSONEncoder().encode(result)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    public func getAccessibleApplications() async throws -> String {
        let runningApps = NSWorkspace.shared.runningApplications
        var accessibleApps: [AccessibleApplication] = []
        
        for app in runningApps {
            guard app.activationPolicy == .regular else { continue }
            
            let permissions = await tccManager.checkPermissions(for: app)
            
            var appHandle: String?
            var windows: [WindowInfo] = []
            
            if permissions.accessibility {
                do {
                    appHandle = try await registry.generateAppHandle(for: app)
                    windows = try await getWindows(for: app, appHandle: appHandle!)
                } catch {
                    // Continue without handle if accessibility fails
                }
            }
            
            let accessibleApp = AccessibleApplication(
                bundleId: app.bundleIdentifier,
                name: app.localizedName ?? "Unknown",
                pid: app.processIdentifier,
                appHandle: appHandle,
                accessibilityOk: permissions.accessibility,
                screenRecordingOk: permissions.screenRecording,
                isActive: app.isActive,
                isHidden: app.isHidden,
                activationPolicy: activationPolicyString(app.activationPolicy),
                windows: windows
            )
            accessibleApps.append(accessibleApp)
        }
        
        accessibleApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        let result = ["applications": accessibleApps]
        let data = try JSONEncoder().encode(result)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    public func getListWindows(appHandle: String) async throws -> String {
        let appData = try await registry.getApp(handle: appHandle)
        
        // Get windows from AX
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appData.axApp, kAXWindowsAttribute as CFString, &windowsValue)
        
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            throw MCPError.resourceUnavailable("Cannot access windows for app")
        }
        
        var windowDetails: [WindowDetail] = []
        
        for (_, window) in windows.enumerated() {
            let windowHandle = try await registry.generateWindowHandle(for: window, appHandle: appHandle)
            let detail = try getWindowDetail(window: window, handle: windowHandle)
            windowDetails.append(detail)
        }
        
        let result_data = ["windows": windowDetails]
        let data = try JSONEncoder().encode(result_data)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - Helper Methods
    
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
    
    private func getWindows(for app: NSRunningApplication, appHandle: String) async throws -> [WindowInfo] {
        let appData = try await registry.getApp(handle: appHandle)
        
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appData.axApp, kAXWindowsAttribute as CFString, &windowsValue)
        
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return []
        }
        
        var windowInfos: [WindowInfo] = []
        
        for window in windows {
            do {
                let windowHandle = try await registry.generateWindowHandle(for: window, appHandle: appHandle)
                let info = try getWindowInfo(window: window, handle: windowHandle)
                windowInfos.append(info)
            } catch {
                // Skip windows that can't be accessed
                continue
            }
        }
        
        return windowInfos
    }
    
    private func getWindowInfo(window: AXUIElement, handle: String) throws -> WindowInfo {
        let title = getStringAttribute(from: window, attribute: kAXTitleAttribute)
        let isMain = getBoolAttribute(from: window, attribute: kAXMainAttribute) ?? false
        let isKey = getBoolAttribute(from: window, attribute: kAXFocusedAttribute) ?? false
        let isMinimized = getBoolAttribute(from: window, attribute: kAXMinimizedAttribute) ?? false
        
        // Get frame
        let frame = try getWindowFrame(from: window)
        
        return WindowInfo(
            windowHandle: handle,
            title: title,
            isMain: isMain,
            isKey: isKey,
            isMinimized: isMinimized,
            frame: frame
        )
    }
    
    private func getWindowDetail(window: AXUIElement, handle: String) throws -> WindowDetail {
        let title = getStringAttribute(from: window, attribute: kAXTitleAttribute)
        let isMain = getBoolAttribute(from: window, attribute: kAXMainAttribute) ?? false
        let isKey = getBoolAttribute(from: window, attribute: kAXFocusedAttribute) ?? false
        let isMinimized = getBoolAttribute(from: window, attribute: kAXMinimizedAttribute) ?? false
        let isVisible = !(getBoolAttribute(from: window, attribute: kAXHiddenAttribute) ?? false)
        let role = getStringAttribute(from: window, attribute: kAXRoleAttribute)
        let subrole = getStringAttribute(from: window, attribute: kAXSubroleAttribute)
        
        // Get frame
        let frame = try getWindowFrame(from: window)
        
        return WindowDetail(
            windowHandle: handle,
            title: title,
            isMain: isMain,
            isKey: isKey,
            isMinimized: isMinimized,
            isVisible: isVisible,
            frame: frame,
            role: role,
            subrole: subrole
        )
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
    
    private func getStringAttribute(from element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }
    
    private func getBoolAttribute(from element: AXUIElement, attribute: String) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? Bool
    }
    
    private func activationPolicyString(_ policy: NSApplication.ActivationPolicy) -> String {
        switch policy {
        case .regular: return "regular"
        case .accessory: return "accessory"
        case .prohibited: return "prohibited"
        @unknown default: return "unknown"
        }
    }
}
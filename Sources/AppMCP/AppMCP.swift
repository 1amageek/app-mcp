import Foundation
import MCP
@preconcurrency import ApplicationServices
import AppKit

// MARK: - Core Protocols

/// Protocol for MCP resource providers that can handle requests and return Value responses
public protocol MCPResourceProvider: Sendable {
    var name: String { get }
    func handle(params: MCP.Value) async throws -> MCP.Value
}

/// Protocol for MCP tool executors that can handle requests and return Value responses
public protocol MCPToolExecutor: Sendable {
    var name: String { get }
    func handle(params: MCP.Value) async throws -> MCP.Value
}

// MARK: - Error Types

/// Standardized error types for AppMCP operations
public enum MCPError: Swift.Error, Sendable {
    case permissionDenied(String)
    case systemError(String)
    case invalidParameters(String)
    case resourceUnavailable(String)
    case appNotFound(String)
    case timeout(String)
}

extension MCPError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .systemError(let message):
            return "System error: \(message)"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .resourceUnavailable(let message):
            return "Resource unavailable: \(message)"
        case .appNotFound(let message):
            return "Application not found: \(message)"
        case .timeout(let message):
            return "Operation timed out: \(message)"
        }
    }
}

// MARK: - App Information

/// Information about a running application
public struct AppInfo: Sendable, Codable {
    public let bundleId: String?
    public let name: String
    public let pid: pid_t
    public let isActive: Bool
    
    public init(bundleId: String?, name: String, pid: pid_t, isActive: Bool) {
        self.bundleId = bundleId
        self.name = name
        self.pid = pid
        self.isActive = isActive
    }
}

// MARK: - App Selector

/// Actor responsible for finding and selecting applications by various criteria
public actor AppSelector: @unchecked Sendable {
    
    /// Find an application by its Bundle ID
    public func findApp(bundleId: String) async throws -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) else {
            throw MCPError.appNotFound("App with bundle ID '\(bundleId)' not found")
        }
        let pid = app.processIdentifier
        return AXUIElementCreateApplication(pid)
    }
    
    /// Find an application by its process name
    public func findApp(processName: String) async throws -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.localizedName == processName }) else {
            throw MCPError.appNotFound("App with process name '\(processName)' not found")
        }
        let pid = app.processIdentifier
        return AXUIElementCreateApplication(pid)
    }
    
    /// Find an application by its process ID
    public func findApp(pid: pid_t) async throws -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        guard runningApps.contains(where: { $0.processIdentifier == pid }) else {
            throw MCPError.appNotFound("App with PID \(pid) not found")
        }
        return AXUIElementCreateApplication(pid)
    }
    
    /// Get PID from AXUIElement
    public func getPid(from element: AXUIElement) async throws -> pid_t {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        guard result == .success else {
            throw MCPError.systemError("Failed to get PID from AXUIElement")
        }
        return pid
    }
    
    /// Get a list of all running applications
    public func listRunningApps() async -> [AppInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        
        return runningApps.map { app in
            let pid = app.processIdentifier
            let isActive = app == frontmostApp
            return AppInfo(
                bundleId: app.bundleIdentifier,
                name: app.localizedName ?? "Unknown",
                pid: pid,
                isActive: isActive
            )
        }
    }
}

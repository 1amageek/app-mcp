import Foundation
import MCP
@preconcurrency import ApplicationServices
import AppKit

// MARK: - Core Protocols

/// A protocol that defines the interface for MCP resource providers.
///
/// Resource providers are responsible for extracting and providing data from macOS applications,
/// such as screenshots, accessibility trees, and application information. They implement the
/// Model Context Protocol's resource interface, allowing AI models to discover and access
/// various types of application data.
///
/// ## Topics
///
/// ### Implementing a Resource Provider
///
/// To create a custom resource provider, implement this protocol and provide:
/// - A unique name identifier
/// - A handler method that processes MCP requests and returns data
///
/// ### Example
///
/// ```swift
/// struct CustomResourceProvider: MCPResourceProvider {
///     var name: String { "custom_data" }
///     
///     func handle(params: MCP.Value) async throws -> MCP.Value {
///         // Extract parameters and return data
///         return .object(["data": .string("example")])
///     }
/// }
/// ```
public protocol MCPResourceProvider: Sendable {
    /// The unique identifier for this resource provider.
    ///
    /// This name is used by MCP clients to identify and request data from this specific
    /// resource provider. Names should be descriptive and follow snake_case convention.
    var name: String { get }
    
    /// Handles an MCP resource request and returns the requested data.
    ///
    /// This method processes incoming requests from MCP clients, extracts any necessary
    /// parameters, performs the required data collection operations, and returns the
    /// results in MCP.Value format.
    ///
    /// - Parameter params: The request parameters provided by the MCP client
    /// - Returns: The requested data wrapped in an MCP.Value
    /// - Throws: MCPError for various failure conditions (permissions, system errors, etc.)
    func handle(params: MCP.Value) async throws -> MCP.Value
}

/// A protocol that defines the interface for MCP tool executors.
///
/// Tool executors are responsible for performing automation actions on macOS applications,
/// such as mouse clicks, keyboard input, and other UI interactions. They implement the
/// Model Context Protocol's tool interface, allowing AI models to discover and execute
/// various automation capabilities.
///
/// ## Topics
///
/// ### Implementing a Tool Executor
///
/// To create a custom tool executor, implement this protocol and provide:
/// - A unique name identifier
/// - A handler method that processes MCP tool calls and performs actions
///
/// ### Example
///
/// ```swift
/// struct CustomToolExecutor: MCPToolExecutor {
///     var name: String { "custom_action" }
///     
///     func handle(params: MCP.Value) async throws -> MCP.Value {
///         // Extract parameters and perform action
///         return .object(["success": .bool(true)])
///     }
/// }
/// ```
public protocol MCPToolExecutor: Sendable {
    /// The unique identifier for this tool executor.
    ///
    /// This name is used by MCP clients to identify and invoke this specific tool.
    /// Names should be descriptive and follow snake_case convention.
    var name: String { get }
    
    /// Handles an MCP tool call request and performs the requested action.
    ///
    /// This method processes incoming tool calls from MCP clients, extracts any necessary
    /// parameters, performs the required automation actions, and returns the results
    /// in MCP.Value format.
    ///
    /// - Parameter params: The tool call parameters provided by the MCP client
    /// - Returns: The action results wrapped in an MCP.Value
    /// - Throws: MCPError for various failure conditions (permissions, system errors, etc.)
    func handle(params: MCP.Value) async throws -> MCP.Value
}

// MARK: - Error Types

/// Standardized error types for AppMCP operations.
///
/// This enumeration defines the various error conditions that can occur during
/// AppMCP operations, providing consistent error handling across all components.
/// Each error case includes an associated message with additional context.
///
/// ## Topics
///
/// ### Permission Errors
/// - ``permissionDenied(_:)``
///
/// ### System Errors
/// - ``systemError(_:)``
/// - ``resourceUnavailable(_:)``
/// - ``appNotFound(_:)``
/// - ``timeout(_:)``
///
/// ### Parameter Errors
/// - ``invalidParameters(_:)``
///
/// ### Usage
///
/// ```swift
/// do {
///     try await performAutomation()
/// } catch MCPError.permissionDenied(let message) {
///     print("Permission error: \(message)")
/// } catch MCPError.appNotFound(let message) {
///     print("App not found: \(message)")
/// }
/// ```
public enum MCPError: Swift.Error, Sendable {
    /// Indicates that the operation was denied due to insufficient permissions.
    ///
    /// This error is typically thrown when:
    /// - Accessibility permission is not granted for UI automation
    /// - Screen Recording permission is not granted for screenshots
    /// - The application lacks necessary TCC permissions
    ///
    /// - Parameter message: A descriptive message explaining the permission requirement
    case permissionDenied(String)
    
    /// Indicates a low-level system error occurred.
    ///
    /// This error is thrown when macOS APIs return error codes or when
    /// system-level operations fail unexpectedly.
    ///
    /// - Parameter message: A descriptive message explaining the system error
    case systemError(String)
    
    /// Indicates that the provided parameters are invalid or malformed.
    ///
    /// This error is thrown when:
    /// - Required parameters are missing from MCP requests
    /// - Parameter values are outside acceptable ranges
    /// - Parameter formats don't match expected schemas
    ///
    /// - Parameter message: A descriptive message explaining the parameter issue
    case invalidParameters(String)
    
    /// Indicates that a requested resource is not available.
    ///
    /// This error is thrown when:
    /// - A resource provider cannot access the requested data
    /// - Network resources are unavailable
    /// - File system resources cannot be read
    ///
    /// - Parameter message: A descriptive message explaining the unavailability
    case resourceUnavailable(String)
    
    /// Indicates that the specified application could not be found.
    ///
    /// This error is thrown when:
    /// - An application with the specified Bundle ID is not running
    /// - A process with the specified name or PID doesn't exist
    /// - Application discovery operations fail
    ///
    /// - Parameter message: A descriptive message including the search criteria
    case appNotFound(String)
    
    /// Indicates that an operation timed out.
    ///
    /// This error is thrown when:
    /// - UI automation operations take too long to complete
    /// - Wait conditions are not met within the specified time limit
    /// - Network operations exceed their timeout period
    ///
    /// - Parameter message: A descriptive message explaining the timeout
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

/// Information about a running macOS application.
///
/// This structure provides comprehensive metadata about applications currently
/// running on the system, including identification information and status.
/// It's used by resource providers and automation tools to target specific
/// applications for interaction.
///
/// ## Topics
///
/// ### Properties
/// - ``bundleId``
/// - ``name``
/// - ``pid``
/// - ``isActive``
///
/// ### Creating App Information
/// - ``init(bundleId:name:pid:isActive:)``
///
/// ### Usage
///
/// ```swift
/// let appInfo = AppInfo(
///     bundleId: "com.apple.weather",
///     name: "Weather",
///     pid: 1234,
///     isActive: true
/// )
/// ```
public struct AppInfo: Sendable, Codable {
    /// The application's Bundle Identifier.
    ///
    /// This is the reverse-DNS style identifier that uniquely identifies
    /// the application (e.g., "com.apple.weather"). May be nil for some
    /// system processes or applications without proper Bundle IDs.
    public let bundleId: String?
    
    /// The localized display name of the application.
    ///
    /// This is the human-readable name as it appears in the Dock, Finder,
    /// and other system interfaces (e.g., "Weather", "Safari").
    public let name: String
    
    /// The process identifier (PID) of the running application.
    ///
    /// This is a unique integer assigned by macOS to identify the
    /// application process. PIDs are reused when processes terminate.
    public let pid: pid_t
    
    /// Whether this application is currently the frontmost (active) application.
    ///
    /// Only one application can be active at a time. The active application
    /// receives keyboard input and appears in front of other windows.
    public let isActive: Bool
    
    /// Creates a new AppInfo instance with the specified properties.
    ///
    /// - Parameters:
    ///   - bundleId: The application's Bundle Identifier (may be nil)
    ///   - name: The localized display name of the application
    ///   - pid: The process identifier of the running application
    ///   - isActive: Whether this application is currently frontmost
    public init(bundleId: String?, name: String, pid: pid_t, isActive: Bool) {
        self.bundleId = bundleId
        self.name = name
        self.pid = pid
        self.isActive = isActive
    }
}

// MARK: - App Selector

/// An actor that provides thread-safe application discovery and selection functionality.
///
/// AppSelector serves as the central component for finding and interacting with
/// running macOS applications. It uses NSWorkspace and Accessibility APIs to
/// discover applications by various criteria and convert them to AXUIElement
/// references for automation purposes.
///
/// The actor pattern ensures thread-safe access to application discovery operations,
/// which is crucial when multiple MCP clients or automation workflows are running
/// concurrently.
///
/// ## Topics
///
/// ### Finding Applications
/// - ``findApp(bundleId:)``
/// - ``findApp(processName:)``
/// - ``findApp(pid:)``
///
/// ### Application Information
/// - ``listRunningApps()``
/// - ``getPid(from:)``
///
/// ### Usage
///
/// ```swift
/// let appSelector = AppSelector()
///
/// // Find Weather app by Bundle ID
/// let weatherApp = try await appSelector.findApp(bundleId: "com.apple.weather")
///
/// // Find Finder by process name
/// let finder = try await appSelector.findApp(processName: "Finder")
///
/// // List all running applications
/// let apps = await appSelector.listRunningApps()
/// ```
public actor AppSelector: @unchecked Sendable {
    
    /// Creates a new AppSelector instance.
    public init() {}
    
    /// Finds a running application by its Bundle Identifier.
    ///
    /// This method searches through all currently running applications to find one
    /// with the specified Bundle ID. Bundle IDs are reverse-DNS style identifiers
    /// (e.g., "com.apple.weather") that uniquely identify applications.
    ///
    /// - Parameter bundleId: The Bundle Identifier of the application to find
    /// - Returns: An AXUIElement representing the application, or nil if not found
    /// - Throws: ``MCPError/appNotFound(_:)`` if no application with the specified Bundle ID is running
    ///
    /// ### Example
    /// ```swift
    /// let weatherApp = try await appSelector.findApp(bundleId: "com.apple.weather")
    /// ```
    public func findApp(bundleId: String) async throws -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) else {
            throw MCPError.appNotFound("App with bundle ID '\(bundleId)' not found")
        }
        let pid = app.processIdentifier
        return AXUIElementCreateApplication(pid)
    }
    
    /// Finds a running application by its localized process name.
    ///
    /// This method searches through all currently running applications to find one
    /// with the specified localized name. Process names are the human-readable names
    /// as they appear in the Dock and Finder (e.g., "Weather", "Safari").
    ///
    /// - Parameter processName: The localized name of the application to find
    /// - Returns: An AXUIElement representing the application, or nil if not found
    /// - Throws: ``MCPError/appNotFound(_:)`` if no application with the specified name is running
    ///
    /// ### Example
    /// ```swift
    /// let finder = try await appSelector.findApp(processName: "Finder")
    /// ```
    public func findApp(processName: String) async throws -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.localizedName == processName }) else {
            throw MCPError.appNotFound("App with process name '\(processName)' not found")
        }
        let pid = app.processIdentifier
        return AXUIElementCreateApplication(pid)
    }
    
    /// Finds a running application by its process identifier (PID).
    ///
    /// This method verifies that an application with the specified PID is currently
    /// running and returns an AXUIElement for automation purposes. PIDs are unique
    /// integers assigned by macOS to identify running processes.
    ///
    /// - Parameter pid: The process identifier of the application to find
    /// - Returns: An AXUIElement representing the application, or nil if not found
    /// - Throws: ``MCPError/appNotFound(_:)`` if no application with the specified PID is running
    ///
    /// ### Example
    /// ```swift
    /// let app = try await appSelector.findApp(pid: 1234)
    /// ```
    public func findApp(pid: pid_t) async throws -> AXUIElement? {
        let runningApps = NSWorkspace.shared.runningApplications
        guard runningApps.contains(where: { $0.processIdentifier == pid }) else {
            throw MCPError.appNotFound("App with PID \(pid) not found")
        }
        return AXUIElementCreateApplication(pid)
    }
    
    /// Extracts the process identifier (PID) from an AXUIElement.
    ///
    /// This method retrieves the PID associated with an AXUIElement, which can be
    /// useful for correlating accessibility elements with running processes or for
    /// debugging automation workflows.
    ///
    /// - Parameter element: The AXUIElement to extract the PID from
    /// - Returns: The process identifier associated with the element
    /// - Throws: ``MCPError/systemError(_:)`` if the PID cannot be retrieved
    ///
    /// ### Example
    /// ```swift
    /// let weatherApp = try await appSelector.findApp(bundleId: "com.apple.weather")
    /// let pid = try await appSelector.getPid(from: weatherApp)
    /// ```
    public func getPid(from element: AXUIElement) async throws -> pid_t {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        guard result == .success else {
            throw MCPError.systemError("Failed to get PID from AXUIElement")
        }
        return pid
    }
    
    /// Retrieves information about all currently running applications.
    ///
    /// This method provides a comprehensive list of all applications currently running
    /// on the system, including their Bundle IDs, process names, PIDs, and active status.
    /// This is useful for application discovery and for providing users with a list of
    /// available automation targets.
    ///
    /// - Returns: An array of ``AppInfo`` structures containing application metadata
    ///
    /// ### Example
    /// ```swift
    /// let apps = await appSelector.listRunningApps()
    /// for app in apps {
    ///     print("\(app.name) (\(app.bundleId ?? "unknown"))")
    /// }
    /// ```
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

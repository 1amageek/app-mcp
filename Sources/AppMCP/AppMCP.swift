import Foundation
import MCP
import AppPilot

/// AppMCP - Modern macOS UI Automation via Model Context Protocol
///
/// A Swift package that enables AI models to automate macOS applications through
/// element-based UI interaction powered by AppPilot.
///
/// ## Features
/// - Element-based automation (no brittle coordinates)
/// - MCP v0.7.1 protocol support
/// - Native Swift async/await integration
/// - Comprehensive app discovery and window management
///
/// ## Usage
/// ```swift
/// let server = AppMCPServer()
/// try await server.start()
/// ```
public struct AppMCP {
    
    /// Creates a new AppMCP server instance
    public static func createServer() -> AppMCPServer {
        return AppMCPServer()
    }
    
    /// Current version of AppMCP
    public static let version = "1.0.0"
    
    /// MCP protocol version supported
    public static let mcpVersion = "0.7.1"
}

/// Common error types for AppMCP operations
public enum AppMCPError: Swift.Error, Sendable {
    case invalidParameters(String)
    case applicationNotFound(String)
    case windowNotFound(String)
    case elementNotFound(String)
    case permissionDenied(String)
    case systemError(String)
    case missingParameter(String)
    case invalidParameterType(String, expected: String, got: String)
    
    public var localizedDescription: String {
        switch self {
        case .invalidParameters(let msg):
            return "Invalid parameters: \(msg)"
        case .applicationNotFound(let msg):
            return "Application not found: \(msg)"
        case .windowNotFound(let msg):
            return "Window not found: \(msg)"
        case .elementNotFound(let msg):
            return "Element not found: \(msg)"
        case .permissionDenied(let msg):
            return "Permission denied: \(msg)"
        case .systemError(let msg):
            return "System error: \(msg)"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidParameterType(let param, let expected, let got):
            return "Parameter '\(param)' must be \(expected), got \(got)"
        }
    }
}

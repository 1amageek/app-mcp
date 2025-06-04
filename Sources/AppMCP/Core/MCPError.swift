import Foundation

public enum MCPError: Error, CustomStringConvertible, LocalizedError {
    case permissionDenied(String)
    case invalidParameters(String)
    case appNotFound(bundleId: String?, name: String?, pid: Int32?)
    case windowNotFound(handle: String)
    case resourceUnavailable(String)
    case timeout(condition: String, duration: TimeInterval)
    case internalError(String)
    case systemError(String)
    
    public var description: String {
        switch self {
        case .permissionDenied(let detail):
            return "Permission denied: \(detail)"
        case .invalidParameters(let detail):
            return "Invalid parameters: \(detail)"
        case .appNotFound(let bundleId, let name, let pid):
            var parts: [String] = []
            if let bundleId = bundleId { parts.append("bundleId: \(bundleId)") }
            if let name = name { parts.append("name: \(name)") }
            if let pid = pid { parts.append("pid: \(pid)") }
            return "App not found (\(parts.joined(separator: ", ")))"
        case .windowNotFound(let handle):
            return "Window not found: \(handle)"
        case .resourceUnavailable(let detail):
            return "Resource unavailable: \(detail)"
        case .timeout(let condition, let duration):
            return "Timeout waiting for \(condition) after \(duration)s"
        case .internalError(let detail):
            return "Internal error: \(detail)"
        case .systemError(let detail):
            return "System error: \(detail)"
        }
    }
    
    public var errorDescription: String? {
        return description
    }
    
    public var mcpErrorCode: Int {
        switch self {
        case .permissionDenied: return -32001
        case .invalidParameters: return -32602
        case .appNotFound, .windowNotFound: return -32002
        case .resourceUnavailable: return -32003
        case .timeout: return -32004
        case .internalError: return -32603
        case .systemError: return -32603
        }
    }
}
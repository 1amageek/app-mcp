import Foundation
import MCP
@preconcurrency import ApplicationServices
import AppKit

/// Resource provider that extracts accessibility trees from specified applications
public final class AppAXTreeProvider: MCPResourceProvider, @unchecked Sendable {
    
    public let name = "app_accessibility_tree"
    private let appSelector: AppSelector
    private let tccManager: TCCManager
    
    public init(appSelector: AppSelector, tccManager: TCCManager) {
        self.appSelector = appSelector
        self.tccManager = tccManager
    }
    
    public func handle(params: MCP.Value) async throws -> MCP.Value {
        // Ensure accessibility permission
        try await tccManager.ensureAccessibilityPermission()
        
        // Parse parameters from Value
        guard case let .object(paramsDict) = params else {
            throw MCPError.invalidParameters("Parameters must be an object")
        }
        
        // Get the target app
        let appElement: AXUIElement
        if case let .string(bundleId) = paramsDict["bundle_id"] {
            guard let element = try await appSelector.findApp(bundleId: bundleId) else {
                throw MCPError.appNotFound(bundleId: bundleId, name: nil, pid: nil)
            }
            appElement = element
        } else if case let .string(processName) = paramsDict["process_name"] {
            guard let element = try await appSelector.findApp(processName: processName) else {
                throw MCPError.appNotFound(bundleId: nil, name: processName, pid: nil)
            }
            appElement = element
        } else if case let .int(pid) = paramsDict["pid"] {
            guard let element = try await appSelector.findApp(pid: pid_t(pid)) else {
                throw MCPError.appNotFound(bundleId: nil, name: nil, pid: Int32(pid))
            }
            appElement = element
        } else {
            throw MCPError.invalidParameters("Must specify bundle_id, process_name, or pid")
        }
        
        // Extract accessibility tree
        let tree = try extractAccessibilityTree(from: appElement)
        
        // Convert tree to MCP.Value
        let treeValue = convertToValue(tree)
        
        return .object([
            "tree": treeValue
        ])
    }
    
    private func extractAccessibilityTree(from element: AXUIElement, depth: Int = 0, maxDepth: Int = 10) throws -> [String: Any] {
        // Prevent infinite recursion
        guard depth < maxDepth else {
            return ["error": "Max depth reached"]
        }
        
        var elementInfo: [String: Any] = [:]
        
        // Get basic attributes
        elementInfo["role"] = getStringAttribute(element, kAXRoleAttribute as CFString)
        elementInfo["title"] = getStringAttribute(element, kAXTitleAttribute as CFString)
        elementInfo["value"] = getStringAttribute(element, kAXValueAttribute as CFString)
        elementInfo["description"] = getStringAttribute(element, kAXDescriptionAttribute as CFString)
        elementInfo["help"] = getStringAttribute(element, kAXHelpAttribute as CFString)
        elementInfo["identifier"] = getStringAttribute(element, kAXIdentifierAttribute as CFString)
        
        // Get position and size
        if let position = getPositionAttribute(element, kAXPositionAttribute as CFString) {
            elementInfo["position"] = [
                "x": position.x,
                "y": position.y
            ]
        }
        
        if let size = getSizeAttribute(element, kAXSizeAttribute as CFString) {
            elementInfo["size"] = [
                "width": size.width,
                "height": size.height
            ]
        }
        
        // Get boolean attributes
        elementInfo["enabled"] = getBoolAttribute(element, kAXEnabledAttribute as CFString)
        elementInfo["focused"] = getBoolAttribute(element, kAXFocusedAttribute as CFString)
        
        // Get children
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        
        if result == .success, let children = childrenRef as? [AXUIElement] {
            var childrenInfo: [[String: Any]] = []
            
            // Limit number of children to prevent excessive data
            let maxChildren = 50
            let childrenToProcess = Array(children.prefix(maxChildren))
            
            for child in childrenToProcess {
                do {
                    let childInfo = try extractAccessibilityTree(from: child, depth: depth + 1, maxDepth: maxDepth)
                    childrenInfo.append(childInfo)
                } catch {
                    // Skip problematic children
                    continue
                }
            }
            
            elementInfo["children"] = childrenInfo
            elementInfo["children_count"] = children.count
        }
        
        return elementInfo
    }
    
    private func getStringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        
        guard result == .success, let value = valueRef as? String else {
            return nil
        }
        
        return value
    }
    
    private func getBoolAttribute(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        
        guard result == .success, let value = valueRef as? Bool else {
            return nil
        }
        
        return value
    }
    
    private func getPositionAttribute(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        
        guard result == .success,
              CFGetTypeID(valueRef) == AXValueGetTypeID() else {
            return nil
        }
        let value = valueRef as! AXValue
        
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else {
            return nil
        }
        
        return point
    }
    
    private func getSizeAttribute(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        var valueRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &valueRef)
        
        guard result == .success,
              CFGetTypeID(valueRef) == AXValueGetTypeID() else {
            return nil
        }
        let value = valueRef as! AXValue
        
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else {
            return nil
        }
        
        return size
    }
    
    private func convertToValue(_ any: Any) -> MCP.Value {
        switch any {
        case let string as String:
            return .string(string)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let bool as Bool:
            return .bool(bool)
        case let dict as [String: Any]:
            var result: [String: MCP.Value] = [:]
            for (key, value) in dict {
                result[key] = convertToValue(value)
            }
            return .object(result)
        case let array as [Any]:
            return .array(array.map { convertToValue($0) })
        default:
            return .null
        }
    }
}

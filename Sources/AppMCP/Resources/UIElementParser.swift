import Foundation

/// Parser for extracting actionable UI elements from accessibility trees
public struct UIElementParser {
    
    /// Represents a clickable or actionable UI element
    public struct ActionableElement {
        public let role: String
        public let title: String?
        public let value: String?
        public let identifier: String?
        public let position: CGPoint?
        public let size: CGSize?
        public let isEnabled: Bool
        public let path: [String]  // Path to element in tree
        
        public var displayName: String {
            if let title = title, !title.isEmpty {
                return title
            }
            if let value = value, !value.isEmpty {
                return value
            }
            if let identifier = identifier, !identifier.isEmpty {
                return identifier
            }
            return role
        }
        
        public var centerPoint: CGPoint? {
            guard let position = position, let size = size else { return nil }
            return CGPoint(
                x: position.x + size.width / 2,
                y: position.y + size.height / 2
            )
        }
    }
    
    /// Extract all actionable elements from accessibility tree
    public static func extractActionableElements(from tree: [String: Any]) -> [ActionableElement] {
        var elements: [ActionableElement] = []
        extractElements(from: tree, path: [], elements: &elements)
        return elements
    }
    
    /// Find elements by role
    public static func findElements(in tree: [String: Any], role: String) -> [ActionableElement] {
        return extractActionableElements(from: tree).filter { $0.role == role }
    }
    
    /// Find elements by title/value content
    public static func findElements(in tree: [String: Any], containing text: String) -> [ActionableElement] {
        return extractActionableElements(from: tree).filter { element in
            let searchText = text.lowercased()
            return element.title?.lowercased().contains(searchText) == true ||
                   element.value?.lowercased().contains(searchText) == true ||
                   element.identifier?.lowercased().contains(searchText) == true
        }
    }
    
    /// Find clickable elements (buttons, menu items, etc.)
    public static func findClickableElements(in tree: [String: Any]) -> [ActionableElement] {
        let clickableRoles = ["AXButton", "AXMenuItem", "AXMenuBarItem", "AXPopUpButton", "AXCheckBox", "AXRadioButton"]
        return extractActionableElements(from: tree).filter { element in
            clickableRoles.contains(element.role) && element.isEnabled
        }
    }
    
    /// Find text input elements
    public static func findTextInputElements(in tree: [String: Any]) -> [ActionableElement] {
        let inputRoles = ["AXTextField", "AXTextArea", "AXSearchField", "AXComboBox"]
        return extractActionableElements(from: tree).filter { element in
            inputRoles.contains(element.role) && element.isEnabled
        }
    }
    
    /// Find elements that likely represent weather search functionality
    public static func findWeatherSearchElements(in tree: [String: Any]) -> [ActionableElement] {
        let searchKeywords = ["search", "location", "city", "place", "検索", "場所", "都市"]
        return extractActionableElements(from: tree).filter { element in
            let isTextField = ["AXTextField", "AXSearchField", "AXComboBox"].contains(element.role)
            let hasSearchKeyword = searchKeywords.contains { keyword in
                element.title?.lowercased().contains(keyword) == true ||
                element.value?.lowercased().contains(keyword) == true ||
                element.identifier?.lowercased().contains(keyword) == true
            }
            return isTextField || hasSearchKeyword
        }
    }
    
    private static func extractElements(from node: [String: Any], path: [String], elements: inout [ActionableElement]) {
        // Create element from current node
        let role = node["role"] as? String ?? "unknown"
        let title = node["title"] as? String
        let value = node["value"] as? String
        let identifier = node["identifier"] as? String
        let isEnabled = node["enabled"] as? Bool ?? true
        
        // Extract position
        var position: CGPoint?
        if let posData = node["position"] as? [String: Any],
           let x = posData["x"] as? Double,
           let y = posData["y"] as? Double {
            position = CGPoint(x: x, y: y)
        }
        
        // Extract size
        var size: CGSize?
        if let sizeData = node["size"] as? [String: Any],
           let width = sizeData["width"] as? Double,
           let height = sizeData["height"] as? Double {
            size = CGSize(width: width, height: height)
        }
        
        // Only include elements that are actionable or have meaningful content
        let isActionable = isActionableRole(role) || hasmeaningfulContent(title: title, value: value, identifier: identifier)
        
        if isActionable {
            let element = ActionableElement(
                role: role,
                title: title,
                value: value,
                identifier: identifier,
                position: position,
                size: size,
                isEnabled: isEnabled,
                path: path + [role]
            )
            elements.append(element)
        }
        
        // Recursively process children
        if let children = node["children"] as? [[String: Any]] {
            for (index, child) in children.enumerated() {
                extractElements(from: child, path: path + ["\(role)[\(index)]"], elements: &elements)
            }
        }
    }
    
    private static func isActionableRole(_ role: String) -> Bool {
        let actionableRoles = [
            "AXButton", "AXMenuItem", "AXMenuBarItem", "AXPopUpButton",
            "AXTextField", "AXTextArea", "AXSearchField", "AXComboBox",
            "AXCheckBox", "AXRadioButton", "AXLink", "AXTab"
        ]
        return actionableRoles.contains(role)
    }
    
    private static func hasmeaningfulContent(title: String?, value: String?, identifier: String?) -> Bool {
        let meaningfulTexts = [title, value, identifier].compactMap { $0 }.filter { !$0.isEmpty }
        return !meaningfulTexts.isEmpty
    }
}

// MARK: - Helper Extensions

extension UIElementParser.ActionableElement {
    /// Generate a user-friendly description of the element
    public var description: String {
        var parts: [String] = []
        parts.append(role)
        
        if let title = title, !title.isEmpty {
            parts.append("'\(title)'")
        }
        
        if let position = position {
            parts.append("at (\(Int(position.x)), \(Int(position.y)))")
        }
        
        if !isEnabled {
            parts.append("(disabled)")
        }
        
        return parts.joined(separator: " ")
    }
    
    /// Check if element matches search criteria
    public func matches(text: String) -> Bool {
        let searchText = text.lowercased()
        return title?.lowercased().contains(searchText) == true ||
               value?.lowercased().contains(searchText) == true ||
               identifier?.lowercased().contains(searchText) == true
    }
}
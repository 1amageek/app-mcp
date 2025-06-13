import Foundation
import MCP
import AppPilot
import AppKit

// MARK: - AppPilot Compatibility Notes
// AppPilot v3.0+ removed the UIElement.id property
// Use element.identifier for accessibility identifiers
// Use getElementDescription() for user-friendly element descriptions

/// Modern MCP Server for macOS UI automation powered by AppPilot
public final class AppMCPServer: @unchecked Sendable {
    
    private let server: MCP.Server
    private let pilot: AppPilot
    
    public init() {
        // Initialize AppPilot with default drivers
        self.pilot = AppPilot()
        
        self.server = MCP.Server(
            name: "AppMCP",
            version: AppMCP.version,
            capabilities: .init(
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            )
        )
        
        Task { await setupHandlers() }
    }
    
    /// Check if required AppPilot capabilities are available
    private func validateAppPilotCapabilities() async throws {
        // Verify we can list applications (basic capability check)
        do {
            _ = try await pilot.listApplications()
        } catch {
            throw AppMCPError.systemError("AppPilot initialization failed. Ensure accessibility permissions are granted: \(error.localizedDescription)")
        }
    }
    
    private func setupHandlers() async {
        await setupToolHandlers()
        await setupResourceHandlers()
    }
    
    // MARK: - Element Identification Helpers
    
    /// Validate that an element is accessible and can be interacted with
    private func validateElementAccessibility(_ element: AIElement) throws {
        // Check if element has a valid center point
        if element.centerPoint.x == 0 && element.centerPoint.y == 0 {
            throw AppMCPError.elementNotAccessible("Element has no valid position")
        }
        
        // Check bounds if available
        if let bounds = element.bounds, bounds.count >= 4 {
            let width = bounds[2]
            let height = bounds[3]
            if width <= 0 || height <= 0 {
                throw AppMCPError.elementNotAccessible("Element has invalid bounds: width=\(width), height=\(height)")
            }
        }
        
        // Additional validation can be added here as AppPilot API evolves
    }
    
    /// Get a human-readable description for an element for error messages
    private func getElementDescription(_ element: AIElement) -> String {
        if let title = element.title, !title.isEmpty {
            return title
        } else if let identifier = element.identifier, !identifier.isEmpty {
            return identifier
        } else if let value = element.value, !value.isEmpty {
            return value
        } else if let role = element.role {
            return "\(role.rawValue) element"
        } else {
            return "UI element"
        }
    }
    
    // MARK: - Tool Handlers
    
    private func setupToolHandlers() async {
        await server.withMethodHandler(ListTools.self) { _ in
            return ListTools.Result(tools: [
                // Basic Operations
                MCP.Tool(
                    name: "click_element",
                    description: "Click UI elements using element IDs from capture_ui_snapshot",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "elementId": [
                                "type": "string",
                                "description": "Element ID from capture_ui_snapshot"
                            ],
                            "button": [
                                "type": "string",
                                "enum": ["left", "right", "center"],
                                "description": "Mouse button (default: left)"
                            ],
                            "count": [
                                "type": "number",
                                "description": "Click count (default: 1)"
                            ]
                        ],
                        "required": ["elementId"]
                    ]
                ),
                
                MCP.Tool(
                    name: "input_text",
                    description: "Input text into elements using element IDs from capture_ui_snapshot",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "elementId": [
                                "type": "string",
                                "description": "Element ID from capture_ui_snapshot"
                            ],
                            "text": [
                                "type": "string",
                                "description": "Text to input"
                            ],
                            "method": [
                                "type": "string",
                                "enum": ["type", "setValue"],
                                "description": "Input method (default: type)"
                            ]
                        ],
                        "required": ["elementId", "text"]
                    ]
                ),
                
                MCP.Tool(
                    name: "drag_drop",
                    description: "Perform drag and drop operations using element IDs from capture_ui_snapshot",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "fromElementId": [
                                "type": "string",
                                "description": "Source element ID"
                            ],
                            "toElementId": [
                                "type": "string",
                                "description": "Target element ID"
                            ],
                            "duration": [
                                "type": "number",
                                "description": "Duration in seconds (default: 1.0)"
                            ]
                        ],
                        "required": ["fromElementId", "toElementId"]
                    ]
                ),
                
                MCP.Tool(
                    name: "scroll_window",
                    description: "Scroll at element location using element ID from capture_ui_snapshot",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "elementId": [
                                "type": "string",
                                "description": "Element ID for scroll location"
                            ],
                            "deltaX": [
                                "type": "number",
                                "description": "Horizontal scroll amount (default: 0)"
                            ],
                            "deltaY": [
                                "type": "number",
                                "description": "Vertical scroll amount"
                            ]
                        ],
                        "required": ["elementId", "deltaY"]
                    ]
                ),
                
                // Utility Tools
                MCP.Tool(
                    name: "wait_time",
                    description: "Wait for a specified duration",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "duration": [
                                "type": "number",
                                "description": "Wait duration in seconds"
                            ]
                        ],
                        "required": ["duration"]
                    ]
                ),
                
                // UI Snapshot Tool
                MCP.Tool(
                    name: "capture_ui_snapshot",
                    description: "Capture window screenshot and extract clickable element IDs",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "bundleID": [
                                "type": "string",
                                "description": "Application bundle ID"
                            ],
                            "window": [
                                "type": ["string", "number"],
                                "description": "Window title or index (optional)"
                            ]
                        ],
                        "required": ["bundleID"]
                    ]
                ),
                
                // Information Tools
                MCP.Tool(
                    name: "list_running_applications",
                    description: "List running applications with bundle IDs and names",
                    inputSchema: [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                ),
                
                MCP.Tool(
                    name: "list_application_windows",
                    description: "List application windows with titles and coordinates",
                    inputSchema: [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                )
            ])
        }
        
        await server.withMethodHandler(CallTool.self) { params in
            let arguments = params.arguments ?? [:]
            
            switch params.name {
            case "click_element":
                return await self.handleClickElement(arguments)
            case "input_text":
                return await self.handleInputText(arguments)
            case "drag_drop":
                return await self.handleDragDrop(arguments)
            case "scroll_window":
                return await self.handleScrollWindow(arguments)
            case "capture_ui_snapshot":
                return await self.handleCaptureUISnapshot(arguments)
            case "wait_time":
                return await self.handleWaitTime(arguments)
            case "list_running_applications":
                return await self.handleListRunningApplications(arguments)
            case "list_application_windows":
                return await self.handleListApplicationWindows(arguments)
            default:
                return CallTool.Result(
                    content: [.text("Unknown tool: \(params.name)")],
                    isError: true
                )
            }
        }
    }
    
    // MARK: - Tool Handler Methods
    
    internal func handleClickElement(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performClick(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "click_element")
        }
    }
    
    internal func handleInputText(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            guard case .string(_) = arguments["text"] else {
                throw AppMCPError.invalidParameters("Missing 'text' parameter")
            }
            
            let method = extractOptionalString(from: arguments, key: "method") ?? "type"
            let clearFirst = extractOptionalBool(from: arguments, key: "clearFirst") ?? false
            
            let result: String
            if method == "setValue" {
                result = try await performSetText(arguments)
            } else {
                result = try await performType(arguments, clearFirst: clearFirst)
            }
            
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "input_text")
        }
    }
    
    internal func handleDragDrop(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performDrag(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "drag_drop")
        }
    }
    
    internal func handleScrollWindow(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performScroll(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "scroll_window")
        }
    }
    
    internal func handleCaptureUISnapshot(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performUISnapshot(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "capture_ui_snapshot")
        }
    }
    
    internal func handleWaitTime(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performWait(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "wait_time")
        }
    }
    
    internal func handleListRunningApplications(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await getApplications()
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "list_running_applications")
        }
    }
    
    internal func handleListApplicationWindows(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await getWindows()
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "list_application_windows")
        }
    }
    
    
    
    // MARK: - Action Implementations
    
    private func performClick(_ arguments: [String: MCP.Value]) async throws -> String {
        let elementId = try extractRequiredString(from: arguments, key: "elementId")
        let buttonType = extractOptionalString(from: arguments, key: "button") ?? "left"
        let count = extractOptionalDouble(from: arguments, key: "count").map { Int($0) } ?? 1
        
        // Convert button type to MouseButton
        let mouseButton: MouseButton = {
            switch buttonType {
            case "right": return .right
            case "center": return .center
            default: return .left
            }
        }()
        
        // Use AppPilot's element ID method
        let result = try await pilot.click(elementID: elementId)
        
        // For non-default button/count, use coordinate-based clicking
        if buttonType != "left" || count != 1 {
            guard let element = result.element else {
                throw AppMCPError.systemError("Failed to get element info for advanced click")
            }
            
            // Use coordinate-based click with specified button and count
            _ = try await pilot.click(at: element.centerPoint, button: mouseButton, count: count)
            
            let buttonDesc = buttonType == "left" ? "" : " (\(buttonType) button)"
            let countDesc = count == 1 ? "" : " \(count) times"
            
            return "Clicked\(buttonDesc) element ID '\(elementId)'\(countDesc) at (\(element.centerPoint.x), \(element.centerPoint.y))"
        }
        
        return "Clicked element ID '\(elementId)'"
    }
    
    private func extractRequiredDouble(from arguments: [String: MCP.Value], key: String) throws -> Double {
        guard let value = arguments[key] else {
            throw AppMCPError.missingParameter(key)
        }
        
        switch value {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        default:
            throw AppMCPError.invalidParameterType(key, expected: "number", got: "\(value)")
        }
    }
    
    private func performSetText(_ arguments: [String: MCP.Value]) async throws -> String {
        let elementId = try extractRequiredString(from: arguments, key: "elementId")
        let text = try extractRequiredString(from: arguments, key: "text")
        let method = extractOptionalString(from: arguments, key: "method") ?? "type"
        
        if method == "setValue" {
            // Use AppPilot's direct setValue method (efficient)
            _ = try await pilot.setValue(text, for: elementId)
            return "Set text '\(text)' in element ID '\(elementId)' using setValue method"
        } else {
            // Use AppPilot's input method (keyboard simulation)
            _ = try await pilot.input(text: text, into: elementId)
            return "Typed text '\(text)' into element ID '\(elementId)'"
        }
    }
    
    private func performType(_ arguments: [String: MCP.Value], clearFirst: Bool = false) async throws -> String {
        guard case .string(let text) = arguments["text"] else {
            throw AppMCPError.invalidParameters("Missing 'text' parameter")
        }
        
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        if let elementObject = extractOptionalObject(from: arguments, key: "element") {
            let element = try await findElementWithCriteria(elementObject, in: window)
            
            // Validate element accessibility
            try validateElementAccessibility(element)
            
            // Click element to focus it
            _ = try await pilot.click(window: window, at: element.centerPoint)
            
            if clearFirst {
                // Clear existing text first by selecting all
                _ = try await pilot.keyCombination([.a], modifiers: [.command])
            }
            
            // Type the text
            _ = try await pilot.type(text, window: window)
            
            return "Typed '\(text)' into \(element.role?.rawValue ?? "unknown") '\(getElementDescription(element))'"
        } else {
            if clearFirst {
                // Clear focused element first - use Cmd+A to select all, then type to replace
                _ = try await pilot.type("", window: window)
            }
            
            _ = try await pilot.type(text, window: window)
            return "Typed '\(text)' into focused element"
        }
    }
    
    
    private func performWait(_ arguments: [String: MCP.Value]) async throws -> String {
        // Extract required duration parameter using type-safe method
        let duration = try extractRequiredDouble(from: arguments, key: "duration")
        
        // Validate duration is positive
        guard duration > 0 else {
            throw AppMCPError.invalidParameters("Duration must be positive, got \(duration)")
        }
        
        try await pilot.wait(.time(seconds: duration))
        return "Waited \(duration) seconds"
    }
    
    private func performDrag(_ arguments: [String: MCP.Value]) async throws -> String {
        let fromElementId = try extractRequiredString(from: arguments, key: "fromElementId")
        let toElementId = try extractRequiredString(from: arguments, key: "toElementId")
        let duration = extractOptionalDouble(from: arguments, key: "duration") ?? 1.0
        
        // Check if elements exist
        guard try await pilot.elementExists(elementID: fromElementId) else {
            throw AppMCPError.elementNotAccessible("Source element '\(fromElementId)' not found or not accessible")
        }
        
        guard try await pilot.elementExists(elementID: toElementId) else {
            throw AppMCPError.elementNotAccessible("Target element '\(toElementId)' not found or not accessible")
        }
        
        // Get element positions by clicking them (which gives us ActionResult with coordinates)
        let fromResult = try await pilot.click(elementID: fromElementId)
        let toResult = try await pilot.click(elementID: toElementId)
        
        guard let fromElement = fromResult.element, let toElement = toResult.element else {
            throw AppMCPError.systemError("Failed to get element coordinates for drag operation")
        }
        
        let fromPoint = fromElement.centerPoint
        let toPoint = toElement.centerPoint
        
        // Perform drag operation using AppPilot
        _ = try await pilot.drag(from: fromPoint, to: toPoint, duration: duration)
        
        return "Dragged from element '\(fromElementId)' at (\(fromPoint.x), \(fromPoint.y)) to element '\(toElementId)' at (\(toPoint.x), \(toPoint.y)) over \(duration) seconds"
    }
    
    private func performScroll(_ arguments: [String: MCP.Value]) async throws -> String {
        let elementId = try extractRequiredString(from: arguments, key: "elementId")
        let deltaX = extractOptionalDouble(from: arguments, key: "deltaX") ?? 0
        let deltaY = try extractRequiredDouble(from: arguments, key: "deltaY")
        
        // Check if element exists
        guard try await pilot.elementExists(elementID: elementId) else {
            throw AppMCPError.elementNotAccessible("Element '\(elementId)' not found or not accessible")
        }
        
        // Get element position by clicking it (which gives us ActionResult with coordinates)
        let result = try await pilot.click(elementID: elementId)
        
        guard let element = result.element else {
            throw AppMCPError.systemError("Failed to get element coordinates for scroll operation")
        }
        
        let scrollPoint = element.centerPoint
        
        // Perform scroll operation using AppPilot
        _ = try await pilot.scroll(deltaX: deltaX, deltaY: deltaY, at: scrollPoint)
        
        return "Scrolled at element '\(elementId)' location (\(scrollPoint.x), \(scrollPoint.y)) with delta (\(deltaX), \(deltaY))"
    }
    
    private func performFind(_ arguments: [String: MCP.Value]) async throws -> String {
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        let limit = extractOptionalDouble(from: arguments, key: "limit").map { Int($0) } ?? 10
        
        // Create criteria from arguments (excluding bundleID, window, and limit)
        var criteria: [String: MCP.Value] = [:]
        for (key, value) in arguments {
            if key != "bundleID" && key != "window" && key != "limit" {
                criteria[key] = value
            }
        }
        
        // Find elements with user-friendly criteria using type-safe method
        let userType = extractOptionalString(from: criteria, key: "type")
        let exactText = extractOptionalString(from: criteria, key: "text")
        let containingText = extractOptionalString(from: criteria, key: "containing")
        let placeholderText = extractOptionalString(from: criteria, key: "placeholder")
        let labelText = extractOptionalString(from: criteria, key: "label")
        let index = extractOptionalDouble(from: criteria, key: "index").map { Int($0) }
        
        let elements = try await findElementsWithTypeSafeCriteria(
            in: window,
            userType: userType,
            exactText: exactText,
            containingText: containingText,
            placeholderText: placeholderText,
            labelText: labelText,
            index: index
        )
        let limitedElements = Array(elements.prefix(limit))
        
        if limitedElements.isEmpty {
            let criteriaDesc = describeCriteria(criteria)
            return "No elements found matching criteria: \(criteriaDesc.isEmpty ? "all elements" : criteriaDesc)"
        }
        
        // Build hierarchical structure
        return try await buildHierarchicalResponse(elements: limitedElements, totalCount: elements.count, limit: limit)
    }
    
    private func getUserFriendlyType(for roleString: String?) -> String {
        guard let roleString = roleString else { return "unknown" }
        
        // Convert string role to Role if possible
        guard let role = Role(rawValue: roleString) else { return roleString }
        
        switch role {
        case .button, .popUpButton, .menuBarItem, .tabGroup:
            return "button"
        case .textField, .field:
            return "textfield"
        case .staticText:
            return "text"
        case .image:
            return "image"
        case .menu, .menuBar, .menuItem:
            return "menu"
        case .list, .row:
            return "list"
        case .table, .cell:
            return "table"
        case .checkBox:
            return "checkbox"
        case .radioButton:
            return "radio"
        case .slider:
            return "slider"
        case .link:
            return "link"
        case .group, .scrollArea:
            return "group"
        case .unknown:
            return "unknown"
        default:
            return role.rawValue
        }
    }
    
    private func performScreenshot(_ arguments: [String: MCP.Value]) async throws -> String {
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        let format = extractOptionalString(from: arguments, key: "format") ?? "png"
        
        // Get window information for context
        let windows = try await pilot.listWindows(app: app)
        let windowInfo = windows.first(where: { $0.id == window })
        
        // Use AppPilot's improved window-specific screenshot capability
        let originalImage = try await pilot.capture(window: window)
        
        // Resize image to reasonable dimensions for MCP
        let cgImage = resizeImageIfNeeded(originalImage, maxDimension: 600)
        
        // Use AppPilot's ScreenCaptureUtility for image conversion with compression
        let imageData: Data
        let mimeType: String
        
        switch format.lowercased() {
        case "jpeg", "jpg":
            // Use lower quality for smaller file size
            guard let jpegData = ScreenCaptureUtility.convertToJPEG(cgImage, quality: 0.4) else {
                throw AppMCPError.systemError("Failed to convert screenshot to JPEG")
            }
            imageData = jpegData
            mimeType = "image/jpeg"
        default: // "png"
            // Always prefer JPEG for screenshots to reduce size
            guard let jpegData = ScreenCaptureUtility.convertToJPEG(cgImage, quality: 0.4) else {
                throw AppMCPError.systemError("Failed to convert screenshot to JPEG")
            }
            imageData = jpegData
            mimeType = "image/jpeg"
        }
        
        // Build response with window context but limit size
        let windowTitle = windowInfo?.title ?? "Unknown Window"
        let appName = windowInfo?.appName ?? "Unknown App"
        let dimensions = "\(cgImage.width)x\(cgImage.height)"
        let fileSizeKB = String(format: "%.1f", Double(imageData.count) / 1024.0)
        
        // Check total response size (base64 is ~33% larger than binary)
        let base64Size = (imageData.count * 4) / 3
        let maxAllowedSize = 600_000 // ~600KB for base64 data to be safe
        
        if base64Size > maxAllowedSize {
            // Return metadata only if image is too large
            return """
            Screenshot captured but too large for direct transmission:
            - Application: \(appName)
            - Window: \(windowTitle)
            - Dimensions: \(dimensions)
            - Format: \(mimeType == "image/jpeg" ? "JPEG" : "PNG")
            - Size: \(fileSizeKB) KB
            
            Image is too large (\(fileSizeKB) KB) for MCP response. Consider using a smaller window or requesting JPEG format with lower quality.
            """
        }
        
        let base64Data = imageData.base64EncodedString()
        return """
        Screenshot captured successfully:
        - Application: \(appName)
        - Window: \(windowTitle)
        - Dimensions: \(dimensions)
        - Format: \(mimeType == "image/jpeg" ? "JPEG" : "PNG")
        - Size: \(fileSizeKB) KB
        
        data:\(mimeType);base64,\(base64Data)
        """
    }
    
    private func performUISnapshot(_ arguments: [String: MCP.Value]) async throws -> String {
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        // Capture complete UI snapshot using AppPilot
        let snapshot = try await pilot.snapshot(window: window, metadata: nil)
        
        // Resize image for MCP compatibility
        guard let originalImage = snapshot.image else {
            throw AppMCPError.systemError("Failed to extract image from snapshot")
        }
        let resizedImage = resizeImageIfNeeded(originalImage, maxDimension: 600)
        
        // Convert to JPEG for efficiency
        guard let imageData = ScreenCaptureUtility.convertToJPEG(resizedImage, quality: 0.4) else {
            throw AppMCPError.systemError("Failed to convert snapshot to JPEG")
        }
        
        // Build element hierarchy with IDs
        let elementsJson = try buildElementsJsonResponse(snapshot.elements)
        
        // Build metadata information
        let windowTitle = snapshot.windowInfo.title ?? "Unknown Window"
        let dimensions = "\(resizedImage.width)x\(resizedImage.height)"
        let fileSizeKB = String(format: "%.1f", Double(imageData.count) / 1024.0)
        let elementCount = snapshot.elements.count
        
        let base64Data = imageData.base64EncodedString()
        
        return """
        UI Snapshot captured successfully:
        - Window: \(windowTitle)
        - Dimensions: \(dimensions)
        - Format: JPEG
        - Size: \(fileSizeKB) KB
        - Elements found: \(elementCount)
        - Timestamp: \(snapshot.timestamp)
        
        Screenshot:
        data:image/jpeg;base64,\(base64Data)
        
        UI Elements:
        \(elementsJson)
        """
    }
    
    private func buildElementsJsonResponse(_ elements: [AIElement]) throws -> String {
        var elementsData: [[String: Any]] = []
        
        for element in elements {
            var elementData: [String: Any] = [
                "id": element.id,
                "role": element.role?.rawValue ?? "unknown"
            ]
            
            if let title = element.title, !title.isEmpty {
                elementData["title"] = title
            }
            
            if let value = element.value, !value.isEmpty {
                elementData["value"] = value
            }
            
            if let identifier = element.identifier, !identifier.isEmpty {
                elementData["identifier"] = identifier
            }
            
            if let bounds = element.bounds, bounds.count == 4 {
                elementData["bounds"] = [
                    "x": bounds[0],
                    "y": bounds[1], 
                    "width": bounds[2],
                    "height": bounds[3]
                ]
            }
            
            elementData["enabled"] = element.isEnabled
            elementData["userFriendlyType"] = getUserFriendlyType(for: element.role?.rawValue)
            
            elementsData.append(elementData)
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: elementsData, options: [.prettyPrinted])
        return String(data: jsonData, encoding: .utf8) ?? "[]"
    }
    
    // MARK: - Image Processing Utilities
    
    private func resizeImageIfNeeded(_ image: CGImage, maxDimension: Int) -> CGImage {
        let width = image.width
        let height = image.height
        let maxDim = max(width, height)
        
        // Return original if already small enough
        if maxDim <= maxDimension {
            return image
        }
        
        // Calculate new dimensions maintaining aspect ratio
        let scale = Double(maxDimension) / Double(maxDim)
        let newWidth = Int(Double(width) * scale)
        let newHeight = Int(Double(height) * scale)
        
        // Create resized image
        guard let colorSpace = image.colorSpace,
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue
              ) else {
            // Return original if resize fails
            return image
        }
        
        // Set high quality interpolation
        context.interpolationQuality = .high
        
        // Draw resized image
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        // Return resized image or original if creation fails
        return context.makeImage() ?? image
    }
    
    // MARK: - Resource Handlers
    
    private func setupResourceHandlers() async {
        await server.withMethodHandler(ListResources.self) { _ in
            return ListResources.Result(resources: [
                MCP.Resource(
                    name: "running_applications",
                    uri: "appmcp://resources/running_applications",
                    description: "List of all running applications with metadata",
                    mimeType: "application/json"
                ),
                MCP.Resource(
                    name: "application_windows",
                    uri: "appmcp://resources/application_windows",
                    description: "All application windows with bounds and visibility info",
                    mimeType: "application/json"
                )
            ])
        }
        
        await server.withMethodHandler(ReadResource.self) { params in
            return await self.handleResource(uri: params.uri)
        }
    }
    
    internal func handleResource(uri: String) async -> ReadResource.Result {
        do {
            let content: String
            
            switch uri {
            case "appmcp://resources/running_applications":
                content = try await getApplications()
            case "appmcp://resources/application_windows":
                content = try await getWindows()
            default:
                throw AppMCPError.invalidParameters("Unknown resource: \(uri)")
            }
            
            return ReadResource.Result(contents: [
                .text(content, uri: uri, mimeType: "application/json")
            ])
            
        } catch {
            return ReadResource.Result(contents: [
                .text("{\"error\": \"\(error.localizedDescription)\"}", uri: uri, mimeType: "application/json")
            ])
        }
    }
    
    private func getApplications() async throws -> String {
        // Use AppPilot to get real running applications
        let apps = try await pilot.listApplications()
        
        var appData: [[String: Any]] = []
        
        for app in apps {
            var appInfo: [String: Any] = [
                "name": app.name,
                "bundleID": app.bundleIdentifier ?? "unknown",
                "handle": app.id.id,
                "isActive": app.isActive
            ]
            
            // Get windows for this application
            do {
                let windows = try await pilot.listWindows(app: app.id)
                let windowData = windows.map { window in
                    [
                        "title": window.title ?? "Untitled",
                        "handle": window.id.id,
                        "bounds": [
                            "x": window.bounds.origin.x,
                            "y": window.bounds.origin.y,
                            "width": window.bounds.size.width,
                            "height": window.bounds.size.height
                        ],
                        "isVisible": window.isVisible,
                        "isMain": window.isMain
                    ] as [String: Any]
                }
                appInfo["windows"] = windowData
                appInfo["windowCount"] = windows.count
            } catch {
                // If we can't get windows (permission issues), include empty array
                appInfo["windows"] = []
                appInfo["windowCount"] = 0
            }
            
            appData.append(appInfo)
        }
        
        let data = try JSONSerialization.data(withJSONObject: ["applications": appData])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    private func getWindows() async throws -> String {
        // Get windows from all accessible applications
        let apps = try await pilot.listApplications()
        var allWindows: [[String: Any]] = []
        
        for app in apps {
            do {
                let windows = try await pilot.listWindows(app: app.id)
                let windowData = windows.map { window in
                    [
                        "title": window.title ?? "Untitled",
                        "handle": window.id.id,
                        "app": app.name,
                        "appHandle": app.id.id,
                        "bounds": [
                            "x": window.bounds.origin.x,
                            "y": window.bounds.origin.y,
                            "width": window.bounds.size.width,
                            "height": window.bounds.size.height
                        ],
                        "isVisible": window.isVisible,
                        "isMain": window.isMain
                    ] as [String: Any]
                }
                allWindows.append(contentsOf: windowData)
            } catch {
                // Skip apps that can't be queried (permission issues)
                continue
            }
        }
        
        let data = try JSONSerialization.data(withJSONObject: ["windows": allWindows])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - Type-Safe Parameter Extraction
    
    private func extractRequiredString(from arguments: [String: MCP.Value], key: String) throws -> String {
        guard let value = arguments[key] else {
            throw AppMCPError.missingParameter(key)
        }
        
        guard case .string(let str) = value else {
            throw AppMCPError.invalidParameterType(key, expected: "string", got: "\(value)")
        }
        
        return str
    }
    
    private func extractOptionalString(from arguments: [String: MCP.Value], key: String) -> String? {
        guard let value = arguments[key] else { return nil }
        guard case .string(let str) = value else { return nil }
        return str
    }
    
    private func extractRequiredObject(from arguments: [String: MCP.Value], key: String) throws -> [String: MCP.Value] {
        guard let value = arguments[key] else {
            throw AppMCPError.missingParameter(key)
        }
        
        guard case .object(let obj) = value else {
            throw AppMCPError.invalidParameterType(key, expected: "object", got: "\(value)")
        }
        
        return obj
    }
    
    private func extractOptionalObject(from arguments: [String: MCP.Value], key: String) -> [String: MCP.Value]? {
        guard let value = arguments[key] else { return nil }
        guard case .object(let obj) = value else { return nil }
        return obj
    }
    
    private func extractOptionalDouble(from arguments: [String: MCP.Value], key: String) -> Double? {
        guard let value = arguments[key] else { return nil }
        
        switch value {
        case .double(let d):
            return d
        case .int(let i):
            return Double(i)
        default:
            return nil
        }
    }
    
    private func extractOptionalBool(from arguments: [String: MCP.Value], key: String) -> Bool? {
        guard let value = arguments[key] else { return nil }
        guard case .bool(let bool) = value else { return nil }
        return bool
    }
    
    // MARK: - Dynamic Element Discovery
    
    /// Find search field dynamically using UI snapshot analysis
    private func findSearchFieldDynamically(in window: WindowHandle) async throws -> AIElement? {
        let snapshot = try await pilot.snapshot(window: window)
        
        // Search for potential search field candidates
        var searchCandidates: [AIElement] = []
        for element in snapshot.elements {
            // Check role (various search field implementations)
            let roleMatches = ["TextField", "SearchField", "Field"].contains(element.role?.rawValue ?? "")
            
            // Check title/value/identifier for search-related text
            let titleText = element.title?.lowercased() ?? ""
            let valueText = element.value?.lowercased() ?? ""
            let idText = element.identifier?.lowercased() ?? ""
            
            let hasSearchInText = titleText.contains("search") || titleText.contains("検索") ||
                                valueText.contains("search") || valueText.contains("検索") ||
                                idText.contains("search") || idText.contains("検索")
            
            // Check element properties for search field characteristics
            var hasReasonableSize = false
            var isInTopArea = false
            var isInToolbarArea = false
            
            if let bounds = element.bounds, bounds.count >= 4 {
                let width = bounds[2] - bounds[0]
                let height = bounds[3] - bounds[1]
                let maxY = bounds[3]
                let minY = bounds[1]
                
                hasReasonableSize = width > 100 && height > 15
                isInTopArea = maxY > -1050 // Top area of window for search fields
                isInToolbarArea = minY > -1030 && maxY < -990
            }
            
            if roleMatches || (hasSearchInText && hasReasonableSize) || 
               (hasReasonableSize && (isInTopArea || isInToolbarArea)) {
                searchCandidates.append(element)
            }
        }
        
        // Prefer elements with search-related text, then by role, then by position
        return searchCandidates.sorted { first, second in
            // Check if elements have search-related text
            let firstTitle = first.title?.lowercased() ?? ""
            let firstId = first.identifier?.lowercased() ?? ""
            let firstHasSearch = firstTitle.contains("search") || first.title?.contains("検索") == true ||
                               firstId.contains("search") || first.identifier?.contains("検索") == true
            
            let secondTitle = second.title?.lowercased() ?? ""
            let secondId = second.identifier?.lowercased() ?? ""
            let secondHasSearch = secondTitle.contains("search") || second.title?.contains("検索") == true ||
                                secondId.contains("search") || second.identifier?.contains("検索") == true
            
            if firstHasSearch != secondHasSearch {
                return firstHasSearch
            }
            
            // Prefer elements with known search roles
            let firstRole = first.role?.rawValue ?? ""
            let secondRole = second.role?.rawValue ?? ""
            let firstIsKnownRole = ["TextField", "SearchField"].contains(firstRole)
            let secondIsKnownRole = ["TextField", "SearchField"].contains(secondRole)
            
            if firstIsKnownRole != secondIsKnownRole {
                return firstIsKnownRole
            }
            
            // Prefer higher elements (closer to top of window)
            if let firstBounds = first.bounds, firstBounds.count >= 4,
               let secondBounds = second.bounds, secondBounds.count >= 4 {
                return firstBounds[3] > secondBounds[3] // Compare maxY
            }
            
            return false
        }.first
    }
    
    // MARK: - User-Friendly Element Type Mapping
    
    private func mapUserTypeToElementRoles(_ userType: String) -> [Role] {
        switch userType.lowercased() {
        case "button":
            return [.button, .popUpButton, .menuBarItem, .tabGroup]
        case "textfield":
            return [.textField]
        case "text":
            return [.staticText]
        case "image":
            return [.image]
        case "menu":
            return [.menu, .menuBar, .menuItem]
        case "list":
            return [.list, .row]
        case "table":
            return [.table, .cell, .row]
        case "checkbox":
            return [.checkBox]
        case "radio":
            return [.radioButton]
        case "slider":
            return [.slider]
        case "link":
            return [.link]
        case "group":
            return [.group, .scrollArea]
        case "unknown":
            return [.unknown]
        default:
            // Return all common interactive elements if type is unknown
            // Note: .unknown elements are excluded to avoid performance issues with large element trees
            return [.button, .popUpButton, .textField, .staticText, 
                   .image, .menuItem, .tabGroup, .link, .checkBox, .radioButton, .list, .row, .cell]
        }
    }
    
    
    
    
    private func resolveWindow(from arguments: [String: MCP.Value], for app: AppHandle) async throws -> WindowHandle {
        // Check for explicit window parameter
        if let windowTitle = extractOptionalString(from: arguments, key: "window") {
            guard let window = try await pilot.findWindow(app: app, title: windowTitle) else {
                throw AppMCPError.windowNotFound("Window with title '\(windowTitle)' not found")
            }
            return window
        }
        
        // Check for window index
        if let windowIndex = extractOptionalDouble(from: arguments, key: "window") {
            let index = Int(windowIndex)
            guard let window = try await pilot.findWindow(app: app, index: index) else {
                throw AppMCPError.windowNotFound("Window at index \(index) not found")
            }
            return window
        }
        
        // Default to main window, then first available window
        let windows = try await pilot.listWindows(app: app)
        
        if let mainWindow = windows.first(where: { $0.isMain }) {
            return mainWindow.id
        }
        
        if let firstWindow = windows.first {
            return firstWindow.id
        }
        
        throw AppMCPError.windowNotFound("No windows found for application")
    }
    
    private func findElementWithCriteria(_ criteria: [String: MCP.Value], in window: WindowHandle) async throws -> AIElement {
        // Validate criteria is not empty
        guard !criteria.isEmpty else {
            throw AppMCPError.invalidParameters("Element criteria cannot be empty")
        }
        
        // Extract search criteria using type-safe methods
        let userType = extractOptionalString(from: criteria, key: "type")
        let exactText = extractOptionalString(from: criteria, key: "text")
        let containingText = extractOptionalString(from: criteria, key: "containing")
        let placeholderText = extractOptionalString(from: criteria, key: "placeholder")
        let labelText = extractOptionalString(from: criteria, key: "label")
        let index = extractOptionalDouble(from: criteria, key: "index").map { Int($0) }
        
        // Validate that we have some search criteria - AppPilot requires at least one criterion
        let hasSearchCriteria = exactText != nil || containingText != nil || placeholderText != nil || labelText != nil
        if !hasSearchCriteria && userType == nil {
            throw AppMCPError.invalidParameters("At least one search criterion (type, text, containing, placeholder, or label) must be provided")
        }
        
        // Convert to internal search criteria
        let elements = try await findElementsWithTypeSafeCriteria(
            in: window,
            userType: userType,
            exactText: exactText,
            containingText: containingText,
            placeholderText: placeholderText,
            labelText: labelText,
            index: index
        )
        
        guard let element = elements.first else {
            let criteriaDesc = describeCriteria(criteria)
            throw AppMCPError.elementNotFound("No element found matching criteria: \(criteriaDesc)")
        }
        
        return element
    }
    
    private func findElementsWithTypeSafeCriteria(
        in window: WindowHandle,
        userType: String?,
        exactText: String?,
        containingText: String?,
        placeholderText: String?,
        labelText: String?,
        index: Int?
    ) async throws -> [AIElement] {
        // Convert user type to internal element roles
        let targetRoles: [Role]?
        if let userType = userType {
            targetRoles = mapUserTypeToElementRoles(userType)
        } else {
            targetRoles = nil
        }
        
        // Determine search criteria - AppPilot requires title OR identifier for efficient search
        let searchTitle = exactText ?? containingText ?? placeholderText ?? labelText
        let searchIdentifier: String? = nil // Future: Add identifier-based search to element criteria
        
        // Find all elements matching the roles
        var matchingElements: [AIElement] = []
        
        if let roles = targetRoles {
            for role in roles {
                do {
                    if searchTitle != nil || searchIdentifier != nil {
                        // Use specific search when we have title or identifier
                        let element = try await pilot.findElement(in: window, role: role, title: searchTitle, identifier: searchIdentifier)
                        matchingElements.append(element)
                    } else {
                        // Fallback to broader search and filter later
                        let elementsForRole = try await pilot.findElements(in: window, role: role, title: nil, identifier: nil)
                        matchingElements.append(contentsOf: elementsForRole)
                    }
                } catch {
                    // Continue searching other roles if this one fails
                    // This is expected behavior in AppPilot when elements aren't found
                    continue
                }
            }
        } else {
            // Get all elements if no specific role
            matchingElements = try await pilot.findElements(in: window, role: nil, title: searchTitle, identifier: searchIdentifier)
        }
        
        // Apply additional text-based filters for broader searches
        if searchTitle == nil {
            matchingElements = matchingElements.filter { element in
                // Exact text match
                if let exactText = exactText {
                    return element.title == exactText || element.value == exactText
                }
                
                // Containing text match
                if let containingText = containingText {
                    let elementTexts = [element.title, element.value].compactMap { $0 }
                    return elementTexts.contains { text in
                        text.localizedCaseInsensitiveContains(containingText)
                    }
                }
                
                // Placeholder text (for text fields)
                if let placeholderText = placeholderText {
                    return element.title?.localizedCaseInsensitiveContains(placeholderText) == true
                }
                
                // Label text
                if let labelText = labelText {
                    return element.title?.localizedCaseInsensitiveContains(labelText) == true
                }
                
                return true
            }
        }
        
        // Apply index selection if specified
        if let index = index {
            guard index >= 0 && index < matchingElements.count else {
                throw AppMCPError.elementNotFound("Index \(index) out of range. Found \(matchingElements.count) matching elements.")
            }
            return [matchingElements[index]]
        }
        
        return matchingElements
    }
    
    
    private func describeCriteria(_ criteria: [String: MCP.Value]) -> String {
        var parts: [String] = []
        
        if let type = extractOptionalString(from: criteria, key: "type") {
            parts.append("type=\(type)")
        }
        if let text = extractOptionalString(from: criteria, key: "text") {
            parts.append("text='\(text)'")
        }
        if let containing = extractOptionalString(from: criteria, key: "containing") {
            parts.append("containing='\(containing)'")
        }
        if let placeholder = extractOptionalString(from: criteria, key: "placeholder") {
            parts.append("placeholder='\(placeholder)'")
        }
        if let label = extractOptionalString(from: criteria, key: "label") {
            parts.append("label='\(label)'")
        }
        if let index = extractOptionalDouble(from: criteria, key: "index") {
            parts.append("index=\(Int(index))")
        }
        
        return parts.isEmpty ? "no criteria" : parts.joined(separator: ", ")
    }
    
    private func buildHierarchicalResponse(elements: [AIElement], totalCount: Int, limit: Int) async throws -> String {
        // Group elements by functional areas
        let functionalGroups = groupElementsByFunction(elements)
        
        var response = "Found \(totalCount) element\(totalCount == 1 ? "" : "s")"
        if totalCount > limit {
            response += " (showing first \(limit))"
        }
        response += ":\n"
        
        // Build structured output
        for (groupName, groupElements) in functionalGroups {
            response += "\n[\(groupName)]:\n"
            for element in groupElements {
                let shortInfo = buildElementSummary(element)
                response += "  \(shortInfo)\n"
            }
        }
        
        return response
    }
    
    private func groupElementsByFunction(_ elements: [AIElement]) -> [String: [AIElement]] {
        var groups: [String: [AIElement]] = [:]
        
        for element in elements {
            let groupName = determineElementGroup(element)
            if groups[groupName] == nil {
                groups[groupName] = []
            }
            groups[groupName]?.append(element)
        }
        
        return groups
    }
    
    private func determineElementGroup(_ element: AIElement) -> String {
        let userType = getUserFriendlyType(for: element.role?.rawValue)
        
        // Group by UI patterns
        if userType == "textfield" {
            return "Input Fields"
        } else if userType == "button" {
            return "Controls"
        } else if userType == "text" {
            if let title = element.title, !title.isEmpty {
                return "Content"
            } else {
                return "Labels"
            }
        } else if userType == "list" || userType == "table" {
            return "Data"
        } else if userType == "menu" {
            return "Navigation"
        } else {
            return "Other"
        }
    }
    
    private func buildElementSummary(_ element: AIElement) -> String {
        let userType = getUserFriendlyType(for: element.role?.rawValue)
        let displayText = extractDisplayText(element)
        let coordinates = "(\(Int(element.centerPoint.x)), \(Int(element.centerPoint.y)))"
        
        if !displayText.isEmpty {
            return "\(userType): \"\(displayText)\" at \(coordinates)"
        } else {
            return "\(userType) at \(coordinates)"
        }
    }
    
    private func extractDisplayText(_ element: AIElement) -> String {
        // Extract meaningful text, avoiding internal IDs
        if let title = element.title, !title.isEmpty && !title.hasPrefix("win_") {
            return title
        }
        if let value = element.value, !value.isEmpty && !value.hasPrefix("win_") {
            return value
        }
        
        // For elements without meaningful text, use role description
        return ""
    }
    
    // MARK: - Error Handling Helpers
    
    /// Convert AppPilot errors to AppMCP errors for better error reporting
    private func convertPilotError(_ error: Swift.Error) -> AppMCPError {
        // Check if it's already an AppMCP error
        if let appMcpError = error as? AppMCPError {
            return appMcpError
        }
        
        // Convert common AppPilot error patterns
        let errorString = error.localizedDescription.lowercased()
        
        // Application-related errors
        if errorString.contains("application not found") || errorString.contains("no application") || 
           (errorString.contains("application") && errorString.contains("not found")) {
            return .applicationNotFound(error.localizedDescription)
        }
        
        // Window-related errors
        if errorString.contains("window not found") || errorString.contains("no window") ||
           (errorString.contains("window") && errorString.contains("not found")) {
            return .windowNotFound(error.localizedDescription)
        }
        
        // Element-related errors
        if errorString.contains("element not found") || errorString.contains("no element") ||
           (errorString.contains("element") && errorString.contains("not found")) ||
           errorString.contains("failed to find element") {
            return .elementNotFound(error.localizedDescription)
        }
        
        // Accessibility errors
        if errorString.contains("element not accessible") || errorString.contains("not accessible") ||
           errorString.contains("accessibility disabled") {
            return .elementNotAccessible(error.localizedDescription)
        }
        
        // Permission errors
        if errorString.contains("permission denied") || errorString.contains("accessibility") ||
           errorString.contains("not authorized") || errorString.contains("requires permission") {
            return .permissionDenied(error.localizedDescription)
        }
        
        // Coordinate/bounds errors
        if (errorString.contains("coordinate") && errorString.contains("bounds")) ||
           errorString.contains("out of bounds") || errorString.contains("invalid coordinates") {
            return .coordinateOutOfBounds(error.localizedDescription)
        }
        
        // Timeout errors
        if errorString.contains("timeout") || errorString.contains("timed out") ||
           errorString.contains("operation took too long") {
            return .timeout(error.localizedDescription)
        }
        
        // Default to system error
        return .systemError(error.localizedDescription)
    }
    
    /// Enhanced error handling for tool operations
    private func handleToolError(_ error: Swift.Error, toolName: String) -> CallTool.Result {
        let convertedError = convertPilotError(error)
        return CallTool.Result(
            content: [.text("Error in \(toolName): \(convertedError.localizedDescription)")],
            isError: true
        )
    }
    
    // MARK: - Server Lifecycle
    
    public func start() async throws {
        print("🚀 AppMCP Server starting...")
        print("   Version: \(AppMCP.version)")
        print("   MCP Protocol: \(AppMCP.mcpVersion)")
        print("   Powered by: AppPilot")
        print("   Essential automation actions available")
        
        // Validate AppPilot capabilities on startup
        do {
            try await validateAppPilotCapabilities()
            print("✅ AppPilot capabilities verified")
        } catch {
            print("⚠️  AppPilot capability check failed: \(error.localizedDescription)")
            print("   Some features may not work without proper permissions")
        }
        
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
    
    public func stop() async {
        await server.stop()
    }
}

// MARK: - Extensions for convenience

extension AppMCPServer {
    /// Create a server for Weather app automation
    public static func forWeatherApp() -> AppMCPServer {
        return AppMCPServer()
    }
}
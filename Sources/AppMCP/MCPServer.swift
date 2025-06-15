import Foundation
import MCP
import AppPilot
import AppKit
import AXUI
import Vision

// Note: Both AppPilot and AXUI define Role types
// We need to be explicit about which Role to use in each context

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
    
    /// Compute center point from AXElement position and size
    private func centerPoint(for element: AXUI.AXElement) -> CGPoint {
        guard let position = element.position, let size = element.size else {
            return CGPoint(x: 0, y: 0)
        }
        return CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2
        )
    }
    
    /// Validate that an element is accessible and can be interacted with
    private func validateElementAccessibility(_ element: AXUI.AXElement) throws {
        // Check if element has a valid position
        guard let position = element.position else {
            throw AppMCPError.elementNotAccessible("Element has no position information")
        }
        
        if position.x == 0 && position.y == 0 {
            throw AppMCPError.elementNotAccessible("Element has no valid position")
        }
        
        // Check size if available
        if let size = element.size {
            if size.width <= 0 || size.height <= 0 {
                throw AppMCPError.elementNotAccessible("Element has invalid size: width=\(size.width), height=\(size.height)")
            }
        }
        
        // Additional validation can be added here as AppPilot API evolves
    }
    
    /// Get a human-readable description for an element for error messages
    private func getElementDescription(_ element: AXUI.AXElement) -> String {
        if let description = element.description, !description.isEmpty {
            return description
        } else if let identifier = element.identifier, !identifier.isEmpty {
            return identifier
        } else if !element.id.isEmpty {
            return element.id
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
                
                // UI Snapshot Tool
                MCP.Tool(
                    name: "capture_ui_snapshot",
                    description: "Capture screenshot + UI elements with optional text recognition",
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
                            ],
                            "query": [
                                "type": "object",
                                "description": "Element filtering options - specify role, title, identifier, or enabled state to filter elements at source for efficiency",
                                "properties": [
                                    "role": [
                                        "type": "string",
                                        "enum": [
                                            "button", "textfield", "text", "image", "menu", "list", "table", 
                                            "checkbox", "radio", "slider", "link", "group", "window", "toolbar",
                                            "menubar", "menuitem", "popupbutton", "searchfield", "scrollarea",
                                            "tab", "tabgroup", "splitgroup", "outline", "browser", "application",
                                            "combobox", "progressindicator", "disclosure", "sheet", "drawer",
                                            "helpbutton", "colorwell", "ruler", "cell", "row", "column"
                                        ],
                                        "description": "Element role filter - UI element type to search for"
                                    ],
                                    "title": [
                                        "type": "string",
                                        "description": "Element title/text filter (partial match)"
                                    ],
                                    "identifier": [
                                        "type": "string",
                                        "description": "Element identifier filter (exact match)"
                                    ],
                                    "enabled": [
                                        "type": "boolean",
                                        "description": "Filter by enabled state - true for interactive elements, false for disabled elements (default: true)"
                                    ]
                                ]
                            ],
                            "includeTextRecognition": [
                                "type": "boolean",
                                "description": "Include OCR text recognition results (default: false)"
                            ],
                        ],
                        "required": ["bundleID"]
                    ]
                ),
                
                // Elements Snapshot Tool (without screenshot)
                MCP.Tool(
                    name: "elements_snapshot",
                    description: "Extract UI elements only",
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
                            ],
                            "query": [
                                "type": "object",
                                "description": "Element filtering options - specify role, title, identifier, or enabled state to filter elements at source for efficiency",
                                "properties": [
                                    "role": [
                                        "type": "string",
                                        "enum": [
                                            "button", "textfield", "text", "image", "menu", "list", "table", 
                                            "checkbox", "radio", "slider", "link", "group", "window", "toolbar",
                                            "menubar", "menuitem", "popupbutton", "searchfield", "scrollarea",
                                            "tab", "tabgroup", "splitgroup", "outline", "browser", "application",
                                            "combobox", "progressindicator", "disclosure", "sheet", "drawer",
                                            "helpbutton", "colorwell", "ruler", "cell", "row", "column"
                                        ],
                                        "description": "Element role filter - UI element type to search for"
                                    ],
                                    "title": [
                                        "type": "string",
                                        "description": "Element title/text filter (partial match)"
                                    ],
                                    "identifier": [
                                        "type": "string",
                                        "description": "Element identifier filter (exact match)"
                                    ],
                                    "enabled": [
                                        "type": "boolean",
                                        "description": "Filter by enabled state - true for interactive elements, false for disabled elements (default: true)"
                                    ]
                                ]
                            ]
                        ],
                        "required": ["bundleID"]
                    ]
                ),
                
                // Text Recognition Tool
                MCP.Tool(
                    name: "read_content",
                    description: "Capture screenshot and perform OCR text recognition with structured output",
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
                            ],
                            "recognitionLevel": [
                                "type": "string",
                                "enum": ["accurate", "fast"],
                                "description": "Recognition accuracy level (default: accurate)"
                            ]
                        ],
                        "required": ["bundleID"]
                    ]
                ),
                
                // Information Tools
                MCP.Tool(
                    name: "list_running_applications",
                    description: "List running App on macOS with bundle IDs and names",
                    inputSchema: [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                ),
                
                MCP.Tool(
                    name: "list_application_windows",
                    description: "List App windows with titles and coordinates",
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
            case "elements_snapshot":
                return await self.handleElementsSnapshot(arguments)
            case "wait_time":
                return await self.handleWaitTime(arguments)
            case "read_content":
                return await self.handleRecognizeText(arguments)
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
            let result = try await performSetText(arguments)
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
    
    internal func handleElementsSnapshot(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performElementsSnapshot(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "elements_snapshot")
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
    
    internal func handleRecognizeText(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performTextRecognition(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return handleToolError(error, toolName: "read_content")
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
    
    
    private func getUserFriendlyType(for roleString: String?) -> String {
        guard let roleString = roleString else { return "unknown" }
        
        // Simple string-based mapping for user-friendly types
        switch roleString.lowercased() {
        case "button", "popupbutton", "menubaritem", "tabgroup":
            return "button"
        case "textfield", "field":
            return "textfield"
        case "statictext", "text":
            return "text"
        case "image":
            return "image"
        case "menu", "menubar", "menuitem":
            return "menu"
        case "list", "row":
            return "list"
        case "table", "cell":
            return "table"
        case "checkbox":
            return "checkbox"
        case "radiobutton":
            return "radio"
        case "slider":
            return "slider"
        case "link":
            return "link"
        case "group", "scrollarea":
            return "group"
        default:
            return roleString
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
        let cgImage = resizeImageIfNeeded(originalImage, maxDimension: 320)
        
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
        
        // Extract query options for AXQuery
        let queryOptions = extractOptionalObject(from: arguments, key: "query")
        let axQuery = try buildAXQuery(from: queryOptions)
        
        // Check if text recognition is requested
        let includeTextRecognition = extractOptionalBool(from: arguments, key: "includeTextRecognition") ?? false
        
        // Capture UI snapshot using AppPilot with AXQuery filtering
        let snapshot = try await pilot.snapshot(window: window, query: axQuery)
        
        // Resize image for MCP compatibility (smaller size for network efficiency)
        guard let originalImage = snapshot.image else {
            throw AppMCPError.systemError("Failed to extract image from snapshot")
        }
        let resizedImage = resizeImageIfNeeded(originalImage, maxDimension: 240)
        
        // Convert to JPEG for efficiency (lower quality for smaller size)
        guard let imageData = ScreenCaptureUtility.convertToJPEG(resizedImage, quality: 0.2) else {
            throw AppMCPError.systemError("Failed to convert snapshot to JPEG")
        }
        
        // Build element hierarchy with IDs using query-filtered elements  
        let elementsJson = try AXUI.AIFormatHelpers.convertToAIFormat(
            elements: snapshot.elements
        )
        
        // Perform text recognition if requested
        var textRecognitionSection = ""
        if includeTextRecognition {
            do {
                let textResult = try await VisionTextRecognition.recognizeText(
                    in: resizedImage
                )
                let textJson = try VisionTextRecognition.formatAsJSON(textResult)
                textRecognitionSection = """
                
                Text Recognition:
                \(textJson)
                """
            } catch {
                // Include error but don't fail the entire operation
                textRecognitionSection = """
                
                Text Recognition:
                {"error": "Text recognition failed: \(error.localizedDescription)"}
                """
            }
        }
        
        // Build metadata information
        let windowTitle = snapshot.windowInfo.title ?? "Unknown Window"
        let dimensions = "\(resizedImage.width)x\(resizedImage.height)"
        let fileSizeKB = String(format: "%.1f", Double(imageData.count) / 1024.0)
        let elementCount = snapshot.elements.count
        
        let base64Data = imageData.base64EncodedString()
        
        // Check if response would be too large and provide summary only
        let totalSize = base64Data.count + elementsJson.count + textRecognitionSection.count
        if totalSize > 50000 { // 50KB limit for better MCP compatibility
            return """
            UI Snapshot captured (large response truncated for MCP compatibility):
            - Window: \(windowTitle)
            - Dimensions: \(dimensions)
            - Format: JPEG
            - Size: \(fileSizeKB) KB
            - Elements found: \(elementCount)
            - Text recognition: \(includeTextRecognition ? "enabled" : "disabled")
            - Total response size: \(String(format: "%.1f", Double(totalSize) / 1024.0)) KB
            
            Summary:
            {"window": "\(windowTitle)", "elementCount": \(elementCount), "dimensions": "\(dimensions)"}
            
            Note: Full screenshot and elements data truncated due to size. Use elements_snapshot tool for UI elements only.
            """
        }
        
        return """
        UI Snapshot captured successfully:
        - Window: \(windowTitle)
        - Dimensions: \(dimensions)
        - Format: JPEG
        - Size: \(fileSizeKB) KB
        - Elements found: \(elementCount)
        - Text recognition: \(includeTextRecognition ? "enabled" : "disabled")
        - Captured: \(Date().formatted())
        
        Screenshot:
        data:image/jpeg;base64,\(base64Data)
        
        UI Elements:
        \(elementsJson)\(textRecognitionSection)
        """
    }
    
    private func performTextRecognition(_ arguments: [String: MCP.Value]) async throws -> String {
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        
        // Extract recognition options
        let recognitionLevelStr = extractOptionalString(from: arguments, key: "recognitionLevel") ?? "accurate"
        let recognitionLevel: VNRequestTextRecognitionLevel = recognitionLevelStr == "fast" ? .fast : .accurate
        
        // Try different capture approaches for better compatibility
        let originalImage: CGImage
        
        // Simply try to resolve window and capture - let any errors propagate
        let window = try await resolveWindow(from: arguments, for: app)
        originalImage = try await pilot.capture(window: window)
        
        // Resize image for faster text recognition
        let resizedImage = resizeImageIfNeeded(originalImage, maxDimension: 800)
        
        // Perform block-level text recognition with automatic language detection
        let textResult = try await VisionTextRecognition.recognizeText(
            in: resizedImage,
            recognitionLevel: recognitionLevel
        )
        
        // Return structured JSON format with simplified layout information
        return try VisionTextRecognition.formatAsStructuredData(textResult)
    }
    
    private func performElementsSnapshot(_ arguments: [String: MCP.Value]) async throws -> String {
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        // Extract query options for AXQuery
        let queryOptions = extractOptionalObject(from: arguments, key: "query")
        let axQuery = try buildAXQuery(from: queryOptions)
        
        // Capture UI snapshot using AppPilot with AXQuery filtering (no screenshot needed)
        let snapshot = try await pilot.snapshot(window: window, query: axQuery)
        
        // Build element hierarchy with IDs using query-filtered elements  
        let elementsJson = try AXUI.AIFormatHelpers.convertToAIFormat(
            elements: snapshot.elements
        )
        
        // Build metadata information
        let windowTitle = snapshot.windowInfo.title ?? "Unknown Window"
        let elementCount = snapshot.elements.count
        
        return """
        Elements Snapshot extracted successfully:
        - Application: \(bundleID)
        - Window: \(windowTitle)
        - Elements found: \(elementCount)
        - Captured: \(Date().formatted())
        
        UI Elements:
        \(elementsJson)
        """
    }
    
    /// Build AXQuery from MCP query parameters
    private func buildAXQuery(from queryOptions: [String: MCP.Value]?) throws -> AXUI.AXQuery? {
        guard let queryOptions = queryOptions else {
            return nil // Return nil for no filtering (all elements)
        }
        
        // Extract query parameters
        let role = extractOptionalString(from: queryOptions, key: "role")
        
        // For now, create a simple query based on role only
        // TODO: Expand with more AXQuery features as they become available
        if let role = role, let axuiRole = convertToAXUIRole(role) {
            var query = AXUI.AXQuery()
            query.role = axuiRole
            return query
        }
        
        // Return nil if no supported filters are specified
        return nil
    }
    
    /// Convert user-friendly role string to AXUI.Role
    private func convertToAXUIRole(_ roleString: String) -> AXUI.Role? {
        // Try to create AXUI.Role directly from string
        return AXUI.Role(rawValue: roleString.capitalized)
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
    
    private func extractOptionalStringArray(from arguments: [String: MCP.Value], key: String) -> [String]? {
        guard let value = arguments[key] else { return nil }
        guard case .array(let array) = value else { return nil }
        
        var strings: [String] = []
        for item in array {
            if case .string(let str) = item {
                strings.append(str)
            }
        }
        
        return strings.isEmpty ? nil : strings
    }
    
    // MARK: - Dynamic Element Discovery
    
    /// Find search field dynamically using UI snapshot analysis
    private func findSearchFieldDynamically(in window: WindowHandle) async throws -> AXUI.AXElement? {
        let snapshot = try await pilot.snapshot(window: window)
        
        // Search for potential search field candidates
        var searchCandidates: [AXUI.AXElement] = []
        for element in snapshot.elements {
            // Check role (various search field implementations)
            let roleMatches = ["TextField", "SearchField", "Field"].contains(element.role?.rawValue ?? "")
            
            // Check description/identifier for search-related text
            let descriptionText = element.description?.lowercased() ?? ""
            let idText = element.id.lowercased()
            let identifierText = element.identifier?.lowercased() ?? ""
            
            let hasSearchInText = descriptionText.contains("search") || descriptionText.contains("検索") ||
                                identifierText.contains("search") || identifierText.contains("検索") ||
                                idText.contains("search") || idText.contains("検索")
            
            // Check element properties for search field characteristics
            var hasReasonableSize = false
            var isInTopArea = false
            var isInToolbarArea = false
            
            if let position = element.position, let size = element.size {
                let width = size.width
                let height = size.height
                let maxY = position.y + height
                let minY = position.y
                
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
            let firstDescription = first.description?.lowercased() ?? ""
            let firstId = first.id.lowercased()
            let firstIdentifier = first.identifier?.lowercased() ?? ""
            let firstHasSearch = firstDescription.contains("search") || first.description?.contains("検索") == true ||
                               firstId.contains("search") || first.id.contains("検索") ||
                               firstIdentifier.contains("search") || first.identifier?.contains("検索") == true
            
            let secondDescription = second.description?.lowercased() ?? ""
            let secondId = second.id.lowercased()
            let secondIdentifier = second.identifier?.lowercased() ?? ""
            let secondHasSearch = secondDescription.contains("search") || second.description?.contains("検索") == true ||
                                secondId.contains("search") || second.id.contains("検索") ||
                                secondIdentifier.contains("search") || second.identifier?.contains("検索") == true
            
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
            if let firstPosition = first.position, let firstSize = first.size,
               let secondPosition = second.position, let secondSize = second.size {
                let firstMaxY = firstPosition.y + firstSize.height
                let secondMaxY = secondPosition.y + secondSize.height
                return firstMaxY > secondMaxY // Compare maxY
            }
            
            return false
        }.first
    }
    
    // MARK: - User-Friendly Element Type Mapping
    
    private func resolveWindow(from arguments: [String: MCP.Value], for app: AppHandle) async throws -> WindowHandle {
        // Check for explicit windowHandle parameter first
        if let windowHandleId = extractOptionalString(from: arguments, key: "windowHandle") {
            return WindowHandle(id: windowHandleId)
        }
        
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
        
        // Default to main window, then first available window (revert to original approach)
        let windows = try await pilot.listWindows(app: app)
        
        // For Chrome and other browsers, don't pre-validate with capture
        // as they may have special security restrictions
        if let mainWindow = windows.first(where: { $0.isMain }) {
            return mainWindow.id
        }
        
        if let firstWindow = windows.first {
            return firstWindow.id
        }
        
        throw AppMCPError.windowNotFound("No windows found for application")
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

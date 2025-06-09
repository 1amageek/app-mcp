import Foundation
import MCP
import AppPilot
import AppKit

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
    
    private func setupHandlers() async {
        await setupToolHandlers()
        await setupResourceHandlers()
    }
    
    // MARK: - Tool Handlers
    
    private func setupToolHandlers() async {
        await server.withMethodHandler(ListTools.self) { _ in
            return ListTools.Result(tools: [
                // Basic Operations
                MCP.Tool(
                    name: "click_element",
                    description: "Click on UI elements or coordinates",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "bundleID": [
                                "type": "string",
                                "description": "Target application bundle ID (e.g., 'com.apple.calculator')"
                            ],
                            "window": [
                                "type": ["string", "number"],
                                "description": "Target window (title or index, optional)"
                            ],
                            "element": [
                                "type": "object",
                                "properties": [
                                    "type": ["type": "string", "enum": ["button", "textfield", "text", "image", "menu", "list", "table", "checkbox", "radio", "slider"], "description": "Type of UI element"],
                                    "text": ["type": "string", "description": "Exact text displayed on or in the element"],
                                    "placeholder": ["type": "string", "description": "Placeholder text for text fields"],
                                    "label": ["type": "string", "description": "Accessibility label of the element"],
                                    "containing": ["type": "string", "description": "Text that the element contains (partial match)"],
                                    "index": ["type": "number", "description": "Index of the element when multiple elements match (0-based)"]
                                ],
                                "description": "Target UI element (preferred method)"
                            ],
                            "coordinates": [
                                "type": "object",
                                "properties": [
                                    "x": ["type": "number", "description": "X coordinate"],
                                    "y": ["type": "number", "description": "Y coordinate"]
                                ],
                                "description": "Screen coordinates (fallback when element not available)"
                            ],
                            "button": [
                                "type": "string",
                                "enum": ["left", "right", "center"],
                                "description": "Mouse button to click (default: left)"
                            ],
                            "clickCount": [
                                "type": "number",
                                "description": "Number of clicks (default: 1)"
                            ]
                        ],
                        "required": ["bundleID"]
                    ]
                ),
                
                MCP.Tool(
                    name: "input_text",
                    description: "Input text into text fields or focused elements",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "bundleID": [
                                "type": "string",
                                "description": "Target application bundle ID"
                            ],
                            "window": [
                                "type": ["string", "number"],
                                "description": "Target window (title or index, optional)"
                            ],
                            "text": [
                                "type": "string",
                                "description": "Text to input"
                            ],
                            "element": [
                                "type": "object",
                                "properties": [
                                    "type": ["type": "string", "enum": ["button", "textfield", "text", "image", "menu", "list", "table", "checkbox", "radio", "slider"], "description": "Type of UI element"],
                                    "text": ["type": "string", "description": "Exact text displayed on or in the element"],
                                    "placeholder": ["type": "string", "description": "Placeholder text for text fields"],
                                    "label": ["type": "string", "description": "Accessibility label of the element"],
                                    "containing": ["type": "string", "description": "Text that the element contains (partial match)"],
                                    "index": ["type": "number", "description": "Index of the element when multiple elements match (0-based)"]
                                ],
                                "description": "Target text field (optional, uses focused element if not specified)"
                            ],
                            "method": [
                                "type": "string",
                                "enum": ["type", "setValue"],
                                "description": "Input method: type (keystroke simulation) or setValue (direct value setting, default: type)"
                            ],
                            "clearFirst": [
                                "type": "boolean",
                                "description": "Clear existing text before input (default: false)"
                            ]
                        ],
                        "required": ["bundleID", "text"]
                    ]
                ),
                
                MCP.Tool(
                    name: "drag_drop",
                    description: "Perform drag and drop operations",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "bundleID": [
                                "type": "string",
                                "description": "Target application bundle ID"
                            ],
                            "window": [
                                "type": ["string", "number"],
                                "description": "Target window (title or index, optional)"
                            ],
                            "from": [
                                "type": "object",
                                "properties": [
                                    "x": ["type": "number", "description": "Start X coordinate"],
                                    "y": ["type": "number", "description": "Start Y coordinate"]
                                ],
                                "required": ["x", "y"],
                                "description": "Start point for drag"
                            ],
                            "to": [
                                "type": "object",
                                "properties": [
                                    "x": ["type": "number", "description": "End X coordinate"],
                                    "y": ["type": "number", "description": "End Y coordinate"]
                                ],
                                "required": ["x", "y"],
                                "description": "End point for drag"
                            ],
                            "duration": [
                                "type": "number",
                                "description": "Duration in seconds (default: 1.0)"
                            ]
                        ],
                        "required": ["bundleID", "from", "to"]
                    ]
                ),
                
                MCP.Tool(
                    name: "scroll_window",
                    description: "Scroll within a window",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "bundleID": [
                                "type": "string",
                                "description": "Target application bundle ID"
                            ],
                            "window": [
                                "type": ["string", "number"],
                                "description": "Target window (title or index, optional)"
                            ],
                            "deltaX": [
                                "type": "number",
                                "description": "Horizontal scroll amount (positive = right, negative = left, default: 0)"
                            ],
                            "deltaY": [
                                "type": "number",
                                "description": "Vertical scroll amount (positive = down, negative = up)"
                            ],
                            "position": [
                                "type": "object",
                                "properties": [
                                    "x": ["type": "number", "description": "X coordinate for scroll position"],
                                    "y": ["type": "number", "description": "Y coordinate for scroll position"]
                                ],
                                "description": "Scroll position (optional, uses window center if not specified)"
                            ]
                        ],
                        "required": ["bundleID", "deltaY"]
                    ]
                ),
                
                // Information Tools
                MCP.Tool(
                    name: "find_elements",
                    description: "Find and list UI elements in a window",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "bundleID": [
                                "type": "string",
                                "description": "Target application bundle ID"
                            ],
                            "window": [
                                "type": ["string", "number"],
                                "description": "Target window (title or index, optional)"
                            ],
                            "type": [
                                "type": "string",
                                "enum": ["button", "textfield", "text", "image", "menu", "list", "table", "checkbox", "radio", "slider"],
                                "description": "Filter by UI element type (optional)"
                            ],
                            "text": [
                                "type": "string",
                                "description": "Filter by exact text content (optional)"
                            ],
                            "containing": [
                                "type": "string",
                                "description": "Filter by partial text content (optional)"
                            ],
                            "label": [
                                "type": "string",
                                "description": "Filter by accessibility label (optional)"
                            ],
                            "limit": [
                                "type": "number",
                                "description": "Maximum number of elements to return (default: 10)"
                            ]
                        ],
                        "required": ["bundleID"]
                    ]
                ),
                
                MCP.Tool(
                    name: "capture_screenshot",
                    description: "Capture a screenshot of a window",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "bundleID": [
                                "type": "string",
                                "description": "Target application bundle ID"
                            ],
                            "window": [
                                "type": ["string", "number"],
                                "description": "Target window (title or index, optional)"
                            ],
                            "format": [
                                "type": "string",
                                "enum": ["png", "jpeg"],
                                "description": "Image format (default: png)"
                            ]
                        ],
                        "required": ["bundleID"]
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
                                "description": "Duration to wait in seconds"
                            ]
                        ],
                        "required": ["duration"]
                    ]
                ),
                
                // Information Tools
                MCP.Tool(
                    name: "list_running_applications",
                    description: "Get list of currently running applications with metadata",
                    inputSchema: [
                        "type": "object",
                        "properties": [:],
                        "required": []
                    ]
                ),
                
                MCP.Tool(
                    name: "list_application_windows",
                    description: "Get list of all application windows with bounds and visibility info",
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
            case "find_elements":
                return await self.handleFindElements(arguments)
            case "capture_screenshot":
                return await self.handleCaptureScreenshot(arguments)
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
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    internal func handleInputText(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            guard case .string(_) = arguments["text"] else {
                throw AppMCPError.invalidParameters("Missing 'text' parameter")
            }
            
            let method = extractStringValue(arguments["method"]) ?? "type"
            let clearFirst = extractBoolValue(arguments["clearFirst"]) ?? false
            
            let result: String
            if method == "setValue" {
                result = try await performSetText(arguments)
            } else {
                result = try await performType(arguments, clearFirst: clearFirst)
            }
            
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    internal func handleDragDrop(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performDrag(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    internal func handleScrollWindow(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performScroll(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    internal func handleFindElements(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performFind(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    internal func handleCaptureScreenshot(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performScreenshot(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    internal func handleWaitTime(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await performWait(arguments)
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    internal func handleListRunningApplications(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await getApplications()
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    internal func handleListApplicationWindows(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            let result = try await getWindows()
            return CallTool.Result(content: [.text(result)])
        } catch {
            return CallTool.Result(
                content: [.text("Error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
    
    
    // MARK: - Action Implementations
    
    private func performClick(_ arguments: [String: MCP.Value]) async throws -> String {
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        if let elementValue = arguments["element"] {
            // Element-based click
            let element = try await findElement(in: window, using: elementValue)
            _ = try await pilot.clickElement(element, in: window)
            return "Clicked element \(element.role.rawValue) '\(element.title ?? element.id)' at (\(element.centerPoint.x), \(element.centerPoint.y))"
        } else if case .object(let coords) = arguments["coordinates"],
                  case .double(let x) = coords["x"],
                  case .double(let y) = coords["y"] {
            // Coordinate-based click
            let point = Point(x: x, y: y)
            _ = try await pilot.click(window: window, at: point)
            return "Clicked at coordinates (\(x), \(y))"
        } else {
            throw AppMCPError.invalidParameters("Missing 'element' or 'coordinates' parameter for click action")
        }
    }
    
    private func performSetText(_ arguments: [String: MCP.Value]) async throws -> String {
        guard case .string(let text) = arguments["text"] else {
            throw AppMCPError.invalidParameters("Missing 'text' parameter")
        }
        
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        if let elementValue = arguments["element"] {
            // Set text directly using AppPilot's setValue method (fast, direct)
            let element = try await findElement(in: window, using: elementValue)
            let result = try await pilot.setValue(text, for: element)
            let actualText: String
            if case .setValue(_, let actual) = result.data {
                actualText = actual ?? "unknown"
            } else {
                actualText = "unknown"
            }
            return "Set text '\(text)' in \(element.role.rawValue) '\(element.title ?? element.id)'. Actual text: \(actualText)"
        } else {
            throw AppMCPError.invalidParameters("setText action requires 'element' parameter")
        }
    }
    
    private func performType(_ arguments: [String: MCP.Value], clearFirst: Bool = false) async throws -> String {
        guard case .string(let text) = arguments["text"] else {
            throw AppMCPError.invalidParameters("Missing 'text' parameter")
        }
        
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        if let elementValue = arguments["element"] {
            let element = try await findElement(in: window, using: elementValue)
            
            if clearFirst {
                // Clear existing text first
                _ = try await pilot.setValue("", for: element)
            }
            
            let result = try await pilot.input(text: text, into: element)
            let actualText: String
            if case .type(_, let actual, _, _) = result.data {
                actualText = actual ?? "unknown"
            } else {
                actualText = "unknown"
            }
            return "Typed '\(text)' into \(element.role.rawValue) '\(element.title ?? element.id)'. Actual text: \(actualText)"
        } else {
            if clearFirst {
                // Clear focused element first - use Cmd+A to select all, then type to replace
                _ = try await pilot.type("", window: window)
            }
            
            _ = try await pilot.type(text, window: window)
            return "Typed '\(text)' into focused element"
        }
    }
    
    private func performDrag(_ arguments: [String: MCP.Value]) async throws -> String {
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        guard case .object(let fromCoords) = arguments["from"],
              case .double(let startX) = fromCoords["x"],
              case .double(let startY) = fromCoords["y"],
              case .object(let toCoords) = arguments["to"],
              case .double(let endX) = toCoords["x"],
              case .double(let endY) = toCoords["y"] else {
            throw AppMCPError.invalidParameters("Missing 'from' and 'to' parameters for drag action")
        }
        
        let startPoint = Point(x: startX, y: startY)
        let endPoint = Point(x: endX, y: endY)
        
        let duration: TimeInterval
        if case .double(let d) = arguments["duration"] {
            duration = d
        } else {
            duration = 1.0
        }
        
        _ = try await pilot.drag(from: startPoint, to: endPoint, duration: duration, window: window)
        return "Dragged from (\(startX), \(startY)) to (\(endX), \(endY)) over \(duration) seconds"
    }
    
    private func performScroll(_ arguments: [String: MCP.Value]) async throws -> String {
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        let deltaX: Double
        if case .double(let dx) = arguments["deltaX"] {
            deltaX = dx
        } else if case .int(let dx) = arguments["deltaX"] {
            deltaX = Double(dx)
        } else {
            deltaX = 0.0
        }
        
        let deltaY: Double
        if case .double(let dy) = arguments["deltaY"] {
            deltaY = dy
        } else if case .int(let dy) = arguments["deltaY"] {
            deltaY = Double(dy)
        } else {
            throw AppMCPError.invalidParameters("Missing 'deltaY' parameter for scroll action")
        }
        
        // Get scroll position - use window center if no coordinates specified
        let point: Point
        if case .object(let coords) = arguments["position"],
           case .double(let x) = coords["x"],
           case .double(let y) = coords["y"] {
            point = Point(x: x, y: y)
        } else {
            // Use window center for scroll
            let windows = try await pilot.listWindows(app: try await resolveApp(arguments))
            if let windowInfo = windows.first(where: { $0.id == window }) {
                let bounds = windowInfo.bounds
                point = Point(x: bounds.midX, y: bounds.midY)
            } else {
                point = Point(x: 400.0, y: 400.0) // Default center
            }
        }
        
        // Use AppPilot's safe scroll method with window context
        _ = try await pilot.scroll(deltaX: deltaX, deltaY: deltaY, at: point, window: window)
        
        return "Scrolled deltaX: \(deltaX), deltaY: \(deltaY) at (\(point.x), \(point.y))"
    }
    
    private func performWait(_ arguments: [String: MCP.Value]) async throws -> String {
        let duration: Double
        if case .double(let d) = arguments["duration"] {
            duration = d
        } else if case .int(let i) = arguments["duration"] {
            duration = Double(i)
        } else {
            duration = 1.0 // Default 1 second
        }
        
        try await pilot.wait(.time(seconds: duration))
        return "Waited \(duration) seconds"
    }
    
    private func performFind(_ arguments: [String: MCP.Value]) async throws -> String {
        let (_, window) = try await resolveAppAndWindow(arguments)
        
        let limit = extractIntValue(arguments["limit"]) ?? 10
        
        // Create criteria from arguments (excluding bundleID, window, and limit)
        var criteria: [String: MCP.Value] = [:]
        for (key, value) in arguments {
            if key != "bundleID" && key != "window" && key != "limit" {
                criteria[key] = value
            }
        }
        
        // Find elements with user-friendly criteria
        let elements = try await findElementsByUserCriteria(in: window, criteria: criteria)
        let limitedElements = Array(elements.prefix(limit))
        
        if limitedElements.isEmpty {
            let criteriaDesc = describeCriteria(criteria)
            return "No elements found matching criteria: \(criteriaDesc.isEmpty ? "all elements" : criteriaDesc)"
        }
        
        // Build hierarchical structure
        return try await buildHierarchicalResponse(elements: limitedElements, totalCount: elements.count, limit: limit)
    }
    
    private func getUserFriendlyType(for role: ElementRole) -> String {
        switch role {
        case .button, .popUpButton, .menuBarItem:
            return "button"
        case .textField, .searchField:
            return "textfield"
        case .staticText:
            return "text"
        case .image:
            return "image"
        case .menuBar, .menuItem:
            return "menu"
        case .list:
            return "list"
        case .table, .cell:
            return "table"
        case .checkBox:
            return "checkbox"
        case .radioButton:
            return "radio"
        case .slider:
            return "slider"
        default:
            return role.rawValue
        }
    }
    
    private func performScreenshot(_ arguments: [String: MCP.Value]) async throws -> String {
        let (app, window) = try await resolveAppAndWindow(arguments)
        
        let format = extractStringValue(arguments["format"]) ?? "png"
        
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
        
        let appData = apps.map { app in
            [
                "name": app.name,
                "bundleID": app.bundleIdentifier ?? "unknown",
                "handle": app.id.id,
                "isActive": app.isActive
            ] as [String: Any]
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
    
    // MARK: - Helper Methods
    
    private func extractStringValue(_ value: MCP.Value?) -> String? {
        guard case .string(let str) = value else { return nil }
        return str
    }
    
    // MARK: - User-Friendly Element Type Mapping
    
    private func mapUserTypeToElementRoles(_ userType: String) -> [ElementRole] {
        switch userType.lowercased() {
        case "button":
            return [.button, .popUpButton, .menuBarItem]
        case "textfield":
            return [.textField, .searchField]
        case "text":
            return [.staticText]
        case "image":
            return [.image]
        case "menu":
            return [.menuBar, .menuItem]
        case "list":
            return [.list]
        case "table":
            return [.table, .cell]
        case "checkbox":
            return [.checkBox]
        case "radio":
            return [.radioButton]
        case "slider":
            return [.slider]
        default:
            // Return all common interactive elements if type is unknown
            return [.button, .textField, .staticText, .image, .menuItem]
        }
    }
    
    private func findElementsByUserCriteria(in window: WindowHandle, criteria: [String: MCP.Value]) async throws -> [UIElement] {
        // Extract user-friendly criteria
        let userType = extractStringValue(criteria["type"])
        let exactText = extractStringValue(criteria["text"])
        let containingText = extractStringValue(criteria["containing"])
        let placeholderText = extractStringValue(criteria["placeholder"])
        let labelText = extractStringValue(criteria["label"])
        let index = extractIntValue(criteria["index"])
        
        // Convert user type to internal element roles
        let targetRoles: [ElementRole]?
        if let userType = userType {
            targetRoles = mapUserTypeToElementRoles(userType)
        } else {
            targetRoles = nil
        }
        
        // Find all elements matching the criteria
        var matchingElements: [UIElement] = []
        
        if let roles = targetRoles {
            // Search by specific roles
            for role in roles {
                let elementsForRole = try await pilot.findElements(in: window, role: role, title: nil, identifier: nil)
                matchingElements.append(contentsOf: elementsForRole)
            }
        } else {
            // Search all elements
            matchingElements = try await pilot.findElements(in: window)
        }
        
        // Filter by text criteria
        matchingElements = matchingElements.filter { element in
            // Check exact text match
            if let exactText = exactText {
                if element.title == exactText || element.value == exactText {
                    return true
                }
                // Also check if element has this text as accessibility label
                if element.id.contains(exactText) {
                    return true
                }
                return false
            }
            
            // Check containing text (partial match)
            if let containingText = containingText {
                let elementTexts = [element.title, element.value, element.id].compactMap { $0 }
                return elementTexts.contains { text in
                    text.localizedCaseInsensitiveContains(containingText)
                }
            }
            
            // Check placeholder text (for text fields)
            if let placeholderText = placeholderText {
                // Placeholder text is often stored in accessibility properties
                return element.title?.localizedCaseInsensitiveContains(placeholderText) == true ||
                       element.id.localizedCaseInsensitiveContains(placeholderText)
            }
            
            // Check label text
            if let labelText = labelText {
                return element.title?.localizedCaseInsensitiveContains(labelText) == true ||
                       element.id.localizedCaseInsensitiveContains(labelText)
            }
            
            // If no specific text criteria, include all elements
            return true
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
    
    private func extractIntValue(_ value: MCP.Value?) -> Int? {
        switch value {
        case .int(let int):
            return int
        case .double(let double):
            return Int(double)
        default:
            return nil
        }
    }
    
    private func extractBoolValue(_ value: MCP.Value?) -> Bool? {
        guard case .bool(let bool) = value else { return nil }
        return bool
    }
    
    private func resolveApp(_ arguments: [String: MCP.Value]) async throws -> AppHandle {
        // Try bundle ID first (more specific)
        if case .string(let bundleID) = arguments["bundleID"] {
            return try await pilot.findApplication(bundleId: bundleID)
        }
        
        // Then try app name
        if case .string(let appName) = arguments["appName"] {
            return try await pilot.findApplication(name: appName)
        }
        
        throw AppMCPError.invalidParameters("Missing 'appName' or 'bundleID' parameter")
    }
    
    private func resolveAppAndWindow(_ arguments: [String: MCP.Value]) async throws -> (AppHandle, WindowHandle) {
        // Get application
        let app = try await resolveApp(arguments)
        
        // Get window (optional for some actions)
        let window: WindowHandle
        if case .string(let windowTitle) = arguments["window"] {
            guard let foundWindow = try await pilot.findWindow(app: app, title: windowTitle) else {
                throw AppMCPError.windowNotFound("Window with title '\(windowTitle)' not found")
            }
            window = foundWindow
        } else if case .int(let index) = arguments["window"] {
            guard let foundWindow = try await pilot.findWindow(app: app, index: index) else {
                throw AppMCPError.windowNotFound("Window at index \(index) not found")
            }
            window = foundWindow
        } else {
            // Default to main window first, then fallback to first window
            let windows = try await pilot.listWindows(app: app)
            
            // Try to find the main window first
            if let mainWindow = windows.first(where: { $0.isMain }) {
                window = mainWindow.id
            } else if let firstWindow = windows.first {
                // Fallback to first available window
                window = firstWindow.id
            } else {
                throw AppMCPError.windowNotFound("No windows found for application")
            }
        }
        
        return (app, window)
    }
    
    private func findElement(in window: WindowHandle, using elementValue: MCP.Value?) async throws -> UIElement {
        guard case .object(let elementParams) = elementValue else {
            throw AppMCPError.invalidParameters("Missing element parameters")
        }
        
        // Use new user-friendly element finding
        let matchingElements = try await findElementsByUserCriteria(in: window, criteria: elementParams)
        
        guard let element = matchingElements.first else {
            let criteriaDesc = describeCriteria(elementParams)
            throw AppMCPError.elementNotFound("No element found matching criteria: \(criteriaDesc)")
        }
        
        return element
    }
    
    private func describeCriteria(_ criteria: [String: MCP.Value]) -> String {
        var parts: [String] = []
        
        if let type = extractStringValue(criteria["type"]) {
            parts.append("type=\(type)")
        }
        if let text = extractStringValue(criteria["text"]) {
            parts.append("text='\(text)'")
        }
        if let containing = extractStringValue(criteria["containing"]) {
            parts.append("containing='\(containing)'")
        }
        if let placeholder = extractStringValue(criteria["placeholder"]) {
            parts.append("placeholder='\(placeholder)'")
        }
        if let label = extractStringValue(criteria["label"]) {
            parts.append("label='\(label)'")
        }
        if let index = extractIntValue(criteria["index"]) {
            parts.append("index=\(index)")
        }
        
        return parts.isEmpty ? "no criteria" : parts.joined(separator: ", ")
    }
    
    private func buildHierarchicalResponse(elements: [UIElement], totalCount: Int, limit: Int) async throws -> String {
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
    
    private func groupElementsByFunction(_ elements: [UIElement]) -> [String: [UIElement]] {
        var groups: [String: [UIElement]] = [:]
        
        for element in elements {
            let groupName = determineElementGroup(element)
            if groups[groupName] == nil {
                groups[groupName] = []
            }
            groups[groupName]?.append(element)
        }
        
        return groups
    }
    
    private func determineElementGroup(_ element: UIElement) -> String {
        let userType = getUserFriendlyType(for: element.role)
        
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
    
    private func buildElementSummary(_ element: UIElement) -> String {
        let userType = getUserFriendlyType(for: element.role)
        let displayText = extractDisplayText(element)
        let coordinates = "(\(Int(element.centerPoint.x)), \(Int(element.centerPoint.y)))"
        
        if !displayText.isEmpty {
            return "\(userType): \"\(displayText)\" at \(coordinates)"
        } else {
            return "\(userType) at \(coordinates)"
        }
    }
    
    private func extractDisplayText(_ element: UIElement) -> String {
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
    
    // MARK: - Server Lifecycle
    
    public func start() async throws {
        print("🚀 AppMCP Server starting...")
        print("   Version: \(AppMCP.version)")
        print("   MCP Protocol: \(AppMCP.mcpVersion)")
        print("   Powered by: AppPilot")
        print("   Essential automation actions available")
        
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
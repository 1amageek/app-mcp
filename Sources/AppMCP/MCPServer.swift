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
                                    "type": [
                                        "type": "string",
                                        "enum": ["button", "textfield", "text", "image", "menu", "list", "table", "checkbox", "radio", "slider"],
                                        "description": "Type of UI element"
                                    ],
                                    "text": [
                                        "type": "string",
                                        "description": "Exact text displayed on or in the element"
                                    ],
                                    "placeholder": [
                                        "type": "string",
                                        "description": "Placeholder text for text fields"
                                    ],
                                    "label": [
                                        "type": "string",
                                        "description": "Accessibility label of the element"
                                    ],
                                    "containing": [
                                        "type": "string",
                                        "description": "Text that the element contains (partial match)"
                                    ],
                                    "index": [
                                        "type": "number",
                                        "description": "Index of the element when multiple elements match (0-based)"
                                    ]
                                ],
                                "description": "Target UI element (preferred method)"
                            ],
                            "coordinates": [
                                "type": "object",
                                "properties": [
                                    "x": [
                                        "type": "number",
                                        "description": "X coordinate"
                                    ],
                                    "y": [
                                        "type": "number",
                                        "description": "Y coordinate"
                                    ]
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
                                    "type": [
                                        "type": "string",
                                        "enum": ["button", "textfield", "text", "image", "menu", "list", "table", "checkbox", "radio", "slider"],
                                        "description": "Type of UI element"
                                    ],
                                    "text": [
                                        "type": "string",
                                        "description": "Exact text displayed on or in the element"
                                    ],
                                    "placeholder": [
                                        "type": "string",
                                        "description": "Placeholder text for text fields"
                                    ],
                                    "label": [
                                        "type": "string",
                                        "description": "Accessibility label of the element"
                                    ],
                                    "containing": [
                                        "type": "string",
                                        "description": "Text that the element contains (partial match)"
                                    ],
                                    "index": [
                                        "type": "number",
                                        "description": "Index of the element when multiple elements match (0-based)"
                                    ]
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
                                    "x": [
                                        "type": "number",
                                        "description": "Start X coordinate"
                                    ],
                                    "y": [
                                        "type": "number",
                                        "description": "Start Y coordinate"
                                    ]
                                ],
                                "required": ["x", "y"],
                                "description": "Start point for drag"
                            ],
                            "to": [
                                "type": "object",
                                "properties": [
                                    "x": [
                                        "type": "number",
                                        "description": "End X coordinate"
                                    ],
                                    "y": [
                                        "type": "number",
                                        "description": "End Y coordinate"
                                    ]
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
                                    "x": [
                                        "type": "number",
                                        "description": "X coordinate for scroll position"
                                    ],
                                    "y": [
                                        "type": "number",
                                        "description": "Y coordinate for scroll position"
                                    ]
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
        // Extract required bundleID using type-safe method
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        
        // Extract optional button type and click count
        let buttonType = extractOptionalString(from: arguments, key: "button") ?? "left"
        let clickCount = extractOptionalDouble(from: arguments, key: "clickCount").map { Int($0) } ?? 1
        
        // Resolve app and window
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        // Check for element parameter first (preferred method)
        if let elementObject = extractOptionalObject(from: arguments, key: "element") {
            let element = try await findElementWithCriteria(elementObject, in: window)
            
            // Use AppPilot's click method with button type and count parameters
            for _ in 0..<clickCount {
                _ = try await pilot.clickElement(element, in: window)
                if clickCount > 1 {
                    try await pilot.wait(.time(seconds: 0.1)) // Brief delay between multiple clicks
                }
            }
            
            let buttonDesc = buttonType == "left" ? "" : " (\(buttonType) button)"
            let countDesc = clickCount == 1 ? "" : " \(clickCount) times"
            return "Clicked\(buttonDesc) element \(element.role.rawValue) '\(element.title ?? element.id)'\(countDesc) at (\(element.centerPoint.x), \(element.centerPoint.y))"
        }
        
        // Fallback to coordinate-based click
        if let coordinatesObject = extractOptionalObject(from: arguments, key: "coordinates") {
            let x = try extractRequiredDouble(from: coordinatesObject, key: "x")
            let y = try extractRequiredDouble(from: coordinatesObject, key: "y")
            let point = Point(x: x, y: y)
            
            // Use coordinate-based clicking with button type and count
            for _ in 0..<clickCount {
                _ = try await pilot.click(window: window, at: point)
                if clickCount > 1 {
                    try await pilot.wait(.time(seconds: 0.1)) // Brief delay between multiple clicks
                }
            }
            
            let buttonDesc = buttonType == "left" ? "" : " (\(buttonType) button)"
            let countDesc = clickCount == 1 ? "" : " \(clickCount) times"
            return "Clicked\(buttonDesc)\(countDesc) at coordinates (\(x), \(y))"
        }
        
        throw AppMCPError.invalidParameters("Either 'element' or 'coordinates' parameter is required")
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
        guard case .string(let text) = arguments["text"] else {
            throw AppMCPError.invalidParameters("Missing 'text' parameter")
        }
        
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        if let elementObject = extractOptionalObject(from: arguments, key: "element") {
            // Set text directly using AppPilot's setValue method (fast, direct)
            let element = try await findElementWithCriteria(elementObject, in: window)
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
        
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        if let elementObject = extractOptionalObject(from: arguments, key: "element") {
            let element = try await findElementWithCriteria(elementObject, in: window)
            
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
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        // Extract 'from' coordinates using type-safe method
        let fromCoords = try extractRequiredObject(from: arguments, key: "from")
        let startX = try extractRequiredDouble(from: fromCoords, key: "x")
        let startY = try extractRequiredDouble(from: fromCoords, key: "y")
        
        // Extract 'to' coordinates using type-safe method
        let toCoords = try extractRequiredObject(from: arguments, key: "to")
        let endX = try extractRequiredDouble(from: toCoords, key: "x")
        let endY = try extractRequiredDouble(from: toCoords, key: "y")
        
        let startPoint = Point(x: startX, y: startY)
        let endPoint = Point(x: endX, y: endY)
        
        // Extract duration using type-safe method with default
        let duration = extractOptionalDouble(from: arguments, key: "duration") ?? 1.0
        
        _ = try await pilot.drag(from: startPoint, to: endPoint, duration: duration, window: window)
        return "Dragged from (\(startX), \(startY)) to (\(endX), \(endY)) over \(duration) seconds"
    }
    
    private func performScroll(_ arguments: [String: MCP.Value]) async throws -> String {
        let bundleID = try extractRequiredString(from: arguments, key: "bundleID")
        let app = try await pilot.findApplication(bundleId: bundleID)
        let window = try await resolveWindow(from: arguments, for: app)
        
        let deltaX = extractOptionalDouble(from: arguments, key: "deltaX") ?? 0.0
        let deltaY = try extractRequiredDouble(from: arguments, key: "deltaY")
        
        // Get scroll position - use window center if no coordinates specified
        let point: Point
        if let positionObject = extractOptionalObject(from: arguments, key: "position") {
            let x = try extractRequiredDouble(from: positionObject, key: "x")
            let y = try extractRequiredDouble(from: positionObject, key: "y")
            point = Point(x: x, y: y)
        } else {
            // Use window center for scroll
            let windows = try await pilot.listWindows(app: app)
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
        // Extract required duration parameter using type-safe method
        let duration = try extractRequiredDouble(from: arguments, key: "duration")
        
        // Validate duration is positive
        guard duration > 0 else {
            throw AppMCPError.invalidParameters("Duration must be positive, got \(duration)")
        }
        
        try await pilot.wait(.time(seconds: duration))
        return "Waited \(duration) seconds"
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
    
    private func findElementWithCriteria(_ criteria: [String: MCP.Value], in window: WindowHandle) async throws -> UIElement {
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
    ) async throws -> [UIElement] {
        // Convert user type to internal element roles
        let targetRoles: [ElementRole]?
        if let userType = userType {
            targetRoles = mapUserTypeToElementRoles(userType)
        } else {
            targetRoles = nil
        }
        
        // Find all elements matching the roles
        var matchingElements: [UIElement] = []
        
        if let roles = targetRoles {
            for role in roles {
                let elementsForRole = try await pilot.findElements(in: window, role: role, title: nil, identifier: nil)
                matchingElements.append(contentsOf: elementsForRole)
            }
        } else {
            matchingElements = try await pilot.findElements(in: window)
        }
        
        // Apply text-based filters
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
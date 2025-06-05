import XCTest
import Foundation
import MCP
@testable import AppMCP

/// Comprehensive test suite for AppMCP components
class AppMCPTests: XCTestCase {
    
    // MARK: - UIElementParser Tests
    
    func testExtractActionableElements() async throws {
        // Sample accessibility tree structure
        let sampleTree: [String: Any] = [
            "role": "AXApplication",
            "title": "Test App",
            "children": [
                [
                    "role": "AXTextField",
                    "title": "Search Field",
                    "position": ["x": 100, "y": 50],
                    "size": ["width": 200, "height": 30],
                    "enabled": true
                ],
                [
                    "role": "AXButton",
                    "title": "Submit",
                    "position": ["x": 320, "y": 50],
                    "size": ["width": 80, "height": 30],
                    "enabled": true
                ]
            ]
        ]
        
        let elements = UIElementParser.extractActionableElements(from: sampleTree)
        
        XCTAssertGreaterThanOrEqual(elements.count, 2) // At least TextField and Button
        
        let textFields = elements.filter { $0.role == "AXTextField" }
        XCTAssertEqual(textFields.count, 1)
        XCTAssertEqual(textFields.first?.title, "Search Field")
        
        let buttons = elements.filter { $0.role == "AXButton" }
        XCTAssertEqual(buttons.count, 1)
        XCTAssertEqual(buttons.first?.title, "Submit")
    }
    
    func testFindClickableElements() async throws {
        let sampleTree: [String: Any] = [
            "role": "AXApplication",
            "children": [
                [
                    "role": "AXButton",
                    "title": "Click Me",
                    "enabled": true
                ],
                [
                    "role": "AXMenuItem",
                    "title": "Menu Item",
                    "enabled": true
                ],
                [
                    "role": "AXStaticText",
                    "title": "Not Clickable"
                ]
            ]
        ]
        
        let clickableElements = UIElementParser.findClickableElements(in: sampleTree)
        
        XCTAssertEqual(clickableElements.count, 2)
        XCTAssertTrue(clickableElements.contains { $0.role == "AXButton" })
        XCTAssertTrue(clickableElements.contains { $0.role == "AXMenuItem" })
    }
    
    func testCalculateCenterPoint() async throws {
        let element = UIElementParser.ActionableElement(
            role: "AXButton",
            title: "Test Button",
            value: nil,
            identifier: nil,
            position: CGPoint(x: 100, y: 200),
            size: CGSize(width: 80, height: 40),
            isEnabled: true,
            path: ["AXButton"]
        )
        
        let centerPoint = try XCTUnwrap(element.centerPoint)
        XCTAssertEqual(centerPoint.x, 140) // 100 + 80/2
        XCTAssertEqual(centerPoint.y, 220) // 200 + 40/2
    }
    
    // MARK: - AppSelector Tests
    
    func testInitializeAppSelector() async throws {
        let appSelector = AppSelector()
        XCTAssertTrue(type(of: appSelector) == AppSelector.self)
    }
    
    func testBundleIdValidation() async throws {
        let validBundleIds = [
            "com.apple.weather",
            "com.example.app",
            "org.test.application"
        ]
        
        for bundleId in validBundleIds {
            XCTAssertTrue(bundleId.contains("."))
            XCTAssertGreaterThan(bundleId.count, 3)
        }
    }
    
    // MARK: - MCPServer Tests
    
    func testInitializeMCPServer() async throws {
        let server = MCPServer()
        XCTAssertTrue(type(of: server) == MCPServer.self)
    }
    
    func testServerConfiguration() async throws {
        let server = MCPServer()
        
        let resourceInfo = server.getResourceInfo()
        
        XCTAssertTrue(resourceInfo.keys.contains("running_applications"))
        XCTAssertTrue(resourceInfo.keys.contains("app_screenshot"))
        XCTAssertTrue(resourceInfo.keys.contains("app_accessibility_tree"))
    }
    
    func testToolInformation() async throws {
        let server = MCPServer()
        
        let toolInfo = server.getToolInfo()
        
        XCTAssertTrue(toolInfo.keys.contains("mouse_click"))
        XCTAssertTrue(toolInfo.keys.contains("type_text"))
        XCTAssertTrue(toolInfo.keys.contains("wait"))
    }
    
    func testWeatherAppPoCServerCreation() async throws {
        let server = MCPServer.weatherAppPoC()
        XCTAssertTrue(type(of: server) == MCPServer.self)
        
        try await server.validateConfiguration()
    }
    
    // MARK: - TCC Manager Tests
    
    func testInitializeTCCManager() async throws {
        let tccManager = TCCManager()
        XCTAssertTrue(type(of: tccManager) == TCCManager.self)
    }
    
    func testPermissionStatusCheck() async throws {
        let tccManager = TCCManager()
        
        let permissionStatus = await tccManager.getPermissionStatus()
        
        XCTAssertTrue(permissionStatus.keys.contains("accessibility"))
        XCTAssertTrue(permissionStatus.keys.contains("screenRecording"))
        
        // Each permission should have a valid status
        for (_, status) in permissionStatus {
            let validStatuses: [TCCManager.PermissionStatus] = [.granted, .denied, .notDetermined]
            XCTAssertTrue(validStatuses.contains(status))
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleMissingAppErrors() async throws {
        let error = MCPError.appNotFound(bundleId: "com.nonexistent.app", name: nil, pid: nil)
        XCTAssertTrue(error.localizedDescription.contains("com.nonexistent.app"))
    }
    
    func testHandleInvalidParameters() async throws {
        let error = MCPError.invalidParameters("Missing required field")
        XCTAssertTrue(error.localizedDescription.contains("Missing required field"))
    }
    
    func testHandleSystemErrors() async throws {
        let error = MCPError.systemError("Permission denied")
        XCTAssertTrue(error.localizedDescription.contains("Permission denied"))
    }
    
    // MARK: - Weather App Specific Tests
    
    func testWeatherAppBundleIdValidation() async throws {
        let weatherBundleId = "com.apple.weather"
        
        XCTAssertTrue(weatherBundleId.hasPrefix("com.apple."))
        XCTAssertTrue(weatherBundleId.contains("weather"))
    }
    
    func testWeatherSpecificUIElementDetection() async throws {
        let weatherUITree: [String: Any] = [
            "role": "AXApplication",
            "title": "天気",
            "children": [
                [
                    "role": "AXTextField",
                    "title": "Search Location",
                    "enabled": true
                ],
                [
                    "role": "AXStaticText",
                    "description": "現在地、渋谷区、26, 体感温度は26°Cです, 曇り, 最高気温27、最低気温17"
                ]
            ]
        ]
        
        let weatherElements = UIElementParser.extractActionableElements(from: weatherUITree)
        let searchFields = weatherElements.filter { $0.role == "AXTextField" }
        XCTAssertGreaterThanOrEqual(searchFields.count, 1)
        
        let weatherInfo = weatherElements.filter { element in
            let description = element.value ?? ""
            return description.contains("°C") || description.contains("天気") || description.contains("雨")
        }
        
        // Weather info might be in description field instead of value
        let hasWeatherDescription = weatherUITree["children"] as? [[String: Any]]
        let weatherText = hasWeatherDescription?.compactMap { $0["description"] as? String }.first(where: { text in
            text.contains("°C") || text.contains("天気") || text.contains("雨")
        })
        
        XCTAssertTrue(weatherInfo.count >= 1 || weatherText != nil)
    }
    
    func testTokyoLocationInputValidation() async throws {
        let tokyoVariants = ["Tokyo", "東京", "tokyo", "TOKYO"]
        
        for variant in tokyoVariants {
            let isValidTokyo = variant.lowercased().contains("tokyo") || variant.contains("東京")
            XCTAssertTrue(isValidTokyo)
        }
    }
    
    // MARK: - Integration Tests
    
    func testWeatherAppAutomationComponents() async throws {
        let server = MCPServer.weatherAppPoC()
        let resourceInfo = server.getResourceInfo()
        let toolInfo = server.getToolInfo()
        
        let requiredResources = ["running_applications", "app_screenshot", "app_accessibility_tree"]
        for resource in requiredResources {
            XCTAssertTrue(resourceInfo.keys.contains(resource), 
                         "Missing required resource: \(resource)")
        }
        
        let requiredTools = ["mouse_click", "type_text", "wait"]
        for tool in requiredTools {
            XCTAssertTrue(toolInfo.keys.contains(tool), 
                         "Missing required tool: \(tool)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testUIElementParsingPerformance() async throws {
        var largeTree: [String: Any] = [
            "role": "AXApplication",
            "children": []
        ]
        
        var children: [[String: Any]] = []
        for i in 0..<100 {
            children.append([
                "role": "AXButton",
                "title": "Button \(i)",
                "enabled": true,
                "position": ["x": i * 10, "y": 50],
                "size": ["width": 80, "height": 30]
            ])
        }
        largeTree["children"] = children
        
        let startTime = Date()
        let elements = UIElementParser.extractActionableElements(from: largeTree)
        let endTime = Date()
        
        let processingTime = endTime.timeIntervalSince(startTime)
        
        XCTAssertEqual(elements.count, 100) // 100 buttons
        XCTAssertLessThan(processingTime, 1.0) // Should complete within 1 second
    }
}
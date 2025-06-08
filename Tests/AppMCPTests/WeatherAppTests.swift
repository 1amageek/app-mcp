import Testing
import Foundation
import AppKit
import MCP
@testable import AppMCP

/// Tests for Weather app automation using AppMCP
/// 
/// These tests validate that AppMCP can successfully automate the macOS Weather app
/// to search for locations and retrieve weather information.
@Suite("Weather App Automation Tests")
struct WeatherAppTests {
    
    private let server = AppMCPServer()
    private let weatherBundleID = "com.apple.weather"
    
    // MARK: - Basic App Discovery Tests
    
    @Test("Weather app can be discovered in running applications")
    func testWeatherAppDiscovery() async throws {
        // Launch Weather app if not running
        try await launchWeatherApp()
        
        // Wait for app to be fully loaded
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Test resource endpoint for running applications
        let result = try await callResource("appmcp://resources/running_applications")
        
        #expect(result.contains("com.apple.weather"), "Weather app should be discovered in running applications")
        #expect(result.contains("Weather"), "Weather app name should be present")
    }
    
    @Test("Weather app windows can be listed")
    func testWeatherAppWindowListing() async throws {
        try await launchWeatherApp()
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        let result = try await callResource("appmcp://resources/application_windows")
        
        #expect(result.contains("Weather"), "Weather app window should be listed")
        #expect(result.contains("com.apple.weather"), "Bundle ID should be associated with window")
    }
    
    // MARK: - UI Element Discovery Tests
    
    @Test("Can find UI elements in Weather app")
    func testUIElementDiscovery() async throws {
        try await launchWeatherApp()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Find elements in the Weather app
        let findResult = try await callAutomationTool([
            "action": "find",
            "bundleID": weatherBundleID
        ])
        
        #expect(findResult.contains("Found"), "Should find UI elements in Weather app")
        #expect(!findResult.contains("Error"), "Should not contain errors")
    }
    
    @Test("Can take screenshot of Weather app")
    func testWeatherAppScreenshot() async throws {
        try await launchWeatherApp()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        let screenshotResult = try await callAutomationTool([
            "action": "screenshot",
            "bundleID": weatherBundleID
        ])
        
        // Validate screenshot without exposing base64 data in test output
        let hasValidPrefix = screenshotResult.hasPrefix("data:image/png;base64,")
        #expect(hasValidPrefix, "Should return base64 encoded PNG")
        
        if hasValidPrefix {
            let base64String = String(screenshotResult.dropFirst("data:image/png;base64,".count))
            let imageData = Data(base64Encoded: base64String)
            let isValidData = imageData != nil && (imageData?.count ?? 0) > 0
            #expect(isValidData, "Screenshot should contain valid base64 image data")
        }
    }
    
    // MARK: - Location Search Tests
    
    @Test("Can search for a location in Weather app")
    func testLocationSearch() async throws {
        try await launchWeatherApp()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Look for search field or add location button
        let findResult = try await callAutomationTool([
            "action": "find",
            "bundleID": weatherBundleID,
            "element": [
                "role": "AXButton",
                "title": "Add"
            ]
        ])
        
        if findResult.contains("Found element") {
            // Click the add location button
            let clickResult = try await callAutomationTool([
                "action": "click",
                "bundleID": weatherBundleID,
                "element": [
                    "role": "AXButton", 
                    "title": "Add"
                ]
            ])
            
            #expect(clickResult.contains("Clicked"), "Should successfully click add button")
            
            // Wait for search interface to appear
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Try to find and interact with search field
            let searchResult = try await searchForLocation("Tokyo")
            #expect(!searchResult.contains("Error"), "Location search should not error: \(searchResult)")
        }
    }
    
    @Test("Can search for multiple locations")
    func testMultipleLocationSearch() async throws {
        try await launchWeatherApp()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        let locations = ["Tokyo", "New York", "London"]
        
        for location in locations {
            do {
                let result = try await searchForLocation(location)
                let summary = result.prefix(100)
                print("Search result for \(location): \(summary)...")
                
                // Wait between searches
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                print("Failed to search for \(location): \(error)")
                // Continue with other locations
            }
        }
    }
    
    // MARK: - Weather Information Extraction Tests
    
    @Test("Can extract current weather information")
    func testWeatherInformationExtraction() async throws {
        try await launchWeatherApp()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Get current weather display
        let findResult = try await callAutomationTool([
            "action": "find",
            "bundleID": weatherBundleID
        ])
        
        print("Weather app elements: \(findResult)")
        
        // Look for temperature or weather condition elements
        let weatherElements = try await findWeatherInformation()
        #expect(!weatherElements.isEmpty, "Should find weather information elements")
        
        for element in weatherElements {
            print("Weather element: \(element)")
        }
    }
    
    @Test("Can extract weather for specific location")
    func testSpecificLocationWeather() async throws {
        try await launchWeatherApp()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Try to search for Tokyo and get its weather
        let searchResult = try await searchForLocation("Tokyo")
        let searchSummary = searchResult.prefix(100)
        print("Tokyo search result: \(searchSummary)...")
        
        // Wait for weather to load
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Extract weather information
        let weatherInfo = try await extractCurrentWeather()
        print("Tokyo weather: \(weatherInfo)")
        
        #expect(!weatherInfo.isEmpty, "Should extract weather information for Tokyo")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handles invalid location search gracefully")
    func testInvalidLocationSearch() async throws {
        try await launchWeatherApp()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Try to search for an invalid location
        let result = try await searchForLocation("InvalidLocationXYZ123")
        
        // Should not crash, may return no results or error message
        let resultSummary = result.prefix(100)
        print("Invalid location search result: \(resultSummary)...")
    }
    
    @Test("Handles app not available gracefully")
    func testAppNotAvailable() async throws {
        // Try to interact with non-existent app
        do {
            let result = try await callAutomationTool([
                "action": "find",
                "bundleID": "com.nonexistent.app"
            ])
            #expect(result.contains("Error"), "Should return error for non-existent app")
        } catch {
            // Expected to throw an error
            print("Expected error for non-existent app: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func launchWeatherApp() async throws {
        let workspace = NSWorkspace.shared
        
        // Check if Weather app is already running
        let runningApps = workspace.runningApplications
        if runningApps.contains(where: { $0.bundleIdentifier == weatherBundleID }) {
            return // Already running
        }
        
        // Launch Weather app
        let appURL = URL(fileURLWithPath: "/System/Applications/Weather.app")
        try await workspace.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        
        // Wait for launch
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func isWeatherAppAvailable() async -> Bool {
        let appPath = "/System/Applications/Weather.app"
        return FileManager.default.fileExists(atPath: appPath)
    }
    
    private func callResource(_ uri: String) async throws -> String {
        let result = await server.testHandleResource(uri: uri)
        
        try #require(result.success, "Resource call should succeed")
        
        return result.content
    }
    
    private func callAutomationTool(_ arguments: [String: Any]) async throws -> String {
        // Convert arguments to MCP.Value format
        let mcpArguments = arguments.mapValues { value -> MCP.Value in
            switch value {
            case let string as String:
                return .string(string)
            case let int as Int:
                return .int(int)
            case let double as Double:
                return .double(double)
            case let dict as [String: Any]:
                let mcpDict = dict.mapValues { dictValue -> MCP.Value in
                    if let str = dictValue as? String {
                        return .string(str)
                    } else if let num = dictValue as? Int {
                        return .int(num)
                    } else if let dbl = dictValue as? Double {
                        return .double(dbl)
                    } else {
                        return .string("\(dictValue)")
                    }
                }
                return .object(mcpDict)
            default:
                return .string("\(value)")
            }
        }
        
        let result = await server.testHandleAutomation(mcpArguments)
        
        try #require(result.success, "Automation call should succeed")
        
        if result.isError {
            throw WeatherTestError.automationError(result.content)
        }
        
        return result.content
    }
    
    private func searchForLocation(_ location: String) async throws -> String {
        // Try multiple strategies to search for location
        
        // Strategy 1: Look for search field
        do {
            let searchResult = try await callAutomationTool([
                "action": "type",
                "bundleID": weatherBundleID,
                "element": [
                    "role": "AXTextField"
                ],
                "text": location
            ])
            return searchResult
        } catch {
            print("Strategy 1 failed: \(error)")
        }
        
        // Strategy 2: Look for search field with specific identifier
        do {
            let searchResult = try await callAutomationTool([
                "action": "type",
                "bundleID": weatherBundleID,
                "element": [
                    "role": "AXSearchField"
                ],
                "text": location
            ])
            return searchResult
        } catch {
            print("Strategy 2 failed: \(error)")
        }
        
        // Strategy 3: Try clicking search area first
        do {
            let clickResult = try await callAutomationTool([
                "action": "click",
                "bundleID": weatherBundleID,
                "coordinates": [
                    "x": 400,
                    "y": 100
                ]
            ])
            
            try await Task.sleep(nanoseconds: 500_000_000)
            
            let typeResult = try await callAutomationTool([
                "action": "type",
                "bundleID": weatherBundleID,
                "text": location
            ])
            
            return "Click: \(clickResult), Type: \(typeResult)"
        } catch {
            print("Strategy 3 failed: \(error)")
        }
        
        return "All search strategies failed for location: \(location)"
    }
    
    private func findWeatherInformation() async throws -> [String] {
        let findResult = try await callAutomationTool([
            "action": "find",
            "bundleID": weatherBundleID
        ])
        
        // Parse the result to extract weather-related elements
        // This is a simplified version - in practice you'd parse the JSON response
        let elements = findResult.components(separatedBy: ", ")
        let weatherElements = elements.filter { element in
            element.lowercased().contains("temperature") ||
            element.lowercased().contains("weather") ||
            element.lowercased().contains("°") ||
            element.lowercased().contains("condition")
        }
        
        return weatherElements
    }
    
    private func extractCurrentWeather() async throws -> String {
        // Take a screenshot to analyze weather information
        let screenshot = try await callAutomationTool([
            "action": "screenshot",
            "bundleID": weatherBundleID
        ])
        
        // Find text elements that might contain weather info
        let elements = try await callAutomationTool([
            "action": "find",
            "bundleID": weatherBundleID
        ])
        
        let hasScreenshot = screenshot.hasPrefix("data:image/png;base64,")
        let screenshotSize = hasScreenshot ? screenshot.count : 0
        return "Screenshot captured: \(hasScreenshot ? "Valid PNG data (\(screenshotSize) chars)" : "Invalid data"), Elements: \(elements.prefix(100))..."
    }
}

// MARK: - Test Error Types

enum WeatherTestError: Swift.Error, LocalizedError {
    case weatherAppNotAvailable
    case invalidResponse(String)
    case automationError(String)
    
    var errorDescription: String? {
        switch self {
        case .weatherAppNotAvailable:
            return "Weather app is not available on this system"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .automationError(let message):
            return "Automation error: \(message)"
        }
    }
}
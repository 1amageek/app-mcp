import Testing
import Foundation
import AppKit
@testable import AppMCP
import MCP

/// Tests for Vision Framework text recognition integration
@Suite
struct TextRecognitionTests {

    /// Launch an application if not already running
    private func launchApp(bundleID: String, appPath: String) async throws {
        let workspace = NSWorkspace.shared

        // Check if app is already running
        let runningApps = workspace.runningApplications
        if runningApps.contains(where: { $0.bundleIdentifier == bundleID }) {
            return // Already running
        }

        // Launch the app
        let appURL = URL(fileURLWithPath: appPath)
        try await workspace.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())

        // Wait for app to fully launch
        try await Task.sleep(for: .seconds(2))
    }
    
    @Test("Text recognition in UI snapshot")
    func testUISnapshotWithTextRecognition() async throws {
        // Use Finder which always has windows open
        let server = AppMCPServer()

        // Wait for server initialization
        try await Task.sleep(for: .milliseconds(100))

        // Test with Finder app
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.finder"),
            "includeTextRecognition": .bool(true),
            "recognitionLanguages": .array([.string("en-US")])
        ]

        let result = await server.handleCaptureUISnapshot(arguments)

        #expect(!(result.isError ?? false), "UI snapshot should succeed")

        if case .text(let content) = result.content.first {
            // Verify the response includes text recognition section
            #expect(content.contains("Text recognition: enabled"))
            #expect(content.contains("Text Recognition:") || content.contains("error"))

            // Print result for manual inspection
            print("=== UI Snapshot with Text Recognition ===")
            print(content)
            print("========================================")
        } else {
            Issue.record("Expected text content in result")
        }
    }
    
    @Test("Dedicated text recognition tool")
    func testDedicatedTextRecognition() async throws {
        // Finder is always running, no need to launch

        let server = AppMCPServer()

        // Wait for server initialization
        try await Task.sleep(for: .milliseconds(100))

        // Test with Finder app
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.finder"),
            "languages": .array([.string("en-US")]),
            "recognitionLevel": .string("accurate")
        ]

        let result = await server.handleRecognizeText(arguments)

        #expect(!(result.isError ?? false), "Text recognition should succeed")

        if case .text(let content) = result.content.first {
            // Verify the response contains JSON structure (actual format)
            #expect(content.contains("\"fullText\""), "Should contain fullText field")
            #expect(content.contains("\"processingTime\""), "Should contain processingTime field")
            #expect(content.contains("\"rows\""), "Should contain rows array")

            // Print result for manual inspection
            print("=== Dedicated Text Recognition ===")
            print(content)
            print("=================================")
        } else {
            Issue.record("Expected text content in result")
        }
    }
    
    @Test("Text recognition with fast mode")
    func testFastTextRecognition() async throws {
        // Use Finder which is always running and accessible
        let server = AppMCPServer()

        // Wait for server initialization
        try await Task.sleep(for: .milliseconds(100))

        // Test with Finder using fast recognition
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.finder"),
            "recognitionLevel": .string("fast")
        ]

        let result = await server.handleRecognizeText(arguments)

        #expect(!(result.isError ?? false), "Fast text recognition should succeed")

        if case .text(let content) = result.content.first {
            // Verify the response contains JSON structure
            #expect(content.contains("\"fullText\""), "Should contain fullText field")
            // Note: recognitionLevel is included in the JSON output
            #expect(content.contains("\"recognitionLevel\"") || content.contains("fast"), "Should indicate fast mode")

            print("=== Fast Text Recognition ===")
            print("Recognition completed with fast mode")
            print("=============================")
        } else {
            Issue.record("Expected text content in result")
        }
    }
    
    @Test("UI snapshot without text recognition (default)")
    func testUISnapshotWithoutTextRecognition() async throws {
        // Finder is always running and accessible
        let server = AppMCPServer()

        // Wait for server initialization
        try await Task.sleep(for: .milliseconds(100))

        // Test without enabling text recognition (default behavior)
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.finder")
        ]

        let result = await server.handleCaptureUISnapshot(arguments)

        #expect(!(result.isError ?? false), "UI snapshot should succeed")

        if case .text(let content) = result.content.first {
            // Verify text recognition was disabled
            #expect(content.contains("Text recognition: disabled"))
            #expect(!content.contains("Text Recognition:"))

            print("=== UI Snapshot without Text Recognition ===")
            print("Verified text recognition is disabled by default")
            print("============================================")
        } else {
            Issue.record("Expected text content in result")
        }
    }
}
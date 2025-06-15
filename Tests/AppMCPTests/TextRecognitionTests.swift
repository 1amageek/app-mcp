import Testing
import Foundation
@testable import AppMCP
import MCP

/// Tests for Vision Framework text recognition integration
@Suite
struct TextRecognitionTests {
    
    @Test("Text recognition in UI snapshot")
    func testUISnapshotWithTextRecognition() async throws {
        let server = AppMCPServer()
        
        // Wait for server initialization
        try await Task.sleep(for: .milliseconds(100))
        
        // Test with TextEdit app (should be available on all macOS systems)
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.TextEdit"),
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
            // Verify the response includes recognition results
            #expect(content.contains("Text Recognition completed:"))
            #expect(content.contains("Recognition level: accurate"))
            #expect(content.contains("JSON Result:"))
            
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
        let server = AppMCPServer()
        
        // Wait for server initialization
        try await Task.sleep(for: .milliseconds(100))
        
        // Test with Safari app using fast recognition
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.Safari"),
            "recognitionLevel": .string("fast")
        ]
        
        let result = await server.handleRecognizeText(arguments)
        
        #expect(!(result.isError ?? false), "Fast text recognition should succeed")
        
        if case .text(let content) = result.content.first {
            // Verify fast mode was used
            #expect(content.contains("Recognition level: fast"))
            
            print("=== Fast Text Recognition ===")
            print("Recognition completed with fast mode")
            print("=============================")
        } else {
            Issue.record("Expected text content in result")
        }
    }
    
    @Test("UI snapshot without text recognition (default)")
    func testUISnapshotWithoutTextRecognition() async throws {
        let server = AppMCPServer()
        
        // Wait for server initialization
        try await Task.sleep(for: .milliseconds(100))
        
        // Test without enabling text recognition (default behavior)
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.Terminal")
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
import Testing
import Foundation
@testable import AppMCP
import MCP

@Suite("Screenshot Saving Tests")
struct ScreenshotSavingTests {
    
    @Test("Save Weather app screenshot to temp file")
    func testSaveWeatherScreenshot() async throws {
        let server = AppMCPServer()
        
        // Give server time to initialize
        try await Task.sleep(for: .milliseconds(100))
        
        // Take screenshot of Weather app
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.weather"),
            "format": .string("png")
        ]
        
        let result = await server.handleCaptureScreenshot(arguments)
        
        // Verify screenshot was taken successfully
        #expect(!(result.isError ?? false), "Screenshot should be taken without error")
        
        guard case .text(let base64Data) = result.content.first else {
            #expect(Bool(false), "Screenshot result should contain text data")
            return
        }
        
        // Extract data URL from the response (it's on the last line)
        let lines = base64Data.components(separatedBy: .newlines)
        let dataURL = lines.last { $0.hasPrefix("data:image/") } ?? ""
        
        // Verify it's a base64 data URL (PNG or JPEG since AppMCP may optimize format)
        let isPNG = dataURL.hasPrefix("data:image/png;base64,")
        let isJPEG = dataURL.hasPrefix("data:image/jpeg;base64,")
        #expect(isPNG || isJPEG, "Should be PNG or JPEG data URL")
        
        // Extract base64 string based on format
        let base64String: String
        if dataURL.hasPrefix("data:image/png;base64,") {
            base64String = String(dataURL.dropFirst("data:image/png;base64,".count))
        } else if dataURL.hasPrefix("data:image/jpeg;base64,") {
            base64String = String(dataURL.dropFirst("data:image/jpeg;base64,".count))
        } else {
            #expect(Bool(false), "Unknown image format in data URL")
            return
        }
        
        // Decode base64 to Data
        guard let imageData = Data(base64Encoded: base64String) else {
            #expect(Bool(false), "Should be valid base64 data")
            return
        }
        
        // Create temp directory path
        let tempDir = NSTemporaryDirectory()
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "weather_screenshot_\(timestamp).png"
        let filePath = (tempDir as NSString).appendingPathComponent(filename)
        
        // Save to file
        do {
            try imageData.write(to: URL(fileURLWithPath: filePath))
            print("✅ Screenshot saved to: \(filePath)")
            
            // Verify file exists and has content
            let fileSize = try FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int ?? 0
            #expect(fileSize > 0, "Screenshot file should have content")
            print("📊 Screenshot file size: \(fileSize) bytes")
            
        } catch {
            #expect(Bool(false), "Failed to save screenshot: \(error)")
        }
    }
    
    @Test("Save Finder screenshot to temp file")
    func testSaveFinderScreenshot() async throws {
        let server = AppMCPServer()
        
        // Give server time to initialize
        try await Task.sleep(for: .milliseconds(100))
        
        // Take screenshot of Finder
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.finder"),
            "format": .string("jpeg")
        ]
        
        let result = await server.handleCaptureScreenshot(arguments)
        
        // Verify screenshot was taken successfully
        #expect(!(result.isError ?? false), "Finder screenshot should be taken without error")
        
        guard case .text(let base64Data) = result.content.first else {
            #expect(Bool(false), "Screenshot result should contain text data")
            return
        }
        
        // Extract data URL from the response (it's on the last line)
        let lines = base64Data.components(separatedBy: .newlines)
        let dataURL = lines.last { $0.hasPrefix("data:image/") } ?? ""
        
        // Verify it's a base64 data URL (JPEG or PNG since format may be optimized)
        let isJPEG = dataURL.hasPrefix("data:image/jpeg;base64,")
        let isPNG = dataURL.hasPrefix("data:image/png;base64,")
        #expect(isJPEG || isPNG, "Should be JPEG or PNG data URL")
        
        // Extract base64 string based on format
        let base64String: String
        if dataURL.hasPrefix("data:image/jpeg;base64,") {
            base64String = String(dataURL.dropFirst("data:image/jpeg;base64,".count))
        } else if dataURL.hasPrefix("data:image/png;base64,") {
            base64String = String(dataURL.dropFirst("data:image/png;base64,".count))
        } else {
            #expect(Bool(false), "Unknown image format in data URL")
            return
        }
        
        // Decode base64 to Data
        guard let imageData = Data(base64Encoded: base64String) else {
            #expect(Bool(false), "Should be valid base64 data")
            return
        }
        
        // Create temp directory path
        let tempDir = NSTemporaryDirectory()
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "finder_screenshot_\(timestamp).jpg"
        let filePath = (tempDir as NSString).appendingPathComponent(filename)
        
        // Save to file
        do {
            try imageData.write(to: URL(fileURLWithPath: filePath))
            print("✅ Finder screenshot saved to: \(filePath)")
            
            // Verify file exists and has content
            let fileSize = try FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int ?? 0
            #expect(fileSize > 0, "Finder screenshot file should have content")
            print("📊 Finder screenshot file size: \(fileSize) bytes")
            
        } catch {
            #expect(Bool(false), "Failed to save Finder screenshot: \(error)")
        }
    }
    
    @Test("Save multiple app screenshots")
    func testSaveMultipleScreenshots() async throws {
        let server = AppMCPServer()
        
        // Give server time to initialize
        try await Task.sleep(for: .milliseconds(100))
        
        let apps = [
            ("com.apple.Terminal", "terminal"),
            ("com.apple.TextEdit", "textedit"),
            ("com.anthropic.claudefordesktop", "claude")
        ]
        
        let tempDir = NSTemporaryDirectory()
        let timestamp = Int(Date().timeIntervalSince1970)
        var savedFiles: [String] = []
        
        for (bundleID, appName) in apps {
            let arguments: [String: MCP.Value] = [
                "bundleID": .string(bundleID),
                "format": .string("png")
            ]
            
            let result = await server.handleCaptureScreenshot(arguments)
            
            if result.isError ?? false {
                print("⚠️ Could not capture \(appName) (may not be running)")
                continue
            }
            
            guard case .text(let base64Data) = result.content.first else {
                continue
            }
            
            // Extract data URL from the response
            let lines = base64Data.components(separatedBy: .newlines)
            let dataURL = lines.last { $0.hasPrefix("data:image/") } ?? ""
            
            // Handle both PNG and JPEG formats
            let base64String: String?
            if dataURL.hasPrefix("data:image/png;base64,") {
                base64String = String(dataURL.dropFirst("data:image/png;base64,".count))
            } else if dataURL.hasPrefix("data:image/jpeg;base64,") {
                base64String = String(dataURL.dropFirst("data:image/jpeg;base64,".count))
            } else {
                base64String = nil
            }
            
            if let base64StringToUse = base64String,
               let imageData = Data(base64Encoded: base64StringToUse) {
                    let filename = "\(appName)_screenshot_\(timestamp).png"
                    let filePath = (tempDir as NSString).appendingPathComponent(filename)
                    
                    do {
                        try imageData.write(to: URL(fileURLWithPath: filePath))
                        savedFiles.append(filePath)
                        print("✅ \(appName.capitalized) screenshot saved to: \(filePath)")
                        
                        let fileSize = try FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int ?? 0
                        print("📊 \(appName.capitalized) file size: \(fileSize) bytes")
                    } catch {
                        print("❌ Failed to save \(appName) screenshot: \(error)")
                    }
                }
        }
        
        #expect(savedFiles.count > 0, "At least one screenshot should be saved")
        print("📁 Saved \(savedFiles.count) screenshots to temp directory")
    }
    
    @Test("Test screenshot base64 format validation")
    func testScreenshotBase64Format() async throws {
        let server = AppMCPServer()
        
        // Take a screenshot and validate its base64 format
        let arguments: [String: MCP.Value] = [
            "bundleID": .string("com.apple.finder")
        ]
        
        let result = await server.handleCaptureScreenshot(arguments)
        
        guard !(result.isError ?? false), case .text(let base64Data) = result.content.first else {
            return // Skip if no screenshot available
        }
        
        // Extract data URL from the response
        let lines = base64Data.components(separatedBy: .newlines)
        let dataURL = lines.last { $0.hasPrefix("data:image/") } ?? ""
        
        // Validate data URL format
        let hasValidPrefix = dataURL.hasPrefix("data:image/png;base64,") || 
                           dataURL.hasPrefix("data:image/jpeg;base64,")
        #expect(hasValidPrefix, "Should start with data:image/png or data:image/jpeg")
        #expect(dataURL.contains(";base64,"), "Should contain ;base64,")
        
        // Extract and validate base64 content
        if let base64Range = dataURL.range(of: ";base64,") {
            let base64Content = String(dataURL[base64Range.upperBound...])
            #expect(!base64Content.isEmpty, "Base64 content should not be empty")
            
            // Test that it's valid base64
            let decodedData = Data(base64Encoded: base64Content)
            #expect(decodedData != nil, "Should be valid base64 encoding")
            #expect((decodedData?.count ?? 0) > 0, "Decoded data should have content")
        }
    }
}
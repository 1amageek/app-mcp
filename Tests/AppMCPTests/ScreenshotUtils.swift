import Foundation
import AppKit
@testable import AppMCP
import MCP

/// Utility functions for saving screenshots during testing
struct ScreenshotUtils {
    
    /// Save a screenshot of the specified app to the temp directory
    /// - Parameters:
    ///   - bundleID: The bundle ID of the app to screenshot
    ///   - appName: Human-readable name for the filename (optional)
    ///   - format: Image format ("png" or "jpeg", default: "png")
    /// - Returns: The path to the saved file, or nil if failed
    static func saveScreenshot(bundleID: String, appName: String? = nil, format: String = "png") async -> String? {
        let server = AppMCPServer()
        
        // Give server time to initialize
        try? await Task.sleep(for: .milliseconds(100))
        
        let arguments: [String: MCP.Value] = [
            "bundleID": .string(bundleID),
            "format": .string(format)
        ]
        
        let result = await server.handleCaptureUISnapshot(arguments)
        
        // Check if screenshot was successful
        guard !(result.isError ?? false),
              case .text(let base64Data) = result.content.first else {
            print("❌ Failed to capture screenshot for \(bundleID)")
            return nil
        }
        
        // Determine file extension based on format
        let fileExtension = format.lowercased() == "jpeg" || format.lowercased() == "jpg" 
            ? "jpg" 
            : "png"
        
        // Extract data URL from the response (it's on the last line)
        let lines = base64Data.components(separatedBy: CharacterSet.newlines)
        let dataURL = lines.last { $0.hasPrefix("data:image/") } ?? ""
        
        // Verify data URL format (accept both PNG and JPEG as AppMCP may optimize)
        let hasValidFormat = dataURL.hasPrefix("data:image/png;base64,") || 
                           dataURL.hasPrefix("data:image/jpeg;base64,")
        guard hasValidFormat else {
            print("❌ Invalid data URL format for \(bundleID)")
            return nil
        }
        
        // Extract base64 string based on actual format
        let base64String: String
        if dataURL.hasPrefix("data:image/png;base64,") {
            base64String = String(dataURL.dropFirst("data:image/png;base64,".count))
        } else if dataURL.hasPrefix("data:image/jpeg;base64,") {
            base64String = String(dataURL.dropFirst("data:image/jpeg;base64,".count))
        } else {
            print("❌ Unexpected data format for \(bundleID)")
            return nil
        }
        
        // Decode base64 to Data
        guard let imageData = Data(base64Encoded: base64String) else {
            print("❌ Invalid base64 data for \(bundleID)")
            return nil
        }
        
        // Create filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let name = appName ?? bundleID.replacingOccurrences(of: ".", with: "_")
        let filename = "\(name)_screenshot_\(timestamp).\(fileExtension)"
        
        // Save to temp directory
        let tempDir = NSTemporaryDirectory()
        let filePath = (tempDir as NSString).appendingPathComponent(filename)
        
        do {
            try imageData.write(to: URL(fileURLWithPath: filePath))
            let fileSize = try FileManager.default.attributesOfItem(atPath: filePath)[.size] as? Int ?? 0
            
            print("✅ Screenshot saved: \(filename)")
            print("📍 Path: \(filePath)")
            print("📊 Size: \(fileSize) bytes")
            
            return filePath
            
        } catch {
            print("❌ Failed to save screenshot: \(error)")
            return nil
        }
    }
    
    /// Save screenshots of multiple apps at once
    /// - Parameter apps: Array of (bundleID, appName) tuples
    /// - Returns: Array of successfully saved file paths
    static func saveMultipleScreenshots(_ apps: [(bundleID: String, appName: String)]) async -> [String] {
        var savedPaths: [String] = []
        
        print("📸 Taking screenshots of \(apps.count) apps...")
        
        for (bundleID, appName) in apps {
            if let path = await saveScreenshot(bundleID: bundleID, appName: appName) {
                savedPaths.append(path)
            } else {
                print("⚠️ Skipped \(appName) (\(bundleID))")
            }
        }
        
        print("📁 Saved \(savedPaths.count) of \(apps.count) screenshots")
        return savedPaths
    }
    
    /// Save screenshots of common macOS apps
    /// - Returns: Array of successfully saved file paths
    static func saveCommonAppScreenshots() async -> [String] {
        let commonApps = [
            (bundleID: "com.apple.finder", appName: "finder"),
            (bundleID: "com.apple.weather", appName: "weather"),
            (bundleID: "com.apple.Terminal", appName: "terminal"),
            (bundleID: "com.apple.TextEdit", appName: "textedit"),
            (bundleID: "com.apple.Safari", appName: "safari"),
            (bundleID: "com.apple.mail", appName: "mail"),
            (bundleID: "com.apple.Calendar", appName: "calendar"),
            (bundleID: "com.anthropic.claudefordesktop", appName: "claude"),
            (bundleID: "com.microsoft.VSCode", appName: "vscode"),
            (bundleID: "com.google.Chrome", appName: "chrome")
        ]
        
        return await saveMultipleScreenshots(commonApps)
    }
    
    /// Open the temp directory in Finder to view saved screenshots
    static func openTempDirectory() {
        let tempDir = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: tempDir)
        NSWorkspace.shared.open(url)
        print("📂 Opened temp directory: \(tempDir)")
    }
    
    /// Clean up old screenshot files (older than specified hours)
    static func cleanupOldScreenshots(olderThanHours hours: Int = 24) {
        let tempDir = NSTemporaryDirectory()
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: tempDir)
            let screenshotFiles = files.filter { $0.contains("screenshot") }
            
            let cutoffDate = Date().addingTimeInterval(-TimeInterval(hours * 3600))
            var deletedCount = 0
            
            for filename in screenshotFiles {
                let filePath = (tempDir as NSString).appendingPathComponent(filename)
                
                if let attributes = try? fileManager.attributesOfItem(atPath: filePath),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    
                    try? fileManager.removeItem(atPath: filePath)
                    deletedCount += 1
                }
            }
            
            print("🗑️ Cleaned up \(deletedCount) old screenshot files")
            
        } catch {
            print("❌ Failed to cleanup screenshots: \(error)")
        }
    }
}
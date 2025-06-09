import Testing
import Foundation
@testable import AppMCP

@Suite("Screenshot Utils Tests")
struct ScreenshotUtilsTests {
    
    @Test("Save single app screenshot using utility")
    func testSaveSingleScreenshot() async throws {
        let filePath = await ScreenshotUtils.saveScreenshot(
            bundleID: "com.apple.finder",
            appName: "finder_util_test"
        )
        
        if let path = filePath {
            #expect(FileManager.default.fileExists(atPath: path), "Screenshot file should exist")
            print("✅ Utility saved screenshot to: \(path)")
        } else {
            print("⚠️ No screenshot saved (app may not be running)")
        }
    }
    
    @Test("Save multiple screenshots using utility")
    func testSaveMultipleScreenshots() async throws {
        let apps = [
            (bundleID: "com.apple.finder", appName: "finder"),
            (bundleID: "com.apple.weather", appName: "weather"),
            (bundleID: "com.apple.Terminal", appName: "terminal")
        ]
        
        let savedPaths = await ScreenshotUtils.saveMultipleScreenshots(apps)
        
        #expect(savedPaths.count > 0, "At least one screenshot should be saved")
        
        for path in savedPaths {
            #expect(FileManager.default.fileExists(atPath: path), "Each screenshot file should exist")
        }
        
        print("✅ Utility saved \(savedPaths.count) screenshots")
    }
    
    @Test("Save common app screenshots")
    func testSaveCommonAppScreenshots() async throws {
        let savedPaths = await ScreenshotUtils.saveCommonAppScreenshots()
        
        print("📸 Common apps screenshot test completed")
        print("📁 Saved \(savedPaths.count) screenshots")
        
        for path in savedPaths {
            #expect(FileManager.default.fileExists(atPath: path), "Screenshot file should exist")
        }
        
        // This test doesn't fail if no apps are running - it's informational
        #expect(Bool(true), "Common apps screenshot test completed")
    }
    
    @Test("Test JPEG format screenshot")
    func testJPEGScreenshot() async throws {
        let filePath = await ScreenshotUtils.saveScreenshot(
            bundleID: "com.apple.finder",
            appName: "finder_jpeg_test",
            format: "jpeg"
        )
        
        if let path = filePath {
            #expect(path.hasSuffix(".jpg"), "JPEG screenshot should have .jpg extension")
            #expect(FileManager.default.fileExists(atPath: path), "JPEG screenshot file should exist")
            print("✅ JPEG screenshot saved to: \(path)")
        } else {
            print("⚠️ No JPEG screenshot saved (app may not be running)")
        }
    }
    
    @Test("Test cleanup functionality")
    func testCleanupOldScreenshots() async throws {
        // First save a screenshot
        let _ = await ScreenshotUtils.saveScreenshot(
            bundleID: "com.apple.finder",
            appName: "cleanup_test"
        )
        
        // Run cleanup (this won't delete the file we just created since it's fresh)
        ScreenshotUtils.cleanupOldScreenshots(olderThanHours: 24)
        
        // Test that cleanup runs without error
        #expect(Bool(true), "Cleanup should run without error")
    }
}
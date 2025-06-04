#!/usr/bin/env swift

import Foundation
import MCP
import AppMCP

// Test script to capture Weather app screenshot and accessibility tree

@main
struct WeatherCaptureTest {
    static func main() async {
        print("🧪 Testing Weather App Capture...")
        
        do {
            // Initialize components
            let tccManager = TCCManager()
            let appSelector = AppSelector()
            let screenshotProvider = AppScreenshotProvider(appSelector: appSelector, tccManager: tccManager)
            let axTreeProvider = AppAXTreeProvider(appSelector: appSelector, tccManager: tccManager)
            
            print("✅ Components initialized")
            
            // Check permissions
            print("🔍 Checking permissions...")
            let hasAccessibility = await tccManager.checkAccessibilityPermission()
            let hasScreenRecording = await tccManager.checkScreenRecordingPermission()
            print("   Accessibility: \(hasAccessibility)")
            print("   Screen Recording: \(hasScreenRecording)")
            
            // List running apps to verify Weather is running
            print("\n📱 Checking running applications...")
            let runningApps = await appSelector.listRunningApps()
            let weatherApp = runningApps.first { $0.bundleId == "com.apple.weather" }
            
            if let weather = weatherApp {
                print("✅ Weather app found:")
                print("   Bundle ID: \(weather.bundleId ?? "unknown")")
                print("   Name: \(weather.name)")
                print("   PID: \(weather.pid)")
                print("   Active: \(weather.isActive)")
            } else {
                print("❌ Weather app not found in running applications")
                return
            }
            
            // Test screenshot capture
            print("\n📸 Testing screenshot capture...")
            let screenshotParams = MCP.Value.object([
                "bundle_id": .string("com.apple.weather")
            ])
            
            let screenshotResult = try await screenshotProvider.handle(params: screenshotParams)
            
            if case let .object(resultDict) = screenshotResult {
                if case let .string(imageData) = resultDict["image_data"],
                   case let .string(format) = resultDict["format"],
                   case let .int(width) = resultDict["width"],
                   case let .int(height) = resultDict["height"] {
                    
                    print("✅ Screenshot captured successfully:")
                    print("   Format: \(format)")
                    print("   Size: \(width) x \(height)")
                    print("   Data size: \(imageData.count) characters (base64)")
                    
                    if let captureMethod = resultDict["capture_method"] {
                        print("   Capture method: \(captureMethod)")
                    }
                    
                    // Save to file for manual verification
                    if let imageDataDecoded = Data(base64Encoded: imageData) {
                        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
                        let filePath = desktopPath.appendingPathComponent("weather_screenshot.png")
                        try imageDataDecoded.write(to: filePath)
                        print("   💾 Screenshot saved to: \(filePath.path)")
                    }
                } else {
                    print("❌ Screenshot result has unexpected format")
                }
            } else {
                print("❌ Screenshot result is not an object")
            }
            
            // Test accessibility tree
            print("\n🌳 Testing accessibility tree extraction...")
            let axParams = MCP.Value.object([
                "bundle_id": .string("com.apple.weather")
            ])
            
            let axResult = try await axTreeProvider.handle(params: axParams)
            
            if case let .object(axResultDict) = axResult {
                if case let .string(treeJson) = axResultDict["tree"] {
                    print("✅ Accessibility tree extracted:")
                    print("   Tree size: \(treeJson.count) characters")
                    
                    // Save AX tree to file for analysis
                    let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
                    let axFilePath = desktopPath.appendingPathComponent("weather_ax_tree.json")
                    try treeJson.write(to: axFilePath, atomically: true, encoding: .utf8)
                    print("   💾 AX tree saved to: \(axFilePath.path)")
                    
                    // Show first few elements
                    if let treeData = treeJson.data(using: .utf8),
                       let jsonObject = try? JSONSerialization.jsonObject(with: treeData),
                       let tree = jsonObject as? [String: Any] {
                        print("   📋 Tree summary:")
                        if let role = tree["role"] as? String {
                            print("      Root role: \(role)")
                        }
                        if let title = tree["title"] as? String {
                            print("      Root title: \(title)")
                        }
                    }
                } else {
                    print("❌ AX tree result has unexpected format")
                }
            } else {
                print("❌ AX tree result is not an object")
            }
            
            print("\n🎉 Weather app capture test completed!")
            
        } catch {
            print("❌ Error during test: \(error)")
        }
    }
}
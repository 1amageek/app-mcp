import Foundation
import ScreenCaptureKit
import CoreGraphics
import UniformTypeIdentifiers

@available(macOS 15.0, *)
func testScreenCaptureKit() async {
    print("🧪 ScreenCaptureKit Test for Weather App")
    print("=========================================")
    
    do {
        // Get shareable content
        print("\n1️⃣ Getting shareable content...")
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        print("✅ Found \(content.applications.count) applications")
        print("✅ Found \(content.windows.count) windows")
        print("✅ Found \(content.displays.count) displays")
        
        // Find Weather app
        print("\n2️⃣ Finding Weather app...")
        guard let weatherApp = content.applications.first(where: { $0.bundleIdentifier == "com.apple.weather" }) else {
            print("❌ Weather app not found in shareable content")
            return
        }
        
        print("✅ Weather app found:")
        print("   Bundle ID: \(weatherApp.bundleIdentifier)")
        print("   Process ID: \(weatherApp.processID)")
        
        // Find Weather app windows
        print("\n3️⃣ Finding Weather app windows...")
        let weatherWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == "com.apple.weather" && window.isOnScreen
        }
        
        guard let mainWindow = weatherWindows.first else {
            print("❌ No Weather app windows found")
            return
        }
        
        print("✅ Found \(weatherWindows.count) Weather app window(s)")
        print("   Main window title: '\(mainWindow.title ?? "untitled")'")
        print("   Window frame: \(mainWindow.frame)")
        print("   Is on screen: \(mainWindow.isOnScreen)")
        
        // Create content filter
        print("\n4️⃣ Creating content filter...")
        let filter = SCContentFilter(desktopIndependentWindow: mainWindow)
        print("✅ Content filter created for Weather app window")
        
        // Configure capture
        print("\n5️⃣ Configuring capture...")
        let config = SCStreamConfiguration()
        config.width = Int(mainWindow.frame.width)
        config.height = Int(mainWindow.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        
        print("✅ Capture configuration:")
        print("   Size: \(config.width) x \(config.height)")
        print("   Pixel format: \(config.pixelFormat)")
        
        // Perform capture
        print("\n6️⃣ Performing screenshot capture...")
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        print("✅ Screenshot captured successfully!")
        print("   Image size: \(image.width) x \(image.height)")
        print("   Bits per component: \(image.bitsPerComponent)")
        print("   Bits per pixel: \(image.bitsPerPixel)")
        
        // Convert to PNG and save
        print("\n7️⃣ Saving screenshot...")
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            print("❌ Failed to create image destination")
            return
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            print("❌ Failed to finalize image destination")
            return
        }
        
        let pngData = mutableData as Data
        let base64String = pngData.base64EncodedString()
        
        // Save to Desktop
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let timestamp = DateFormatter().apply {
            $0.dateFormat = "yyyyMMdd_HHmmss"
        }.string(from: Date())
        
        let pngFile = desktopPath.appendingPathComponent("weather_screencapture_\(timestamp).png")
        try pngData.write(to: pngFile)
        
        print("✅ Screenshot saved:")
        print("   File: \(pngFile.path)")
        print("   Size: \(pngData.count) bytes")
        print("   Base64 size: \(base64String.count) characters")
        
    } catch {
        print("❌ ScreenCaptureKit error: \(error)")
    }
    
    print("\n🎉 ScreenCaptureKit test completed!")
}

extension DateFormatter {
    func apply(closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}

// Make sure Weather app is visible and run the test
if #available(macOS 15.0, *) {
    await testScreenCaptureKit()
} else {
    print("❌ ScreenCaptureKit requires macOS 15.0 or later")
}
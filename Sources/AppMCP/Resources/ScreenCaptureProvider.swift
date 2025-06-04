import Foundation
import ScreenCaptureKit
import CoreGraphics
import UniformTypeIdentifiers

/// Modern screenshot provider using ScreenCaptureKit for macOS 15+
@available(macOS 15.0, *)
public final class ScreenCaptureProvider: @unchecked Sendable {
    
    public init() {}
    
    /// Captures a screenshot of the specified application window using one-shot capture
    public func captureWindow(for bundleId: String) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Find the target application
        guard let app = content.applications.first(where: { $0.bundleIdentifier == bundleId }) else {
            throw ScreenCaptureError.applicationNotFound(bundleId)
        }
        
        // Get windows owned by the application
        let windows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == bundleId && window.isOnScreen
        }
        
        guard let mainWindow = windows.first else {
            throw ScreenCaptureError.noWindowsFound(bundleId)
        }
        
        // Create content filter for the specific window
        let filter = SCContentFilter(desktopIndependentWindow: mainWindow)
        
        // Configure capture settings
        let config = SCStreamConfiguration()
        config.width = Int(mainWindow.frame.width)
        config.height = Int(mainWindow.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        
        // Create a one-shot capture
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        return image
    }
    
    /// Captures all windows of the specified application
    public func captureApplication(bundleId: String) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Find the target application
        guard let app = content.applications.first(where: { $0.bundleIdentifier == bundleId }) else {
            throw ScreenCaptureError.applicationNotFound(bundleId)
        }
        
        // Get all visible windows of the application
        let windows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == bundleId && window.isOnScreen
        }
        
        guard !windows.isEmpty else {
            throw ScreenCaptureError.noWindowsFound(bundleId)
        }
        
        // Create content filter for the application
        let filter = SCContentFilter(
            display: content.displays.first!,
            including: [app],
            exceptingWindows: []
        )
        
        // Configure capture settings
        let config = SCStreamConfiguration()
        config.width = 1920
        config.height = 1080
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        
        // Create a one-shot capture
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        
        return image
    }
    
    /// Converts CGImage to PNG data
    public func convertToPNG(_ image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
}

/// Errors that can occur during screen capture
public enum ScreenCaptureError: Error, LocalizedError {
    case applicationNotFound(String)
    case noWindowsFound(String)
    case conversionFailed
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let bundleId):
            return "Application with bundle ID '\(bundleId)' not found"
        case .noWindowsFound(let bundleId):
            return "No visible windows found for application '\(bundleId)'"
        case .conversionFailed:
            return "Failed to convert screen capture to image"
        case .permissionDenied:
            return "Screen recording permission denied"
        }
    }
}
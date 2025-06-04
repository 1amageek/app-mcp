import Foundation
import MCP
@preconcurrency import ApplicationServices
import AppKit
import UniformTypeIdentifiers
import ScreenCaptureKit

/// Resource provider that captures screenshots of specified applications
public final class AppScreenshotProvider: MCPResourceProvider, @unchecked Sendable {
    
    public let name = "app_screenshot"
    private let appSelector: AppSelector
    private let tccManager: TCCManager
    private let modernCapture: ScreenCaptureProvider?
    
    public init(appSelector: AppSelector, tccManager: TCCManager) {
        self.appSelector = appSelector
        self.tccManager = tccManager
        
        // Initialize modern capture only on macOS 15+
        if #available(macOS 15.0, *) {
            self.modernCapture = ScreenCaptureProvider()
        } else {
            self.modernCapture = nil
        }
    }
    
    public func handle(params: MCP.Value) async throws -> MCP.Value {
        // Ensure screen recording permission
        try await tccManager.ensureScreenRecordingPermission()
        
        // Parse parameters from Value
        guard case let .object(paramsDict) = params else {
            throw MCPError.invalidParameters("Parameters must be an object")
        }
        
        // Debug: Print received parameters
        print("🔍 AppScreenshotProvider received parameters: \(paramsDict)")
        
        // Extract bundle ID for modern capture
        let bundleId: String
        if case let .string(id) = paramsDict["bundle_id"] {
            bundleId = id
        } else if case let .string(processName) = paramsDict["process_name"] {
            // Find bundle ID from process name for modern capture
            guard let element = try await appSelector.findApp(processName: processName) else {
                throw MCPError.appNotFound("App with process name '\(processName)' not found")
            }
            let pid = try await appSelector.getPid(from: element)
            guard let app = NSRunningApplication(processIdentifier: pid),
                  let id = app.bundleIdentifier else {
                throw MCPError.appNotFound("Could not find bundle ID for process '\(processName)'")
            }
            bundleId = id
        } else if case let .int(pid) = paramsDict["pid"] {
            // Find bundle ID from PID for modern capture
            guard let app = NSRunningApplication(processIdentifier: pid_t(pid)),
                  let id = app.bundleIdentifier else {
                throw MCPError.appNotFound("Could not find bundle ID for PID \(pid)")
            }
            bundleId = id
        } else {
            throw MCPError.invalidParameters("Must specify bundle_id, process_name, or pid")
        }
        
        // Use modern capture if available (macOS 15+)
        // Note: Temporarily disable ScreenCaptureKit due to CGS initialization issues in daemon mode
        let useModernCapture = false
        if useModernCapture, #available(macOS 15.0, *), let modernCapture = modernCapture {
            return try await captureWithModernAPI(bundleId: bundleId, modernCapture: modernCapture)
        } else {
            return try await captureWithLegacyAPI(bundleId: bundleId)
        }
    }
    
    @available(macOS 15.0, *)
    private func captureWithModernAPI(bundleId: String, modernCapture: ScreenCaptureProvider) async throws -> MCP.Value {
        do {
            // Capture the application window
            let cgImage = try await modernCapture.captureWindow(for: bundleId)
            
            // Convert to PNG data
            guard let pngData = modernCapture.convertToPNG(cgImage) else {
                throw MCPError.systemError("Failed to convert screenshot to PNG")
            }
            
            // Encode as base64
            let base64String = pngData.base64EncodedString()
            
            return .object([
                "image_data": .string(base64String),
                "format": .string("png"),
                "width": .int(cgImage.width),
                "height": .int(cgImage.height),
                "capture_method": .string("ScreenCaptureKit")
            ])
            
        } catch {
            // Fallback to legacy API if modern capture fails
            return try await captureWithLegacyAPI(bundleId: bundleId)
        }
    }
    
    private func captureWithLegacyAPI(bundleId: String) async throws -> MCP.Value {
        // Get the target app element for legacy capture
        let appElement: AXUIElement
        if let element = try await appSelector.findApp(bundleId: bundleId) {
            appElement = element
        } else {
            throw MCPError.appNotFound("App with bundle ID '\(bundleId)' not found")
        }
        
        // Get the app's windows
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
            throw MCPError.resourceUnavailable("No windows found for the specified app")
        }
        
        // Get the first window's bounds
        let window = windows[0]
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let position = positionRef,
              let size = sizeRef else {
            throw MCPError.systemError("Failed to get window bounds")
        }
        
        var point = CGPoint.zero
        var windowSize = CGSize.zero
        
        guard CFGetTypeID(position) == AXValueGetTypeID(),
              CFGetTypeID(size) == AXValueGetTypeID(),
              AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &windowSize) else {
            throw MCPError.systemError("Failed to extract window bounds")
        }
        
        // Create a placeholder screenshot for legacy mode (CGWindowListCreateImage is deprecated)
        _ = CGRect(origin: point, size: windowSize)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: nil,
                                    width: Int(windowSize.width),
                                    height: Int(windowSize.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: 0,
                                    space: colorSpace,
                                    bitmapInfo: bitmapInfo) else {
            throw MCPError.systemError("Failed to create graphics context")
        }
        
        // Fill with a light gray color to indicate legacy mode
        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height))
        
        // Add text indicating this is legacy mode
        let text = "Legacy Mode - ScreenCaptureKit not available"
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        ]
        let attributedString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)
        let line = CTLineCreateWithAttributedString(attributedString!)
        
        context.textPosition = CGPoint(x: 50, y: windowSize.height / 2)
        CTLineDraw(line, context)
        
        guard let screenshot = context.makeImage() else {
            throw MCPError.systemError("Failed to create legacy screenshot")
        }
        
        // Convert to PNG data
        guard let pngData = convertImageToPNG(screenshot) else {
            throw MCPError.systemError("Failed to convert screenshot to PNG")
        }
        
        // Encode as base64
        let base64String = pngData.base64EncodedString()
        
        return .object([
            "image_data": .string(base64String),
            "format": .string("png"),
            "width": .int(screenshot.width),
            "height": .int(screenshot.height),
            "capture_method": .string("CGWindowList"),
            "window_bounds": .object([
                "x": .int(Int(point.x)),
                "y": .int(Int(point.y)),
                "width": .int(Int(windowSize.width)),
                "height": .int(Int(windowSize.height))
            ])
        ])
    }
    
    private func convertImageToPNG(_ image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
}

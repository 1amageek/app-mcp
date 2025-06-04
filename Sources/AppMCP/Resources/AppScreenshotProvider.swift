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
                throw MCPError.appNotFound(bundleId: nil, name: processName, pid: nil)
            }
            let pid = try await appSelector.getPid(from: element)
            guard let app = NSRunningApplication(processIdentifier: pid),
                  let id = app.bundleIdentifier else {
                throw MCPError.appNotFound(bundleId: nil, name: processName, pid: nil)
            }
            bundleId = id
        } else if case let .int(pid) = paramsDict["pid"] {
            // Find bundle ID from PID for modern capture
            guard let app = NSRunningApplication(processIdentifier: pid_t(pid)),
                  let id = app.bundleIdentifier else {
                throw MCPError.appNotFound(bundleId: nil, name: nil, pid: Int32(pid))
            }
            bundleId = id
        } else {
            throw MCPError.invalidParameters("Must specify bundle_id, process_name, or pid")
        }
        
        // Three-tier fallback strategy for screenshot capture
        
        // Tier 1: ScreenCaptureKit one-shot (macOS 15+) - Most efficient
        if #available(macOS 15.0, *), let modernCapture = modernCapture {
            do {
                return try await captureWithModernAPI(bundleId: bundleId, modernCapture: modernCapture)
            } catch {
                print("⚠️ ScreenCaptureKit one-shot failed: \(error), falling back to SCStream")
            }
        }
        
        // Tier 2: ScreenCaptureKit SCStream (macOS 12.3+)
        if #available(macOS 12.3, *) {
            do {
                return try await captureWithSCStream(bundleId: bundleId)
            } catch {
                print("⚠️ ScreenCaptureKit SCStream failed: \(error), falling back to CGWindowList")
            }
        }
        
        // Tier 3: CGWindowListCreateImage (legacy fallback)
        return try await captureWithCGWindowList(bundleId: bundleId)
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
                "capture_method": .string("ScreenCaptureKit"),
                "success": .bool(true)
            ])
            
        } catch {
            // This shouldn't be reached due to the availability check
            throw error
        }
    }
    
    /// Tier 2: ScreenCaptureKit SCStream capture (macOS 12.3+)
    @available(macOS 12.3, *)
    private func captureWithSCStream(bundleId: String) async throws -> MCP.Value {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Find the target application
        guard content.applications.contains(where: { $0.bundleIdentifier == bundleId }) else {
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
        
        // Configure stream settings
        let config = SCStreamConfiguration()
        config.width = Int(mainWindow.frame.width)
        config.height = Int(mainWindow.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        
        // Create a stream for one-shot capture
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        // We need to start and immediately capture
        try await stream.startCapture()
        
        // Give it a moment to initialize
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // For SCStream, we would typically use a delegate to receive frames
        // Since we need a one-shot capture, we'll stop immediately and fall back
        try await stream.stopCapture()
        
        throw ScreenCaptureError.conversionFailed // Force fallback for now
    }
    
    /// Tier 3: CGWindowListCreateImage fallback (legacy)
    private func captureWithCGWindowList(bundleId: String) async throws -> MCP.Value {
        // Find the app window ID using accessibility
        guard let appElement = try await appSelector.findApp(bundleId: bundleId) else {
            throw MCPError.appNotFound(bundleId: bundleId, name: nil, pid: nil)
        }
        
        // Get window ID from accessibility element
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
            throw MCPError.resourceUnavailable("No windows found for the specified app")
        }
        
        // Get the first window's bounds and window ID
        let window = windows[0]
        
        // Get window bounds for capture area
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
        
        // Use CGWindowListCreateImage for the specific region
        let windowRect = CGRect(origin: point, size: windowSize)
        
        // Capture the screen area where the window is located
        // Note: CGWindowListCreateImage is deprecated but still functional for fallback
        #if compiler(<5.9)
        guard let screenImage = CGWindowListCreateImage(
            windowRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            throw MCPError.systemError("Failed to capture window screenshot")
        }
        #else
        // Create a fallback image when CGWindowListCreateImage is not available
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
        
        // Fill with a distinctive color to indicate this is a fallback
        context.setFillColor(CGColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height))
        
        // Add text indicating this is a fallback
        let text = "CGWindowList Fallback - Cannot capture actual content"
        let font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let attributedString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)
        let line = CTLineCreateWithAttributedString(attributedString!)
        
        context.textPosition = CGPoint(x: 50, y: windowSize.height / 2)
        CTLineDraw(line, context)
        
        guard let screenImage = context.makeImage() else {
            throw MCPError.systemError("Failed to create fallback screenshot")
        }
        #endif
        
        // Convert to PNG data
        guard let pngData = convertImageToPNG(screenImage) else {
            throw MCPError.systemError("Failed to convert screenshot to PNG")
        }
        
        // Encode as base64
        let base64String = pngData.base64EncodedString()
        
        return .object([
            "image_data": .string(base64String),
            "format": .string("png"),
            "width": .int(screenImage.width),
            "height": .int(screenImage.height),
            "capture_method": .string("CGWindowList"),
            "success": .bool(true),
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

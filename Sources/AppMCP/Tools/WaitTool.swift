import Foundation
import MCP
import ApplicationServices
import AppKit

/// Tool executor that provides wait functionality for UI state changes
public final class WaitTool: MCPToolExecutor, @unchecked Sendable {
    
    public let name = "wait"
    
    public init() {}
    
    public func handle(params: MCP.Value) async throws -> MCP.Value {
        // Parse parameters from Value
        guard case let .object(paramsDict) = params else {
            throw MCPError.invalidParameters("Parameters must be an object")
        }
        
        let durationMs = (paramsDict["duration_ms"].flatMap { if case let .int(d) = $0 { return d } else { return nil } }) ?? 1000
        let condition = (paramsDict["condition"].flatMap { if case let .string(c) = $0 { return c } else { return nil } }) ?? "time"
        
        // Validate duration
        guard durationMs > 0 && durationMs <= 30000 else { // Max 30 seconds
            throw MCPError.invalidParameters("Duration must be between 1 and 30000 milliseconds")
        }
        
        let startTime = Date()
        
        switch condition.lowercased() {
        case "time":
            // Simple time-based wait
            try await Task.sleep(nanoseconds: UInt64(durationMs) * 1_000_000)
            
        case "ui_change":
            // Wait for UI change (simplified implementation)
            try await waitForUIChange(maxDurationMs: durationMs)
            
        default:
            throw MCPError.invalidParameters("Invalid condition. Use 'time' or 'ui_change'")
        }
        
        let endTime = Date()
        let actualDuration = Int(endTime.timeIntervalSince(startTime) * 1000)
        
        return .object([
            "success": .bool(true),
            "action": .string("wait"),
            "condition": .string(condition),
            "requested_duration_ms": .int(durationMs),
            "actual_duration_ms": .int(actualDuration)
        ])
    }
    
    private func waitForUIChange(maxDurationMs: Int) async throws {
        let startTime = Date()
        let maxDuration = TimeInterval(maxDurationMs) / 1000.0
        
        // Take initial screenshot for comparison
        guard let initialScreenshot = captureScreen() else {
            // If we can't capture screen, fall back to time-based wait
            try await Task.sleep(nanoseconds: UInt64(maxDurationMs) * 1_000_000)
            return
        }
        
        // Poll for changes every 100ms
        let pollInterval: UInt64 = 100_000_000 // 100ms in nanoseconds
        
        while Date().timeIntervalSince(startTime) < maxDuration {
            try await Task.sleep(nanoseconds: pollInterval)
            
            guard let currentScreenshot = captureScreen() else {
                continue
            }
            
            // Simple comparison - if screenshots are different, UI has changed
            if !areImagesEqual(initialScreenshot, currentScreenshot) {
                return
            }
        }
        
        // Timeout reached
    }
    
    private func captureScreen() -> CGImage? {
        // Simple fallback implementation - return nil to force time-based wait
        // TODO: Implement using ScreenCaptureKit for macOS 15+
        return nil
    }
    
    private func areImagesEqual(_ image1: CGImage, _ image2: CGImage) -> Bool {
        // Simple comparison based on image properties
        return image1.width == image2.width &&
               image1.height == image2.height &&
               image1.bitsPerComponent == image2.bitsPerComponent &&
               image1.bitsPerPixel == image2.bitsPerPixel
        // Note: This is a simplified comparison. A more robust implementation
        // would compare actual pixel data, but that's beyond the scope of this PoC
    }
}

import Foundation
import AppKit
import ApplicationServices

public actor CoordinateConverter {
    
    public enum CoordinateSpace {
        case window
        case screen(displayId: CGDirectDisplayID)
        case global
    }
    
    public init() {}
    
    public func toGlobal(
        x: Double, 
        y: Double, 
        from space: CoordinateSpace, 
        window: AXUIElement? = nil, 
        screenId: CGDirectDisplayID? = nil
    ) async throws -> CGPoint {
        
        switch space {
        case .window:
            guard let window = window else {
                throw MCPError.invalidParameters("Window handle required for window coordinates")
            }
            
            // Get window position and size
            let windowFrame = try getWindowFrame(from: window)
            
            // Window coordinates: origin at top-left, Y increases downward
            // Convert to global coordinates (same coordinate system for macOS)
            return CGPoint(x: windowFrame.origin.x + x, y: windowFrame.origin.y + y)
            
        case .screen(let displayId):
            let bounds = CGDisplayBounds(displayId)
            
            // Screen coordinates: origin at bottom-left, Y increases upward
            // Convert to global: flip Y coordinate
            let globalY = bounds.origin.y + bounds.height - y
            return CGPoint(x: bounds.origin.x + x, y: globalY)
            
        case .global:
            // Already in global coordinates
            return CGPoint(x: x, y: y)
        }
    }
    
    public func fromGlobal(
        point: CGPoint, 
        to space: CoordinateSpace, 
        window: AXUIElement? = nil
    ) async throws -> CGPoint {
        
        switch space {
        case .window:
            guard let window = window else {
                throw MCPError.invalidParameters("Window handle required")
            }
            
            let windowFrame = try getWindowFrame(from: window)
            return CGPoint(x: point.x - windowFrame.origin.x, y: point.y - windowFrame.origin.y)
            
        case .screen(let displayId):
            let bounds = CGDisplayBounds(displayId)
            let screenY = bounds.height - (point.y - bounds.origin.y)
            return CGPoint(x: point.x - bounds.origin.x, y: screenY)
            
        case .global:
            return point
        }
    }
    
    public func getWindowFrame(from window: AXUIElement) throws -> CGRect {
        // Get window position
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        
        guard positionResult == .success, let position = positionValue as! AXValue? else {
            throw MCPError.resourceUnavailable("Cannot get window position")
        }
        
        var windowOrigin = CGPoint.zero
        guard AXValueGetValue(position, .cgPoint, &windowOrigin) else {
            throw MCPError.resourceUnavailable("Cannot extract window position")
        }
        
        // Get window size
        var sizeValue: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
        
        guard sizeResult == .success, let size = sizeValue as! AXValue? else {
            throw MCPError.resourceUnavailable("Cannot get window size")
        }
        
        var windowSize = CGSize.zero
        guard AXValueGetValue(size, .cgSize, &windowSize) else {
            throw MCPError.resourceUnavailable("Cannot extract window size")
        }
        
        return CGRect(origin: windowOrigin, size: windowSize)
    }
    
    public func getDisplayBounds(for displayId: CGDirectDisplayID) -> CGRect {
        return CGDisplayBounds(displayId)
    }
    
    public func getMainDisplayId() -> CGDirectDisplayID {
        return CGMainDisplayID()
    }
    
    public func getAllDisplayIds() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        
        // Get display count
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success else {
            return [CGMainDisplayID()]
        }
        
        // Get display list
        var displayIds = Array<CGDirectDisplayID>(repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displayIds, &displayCount) == .success else {
            return [CGMainDisplayID()]
        }
        
        return displayIds
    }
    
    public func findDisplayContaining(point: CGPoint) -> CGDirectDisplayID? {
        let displayIds = getAllDisplayIds()
        
        for displayId in displayIds {
            let bounds = CGDisplayBounds(displayId)
            if bounds.contains(point) {
                return displayId
            }
        }
        
        return nil
    }
}
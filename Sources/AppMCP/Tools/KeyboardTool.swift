import Foundation
import MCP
@preconcurrency import ApplicationServices
import AppKit

/// Tool executor that performs keyboard input operations in specified applications
public final class KeyboardTool: MCPToolExecutor, @unchecked Sendable {
    
    public let name = "type_text"
    private let appSelector: AppSelector
    private let tccManager: TCCManager
    
    public init(appSelector: AppSelector, tccManager: TCCManager) {
        self.appSelector = appSelector
        self.tccManager = tccManager
    }
    
    public func handle(params: MCP.Value) async throws -> MCP.Value {
        // Ensure accessibility permission
        try await tccManager.ensureAccessibilityPermission()
        
        // Parse parameters from Value
        guard case let .object(paramsDict) = params else {
            throw MCPError.invalidParameters("Parameters must be an object")
        }
        
        guard case let .string(text) = paramsDict["text"] else {
            throw MCPError.invalidParameters("Missing text parameter")
        }
        
        // If target app is specified, bring it to front first
        if case let .object(targetApp) = paramsDict["target_app"] {
            try await bringAppToFront(targetApp: targetApp)
        }
        
        // Type the text
        try typeText(text)
        
        return .object([
            "success": .bool(true),
            "action": .string("type_text"),
            "text": .string(text),
            "character_count": .int(text.count)
        ])
    }
    
    private func bringAppToFront(targetApp: [String: MCP.Value]) async throws {
        if case let .string(bundleId) = targetApp["bundle_id"] {
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.bundleIdentifier == bundleId }) {
                app.activate()
                // Wait a bit for the app to come to front
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        } else if case let .string(processName) = targetApp["process_name"] {
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.localizedName == processName }) {
                app.activate()
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    private func typeText(_ text: String) throws {
        // Create a keyboard event source
        let eventSource = CGEventSource(stateID: .hidSystemState)
        
        for character in text {
            // Handle special characters
            if character == "\n" {
                // Handle return key
                try sendKeyPress(keyCode: 36, eventSource: eventSource) // Return key
            } else if character == "\t" {
                // Handle tab key
                try sendKeyPress(keyCode: 48, eventSource: eventSource) // Tab key
            } else if character == " " {
                // Handle space key
                try sendKeyPress(keyCode: 49, eventSource: eventSource) // Space key
            } else {
                // Handle regular characters using Unicode
                try sendUnicodeCharacter(character, eventSource: eventSource)
            }
            
            // Small delay between characters to simulate natural typing
            usleep(50_000) // 0.05 seconds
        }
    }
    
    private func sendKeyPress(keyCode: CGKeyCode, eventSource: CGEventSource?) throws {
        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true) else {
            throw MCPError.systemError("Failed to create key down event")
        }
        
        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false) else {
            throw MCPError.systemError("Failed to create key up event")
        }
        
        // Post the events
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    private func sendUnicodeCharacter(_ character: Character, eventSource: CGEventSource?) throws {
        let string = String(character)
        let utf16 = Array(string.utf16)
        
        for unicodeValue in utf16 {
            // Create keyboard event with Unicode
            guard let keyEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true) else {
                throw MCPError.systemError("Failed to create Unicode key event")
            }
            
            // Set the Unicode string
            keyEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unicodeValue])
            
            // Post the event
            keyEvent.post(tap: .cghidEventTap)
        }
    }
}

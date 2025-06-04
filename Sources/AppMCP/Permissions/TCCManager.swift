import Foundation
@preconcurrency import ApplicationServices
import AppKit

/// Actor responsible for managing TCC (Transparency, Consent, and Control) permissions
public actor TCCManager {
    
    // MARK: - Permission Status
    
    public enum PermissionStatus: Sendable {
        case granted
        case denied
        case notDetermined
    }
    
    // MARK: - Permission Checking
    
    /// Check if accessibility permissions are granted
    public func checkAccessibilityPermission() async -> PermissionStatus {
        // Use the simpler AXIsProcessTrusted() function first
        let trusted = AXIsProcessTrusted()
        print("🔍 AXIsProcessTrusted result: \(trusted)")
        
        return trusted ? .granted : .denied
    }
    
    /// Check if screen recording permissions are granted
    public func checkScreenRecordingPermission() async -> PermissionStatus {
        // Use the preflight API for permission checking
        let preflightResult = CGPreflightScreenCaptureAccess()
        print("🔍 CGPreflightScreenCaptureAccess result: \(preflightResult)")
        
        // If not granted, try requesting access
        if !preflightResult {
            print("🔍 Requesting screen capture access...")
            let requestResult = CGRequestScreenCaptureAccess()
            print("🔍 CGRequestScreenCaptureAccess result: \(requestResult)")
            return requestResult ? .granted : .denied
        }
        
        return .granted
    }
    
    /// Request accessibility permission with user prompt
    public func requestAccessibilityPermission() async -> PermissionStatus {
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary)
        
        return trusted ? .granted : .denied
    }
    
    /// Request screen recording permission
    public func requestScreenRecordingPermission() async -> PermissionStatus {
        // This will trigger the system permission dialog
        let hasPermission = CGRequestScreenCaptureAccess()
        return hasPermission ? .granted : .denied
    }
    
    // MARK: - Permission Validation
    
    /// Ensure accessibility permission is granted, throw error if not
    public func ensureAccessibilityPermission() async throws {
        let status = await checkAccessibilityPermission()
        guard status == .granted else {
            throw MCPError.permissionDenied(
                "Accessibility permission is required. Please grant permission in System Preferences > Privacy & Security > Accessibility"
            )
        }
    }
    
    /// Ensure screen recording permission is granted, throw error if not
    public func ensureScreenRecordingPermission() async throws {
        let status = await checkScreenRecordingPermission()
        guard status == .granted else {
            throw MCPError.permissionDenied(
                "Screen Recording permission is required. Please grant permission in System Preferences > Privacy & Security > Screen Recording"
            )
        }
    }
    
    /// Ensure both accessibility and screen recording permissions are granted
    public func ensureAllPermissions() async throws {
        try await ensureAccessibilityPermission()
        try await ensureScreenRecordingPermission()
    }
    
    // MARK: - User Guidance
    
    /// Open System Preferences to the Privacy & Security section
    @MainActor
    public func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
        NSWorkspace.shared.open(url)
    }
    
    /// Show an alert dialog explaining permission requirements
    @MainActor
    public func showPermissionAlert(for permissionType: String) {
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText = """
        AppMCP requires \(permissionType) permission to function properly.
        
        Please:
        1. Click "Open System Preferences" below
        2. Navigate to Privacy & Security > \(permissionType)
        3. Add this application to the allowed list
        4. Restart the application
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openPrivacySettings()
        }
    }
    
    /// Get a comprehensive status of all required permissions
    public func getPermissionStatus() async -> [String: PermissionStatus] {
        let accessibilityStatus = await checkAccessibilityPermission()
        let screenRecordingStatus = await checkScreenRecordingPermission()
        
        return [
            "accessibility": accessibilityStatus,
            "screenRecording": screenRecordingStatus
        ]
    }
}

// MARK: - Permission Status Extensions

extension TCCManager.PermissionStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        }
    }
}

extension TCCManager.PermissionStatus: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        switch string {
        case "granted":
            self = .granted
        case "denied":
            self = .denied
        case "notDetermined":
            self = .notDetermined
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid permission status")
            )
        }
    }
}

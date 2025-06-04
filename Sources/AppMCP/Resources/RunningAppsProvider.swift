import Foundation
import MCP
import AppKit

/// Resource provider that lists all running applications with their Bundle IDs
public final class RunningAppsProvider: MCPResourceProvider, @unchecked Sendable {
    
    public let name = "running_applications"
    private let appSelector: AppSelector
    
    public init(appSelector: AppSelector) {
        self.appSelector = appSelector
    }
    
    public func handle(params: MCP.Value) async throws -> MCP.Value {
        // Get list of running applications
        let apps = await appSelector.listRunningApps()
        
        // Convert to MCP.Value structure
        let appsData = apps.map { app in
            MCP.Value.object([
                "bundle_id": app.bundleId.map { .string($0) } ?? .null,
                "name": .string(app.name),
                "pid": .int(Int(app.pid)),
                "is_active": .bool(app.isActive)
            ])
        }
        
        return .object([
            "applications": .array(appsData)
        ])
    }
}

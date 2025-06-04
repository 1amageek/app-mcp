import Foundation
import AppMCP
import ArgumentParser

@main
struct AppMCPDaemon: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appmcpd",
        abstract: "AppMCP Server Daemon - Model Context Protocol server for macOS GUI automation",
        version: "0.1.0"
    )
    
    @Flag(name: .long, help: "Use STDIO transport (default)")
    var stdio: Bool = false
    
    @Option(name: .long, help: "Use HTTP transport on specified port")
    var http: Int?
    
    @Option(name: .long, help: "Log level (debug, info, warning, error)")
    var logLevel: String = "info"
    
    @Flag(name: .long, help: "Validate configuration and exit")
    var validate: Bool = false
    
    @Flag(name: .long, help: "Show available resources and tools")
    var listCapabilities: Bool = false
    
    func run() async throws {
        // Print banner
        printBanner()
        
        // Create server
        let server = MCPServer.weatherAppPoC()
        
        // Handle special commands
        if validate {
            try await server.validateConfiguration()
            return
        }
        
        if listCapabilities {
            printCapabilities(server: server)
            return
        }
        
        // Determine transport
        if http != nil {
            print("❌ HTTP transport not yet implemented")
            throw ExitCode.failure
        } else {
            print("📡 Starting AppMCP server with STDIO transport")
        }
        
        // Set up signal handling for graceful shutdown
        setupSignalHandling()
        
        do {
            // Start the server
            try await server.start()
        } catch {
            print("❌ Failed to start server: \(error)")
            throw ExitCode.failure
        }
    }
    
    private func printBanner() {
        print("""
        ╭─────────────────────────────────────────────────────────────╮
        │                         AppMCP v0.1.0                      │
        │              macOS GUI Automation via MCP Protocol         │
        │                                                             │
        │  🎯 Weather App PoC: AI-driven weather forecast retrieval  │
        ╰─────────────────────────────────────────────────────────────╯
        """)
    }
    
    private func printCapabilities(server: MCPServer) {
        print("📋 Available Resources:")
        let resources = server.getResourceInfo()
        for (name, type) in resources.sorted(by: { $0.key < $1.key }) {
            print("   • \(name) (\(type))")
        }
        
        print("\n🔧 Available Tools:")
        let tools = server.getToolInfo()
        for (name, type) in tools.sorted(by: { $0.key < $1.key }) {
            print("   • \(name) (\(type))")
        }
        
        print("\n💡 Weather App PoC Workflow:")
        print("   1. List running apps: running_applications")
        print("   2. Target Weather app: bundle_id=com.apple.weather")
        print("   3. Capture state: app_screenshot")
        print("   4. Analyze UI: app_accessibility_tree")
        print("   5. Click search field: mouse_click")
        print("   6. Type location: type_text")
        print("   7. Wait for results: wait")
        print("   8. Select result: mouse_click")
        print("   9. Extract weather data: app_accessibility_tree")
    }
    
    private func setupSignalHandling() {
        // Set up signal handling for graceful shutdown
        signal(SIGINT) { _ in
            print("\n🛑 Received SIGINT, shutting down gracefully...")
            Foundation.exit(0)
        }
        
        signal(SIGTERM) { _ in
            print("\n🛑 Received SIGTERM, shutting down gracefully...")
            Foundation.exit(0)
        }
    }
    
    // MARK: - Helper Functions
    
    private func printUsageExamples() {
        print("""
        
        📖 Usage Examples:
        
        # Start with STDIO transport (default)
        appmcpd
        
        # Start with HTTP transport
        appmcpd --http 8080
        
        # Validate configuration
        appmcpd --validate
        
        # List available capabilities
        appmcpd --list-capabilities
        
        # Start with debug logging
        appmcpd --log-level debug
        
        """)
    }
}

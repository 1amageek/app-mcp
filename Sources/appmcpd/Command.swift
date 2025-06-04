import Foundation
import AppMCP
import ArgumentParser
import AppKit
import MCP

@main
struct AppMCPDaemon: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appmcpd",
        abstract: "AppMCP Server Daemon - Model Context Protocol server for macOS GUI automation",
        version: "0.2.0"
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
        
        // Initialize GUI environment to prevent CGS errors
        await initializeGUIEnvironment()
        
        // Create server
        let server = AppMCPServer()
        
        // Handle special commands
        if validate {
            print("✅ Configuration validation not yet implemented in v0.2")
            return
        }
        
        if listCapabilities {
            printCapabilities()
            return
        }
        
        // Determine transport
        let transport: Transport
        if let httpPort = http {
            print("❌ HTTP transport not yet implemented in v0.2")
            print("   Coming in future version with authentication support")
            throw ExitCode.failure
        } else {
            print("📡 Starting AppMCP server with STDIO transport")
            transport = StdioTransport()
        }
        
        // Set up signal handling for graceful shutdown
        setupSignalHandling()
        
        do {
            // Start the server
            try await server.start(transport: transport)
        } catch {
            print("❌ Failed to start server: \(error)")
            throw ExitCode.failure
        }
    }
    
    private func printBanner() {
        print("""
        ╭─────────────────────────────────────────────────────────────╮
        │                         AppMCP v0.2.0                      │
        │         Multi-App/Multi-Window macOS GUI Automation        │
        │                    via MCP Protocol                        │
        │                                                             │
        │  🎯 Advanced UI automation with handle-based management    │
        ╰─────────────────────────────────────────────────────────────╯
        """)
    }
    
    private func printCapabilities() {
        print("📋 Available Resources:")
        print("   • installed_applications - List all installed .app bundles")
        print("   • running_applications - List currently running applications")
        print("   • accessible_applications - Apps with accessibility permissions + windows")
        print("   • list_windows - List windows for specific app handle")
        
        print("\n🔧 Available Tools:")
        print("   • resolve_app - Get app_handle from bundle_id/name/pid")
        print("   • resolve_window - Get window_handle from app_handle + title/index")
        print("   • mouse_click - Click at coordinates (window/screen/global)")
        print("   • type_text - Type text into focused element")
        print("   • perform_gesture - Swipe/pinch/rotate gestures")
        print("   • wait - Wait for time/UI change/window appear/disappear")
        
        print("\n💡 Typical Automation Workflow:")
        print("   1. List apps: accessible_applications")
        print("   2. Get app handle: resolve_app{bundle_id: 'com.apple.weather'}")
        print("   3. Get window handle: resolve_window{app_handle: 'ah_1234', title_regex: '.*'}")
        print("   4. Click UI element: mouse_click{window_handle: 'wh_5678', x: 100, y: 200}")
        print("   5. Type search query: type_text{window_handle: 'wh_5678', text: 'Tokyo'}")
        print("   6. Wait for results: wait{condition: 'ui_change', duration_ms: 3000}")
        print("   7. Extract data: list_windows{app_handle: 'ah_1234'}")
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
    
    /// Initialize GUI environment to prevent CGS initialization errors
    private func initializeGUIEnvironment() async {
        // Force NSApplication initialization to set up the GUI environment
        DispatchQueue.main.async {
            _ = NSApplication.shared
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        
        // Give the GUI environment time to initialize
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        print("🔧 GUI environment initialized for ScreenCaptureKit compatibility")
    }
}

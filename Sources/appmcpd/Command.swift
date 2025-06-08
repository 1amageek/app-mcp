import Foundation
import AppMCP
import ArgumentParser

@main
struct AppMCPDaemon: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appmcpd",
        abstract: "AppMCP Server - Modern macOS UI Automation via MCP",
        version: AppMCP.version
    )
    
    @Option(name: .long, help: "Use HTTP transport on specified port")
    var http: Int?
    
    @Flag(name: .long, help: "Enable verbose output")
    var verbose: Bool = false
    
    @Flag(name: .long, help: "Weather app automation mode")
    var weather: Bool = false
    
    @Flag(name: .long, help: "Show available capabilities")
    var listCapabilities: Bool = false
    
    func run() async throws {
        // Print banner
        if verbose || listCapabilities {
            printBanner()
        }
        
        // Handle special commands
        if listCapabilities {
            printCapabilities()
            return
        }
        
        // Create server
        let server: AppMCPServer
        if weather {
            if verbose {
                print("🌤️  Weather App Mode")
            }
            server = AppMCPServer.forWeatherApp()
        } else {
            server = AppMCPServer()
        }
        
        // Check for HTTP transport
        if let httpPort = http {
            print("❌ HTTP transport not yet implemented")
            print("   HTTP port \(httpPort) specified, but only STDIO is supported")
            print("   Use STDIO transport for now (remove --http flag)")
            throw ExitCode.failure
        }
        
        // Set up signal handling
        setupSignalHandling()
        
        do {
            // Start the server (this will run indefinitely)
            try await server.start()
            
        } catch {
            print("❌ Failed to start server: \(error)")
            throw ExitCode.failure
        }
    }
    
    private func printBanner() {
        print("""
        ╭─────────────────────────────────────────────────────────────╮
        │                    AppMCP \(AppMCP.version)                        │
        │           Modern macOS UI Automation via MCP               │
        │                                                             │
        │  🎯 Element-based automation powered by AppPilot           │
        │  🚀 MCP Protocol \(AppMCP.mcpVersion) support                      │
        ╰─────────────────────────────────────────────────────────────╯
        """)
    }
    
    private func printCapabilities() {
        print("📋 Available Resources:")
        print("   • running_applications - List all running applications with metadata")
        print("   • application_windows - All application windows with bounds and visibility")
        
        print("\n🔧 Available Tools:")
        print("   • automation - Essential automation actions for macOS applications")
        print("     - click: Click UI elements or coordinates")
        print("     - type: Type text into elements or focused field")
        print("     - drag: Drag from one point to another")
        print("     - scroll: Scroll in specified direction and amount")
        print("     - wait: Wait for specified duration")
        print("     - find: Find and describe UI elements")
        print("     - screenshot: Capture window screenshots")
        
        print("\n💡 Example Usage:")
        print("   automation{action: 'click', appName: 'Calculator', element: {title: 'Clear'}}")
        print("   automation{action: 'type', bundleID: 'com.apple.TextEdit', text: 'Hello World'}")
        print("   automation{action: 'drag', appName: 'Finder', startPoint: {x: 100, y: 100}, endPoint: {x: 200, y: 200}}")
        print("   automation{action: 'scroll', appName: 'Safari', deltaY: -100}")
        print("   automation{action: 'screenshot', bundleID: 'com.apple.weather'}")
    }
    
    private func setupSignalHandling() {
        signal(SIGINT) { _ in
            print("\n🛑 Shutting down gracefully...")
            Foundation.exit(0)
        }
        
        signal(SIGTERM) { _ in
            print("\n🛑 Shutting down gracefully...")
            Foundation.exit(0)
        }
    }
}

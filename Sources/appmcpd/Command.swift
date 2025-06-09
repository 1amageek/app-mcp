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
        print("   • click_element - Click on UI elements or coordinates")
        print("     Parameters: bundleID, element (type, text, etc.), coordinates, button, clickCount")
        print("   • input_text - Input text into text fields or focused elements")
        print("     Parameters: bundleID, text, element, method (type/setValue), clearFirst")
        print("   • drag_drop - Perform drag and drop operations")
        print("     Parameters: bundleID, from, to, duration")
        print("   • scroll_window - Scroll within a window")
        print("     Parameters: bundleID, deltaX, deltaY, position")
        print("   • find_elements - Find and list UI elements in a window")
        print("     Parameters: bundleID, type, text, containing, label, limit")
        print("   • capture_screenshot - Capture a screenshot of a window")
        print("     Parameters: bundleID, format (png/jpeg)")
        print("   • wait_time - Wait for a specified duration")
        print("     Parameters: duration (seconds)")
        print("   • list_running_applications - Get list of currently running applications")
        print("     Parameters: none")
        print("   • list_application_windows - Get list of all application windows")
        print("     Parameters: none")
        
        print("\n💡 Example Usage:")
        print("   click_element{bundleID: 'com.apple.calculator', element: {type: 'button', text: 'Clear'}}")
        print("   input_text{bundleID: 'com.apple.TextEdit', text: 'Hello World', method: 'type'}")
        print("   drag_drop{bundleID: 'com.apple.finder', from: {x: 100, y: 100}, to: {x: 200, y: 200}}")
        print("   scroll_window{bundleID: 'com.apple.safari', deltaY: -100}")
        print("   capture_screenshot{bundleID: 'com.apple.weather'}")
        print("   find_elements{bundleID: 'com.apple.weather', type: 'button', limit: 5}")
        print("   list_running_applications{}")
        print("   list_application_windows{}")
        
        print("\n🎯 Element Types (User-Friendly):")
        print("   • button, textfield, text, image, menu, list, table, checkbox, radio, slider")
        print("   No accessibility knowledge required - use intuitive element types!")
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

# ``AppMCP``

A Swift framework for macOS GUI automation using the Model Context Protocol (MCP).

## Overview

AppMCP is a comprehensive Swift package that implements the Model Context Protocol (MCP) SDK v0.7.1 for macOS application automation. It enables AI models to visually inspect, interpret, and control macOS applications through a standardized protocol interface.

The framework provides a bridge between AI models and macOS applications, allowing for sophisticated automation workflows that can:
- Capture screenshots and accessibility trees from running applications
- Perform mouse clicks and keyboard input with pixel-perfect precision
- Discover and interact with applications by Bundle ID, process name, or PID
- Handle macOS permissions and security requirements automatically

## Key Features

### Resource Providers
- **Screenshot Capture**: High-quality PNG screenshots of application windows
- **Accessibility Trees**: Structured JSON representation of UI elements
- **Application Discovery**: Enumerate running applications with detailed metadata

### Tool Executors
- **Mouse Automation**: Precise click operations with support for different buttons
- **Keyboard Input**: Text typing and keyboard shortcuts
- **Wait Operations**: Configurable delays and condition-based waiting

### Permission Management
- **TCC Integration**: Automatic handling of Transparency, Consent, and Control permissions
- **Accessibility Support**: Seamless integration with macOS accessibility APIs
- **Screen Recording**: Managed screen capture permissions

## Architecture

AppMCP follows a protocol-based architecture that separates concerns between resource providers and tool executors:

```swift
// Resource providers handle data extraction
public protocol MCPResourceProvider: Sendable {
    var name: String { get }
    func handle(params: MCP.Value) async throws -> MCP.Value
}

// Tool executors handle actions and automation
public protocol MCPToolExecutor: Sendable {
    var name: String { get }
    func handle(params: MCP.Value) async throws -> MCP.Value
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>
- <doc:WeatherAppTutorial>

### Core Components

- ``MCPServer``
- ``AppSelector``
- ``MCPResourceProvider``
- ``MCPToolExecutor``

### Resource Providers

- ``RunningAppsProvider``
- ``AppScreenshotProvider``
- ``AppAXTreeProvider``

### Tool Executors

- ``MouseClickTool``
- ``KeyboardTool``
- ``WaitTool``

### Permission Management

- ``TCCManager``

### Error Handling

- ``MCPError``

## Requirements

- macOS 15.0 or later
- Swift 6.1 or later
- Xcode 16.0 or later

## Model Context Protocol

AppMCP implements the Model Context Protocol (MCP), a standardized way for AI models to interact with external systems. MCP provides:

- **Standardized Communication**: JSON-RPC based protocol for reliable message exchange
- **Resource Discovery**: Dynamic enumeration of available data sources
- **Tool Execution**: Structured way to perform actions in external systems
- **Transport Agnostic**: Support for STDIO, HTTP, and other transport mechanisms

## Use Cases

- **AI-Driven Testing**: Automated testing of macOS applications using AI vision
- **Workflow Automation**: Complex multi-step automation guided by AI understanding
- **Application Integration**: Bridge between AI models and existing macOS software
- **Accessibility Enhancement**: AI-powered assistance for users with disabilities
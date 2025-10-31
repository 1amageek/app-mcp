# ``AppMCP``

A Swift framework for macOS GUI automation using the Model Context Protocol (MCP).

## Overview

AppMCP is a comprehensive Swift package that implements the Model Context Protocol (MCP) SDK v0.7.1 for macOS application automation. It enables AI models to visually inspect, interpret, and control macOS applications through a standardized protocol interface.

The framework provides a bridge between AI models and macOS applications, allowing for sophisticated automation workflows:

### Resources (Read-Only Data)
- Query running applications and their windows
- Capture UI snapshots with screenshots and element IDs
- Extract element hierarchies for programmatic access

### Tools (State-Mutating Actions)
- Click, input text, drag & drop using element IDs
- Execute keyboard shortcuts and sequences
- Time-based wait operations

### AppPilot Integration
- Core macOS UI automation powered by AppPilot framework
- Accessibility API integration for element discovery
- CGEvent-based mouse and keyboard control

## Key Features

### MCP Resources (4 Data Sources)
- **`running_applications`**: List all running apps with Bundle ID, PID, status
- **`application_windows`**: Query windows with titles, bounds, visibility
- **`ui_snapshot`**: Capture screenshot + element hierarchy with unique IDs
- **`ui_elements`**: Fast element hierarchy extraction without screenshot

### MCP Tools (6 Automation Actions)
- **`click_element`**: Element-based clicking with multi-button support
- **`input_text`**: Text input with type or setValue methods
- **`drag_drop`**: Drag and drop operations between elements
- **`scroll_window`**: Scrolling at specific element locations
- **`keyboard_input`**: Keyboard shortcuts and key sequences
- **`wait_time`**: Time-based waiting (up to 60 seconds)

### Permission Management
- **Accessibility**: Required for UI element discovery and interaction
- **Screen Recording**: Required for screenshot capture
- **Automatic Prompts**: System prompts guide users through permission setup

## Architecture

AppMCP follows a layered architecture with clear separation between MCP protocol handling and automation:

```
┌─────────────────────────────────┐
│      MCP Client (AI Model)      │
└─────────────┬───────────────────┘
              │ JSON-RPC
┌─────────────▼───────────────────┐
│        AppMCPServer             │
│  ┌──────────┐   ┌──────────┐   │
│  │Resources │   │  Tools   │   │
│  └──────────┘   └──────────┘   │
└─────────────┬───────────────────┘
              │
┌─────────────▼───────────────────┐
│          AppPilot               │
│  (macOS Automation Framework)   │
└─────────────────────────────────┘
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>
- <doc:WeatherAppTutorial>

### Core Components

- ``AppMCPServer``: Main MCP server implementing Resources and Tools

## Requirements

- macOS 15.0 or later
- Swift 6.1 or later
- Xcode 16.0 or later
- AppPilot framework for core automation

## Model Context Protocol

AppMCP implements the Model Context Protocol (MCP) v0.7.1, a standardized way for AI models to interact with external systems:

### Resources (Read-Only)
Resources provide read-only access to system state via URIs:
- `appmcp://resources/running_applications` - List all running apps
- `appmcp://resources/application_windows` - List all windows
- `appmcp://ui/snapshot/{bundleID}` - Capture UI with screenshot + element IDs
- `appmcp://ui/elements/{bundleID}` - Get element hierarchy (no screenshot)

### Tools (State-Mutating)
Tools perform actions that modify system state:
- `click_element` - Click UI elements by ID
- `input_text` - Input text into elements
- `drag_drop` - Drag between elements
- `scroll_window` - Scroll at element location
- `keyboard_input` - Execute keyboard shortcuts
- `wait_time` - Wait for specified duration

### Design Principles
- **Fail-Fast Philosophy**: Explicit error propagation, no silent failures
- **ElementID Workflow**: Capture once via Resources, operate multiple times via Tools
- **Type-Safe Parameters**: Validated inputs with clear error messages
- **Async/Await**: Full Swift concurrency support throughout

## Use Cases

- **AI-Driven Testing**: Automated testing of macOS applications using AI vision
- **Workflow Automation**: Complex multi-step automation guided by AI understanding
- **Application Integration**: Bridge between AI models and existing macOS software
- **UI Automation**: Element-based interaction with native macOS applications
# AppMCP Project Brief

## Project Overview
**AppMCP** is a Swift Package that implements a Model Context Protocol (MCP) server enabling AI systems to visually perceive, interpret, and control macOS applications through a standardized interface.

## Core Mission
Create a pipeline where AI can:
1. **Perceive** → Take screenshots and read accessibility trees
2. **Interpret** → Understand UI structure and context  
3. **Control** → Execute mouse clicks, keyboard input, and other interactions

## Deliverables
- **Swift Package Library**: `AppMCP` - Core functionality as reusable library
- **CLI Binary**: `appmcpd` - Server daemon for MCP clients
- **Public Distribution**: Available via SwiftPM for integration into other projects

## Success Criteria
1. ✅ **Test Suite Green** - All unit, integration, and UI tests passing
2. ✅ **LLM Integration** - Successful Resource/Tool calls from local LLM clients
3. ✅ **Documentation Complete** - README, API docs, and demo video ready

## Technical Foundation
- **Platform**: macOS 15+ (Sonoma and later)
- **Architecture**: Apple Silicon + Intel support
- **Primary Dependency**: `modelcontextprotocol/swift-sdk` ≥ 0.9.0
- **Language**: Swift 6.1+

## Target Users
- AI/LLM developers building macOS automation
- Researchers working on AI-computer interaction
- Developers creating accessibility tools
- Teams building AI assistants with GUI control

## Project Scope
**In Scope v0.1.0:**
- Screenshot capture resource
- Accessibility tree resource
- Mouse control tools (move, click)
- Keyboard input tools
- Permission management (TCC)
- STDIO transport
- Basic logging

**Future Versions:**
- HTTP transport (v0.2.0)
- DevTools integration (v0.2.0)
- Shortcuts bridge (v0.3.0)
- Plugin SDK (v1.0.0)

## Key Constraints
- macOS-only (no cross-platform support planned)
- Requires system permissions (Accessibility, Screen Recording)
- Swift 6.1+ for modern concurrency
- MCP protocol compliance mandatory

## Business Value
- Enables AI automation of macOS applications
- Standardized interface for GUI control
- Reusable library for broader ecosystem
- Foundation for advanced AI-computer interaction research

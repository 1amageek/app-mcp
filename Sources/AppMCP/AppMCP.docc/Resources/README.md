# Building AppMCP Documentation

This directory contains the DocC documentation catalog for AppMCP. The documentation is built using Swift-DocC and includes comprehensive API reference, tutorials, and architectural overviews.

## Building Documentation

### Prerequisites

- Xcode 16.0 or later
- Swift 6.1 or later
- Swift-DocC plugin (included in Package.swift)

### Build Commands

#### Local Preview

Generate and preview documentation locally:

```bash
# Build and preview documentation
swift package generate-documentation --target AppMCP

# Preview with custom hosting port
swift package preview-documentation --target AppMCP --port 8080
```

#### Generate Static Documentation

Create static HTML documentation for hosting:

```bash
# Generate static documentation
swift package generate-documentation \
    --target AppMCP \
    --output-path ./docs \
    --hosting-base-path /AppMCP
```

#### Archive for Distribution

Create a documentation archive:

```bash
# Generate documentation archive
swift package generate-documentation \
    --target AppMCP \
    --output-path ./AppMCP.doccarchive
```

## Documentation Structure

```
AppMCP.docc/
├── AppMCP.md              # Main documentation page
├── GettingStarted.md      # Installation and setup guide
├── Architecture.md        # Technical architecture overview
├── WeatherAppTutorial.md  # Complete automation tutorial
└── Resources/
    └── README.md          # This file
```

## Content Overview

### Main Page (AppMCP.md)
- Framework overview and key features
- Architecture summary
- Requirements and setup
- Navigation to detailed sections

### Getting Started Guide
- Installation instructions for SPM and Xcode
- Permission setup and troubleshooting
- Basic usage examples
- Command-line usage

### Architecture Documentation
- Component design and patterns
- MCP protocol integration
- Performance considerations
- Extensibility guidelines

### Weather App Tutorial
- Complete end-to-end automation example
- MCP client interaction patterns
- Error handling and debugging
- Advanced automation techniques

## API Documentation

API documentation is automatically generated from inline documentation comments in the source code. Key documented components include:

### Core Protocols
- `MCPResourceProvider` - Interface for data extraction components
- `MCPToolExecutor` - Interface for automation action components

### Main Classes
- `MCPServer` - Central MCP protocol coordinator
- `AppSelector` - Thread-safe application discovery actor
- `TCCManager` - macOS permission management

### Resource Providers
- `RunningAppsProvider` - Application discovery and enumeration
- `AppScreenshotProvider` - Application screenshot capture
- `AppAXTreeProvider` - Accessibility tree extraction

### Tool Executors
- `MouseClickTool` - Mouse automation and clicking
- `KeyboardTool` - Text input and keyboard shortcuts
- `WaitTool` - Delays and condition-based waiting

### Data Types
- `AppInfo` - Application metadata structure
- `MCPError` - Standardized error types

## Documentation Standards

### Inline Documentation
All public APIs include comprehensive documentation with:
- Purpose and functionality descriptions
- Parameter documentation with types and purposes
- Return value descriptions
- Error conditions and types
- Usage examples where appropriate
- Cross-references to related APIs

### Code Examples
Documentation includes working code examples that:
- Demonstrate real-world usage patterns
- Show error handling best practices
- Illustrate common automation workflows
- Provide copy-paste ready code snippets

### Cross-References
Documentation uses DocC linking syntax to connect related concepts:
- ``TypeName`` for type references
- ``methodName(parameter:)`` for method references
- `<doc:ArticleName>` for article cross-references

## Updating Documentation

### Adding New APIs
When adding new public APIs:
1. Add comprehensive inline documentation
2. Include usage examples
3. Document error conditions
4. Add cross-references to related components
5. Update relevant tutorial sections if applicable

### Modifying Tutorials
When updating tutorials:
1. Verify all code examples compile and run
2. Update screenshots if UI changes
3. Test automation workflows end-to-end
4. Update error handling sections as needed

### Architecture Changes
When modifying the architecture:
1. Update the Architecture.md document
2. Revise component diagrams if needed
3. Update cross-references between components
4. Ensure Getting Started guide reflects changes

## Publishing Documentation

### GitHub Pages
To publish to GitHub Pages:

```bash
# Generate static documentation
swift package generate-documentation \
    --target AppMCP \
    --output-path ./docs \
    --hosting-base-path /AppMCP

# Commit and push to gh-pages branch
git add docs/
git commit -m "Update documentation"
git push origin gh-pages
```

### Documentation Hosting Services
The generated static documentation can be hosted on:
- GitHub Pages
- Netlify
- Vercel
- AWS S3 + CloudFront
- Any static web hosting service

## Troubleshooting

### Common Build Issues

**Missing Dependencies**
```bash
swift package resolve
swift package update
```

**DocC Plugin Issues**
Ensure Package.swift includes the DocC plugin dependency:
```swift
.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
```

**Memory Issues on Large Projects**
For large documentation builds:
```bash
swift package generate-documentation --target AppMCP --verbose
```

### Documentation Quality

**Link Validation**
Verify all internal links work:
```bash
swift package generate-documentation --target AppMCP --warnings-as-errors
```

**Accessibility Check**
Ensure documentation is accessible:
- Use semantic HTML in custom content
- Provide alt text for images
- Maintain proper heading hierarchy

## Contributing

When contributing to documentation:
1. Follow Apple's DocC documentation style guidelines
2. Include working code examples
3. Test all links and cross-references
4. Verify examples compile and run correctly
5. Update this README if adding new documentation sections
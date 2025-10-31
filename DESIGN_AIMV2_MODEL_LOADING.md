# AIMv2 Model Loading Strategy - Design Document

**Status**: Draft
**Date**: 2025-01-30
**Author**: System Design

## Executive Summary

This document outlines the design strategy for loading the AIMv2 vision model in AppMCP. The AIMv2 model is a large machine learning model (~300MB+) that requires careful consideration of loading timing, error handling, and user experience.

## Current Implementation Analysis

### Status Quo

```swift
// Current implementation in MCPServer.swift
private var semanticAnalyzer: SemanticElementAnalyzer?

// In performFindSimilarElements() and performGroupElementsVisually()
if semanticAnalyzer == nil {
    semanticAnalyzer = SemanticElementAnalyzer()
    try semanticAnalyzer!.loadModel()  // Lazy loading on first use
}
```

### Problems with Current Approach

1. **Delayed Error Discovery**
   - Model loading errors only surface when tools are first invoked
   - User doesn't know if vision features are available until runtime
   - Poor error messages: generic loading failures without context

2. **Unpredictable First-Use Latency**
   - First vision tool call takes 2-5 seconds (model loading time)
   - Subsequent calls are fast (~50-100ms)
   - User experience is inconsistent

3. **Unclear Requirements**
   - No documentation about required model files
   - No guidance on where to place model files
   - No validation of model path before attempting load

4. **Error Handling Issues**
   - Force unwrapping (`semanticAnalyzer!`) is unsafe
   - Errors propagate as generic tool failures
   - No differentiation between "model not found" vs "model corrupt"

## Requirements

### Functional Requirements

1. **FR1**: Support both model-present and model-absent scenarios
2. **FR2**: Provide clear feedback about model availability
3. **FR3**: Load model efficiently (minimize startup impact)
4. **FR4**: Handle errors gracefully with actionable messages
5. **FR5**: Support multiple model sources (env var, default path, custom path)

### Non-Functional Requirements

1. **NFR1**: Startup time should not increase significantly when model is absent
2. **NFR2**: First vision tool call should be reasonably fast (<500ms if model pre-loaded)
3. **NFR3**: Memory efficient (don't load model if vision features unused)
4. **NFR4**: Thread-safe model initialization
5. **NFR5**: Clear logging for troubleshooting

## Design Options

### Option A: Eager Loading (Server Startup)

**Strategy**: Load model during `MCPServer.init()` if available.

```swift
public init() {
    self.pilot = AppPilot()

    // Attempt to load AIMv2 model at startup
    if let modelPath = resolveModelPath() {
        do {
            self.semanticAnalyzer = SemanticElementAnalyzer()
            try self.semanticAnalyzer?.loadModel(modelPath: modelPath)
            print("✅ AIMv2 vision features enabled")
        } catch {
            print("⚠️  AIMv2 model load failed: \(error)")
            print("   Vision tools will be unavailable")
            self.semanticAnalyzer = nil
        }
    } else {
        print("ℹ️  AIMv2 model not found")
        print("   Set AIMV2_MODEL_PATH or install model to ~/.aimv2/")
    }

    // Continue with server setup...
}
```

**Pros**:
- ✅ Immediate feedback on model availability
- ✅ Consistent tool performance (no first-use delay)
- ✅ Clear error messages at startup
- ✅ Fails fast if model is required

**Cons**:
- ❌ Slower startup (~2-3 seconds) even if vision features unused
- ❌ Memory overhead if vision features never used
- ❌ Server won't start if model loading is mandatory

**Recommended When**:
- Vision features are primary use case
- Fast tool response time is critical
- Users expect deterministic behavior

---

### Option B: Lazy Loading with Validation (Current + Enhanced)

**Strategy**: Validate model path at startup, load on first use.

```swift
public init() {
    self.pilot = AppPilot()

    // Validate model availability without loading
    self.modelPath = resolveModelPath()
    if modelPath != nil {
        print("✅ AIMv2 model detected (will load on first use)")
    } else {
        print("ℹ️  AIMv2 model not found - vision tools unavailable")
    }

    // Continue with server setup...
}

// In tool handlers:
private func ensureModelLoaded() throws {
    guard let path = modelPath else {
        throw AppMCPError.modelNotAvailable("""
            AIMv2 model not configured. Install model:

            1. Download: huggingface.co/apple/aimv2-large-patch14-224
            2. Place at: ~/.aimv2/aimv2-large-patch14-224
            Or set: AIMV2_MODEL_PATH=/path/to/model
            """)
    }

    if semanticAnalyzer == nil {
        semanticAnalyzer = SemanticElementAnalyzer()
        try semanticAnalyzer!.loadModel(modelPath: path)
    }
}
```

**Pros**:
- ✅ Fast startup (no model loading)
- ✅ Memory efficient (only load if used)
- ✅ Early validation of model path
- ✅ Server starts even without model

**Cons**:
- ⚠️ First vision tool call has loading delay
- ⚠️ Model load errors delayed until first use
- ⚠️ Requires careful error handling in tools

**Recommended When**:
- Vision features are optional
- Fast startup is important
- Model may not be present in all deployments

---

### Option C: Explicit Initialization Tool

**Strategy**: Provide dedicated tool for model loading.

```swift
MCP.Tool(
    name: "initialize_vision_model",
    description: "Load AIMv2 vision model for similarity search",
    inputSchema: [
        "type": "object",
        "properties": [
            "modelPath": [
                "type": "string",
                "description": "Optional custom model path"
            ]
        ]
    ]
)

// Handler:
func handleInitializeVisionModel(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
    do {
        let customPath = extractOptionalString(from: arguments, key: "modelPath")
        let analyzer = SemanticElementAnalyzer()
        try analyzer.loadModel(modelPath: customPath)
        self.semanticAnalyzer = analyzer

        return .success("Vision model loaded successfully")
    } catch {
        return .error("Failed to load model: \(error)")
    }
}
```

**Pros**:
- ✅ Complete user control over loading
- ✅ Can retry with different paths
- ✅ Clear separation of concerns
- ✅ Can unload/reload model dynamically

**Cons**:
- ❌ Extra step for users (must call tool first)
- ❌ More complex workflow
- ❌ Vision tools fail if not initialized
- ❌ Need to document initialization requirement

**Recommended When**:
- Advanced users need fine control
- Multiple model paths need testing
- Model reloading is required

---

### Option D: Hybrid Approach (Recommended)

**Strategy**: Combine automatic startup validation with graceful lazy loading.

```swift
public init() {
    self.pilot = AppPilot()

    // Phase 1: Check model availability
    self.modelPath = resolveModelPath()
    self.modelStatus = validateModelPath(modelPath)

    // Phase 2: Optional eager loading if env var set
    if ProcessInfo.processInfo.environment["AIMV2_PRELOAD"] == "true" {
        if let path = modelPath {
            print("🔄 Pre-loading AIMv2 model...")
            do {
                semanticAnalyzer = SemanticElementAnalyzer()
                try semanticAnalyzer?.loadModel(modelPath: path)
                print("✅ AIMv2 model pre-loaded")
            } catch {
                print("⚠️  Pre-load failed: \(error)")
            }
        }
    }

    // Phase 3: Log status
    switch modelStatus {
    case .ready:
        print("✅ AIMv2 ready (lazy load)")
    case .notFound:
        print("ℹ️  AIMv2 not configured")
    case .invalid(let reason):
        print("⚠️  AIMv2 model invalid: \(reason)")
    }
}
```

**Pros**:
- ✅ Fast startup by default
- ✅ Optional pre-loading for power users
- ✅ Clear status reporting
- ✅ Flexible for different use cases
- ✅ Graceful degradation

**Cons**:
- ⚠️ More complex implementation
- ⚠️ Multiple code paths to test

**Recommended When**:
- Need to support diverse deployment scenarios
- Want both performance and flexibility
- Target both casual and power users

## Recommended Design: Option D (Hybrid)

### Architecture

```
MCPServer Initialization
├── Phase 1: Model Discovery
│   ├── Check AIMV2_MODEL_PATH env var
│   ├── Check ~/.aimv2/aimv2-large-patch14-224
│   └── Set modelStatus: .ready | .notFound | .invalid
│
├── Phase 2: Conditional Pre-loading
│   ├── If AIMV2_PRELOAD=true → load now
│   └── Else → defer to first use
│
└── Phase 3: Status Reporting
    └── Log clear status message

Tool Execution (find_similar_elements, etc.)
├── Check semanticAnalyzer != nil
│   ├── If loaded → proceed
│   └── If not loaded → ensureModelLoaded()
│
└── ensureModelLoaded()
    ├── Check modelStatus
    │   ├── .notFound → actionable error
    │   ├── .invalid → detailed error
    │   └── .ready → load model
    └── Handle errors gracefully
```

### Error Handling Strategy

```swift
enum ModelStatus {
    case ready(path: String)
    case notFound
    case invalid(reason: String)
}

func ensureModelLoaded() throws {
    if semanticAnalyzer != nil { return }

    switch modelStatus {
    case .ready(let path):
        semanticAnalyzer = SemanticElementAnalyzer()
        try semanticAnalyzer!.loadModel(modelPath: path)

    case .notFound:
        throw AppMCPError.modelNotAvailable("""
            AIMv2 vision model not found.

            To enable vision features:
            1. Download model from HuggingFace:
               https://huggingface.co/apple/aimv2-large-patch14-224

            2. Install to default location:
               ~/.aimv2/aimv2-large-patch14-224/

            Or set environment variable:
               export AIMV2_MODEL_PATH=/path/to/model
            """)

    case .invalid(let reason):
        throw AppMCPError.modelInvalid("""
            AIMv2 model is invalid: \(reason)

            Please verify:
            - Model files are complete
            - safetensors files are not corrupted
            - config.json is valid
            """)
    }
}
```

### Configuration

Users can control behavior via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `AIMV2_MODEL_PATH` | `~/.aimv2/aimv2-large-patch14-224` | Model directory path |
| `AIMV2_PRELOAD` | `false` | Pre-load model at startup |
| `AIMV2_REQUIRED` | `false` | Fail startup if model unavailable |

## Implementation Plan

### Phase 1: Model Status Enumeration (30 min)

```swift
// Add to AppMCPError.swift
enum ModelStatus {
    case ready(path: String)
    case notFound
    case invalid(reason: String)
}

extension AppMCPError {
    static func modelNotAvailable(_ message: String) -> AppMCPError
    static func modelInvalid(_ message: String) -> AppMCPError
}
```

### Phase 2: Model Path Resolution (45 min)

```swift
// Add to MCPServer.swift
private var modelPath: String?
private var modelStatus: ModelStatus = .notFound

private func resolveModelPath() -> String? {
    // 1. Check environment variable
    if let envPath = ProcessInfo.processInfo.environment["AIMV2_MODEL_PATH"] {
        return envPath
    }

    // 2. Check default location
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let defaultPath = homeDir.appendingPathComponent(".aimv2/aimv2-large-patch14-224").path
    if FileManager.default.fileExists(atPath: defaultPath) {
        return defaultPath
    }

    return nil
}

private func validateModelPath(_ path: String?) -> ModelStatus {
    guard let path = path else {
        return .notFound
    }

    // Check if directory exists
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
        return .invalid("Path is not a directory")
    }

    // Check for required files
    let configPath = "\(path)/config.json"
    guard FileManager.default.fileExists(atPath: configPath) else {
        return .invalid("config.json not found")
    }

    return .ready(path: path)
}
```

### Phase 3: Init Logic Update (30 min)

```swift
public init() {
    self.pilot = AppPilot()

    // Discover and validate model
    self.modelPath = resolveModelPath()
    self.modelStatus = validateModelPath(modelPath)

    // Optional pre-loading
    if ProcessInfo.processInfo.environment["AIMV2_PRELOAD"] == "true" {
        preloadModel()
    }

    // Status reporting
    logModelStatus()

    // Continue with server setup...
}

private func preloadModel() {
    guard case .ready(let path) = modelStatus else { return }

    print("🔄 Pre-loading AIMv2 model from: \(path)")
    do {
        let analyzer = SemanticElementAnalyzer()
        try analyzer.loadModel(modelPath: path)
        self.semanticAnalyzer = analyzer
        print("✅ AIMv2 model pre-loaded successfully")
    } catch {
        print("⚠️  Pre-load failed: \(error.localizedDescription)")
        print("   Model will load on first use")
    }
}

private func logModelStatus() {
    switch modelStatus {
    case .ready(let path):
        print("✅ AIMv2 model ready: \(path)")
        if semanticAnalyzer != nil {
            print("   Status: Pre-loaded")
        } else {
            print("   Status: Will load on first use")
        }
    case .notFound:
        print("ℹ️  AIMv2 model not found")
        print("   Vision tools unavailable")
        print("   See: https://huggingface.co/apple/aimv2-large-patch14-224")
    case .invalid(let reason):
        print("⚠️  AIMv2 model invalid: \(reason)")
        print("   Vision tools unavailable")
    }
}
```

### Phase 4: Tool Handler Updates (45 min)

```swift
private func ensureModelLoaded() throws {
    // Early return if already loaded
    if semanticAnalyzer != nil { return }

    // Handle based on status
    switch modelStatus {
    case .ready(let path):
        print("🔄 Loading AIMv2 model on first use...")
        let analyzer = SemanticElementAnalyzer()
        try analyzer.loadModel(modelPath: path)
        self.semanticAnalyzer = analyzer
        print("✅ Model loaded")

    case .notFound:
        throw AppMCPError.modelNotAvailable("""
            AIMv2 vision model not found.

            To enable vision similarity search:

            1. Download the model:
               https://huggingface.co/apple/aimv2-large-patch14-224

            2. Install to default location:
               mkdir -p ~/.aimv2
               mv aimv2-large-patch14-224 ~/.aimv2/

            Or use custom path:
               export AIMV2_MODEL_PATH=/your/path/to/model

            Then restart AppMCP.
            """)

    case .invalid(let reason):
        throw AppMCPError.modelInvalid("""
            AIMv2 model is invalid: \(reason)

            Please verify the model installation:
            - Check config.json exists
            - Verify safetensors files are complete
            - Re-download if corrupted
            """)
    }
}

// Update all vision tool handlers:
private func performFindSimilarElements(_ arguments: [String: MCP.Value]) async throws -> String {
    // Ensure model is loaded
    try ensureModelLoaded()

    guard let analyzer = semanticAnalyzer else {
        throw AppMCPError.systemError("Semantic analyzer failed to initialize")
    }

    // ... rest of implementation
}
```

### Phase 5: Testing (60 min)

Test scenarios:
1. ✅ Model present, no preload → loads on first tool call
2. ✅ Model present, preload enabled → loads at startup
3. ✅ Model absent → clear error message
4. ✅ Model invalid (missing files) → clear error message
5. ✅ Custom path via env var → loads correctly
6. ✅ Multiple tool calls → model loaded only once

## Documentation Requirements

### User Documentation

Update `README.md` with:

```markdown
## Vision Features (Optional)

AppMCP supports visual similarity search using Apple's AIMv2 model.

### Installation

1. Download the model:
   ```bash
   # Clone with Git LFS
   git lfs install
   git clone https://huggingface.co/apple/aimv2-large-patch14-224
   ```

2. Install to default location:
   ```bash
   mkdir -p ~/.aimv2
   mv aimv2-large-patch14-224 ~/.aimv2/
   ```

3. Or set custom path:
   ```bash
   export AIMV2_MODEL_PATH=/path/to/aimv2-large-patch14-224
   ```

### Performance Tuning

Pre-load model at startup for faster first call:
```bash
export AIMV2_PRELOAD=true
```

### Available Tools

- `find_similar_elements`: Find visually similar UI elements
- `group_elements_visually`: Group elements by visual similarity
```

### Developer Documentation

Update `CLAUDE.md` with:

```markdown
## AIMv2 Model Loading

The AIMv2 vision model uses a hybrid loading strategy:

1. **Startup**: Validates model availability without loading
2. **Runtime**: Loads on first tool use (lazy loading)
3. **Optional**: Pre-load with `AIMV2_PRELOAD=true`

### Testing

Test with model present:
```bash
AIMV2_MODEL_PATH=~/.aimv2/aimv2-large-patch14-224 swift run appmcpd
```

Test without model:
```bash
unset AIMV2_MODEL_PATH
swift run appmcpd
# Should start successfully with warning
```
```

## Security Considerations

1. **Path Validation**
   - Sanitize user-provided paths
   - Prevent directory traversal attacks
   - Validate model file integrity

2. **Resource Limits**
   - Model size ~300MB → ensure sufficient memory
   - Loading time 2-5s → may need timeout handling
   - Concurrent requests → ensure thread-safe loading

3. **Error Information**
   - Don't expose internal paths in error messages
   - Provide actionable guidance without revealing system details

## Future Enhancements

1. **Model Caching**: Keep model in memory across server restarts
2. **Hot Reload**: Detect model updates and reload
3. **Multiple Models**: Support different AIMv2 variants
4. **Model Quantization**: Reduce memory footprint
5. **Health Check Tool**: Verify model integrity

## Decision

**Selected Option**: Option D (Hybrid Approach)

**Rationale**:
- Balances startup speed with runtime performance
- Provides flexibility for different use cases
- Clear error messages improve user experience
- Graceful degradation when model unavailable
- Minimal impact on non-vision workflows

**Timeline**: 2.5 hours implementation + 1 hour testing

## Approval

- [ ] Technical Review
- [ ] User Experience Review
- [ ] Security Review
- [ ] Implementation Approved

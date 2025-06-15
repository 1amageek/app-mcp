# Vision Framework Text Recognition Integration

## Overview

AppMCP now includes Apple's Vision Framework for OCR (Optical Character Recognition) capabilities, enabling AI models to extract and analyze text from macOS application screenshots.

## Implementation Summary

### New Files Added

1. **`Sources/AppMCP/VisionTextRecognition.swift`**
   - Core Vision Framework integration
   - Text recognition utilities and result formatting
   - Support for multiple languages and recognition levels

2. **`Tests/AppMCPTests/VisionFrameworkTests.swift`**
   - Unit tests for Vision Framework functionality
   - Tests text recognition with synthetic images
   - Validates JSON and readable text formatting

3. **`Tests/AppMCPTests/TextRecognitionTests.swift`**
   - Integration tests for MCP tools with text recognition
   - Tests UI snapshot with OCR enabled
   - Tests dedicated text recognition tool

4. **`Examples/text_recognition_demo.py`**
   - Python demo script showing text recognition usage
   - Examples of all text recognition features

### Enhanced MCP Tools

#### Updated: `capture_ui_snapshot`
- Added `includeTextRecognition` boolean parameter
- Added `recognitionLanguages` array parameter
- When enabled, includes OCR results in response
- Graceful fallback if text recognition fails

#### New: `recognize_text_in_screenshot`
- Dedicated tool for text extraction from screenshots
- Parameters:
  - `bundleID`: Target application
  - `window`: Optional window specification
  - `languages`: Recognition languages (default: ["en-US"])
  - `recognitionLevel`: "accurate" or "fast" (default: "accurate")
- Returns detailed text recognition results with confidence scores

### Key Features

1. **Multi-Language Support**
   - Supports 50+ languages including English, Japanese, Chinese, etc.
   - Configurable language preferences per request

2. **Recognition Modes**
   - **Accurate**: Higher quality, slower processing
   - **Fast**: Optimized for speed, slightly lower accuracy

3. **Rich Results**
   - Full text in reading order
   - Individual text regions with bounding boxes
   - Confidence scores for each recognized text
   - Processing time metrics

4. **Coordinate System**
   - Normalized coordinates (0.0 to 1.0)
   - Top-left origin for consistency with UI frameworks

5. **Format Options**
   - JSON format for programmatic access
   - Human-readable format for debugging
   - Structured data with metadata

## Usage Examples

### Basic UI Snapshot with Text Recognition

```json
{
  "bundleID": "com.apple.TextEdit",
  "includeTextRecognition": true,
  "recognitionLanguages": ["en-US"]
}
```

### Dedicated Text Recognition

```json
{
  "bundleID": "com.apple.Safari",
  "languages": ["en-US", "ja-JP"],
  "recognitionLevel": "accurate"
}
```

### Multi-Language Text Recognition

```json
{
  "bundleID": "com.apple.TextEdit",
  "languages": ["en-US", "zh-Hans", "ja-JP"],
  "recognitionLevel": "fast"
}
```

## Response Format

### Text Recognition Result Structure

```json
{
  "recognizedTexts": [
    {
      "text": "Hello World",
      "confidence": 0.95,
      "boundingBox": {
        "x": 0.1,
        "y": 0.2,
        "width": 0.3,
        "height": 0.05
      },
      "language": null
    }
  ],
  "fullText": "Hello World",
  "primaryLanguage": null,
  "processingTime": 0.234
}
```

## Performance Considerations

1. **Processing Time**: OCR typically takes 0.2-2.0 seconds depending on image complexity
2. **Accuracy vs Speed**: "accurate" mode is recommended for production use
3. **Memory Usage**: Vision Framework handles memory management automatically
4. **Error Handling**: Graceful fallback ensures main functionality continues if OCR fails

## Benefits for AI Automation

1. **Text Verification**: Verify that expected text appears in UI
2. **Content Reading**: Extract text from images, PDFs, or non-accessible UI
3. **Form Filling**: Read existing form values before automation
4. **Error Detection**: Identify error messages or status text
5. **Accessibility**: Handle apps with poor accessibility implementation

## Integration with Existing Architecture

- **AppPilot Compatibility**: Works seamlessly with existing screenshot capture
- **MCP Protocol**: Follows established tool patterns and error handling
- **Async Design**: Non-blocking implementation preserves UI responsiveness
- **Type Safety**: Full Swift type safety with structured result types

## Future Enhancements

1. **Language Detection**: Automatic language detection for mixed-language content
2. **Text Regions**: Advanced text block detection (paragraphs, tables, etc.)
3. **Handwriting Support**: Enhanced handwritten text recognition
4. **Live OCR**: Real-time text recognition during UI automation
5. **Text Search**: Find specific text within screenshots

## Testing

The implementation includes comprehensive tests:

- **Unit Tests**: Core Vision Framework functionality
- **Integration Tests**: MCP tool behavior with real applications
- **Performance Tests**: Recognition speed benchmarks
- **Error Handling**: Graceful failure scenarios

All tests pass and demonstrate reliable text recognition functionality across various scenarios.

## Dependencies

- **Vision Framework**: Native Apple framework (macOS 10.15+)
- **CoreGraphics**: For image processing
- **AppPilot**: For screenshot capture integration
- **MCP SDK**: For protocol compliance

No external dependencies required - everything uses native Apple frameworks for optimal performance and compatibility.
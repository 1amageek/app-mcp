import Testing
import Foundation
import CoreGraphics
import AppKit
@testable import AppMCP

/// Unit tests for Vision Framework text recognition functionality
@Suite
struct VisionFrameworkTests {
    
    @Test("Vision text recognition with sample image")
    func testTextRecognitionWithSampleImage() async throws {
        // Create a sample image with text
        let image = try createSampleTextImage(text: "Hello Vision Framework", size: CGSize(width: 400, height: 100))
        
        // Perform text recognition
        let result = try await VisionTextRecognition.recognizeText(
            in: image,
            languages: ["en-US"],
            recognitionLevel: .accurate
        )
        
        // Verify results
        #expect(result.recognizedTexts.count > 0, "Should recognize at least one text region")
        #expect(result.fullText.contains("Hello") || result.fullText.contains("Vision") || result.fullText.contains("Framework"), 
                "Should recognize at least part of the text")
        #expect(result.processingTime > 0, "Processing time should be positive")
        
        print("Recognized text: '\(result.fullText)'")
        print("Number of text regions: \(result.recognizedTexts.count)")
        print("Processing time: \(String(format: "%.3f", result.processingTime))s")
    }
    
    @Test("Vision text recognition JSON formatting")
    func testTextRecognitionJSONFormatting() async throws {
        // Create a simple text image
        let image = try createSampleTextImage(text: "Test", size: CGSize(width: 100, height: 50))
        
        // Perform recognition
        let result = try await VisionTextRecognition.recognizeText(in: image)
        
        // Test JSON formatting
        let json = try VisionTextRecognition.formatAsJSON(result)
        #expect(json.contains("recognizedTexts"), "JSON should contain recognizedTexts field")
        #expect(json.contains("fullText"), "JSON should contain fullText field")
        #expect(json.contains("processingTime"), "JSON should contain processingTime field")
        
        // Verify it's valid JSON
        let data = json.data(using: .utf8)!
        _ = try JSONSerialization.jsonObject(with: data)
    }
    
    @Test("Vision text recognition structured formatting")
    func testTextRecognitionStructuredFormatting() async throws {
        // Create a simple text image
        let image = try createSampleTextImage(text: "Structured", size: CGSize(width: 150, height: 50))
        
        // Perform recognition
        let result = try await VisionTextRecognition.recognizeText(in: image)
        
        // Test structured formatting (replaces readable formatting)
        let structured = try VisionTextRecognition.formatAsStructuredData(result)
        #expect(structured.contains("\"metadata\""), "Should have metadata section")
        #expect(structured.contains("\"rawText\""), "Should have raw text section")
        #expect(structured.contains("\"structuredLayout\""), "Should have structured layout section")
        #expect(structured.contains("\"recognitionRevision\""), "Should include recognition revision")
        #expect(structured.contains("\"maxCandidatesCaptured\""), "Should include max candidates info")
        
        print("=== Structured Format ===")
        print(structured)
        print("========================")
    }
    
    @Test("Vision text recognition with multiple languages")
    func testMultiLanguageRecognition() async throws {
        // Create image with English text
        let image = try createSampleTextImage(text: "Hello World", size: CGSize(width: 200, height: 50))
        
        // Test with multiple language preferences
        let result = try await VisionTextRecognition.recognizeText(
            in: image,
            languages: ["en-US", "ja-JP", "zh-Hans"],
            recognitionLevel: .accurate
        )
        
        #expect(result.recognizedTexts.count > 0, "Should recognize text with multiple language settings")
    }
    
    @Test("Vision text recognition fast vs accurate")
    func testRecognitionLevels() async throws {
        let image = try createSampleTextImage(text: "Performance Test", size: CGSize(width: 300, height: 80))
        
        // Test fast recognition
        let fastResult = try await VisionTextRecognition.recognizeText(
            in: image,
            languages: ["en-US"],
            recognitionLevel: .fast
        )
        
        // Test accurate recognition
        let accurateResult = try await VisionTextRecognition.recognizeText(
            in: image,
            languages: ["en-US"],
            recognitionLevel: .accurate
        )
        
        print("Fast recognition time: \(String(format: "%.3f", fastResult.processingTime))s")
        print("Accurate recognition time: \(String(format: "%.3f", accurateResult.processingTime))s")
        
        // Both should recognize something
        #expect(fastResult.recognizedTexts.count > 0, "Fast mode should recognize text")
        #expect(accurateResult.recognizedTexts.count > 0, "Accurate mode should recognize text")
    }
    
    // MARK: - Helper Methods
    
    /// Creates a sample image with text for testing
    private func createSampleTextImage(text: String, size: CGSize) throws -> CGImage {
        // Create bitmap context
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw TestError.imageCreationFailed
        }
        
        // Fill white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        
        // Create attributed string and draw
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // Position text in center
        let textBounds = CTLineGetBoundsWithOptions(line, [])
        let x = (size.width - textBounds.width) / 2
        let y = (size.height - textBounds.height) / 2
        
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
        
        guard let image = context.makeImage() else {
            throw TestError.imageCreationFailed
        }
        
        return image
    }
}

enum TestError: Error {
    case imageCreationFailed
}
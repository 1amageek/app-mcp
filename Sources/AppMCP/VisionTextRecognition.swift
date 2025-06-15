import Foundation
import Vision
import CoreGraphics

/// Vision Framework text recognition integration for AppMCP
public struct VisionTextRecognition {
    
    
    /// Result of text recognition operation
    public struct TextRecognitionResult: Codable {
        /// Recognized text block containing multiple text elements
        public struct RecognizedTextBlock: Codable {
            /// Block identifier
            let blockId: String
            
            /// Combined text content of the entire block
            let blockText: String
            
            /// Overall confidence score for the block
            let blockConfidence: Float
            
            /// Bounding box encompassing the entire block
            let blockBoundingBox: BoundingBox
            
            /// Individual text elements within this block
            let textElements: [RecognizedText]
            
            /// Block-level corner points
            let blockCornerPoints: CornerPoints?
            
            /// Number of text elements in this block
            let elementCount: Int
        }
        
        /// Individual recognized text item
        public struct RecognizedText: Codable {
            /// Alternative text candidates
            public struct TextCandidate: Codable {
                let text: String
                let confidence: Float
            }
            
            /// The top recognized text string
            let text: String
            
            /// Confidence score (0.0 to 1.0)
            let confidence: Float
            
            /// Bounding box in normalized coordinates (0.0 to 1.0)
            let boundingBox: BoundingBox
            
            /// Language of the recognized text (if available)
            let language: String?
            
            /// Alternative recognition candidates
            let candidates: [TextCandidate]
            
            /// Individual corner points for precise positioning
            let cornerPoints: CornerPoints?
        }
        
        /// Corner points for precise text positioning
        public struct CornerPoints: Codable {
            let topLeft: Point
            let topRight: Point
            let bottomLeft: Point
            let bottomRight: Point
        }
        
        /// Point structure for Codable compatibility
        public struct Point: Codable {
            let x: Double
            let y: Double
            
            init(_ point: CGPoint) {
                self.x = Double(point.x)
                self.y = Double(point.y)
            }
        }
        
        /// Bounding box in normalized coordinates
        public struct BoundingBox: Codable {
            let x: Double
            let y: Double
            let width: Double
            let height: Double
        }
        
        /// All recognized text items (character-level)
        let recognizedTexts: [RecognizedText]
        
        /// Recognized text blocks (block-level, when using block recognition mode)
        let textBlocks: [RecognizedTextBlock]
        
        /// Combined text in reading order
        let fullText: String
        
        /// Primary language detected
        let primaryLanguage: String?
        
        /// Processing time in seconds
        let processingTime: Double
        
        /// Recognition engine revision
        let recognitionRevision: Int
        
        /// Recognition level used
        let recognitionLevel: String
        
        /// Maximum candidates captured per text element
        let maxCandidatesCaptured: Int
    }
    
    /// Performs block-level text recognition on a CGImage using VNRecognizedTextBlockObservation
    /// - Parameters:
    ///   - image: The image to analyze
    ///   - languages: Preferred languages for recognition. If empty, automatic language detection is used
    ///   - recognitionLevel: Recognition level (.accurate or .fast)
    ///   - maxCandidates: Maximum number of alternative candidates to capture (1-10)
    /// - Returns: Text recognition result with block-level grouping
    public static func recognizeText(
        in image: CGImage,
        languages: [String] = [],
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate,
        maxCandidates: Int = 3
    ) async throws -> TextRecognitionResult {
        let startTime = Date()
        
        // Create Vision request for block-level text recognition
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        
        // Use automatic language detection if no languages specified
        if languages.isEmpty {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = languages
        }
        
        request.usesLanguageCorrection = true
        
        // Process image
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        
        // Extract results
        guard let observations = request.results else {
            throw VisionError.noResults
        }
        
        // Group observations into blocks using spatial proximity
        let textBlocks = try groupTextIntoBlocks(observations, maxCandidates: maxCandidates)
        
        // Also maintain individual text elements for backward compatibility
        var recognizedTexts: [TextRecognitionResult.RecognizedText] = []
        var allTextLines: [String] = []
        
        for observation in observations {
            let candidates = observation.topCandidates(min(maxCandidates, 10))
            guard let topCandidate = candidates.first else {
                continue
            }
            
            let visionBox = observation.boundingBox
            let boundingBox = TextRecognitionResult.BoundingBox(
                x: visionBox.origin.x,
                y: 1.0 - (visionBox.origin.y + visionBox.height),
                width: visionBox.width,
                height: visionBox.height
            )
            
            let cornerPoints = TextRecognitionResult.CornerPoints(
                topLeft: TextRecognitionResult.Point(CGPoint(x: observation.topLeft.x, y: 1.0 - observation.topLeft.y)),
                topRight: TextRecognitionResult.Point(CGPoint(x: observation.topRight.x, y: 1.0 - observation.topRight.y)),
                bottomLeft: TextRecognitionResult.Point(CGPoint(x: observation.bottomLeft.x, y: 1.0 - observation.bottomLeft.y)),
                bottomRight: TextRecognitionResult.Point(CGPoint(x: observation.bottomRight.x, y: 1.0 - observation.bottomRight.y))
            )
            
            let candidatesArray = candidates.map { candidate in
                TextRecognitionResult.RecognizedText.TextCandidate(
                    text: candidate.string,
                    confidence: candidate.confidence
                )
            }
            
            let recognizedText = TextRecognitionResult.RecognizedText(
                text: topCandidate.string,
                confidence: topCandidate.confidence,
                boundingBox: boundingBox,
                language: nil,
                candidates: candidatesArray,
                cornerPoints: cornerPoints
            )
            
            recognizedTexts.append(recognizedText)
            allTextLines.append(topCandidate.string)
        }
        
        // Sort individual elements by reading order
        recognizedTexts.sort { first, second in
            let yTolerance = 0.02
            let firstY = first.boundingBox.y
            let secondY = second.boundingBox.y
            
            if abs(firstY - secondY) < yTolerance {
                return first.boundingBox.x < second.boundingBox.x
            } else {
                return firstY < secondY
            }
        }
        
        // Create full text from blocks (preferred) or individual elements
        let fullText = textBlocks.isEmpty ? 
            recognizedTexts.map { $0.text }.joined(separator: " ") :
            textBlocks.map { $0.blockText }.joined(separator: "\n")
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return TextRecognitionResult(
            recognizedTexts: recognizedTexts,
            textBlocks: textBlocks,
            fullText: fullText,
            primaryLanguage: nil,
            processingTime: processingTime,
            recognitionRevision: request.revision,
            recognitionLevel: recognitionLevel == .accurate ? "accurate" : "fast",
            maxCandidatesCaptured: maxCandidates
        )
    }
    
    /// Groups individual text observations into logical blocks based on spatial proximity
    private static func groupTextIntoBlocks(
        _ observations: [VNRecognizedTextObservation],
        maxCandidates: Int
    ) throws -> [TextRecognitionResult.RecognizedTextBlock] {
        
        var blocks: [TextRecognitionResult.RecognizedTextBlock] = []
        var processedObservations: Set<Int> = []
        
        for (index, observation) in observations.enumerated() {
            if processedObservations.contains(index) {
                continue
            }
            
            // Find all nearby observations that should be grouped with this one
            var blockObservations: [VNRecognizedTextObservation] = [observation]
            var blockIndices: [Int] = [index]
            processedObservations.insert(index)
            
            // Look for nearby text elements to group into this block
            let currentBox = observation.boundingBox
            let proximityThreshold: Double = 0.05 // 5% of image height/width
            
            for (otherIndex, otherObservation) in observations.enumerated() {
                if processedObservations.contains(otherIndex) {
                    continue
                }
                
                let otherBox = otherObservation.boundingBox
                
                // Check if the observations are close enough to be in the same block
                let verticalDistance = abs(currentBox.midY - otherBox.midY)
                let horizontalDistance = abs(currentBox.midX - otherBox.midX)
                
                // Group if they're on the same line (small vertical distance) or in the same column (small horizontal distance)
                let sameLineThreshold = min(currentBox.height, otherBox.height) * 1.5
                let sameColumnThreshold = proximityThreshold
                
                if verticalDistance < sameLineThreshold || horizontalDistance < sameColumnThreshold {
                    blockObservations.append(otherObservation)
                    blockIndices.append(otherIndex)
                    processedObservations.insert(otherIndex)
                }
            }
            
            // Sort observations within the block by reading order
            blockObservations.sort { first, second in
                let yTolerance = 0.02
                let firstY = 1.0 - (first.boundingBox.origin.y + first.boundingBox.height)
                let secondY = 1.0 - (second.boundingBox.origin.y + second.boundingBox.height)
                
                if abs(firstY - secondY) < yTolerance {
                    return first.boundingBox.origin.x < second.boundingBox.origin.x
                } else {
                    return firstY < secondY
                }
            }
            
            // Create block from grouped observations
            var blockTexts: [String] = []
            var blockConfidences: [Float] = []
            var blockElements: [TextRecognitionResult.RecognizedText] = []
            
            var minX = Double.greatestFiniteMagnitude
            var minY = Double.greatestFiniteMagnitude
            var maxX = -Double.greatestFiniteMagnitude
            var maxY = -Double.greatestFiniteMagnitude
            
            for blockObservation in blockObservations {
                let candidates = blockObservation.topCandidates(min(maxCandidates, 10))
                guard let topCandidate = candidates.first else {
                    continue
                }
                
                blockTexts.append(topCandidate.string)
                blockConfidences.append(topCandidate.confidence)
                
                // Update block bounding box
                let visionBox = blockObservation.boundingBox
                minX = min(minX, visionBox.origin.x)
                minY = min(minY, 1.0 - (visionBox.origin.y + visionBox.height))
                maxX = max(maxX, visionBox.origin.x + visionBox.width)
                maxY = max(maxY, 1.0 - visionBox.origin.y)
                
                // Create individual text element
                let elementBoundingBox = TextRecognitionResult.BoundingBox(
                    x: visionBox.origin.x,
                    y: 1.0 - (visionBox.origin.y + visionBox.height),
                    width: visionBox.width,
                    height: visionBox.height
                )
                
                let cornerPoints = TextRecognitionResult.CornerPoints(
                    topLeft: TextRecognitionResult.Point(CGPoint(x: blockObservation.topLeft.x, y: 1.0 - blockObservation.topLeft.y)),
                    topRight: TextRecognitionResult.Point(CGPoint(x: blockObservation.topRight.x, y: 1.0 - blockObservation.topRight.y)),
                    bottomLeft: TextRecognitionResult.Point(CGPoint(x: blockObservation.bottomLeft.x, y: 1.0 - blockObservation.bottomLeft.y)),
                    bottomRight: TextRecognitionResult.Point(CGPoint(x: blockObservation.bottomRight.x, y: 1.0 - blockObservation.bottomRight.y))
                )
                
                let candidatesArray = candidates.map { candidate in
                    TextRecognitionResult.RecognizedText.TextCandidate(
                        text: candidate.string,
                        confidence: candidate.confidence
                    )
                }
                
                let element = TextRecognitionResult.RecognizedText(
                    text: topCandidate.string,
                    confidence: topCandidate.confidence,
                    boundingBox: elementBoundingBox,
                    language: nil,
                    candidates: candidatesArray,
                    cornerPoints: cornerPoints
                )
                
                blockElements.append(element)
            }
            
            if blockTexts.isEmpty {
                continue
            }
            
            // Create block
            let blockText = blockTexts.joined(separator: " ")
            let blockConfidence = blockConfidences.reduce(0, +) / Float(blockConfidences.count)
            
            let blockBoundingBox = TextRecognitionResult.BoundingBox(
                x: minX,
                y: minY,
                width: maxX - minX,
                height: maxY - minY
            )
            
            // Create block corner points from the bounding box
            let blockCornerPoints = TextRecognitionResult.CornerPoints(
                topLeft: TextRecognitionResult.Point(CGPoint(x: minX, y: minY)),
                topRight: TextRecognitionResult.Point(CGPoint(x: maxX, y: minY)),
                bottomLeft: TextRecognitionResult.Point(CGPoint(x: minX, y: maxY)),
                bottomRight: TextRecognitionResult.Point(CGPoint(x: maxX, y: maxY))
            )
            
            let textBlock = TextRecognitionResult.RecognizedTextBlock(
                blockId: "block_\(blocks.count)",
                blockText: blockText,
                blockConfidence: blockConfidence,
                blockBoundingBox: blockBoundingBox,
                textElements: blockElements,
                blockCornerPoints: blockCornerPoints,
                elementCount: blockElements.count
            )
            
            blocks.append(textBlock)
        }
        
        // Sort blocks by reading order
        blocks.sort { first, second in
            let yTolerance = 0.05
            let firstY = first.blockBoundingBox.y
            let secondY = second.blockBoundingBox.y
            
            if abs(firstY - secondY) < yTolerance {
                return first.blockBoundingBox.x < second.blockBoundingBox.x
            } else {
                return firstY < secondY
            }
        }
        
        return blocks
    }
    
    /// Formats text recognition result as JSON string for MCP response
    public static func formatAsJSON(_ result: TextRecognitionResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    /// Formats text recognition result as compact JSON for AI consumption
    /// Removes candidates, cornerPoints, and confidence to reduce size
    public static func formatAsCompactJSON(_ result: TextRecognitionResult) throws -> String {
        // Create compact text blocks
        let compactTextBlocks = result.textBlocks.map { block in
            [
                "blockId": block.blockId,
                "blockText": block.blockText,
                "blockBoundingBox": [
                    "x": block.blockBoundingBox.x,
                    "y": block.blockBoundingBox.y,
                    "width": block.blockBoundingBox.width,
                    "height": block.blockBoundingBox.height
                ],
                "elementCount": block.elementCount
            ]
        }
        
        // Create compact recognized texts
        let compactRecognizedTexts = result.recognizedTexts.map { text in
            [
                "text": text.text,
                "boundingBox": [
                    "x": text.boundingBox.x,
                    "y": text.boundingBox.y,
                    "width": text.boundingBox.width,
                    "height": text.boundingBox.height
                ]
            ]
        }
        
        // Create compact result
        let compactResult: [String: Any] = [
            "fullText": result.fullText,
            "textBlocks": compactTextBlocks,
            "recognizedTexts": compactRecognizedTexts,
            "processingTime": result.processingTime,
            "recognitionLevel": result.recognitionLevel,
            "maxCandidatesCaptured": result.maxCandidatesCaptured
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: compactResult, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
    
    /// Formats text recognition result as simplified structured data
    public static func formatAsStructuredData(_ result: TextRecognitionResult) throws -> String {
        // Group text elements by vertical regions (rows)
        let yTolerance = 0.05 // 5% tolerance for grouping into rows
        var textRows: [[TextRecognitionResult.RecognizedText]] = []
        
        for text in result.recognizedTexts {
            let textY = text.boundingBox.y
            
            // Find existing row that matches this Y position
            var foundRow = false
            for i in 0..<textRows.count {
                if let firstInRow = textRows[i].first {
                    let rowY = firstInRow.boundingBox.y
                    if abs(textY - rowY) < yTolerance {
                        textRows[i].append(text)
                        foundRow = true
                        break
                    }
                }
            }
            
            // Create new row if not found
            if !foundRow {
                textRows.append([text])
            }
        }
        
        // Sort rows by Y position and texts within rows by X position
        textRows.sort { $0.first!.boundingBox.y < $1.first!.boundingBox.y }
        for i in 0..<textRows.count {
            textRows[i].sort { $0.boundingBox.x < $1.boundingBox.x }
        }
        
        // Build simplified structured output
        var structuredData: [String: Any] = [
            "fullText": result.fullText,
            "processingTime": result.processingTime,
            "rows": []
        ]
        
        var layoutRows: [[String: Any]] = []
        
        for (rowIndex, row) in textRows.enumerated() {
            let rowText = row.map { $0.text }.joined(separator: " ")
            let avgY = row.map { $0.boundingBox.y }.reduce(0, +) / Double(row.count)
            let minX = row.map { $0.boundingBox.x }.min() ?? 0
            let maxX = row.map { $0.boundingBox.x + $0.boundingBox.width }.max() ?? 0
            
            let rowData: [String: Any] = [
                "index": rowIndex,
                "text": rowText,
                "bounds": [
                    round(minX * 10000) / 10000,
                    round(avgY * 10000) / 10000,
                    round((maxX - minX) * 10000) / 10000
                ],
                "elements": row.map { element in
                    [
                        "text": element.text,
                        "bounds": [
                            round(element.boundingBox.x * 10000) / 10000,
                            round(element.boundingBox.y * 10000) / 10000,
                            round(element.boundingBox.width * 10000) / 10000,
                            round(element.boundingBox.height * 10000) / 10000
                        ]
                    ]
                }
            ]
            
            layoutRows.append(rowData)
        }
        
        structuredData["rows"] = layoutRows
        
        let jsonData = try JSONSerialization.data(withJSONObject: structuredData, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }
    
    
}

/// Errors specific to Vision text recognition
enum VisionError: Error, LocalizedError {
    case noResults
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No text was recognized in the image"
        case .processingFailed(let message):
            return "Text recognition failed: \(message)"
        }
    }
}
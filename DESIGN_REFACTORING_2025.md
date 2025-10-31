# AppMCP アーキテクチャ再設計 2025

**作成日**: 2025-01-31
**ステータス**: Draft - Review Pending
**目的**: 現在の技術的問題を解決し、AIMv2の本来の目的（UI視覚状態認識）に特化したアーキテクチャに再設計する

---

## 📋 目次

1. [Executive Summary](#executive-summary)
2. [現状分析](#現状分析)
3. [新アーキテクチャ設計](#新アーキテクチャ設計)
4. [削除する機能](#削除する機能)
5. [追加・変更する機能](#追加変更する機能)
6. [技術的問題の解決](#技術的問題の解決)
7. [実装ロードマップ](#実装ロードマップ)
8. [移行計画](#移行計画)

---

## Executive Summary

### 🎯 設計の核心的変更

AppMCPの本質は「AIがmacOSアプリケーションの**視覚的状態**を理解し、適切に操作する」ことです。

**従来の誤った方向性**:
- ❌ AIMv2を「類似要素検索」に使用
- ❌ MobileCLIPによるテキスト-画像マッチング
- ❌ 視覚的な「グルーピング」機能

**新しい正しい方向性**:
- ✅ AIMv2を「UI状態の視覚認識」に特化
- ✅ IME状態、ポップアップ、フォーカス等のコンテキスト化
- ✅ LLMが判断できる構造化データの提供

### 📊 影響範囲

| カテゴリ | 変更内容 | 影響度 |
|---------|---------|--------|
| **依存関係** | MobileCLIP削除 | Medium |
| **Resource** | vision/similarity, vision/groups削除 | High |
| **Core Logic** | SemanticElementAnalyzer → VisualStateAnalyzer | Critical |
| **Bug Fixes** | 23個の技術的問題修正 | Critical |
| **API** | 新Resource: ui/visual-state追加 | High |

---

## 現状分析

### 📈 統計情報

- **総行数**: MCPServer.swift 約2200行
- **識別された問題**: 23個
  - CRITICAL: 3個
  - HIGH: 6個
  - MEDIUM: 9個
  - LOW: 5個
- **不要な依存関係**: MobileCLIP
- **不要な機能**: 類似性検索、要素グルーピング

### 🔴 CRITICAL問題（即時対応必須）

#### Issue #16: ensureModelLoaded()のデータ競合
**場所**: Lines 145-231
**問題**: タイムアウトチェック中にアンロック状態で競合発生

```swift
// 現在の問題コード
modelLoadLock.unlock()  // ← アンロック

while isModelLoading {
    if Date().timeIntervalSince(startTime) > maxWaitTime {
        throw AppMCPError.modelLoadTimeout(maxWaitTime)  // ← 別スレッドがロード完了してもエラー
    }
    Thread.sleep(forTimeInterval: checkInterval)
}

modelLoadLock.lock()  // ← 再ロック
```

**修正案**:
```swift
modelLoadLock.unlock()

while isModelLoading {
    if Date().timeIntervalSince(startTime) > maxWaitTime {
        // タイムアウト前に最終チェック
        modelLoadLock.lock()
        let stillLoading = isModelLoading
        modelLoadLock.unlock()

        if stillLoading {
            throw AppMCPError.modelLoadTimeout(maxWaitTime)
        }
        break
    }
    Thread.sleep(forTimeInterval: checkInterval)
}

modelLoadLock.lock()
```

#### Issue #1: クエリパラメータの整数解析脆弱性
**場所**: Lines 1532-1536, 1551-1555, 1585-1589, 1613-1617, 1632-1636
**問題**: `Int(string)`失敗時にエラーではなく文字列として扱う

```swift
// 現在の問題コード
if let window = params["window"] {
    if let windowIndex = Int(window) {
        arguments["window"] = .int(windowIndex)
    } else {
        arguments["window"] = .string(window)  // ← "99999999999999"も文字列として通る
    }
}
```

**修正案**:
```swift
if let window = params["window"] {
    guard let windowIndex = Int(window) else {
        throw AppMCPError.invalidParameters("Invalid window index: '\(window)'. Expected integer.")
    }
    guard windowIndex >= 0 else {
        throw AppMCPError.invalidParameters("Window index must be non-negative, got: \(windowIndex)")
    }
    arguments["window"] = .int(windowIndex)
}
```

#### Issue #7: Visionリソースのエラーマスキング
**場所**: Lines 1416-1431
**問題**: リソースエラーが通常のJSONとして返され、MCPクライアントが検出不可

```swift
// 現在の問題コード
catch {
    let errorData: [String: String] = ["error": error.localizedDescription]
    let errorJSON = try? JSONEncoder().encode(errorData)
    return ReadResource.Result(contents: [
        .text(errorJSON, uri: uri, mimeType: "application/json")
    ])
    // ← isError フラグがない！
}
```

**修正案**（要MCP SDK調査）:
```swift
// Option 1: エラー専用MIMEタイプ
return ReadResource.Result(contents: [
    .text(errorJSON, uri: uri, mimeType: "application/json+error")
])

// Option 2: 空のcontentsで返す（MCPプロトコル次第）
throw error  // MCPレイヤーで処理

// Option 3: エラーメタデータを含める
return ReadResource.Result(
    contents: [.text(errorJSON, uri: uri, mimeType: "application/json")],
    // isError: true  // ← ReadResource.Resultにこのフィールドがあるか要確認
)
```

### 🟠 HIGH問題（優先度高）

#### Issue #5: extractRequiredInt/OptionalInt メソッドの欠如
**影響範囲**: 全てのパラメータ抽出箇所

**修正**: 新しいヘルパーメソッド追加
```swift
private func extractRequiredInt(from arguments: [String: MCP.Value], key: String) throws -> Int {
    guard let value = arguments[key] else {
        throw AppMCPError.missingParameter(key)
    }

    switch value {
    case .int(let i):
        return i
    case .double(let d):
        guard d.rounded() == d else {
            throw AppMCPError.invalidParameterType(key, expected: "integer", got: "decimal \(d)")
        }
        guard d >= Double(Int.min) && d <= Double(Int.max) else {
            throw AppMCPError.invalidParameters("Integer overflow for parameter '\(key)': \(d)")
        }
        return Int(d)
    default:
        throw AppMCPError.invalidParameterType(key, expected: "integer", got: "\(value)")
    }
}

private func extractOptionalInt(from arguments: [String: MCP.Value], key: String) -> Int? {
    guard let value = arguments[key] else { return nil }
    return try? extractRequiredInt(from: [key: value], key: key)
}
```

#### Issue #8: ツールハンドラーでメトリクス未更新
**場所**: Lines 452-504 (全ツールハンドラー)

**修正**: 各ハンドラーにメトリクス追跡追加
```swift
internal func handleClickElement(_ arguments: [String: MCP.Value]) async -> CallTool.Result {
    let startTime = Date()

    do {
        let result = try await performClick(arguments)

        // メトリクス更新
        metricsLock.lock()
        metrics.totalToolCalls += 1
        metrics.totalExecutionTime += Date().timeIntervalSince(startTime)
        metricsLock.unlock()

        return CallTool.Result(content: [.text(result)])
    } catch {
        // エラー時もカウント
        metricsLock.lock()
        metrics.totalToolCalls += 1
        metrics.totalExecutionTime += Date().timeIntervalSince(startTime)
        metricsLock.unlock()

        return handleToolError(error, toolName: "click_element")
    }
}
```

#### Issue #9: エラー型変換の非一貫性
**場所**: Lines 1801-1856, 各perform*メソッド

**修正**: AppPilotエラー型の直接サポート
```swift
// AppPilotに型定義を追加してもらうか、
// エラー変換をperform*メソッド内で統一的に実施

private func performClick(_ arguments: [String: MCP.Value]) async throws -> String {
    do {
        let elementId = try extractRequiredString(from: arguments, key: "elementId")
        let result = try await pilot.click(elementID: elementId)
        return "Clicked element ID '\(elementId)'"
    } catch let error as AppPilotError {
        // AppPilotエラーを変換
        throw convertPilotError(error)
    } catch {
        // その他のエラーはそのまま
        throw error
    }
}
```

---

## 新アーキテクチャ設計

### 🏗️ コンポーネント構成

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Model (LLM)                           │
│  「視覚的状態を理解 + コンテキストに基づいて判断」            │
└────────────────────────┬────────────────────────────────────┘
                         │ JSON-RPC over STDIO
                         ↓
┌─────────────────────────────────────────────────────────────┐
│              AppMCP (MCP Protocol Layer)                    │
│                                                             │
│  Tools (Actions - 6個):                                     │
│  ├─ click_element      ← Element IDベース                   │
│  ├─ input_text         ← setValue/type選択可能              │
│  ├─ drag_drop                                               │
│  ├─ scroll_window                                           │
│  ├─ keyboard_input     ← ショートカット対応                 │
│  └─ wait_time                                               │
│                                                             │
│  Resources (Data - 9個 → 8個):                              │
│  ├─ ui/snapshot/{bundleID}       ← 既存                     │
│  ├─ ui/elements/{bundleID}       ← 既存                     │
│  ├─ ui/text/{bundleID}           ← Vision Framework OCR     │
│  ├─ ui/visual-state/{bundleID}  ← 🆕 AIM状態認識           │
│  ├─ resources/running_applications                          │
│  ├─ resources/application_windows                           │
│  ├─ system/vision_model_status                             │
│  └─ system/performance_metrics   ← 🆕 追加                  │
│                                                             │
│  削除:                                                       │
│  ✗ vision/similarity/{bundleID}   ← 不要                    │
│  ✗ vision/groups/{bundleID}       ← 不要                    │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ↓                                 ↓
┌──────────────────┐           ┌──────────────────────┐
│   AppPilot       │           │ VisualStateAnalyzer  │
│  (UI Automation) │           │   (AIMv2 based)      │
│                  │           │                      │
│ ・Accessibility  │           │ ・UI状態認識         │
│ ・CGEvent        │           │ ・IME検出            │
│ ・Screenshot     │           │ ・ポップアップ検出    │
└──────────────────┘           │ ・フォーカス分析     │
                               └──────────────────────┘
```

### 🆕 新コンポーネント: VisualStateAnalyzer

**目的**: スクリーンショットから視覚的なUI状態を抽出し、LLMが理解できる構造化データに変換

**ファイル**: `Sources/AppMCP/VisualStateAnalyzer.swift` (新規作成)

```swift
import Foundation
import AppKit
import SwiftAIM

/// UI状態の視覚的分析を担当
/// AIMv2モデルを使用してスクリーンショットから状態情報を抽出
public actor VisualStateAnalyzer {

    // MARK: - Properties

    private var aimv2: AIMv2Model?
    private let lock = NSLock()
    private var isModelLoaded = false

    // MARK: - Initialization

    public init(modelPath: String?) {
        if let path = modelPath {
            Task {
                try? await loadModel(path: path)
            }
        }
    }

    // MARK: - Model Management

    private func loadModel(path: String) async throws {
        // モデルロード実装（既存のSemanticElementAnalyzerから移植）
    }

    // MARK: - Core Analysis Methods

    /// スクリーンショット全体から視覚的状態を抽出
    public func extractVisualState(
        from screenshot: NSImage,
        elements: [AXUI.AXElement]
    ) async throws -> UIVisualState {

        guard let model = aimv2 else {
            throw AppMCPError.modelNotConfigured("AIMv2 model not loaded")
        }

        // 1. スクリーンショット全体の特徴抽出
        let globalFeatures = try await model.extractFeatures(from: screenshot)

        // 2. IME状態の検出
        let imeState = try await detectIMEState(
            screenshot: screenshot,
            features: globalFeatures,
            elements: elements
        )

        // 3. ポップアップの検出
        let popups = try await detectPopups(
            screenshot: screenshot,
            features: globalFeatures
        )

        // 4. フォーカス状態の分析
        let focusState = try await analyzeFocusState(
            screenshot: screenshot,
            elements: elements
        )

        // 5. セレクション状態
        let selectionState = try await detectSelectionState(
            screenshot: screenshot,
            elements: elements
        )

        // 6. ドラッグ状態（オプション）
        let dragState = try await detectDragState(screenshot: screenshot)

        return UIVisualState(
            imeStatus: imeState,
            popups: popups,
            focus: focusState,
            selection: selectionState,
            dragInProgress: dragState,
            timestamp: Date()
        )
    }

    // MARK: - Specific State Detection

    /// IME（入力メソッド）の状態検出
    private func detectIMEState(
        screenshot: NSImage,
        features: [Float],
        elements: [AXUI.AXElement]
    ) async throws -> IMEState? {

        // AIMv2で変換候補ウィンドウのパターンを検出
        // - 候補リストの視覚的特徴
        // - 現在選択中の項目
        // - 言語（日本語、中国語等）

        // 実装の詳細は後述
        return nil  // Placeholder
    }

    /// ポップアップウィンドウの検出
    private func detectPopups(
        screenshot: NSImage,
        features: [Float]
    ) async throws -> [PopupInfo] {

        // AIMv2でポップアップの視覚的パターンを検出
        // - ドロップダウンメニュー
        // - コンテキストメニュー
        // - ツールチップ
        // - 変換候補

        return []  // Placeholder
    }

    /// フォーカス状態の分析
    private func analyzeFocusState(
        screenshot: NSImage,
        elements: [AXUI.AXElement]
    ) async throws -> FocusState {

        // 視覚的なフォーカスインジケーター検出
        // - ハイライト色
        // - 点滅カーソル
        // - アウトライン

        return FocusState(
            elementType: "unknown",
            hasVisualFocus: false,
            cursorVisible: false
        )  // Placeholder
    }

    /// セレクション（選択範囲）の検出
    private func detectSelectionState(
        screenshot: NSImage,
        elements: [AXUI.AXElement]
    ) async throws -> SelectionState? {

        // 選択されているテキストや項目の検出
        // - ハイライトカラー
        // - 複数選択の範囲

        return nil  // Placeholder
    }

    /// ドラッグ操作中の状態検出
    private func detectDragState(
        screenshot: NSImage
    ) async throws -> DragState? {

        // ドラッグ中のアイテムやゴースト画像の検出

        return nil  // Placeholder
    }
}

// MARK: - Data Structures

/// UI全体の視覚的状態
public struct UIVisualState: Codable {
    public let imeStatus: IMEState?
    public let popups: [PopupInfo]
    public let focus: FocusState
    public let selection: SelectionState?
    public let dragInProgress: DragState?
    public let timestamp: Date
}

/// IME（入力メソッド）の状態
public struct IMEState: Codable {
    public let active: Bool
    public let language: String?  // "ja-JP", "zh-CN", etc.
    public let conversionCandidatesVisible: Bool
    public let candidates: [String]?
    public let selectedIndex: Int?
    public let inputMode: String?  // "hiragana", "katakana", "half-width", etc.
}

/// ポップアップ情報
public struct PopupInfo: Codable {
    public let type: PopupType
    public let bounds: CGRect
    public let items: [String]?
    public let selectedItem: String?
}

public enum PopupType: String, Codable {
    case conversionCandidate = "conversion_candidate"
    case dropdown = "dropdown"
    case contextMenu = "context_menu"
    case tooltip = "tooltip"
    case autocomplete = "autocomplete"
}

/// フォーカス状態
public struct FocusState: Codable {
    public let elementType: String
    public let hasVisualFocus: Bool
    public let cursorVisible: Bool
    public let cursorPosition: Int?
}

/// セレクション状態
public struct SelectionState: Codable {
    public let hasSelection: Bool
    public let selectedText: String?
    public let selectionRange: NSRange?
    public let multipleItemsSelected: Bool
    public let selectedItemCount: Int?
}

/// ドラッグ状態
public struct DragState: Codable {
    public let itemBeingDragged: String?
    public let dragGhostVisible: Bool
    public let dragOrigin: CGPoint?
    public let currentPosition: CGPoint?
}
```

### 📡 新Resource: ui/visual-state

**URI**: `appmcp://ui/visual-state/{bundleID}`

**クエリパラメータ**:
- `window` (optional): ウィンドウインデックスまたはタイトル
- `detailLevel` (optional): "basic" | "detailed" (default: "basic")

**レスポンス例**:
```json
{
  "bundleID": "com.apple.TextEdit",
  "windowTitle": "Untitled",
  "visualState": {
    "imeStatus": {
      "active": true,
      "language": "ja-JP",
      "conversionCandidatesVisible": true,
      "candidates": ["こんにちは", "今日は", "混入派"],
      "selectedIndex": 0,
      "inputMode": "hiragana"
    },
    "popups": [
      {
        "type": "conversion_candidate",
        "bounds": {"x": 120, "y": 80, "width": 200, "height": 90},
        "items": ["こんにちは", "今日は", "混入派"],
        "selectedItem": "こんにちは"
      }
    ],
    "focus": {
      "elementType": "textfield",
      "hasVisualFocus": true,
      "cursorVisible": true,
      "cursorPosition": 5
    },
    "selection": null,
    "dragInProgress": null,
    "timestamp": "2025-01-31T10:30:45.123Z"
  },
  "processingTime": 0.156
}
```

**LLMへの活用例**:
```python
# AIモデルへのプロンプト
context = f"""
Current UI State:
- IME is active (Japanese hiragana mode)
- Conversion candidates are visible: ["こんにちは", "今日は", "混入派"]
- Currently selected: "こんにちは" (index 0)
- Text field has focus with cursor at position 5

User wants to: "Select the second candidate"

What action should we take?
"""

# LLMの応答
# → "Press the down arrow key to move to the next candidate"
# → Use tool: keyboard_input with keys=["down"]
```

---

## 削除する機能

### 🗑️ 削除対象一覧

#### 1. MobileCLIP依存関係
**ファイル**: `Package.swift`

```diff
dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.2"),
    .package(url: "https://github.com/1amageek/AppPilot.git", branch: "main"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
-   .package(url: "https://github.com/1amageek/MobileCLIP.git", branch: "main"),
    .package(url: "https://github.com/1amageek/swift-aim.git", branch: "main")
],
targets: [
    .target(
        name: "AppMCP",
        dependencies: [
            .product(name: "MCP", package: "swift-sdk"),
            .product(name: "AppPilot", package: "AppPilot"),
-           .product(name: "MobileCLIP", package: "MobileCLIP"),
            .product(name: "SwiftAIM", package: "swift-aim")
        ]
    )
]
```

#### 2. SemanticElementAnalyzer.swift の機能削除

**削除するメソッド**:
- `findSimilarElements(referenceElement:screenshot:elements:topK:)`
- `groupVisualElements(_:from:numberOfGroups:)`
- これらに関連する全てのヘルパーメソッド

**保持するメソッド**:
- `loadModel(path:)` - VisualStateAnalyzerに移植
- `getModelStatus()` - VisualStateAnalyzerに移植
- `unloadModel()` - VisualStateAnalyzerに移植

**最終的な対応**:
→ `SemanticElementAnalyzer.swift` 全体を削除し、`VisualStateAnalyzer.swift` に置き換え

#### 3. MCPServer.swift のメソッド削除

```swift
// 削除対象メソッド
- performFindSimilarElements(_ arguments:)        // Lines 647-725
- performGroupElementsVisually(_ arguments:)      // Lines 727-803
- getVisionSimilarity(bundleID:params:)           // Lines 1602-1626
- getVisionGroups(bundleID:params:)               // Lines 1628-1645
```

#### 4. Resource URIの削除

**ListResources ハンドラー** (Lines 1311-1332):
```diff
if self.isVisionModelAvailable {
    resources.append(contentsOf: [
-       MCP.Resource(
-           name: "vision_similarity",
-           uri: "appmcp://vision/similarity/{bundleID}",
-           description: "Find visually similar UI elements..."
-       ),
-       MCP.Resource(
-           name: "vision_groups",
-           uri: "appmcp://vision/groups/{bundleID}",
-           description: "Group UI elements by visual similarity..."
-       ),
        MCP.Resource(
            name: "vision_model_status",
            uri: "appmcp://system/vision_model_status",
            description: "Get AIMv2 model status and performance metrics"
        )
    ])
}
```

**handleResource ルーター** (Lines 1378-1408):
```diff
case "vision":
    guard isVisionModelAvailable else {
        throw AppMCPError.modelNotConfigured("Vision model not available")
    }

    guard parsedURI.pathComponents.count >= 3 else {
        throw AppMCPError.invalidParameters("Invalid vision resource URI...")
    }

    let resourceType = parsedURI.pathComponents[1]
    let bundleID = parsedURI.pathComponents[2]

    switch resourceType {
-   case "similarity":
-       content = try await getVisionSimilarity(bundleID: bundleID, params: parsedURI.queryParameters)
-   case "groups":
-       content = try await getVisionGroups(bundleID: bundleID, params: parsedURI.queryParameters)
+   case "state":
+       content = try await getVisualState(bundleID: bundleID, params: parsedURI.queryParameters)
    default:
        throw AppMCPError.invalidParameters("Unknown vision resource type: \(resourceType)")
    }
```

---

## 追加・変更する機能

### 🆕 新規追加

#### 1. VisualStateAnalyzer.swift
前述の設計に基づいて新規作成

#### 2. 新Resource: ui/visual-state/{bundleID}

**実装**: MCPServer.swift
```swift
// ListResources に追加
if self.isVisionModelAvailable {
    resources.append(
        MCP.Resource(
            name: "ui_visual_state",
            uri: "appmcp://ui/visual-state/{bundleID}",
            description: """
            Extract visual UI state information including:
            - IME (Input Method Editor) status and conversion candidates
            - Popup windows and dropdown menus
            - Focus state and cursor position
            - Selection state (highlighted text/items)
            - Drag-in-progress state

            Query parameters:
            - window: Window index or title (optional)
            - detailLevel: "basic" or "detailed" (default: "basic")

            Returns structured JSON with visual state context optimized for LLM consumption.
            """
        )
    )
}

// handleResource に追加
case "ui":
    guard parsedURI.pathComponents.count >= 3 else {
        throw AppMCPError.invalidParameters("Invalid UI resource URI...")
    }

    let resourceType = parsedURI.pathComponents[1]
    let bundleID = parsedURI.pathComponents[2]

    switch resourceType {
    case "snapshot":
        content = try await getUISnapshot(bundleID: bundleID, params: parsedURI.queryParameters)
    case "elements":
        content = try await getUIElements(bundleID: bundleID, params: parsedURI.queryParameters)
    case "text":
        content = try await getUIText(bundleID: bundleID, params: parsedURI.queryParameters)
    case "visual-state":  // 🆕 追加
        content = try await getVisualState(bundleID: bundleID, params: parsedURI.queryParameters)
    default:
        throw AppMCPError.invalidParameters("Unknown UI resource type: \(resourceType)")
    }

// 新規メソッド実装
private func getVisualState(bundleID: String, params: [String: String]) async throws -> String {
    // VisualStateAnalyzerを使用
    guard let analyzer = visualStateAnalyzer else {
        throw AppMCPError.modelNotConfigured("Visual state analyzer not initialized")
    }

    var arguments: [String: MCP.Value] = ["bundleID": .string(bundleID)]

    // ウィンドウパラメータ
    if let window = params["window"] {
        if let windowIndex = Int(window) {
            arguments["window"] = .int(windowIndex)
        } else {
            arguments["window"] = .string(window)
        }
    }

    // 詳細レベル
    if let detailLevel = params["detailLevel"] {
        arguments["detailLevel"] = .string(detailLevel)
    }

    // アプリとウィンドウを解決
    let app = try await pilot.findApplication(bundleID: bundleID)
    let window = try await resolveWindow(from: arguments, for: app)

    // スクリーンショットと要素を取得
    let snapshot = try await pilot.snapshot(window: window)

    guard let screenshot = snapshot.image else {
        throw AppMCPError.systemError("Failed to capture screenshot")
    }

    // 視覚状態を抽出
    let visualState = try await analyzer.extractVisualState(
        from: screenshot,
        elements: snapshot.elements
    )

    // JSON化
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let resultData: [String: Any] = [
        "bundleID": bundleID,
        "windowTitle": snapshot.title ?? "Unknown",
        "visualState": try JSONSerialization.jsonObject(
            with: encoder.encode(visualState),
            options: []
        ),
        "processingTime": Date().timeIntervalSince(Date())  // 実際は計測する
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: resultData, options: [.prettyPrinted, .sortedKeys])
    return String(data: jsonData, encoding: .utf8) ?? "{}"
}
```

#### 3. 新Resource: system/performance_metrics

**目的**: メトリクスをResourceとして公開（デバッグ用）

```swift
// ListResources に追加
resources.append(
    MCP.Resource(
        name: "performance_metrics",
        uri: "appmcp://system/performance_metrics",
        description: "Get AppMCP server performance metrics and statistics"
    )
)

// handleResource に追加
case "system":
    if parsedURI.path == "system/vision_model_status" {
        content = try await getVisionModelStatus()
    } else if parsedURI.path == "system/performance_metrics" {  // 🆕 追加
        content = try await getPerformanceMetrics()
    } else {
        throw AppMCPError.invalidParameters("Unknown system resource: \(uri)")
    }

// 新規メソッド実装
private func getPerformanceMetrics() async throws -> String {
    metricsLock.lock()
    let currentMetrics = metrics
    metricsLock.unlock()

    let metricsData: [String: Any] = [
        "toolCalls": [
            "total": currentMetrics.totalToolCalls,
            "visionResourceReads": currentMetrics.visionResourceReads
        ],
        "performance": [
            "totalExecutionTime": currentMetrics.totalExecutionTime,
            "averageExecutionTime": currentMetrics.totalToolCalls > 0
                ? currentMetrics.totalExecutionTime / Double(currentMetrics.totalToolCalls)
                : 0
        ],
        "model": [
            "loadAttempts": currentMetrics.modelLoadAttempts,
            "loadSuccesses": currentMetrics.modelLoadSuccesses,
            "successRate": currentMetrics.modelLoadAttempts > 0
                ? Double(currentMetrics.modelLoadSuccesses) / Double(currentMetrics.modelLoadAttempts)
                : 0
        ],
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: metricsData, options: [.prettyPrinted, .sortedKeys])
    return String(data: jsonData, encoding: .utf8) ?? "{}"
}
```

### 🔄 変更する機能

#### 1. MCPServer.swift のプロパティ変更

```swift
// 変更前
private var semanticAnalyzer: SemanticElementAnalyzer?

// 変更後
private var visualStateAnalyzer: VisualStateAnalyzer?
```

#### 2. 初期化処理の変更

```swift
// init() メソッド内
// 変更前
if isVisionModelAvailable {
    semanticAnalyzer = SemanticElementAnalyzer(modelPath: modelPath)
}

// 変更後
if isVisionModelAvailable {
    visualStateAnalyzer = VisualStateAnalyzer(modelPath: modelPath)
}
```

#### 3. メトリクス名の変更

```swift
// PerformanceMetrics 構造体
private struct PerformanceMetrics {
    var totalToolCalls: Int = 0
    var visualStateReads: Int = 0  // ← 変更: visionResourceReads → visualStateReads
    var totalExecutionTime: TimeInterval = 0
    var modelLoadAttempts: Int = 0
    var modelLoadSuccesses: Int = 0
}
```

---

## 技術的問題の解決

### 🔧 修正計画

#### Phase 1: CRITICAL問題修正（即時）

**1. ensureModelLoaded() データ競合**
- タイムアウト前の最終チェック追加
- 推定工数: 30分
- テスト: 並行ロードのストレステスト

**2. クエリパラメータ整数解析**
- 5箇所の修正（getUISnapshot, getUIElements, getUIText, 旧vision系2つ）
- 推定工数: 1時間
- テスト: 無効な入力でのエラーハンドリング確認

**3. Visionリソースエラーマスキング**
- MCP SDK仕様確認
- エラーハンドリング統一
- 推定工数: 2時間（調査含む）
- テスト: エラー時のクライアント挙動確認

#### Phase 2: HIGH問題修正（優先度高）

**4. extractRequiredInt/OptionalInt追加**
- 新メソッド実装
- 既存コードの置き換え
- 推定工数: 2時間
- テスト: 型変換の全パターン

**5. ツールハンドラーメトリクス**
- 6個のハンドラーに追加
- 推定工数: 1.5時間
- テスト: メトリクス値の検証

**6. エラー型変換の一貫性**
- convertPilotError見直し
- 推定工数: 3時間
- テスト: 各種エラーケース

#### Phase 3: MEDIUM/LOW問題修正（順次）

残り15個の問題を優先度順に修正
- 推定工数: 8-10時間
- 個別のテスト

#### Phase 4: アーキテクチャ変更

**7. MobileCLIP削除**
- Package.swift修正
- import文削除
- 推定工数: 15分

**8. SemanticElementAnalyzer削除**
- ファイル削除
- 参照削除
- 推定工数: 30分

**9. VisualStateAnalyzer実装**
- 新ファイル作成
- コアロジック実装
- 推定工数: 16-20時間（段階的実装）

**10. Resource URI変更**
- vision/similarity, vision/groups削除
- ui/visual-state追加
- system/performance_metrics追加
- 推定工数: 4時間

---

## 実装ロードマップ

### 🗓️ タイムライン（推定）

#### Week 1: 安定化（技術的負債解消）
**目標**: 既存コードの品質向上

**Day 1-2**: CRITICAL問題修正
- ✅ Issue #16: データ競合
- ✅ Issue #1: 整数解析
- ✅ Issue #7: エラーマスキング
- **成果物**: 安定したベースコード

**Day 3-4**: HIGH問題修正
- ✅ Issue #5: Integer extractors
- ✅ Issue #8: メトリクス追跡
- ✅ Issue #9: エラー変換
- **成果物**: 一貫性のあるAPI

**Day 5**: MEDIUM/LOW問題修正
- ✅ 残り15個の問題を優先度順
- **成果物**: クリーンなコードベース

#### Week 2: アーキテクチャ移行（段階的）

**Day 6**: 不要機能の削除
- ✅ MobileCLIP依存削除
- ✅ vision/similarity, vision/groups Resource削除
- ✅ 関連メソッド削除
- **成果物**: スリムなコードベース

**Day 7-8**: VisualStateAnalyzer基盤実装
- ✅ ファイル作成
- ✅ データ構造定義
- ✅ モデルロード機能（SemanticElementAnalyzerから移植）
- **成果物**: 動作する基本フレームワーク

**Day 9-10**: コア機能実装（段階1）
- ✅ extractVisualState() 基本実装
- ✅ detectIMEState() プロトタイプ
- ✅ ui/visual-state Resource統合
- **成果物**: 基本的な状態認識機能

#### Week 3: 機能拡充

**Day 11-12**: 詳細検出実装
- ✅ detectPopups()
- ✅ analyzeFocusState()
- ✅ detectSelectionState()
- **成果物**: 包括的な状態認識

**Day 13-14**: パフォーマンス最適化
- ✅ キャッシング戦略
- ✅ 並行処理
- ✅ メモリ管理
- **成果物**: 高速で効率的な実装

**Day 15**: テストとドキュメント
- ✅ 統合テスト
- ✅ ドキュメント更新
- ✅ サンプルコード
- **成果物**: リリース準備完了

### 📊 進捗管理

**マイルストーン**:
1. ✅ M1: 技術的負債解消（Week 1 完了時）
2. ✅ M2: 不要機能削除（Day 6 完了時）
3. ✅ M3: 新アーキテクチャ基盤（Day 8 完了時）
4. ✅ M4: コア機能実装（Day 10 完了時）
5. ✅ M5: リリース準備（Day 15 完了時）

---

## 移行計画

### 🔀 段階的移行戦略

#### Stage 1: 互換性維持（Week 1）
- 既存のAPIは変更なし
- バグ修正のみ実施
- ユーザーへの影響: なし

#### Stage 2: 非推奨化（Week 2 Day 6）
- `vision/similarity` と `vision/groups` を非推奨としてマーク
- ドキュメントに移行ガイド追加
- エラーメッセージで新APIを案内
- ユーザーへの影響: 警告のみ

#### Stage 3: 新API導入（Week 2 Day 10）
- `ui/visual-state` Resource公開
- サンプルコード提供
- ユーザーへの影響: 新機能利用可能

#### Stage 4: 旧API削除（Week 3 完了後）
- `vision/similarity` と `vision/groups` 完全削除
- ユーザーへの影響: 移行必須（事前通知済み）

### 📢 コミュニケーション計画

**Week 1 開始時**:
```markdown
## AppMCP v2.0 Roadmap Announcement

We are planning significant improvements to AppMCP:

### What's Changing
- **Removing**: `vision/similarity` and `vision/groups` resources
- **Adding**: New `ui/visual-state` resource for better UI state recognition
- **Improving**: Bug fixes and performance enhancements

### Timeline
- Week 1: Bug fixes (no breaking changes)
- Week 2: Deprecation warnings added
- Week 3: New APIs available
- Week 4: Migration required

### Migration Guide
Coming soon in Week 2.
```

**Week 2 Day 6**:
```markdown
## Migration Guide: vision/* → ui/visual-state

### Old (Deprecated)
```python
# 類似要素検索
similar = await mcp.read_resource(
    "appmcp://vision/similarity/com.apple.weather?referenceElementId=btn_01&topK=5"
)
```

### New (Recommended)
```python
# 視覚的状態取得
state = await mcp.read_resource(
    "appmcp://ui/visual-state/com.apple.weather"
)

# LLMに状態を渡して判断
context = f"""
UI State: {state['visualState']}
User wants: Find all buttons similar to the search button
"""
# LLMが要素を特定
```

### Why This Change?
The new approach:
1. Provides richer context to LLMs
2. Handles IME states (Japanese input, etc.)
3. Detects popups, focus, and other visual states
4. Better aligns with AI-first automation

### Deprecation Schedule
- Now: Warnings added
- Week 3: New API available
- Week 4: Old API removed
```

---

## テスト戦略

### 🧪 テストカバレッジ

#### 1. ユニットテスト

**VisualStateAnalyzer**:
```swift
@Test("IME detection with Japanese conversion")
func testIMEDetectionJapanese() async throws {
    let analyzer = VisualStateAnalyzer(modelPath: testModelPath)
    let screenshot = loadTestImage("japanese_ime_active.png")
    let elements = loadTestElements("japanese_ime_elements.json")

    let state = try await analyzer.extractVisualState(
        from: screenshot,
        elements: elements
    )

    #expect(state.imeStatus?.active == true)
    #expect(state.imeStatus?.language == "ja-JP")
    #expect(state.imeStatus?.conversionCandidatesVisible == true)
    #expect(state.imeStatus?.candidates?.count ?? 0 > 0)
}

@Test("Popup detection")
func testPopupDetection() async throws {
    let analyzer = VisualStateAnalyzer(modelPath: testModelPath)
    let screenshot = loadTestImage("dropdown_menu.png")

    let state = try await analyzer.extractVisualState(
        from: screenshot,
        elements: []
    )

    #expect(state.popups.count > 0)
    #expect(state.popups.first?.type == .dropdown)
}
```

**MCPServer - Resource**:
```swift
@Test("ui/visual-state resource")
func testVisualStateResource() async throws {
    let server = AppMCPServer()
    let uri = "appmcp://ui/visual-state/com.apple.finder"

    let result = await server.handleResource(uri: uri)

    #expect(!result.contents.isEmpty)

    if case .text(let content, _, _) = result.contents.first {
        let data = content.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["bundleID"] as? String == "com.apple.finder")
        #expect(json["visualState"] != nil)
    }
}
```

#### 2. 統合テスト

**エンドツーエンド日本語入力シナリオ**:
```swift
@Test("Japanese input with IME state detection")
func testJapaneseInputFlow() async throws {
    let server = AppMCPServer()

    // 1. TextEditを起動
    // 2. ui/visual-state で状態確認
    let stateURI = "appmcp://ui/visual-state/com.apple.TextEdit"
    let stateResult = await server.handleResource(uri: stateURI)

    // 3. 日本語入力開始
    _ = await server.handleKeyboardInput([
        "keys": .array([.string("cmd"), .string("space")])  // IME切り替え
    ])

    // 4. テキスト入力
    _ = await server.handleInputText([
        "elementId": .string("elem_textfield_001"),
        "text": .string("konnichiha"),  // ローマ字入力
        "method": .string("type")
    ])

    // 5. 状態再確認（変換候補が表示されているはず）
    let stateResult2 = await server.handleResource(uri: stateURI)

    // 検証
    if case .text(let content, _, _) = stateResult2.contents.first {
        let json = try parseJSON(content)
        let imeStatus = json["visualState"]["imeStatus"] as! [String: Any]

        #expect(imeStatus["active"] as? Bool == true)
        #expect(imeStatus["conversionCandidatesVisible"] as? Bool == true)
    }
}
```

#### 3. パフォーマンステスト

```swift
@Test("Visual state extraction performance")
func testPerformance() async throws {
    let analyzer = VisualStateAnalyzer(modelPath: testModelPath)
    let screenshot = loadTestImage("complex_ui.png")
    let elements = loadTestElements("complex_ui_elements.json")

    let startTime = Date()

    for _ in 0..<10 {
        _ = try await analyzer.extractVisualState(
            from: screenshot,
            elements: elements
        )
    }

    let totalTime = Date().timeIntervalSince(startTime)
    let avgTime = totalTime / 10

    // 平均200ms以下を目標
    #expect(avgTime < 0.2)
}
```

---

## リスク管理

### ⚠️ 主要リスク

| リスク | 影響度 | 確率 | 軽減策 |
|-------|--------|------|--------|
| AIMv2の精度不足 | High | Medium | 段階的実装、フォールバック機能 |
| パフォーマンス劣化 | Medium | Medium | プロファイリング、最適化 |
| 既存ユーザーの移行困難 | Medium | Low | 詳細な移行ガイド、段階的廃止 |
| モデルロードのメモリ不足 | High | Low | メモリ監視、アンロード機能 |
| テスト不足 | High | Medium | 包括的テストスイート |

### 🛡️ ロールバック計画

各ステージでロールバック可能:
- Stage 1完了時: Git tag `v2.0-stage1`
- Stage 2完了時: Git tag `v2.0-stage2`
- Stage 3完了時: Git tag `v2.0-stage3`

問題発生時は前のステージに戻す。

---

## 成功基準

### ✅ 定量的指標

1. **コード品質**
   - ✅ 技術的問題: 23個 → 0個
   - ✅ コードカバレッジ: 現在60% → 目標80%
   - ✅ 警告: 現在2個 → 0個

2. **パフォーマンス**
   - ✅ 視覚状態抽出: < 200ms (平均)
   - ✅ メモリ使用量: < 500MB (AIMv2ロード時)
   - ✅ ツール実行時間: < 100ms (median)

3. **機能性**
   - ✅ IME検出精度: > 90%
   - ✅ ポップアップ検出精度: > 85%
   - ✅ フォーカス検出精度: > 95%

### ✅ 定性的指標

1. **使いやすさ**
   - ✅ LLMが状態を理解しやすい構造化データ
   - ✅ 明確なドキュメント
   - ✅ 実用的なサンプルコード

2. **保守性**
   - ✅ 明確な責任分離（UI automation vs State recognition）
   - ✅ 理解しやすいコード構造
   - ✅ 包括的なテスト

3. **拡張性**
   - ✅ 新しい状態検出の追加が容易
   - ✅ 他のVisionモデルへの置き換え可能
   - ✅ プラグイン機構（将来）

---

## 次のステップ

### 📋 即時アクション

1. **このドキュメントのレビュー**
   - ステークホルダーに共有
   - フィードバック収集
   - 最終承認

2. **開発環境準備**
   - ブランチ作成: `feature/architecture-v2`
   - 問題トラッキング: GitHub Issues作成
   - CI/CD設定更新

3. **Week 1 開始**
   - CRITICAL問題修正開始
   - 日次進捗レポート
   - ブロッカー早期解決

### 📞 連絡先

- **技術的質問**: [開発者Slack/Email]
- **進捗報告**: 毎週金曜日
- **緊急事項**: [連絡先]

---

**承認**:
- [ ] プロジェクトオーナー
- [ ] 技術リード
- [ ] QAリード

**最終更新**: 2025-01-31

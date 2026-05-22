# Best Practices Guide

This document outlines best practices for maintaining and extending the File Organizer App. It covers code quality, architecture, security, performance, and maintainability.

## Table of Contents

1. [Logging & Observability](#logging--observability)
2. [Error Handling](#error-handling)
3. [Security](#security)
4. [Code Quality](#code-quality)
5. [Testing](#testing)
6. [Performance](#performance)
7. [Documentation](#documentation)
8. [Swift/SwiftUI Best Practices](#swiftswiftui-best-practices)
9. [Concurrency & Threading](#concurrency--threading)
10. [Memory Management](#memory-management)
11. [API Design](#api-design)
12. [File System Operations](#file-system-operations)

---

## Logging & Observability

### Current State
- **Issue**: Using `print()` statements (82 instances) throughout the codebase
- **Problem**: No log levels, no structured logging, difficult to filter/debug in production

### Best Practices

#### 1. Use a Proper Logging Framework

**Recommended**: Create a `Logger` utility or use `os.log` (Apple's unified logging)

```swift
import os.log

enum LogLevel {
    case debug, info, warning, error
}

struct AppLogger {
    private static let subsystem = "com.fileorganizer.app"
    private static let category = "FileClassification"
    
    static func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = Logger(subsystem: subsystem, category: category)
        let fileName = (file as NSString).lastPathComponent
        
        switch level {
        case .debug:
            logger.debug("\(fileName):\(line) [\(function)] \(message)")
        case .info:
            logger.info("\(fileName):\(line) [\(function)] \(message)")
        case .warning:
            logger.warning("\(fileName):\(line) [\(function)] \(message)")
        case .error:
            logger.error("\(fileName):\(line) [\(function)] \(message)")
        }
    }
}

// Usage:
AppLogger.log(.info, "Classification started for \(fileName)")
AppLogger.log(.error, "Failed to parse LLM response: \(error.localizedDescription)")
```

#### 2. Replace All `print()` Statements

**Action Items**:
- [ ] Replace `print("⚠️ LLM classification failed: \(error)")` with `AppLogger.log(.warning, ...)`
- [ ] Replace `print("📊 Created experiment: \(name)")` with `AppLogger.log(.info, ...)`
- [ ] Add log levels based on severity
- [ ] Use structured logging for telemetry events

#### 3. Add Logging to Critical Operations

```swift
// In FileClassificationManager
func classifyFile(_ metadata: FileMetadata) async -> ClassificationResult {
    AppLogger.log(.info, "Starting classification for: \(metadata.fileName)")
    let startTime = Date()
    
    // ... classification logic ...
    
    let duration = Date().timeIntervalSince(startTime)
    AppLogger.log(.info, "Classification completed in \(duration)s with confidence \(result.confidence)")
    
    return result
}
```

---

## Error Handling

### Current State
- ✅ Good: `ClassificationError` enum with `LocalizedError`
- ⚠️ Needs improvement: Some errors are swallowed silently
- ⚠️ Needs improvement: Inconsistent error propagation

### Best Practices

#### 1. Never Swallow Errors Silently

**Bad**:
```swift
do {
    try someOperation()
} catch {
    // Silent failure - bad!
}
```

**Good**:
```swift
do {
    try someOperation()
} catch {
    AppLogger.log(.error, "Operation failed: \(error.localizedDescription)")
    // Either propagate, handle, or log with context
    throw error // or handle appropriately
}
```

#### 2. Provide Context in Errors

**Bad**:
```swift
throw ClassificationError.parseError("Failed to parse")
```

**Good**:
```swift
throw ClassificationError.parseError("Failed to parse LLM response for file '\(metadata.fileName)': \(response.prefix(100))")
```

#### 3. Use Result Types for Non-Throwing Operations

```swift
func classifyFile(_ metadata: FileMetadata) async -> Result<ClassificationResult, ClassificationError> {
    // ... classification logic ...
    return .success(result)
    // or
    return .failure(.apiError("API unavailable"))
}
```

#### 4. Add Retry Logic with Exponential Backoff

```swift
func classifyWithRetry(_ metadata: FileMetadata, maxRetries: Int = 3) async throws -> ClassificationResult {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
        do {
            return try await classifyWithLLM(metadata: metadata, preCategory: nil)
        } catch {
            lastError = error
            if attempt < maxRetries {
                let delay = pow(2.0, Double(attempt)) // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                AppLogger.log(.warning, "Retry attempt \(attempt + 1)/\(maxRetries) for \(metadata.fileName)")
            }
        }
    }
    
    throw lastError ?? ClassificationError.apiError("Unknown error after \(maxRetries) retries")
}
```

---

## Security

### Current State
- ⚠️ **Critical**: API keys passed as plain strings in initializers
- ⚠️ **Issue**: No secure storage for sensitive data
- ✅ Good: Metadata-only classification (privacy-friendly)

### Best Practices

#### 1. Store API Keys in Keychain

**Create a KeychainManager**:

```swift
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.fileorganizer.app"
    
    func store(apiKey: String, for service: String) throws {
        let data = apiKey.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey",
            kSecValueData as String: data
        ]
        
        // Delete existing
        SecItemDelete(query as CFDictionary)
        
        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    func retrieve(for service: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "apiKey",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return apiKey
    }
}

enum KeychainError: Error {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
}
```

**Update LLM Services**:

```swift
class OpenAILLMService: LLMService {
    private let apiKey: String
    
    init(serviceName: String = "openai") throws {
        guard let key = try KeychainManager.shared.retrieve(for: serviceName) else {
            throw KeychainError.retrieveFailed(errSecItemNotFound)
        }
        self.apiKey = key
    }
}
```

#### 2. Never Log Sensitive Data

**Bad**:
```swift
print("API Key: \(apiKey)") // NEVER DO THIS
```

**Good**:
```swift
AppLogger.log(.info, "Using API key for service: \(serviceName)")
// Or mask it:
AppLogger.log(.info, "API key: \(String(apiKey.prefix(4)) + "****")")
```

#### 3. Validate File Paths Before Processing

```swift
func validateFilePath(_ url: URL) throws {
    // Check if path is in allowed directories
    let allowedPaths = [
        FileManager.default.homeDirectoryForCurrentUser.path
    ]
    
    guard allowedPaths.contains(where: { url.path.hasPrefix($0) }) else {
        throw SecurityError.invalidPath("Path outside allowed directories")
    }
    
    // Check for path traversal attacks
    guard !url.path.contains("..") else {
        throw SecurityError.invalidPath("Path traversal detected")
    }
}
```

---

## Code Quality

### Current State
- ⚠️ One `fatalError` in `OllamaLLMService` - should be avoided
- ✅ Good: Most force unwraps have been fixed
- ✅ Good: Proper use of optionals

### Best Practices

#### 1. Avoid `fatalError` in Production Code

**Bad**:
```swift
guard let url = baseURL ?? URL(string: "http://localhost:11434") else {
    fatalError("Invalid Ollama base URL")
}
```

**Good**:
```swift
init(baseURL: URL? = nil) throws {
    guard let url = baseURL ?? URL(string: "http://localhost:11434") else {
        throw InitializationError.invalidURL("Invalid Ollama base URL: http://localhost:11434")
    }
    self.baseURL = url
}
```

#### 2. Use Guard Statements for Early Returns

**Bad**:
```swift
if let result = parseResponse(response) {
    if let validated = validateResult(result) {
        return validated
    }
}
return nil
```

**Good**:
```swift
guard let result = parseResponse(response) else {
    return nil
}
guard let validated = validateResult(result) else {
    return nil
}
return validated
```

#### 3. Extract Magic Numbers to Constants

**Bad**:
```swift
let batchSize = 10
if interval < 60 {
    // ...
}
```

**Good**:
```swift
enum ClassificationConstants {
    static let defaultBatchSize = 10
    static let maxRetryAttempts = 3
    static let maxFileSizeForHashing: Int64 = 100 * 1024 * 1024 // 100MB
    static let secondsPerMinute = 60
}
```

#### 4. Use Enums for State Management

```swift
enum ClassificationState {
    case idle
    case scanning
    case classifying
    case moving
    case completed
    case failed(Error)
}
```

---

## Testing

### Current State
- ✅ Good: Comprehensive test coverage
- ✅ Good: Unit, integration, and manual tests
- ⚠️ Could improve: Add more edge case tests

### Best Practices

#### 1. Test Edge Cases

```swift
func testClassificationWithEmptyMetadata() {
    let metadata = FileMetadata(
        fileName: "",
        fileExtension: "",
        fileSize: 0,
        // ... other fields
    )
    // Test behavior
}

func testClassificationWithVeryLongFilename() {
    let longName = String(repeating: "a", count: 1000) + ".pdf"
    // Test behavior
}

func testClassificationWithSpecialCharacters() {
    let specialName = "file with spaces & symbols!@#$%^&*().pdf"
    // Test behavior
}
```

#### 2. Use Test Fixtures

```swift
struct TestFixtures {
    static func sampleFileMetadata(
        fileName: String = "test.pdf",
        extension: String = "pdf",
        size: Int64 = 1024
    ) -> FileMetadata {
        FileMetadata(
            fileName: fileName,
            fileExtension: extension,
            fileSize: size,
            // ... other fields with defaults
        )
    }
}
```

#### 3. Test Error Conditions

```swift
func testClassificationHandlesAPIFailure() async {
    let mockService = MockLLMService()
    mockService.shouldFail = true
    mockService.error = ClassificationError.apiError("Network timeout")
    
    let manager = FileClassificationManager(llmService: mockService)
    let result = await manager.classifyFile(TestFixtures.sampleFileMetadata())
    
    XCTAssertEqual(result.method, .fallback)
    XCTAssertLessThan(result.confidence, 0.5)
}
```

#### 4. Use Async Testing Helpers

```swift
func testAsyncClassification() async throws {
    let expectation = XCTestExpectation(description: "Classification completes")
    
    Task {
        let result = await manager.classifyFile(metadata)
        XCTAssertNotNil(result)
        expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 5.0)
}
```

---

## Performance

### Current State
- ✅ Good: Async/await for concurrent operations
- ✅ Good: Batch processing implemented
- ⚠️ Could improve: Add rate limiting for API calls

### Best Practices

#### 1. Implement Rate Limiting

```swift
class RateLimiter {
    private let maxRequests: Int
    private let timeWindow: TimeInterval
    private var requestTimestamps: [Date] = []
    private let queue = DispatchQueue(label: "com.fileorganizer.ratelimiter")
    
    init(maxRequests: Int, per timeWindow: TimeInterval) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }
    
    func waitIfNeeded() async {
        await withCheckedContinuation { continuation in
            queue.async {
                let now = Date()
                // Remove old timestamps
                self.requestTimestamps = self.requestTimestamps.filter {
                    now.timeIntervalSince($0) < self.timeWindow
                }
                
                if self.requestTimestamps.count >= self.maxRequests {
                    let oldestRequest = self.requestTimestamps.first!
                    let waitTime = self.timeWindow - now.timeIntervalSince(oldestRequest)
                    Thread.sleep(forTimeInterval: waitTime)
                }
                
                self.requestTimestamps.append(Date())
                continuation.resume()
            }
        }
    }
}

// Usage in LLMService
func generateCompletion(prompt: String) async throws -> String {
    await rateLimiter.waitIfNeeded()
    // ... make API call ...
}
```

#### 2. Cache Classification Results

```swift
class ClassificationCache {
    private var cache: [String: ClassificationResult] = [:]
    private let queue = DispatchQueue(label: "com.fileorganizer.cache", attributes: .concurrent)
    
    func cacheKey(for metadata: FileMetadata) -> String {
        "\(metadata.fileName)_\(metadata.fileSize)_\(metadata.fileExtension)"
    }
    
    func get(for metadata: FileMetadata) -> ClassificationResult? {
        queue.sync {
            return cache[cacheKey(for: metadata)]
        }
    }
    
    func set(_ result: ClassificationResult, for metadata: FileMetadata) {
        queue.async(flags: .barrier) {
            self.cache[self.cacheKey(for: metadata)] = result
        }
    }
}
```

#### 3. Optimize File Metadata Extraction

```swift
// Extract metadata in parallel for multiple files
func extractMetadataBatch(_ urls: [URL]) async -> [FileMetadata] {
    await withTaskGroup(of: FileMetadata?.self) { group in
        for url in urls {
            group.addTask {
                return FileMetadata.extract(from: url)
            }
        }
        
        var results: [FileMetadata] = []
        for await metadata in group {
            if let metadata = metadata {
                results.append(metadata)
            }
        }
        return results
    }
}
```

---

## Documentation

### Current State
- ✅ Good: Comprehensive architecture docs
- ⚠️ Could improve: More inline code documentation

### Best Practices

#### 1. Document Public APIs

```swift
/// Classifies a file using LLM with automatic fallback to rule-based classification.
///
/// - Parameters:
///   - metadata: The file metadata to classify
/// - Returns: A `ClassificationResult` containing category, subfolder, confidence, and reasoning
/// - Throws: `ClassificationError` if classification fails and fallback is disabled
///
/// - Note: This method will automatically fall back to rule-based classification if LLM fails,
///   unless `useFallbackOnFailure` is set to `false`.
///
/// - Example:
///   ```swift
///   let result = await manager.classifyFile(metadata)
///   print("Category: \(result.category), Subfolder: \(result.subfolder)")
///   ```
func classifyFile(_ metadata: FileMetadata) async -> ClassificationResult {
    // ...
}
```

#### 2. Use MARK Comments for Organization

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Helper Methods
```

#### 3. Document Complex Algorithms

```swift
/// Recursively scans a directory and all subdirectories to collect files.
///
/// This method uses a depth-first search approach:
/// 1. Scan current directory contents
/// 2. For each item:
///    - If file: add to results
///    - If directory: recursively scan
/// 3. Skip hidden files and system directories
///
/// - Parameter folderURL: The root directory to scan
/// - Returns: Array of file URLs found recursively
/// - Throws: File system errors if directory cannot be accessed
private func getAllFilesRecursively(from folderURL: URL) throws -> [URL] {
    // ...
}
```

---

## Swift/SwiftUI Best Practices

### Best Practices

#### 1. Use Property Wrappers Correctly

```swift
// Good: Use @StateObject for owned objects
@StateObject private var keywordStore = KeywordStore()

// Good: Use @ObservedObject for passed objects
@ObservedObject var classificationManager: FileClassificationManager

// Good: Use @State for simple value types
@State private var isRunning = false
```

#### 2. Extract Complex Views

```swift
// Bad: 500+ line view
struct AIClassificationView: View {
    // ... everything ...
}

// Good: Break into smaller views
struct AIClassificationView: View {
    var body: some View {
        VStack {
            HeaderView()
            ProgressView()
            ActivityLogView()
            ControlButtonsView()
        }
    }
}
```

#### 3. Use ViewModifiers for Reusable Styling

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

#### 4. Handle Async Operations in Views

```swift
struct ClassificationView: View {
    @State private var result: ClassificationResult?
    @State private var isLoading = false
    
    var body: some View {
        // ...
        .task {
            await performClassification()
        }
    }
    
    private func performClassification() async {
        isLoading = true
        defer { isLoading = false }
        
        result = await manager.classifyFile(metadata)
    }
}
```

---

## Concurrency & Threading

### Current State
- ✅ Good: Proper use of async/await
- ⚠️ Mixed: Some `DispatchQueue` usage alongside async/await

### Best Practices

#### 1. Prefer async/await Over DispatchQueue

**Bad**:
```swift
DispatchQueue.global(qos: .userInitiated).async {
    let result = performOperation()
    DispatchQueue.main.async {
        self.updateUI(with: result)
    }
}
```

**Good**:
```swift
Task {
    let result = await performOperation()
    await MainActor.run {
        self.updateUI(with: result)
    }
}
```

#### 2. Use TaskGroup for Parallel Operations

```swift
// Already implemented correctly in FileClassificationManager
func classifyFiles(_ files: [FileMetadata]) async -> [ClassificationResult] {
    await withTaskGroup(of: (Int, ClassificationResult).self) { group in
        // ... parallel processing ...
    }
}
```

#### 3. Use Actors for Shared Mutable State

```swift
actor ClassificationCounter {
    private var count = 0
    
    func increment() {
        count += 1
    }
    
    func getCount() -> Int {
        return count
    }
}

// Usage
let counter = ClassificationCounter()
await counter.increment()
let count = await counter.getCount()
```

---

## Memory Management

### Best Practices

#### 1. Avoid Retain Cycles

```swift
// Bad: Strong reference cycle
class Manager {
    var callback: (() -> Void)?
}

let manager = Manager()
manager.callback = {
    manager.doSomething() // Retain cycle!
}

// Good: Use weak or unowned
manager.callback = { [weak manager] in
    manager?.doSomething()
}
```

#### 2. Release Large Objects When Done

```swift
func processLargeFile(_ url: URL) {
    var data: Data? = try? Data(contentsOf: url)
    // ... process data ...
    data = nil // Explicitly release
}
```

#### 3. Use Lazy Loading for Expensive Operations

```swift
class FileMetadata {
    lazy var contentPreview: String? = {
        // Only computed when accessed
        return extractPreview()
    }()
}
```

---

## API Design

### Best Practices

#### 1. Use Protocols for Abstraction

```swift
// Already well-implemented with LLMService protocol
protocol LLMService {
    func generateCompletion(prompt: String) async throws -> String
}
```

#### 2. Provide Sensible Defaults

```swift
// Good: Default parameters
init(
    llmService: LLMService,
    telemetryService: TelemetryService = TelemetryService.shared,
    fallbackClassifier: FallbackClassifier = FallbackClassifier()
)
```

#### 3. Use Result Builders for Complex Configurations

```swift
@resultBuilder
struct ClassificationConfigBuilder {
    static func buildBlock(_ components: ClassificationConfig...) -> ClassificationConfig {
        // Combine configurations
    }
}
```

---

## File System Operations

### Best Practices

#### 1. Always Check File Existence Before Operations

```swift
func moveFile(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
        throw FileError.sourceNotFound
    }
    
    // Check if destination exists
    if FileManager.default.fileExists(atPath: destination.path) {
        // Handle conflict
    }
    
    try FileManager.default.moveItem(at: source, to: destination)
}
```

#### 2. Use Resource Values for File Properties

```swift
// Already implemented correctly
let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
if resourceValues.isRegularFile == true {
    // Process file
}
```

#### 3. Handle Permissions Gracefully

```swift
func accessFile(_ url: URL) throws -> Data {
    guard url.startAccessingSecurityScopedResource() else {
        throw FileError.permissionDenied
    }
    defer { url.stopAccessingSecurityScopedResource() }
    
    return try Data(contentsOf: url)
}
```

---

## Summary: Priority Action Items

### High Priority
1. **Replace `print()` with proper logging** (82 instances)
2. **Store API keys in Keychain** (security critical)
3. **Remove `fatalError`** from production code
4. **Add rate limiting** for API calls

### Medium Priority
5. **Add retry logic with exponential backoff**
6. **Implement classification result caching**
7. **Add more edge case tests**
8. **Improve inline documentation**

### Low Priority
9. **Extract magic numbers to constants**
10. **Use actors for shared state**
11. **Add view modifiers for reusable styling**
12. **Optimize metadata extraction with parallel processing**

---

## References

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Apple's Logging Framework](https://developer.apple.com/documentation/os/logging)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)


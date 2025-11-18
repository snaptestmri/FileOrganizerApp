# AI Classification Tests - Documentation

> **Note:** Tests have been updated to use the new architecture:
> - `FallbackClassifier` (replaces `RuleBasedClassifier`)
> - `FileClassificationManager` (replaces `ClassifierManager`)
> - `OllamaLLMService`, `MockLLMService` (replaces `OllamaClassifier`)
> See [Architecture/ARCHITECTURE_MIGRATION_STATUS.md](../Architecture/ARCHITECTURE_MIGRATION_STATUS.md) for details.

## Overview

Comprehensive test suite for the AI File Classification feature, covering unit tests, integration tests, and performance tests.

## Test Files

### 1. AIClassificationTests.swift
**Unit tests for individual components**

#### FileMetadata Tests
- ✅ `testFileMetadataExtraction` - Basic metadata extraction
- ✅ `testFileMetadataWithPreview` - Text preview extraction
- ✅ `testFileMetadataWithoutPreview` - No preview mode
- ✅ `testFileMetadataPatternDetection` - Date, version, number patterns
- ✅ `testFileMetadataSiblingFiles` - Context extraction
- ✅ `testFileMetadataToJSON` - JSON serialization
- ✅ `testFileMetadataToDescription` - Human-readable format

#### ClassificationResult Tests
- ✅ `testClassificationResultCreation` - Basic creation
- ✅ `testClassificationResultCodable` - JSON encoding/decoding
- ✅ `testClassificationResultWithoutReasoning` - Optional reasoning

#### FallbackClassifier Tests
- ✅ `testFallbackClassifierBasic` - Basic classification
- ✅ `testFallbackClassifierPDF` - PDF classification
- ✅ `testFallbackClassifierImage` - Image classification
- ✅ `testFallbackClassifierVideo` - Video classification
- ✅ `testFallbackClassifierCode` - Code file classification
- ✅ `testFallbackClassifierBatch` - Batch processing

#### FileClassificationManager Tests
- ✅ `testFileClassificationManagerInitialization` - Manager setup
- ✅ `testFileClassificationManagerWithFallback` - Fallback mechanism
- ✅ `testFileClassificationManagerBatch` - Batch processing

#### AIClassifierMover Tests
- ✅ `testAIClassifierMoverInitialization` - Mover setup
- ✅ `testAIClassifierMoverWithEmptyFolder` - Empty folder handling
- ✅ `testAIClassifierMoverWithFiles` - File processing

#### Mock Classifier Tests
- ✅ `testMockClassifier` - Mock implementation testing

#### Integration Tests
- ✅ `testCompleteClassificationWorkflow` - End-to-end workflow

#### Error Handling Tests
- ✅ `testClassificationWithInvalidMetadata` - Invalid input handling

#### Performance Tests
- ✅ `testFallbackClassifierPerformance` - Single classification speed
- ✅ `testBatchClassificationPerformance` - Batch processing speed

### 2. AIClassificationIntegrationTests.swift
**Integration tests for complete workflows**

#### Complete Workflow Tests
- ✅ `testEndToEndClassificationWorkflow` - Full classification pipeline
- ✅ `testFileOrganizationWithAIClassifier` - File organization workflow

#### Classifier Selection Tests
- ✅ `testFileClassificationManagerFallbackChain` - Fallback mechanism
- ✅ `testFileClassificationManagerWithMultipleServices` - Multiple service support

#### Batch Processing Tests
- ✅ `testLargeBatchProcessing` - Performance with 50+ files

#### Error Recovery Tests
- ✅ `testClassificationWithMissingFiles` - Missing file handling

#### Data Consistency Tests
- ✅ `testMetadataConsistency` - Metadata extraction consistency
- ✅ `testClassificationConsistency` - Classification determinism

## Test Coverage

### Components Covered

| Component | Unit Tests | Integration Tests | Coverage |
|-----------|-----------|------------------|----------|
| FileMetadata | ✅ | ✅ | ~90% |
| ClassificationResult | ✅ | - | ~95% |
| FallbackClassifier | ✅ | ✅ | ~85% |
| FileClassificationManager | ✅ | ✅ | ~80% |
| AIClassifierMover | ✅ | ✅ | ~75% |
| OllamaLLMService | ⚠️ | ⚠️ | ~0%* |
| OpenAILLMService | ⚠️ | ⚠️ | ~0%* |

*Ollama and OpenAI classifiers require external services and are tested manually or with mocks.

### Test Categories

#### Unit Tests (Fast, Isolated)
- Component initialization
- Data extraction
- Classification logic
- Data serialization

#### Integration Tests (End-to-End)
- Complete workflows
- File system operations
- Batch processing
- Error recovery

#### Performance Tests
- Single operation speed
- Batch processing efficiency
- Memory usage
- Scalability

## Running Tests

### Run All Tests
```bash
swift test
```

### Run Specific Test File
```bash
swift test --filter AIClassificationTests
swift test --filter AIClassificationIntegrationTests
```

### Run Specific Test
```bash
swift test --filter AIClassificationTests.testFileMetadataExtraction
```

### Run Performance Tests
```bash
swift test --filter Performance
```

## Test Data

### Test Files Created
- PDF documents (invoices, reports, contracts)
- Images (JPG, PNG)
- Videos (MP4)
- Audio (MP3)
- Code files (Swift, Python)
- Archives (ZIP, TAR.GZ)

### Test Scenarios
- ✅ Normal files
- ✅ Files with special characters
- ✅ Files with dates/versions in names
- ✅ Empty folders
- ✅ Large batches (50+ files)
- ✅ Missing files
- ✅ Invalid metadata

## Mock Objects

### MockLLMClassifier
A test implementation of `LLMClassifier` protocol that:
- Always returns available
- Returns consistent classification results
- Useful for testing without external dependencies

## Test Helpers

### Temporary Directory Management
- Automatic cleanup after tests
- Isolated test environments
- UUID-based directories

### Test File Creation
- Helper methods for creating test files
- Various file types
- Configurable content

## Known Limitations

### External Dependencies
- **OllamaLLMService**: Requires Ollama server running
  - Manual testing recommended
  - Can be tested with integration tests if server available
  
- **OpenAIClassifier**: Requires API key and internet
  - Manual testing recommended
  - Mock testing for unit tests

### Test Environment
- Tests run in isolated temporary directories
- No impact on user files
- Automatic cleanup

## Future Test Additions

### Planned Tests
- [ ] OllamaLLMService unit tests (with mock server)
- [ ] OpenAILLMService unit tests (with mock API)
- [ ] Network error handling
- [ ] Rate limiting tests
- [ ] Concurrent classification tests
- [ ] UI component tests
- [ ] Accessibility tests

### Test Improvements
- [ ] Increase coverage to 90%+
- [ ] Add property-based testing
- [ ] Add snapshot testing for UI
- [ ] Add performance benchmarks
- [ ] Add memory leak detection

## Best Practices

### Writing Tests
1. **Arrange-Act-Assert** pattern
2. **Descriptive test names** - What is being tested
3. **Isolated tests** - No dependencies between tests
4. **Fast tests** - Unit tests should be < 1ms
5. **Clear assertions** - One concept per test

### Test Organization
- Group related tests with `// MARK:`
- Use helper methods for common setup
- Clean up resources in `tearDown`
- Use descriptive test names

### Test Data
- Use realistic test data
- Test edge cases
- Test error conditions
- Test performance boundaries

## Continuous Integration

### CI/CD Integration
Tests should run:
- On every commit
- Before merging PRs
- On release builds
- With code coverage reporting

### Coverage Goals
- **Unit Tests**: 80%+ coverage
- **Integration Tests**: Critical paths covered
- **Performance Tests**: All performance-critical code

---

**Last Updated:** 2024-12-20  
**Test Count:** 30+ tests  
**Coverage:** ~80% of AI classification code


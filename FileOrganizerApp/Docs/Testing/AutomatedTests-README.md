# FileOrganizerApp Test Suite

This directory contains comprehensive automated tests for the FileOrganizerApp functionality.

## Test Structure

### 1. FileOrganizerAppTests.swift
Core functionality tests covering:

#### KeywordEntry Tests
- **testKeywordEntryCreation**: Tests basic keyword entry creation
- **testKeywordEntryCodable**: Tests JSON encoding/decoding for persistence

#### KeywordStore Tests
- **testKeywordStoreInitialization**: Tests store initialization
- **testAddKeyword**: Tests adding single keywords
- **testAddMultipleKeywords**: Tests adding multiple keywords
- **testKeywordStorePersistence**: Tests data persistence across app sessions

#### FileMover Tests
- **testFileMoverInitialization**: Tests FileMover initialization
- **testFileMoverWithEmptyKeywords**: Tests behavior with no keywords
- **testFileMoverWithTestFiles**: Tests file processing with test files

#### iCloudFileManager Tests
- **testICloudFileManagerInitialization**: Tests manager initialization
- **testICloudFileManagerListFiles**: Tests file listing functionality

#### Data Structure Tests
- **testScannedKeywordCreation**: Tests ScannedKeyword creation
- **testScannedKeywordEquality**: Tests equality comparison
- **testScannedKeywordHashable**: Tests hashable functionality
- **testBulkKeywordEntryCreation**: Tests bulk entry creation
- **testKeywordTypeValues**: Tests enum values

#### Integration Tests
- **testCompleteWorkflow**: Tests end-to-end workflow

#### Performance Tests
- **testKeywordStorePerformance**: Tests keyword store performance
- **testFileMoverPerformance**: Tests file mover performance

#### Edge Case Tests
- **testEmptyKeyword**: Tests empty keyword handling
- **testSpecialCharactersInKeyword**: Tests special character handling
- **testUnicodeCharactersInKeyword**: Tests Unicode support
- **testLongKeyword**: Tests long keyword handling

#### Error Handling Tests
- **testFileMoverWithNonExistentDirectory**: Tests error handling
- **testKeywordStoreWithCorruptedData**: Tests corrupted data handling

### 2. UIComponentTests.swift
UI and view-related tests covering:

#### KeywordManagerView Logic Tests
- **testFilteredSuggestionsLogic**: Tests suggestion filtering
- **testExistingSubfoldersComputation**: Tests subfolder computation
- **testTreeStructureComputation**: Tests tree structure building

#### Focus Management Tests
- **testFocusFieldEnum**: Tests focus field enumeration

#### Data Structure Tests
- **testScannedKeywordDataStructure**: Tests data structure properties
- **testBulkKeywordEntryDataStructure**: Tests bulk entry structure

#### State Management Tests
- **testKeywordStoreObservableObject**: Tests ObservableObject compliance

#### File Operations Tests
- **testFileOperationsWithTemporaryDirectory**: Tests file operations

#### Performance Tests
- **testKeywordStorePerformance**: Tests store performance
- **testTreeStructureComputationPerformance**: Tests tree computation performance

#### Edge Case Tests
- **testEmptyKeywordStore**: Tests empty store behavior
- **testDuplicateKeywords**: Tests duplicate handling
- **testUnicodeSupport**: Tests Unicode support

#### Integration Tests
- **testCompleteKeywordManagementWorkflow**: Tests complete workflow

## Running Tests

### Using the Test Runner Script
```bash
./run_tests.sh
```

### Using Swift Package Manager
```bash
swift test
```

### Running Specific Tests
```bash
# Run only core functionality tests
swift test --filter FileOrganizerAppTests

# Run only UI component tests
swift test --filter UIComponentTests

# Run specific test method
swift test --filter testAddKeyword
```

## Test Coverage

The test suite covers:

### ✅ Core Functionality
- Keyword entry creation and management
- Data persistence and loading
- File moving and organization
- iCloud file management

### ✅ UI Components
- View logic and state management
- Focus management
- Tree structure computation
- Dropdown functionality

### ✅ Data Structures
- KeywordEntry model
- ScannedKeyword model
- BulkKeywordEntry model
- KeywordType enumeration

### ✅ Error Handling
- Corrupted data handling
- Non-existent directory handling
- Invalid input handling

### ✅ Performance
- Large dataset handling
- Tree structure computation performance
- File operations performance

### ✅ Edge Cases
- Empty data sets
- Special characters
- Unicode support
- Long inputs
- Duplicate entries

### ✅ Integration
- End-to-end workflows
- Complete user scenarios
- Cross-component interactions

## Test Environment

- **Platform**: macOS 14+
- **Framework**: XCTest
- **Language**: Swift
- **Dependencies**: SwiftUI, AppKit, Foundation

## Test Data

Tests use temporary directories and files to avoid affecting the user's actual data:
- Temporary test directories are created and cleaned up automatically
- Test files are created with controlled content
- No permanent changes are made to the user's system

## Continuous Integration

The test suite is designed to run in CI/CD environments:
- No external dependencies
- Self-contained test data
- Automatic cleanup
- Clear pass/fail reporting

## Adding New Tests

When adding new functionality, follow these guidelines:

1. **Test the core logic** in FileOrganizerAppTests.swift
2. **Test UI components** in UIComponentTests.swift
3. **Include edge cases** and error handling
4. **Add performance tests** for computationally intensive operations
5. **Test integration** with existing components
6. **Use descriptive test names** that explain what is being tested
7. **Include setup and teardown** for proper test isolation

## Test Best Practices

- Each test should be independent
- Use descriptive test names
- Test both success and failure cases
- Include performance tests for critical operations
- Clean up resources in tearDown
- Use temporary directories for file operations
- Test edge cases and error conditions 
#!/bin/bash

# FileOrganizerApp Test Runner
# This script runs all automated tests for the FileOrganizerApp

echo "🧪 Running FileOrganizerApp Tests..."
echo "=================================="

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Package.swift not found. Please run this script from the project root directory."
    exit 1
fi

# Clean build directory
echo "🧹 Cleaning build directory..."
rm -rf .build

# Run tests
echo "🚀 Running tests..."
swift test

# Check if tests passed
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ All tests passed!"
    echo ""
    echo "📊 Test Summary:"
    echo "   - Core functionality tests"
    echo "   - UI component tests"
    echo "   - Performance tests"
    echo "   - Edge case tests"
    echo "   - Integration tests"
else
    echo ""
    echo "❌ Some tests failed. Please check the output above."
    exit 1
fi

echo ""
echo "🎉 Test run completed!" 
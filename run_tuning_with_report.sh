#!/bin/bash

# Script to run tuning tests and generate HTML report using xctesthtmlreport

echo "🧪 Running Classifier Tuning Tests..."
echo "=================================="
echo ""

# Run the tuning test
swift test --filter QuickTuningTest.testQuickTuning

# Check if test results exist
if [ ! -d ".build/test-results" ]; then
    echo "⚠️  No test results found. Make sure tests ran successfully."
    exit 1
fi

echo ""
echo "📊 Generating HTML Report..."
echo ""

# Generate HTML report
xchtmlreport -r .build/test-results -o tuning-reports

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Report generated successfully!"
    echo "📄 Report location: tuning-reports/index.html"
    echo ""
    
    # Check if we're on macOS and can open the report
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "🌐 Opening report in browser..."
        open tuning-reports/index.html
    else
        echo "📄 Open tuning-reports/index.html in your browser"
    fi
else
    echo "❌ Failed to generate report"
    echo "   Make sure xctesthtmlreport is installed: brew install xctesthtmlreport"
    exit 1
fi


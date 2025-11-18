# XCTest HTML Report Setup

## 📊 Using XCTest HTML Report (Allure-like for Swift)

`xctesthtmlreport` generates beautiful HTML reports from XCTest output, similar to Allure.

## 🚀 Installation

```bash
brew install xctesthtmlreport
```

## 📝 Usage

### Option 1: Run Tests and Generate Report

```bash
# Run tests and generate HTML report
xchtmlreport -r .build/test-results -o reports

# Or with custom paths
xchtmlreport -r /path/to/test-results -o /path/to/reports
```

### Option 2: Run Tests with Report Generation

```bash
# Run tests and pipe to xchtmlreport
swift test 2>&1 | xchtmlreport -r .build/test-results -o reports
```

### Option 3: Generate Report from Existing Test Results

If you've already run tests:

```bash
# Generate report from existing results
xchtmlreport -r .build/test-results -o reports
```

## 🎯 For Tuning Tests

### Run Tuning Test with Report

```bash
# Run the tuning test
swift test --filter QuickTuningTest.testQuickTuning

# Generate HTML report
xchtmlreport -r .build/test-results -o tuning-reports

# Open the report
open tuning-reports/index.html
```

### Automated Script

Create a script `run_tuning_with_report.sh`:

```bash
#!/bin/bash

echo "🧪 Running Tuning Tests..."
swift test --filter QuickTuningTest.testQuickTuning

echo "📊 Generating HTML Report..."
xchtmlreport -r .build/test-results -o tuning-reports

echo "✅ Report generated: tuning-reports/index.html"
echo "📄 Opening report..."
open tuning-reports/index.html
```

Make it executable:
```bash
chmod +x run_tuning_with_report.sh
```

Then run:
```bash
./run_tuning_with_report.sh
```

## 📋 Report Features

The generated HTML report includes:
- ✅ Test execution summary
- ✅ Pass/fail statistics
- ✅ Test duration
- ✅ Console output
- ✅ Test results breakdown
- ✅ Beautiful visualizations

## 🔧 Configuration

### Custom Output Directory

```bash
xchtmlreport -r .build/test-results -o my-reports
```

### Include Console Output

```bash
xchtmlreport -r .build/test-results -o reports --include-console-output
```

### Generate JSON Report

```bash
xchtmlreport -r .build/test-results -o reports --json
```

## 📚 More Information

- GitHub: https://github.com/TitouanVanBelle/XCTestHTMLReport
- Documentation: Check `xchtmlreport --help`

---

**Note:** Make sure to run `swift test` first to generate test results, then use `xchtmlreport` to generate the HTML report.


#!/bin/bash
set -euo pipefail

# FileOrganizerApp Test Runner with Allure Report
# Runs tests via xcodebuild (for .xcresult + step support) and generates an Allure HTML report.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

RESULT_BUNDLE="$PROJECT_ROOT/TestResults/TestResults.xcresult"
ALLURE_OUTPUT="$PROJECT_ROOT/allure-report"
WORKSPACE="$PROJECT_ROOT/.swiftpm/xcode/package.xcworkspace"
SCHEME="FileOrganizerApp"
FILTER=""
OPEN_REPORT=false
CLEAN_BUILD=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Runs FileOrganizerApp tests and generates an Allure HTML report with step-level detail.

Options:
  --filter <pattern>   Run only tests matching the pattern (xcodebuild -only-testing)
  --open               Open the Allure report in the default browser after generation
  --clean              Remove DerivedData and previous TestResults before running
  --output <dir>       Allure report output directory (default: allure-report)
  -h, --help           Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --filter FileOrganizerAppTests/testCompleteWorkflow --open
  $(basename "$0") --filter AIClassificationIntegrationTests

Requirements:
  - Xcode (full install, not just Command Line Tools)
  - Node.js/npm (for npx allure)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --filter)
            FILTER="$2"
            shift 2
            ;;
        --open)
            OPEN_REPORT=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --output)
            ALLURE_OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [ ! -f "Package.swift" ]; then
    echo "Error: Package.swift not found. Run this script from the project root or via FileOrganizerApp/scripts/." >&2
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "Error: xcodebuild not found. Install Xcode to generate Allure reports with test steps." >&2
    exit 1
fi

if [ ! -d "$WORKSPACE" ]; then
    echo "Generating SwiftPM Xcode workspace..."
    swift package resolve
fi

if [ "$CLEAN_BUILD" = true ]; then
    echo "Cleaning previous test results..."
    rm -rf "$PROJECT_ROOT/TestResults" "$ALLURE_OUTPUT"
fi

mkdir -p "$PROJECT_ROOT/TestResults"
rm -rf "$RESULT_BUNDLE"
rm -rf "$ALLURE_OUTPUT"

if [ ! -f "$PROJECT_ROOT/package.json" ]; then
    echo "Installing Allure CLI (npm)..."
    npm install --save-dev allure
fi

echo "Running FileOrganizerApp tests..."
echo "================================="

XCODEBUILD_ARGS=(
    test
    -workspace "$WORKSPACE"
    -scheme "$SCHEME"
    -destination "platform=macOS"
    -resultBundlePath "$RESULT_BUNDLE"
)

if [ -n "$FILTER" ]; then
    if [[ "$FILTER" == FileOrganizerAppTests/* ]]; then
        XCODEBUILD_ARGS+=(-only-testing:"$FILTER")
    else
        XCODEBUILD_ARGS+=(-only-testing:"FileOrganizerAppTests/$FILTER")
    fi
fi

set +e
xcodebuild "${XCODEBUILD_ARGS[@]}"
TEST_EXIT=$?
set -e

if [ ! -d "$RESULT_BUNDLE" ]; then
    echo "Error: Test result bundle was not created at $RESULT_BUNDLE" >&2
    exit "${TEST_EXIT:-1}"
fi

echo ""
echo "Generating Allure report..."
npx allure generate "$RESULT_BUNDLE" -o "$ALLURE_OUTPUT"

# Verify the report contains test data
TEST_COUNT=$(python3 -c "import json; print(json.load(open('$ALLURE_OUTPUT/summary.json'))['stats']['total'])" 2>/dev/null || echo "0")
if [ "$TEST_COUNT" = "0" ]; then
    echo ""
    echo "Warning: Allure report has 0 tests." >&2
    echo "  xcresult tests: $(xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('totalTestCount',0))" 2>/dev/null || echo '?')" >&2
    echo "  If you used --filter, use: ClassName/testMethod (not FileOrganizerAppTests/...)" >&2
fi

echo ""
echo "Allure report: $ALLURE_OUTPUT/index.html ($TEST_COUNT tests)"
echo "Test results:  $RESULT_BUNDLE"
echo ""
echo "Open the report (do not open index.html directly — use the server):"
echo "  npx allure open $ALLURE_OUTPUT"

if [ "$OPEN_REPORT" = true ]; then
    npx allure open "$ALLURE_OUTPUT"
fi

exit "$TEST_EXIT"

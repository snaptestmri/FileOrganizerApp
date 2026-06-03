#!/bin/bash
set -euo pipefail

# Regenerate Allure HTML report from an existing .xcresult bundle (no test re-run).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

RESULT_BUNDLE="${1:-$PROJECT_ROOT/TestResults/TestResults.xcresult}"
ALLURE_OUTPUT="${2:-$PROJECT_ROOT/allure-report}"

if [ ! -d "$RESULT_BUNDLE" ]; then
    echo "Error: xcresult bundle not found: $RESULT_BUNDLE" >&2
    echo "Run tests first: ./FileOrganizerApp/scripts/run_tests_with_allure.sh" >&2
    exit 1
fi

TOTAL=$(xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('totalTestCount',0))" 2>/dev/null || echo "0")
echo "Regenerating Allure report from $TOTAL test(s) in xcresult..."

rm -rf "$ALLURE_OUTPUT"
npx allure generate "$RESULT_BUNDLE" -o "$ALLURE_OUTPUT"

TEST_COUNT=$(python3 -c "import json; print(json.load(open('$ALLURE_OUTPUT/summary.json'))['stats']['total'])" 2>/dev/null || echo "0")
echo "Done: $ALLURE_OUTPUT ($TEST_COUNT tests in report)"
echo "Open with: npx allure open $ALLURE_OUTPUT"

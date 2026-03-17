#!/bin/bash
# Automated UI test loop: run tests, capture results, write report, surface feedback.
# Usage: from repo root, ./scripts/run-ui-tests-and-report.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/ios/BarrioCursor/BarrioCursor"
RESULTS_DIR="$REPO_ROOT/ios/test-results"
LOG_FILE="$RESULTS_DIR/latest-run.log"
REPORT_FILE="$RESULTS_DIR/latest-report.md"
RESULT_BUNDLE="$RESULTS_DIR/TestResults.xcresult"

# Default: run all BarrioCursorUITests. Override with -only-testing for a single class.
ONLY_TESTING="${ONLY_TESTING:-BarrioCursorUITests}"
DESTINATION="platform=iOS Simulator,name=iPhone 17,OS=26.2"

mkdir -p "$RESULTS_DIR"
# xcodebuild refuses to run if -resultBundlePath already exists
rm -rf "$RESULT_BUNDLE"

# Kill any stale test runner (reduces bootstrap crashes)
pkill -f BarrioCursorUITests-Runner 2>/dev/null || true
sleep 1

echo "🧪 portal. — Automated UI test run"
echo "==================================="
echo ""

# 1) Boot simulator and wait until ready (fixes "signal kill before establishing connection")
echo "📱 Ensuring simulator is booted..."
DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone 17 " | grep -v Pro | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
if [[ -n "$DEVICE_ID" ]]; then
    if xcrun simctl bootstatus "$DEVICE_ID" -b 2>/dev/null; then
        sleep 2
    else
        xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
        sleep 5
    fi
    open -a Simulator 2>/dev/null || true
    sleep 2
    DESTINATION="platform=iOS Simulator,id=$DEVICE_ID"
fi
echo "   Destination: $DESTINATION"
echo ""

# 2) Run tests with retry on bootstrap crash
echo "🚀 Running UI tests (this may take several minutes)..."
cd "$PROJECT_DIR"
EXIT_CODE=1
for attempt in 1 2 3; do
    if [[ $attempt -gt 1 ]]; then
        echo "   Retry $attempt/3 (bootstrap crash?) — rebooting simulator..."
        xcrun simctl shutdown "$DEVICE_ID" 2>/dev/null || true
        sleep 2
        xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
        sleep 5
        open -a Simulator 2>/dev/null || true
        sleep 2
        pkill -f BarrioCursorUITests-Runner 2>/dev/null || true
        sleep 1
        rm -rf "$RESULT_BUNDLE"
    fi
    set +e
    xcodebuild test \
      -scheme BarrioCursor \
      -destination "$DESTINATION" \
      -only-testing:"$ONLY_TESTING" \
      -resultBundlePath "$RESULT_BUNDLE" \
      2>&1 | tee "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
    set -e
    if [[ $EXIT_CODE -eq 0 ]]; then break; fi
    if ! grep -q "signal kill before establishing connection\|signal abrt while preparing to run\|operation never finished bootstrapping" "$LOG_FILE" 2>/dev/null; then break; fi
done
echo ""

# 3) Inspect run and build report
BUILD_FAILED=false
TEST_FAILED=false
BOOTSTRAP_KILL=false
ERROR_MSG=""

if grep -q "error:" "$LOG_FILE" 2>/dev/null; then
    BUILD_FAILED=true
    ERROR_MSG=$(grep "error:" "$LOG_FILE" | head -5)
fi
if grep -q "Testing failed" "$LOG_FILE" 2>/dev/null; then
    TEST_FAILED=true
fi
if grep -q "signal kill before establishing connection\|signal abrt while preparing to run" "$LOG_FILE" 2>/dev/null; then
    BOOTSTRAP_KILL=true
fi

# 4) Write report
{
    echo "# UI test run report"
    echo ""
    echo "**Generated:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "## Summary"
    echo ""
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "- **Result:** ✅ All tests passed"
    else
        echo "- **Result:** ❌ Failed (exit code $EXIT_CODE)"
    fi
    echo "- **Log:** \`ios/test-results/latest-run.log\`"
    echo "- **Result bundle:** \`ios/test-results/TestResults.xcresult\` (open in Xcode for details)"
    echo ""
    echo "## Details"
    echo ""
    if $BUILD_FAILED; then
        echo "### Build failure"
        echo "The app or test target did not compile."
        echo '```'
        echo "$ERROR_MSG"
        echo '```'
        echo ""
    fi
    if $TEST_FAILED; then
        echo "### Test run failure"
        if $BOOTSTRAP_KILL; then
            echo "The test runner crashed or was killed before/during test startup (e.g. bootstrap timeout or signal abrt)."
            echo ""
            echo "**Recommended actions:**"
            echo "1. Boot the simulator before running: open Simulator, or run \`xcrun simctl boot <device-id>\`."
            echo "2. Run from Xcode (Product → Test) and check the report navigator for crash logs."
            echo "3. Run a smaller subset: \`ONLY_TESTING=BarrioCursorUITests/SmokeTest ./scripts/run-ui-tests-and-report.sh\`."
        else
            echo "One or more tests failed. Check the log and result bundle for failing test names."
        fi
        echo ""
    fi
    echo "## Last 30 lines of log"
    echo '```'
    tail -30 "$LOG_FILE"
    echo '```'
} > "$REPORT_FILE"

echo "📄 Report written to: $REPORT_FILE"
echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ Done. All tests passed."
else
    echo "❌ Done. Tests failed. See $REPORT_FILE for feedback and next steps."
fi
exit $EXIT_CODE

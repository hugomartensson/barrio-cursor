#!/bin/bash
# One-command UI test runner for portal. (BarrioCursor)
# Runs BarrioCursorUITests in the iOS Simulator.

set -e

echo "🧪 portal. — UI Test Runner"
echo "==========================="
echo ""

# Check if xcode-select is configured
CURRENT_PATH=$(xcode-select -p 2>&1)
if [[ "$CURRENT_PATH" == *"CommandLineTools"* ]] || [[ "$CURRENT_PATH" == *"error"* ]]; then
    echo "⚠️  xcode-select needs to be configured"
    echo ""
    echo "Please run:"
    echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    echo ""
    echo "Then run this script again: ./START-TESTING.sh"
    exit 1
fi

echo "✅ xcode-select: $CURRENT_PATH"

# Verify xcodebuild
if ! xcodebuild -version > /dev/null 2>&1; then
    echo "❌ xcodebuild not found or not working"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo "✅ $XCODE_VERSION"
echo ""

# Project paths (from repo root)
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$REPO_ROOT/ios/BarrioCursor/BarrioCursor"

# Simulator: use bootstatus -b so simulator is fully ready (avoids "signal kill before establishing connection")
DESTINATION="platform=iOS Simulator,name=iPhone 17,OS=26.2"
DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone 17 " | grep -v Pro | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
if [[ -n "$DEVICE_ID" ]]; then
    echo "📱 Booting simulator $DEVICE_ID (waiting for ready)..."
    if xcrun simctl bootstatus "$DEVICE_ID" -b 2>/dev/null; then
        sleep 2
    else
        xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
        sleep 5
    fi
    open -a Simulator 2>/dev/null || true
    sleep 1
    DESTINATION="platform=iOS Simulator,id=$DEVICE_ID"
fi
if ! xcodebuild -version -sdk iphonesimulator 2>/dev/null | grep -q "SDKVersion"; then
    echo "⚠️  Could not verify simulator SDK; trying default destination."
fi

echo "📱 Destination: $DESTINATION"
echo "📂 Project: $PROJECT_DIR"
echo ""
echo "For more reliable runs (one class at a time, retry on crash): ./scripts/run-tests-resilient.sh --group 4"
echo ""
echo "🚀 Running BarrioCursor UI tests..."
echo ""

cd "$PROJECT_DIR"
xcodebuild test \
  -scheme BarrioCursor \
  -destination "$DESTINATION" \
  -only-testing:BarrioCursorUITests

EXIT_CODE=$?
echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ UI tests finished successfully."
else
    echo "❌ UI tests failed (exit code $EXIT_CODE)."
fi
exit $EXIT_CODE

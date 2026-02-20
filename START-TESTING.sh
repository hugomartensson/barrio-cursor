#!/bin/bash
# One-command test runner - handles setup and runs tests

echo "🧪 Concept G: Editorial Minimalism - Test Runner"
echo "=================================================="
echo ""

# Check if xcode-select is configured
CURRENT_PATH=$(xcode-select -p 2>&1)

if [[ "$CURRENT_PATH" == *"CommandLineTools"* ]] || [[ "$CURRENT_PATH" == *"error"* ]]; then
    echo "⚠️  xcode-select needs to be configured"
    echo ""
    echo "Please run this command (will prompt for password):"
    echo ""
    echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    echo ""
    echo "After running that command, run this script again:"
    echo "  ./START-TESTING.sh"
    echo ""
    exit 1
fi

echo "✅ xcode-select configured: $CURRENT_PATH"
echo ""

# Verify xcodebuild
if ! xcodebuild -version > /dev/null 2>&1; then
    echo "❌ xcodebuild not working"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo "✅ $XCODE_VERSION"
echo ""

# Run the test suite
echo "🚀 Starting automated tests..."
echo ""

cd "$(dirname "$0")"
./run-concept-g-tests.sh

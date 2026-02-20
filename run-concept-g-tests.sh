#!/bin/bash
# Automated test runner for Concept G - runs tests and processes results

set -e

echo "🧪 Concept G: Editorial Minimalism - Automated Testing"
echo "======================================================"
echo ""

# Check xcode-select
CURRENT_PATH=$(xcode-select -p)
if [[ "$CURRENT_PATH" == *"CommandLineTools"* ]]; then
    echo "❌ xcode-select is not configured for Xcode"
    echo ""
    echo "Please run this command first:"
    echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✅ xcode-select configured: $CURRENT_PATH"
echo ""

# Verify xcodebuild works
if ! xcodebuild -version > /dev/null 2>&1; then
    echo "❌ xcodebuild not working. Please check Xcode installation."
    exit 1
fi

echo "✅ xcodebuild verified"
echo ""

# Run tests
echo "🚀 Running automated tests..."
echo ""

cd ios/BarrioCursorUITests
./run-tests.sh

TEST_EXIT_CODE=$?

echo ""
echo "======================================================"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "⚠️  Some tests failed. Reports generated."
    echo ""
    echo "📊 Review reports in: ios/test-reports/LATEST/"
    echo "📄 AI report: ios/test-reports/LATEST/ai-report.json"
fi

exit $TEST_EXIT_CODE

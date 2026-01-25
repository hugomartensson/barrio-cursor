#!/bin/bash

# Automated UI Test Runner for Barrio
# Runs all UI tests, generates reports, and prepares them for AI consumption

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="$PROJECT_DIR/test-reports"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_DIR="$REPORTS_DIR/$TIMESTAMP"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🧪 Barrio UI Test Runner${NC}"
echo "=================================="
echo ""

# Create reports directory
mkdir -p "$REPORT_DIR"

# Build and run tests
echo -e "${YELLOW}📦 Building test target...${NC}"
xcodebuild test \
    -project "$PROJECT_DIR/BarrioCursor.xcodeproj" \
    -scheme BarrioCursor \
    -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
    -only-testing:BarrioCursorUITests \
    -resultBundlePath "$REPORT_DIR/TestResults.xcresult" \
    2>&1 | tee "$REPORT_DIR/build.log"

# Check if tests passed
TEST_EXIT_CODE=${PIPESTATUS[0]}

# Extract test results
echo ""
echo -e "${YELLOW}📊 Extracting test results...${NC}"

# Use xcresulttool to extract test summary
xcrun xcresulttool get --format json --path "$REPORT_DIR/TestResults.xcresult" > "$REPORT_DIR/results.json" 2>/dev/null || true

# Find all test reports in temp directory
TEMP_DIR=$(getconf DARWIN_USER_TEMP_DIR)
TEST_DIRS=$(find "$TEMP_DIR/BarrioUITests" -type d -name "*_*" -maxdepth 1 2>/dev/null | sort -r | head -20)

if [ -z "$TEST_DIRS" ]; then
    echo -e "${RED}⚠️  No test artifact directories found${NC}"
else
    echo -e "${GREEN}✅ Found test artifacts${NC}"
    
    # Copy latest test reports
    LATEST_DIR=$(echo "$TEST_DIRS" | head -1)
    if [ -n "$LATEST_DIR" ]; then
        cp -r "$LATEST_DIR"/* "$REPORT_DIR/" 2>/dev/null || true
        echo "   Copied artifacts from: $(basename "$LATEST_DIR")"
    fi
fi

# Generate summary report
echo ""
echo -e "${YELLOW}📝 Generating summary report...${NC}"

SUMMARY_FILE="$REPORT_DIR/SUMMARY.md"
cat > "$SUMMARY_FILE" << EOF
# Test Run Summary

**Timestamp:** $TIMESTAMP  
**Status:** $([ $TEST_EXIT_CODE -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")  
**Exit Code:** $TEST_EXIT_CODE

## Test Results

$(if [ -f "$REPORT_DIR/results.json" ]; then
    # Try to extract test counts from results.json
    PASSED=$(grep -o '"status":"success"' "$REPORT_DIR/results.json" | wc -l | tr -d ' ')
    FAILED=$(grep -o '"status":"failure"' "$REPORT_DIR/results.json" | wc -l | tr -d ' ')
    echo "- **Passed:** $PASSED"
    echo "- **Failed:** $FAILED"
else
    echo "- Results extraction failed"
fi)

## Artifacts

- **Test Results:** \`TestResults.xcresult\`
- **Build Log:** \`build.log\`
- **Test Reports:** \`test_report.json\` and \`test_report.md\` (if available)
- **Screenshots:** \`screenshots/\` directory

## Next Steps

1. Review test reports in this directory
2. Check screenshots for visual issues
3. Review build log for errors
4. Fix issues and re-run tests

EOF

echo "   Summary saved to: $SUMMARY_FILE"

# Generate AI-consumable report
echo ""
echo -e "${YELLOW}🤖 Generating AI-consumable report...${NC}"

AI_REPORT="$REPORT_DIR/ai-report.json"

# Collect all test reports
cat > "$AI_REPORT" << EOF
{
  "testRun": {
    "timestamp": "$TIMESTAMP",
    "status": "$([ $TEST_EXIT_CODE -eq 0 ] && echo "passed" || echo "failed")",
    "exitCode": $TEST_EXIT_CODE
  },
  "reports": []
}
EOF

# Find and include individual test reports
for test_dir in $TEST_DIRS; do
    if [ -f "$test_dir/test_report.json" ]; then
        # Merge test report into AI report
        python3 << PYTHON_SCRIPT
import json
import sys

try:
    with open("$AI_REPORT", "r") as f:
        ai_report = json.load(f)
    
    with open("$test_dir/test_report.json", "r") as f:
        test_report = json.load(f)
    
    ai_report["reports"].append(test_report)
    
    with open("$AI_REPORT", "w") as f:
        json.dump(ai_report, f, indent=2)
except Exception as e:
    print(f"Error merging report: {e}", file=sys.stderr)
PYTHON_SCRIPT
    fi
done

echo "   AI report saved to: $AI_REPORT"

# Print summary
echo ""
echo -e "${GREEN}==================================${NC}"
echo -e "${GREEN}✅ Test run complete!${NC}"
echo ""
echo "📁 Reports saved to: $REPORT_DIR"
echo ""
echo "Key files:"
echo "  - $SUMMARY_FILE"
echo "  - $AI_REPORT"
echo "  - $REPORT_DIR/TestResults.xcresult"
echo ""

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Review reports above.${NC}"
    exit 1
fi

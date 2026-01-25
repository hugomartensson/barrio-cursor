#!/bin/bash

# Automated Feedback Loop for Barrio UI Tests
# Runs tests → generates reports → waits for fixes → re-runs automatically

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAX_ITERATIONS=${MAX_ITERATIONS:-10}  # Max number of test-fix cycles
ITERATION=0

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 Barrio Automated Feedback Loop${NC}"
echo "======================================"
echo ""
echo "This script will:"
echo "  1. Run UI tests"
echo "  2. Generate reports"
echo "  3. Wait for code changes"
echo "  4. Re-run tests automatically"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Function to run tests
run_tests() {
    local iteration=$1
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🧪 Iteration $iteration: Running Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    "$SCRIPT_DIR/run-tests.sh"
    return $?
}

# Function to check for code changes
check_for_changes() {
    local last_check=$1
    local current_time=$(date +%s)
    
    # Check git status for changes
    if command -v git &> /dev/null; then
        cd "$PROJECT_DIR"
        git diff --quiet || return 0  # Changes detected
        git diff --cached --quiet || return 0  # Staged changes
    fi
    
    # Check file modification times in source directories
    find "$PROJECT_DIR/BarrioCursor" -type f \( -name "*.swift" -o -name "*.swiftui" \) -newermt "@$last_check" 2>/dev/null | grep -q . && return 0
    
    return 1  # No changes
}

# Function to wait for changes
wait_for_changes() {
    echo ""
    echo -e "${BLUE}⏳ Waiting for code changes...${NC}"
    echo "   (Monitoring: Swift files, git changes)"
    echo ""
    
    local last_check=$(date +%s)
    local check_interval=5  # Check every 5 seconds
    local timeout=300  # 5 minutes timeout
    
    while [ $(($(date +%s) - last_check)) -lt $timeout ]; do
        if check_for_changes $last_check; then
            echo -e "${GREEN}✅ Changes detected!${NC}"
            sleep 2  # Give a moment for files to finish saving
            return 0
        fi
        sleep $check_interval
        echo -n "."
    done
    
    echo ""
    echo -e "${YELLOW}⏰ Timeout reached (5 minutes)${NC}"
    return 1
}

# Main loop
LAST_STATUS=1  # Start with failure to run initial test

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))
    
    # Run tests
    run_tests $ITERATION
    TEST_STATUS=$?
    LAST_STATUS=$TEST_STATUS
    
    if [ $TEST_STATUS -eq 0 ]; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ All tests passed!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "🎉 Success! Tests are passing."
        echo ""
        echo "The feedback loop will continue monitoring for changes."
        echo "Press Ctrl+C to stop."
        echo ""
    else
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ Tests failed${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "📋 Review the test reports above to identify issues."
        echo "💡 Fix the issues in your code, then this script will automatically re-run tests."
        echo ""
    fi
    
    # Wait for changes before next iteration
    if [ $ITERATION -lt $MAX_ITERATIONS ]; then
        if ! wait_for_changes; then
            echo ""
            echo -e "${YELLOW}No changes detected. Exiting feedback loop.${NC}"
            break
        fi
        echo ""
        echo -e "${BLUE}🔄 Changes detected - restarting test cycle...${NC}"
        echo ""
    fi
done

if [ $ITERATION -ge $MAX_ITERATIONS ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Maximum iterations ($MAX_ITERATIONS) reached${NC}"
fi

echo ""
echo -e "${BLUE}👋 Feedback loop ended${NC}"
echo "Final status: $([ $LAST_STATUS -eq 0 ] && echo -e "${GREEN}✅ PASSED${NC}" || echo -e "${RED}❌ FAILED${NC}")"

exit $LAST_STATUS

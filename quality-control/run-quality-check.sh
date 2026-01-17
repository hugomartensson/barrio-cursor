#!/bin/bash

# Quality Control Agent Runner Script
# This script runs the quality agent and handles output

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "🔍 Running Quality Control Agent..."
echo ""

# Check if tsx is available, use npx as fallback
if command -v tsx &> /dev/null; then
    RUNNER="tsx"
elif command -v npx &> /dev/null; then
    RUNNER="npx tsx"
    echo "ℹ️  Using npx to run tsx..."
else
    echo "❌ Error: Neither tsx nor npx is available"
    echo "   Make sure Node.js is installed and in your PATH"
    exit 1
fi

# Run the quality agent
$RUNNER quality-control/quality-agent.ts

# Capture exit code
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Quality check passed!"
else
    echo ""
    echo "❌ Quality check found issues. Review the report above."
fi

exit $EXIT_CODE
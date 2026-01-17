#!/bin/bash

# Quality Control Agent Watcher
# Runs the quality agent continuously (every N seconds)

INTERVAL=${1:-30}  # Default: 30 seconds

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "👀 Quality Control Agent Watcher"
echo "   Running every $INTERVAL seconds"
echo "   Press Ctrl+C to stop"
echo ""

# Determine runner command (tsx or npx tsx)
if command -v tsx &> /dev/null; then
    RUNNER="tsx"
elif command -v npx &> /dev/null; then
    RUNNER="npx tsx"
else
    echo "❌ Error: Neither tsx nor npx is available"
    echo "   Make sure Node.js is installed and in your PATH"
    exit 1
fi

# Check if watch is available (macOS/Unix)
if command -v watch &> /dev/null; then
    watch -n "$INTERVAL" $RUNNER quality-control/quality-agent.ts
else
    # Fallback: manual loop
    while true; do
        clear
        echo "🕐 $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        $RUNNER quality-control/quality-agent.ts
        sleep "$INTERVAL"
    done
fi
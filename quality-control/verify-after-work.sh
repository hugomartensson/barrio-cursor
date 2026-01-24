#!/bin/bash

# Automated Quality Control - Run After Major Work
# 
# This script runs comprehensive quality checks after completing major features.
# It verifies:
# 1. What was promised → What was delivered
# 2. Features are complete (not partial)
# 3. Everything works as intended
#
# Usage:
#   ./quality-control/verify-after-work.sh        # Tier 2 (full backend) [default]
#   ./quality-control/verify-after-work.sh 1      # Tier 1 (quick check)
#   ./quality-control/verify-after-work.sh 3      # Tier 3 (deep check)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIER="${1:-2}"

cd "$PROJECT_ROOT"

# Use tsx or npx tsx so it works in CI and git hooks where tsx may not be on PATH
if command -v tsx &> /dev/null; then
  RUNNER="tsx"
else
  RUNNER="npx tsx"
  [ -t 1 ] && echo "ℹ️  Using npx to run tsx..."
fi

echo "🚀 Running Automated Quality Control (Tier $TIER)..."
echo ""

# Run the combined verification process (writes quality-control-report.txt)
$RUNNER "$SCRIPT_DIR/auto-verify.ts" --tier="$TIER"

echo ""
echo "✅ Quality control complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Review quality-control-report.txt"
echo "   2. If issues found, copy error messages to AI assistant"
echo "   3. Fix issues before continuing"
echo ""

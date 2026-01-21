#!/bin/bash

# Setup Git Hooks for Quality Control Agent
# This script sets up git hooks to run the quality agent automatically

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

cd "$PROJECT_ROOT"

# Check if git repo exists
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository"
    echo "   Initialize git with: git init"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

# Pre-commit hook (optional - can block commits if quality fails)
echo "Setting up pre-commit hook (optional)..."
cat > "$GIT_HOOKS_DIR/pre-commit-quality" << 'EOF'
#!/bin/sh
# Quality Control - Pre-commit Hook (Optional)
# Uncomment the line below to enable blocking commits on quality failures.
# Uses Tier 2 (full backend verification) before allowing commit.
#
# cd "$(git rev-parse --show-toplevel)" && ./quality-control/verify-after-work.sh 2 || exit 1
EOF

chmod +x "$GIT_HOOKS_DIR/pre-commit-quality"

# Post-commit hook (always runs, generates quick report)
echo "Setting up post-commit hook..."
cat > "$GIT_HOOKS_DIR/post-commit-quality" << 'EOF'
#!/bin/sh
# Quality Control - Post-commit Hook
# Runs Tier 1 (quick check) after each commit and writes a report.
cd "$(git rev-parse --show-toplevel)" && ./quality-control/verify-after-work.sh 1 > quality-control-report.txt 2>&1 || true
EOF

chmod +x "$GIT_HOOKS_DIR/post-commit-quality"

# Add to existing hooks if they exist
if [ -f "$GIT_HOOKS_DIR/pre-commit" ]; then
    if ! grep -q "pre-commit-quality" "$GIT_HOOKS_DIR/pre-commit"; then
        echo "" >> "$GIT_HOOKS_DIR/pre-commit"
        echo "# Quality Control Agent" >> "$GIT_HOOKS_DIR/pre-commit"
        echo ".git/hooks/pre-commit-quality" >> "$GIT_HOOKS_DIR/pre-commit"
    fi
else
    # Create basic pre-commit if it doesn't exist
    cat > "$GIT_HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/sh
# Quality Control Agent (optional - uncomment to enable)
# .git/hooks/pre-commit-quality
EOF
    chmod +x "$GIT_HOOKS_DIR/pre-commit"
fi

if [ -f "$GIT_HOOKS_DIR/post-commit" ]; then
    if ! grep -q "post-commit-quality" "$GIT_HOOKS_DIR/post-commit"; then
        echo "" >> "$GIT_HOOKS_DIR/post-commit"
        echo "# Quality Control Agent" >> "$GIT_HOOKS_DIR/post-commit"
        echo ".git/hooks/post-commit-quality" >> "$GIT_HOOKS_DIR/post-commit"
    fi
else
    # Create basic post-commit if it doesn't exist
    cat > "$GIT_HOOKS_DIR/post-commit" << 'EOF'
#!/bin/sh
# Quality Control Agent
.git/hooks/post-commit-quality
EOF
    chmod +x "$GIT_HOOKS_DIR/post-commit"
fi

echo ""
echo "✅ Git hooks set up successfully!"
echo ""
echo "📝 Hooks installed:"
echo "   • .git/hooks/pre-commit-quality (optional - Tier 2, currently disabled)"
echo "   • .git/hooks/post-commit-quality (active - Tier 1 after each commit)"
echo ""
echo "💡 To enable pre-commit blocking (blocks commits on quality failures):"
echo "   1. Edit .git/hooks/pre-commit-quality"
echo "   2. Uncomment the verify-after-work.sh line"
echo ""
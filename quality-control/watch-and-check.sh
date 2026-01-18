#!/bin/bash

# Quality Control Auto-Watcher
# Monitors code changes and automatically runs quality checks

WATCH_DIRS=(
  "server/src"
  "server/prisma"
  "ios"
)

DEBOUNCE_SECONDS=3
QUALITY_AGENT="quality-control/quality-agent.ts"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_ROOT"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Quality Control Auto-Watcher${NC}"
echo "Monitoring code changes in:"
for dir in "${WATCH_DIRS[@]}"; do
  echo "  • $dir"
done
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Track last run time to debounce
LAST_RUN=0

# Function to run quality check
run_quality_check() {
  local current_time=$(date +%s)
  local time_since_last_run=$((current_time - LAST_RUN))
  
  # Debounce: only run if enough time has passed
  if [ $time_since_last_run -lt $DEBOUNCE_SECONDS ]; then
    return
  fi
  
  LAST_RUN=$current_time
  
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}📝 Files changed - Running quality check...${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Determine runner (tsx or npx tsx)
  if command -v tsx &> /dev/null; then
    RUNNER="tsx"
  elif command -v npx &> /dev/null; then
    RUNNER="npx tsx"
  else
    echo -e "${RED}❌ Error: Neither tsx nor npx is available${NC}"
    return 1
  fi
  
  # Run quality agent
  $RUNNER "$QUALITY_AGENT" 2>&1
  
  local exit_code=$?
  
  echo ""
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}✅ Quality check completed${NC}"
  else
    echo -e "${RED}❌ Quality check found issues - see report above${NC}"
  fi
  
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${YELLOW}Watching for changes...${NC}"
}

# Check if fswatch is available (macOS) or use inotifywait (Linux) or fallback
if command -v fswatch &> /dev/null; then
  echo -e "${GREEN}Using fswatch (macOS)${NC}"
  echo ""
  
  # Build watch paths
  WATCH_PATHS=""
  for dir in "${WATCH_DIRS[@]}"; do
    if [ -d "$dir" ]; then
      WATCH_PATHS="$WATCH_PATHS $PROJECT_ROOT/$dir"
    fi
  done
  
  # Watch for changes
  fswatch -m poll_monitor -r -l 0.5 $WATCH_PATHS | while read change; do
    # Filter for relevant file extensions
    if [[ "$change" =~ \.(ts|js|swift|prisma)$ ]] || [[ "$change" =~ (migration|schema) ]]; then
      run_quality_check
    fi
  done

elif command -v inotifywait &> /dev/null; then
  echo -e "${GREEN}Using inotifywait (Linux)${NC}"
  echo ""
  
  # Watch for changes in each directory
  while true; do
    for dir in "${WATCH_DIRS[@]}"; do
      if [ -d "$dir" ]; then
        inotifywait -r -e modify,create,delete --format '%w%f' "$dir" 2>/dev/null | while read file; do
          if [[ "$file" =~ \.(ts|js|swift|prisma)$ ]] || [[ "$file" =~ (migration|schema) ]]; then
            run_quality_check
          fi
        done
      fi
    done
  done

else
  # Fallback: Poll file modification times (simplified for macOS bash compatibility)
  echo -e "${YELLOW}⚠️  fswatch/inotifywait not available, using polling (checking every 5 seconds)${NC}"
  echo -e "${YELLOW}💡 Install fswatch for better performance: brew install fswatch${NC}"
  echo ""
  
  # Create a temporary marker file to track last check time
  TIMESTAMP_FILE=$(mktemp /tmp/quality-watcher-ts-XXXXXX 2>/dev/null || echo "/tmp/quality-watcher-ts-$$")
  trap "rm -f $TIMESTAMP_FILE" EXIT INT TERM
  
  # Create marker file with current time
  touch "$TIMESTAMP_FILE"
  
  # Poll for changes
  while true; do
    sleep 5
    
    # Check if any relevant files have been modified since last check
    CHANGED=false
    for dir in "${WATCH_DIRS[@]}"; do
      if [ -d "$dir" ]; then
        # Find files newer than timestamp file (modified since last check)
        if find "$dir" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.swift" -o -name "*.prisma" \) -newer "$TIMESTAMP_FILE" 2>/dev/null | grep -q .; then
          CHANGED=true
          break
        fi
      fi
    done
    
    if [ "$CHANGED" = true ]; then
      # Update timestamp file to current time
      touch "$TIMESTAMP_FILE"
      run_quality_check
    fi
  done
fi
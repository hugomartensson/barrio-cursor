# Auto-Watcher Setup

The quality control agent can automatically run whenever code changes, ensuring continuous validation against PRD and guidelines.

## Quick Start

Run the auto-watcher in a separate terminal:

```bash
cd /Users/hugo/Desktop/barrio-cursor
./quality-control/watch-and-check.sh
```

This will:
- Monitor `server/src`, `server/prisma`, and `ios/` directories
- Automatically run quality checks when files change
- Debounce runs (wait 3 seconds after last change)
- Display reports in real-time

## What It Monitors

- **server/src/** - All TypeScript/JavaScript source files
- **server/prisma/** - Database schema and migrations
- **ios/** - iOS Swift source files

File types watched:
- `.ts`, `.js` - TypeScript/JavaScript
- `.swift` - Swift files
- `.prisma` - Prisma schema files
- Migration files

## How It Works

1. **File Change Detected** → Watcher detects file save/modification
2. **Debounce (3 seconds)** → Waits 3 seconds to batch multiple changes
3. **Run Quality Agent** → Executes quality control checks
4. **Display Report** → Shows PRD compliance, guidelines validation, code quality
5. **Continue Watching** → Returns to watching for more changes

## Focus Areas

The auto-watcher focuses on:

### ✅ PRD Compliance
- Event expiration filtering
- DELETE endpoint with ownership verification
- Cron job for cleanup
- Video duration validation
- GIST spatial index

### ✅ Guidelines Compliance
- Security (SQL injection, hardcoded secrets)
- Code quality (ESLint, tests)
- Error handling
- Logging standards

### ✅ Code Quality
- ESLint validation
- Test suite execution

### ⚠️ NEXT_STEPS.md Alignment (Disabled)
- Not checked (may be outdated)
- Focus is on PRD and guidelines instead

## Exit Codes

The watcher continues even if checks fail, but you'll see:
- `✅` = All checks passed
- `❌` = Failures found (review report)

## Stop the Watcher

Press `Ctrl+C` to stop monitoring.

## Platform Support

- **macOS**: Uses `fswatch` (install with `brew install fswatch` if not available)
- **Linux**: Uses `inotifywait` (usually pre-installed)
- **Fallback**: Polls file modification times every 5 seconds

## Troubleshooting

### "fswatch: command not found" (macOS)

Install fswatch:
```bash
brew install fswatch
```

### "inotifywait: command not found" (Linux)

Install inotify-tools:
```bash
sudo apt-get install inotify-tools  # Debian/Ubuntu
sudo yum install inotify-tools      # CentOS/RHEL
```

### Watcher not detecting changes

The fallback polling method will work, but is slower (checks every 5 seconds).

## Integration with Cursor Chat

**Recommended setup:**

1. **Terminal 1** - Your main Cursor chat
2. **Terminal 2** - Auto-watcher: `./quality-control/watch-and-check.sh`

Work normally in Terminal 1. Terminal 2 will automatically show quality reports whenever the Cursor agent changes code.

This ensures:
- ✅ PRD compliance is verified after each change
- ✅ Guidelines violations are caught immediately
- ✅ Security issues are flagged in real-time
- ✅ No manual quality checks needed

---

**Note:** The watcher debounces runs (3 seconds) to avoid running checks too frequently during rapid edits.
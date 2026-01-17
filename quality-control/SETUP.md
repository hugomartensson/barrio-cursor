# Quality Control Agent - Setup Guide

This guide explains how to set up and use the automatic quality controller that runs parallel to your development chat.

## Overview

The Quality Control Agent monitors your codebase and automatically validates:

- ✅ **PRD Compliance** - Features match the Product Requirements Document
- ✅ **Guidelines Compliance** - Code follows development guidelines  
- ✅ **Intention Alignment** - Implementation matches stated goals (from NEXT_STEPS.md, commits)
- ✅ **Code Quality** - Linting, tests, and code quality standards

## Quick Start

### Option 1: Manual Run (Recommended for Testing)

Run the agent manually when you want a quality check:

```bash
# From project root
tsx quality-control/quality-agent.ts

# Or use the helper script
./quality-control/run-quality-check.sh
```

This generates a `quality-report.txt` file with all findings.

### Option 2: Continuous Monitoring (Parallel to Chat)

Run the agent in a **separate terminal window** while you work:

```bash
# Runs every 30 seconds (default)
./quality-control/watch-quality.sh

# Or customize interval (e.g., every 60 seconds)
./quality-control/watch-quality.sh 60
```

This continuously monitors your code and shows updates every N seconds.

### Option 3: Git Hook Integration (Automatic)

Set up git hooks to run the agent automatically after commits:

```bash
./quality-control/setup-git-hooks.sh
```

This installs:
- **Pre-commit hook** (optional - disabled by default) - Can block commits if quality fails
- **Post-commit hook** (active) - Runs quality check after each commit

To enable pre-commit blocking (optional):

1. Edit `.git/hooks/pre-commit-quality`
2. Uncomment the `tsx` command line
3. Save the file

## How It Works

### 1. PRD Compliance Checker

The agent checks if your code implements PRD requirements:

- Events filtered by expiration (`endTime > NOW()`)
- DELETE endpoint with ownership verification
- Daily cron job for expired events
- Video duration validation (15 seconds max)
- GIST spatial index on location

**Example Output:**
```
✅ [5.1] Events filtered by expiration (endTime > NOW())
   Status: PASS
   Evidence: Found: endTime > NOW()
   File: server/src/routes/events.ts
```

### 2. Guidelines Compliance Checker

Validates code follows development guidelines:

- **Security**: No SQL injection, no hardcoded secrets, proper error handling
- **Code Quality**: ESLint config exists, tests present
- **Style**: Code follows project standards

**Example Output:**
```
✅ [security] No SQL injection (use parameterized queries)
   Status: PASS
   Evidence: No violations found
```

### 3. Intention Alignment Checker

Compares stated intentions vs actual implementation:

- Reads tasks from `NEXT_STEPS.md`
- Checks if related code exists
- Validates commit messages match code changes

**Example Output:**
```
✅ Fix GIST Index for PostGIS Performance
   Source: NEXT_STEPS.md
   Status: ALIGNED
   Evidence: Found related code in 2 file(s)
   Files: prisma/migrations/..., server/src/routes/events.ts
```

### 4. Code Quality Checker

Runs automated checks:

- ESLint validation
- Test suite execution
- Build verification

**Example Output:**
```
✅ ESLint passes
   Severity: ERROR
   Status: PASS
   Evidence: ESLint passes

❌ Tests pass
   Severity: ERROR
   Status: FAIL
   Evidence: Test failures found
```

## Report Format

The agent generates a comprehensive report:

```
════════════════════════════════════════════════════════════════════════════════
  QUALITY CONTROL REPORT
════════════════════════════════════════════════════════════════════════════════
Timestamp: 2025-01-06T12:00:00.000Z

📊 SUMMARY
--------------------------------------------------------------------------------
Overall Status: WARN
Total Checks: 12
✅ Passed: 8
❌ Failed: 2
⚠️  Warnings: 2

🚨 CRITICAL ISSUES:
   • Events filtered by expiration (endTime > NOW())
   • Not implemented: Fix GIST Index for PostGIS Performance

[... detailed sections ...]
```

## Integration with Cursor/Chat

To run the quality agent **in parallel** to your main development chat:

### Recommended Setup

1. **Open two terminal windows:**
   - Terminal 1: Your main development terminal (for Cursor chat)
   - Terminal 2: Quality control monitoring terminal

2. **In Terminal 2, run:**
   ```bash
   ./quality-control/watch-quality.sh 30
   ```

3. **Work in Terminal 1 as usual.** Terminal 2 will continuously show quality reports.

4. **When you see warnings/failures in Terminal 2:**
   - Review the report
   - Address critical issues in your main chat
   - Re-run quality check to verify fixes

### Alternative: Background Process

Run the agent in the background:

```bash
# Start background process
nohup ./quality-control/watch-quality.sh 60 > quality-reports.log 2>&1 &

# View latest report
cat quality-report.txt

# Stop background process
pkill -f "watch-quality.sh"
```

## Exit Codes

The agent uses exit codes that can be used in CI/CD:

- `0` - All checks passed (or warnings only)
- `1` - Failures found (can block commits if enabled)

## Customization

Edit `quality-control/quality-agent.ts` to:

- Add custom PRD requirement checks
- Adjust guideline patterns
- Change severity levels  
- Add new check categories
- Modify report format

## Troubleshooting

### "tsx is not installed"

Install tsx globally:
```bash
npm install -g tsx
```

Or use npx:
```bash
npx tsx quality-control/quality-agent.ts
```

### "Not a git repository"

The agent works without git, but some features (commit checking) won't work. Initialize git:
```bash
git init
```

### Tests timeout or fail

This is expected in development. The agent will mark tests as "warn" if they can't run. Focus on fixing code issues first.

### Agent runs slowly

- The agent analyzes all server files
- Test execution may take time
- Consider running manually instead of continuous monitoring if it's too slow

## Best Practices

1. **Run after major changes** - Check quality after completing a feature
2. **Review before commits** - Run agent before committing to catch issues early
3. **Fix critical issues first** - Address "fail" status items before warnings
4. **Keep PRD and guidelines updated** - Agent reads from these files, keep them current
5. **Use continuous monitoring sparingly** - Manual runs are often more efficient

## Next Steps

- Run the agent once: `./quality-control/run-quality-check.sh`
- Review the generated `quality-report.txt`
- Fix any critical issues found
- Set up git hooks for automatic checks: `./quality-control/setup-git-hooks.sh`
- Or run continuous monitoring in a separate terminal

---

**Questions or Issues?** Check `quality-control/README.md` for more details.
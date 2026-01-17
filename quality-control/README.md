# Quality Control Agent

An automatic quality controller that runs parallel to development to ensure code changes align with the PRD, guidelines, and stated intentions.

## Overview

The Quality Control Agent monitors code development and automatically validates:

1. **PRD Compliance** - Ensures features match Product Requirements Document
2. **Guidelines Compliance** - Checks code follows development guidelines
3. **Intention Alignment** - Verifies stated goals (from NEXT_STEPS.md, commits) match implementation
4. **Code Quality** - Runs linting, tests, and code quality checks

## Installation

The agent uses TypeScript with tsx. Dependencies are managed in the main project.

## Usage

### Run Manually

```bash
cd quality-control
tsx quality-agent.ts
```

Or from project root:

```bash
tsx quality-control/quality-agent.ts
```

### Run as Git Hook (Automatic)

The agent can be integrated into git hooks to run automatically:

#### Pre-commit Hook

Add to `.git/hooks/pre-commit` (or via husky):

```bash
#!/bin/sh
tsx quality-control/quality-agent.ts || exit 1
```

#### Post-commit Hook

Run after commits to generate quality reports:

```bash
#!/bin/sh
tsx quality-control/quality-agent.ts > quality-report.txt
```

### Run as Watcher (Continuous Monitoring)

Create a watcher script that runs the agent on file changes:

```bash
# Using nodemon or similar
nodemon --watch server/src --exec "tsx quality-control/quality-agent.ts"
```

## Report Format

The agent generates a comprehensive report showing:

- **Summary** - Overall status, pass/fail counts, critical issues
- **Git Status** - Current changes, staged files, recent commits
- **PRD Compliance** - Requirement-by-requirement validation
- **Guidelines Compliance** - Security, code quality, testing checks
- **Intention Alignment** - Tasks from NEXT_STEPS.md vs implementation
- **Code Quality** - ESLint and test results

Reports are printed to console and saved to `quality-report.txt`.

## Integration with Cursor/Chat

To run this agent **in parallel** to your main development chat:

1. **Option A: Separate Terminal**
   - Open a separate terminal window
   - Run: `watch -n 30 tsx quality-control/quality-agent.ts`
   - This runs every 30 seconds and shows the latest report

2. **Option B: Background Process**
   - Run: `nohup tsx quality-control/quality-agent.ts > quality-report.txt 2>&1 &`
   - Check reports with: `cat quality-report.txt`

3. **Option C: Git Hook Integration**
   - Set up post-commit hook to run agent automatically
   - Reports saved after each commit

## Exit Codes

- `0` - All checks passed (or warnings only)
- `1` - Failures found (can be used to block commits)

## Customization

Edit `quality-agent.ts` to:

- Add custom PRD requirement checks
- Adjust guideline patterns
- Change severity levels
- Add new check categories

## Example Output

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

[... detailed report sections ...]
```

## Notes

- The agent reads from `PRD.txt`, `guidelines.txt`, and `NEXT_STEPS.md` in the project root
- Server code is checked in `server/src/`
- Tests are run if available (may timeout in development)
- Git commands are optional (agent works without git repo)
# How to Try the Quality Control Agent

## Method 1: Using npx (Recommended - No Installation Needed)

Open your terminal and run:

```bash
cd /Users/hugo/Desktop/barrio-cursor
npx tsx quality-control/quality-agent.ts
```

This will automatically download and run `tsx` without installing it globally.

## Method 2: Using Node from Server Directory

If you have Node.js set up in the server directory:

```bash
cd /Users/hugo/Desktop/barrio-cursor/server
npx tsx ../quality-control/quality-agent.ts
```

## Method 3: Install tsx Globally (One-Time Setup)

If you want to use `tsx` directly:

```bash
npm install -g tsx
cd /Users/hugo/Desktop/barrio-cursor
tsx quality-control/quality-agent.ts
```

## Method 4: Use the Shell Script (After Node Setup)

```bash
cd /Users/hugo/Desktop/barrio-cursor
./quality-control/run-quality-check.sh
```

Make sure the script is executable (it should already be):
```bash
chmod +x quality-control/run-quality-check.sh
```

## What You'll See

The agent will:
1. Analyze your codebase
2. Check PRD compliance
3. Validate guidelines
4. Check intention alignment
5. Run code quality checks
6. Display a comprehensive report
7. Save results to `quality-report.txt`

## Example Output

```
════════════════════════════════════════════════════════════════════════════════
  QUALITY CONTROL REPORT
════════════════════════════════════════════════════════════════════════════════
Timestamp: 2025-01-06T...

📊 SUMMARY
--------------------------------------------------------------------------------
Overall Status: WARN
Total Checks: 12
✅ Passed: 8
❌ Failed: 2
⚠️  Warnings: 2

[... detailed sections ...]
```

## Troubleshooting

### "npx: command not found"
- Make sure Node.js is installed: `node --version`
- If Node.js is installed via Homebrew but not in PATH, try: `/usr/local/bin/npx` or `/opt/homebrew/bin/npx`

### "tsx not found"
- Use `npx tsx` instead of just `tsx` - npx will download it automatically

### "Permission denied" on scripts
```bash
chmod +x quality-control/*.sh
```

## Next Steps

After running successfully:

1. **Review the report** - Check `quality-report.txt` for detailed findings
2. **Address critical issues** - Fix any "fail" status items
3. **Set up continuous monitoring** - Run `./quality-control/watch-quality.sh 30` in a separate terminal
4. **Set up git hooks** - Run `./quality-control/setup-git-hooks.sh` for automatic checks
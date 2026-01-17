# Quality Control Agent - Quick Reference

## 🚀 Quick Commands

### Run Quality Check (One-time)
```bash
tsx quality-control/quality-agent.ts
```

### Watch Continuously (Parallel to Chat)
```bash
./quality-control/watch-quality.sh 30
```

### Set Up Git Hooks
```bash
./quality-control/setup-git-hooks.sh
```

## 📋 What Gets Checked

| Check | Description | Source |
|-------|-------------|--------|
| **PRD Compliance** | Features match requirements | `PRD.txt` |
| **Guidelines** | Security, code quality, style | `guidelines.txt` |
| **Intention Alignment** | Implementation vs stated goals | `NEXT_STEPS.md`, commits |
| **Code Quality** | ESLint, tests, build | Codebase |

## 🎯 Usage with Cursor Chat

**Two-Terminal Setup:**

1. **Terminal 1** (Main): Your Cursor chat development
2. **Terminal 2** (Monitor): Run `./quality-control/watch-quality.sh 30`

Terminal 2 will show quality updates every 30 seconds while you work in Terminal 1.

## 📊 Report Location

Reports saved to: `quality-report.txt` (project root)

## ⚙️ Exit Codes

- `0` = Pass (or warnings only)
- `1` = Failures found

## 🔧 Customization

Edit `quality-control/quality-agent.ts` to add custom checks.

## 📚 Full Documentation

- `SETUP.md` - Detailed setup guide
- `README.md` - Complete documentation

---

**Pro Tip:** Run manually after features for best performance. Use continuous monitoring for active development sessions.
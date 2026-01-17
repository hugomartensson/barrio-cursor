# Quality Control System

An automatic quality controller that runs parallel to development to ensure code changes align with the PRD, guidelines, and stated intentions.

## Quick Start

### Run Once (Manual Check)

**Easiest way (no installation needed):**
```bash
npx tsx quality-control/quality-agent.ts
```

**Or using the helper script:**
```bash
./quality-control/run-quality-check.sh
```

**Or if you have tsx installed globally:**
```bash
tsx quality-control/quality-agent.ts
```

This generates a `quality-report.txt` file with validation results.

### Run Continuously (Parallel to Chat)

Open a **separate terminal** and run:

```bash
./quality-control/watch-quality.sh 30
```

This monitors your code every 30 seconds while you work in your main chat.

### Set Up Git Hooks (Automatic)

```bash
./quality-control/setup-git-hooks.sh
```

Runs quality checks automatically after each commit.

## What It Checks

The quality agent automatically validates:

1. **PRD Compliance** - Features match Product Requirements Document
2. **Guidelines Compliance** - Code follows development guidelines
3. **Intention Alignment** - Implementation matches stated goals (NEXT_STEPS.md, commits)
4. **Code Quality** - ESLint, tests, build verification

## How to Use with Cursor Chat

**Recommended workflow:**

1. Open two terminals:
   - Terminal 1: Your main development (Cursor chat)
   - Terminal 2: Quality control monitoring

2. In Terminal 2, run:
   ```bash
   ./quality-control/watch-quality.sh 30
   ```

3. Work normally in Terminal 1. Terminal 2 will show quality reports every 30 seconds.

4. When you see warnings/failures, address them in your main chat.

## Report Location

Quality reports are saved to `quality-report.txt` in the project root.

## Documentation

- `quality-control/README.md` - Full documentation
- `quality-control/SETUP.md` - Detailed setup guide

---

**Tip:** Run the agent manually after completing features for the best balance of feedback and performance.
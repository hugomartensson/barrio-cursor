# Quality Control System

Automated quality control for verifying implementation matches requirements, completeness, and functionality.

## Quick Start

**After completing major work:**

```bash
./quality-control/verify-after-work.sh
```

This runs both agents and generates `quality-control-report.txt`.

## What It Does

### Two-Agent System

1. **Quality Agent** (`quality-agent.ts`)
   - Checks PRD compliance (features match PRD-TestFlight.md)
   - Validates guidelines compliance
   - Runs code quality checks (linting, tests, build)

2. **Implementation Verifier** (`implementation-verifier.ts`)
   - Extracts features from recent git commits
   - Verifies each feature is actually implemented
   - Checks completeness (all required components)
   - Verifies functionality (builds, tests pass)

### Combined Process (`auto-verify.ts`)
- Runs both agents in sequence
- Generates comprehensive report
- Provides clear pass/fail status

## Usage

### Recommended: After Major Work (Tiered)

```bash
# Quick check (Tier 1 - fast, after major AI prompt)
./quality-control/verify-after-work.sh 1

# Full backend verification (Tier 2 - before commits)
./quality-control/verify-after-work.sh 2

# Deep verification (Tier 3 - pre-TestFlight)
./quality-control/verify-after-work.sh 3
```

Review `quality-control-report.txt` in the project root. It is written by `verify-after-work` and by the post-commit hook (Tier 1).

### Individual Agents

```bash
# Quality Agent only (PRD + Guidelines) – output to console only
tsx quality-control/quality-agent.ts

# Implementation Verifier only
tsx quality-control/implementation-verifier.ts

# Combined (recommended) – writes quality-control-report.txt
tsx quality-control/auto-verify.ts
```

### Continuous Monitoring (Optional)

Run in separate terminal while developing:

```bash
# Runs every 30 seconds
./quality-control/watch-quality.sh 30
```

### Git Hooks (Optional)

```bash
./quality-control/setup-git-hooks.sh
```

## What Gets Verified

### Implementation Checks

Automatically detects features from commit messages:

- `feat(plans): add plans feature` → Checks Plans tables, endpoints, iOS views
- `feat(interested): add interested endpoint` → Checks endpoint, table, field
- `feat(follow): add following system` → Checks tables, endpoints, user fields
- `fix(terminology): update to Interested` → Verifies old terminology removed

### Completeness Checks

For each feature, verifies all required components:

**Example: Plans Feature**
- Database table: Plan
- Database table: PlanEvent
- Backend endpoints: POST/GET /api/plans, POST /api/plans/:id/events/:eventId
- iOS views: PlansView, PlanDetailView

If any component missing → Status: **PARTIAL**

### Functionality Checks

- Backend TypeScript compilation
- Backend tests pass
- Backend linting passes
- iOS build status (if Xcode available)

## Report Format

```
📊 SUMMARY
Overall Status: PASS/FAIL/WARN
✅ Complete: X
⚠️  Partial: X
❌ Missing: X
💥 Broken: X

🚨 CRITICAL ISSUES:
   • Missing: Plans feature
   • Broken: Backend tests
```

## Integration Options

1. **Manual Trigger** (Recommended) - Run after major features
2. **Git Hook** - Automatic after commits
3. **Continuous Monitoring** - Background watching

## Troubleshooting

- **"Could not read Prisma schema"** - Ensure `server/prisma/schema.prisma` exists
- **"Could not read git commits"** - Ensure you're in a git repository
- **"Tests timeout"** - Expected in development, check report file
- **"Build fails"** - Fix TypeScript errors, check report for details

## Next Steps

1. **If PASS**: Continue development ✅
2. **If WARN**: Review partial implementations ⚠️
3. **If FAIL**: Fix critical issues before continuing ❌
   - Copy error messages to AI assistant
   - Fix issues
   - Re-run verification

---

**Remember**: This is a tool to help ensure quality, not a blocker. Use it to verify work, not to slow down development.

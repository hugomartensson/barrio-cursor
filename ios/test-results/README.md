# UI test results

This directory is populated by the automated test loop:

```bash
# From repo root
./scripts/run-ui-tests-and-report.sh
```

**Outputs:**

- `latest-run.log` — Full xcodebuild log
- `latest-report.md` — Summary, failure analysis, and recommended next steps (for humans or agents)
- `TestResults.xcresult` — Xcode result bundle (open in Xcode for test details)

After each run, read `latest-report.md` to see pass/fail, whether the failure was build vs test vs bootstrap timeout, and what to do next.

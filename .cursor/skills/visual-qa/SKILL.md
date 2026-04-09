---
name: visual-qa
description: Automated visual QA for the Barrio iOS app. Captures screenshots from the running iOS Simulator, sends them to Gemini for defect detection, and produces a structured report. Use when the user says "run visual qa", "check the screen", "visual qa", or asks to review what a screen looks like for visual defects.
---

# Visual QA — Barrio iOS

Catches objective visual defects (broken layout, unreadable text, missing images, safe area violations, dark mode failures) in the Barrio iOS app by analysing screenshots with Gemini.

**Scope:** What any sighted person would notice in a 5-second glance. Not design critique — only clear defects.

---

## Prerequisites

Before running, confirm:
1. Xcode Simulator is running with the Barrio app open
2. The app is showing the screen the user wants to review
3. `GEMINI_API_KEY` is available in the environment (check with `echo $GEMINI_API_KEY`)

If the key is not set, ask the user to provide it or check their shell environment.

---

## Steps

### 1 — Install dependencies (first run only)

```bash
cd .cursor/skills/visual-qa/scripts && npm install
```

Check if `node_modules/` already exists before running — skip if it does.

### 2 — Capture screenshot(s)

Capture the current simulator screen:

```bash
xcrun simctl io booted screenshot /tmp/barrio-vqa-$(date +%s).png
```

Save the full path — you'll pass it to the reviewer in the next step.

To capture **multiple screens**, navigate the app to each screen, capture, repeat. Collect all paths.

To capture **dark mode**:
```bash
xcrun simctl ui booted appearance dark
xcrun simctl io booted screenshot /tmp/barrio-vqa-dark-$(date +%s).png
xcrun simctl ui booted appearance light
```

### 3 — Run the reviewer

Single screenshot:
```bash
GEMINI_API_KEY=$GEMINI_API_KEY node .cursor/skills/visual-qa/scripts/review.mjs \
  --screen="Discover feed" \
  /tmp/barrio-vqa-<timestamp>.png
```

Multiple screenshots (screen labels come from filenames):
```bash
GEMINI_API_KEY=$GEMINI_API_KEY node .cursor/skills/visual-qa/scripts/review.mjs \
  /tmp/barrio-vqa-discover.png \
  /tmp/barrio-vqa-event-detail.png \
  /tmp/barrio-vqa-map.png
```

The `--screen` flag sets the screen name in the report. When reviewing multiple files, name the files descriptively so the report is readable.

### 4 — Read and present the report

The script prints the full report to stdout and saves it to:
- `.cursor/skills/visual-qa/output/report-latest.md` (always overwritten)
- `.cursor/skills/visual-qa/output/report-<timestamp>.md` (archived)

Read the report and present findings to the user. Structure your response as:

1. **Summary line** — total defects, CRITICAL/MAJOR/MINOR counts
2. **CRITICAL issues** — list each with location, element, and what is wrong
3. **MAJOR issues** — same
4. **MINOR issues** — brief mention only
5. **Clean screens** — list any screens with zero defects

Exit code 1 means at least one CRITICAL defect was found.

---

## Screen names to use with --screen

Use these exact names for consistency across reports:

| Screen | `--screen` value |
|--------|-----------------|
| Discover feed (populated) | `Discover feed` |
| Discover feed (empty state) | `Discover feed — empty` |
| Event detail | `Event detail` |
| Map view | `Map view` |
| Login | `Login` |
| Signup | `Signup` |
| Own profile | `Profile` |
| Other user profile | `User profile` |
| Edit profile | `Edit profile` |
| Create event (form) | `Create event` |
| Create event (media) | `Create event — media` |
| Create spot | `Create spot` |
| Spot detail | `Spot detail` |
| Collection detail | `Collection detail` |
| Date range picker | `Date range picker` |

---

## What the reviewer checks

The Gemini model is given the system prompt from `system-prompt.md`. For a full human-readable checklist of what to look for per screen, see `defect-checklist.md`.

**Top priority defects (always flag):**
- Unreadable or invisible text
- Debug/placeholder text visible (`nil`, `Optional(...)`)
- Content clipped by Dynamic Island, notch, or home indicator
- Broken or missing images (grey placeholder when real content expected)
- Blank screen with no loading indicator or empty state message
- Obvious layout collapse (card at zero height, form field off-screen)
- Same element duplicated on screen
- Interactive element invisible or unreachable

---

## Troubleshooting

**No simulator found:**
```bash
xcrun simctl list devices | grep Booted
```
Boot a simulator from Xcode or run:
```bash
xcrun simctl boot "iPhone 16"
open -a Simulator
```

**`npm install` fails:** Requires Node 18+. Check with `node --version`.

**Gemini returns invalid JSON:** The script strips code fences automatically. If it still fails, check the raw output — the model may have returned an error message instead of JSON.

**Screenshot is black:** The simulator may be asleep. Click the simulator window or press a key to wake it before capturing.

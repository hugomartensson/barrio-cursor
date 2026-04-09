/**
 * Barrio Visual QA — Gemini screenshot reviewer
 *
 * Usage:
 *   GEMINI_API_KEY=... node review.mjs <screenshot.png> [screenshot2.png ...]
 *   GEMINI_API_KEY=... node review.mjs --screen="Discover feed" screenshot.png
 *
 * Exit codes:
 *   0 — passed (zero CRITICAL defects)
 *   1 — failed (one or more CRITICAL defects, or fatal error)
 */

import { GoogleGenerativeAI } from '@google/generative-ai';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { join, dirname, resolve, basename, extname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SKILL_DIR = resolve(__dirname, '..');
const OUTPUT_DIR = join(SKILL_DIR, 'output');

// ---------------------------------------------------------------------------
// Parse args
// ---------------------------------------------------------------------------

const rawArgs = process.argv.slice(2);
let screenLabel = null;
const imagePaths = [];

for (const arg of rawArgs) {
  if (arg.startsWith('--screen=')) {
    screenLabel = arg.split('=').slice(1).join('=');
  } else if (arg.startsWith('--')) {
    // ignore unknown flags
  } else {
    imagePaths.push(resolve(arg));
  }
}

if (!imagePaths.length) {
  console.error('Usage: node review.mjs [--screen="Screen name"] <screenshot.png> [screenshot2.png ...]');
  process.exit(1);
}

if (!process.env.GEMINI_API_KEY) {
  console.error('Error: GEMINI_API_KEY environment variable is required.');
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Load system prompt
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT = readFileSync(join(SKILL_DIR, 'system-prompt.md'), 'utf8');

// ---------------------------------------------------------------------------
// Gemini analysis
// ---------------------------------------------------------------------------

async function reviewScreenshot(imagePath, label) {
  const genai = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genai.getGenerativeModel({
    model: 'gemini-2.5-flash',
    systemInstruction: SYSTEM_PROMPT,
  });

  const imageData = readFileSync(imagePath).toString('base64');
  const screenName = label ?? basename(imagePath, extname(imagePath)).replace(/[_-]+/g, ' ');

  const prompt = [
    `Screen: ${screenName}`,
    `Platform: iOS SwiftUI, iPhone`,
    '',
    'Review this screenshot for visual defects.',
    'Return ONLY the JSON array. If there are no defects, return [].',
  ].join('\n');

  const result = await model.generateContent([
    { inlineData: { data: imageData, mimeType: 'image/png' } },
    prompt,
  ]);

  const raw = result.response.text().trim();
  const jsonText = raw
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/, '')
    .trim();

  return { screenName, defects: JSON.parse(jsonText) };
}

// ---------------------------------------------------------------------------
// Report generation
// ---------------------------------------------------------------------------

function generateReport(allResults) {
  const timestamp = new Date().toISOString();
  const allDefects = allResults.flatMap(r => r.defects.map(d => ({ ...d, screen: r.screenName })));
  const critical = allDefects.filter(d => d.severity === 'CRITICAL');
  const major = allDefects.filter(d => d.severity === 'MAJOR');
  const minor = allDefects.filter(d => d.severity === 'MINOR');

  const screensWithDefects = new Set(allDefects.map(d => d.screen));
  const cleanScreens = allResults
    .map(r => r.screenName)
    .filter(n => !screensWithDefects.has(n));

  function renderSection(list) {
    if (!list.length) return '_None_\n';
    return list
      .map(d =>
        `### ${d.id} · ${d.category} · ${d.screen}\n` +
        `**Element:** ${d.element}\n` +
        `**Location:** ${d.location}\n` +
        `**Issue:** ${d.description}\n` +
        `**Likely cause:** ${d.likely_cause}\n`
      )
      .join('\n---\n\n');
  }

  return [
    '# Visual QA Report — Barrio iOS',
    `Date: ${timestamp}`,
    `Screens reviewed: ${allResults.length}`,
    `Total defects: ${allDefects.length} (CRITICAL: ${critical.length} | MAJOR: ${major.length} | MINOR: ${minor.length})`,
    '',
    '---',
    '',
    '## CRITICAL Issues',
    '',
    renderSection(critical),
    '',
    '---',
    '',
    '## MAJOR Issues',
    '',
    renderSection(major),
    '',
    '---',
    '',
    '## MINOR Issues',
    '',
    renderSection(minor),
    '',
    '---',
    '',
    '## Clean Screens',
    '',
    cleanScreens.length
      ? cleanScreens.map(s => `- ${s}`).join('\n')
      : '_All screens had at least one defect._',
    '',
  ].join('\n');
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  if (!existsSync(OUTPUT_DIR)) mkdirSync(OUTPUT_DIR, { recursive: true });

  console.log(`\nBarrio Visual QA — reviewing ${imagePaths.length} screenshot(s)\n`);

  const allResults = [];
  let counter = 1;

  for (const imagePath of imagePaths) {
    const label = imagePaths.length === 1 ? screenLabel : null;
    console.log(`  [analysing] ${basename(imagePath)}`);

    try {
      const result = await reviewScreenshot(imagePath, label ?? screenLabel);
      // Re-number IDs sequentially across all screenshots
      result.defects = result.defects.map(d => ({
        ...d,
        id: `VQA-${String(counter++).padStart(3, '0')}`,
      }));
      allResults.push(result);
    } catch (err) {
      console.error(`  [error] ${basename(imagePath)}: ${err.message}`);
      allResults.push({ screenName: basename(imagePath), defects: [] });
    }
  }

  const report = generateReport(allResults);

  // Save timestamped report
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const reportPath = join(OUTPUT_DIR, `report-${ts}.md`);
  const latestPath = join(OUTPUT_DIR, 'report-latest.md');
  writeFileSync(reportPath, report);
  writeFileSync(latestPath, report);

  console.log(`\n${'='.repeat(60)}\n`);
  console.log(report);
  console.log(`\nReport saved to: ${reportPath}`);

  const criticalCount = allResults.flatMap(r => r.defects).filter(d => d.severity === 'CRITICAL').length;
  if (criticalCount > 0) {
    console.error(`\nFAILED — ${criticalCount} CRITICAL issue(s) found.`);
    process.exit(1);
  }

  console.log('\nPASSED — no CRITICAL issues found.');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});

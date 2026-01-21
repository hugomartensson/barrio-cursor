#!/usr/bin/env tsx

/**
 * Automated Quality Control Process
 * 
 * This script runs comprehensive quality checks after major work:
 * 1. Quality Agent (PRD compliance, guidelines, code quality)
 * 2. Implementation Verifier (What was promised → What was delivered)
 * 
 * Run this after completing major features to verify:
 * - Implementation matches stated intentions
 * - Features are complete (not partial)
 * - Everything works as intended
 */

import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { writeFile } from 'fs/promises';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

type Tier = 1 | 2 | 3;

function parseTierFromArgs(): Tier {
  const arg = process.argv.find((a) => a.startsWith('--tier='));
  if (!arg) {
    return 2; // Default: Tier 2 (full backend verification) for verify-after-work.sh
  }
  const value = Number(arg.split('=')[1]);
  if (value === 1 || value === 2 || value === 3) {
    return value;
  }
  return 2;
}

async function main() {
  const tier = parseTierFromArgs();

  console.log('🚀 Automated Quality Control Process\n');
  console.log(`Running verification (Tier ${tier})...\n`);

  const projectRoot = join(__dirname, '..');

  // Import both agents
  const { QualityAgent } = await import('./quality-agent.js');
  const { ImplementationVerifier } = await import('./implementation-verifier.js');

  // Run Quality Agent
  console.log('📋 Step 1: Running Quality Agent (PRD Compliance & Guidelines)...\n');
  const qualityAgent = new QualityAgent(projectRoot);
  const qualityReport = await qualityAgent.run({ tier });
  const qualityReportText = qualityAgent.generateReport(qualityReport);

  // Run Implementation Verifier
  console.log('\n📋 Step 2: Running Implementation Verifier (What Was Promised → What Was Delivered)...\n');
  const verifier = new ImplementationVerifier(projectRoot);
  const verificationReport = await verifier.verify({ tier });
  const verificationReportText = verifier.generateReport(verificationReport);

  // Combine reports
  const combinedReport = `
${'═'.repeat(80)}
  AUTOMATED QUALITY CONTROL REPORT
${'═'.repeat(80)}
Generated: ${new Date().toISOString()}

${qualityReportText}

${verificationReportText}

${'═'.repeat(80)}
  SUMMARY
${'═'.repeat(80)}
Quality Agent Status: ${qualityReport.summary.overall.toUpperCase()}
Implementation Verifier Status: ${verificationReport.summary.overall.toUpperCase()}

Overall Status: ${
    qualityReport.summary.overall === 'fail' ||
    verificationReport.summary.overall === 'fail'
      ? 'FAIL'
      : qualityReport.summary.overall === 'warn' ||
        verificationReport.summary.overall === 'warn'
      ? 'WARN'
      : 'PASS'
  }

Critical Issues:
${[
  ...qualityReport.summary.criticalIssues,
  ...verificationReport.summary.criticalIssues,
]
  .map((issue) => `  • ${issue}`)
  .join('\n') || '  None'}

${'═'.repeat(80)}
`;

  // Save combined report
  const reportPath = join(projectRoot, 'quality-control-report.txt');
  await writeFile(reportPath, combinedReport, 'utf-8');

  console.log(combinedReport);
  console.log(`\n📄 Full report saved to: ${reportPath}`);

  // Determine exit code
  const overallStatus =
    qualityReport.summary.overall === 'fail' ||
    verificationReport.summary.overall === 'fail'
      ? 'fail'
      : qualityReport.summary.overall === 'warn' ||
        verificationReport.summary.overall === 'warn'
      ? 'warn'
      : 'pass';

  process.exit(overallStatus === 'fail' ? 1 : 0);
}

main().catch((error) => {
  console.error('❌ Quality Control Process Error:', error);
  process.exit(1);
});

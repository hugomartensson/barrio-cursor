#!/usr/bin/env tsx

/**
 * Quality Control Agent
 * 
 * This agent runs parallel to development and automatically validates:
 * 1. Implementation matches stated intentions
 * 2. Code aligns with PRD requirements
 * 3. Guidelines compliance
 * 4. Code quality standards
 */

import { readFile, readdir, stat } from 'fs/promises';
import { join, dirname, relative } from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface QualityReport {
  timestamp: string;
  gitStatus: GitStatus;
  prdCompliance: PRDComplianceCheck[];
  guidelinesCompliance: GuidelinesComplianceCheck[];
  intentionAlignment: IntentionAlignmentCheck[];
  codeQuality: CodeQualityCheck[];
  summary: QualitySummary;
}

interface GitStatus {
  hasChanges: boolean;
  unstagedFiles: string[];
  stagedFiles: string[];
  lastCommit?: string;
  recentCommits: string[];
}

interface PRDRequirement {
  section: string;
  requirement: string;
  pattern: RegExp;
  checkFunction?: (content: string, filePath: string) => Promise<{ found: boolean; evidence: string }>;
}

interface PRDComplianceCheck {
  requirement: string;
  section: string;
  status: 'pass' | 'fail' | 'warn';
  evidence: string;
  file?: string;
}

interface GuidelinesComplianceCheck {
  rule: string;
  category: 'security' | 'code-quality' | 'style' | 'testing' | 'architecture';
  status: 'pass' | 'fail' | 'warn';
  evidence: string;
  file?: string;
}

interface IntentionAlignmentCheck {
  intention: string;
  source: string; // commit message, NEXT_STEPS.md, etc.
  status: 'aligned' | 'misaligned' | 'unclear' | 'not-implemented';
  evidence: string;
  files: string[];
}

interface CodeQualityCheck {
  rule: string;
  severity: 'error' | 'warning' | 'info';
  status: 'pass' | 'fail' | 'warn';
  evidence: string;
  file?: string;
  line?: number;
}

interface QualitySummary {
  totalChecks: number;
  passed: number;
  failed: number;
  warnings: number;
  overall: 'pass' | 'fail' | 'warn';
  criticalIssues: string[];
}

class QualityAgent {
  private projectRoot: string;
  private prdPath: string;
  private guidelinesPath: string;
  private nextStepsPath: string;
  private codeQualityPath: string;

  constructor(projectRoot: string = join(__dirname, '..')) {
    this.projectRoot = projectRoot;
    this.prdPath = join(projectRoot, 'PRD.txt');
    this.guidelinesPath = join(projectRoot, 'guidelines.txt');
    this.nextStepsPath = join(projectRoot, 'NEXT_STEPS.md');
    this.codeQualityPath = join(projectRoot, 'server', 'CODE_QUALITY.md');
  }

  async run(): Promise<QualityReport> {
    console.log('🔍 Quality Control Agent - Starting analysis...\n');

    const gitStatus = await this.checkGitStatus();
    const prdCompliance = await this.checkPRDCompliance();
    const guidelinesCompliance = await this.checkGuidelinesCompliance();
    const intentionAlignment = await this.checkIntentionAlignment();
    const codeQuality = await this.checkCodeQuality();

    const summary = this.generateSummary({
      prdCompliance,
      guidelinesCompliance,
      intentionAlignment,
      codeQuality,
    });

    // Format timestamp in CET timezone
    const timestamp = this.formatCETTime();

    const report: QualityReport = {
      timestamp,
      gitStatus,
      prdCompliance,
      guidelinesCompliance,
      intentionAlignment,
      codeQuality,
      summary,
    };

    return report;
  }

  private formatCETTime(): string {
    const now = new Date();
    
    // Convert to CET (UTC+1, or UTC+2 during daylight saving)
    // Using toLocaleString with Europe/Paris (which uses CET/CEST)
    const cetString = now.toLocaleString('en-US', {
      timeZone: 'Europe/Paris',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
    });
    
    // Format: YYYY-MM-DD HH:MM:SS CET
    // toLocaleString gives MM/DD/YYYY format, convert to YYYY-MM-DD
    const parts = cetString.split(/,?\s+/);
    if (parts.length >= 2) {
      const dateParts = parts[0].split('/');
      const timeParts = parts[1].split(':');
      if (dateParts.length === 3 && timeParts.length >= 3) {
        const year = dateParts[2];
        const month = dateParts[0].padStart(2, '0');
        const day = dateParts[1].padStart(2, '0');
        const hours = timeParts[0].padStart(2, '0');
        const minutes = timeParts[1].padStart(2, '0');
        const seconds = timeParts[2].padStart(2, '0');
        
        // Determine if CET or CEST (simplified: check if DST)
        const monthNum = parseInt(month, 10);
        const isDST = monthNum >= 4 && monthNum <= 10; // Rough DST period
        const tz = isDST ? 'CEST' : 'CET';
        
        return `${year}-${month}-${day} ${hours}:${minutes}:${seconds} ${tz}`;
      }
    }
    
    // Fallback to ISO string if parsing fails
    return now.toISOString().replace('T', ' ').replace('Z', ' CET');
  }

  private async checkGitStatus(): Promise<GitStatus> {
    try {
      const { stdout: status } = await execAsync(
        'git status --porcelain',
        { cwd: this.projectRoot }
      );
      
      const { stdout: log } = await execAsync(
        'git log --oneline -5',
        { cwd: this.projectRoot }
      );

      const { stdout: lastCommit } = await execAsync(
        'git log -1 --pretty=format:"%h %s"',
        { cwd: this.projectRoot }
      ).catch(() => ({ stdout: '' }));

      const lines = status.trim().split('\n').filter(Boolean);
      const unstagedFiles = lines
        .filter((l) => l.match(/^[^? ]/))
        .map((l) => l.substring(3));
      const stagedFiles = lines
        .filter((l) => l.match(/^[AMDR]/))
        .map((l) => l.substring(3));

      const recentCommits = log.trim().split('\n').filter(Boolean);

      return {
        hasChanges: lines.length > 0,
        unstagedFiles,
        stagedFiles,
        lastCommit: lastCommit.trim() || undefined,
        recentCommits,
      };
    } catch (error) {
      // Not a git repo or git not available
      return {
        hasChanges: false,
        unstagedFiles: [],
        stagedFiles: [],
        recentCommits: [],
      };
    }
  }

  private async checkPRDCompliance(): Promise<PRDComplianceCheck[]> {
    const checks: PRDComplianceCheck[] = [];
    
    try {
      const prdContent = await readFile(this.prdPath, 'utf-8');
      const serverFiles = await this.getServerFiles();

      // Check key PRD requirements with specific, accurate patterns
      const requirements = [
        {
          section: '5.1',
          requirement: 'Events filtered by expiration (endTime > NOW())',
          pattern: /(endTime\s*>\s*NOW\(\)|startTime\s*>\s*NOW\(\)|WHERE.*endTime.*NOW)/i,
          checkFunction: async (content: string, filePath: string) => {
            // Check for actual SQL WHERE clause or Prisma filter
            const hasFilter = /(endTime|startTime).*>\s*NOW\(\)|where.*endTime|filter.*endTime/i.test(content);
            if (hasFilter && filePath.includes('routes/events.ts')) {
              return { found: true, evidence: 'Event expiration filter found in routes' };
            }
            return { found: false, evidence: 'Event expiration filter not found in routes' };
          },
        },
        {
          section: '7.5',
          requirement: 'DELETE /events/:id endpoint with ownership verification',
          pattern: /router\.delete.*\/:id|DELETE.*events|event\.userId\s*!==|event\.userId\s*===.*authReq/i,
          checkFunction: async (content: string, filePath: string) => {
            // Check for DELETE route in events.ts with ownership check
            if (filePath.includes('routes/events.ts')) {
              const hasDeleteRoute = /router\.delete.*\/:id/i.test(content);
              const hasOwnershipCheck = /event\.userId\s*!==\s*authReq|event\.userId\s*===.*user\.userId/i.test(content);
              const hasAuthMiddleware = /requireAuth|requireAuth/i.test(content);
              
              if (hasDeleteRoute && hasOwnershipCheck && hasAuthMiddleware) {
                return { found: true, evidence: 'DELETE endpoint with ownership verification and auth middleware' };
              } else if (hasDeleteRoute) {
                return { found: false, evidence: 'DELETE route exists but ownership verification may be missing' };
              }
            }
            return { found: false, evidence: 'DELETE /events/:id route not found in routes/events.ts' };
          },
        },
        {
          section: '8',
          requirement: 'Daily cron job for expired events cleanup',
          pattern: /cron|cleanup.*expired|hard-delete.*endTime|cleanupExpiredEvents/i,
          checkFunction: async (content: string, filePath: string) => {
            // Check for cron job file or cron setup
            if (filePath.includes('jobs/cleanupExpiredEvents.ts') || 
                (filePath.includes('index.ts') && /cleanupExpiredEvents|schedule.*cleanup/i.test(content))) {
              return { found: true, evidence: 'Cron job file found' };
            }
            return { found: false, evidence: 'Cleanup cron job not found' };
          },
        },
        {
          section: '7.4',
          requirement: 'Video duration validation (15 seconds max)',
          pattern: /duration.*15|15.*seconds.*video|video.*duration.*validation/i,
        },
        {
          section: '5.1',
          requirement: 'GIST spatial index on location geometry',
          pattern: /GIST|USING GIST|spatial.*index/i,
        },
      ];

      for (const req of requirements) {
        let found = false;
        let evidence = 'Not found in codebase';
        let file: string | undefined;

        // Use custom check function if available, otherwise use pattern matching
        if (req.checkFunction) {
          for (const filePath of serverFiles) {
            try {
              const content = await readFile(filePath, 'utf-8');
              const result = await req.checkFunction(content, filePath);
              if (result.found) {
                found = true;
                file = relative(this.projectRoot, filePath);
                evidence = result.evidence;
                break;
              }
            } catch {
              // Skip files that can't be read
            }
          }
        } else {
          // Fallback to pattern matching
          for (const filePath of serverFiles) {
            try {
              const content = await readFile(filePath, 'utf-8');
              if (req.pattern.test(content)) {
                found = true;
                file = relative(this.projectRoot, filePath);
                const match = content.match(req.pattern);
                evidence = `Found: ${match?.[0] || 'pattern matched'}`;
                break;
              }
            } catch {
              // Skip files that can't be read
            }
          }
        }

        checks.push({
          requirement: req.requirement,
          section: req.section,
          status: found ? 'pass' : 'fail',
          evidence,
          file,
        });
      }
    } catch (error) {
      checks.push({
        requirement: 'PRD file accessible',
        section: 'N/A',
        status: 'fail',
        evidence: `Error reading PRD: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    }

    return checks;
  }

  private async checkGuidelinesCompliance(): Promise<GuidelinesComplianceCheck[]> {
    const checks: GuidelinesComplianceCheck[] = [];
    
    try {
      const guidelinesContent = await readFile(this.guidelinesPath, 'utf-8');
      const serverFiles = await this.getServerFiles();

      // Check security guidelines with better pattern matching
      const testFiles = await this.getTestFiles();
      const testFilePaths = new Set(testFiles.map(f => relative(this.projectRoot, f)));

      const securityPatterns = [
        {
          rule: 'No SQL injection (use parameterized queries)',
          // Exclude template literals that aren't SQL (e.g., `${var}` in TypeScript)
          // Only flag actual SQL string concatenation patterns
          pattern: /(\+\s*['"`]|['"]\s*\+|query\s*[+=].*['"]|sql\s*[+=].*['"])/i,
          shouldNotMatch: true,
          excludeTestFiles: true,
        },
        {
          rule: 'No hardcoded secrets',
          // Only flag in non-test files (test files can have test data)
          pattern: /(password|secret|key|token)\s*[:=]\s*['"][^'"]{10,}/i,
          shouldNotMatch: true,
          excludeTestFiles: true,
        },
        {
          rule: 'No console.log in production code',
          pattern: /console\.log/,
          shouldNotMatch: true,
          warnOnly: true, // Guideline says console.log OK in MVP dev
        },
      ];

      for (const check of securityPatterns) {
        let violations: string[] = [];
        let violationDetails: Array<{ file: string; line: number; snippet: string }> = [];

        for (const filePath of serverFiles) {
          // Skip test files if excludeTestFiles is true
          const relativePath = relative(this.projectRoot, filePath);
          if (check.excludeTestFiles && testFilePaths.has(relativePath)) {
            continue;
          }

          try {
            const content = await readFile(filePath, 'utf-8');
            const lines = content.split('\n');
            
            // Check each line for violations
            lines.forEach((line, index) => {
              if (check.pattern.test(line)) {
                // Additional context: exclude template literals that aren't SQL
                if (check.rule.includes('SQL injection')) {
                  // Skip if it's a template literal that's clearly not SQL
                  if (/^\s*const|^\s*let|^\s*var|console\.|import|export/.test(line) ||
                      /\$\{.*\}/.test(line) && !/\b(sql|query|db|prisma)\.(raw|query|execute)/i.test(line)) {
                    return; // Skip template literals in regular code
                  }
                }
                
                violations.push(relativePath);
                violationDetails.push({
                  file: relativePath,
                  line: index + 1,
                  snippet: line.trim().substring(0, 80),
                });
              }
            });
          } catch {
            // Skip files that can't be read
          }
        }

        // Remove duplicates
        violations = [...new Set(violations)];

        const hasViolations = violations.length > 0 && check.shouldNotMatch;
        
        let evidence = 'No violations found';
        if (hasViolations) {
          const detail = violationDetails[0];
          evidence = `Found in ${violations.length} file(s) (excluding tests): ${violations.slice(0, 3).join(', ')}`;
          if (detail) {
            evidence += ` | Line ${detail.line}: ${detail.snippet}`;
          }
        }

        checks.push({
          rule: check.rule,
          category: 'security',
          status: hasViolations
            ? check.warnOnly
              ? 'warn'
              : 'fail'
            : 'pass',
          evidence,
          file: violations[0],
        });
      }

      // Check code quality guidelines
      checks.push({
        rule: 'ESLint complexity rules enforced',
        category: 'code-quality',
        status: await this.checkFileExists(join(this.projectRoot, 'server', '.eslintrc.cjs'))
          ? 'pass'
          : 'warn',
        evidence: await this.checkFileExists(join(this.projectRoot, 'server', '.eslintrc.cjs'))
          ? '.eslintrc.cjs exists'
          : '.eslintrc.cjs not found',
      });

      checks.push({
        rule: 'Tests exist for critical features',
        category: 'testing',
        status: (await this.getTestFiles()).length > 0 ? 'pass' : 'warn',
        evidence: `${(await this.getTestFiles()).length} test file(s) found`,
      });

    } catch (error) {
      checks.push({
        rule: 'Guidelines file accessible',
        category: 'code-quality',
        status: 'fail',
        evidence: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      });
    }

    return checks;
  }

  private async checkIntentionAlignment(): Promise<IntentionAlignmentCheck[]> {
    const checks: IntentionAlignmentCheck[] = [];
    
    try {
      // Check NEXT_STEPS.md against actual code
      const nextStepsContent = await readFile(this.nextStepsPath, 'utf-8');
      const gitStatus = await this.checkGitStatus();
      
      // Extract tasks from NEXT_STEPS.md
      const taskPattern = /### \d+\.\s+(.+?)(?:\n|$)/g;
      const tasks: string[] = [];
      let match;
      while ((match = taskPattern.exec(nextStepsContent)) !== null) {
        tasks.push(match[1].trim());
      }

      // For each task, check if code exists
      for (const task of tasks.slice(0, 5)) { // Check first 5 tasks
        const serverFiles = await this.getServerFiles();
        let found = false;
        const relatedFiles: string[] = [];

        // Simple keyword matching (could be improved with AI/NLP)
        const keywords = task
          .toLowerCase()
          .replace(/[^\w\s]/g, ' ')
          .split(/\s+/)
          .filter((w) => w.length > 4);

        for (const filePath of serverFiles) {
          try {
            const content = (await readFile(filePath, 'utf-8')).toLowerCase();
            if (keywords.some((kw) => content.includes(kw))) {
              found = true;
              relatedFiles.push(relative(this.projectRoot, filePath));
            }
          } catch {
            // Skip
          }
        }

        checks.push({
          intention: task,
          source: 'NEXT_STEPS.md',
          status: found ? 'aligned' : 'not-implemented',
          evidence: found
            ? `Found related code in ${relatedFiles.length} file(s)`
            : 'No related code found',
          files: relatedFiles.slice(0, 3),
        });
      }

      // Check recent commits for intention alignment
      if (gitStatus.recentCommits.length > 0) {
        const commitMsg = gitStatus.recentCommits[0];
        checks.push({
          intention: commitMsg,
          source: 'git commit',
          status: 'unclear', // Would need diff analysis for better assessment
          evidence: 'Commit message found; code changes need verification',
          files: gitStatus.stagedFiles.length > 0
            ? gitStatus.stagedFiles.slice(0, 3)
            : gitStatus.unstagedFiles.slice(0, 3),
        });
      }
    } catch (error) {
      checks.push({
        intention: 'Read NEXT_STEPS.md',
        source: 'quality-agent',
        status: 'unclear',
        evidence: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
        files: [],
      });
    }

    return checks;
  }

  private async checkCodeQuality(): Promise<CodeQualityCheck[]> {
    const checks: CodeQualityCheck[] = [];

    // Check if lint passes
    try {
      const { stdout, stderr } = await execAsync('npm run lint', {
        cwd: join(this.projectRoot, 'server'),
      }).catch((error) => ({
        stdout: '',
        stderr: error.stderr || error.message,
      }));

      const hasErrors = stderr.includes('error') || stdout.includes('error');
      checks.push({
        rule: 'ESLint passes',
        severity: 'error',
        status: hasErrors ? 'fail' : 'pass',
        evidence: hasErrors ? 'ESLint errors found' : 'ESLint passes',
      });
    } catch {
      checks.push({
        rule: 'ESLint runs successfully',
        severity: 'warning',
        status: 'warn',
        evidence: 'Could not run ESLint',
      });
    }

    // Check if tests pass
    try {
      const { stdout, stderr } = await execAsync('npm run test 2>&1', {
        cwd: join(this.projectRoot, 'server'),
        timeout: 30000, // 30 second timeout
      }).catch((error) => ({
        stdout: error.stdout || '',
        stderr: error.stderr || error.message,
      }));

      const hasFailures = stderr.includes('FAIL') || stdout.includes('FAIL') || 
                         stderr.includes('failing') || stdout.includes('failing');
      checks.push({
        rule: 'Tests pass',
        severity: 'error',
        status: hasFailures ? 'fail' : 'pass',
        evidence: hasFailures ? 'Test failures found' : 'Tests pass',
      });
    } catch {
      checks.push({
        rule: 'Tests run successfully',
        severity: 'warning',
        status: 'warn',
        evidence: 'Could not run tests (may be expected in development)',
      });
    }

    return checks;
  }

  private generateSummary(data: {
    prdCompliance: PRDComplianceCheck[];
    guidelinesCompliance: GuidelinesComplianceCheck[];
    intentionAlignment: IntentionAlignmentCheck[];
    codeQuality: CodeQualityCheck[];
  }): QualitySummary {
    const allChecks = [
      ...data.prdCompliance,
      ...data.guidelinesCompliance,
      ...data.codeQuality,
    ];

    const failed = allChecks.filter((c) => c.status === 'fail').length;
    const warnings = allChecks.filter((c) => c.status === 'warn').length;
    const passed = allChecks.filter((c) => c.status === 'pass').length;

    const criticalIssues = [
      ...allChecks
        .filter((c) => c.status === 'fail' && 'severity' in c && c.severity === 'error')
        .map((c) => c.rule || c.requirement),
      ...data.intentionAlignment
        .filter((c) => c.status === 'not-implemented')
        .map((c) => `Not implemented: ${c.intention}`),
    ];

    const overall =
      failed > 0 ? 'fail' : warnings > 0 ? 'warn' : 'pass';

    return {
      totalChecks: allChecks.length + data.intentionAlignment.length,
      passed,
      failed,
      warnings,
      overall,
      criticalIssues,
    };
  }

  private async getServerFiles(): Promise<string[]> {
    const serverDir = join(this.projectRoot, 'server', 'src');
    return this.getAllFiles(serverDir, ['.ts', '.js']);
  }

  private async getTestFiles(): Promise<string[]> {
    const testDir = join(this.projectRoot, 'server', 'src', 'tests');
    return this.getAllFiles(testDir, ['.test.ts', '.test.js', '.spec.ts', '.spec.js']);
  }

  private async getAllFiles(dir: string, extensions: string[]): Promise<string[]> {
    const files: string[] = [];

    try {
      const entries = await readdir(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = join(dir, entry.name);
        if (entry.isDirectory()) {
          files.push(...(await this.getAllFiles(fullPath, extensions)));
        } else if (entry.isFile()) {
          if (extensions.some((ext) => entry.name.endsWith(ext))) {
            files.push(fullPath);
          }
        }
      }
    } catch {
      // Directory doesn't exist or can't be read
    }

    return files;
  }

  private async checkFileExists(filePath: string): Promise<boolean> {
    try {
      await stat(filePath);
      return true;
    } catch {
      return false;
    }
  }

  generateReport(report: QualityReport): string {
    const lines: string[] = [];
    
    lines.push('═'.repeat(80));
    lines.push('  QUALITY CONTROL REPORT');
    lines.push('═'.repeat(80));
    lines.push(`Timestamp: ${report.timestamp}\n`);

    // Summary
    lines.push('📊 SUMMARY');
    lines.push('-'.repeat(80));
    lines.push(`Overall Status: ${report.summary.overall.toUpperCase()}`);
    lines.push(`Total Checks: ${report.summary.totalChecks}`);
    lines.push(`✅ Passed: ${report.summary.passed}`);
    lines.push(`❌ Failed: ${report.summary.failed}`);
    lines.push(`⚠️  Warnings: ${report.summary.warnings}\n`);

    if (report.summary.criticalIssues.length > 0) {
      lines.push('🚨 CRITICAL ISSUES:');
      report.summary.criticalIssues.forEach((issue) => {
        lines.push(`   • ${issue}`);
      });
      lines.push('');
    }

    // Git Status
    lines.push('📝 GIT STATUS');
    lines.push('-'.repeat(80));
    lines.push(`Has Changes: ${report.gitStatus.hasChanges ? 'Yes' : 'No'}`);
    if (report.gitStatus.stagedFiles.length > 0) {
      lines.push(`Staged Files: ${report.gitStatus.stagedFiles.length}`);
      report.gitStatus.stagedFiles.slice(0, 3).forEach((f) => {
        lines.push(`   • ${f}`);
      });
    }
    if (report.gitStatus.lastCommit) {
      lines.push(`Last Commit: ${report.gitStatus.lastCommit}`);
    }
    lines.push('');

    // PRD Compliance
    if (report.prdCompliance.length > 0) {
      lines.push('📋 PRD COMPLIANCE');
      lines.push('-'.repeat(80));
      report.prdCompliance.forEach((check) => {
        const icon = check.status === 'pass' ? '✅' : check.status === 'fail' ? '❌' : '⚠️';
        lines.push(`${icon} [${check.section}] ${check.requirement}`);
        lines.push(`   Status: ${check.status.toUpperCase()}`);
        lines.push(`   Evidence: ${check.evidence}`);
        if (check.file) {
          lines.push(`   File: ${check.file}`);
        }
        lines.push('');
      });
    }

    // Guidelines Compliance
    if (report.guidelinesCompliance.length > 0) {
      lines.push('📚 GUIDELINES COMPLIANCE');
      lines.push('-'.repeat(80));
      report.guidelinesCompliance.forEach((check) => {
        const icon = check.status === 'pass' ? '✅' : check.status === 'fail' ? '❌' : '⚠️';
        lines.push(`${icon} [${check.category}] ${check.rule}`);
        lines.push(`   Status: ${check.status.toUpperCase()}`);
        lines.push(`   Evidence: ${check.evidence}`);
        if (check.file) {
          lines.push(`   File: ${check.file}`);
        }
        lines.push('');
      });
    }

    // Intention Alignment
    if (report.intentionAlignment.length > 0) {
      lines.push('🎯 INTENTION ALIGNMENT');
      lines.push('-'.repeat(80));
      report.intentionAlignment.forEach((check) => {
        const icon =
          check.status === 'aligned'
            ? '✅'
            : check.status === 'not-implemented'
            ? '❌'
            : '⚠️';
        lines.push(`${icon} ${check.intention}`);
        lines.push(`   Source: ${check.source}`);
        lines.push(`   Status: ${check.status.toUpperCase()}`);
        lines.push(`   Evidence: ${check.evidence}`);
        if (check.files.length > 0) {
          lines.push(`   Files: ${check.files.join(', ')}`);
        }
        lines.push('');
      });
    }

    // Code Quality
    if (report.codeQuality.length > 0) {
      lines.push('🔧 CODE QUALITY');
      lines.push('-'.repeat(80));
      report.codeQuality.forEach((check) => {
        const icon = check.status === 'pass' ? '✅' : check.status === 'fail' ? '❌' : '⚠️';
        lines.push(`${icon} ${check.rule}`);
        lines.push(`   Severity: ${check.severity.toUpperCase()}`);
        lines.push(`   Status: ${check.status.toUpperCase()}`);
        lines.push(`   Evidence: ${check.evidence}`);
        lines.push('');
      });
    }

    lines.push('═'.repeat(80));

    return lines.join('\n');
  }
}

// Main execution
const isMainModule = import.meta.url === `file://${process.argv[1]}` ||
                     import.meta.url.endsWith('quality-agent.ts');

if (isMainModule) {
  (async () => {
    const agent = new QualityAgent();
    try {
      const report = await agent.run();
      const reportText = agent.generateReport(report);
      console.log(reportText);
      
      // Write to file
      const fs = await import('fs/promises');
      const reportPath = join(process.cwd(), 'quality-report.txt');
      await fs.writeFile(reportPath, reportText, 'utf-8');
      console.log(`\n📄 Report saved to: ${reportPath}`);
      
      process.exit(report.summary.overall === 'fail' ? 1 : 0);
    } catch (error) {
      console.error('❌ Quality Agent Error:', error);
      process.exit(1);
    }
  })();
}

export { QualityAgent, type QualityReport };
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

import { readFile, readdir, stat, access } from 'fs/promises';
import { join, dirname, relative } from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';
import { promisify } from 'util';
import { constants } from 'fs';

const execAsync = promisify(exec);
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

type Tier = 1 | 2 | 3;

interface QualityReport {
  timestamp: string;
  gitStatus: GitStatus;
  prdCompliance: PRDComplianceCheck[];
  guidelinesCompliance: GuidelinesComplianceCheck[];
  intentionAlignment: IntentionAlignmentCheck[];
  codeQuality: CodeQualityCheck[];
  iosBuildStatus: IOSBuildCheck[];
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

interface IOSBuildCheck {
  check: string;
  status: 'pass' | 'fail' | 'warn';
  evidence: string;
  file?: string;
  error?: string;
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
    // PRD-TestFlight.md is the authoritative PRD (may be in Downloads or project root)
    this.prdPath = join(projectRoot, 'PRD-TestFlight.md');
    // Fallback to PRD.txt if PRD-TestFlight.md not found (check async in run method)
    this.guidelinesPath = join(projectRoot, 'guidelines.txt');
    this.nextStepsPath = join(projectRoot, 'NEXT_STEPS.md');
    this.codeQualityPath = join(projectRoot, 'server', 'CODE_QUALITY.md');
  }

  private async checkPRDFileExists(): Promise<string> {
    // Check if PRD-TestFlight.md exists, fallback to PRD.txt
    try {
      await access(this.prdPath, constants.F_OK);
      return this.prdPath;
    } catch {
      const fallbackPath = join(this.projectRoot, 'PRD.txt');
      try {
        await access(fallbackPath, constants.F_OK);
        return fallbackPath;
      } catch {
        return this.prdPath; // Return original path even if not found (will error later)
      }
    }
  }

  async run(options?: { tier?: Tier }): Promise<QualityReport> {
    const tier: Tier = options?.tier ?? 2;

    console.log('🔍 Quality Control Agent - Starting analysis...\n');
    console.log(`📋 Focus: PRD Compliance & Guidelines Validation (Tier ${tier})\n`);

    const gitStatus = await this.checkGitStatus();
    const prdCompliance = await this.checkPRDCompliance();
    const guidelinesCompliance = await this.checkGuidelinesCompliance();
    // Intention alignment is optional - NEXT_STEPS.md may be outdated
    const intentionAlignment = []; // Skip NEXT_STEPS alignment for now
    const codeQuality = await this.checkCodeQuality({ tier });
    const iosBuildStatus = tier === 3 ? await this.checkIOSBuildStatus() : [];

    const summary = this.generateSummary({
      prdCompliance,
      guidelinesCompliance,
      intentionAlignment,
      codeQuality,
      iosBuildStatus,
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
      iosBuildStatus,
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
      // Check which PRD file exists
      const actualPRDPath = await this.checkPRDFileExists();
      const prdContent = await readFile(actualPRDPath, 'utf-8');
      const serverFiles = await this.getServerFiles();

      // Check key PRD-TestFlight.md requirements with specific, accurate patterns
      const requirements = [
        {
          section: '5.1 (PRD-TestFlight)',
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
          section: '4.3 (PRD-TestFlight)',
          requirement: 'DELETE /events/:id endpoint with ownership verification',
          pattern: /router\.delete.*\/:id|DELETE.*events|event\.userId\s*!==|event\.userId\s*===.*authReq/i,
          checkFunction: async (content: string, filePath: string) => {
            // Check for DELETE route in events.ts with ownership check
            if (filePath.includes('routes/events.ts') || filePath.endsWith('routes/events.ts')) {
              const hasDeleteRoute = /router\.delete\s*\([^)]*\/:id|router\.delete\s*\([\s\S]*?'\/:id'/i.test(content);
              const hasOwnershipCheck = /event\.userId\s*!==\s*authReq\.user\.userId/i.test(content);
              const hasAuthMiddleware = /requireAuth/i.test(content);
              
              if (hasDeleteRoute && hasOwnershipCheck && hasAuthMiddleware) {
                return { found: true, evidence: 'DELETE endpoint with ownership verification and auth middleware' };
              } else if (hasDeleteRoute) {
                const missingParts: string[] = [];
                if (!hasOwnershipCheck) missingParts.push('ownership check');
                if (!hasAuthMiddleware) missingParts.push('auth middleware');
                return { found: false, evidence: `DELETE route exists but missing: ${missingParts.join(', ')}` };
              }
            }
            return { found: false, evidence: 'DELETE /events/:id route not found in routes/events.ts' };
          },
        },
        {
          section: '8 (PRD-TestFlight)',
          requirement: 'Daily cron job for expired events cleanup',
          pattern: /cron|cleanup.*expired|hard-delete.*endTime|cleanupExpiredEvents/i,
          checkFunction: async (content: string, filePath: string) => {
            if (filePath.includes('jobs/cleanupExpiredEvents.ts') || 
                (filePath.includes('index.ts') && /cleanupExpiredEvents|schedule.*cleanup/i.test(content))) {
              return { found: true, evidence: 'Cron job file found' };
            }
            return { found: false, evidence: 'Cleanup cron job not found' };
          },
        },
        {
          section: '4.1 (PRD-TestFlight)',
          requirement: 'Video duration validation (15 seconds max)',
          pattern: /duration.*15|15.*seconds.*video|video.*duration.*validation/i,
        },
        {
          section: '7 (PRD-TestFlight)',
          requirement: 'GIST spatial index on location geometry',
          pattern: /GIST|USING GIST|spatial.*index/i,
        },
        {
          section: '5.3 (PRD-TestFlight)',
          requirement: 'Interested endpoint (not Like) - PRD uses "Interested" terminology',
          pattern: /\/interested|interestedCount|POST.*\/events\/:id\/interested/i,
          checkFunction: async (content: string, filePath: string) => {
            // Check for "interested" endpoint, not "like"
            if (filePath.includes('routes/interactions.ts') || filePath.includes('routes/events.ts')) {
              const hasInterested = /\/interested|interestedCount|POST.*\/events\/:id\/interested/i.test(content);
              const hasLike = /\/like|likesCount|POST.*\/events\/:id\/like/i.test(content);
              if (hasInterested) {
                return { found: true, evidence: 'Interested endpoint found (PRD-compliant)' };
              } else if (hasLike) {
                return { found: false, evidence: 'Like endpoint found but PRD requires "Interested" terminology' };
              }
            }
            return { found: false, evidence: 'Interested endpoint not found - PRD requires "Interested", not "Like"' };
          },
        },
        {
          section: '6 (PRD-TestFlight)',
          requirement: 'Following system endpoints (follow/unfollow)',
          pattern: /\/follow|POST.*\/users\/:id\/follow|DELETE.*\/users\/:id\/follow/i,
        },
        {
          section: '7 (PRD-TestFlight)',
          requirement: 'Plans feature endpoints (create, add event, archive)',
          pattern: /\/plans|POST.*\/plans|POST.*\/plans\/:id\/events/i,
        },
        {
          section: '4.1 (PRD-TestFlight)',
          requirement: 'Signed URL upload endpoint for direct client uploads',
          pattern: /\/signed-url|GET.*\/upload\/signed-url|createSignedUploadUrl/i,
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
              } else if (result.evidence && result.evidence !== 'Not found in codebase') {
                // If checkFunction ran but didn't find it, use its evidence instead of default
                // This helps with debugging
                evidence = result.evidence;
              }
            } catch (error) {
              // Skip files that can't be read, but log in debug
              // console.error(`Error reading ${filePath}:`, error);
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
        requirement: 'PRD-TestFlight.md file accessible',
        section: 'N/A',
        status: 'fail',
        evidence: `Error reading PRD: ${error instanceof Error ? error.message : 'Unknown error'}. Looking for PRD-TestFlight.md or PRD.txt`,
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

  private async checkCodeQuality(options: { tier: Tier }): Promise<CodeQualityCheck[]> {
    const { tier } = options;
    const checks: CodeQualityCheck[] = [];

    // Tier 1: keep this fast and let ImplementationVerifier handle quick TS/lint checks.
    if (tier === 1) {
      return checks;
    }

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

  private async checkIOSBuildStatus(): Promise<IOSBuildCheck[]> {
    const checks: IOSBuildCheck[] = [];
    const iosProjectPath = join(this.projectRoot, 'ios', 'BarrioCursor', 'BarrioCursor.xcodeproj');
    
    // Check if Xcode project exists
    const projectExists = await this.checkFileExists(iosProjectPath);
    
    if (!projectExists) {
      checks.push({
        check: 'Xcode project exists',
        status: 'warn',
        evidence: 'Xcode project not found at expected path',
      });
      return checks;
    }

    // Check for Swift compilation errors (scan Swift files for syntax issues)
    const swiftFiles = await this.getAllFiles(
      join(this.projectRoot, 'ios', 'BarrioCursor'),
      ['.swift']
    );

    // Look for common Swift syntax errors in key files
    const criticalSwiftFiles = [
      'CreateEventView.swift',
      'EventDetailView.swift',
      'LocationManager.swift',
    ];

    for (const fileName of criticalSwiftFiles) {
      const filePath = swiftFiles.find(f => f.includes(fileName));
      if (filePath) {
        try {
          const content = await readFile(filePath, 'utf-8');
          const relativePath = relative(this.projectRoot, filePath);
          
          // Check for common Swift errors that would prevent building
          // Check for .onChange syntax issues (the current error from build log)
          // Pattern: .onChange(of: var) { param in - might be incompatible with iOS 17+
          const onChangePattern = /\.onChange\(of:\s*(\w+)\)\s*\{\s*(\w+)\s+in/g;
          const matches = Array.from(content.matchAll(onChangePattern));
          if (matches.length > 0) {
            const firstMatch = matches[0];
            const lineNum = content.substring(0, firstMatch.index || 0).split('\n').length;
            checks.push({
              check: `Swift compilation: .onChange closure in ${fileName}`,
              status: 'fail',
              evidence: `.onChange(of:) with closure parameter may be incompatible - check SwiftUI API (iOS 17+) | Line ~${lineNum}`,
              file: relativePath,
              error: 'Contextual closure type expects 0 arguments, but 1 was used',
            });
          }
          
          // Check for deprecated CLGeocoder usage (from error log)
          if (content.includes('CLGeocoder()')) {
            checks.push({
              check: 'iOS API deprecation: CLGeocoder',
              status: 'warn',
              evidence: 'CLGeocoder is deprecated in iOS 26.0 - should use MapKit instead (PRD: Section 3 location fallback)',
              file: relativePath,
            });
          }

          // Check for common Swift API misuse patterns
          // PhotosPickerItem.identifier doesn't exist (current error)
          if (content.includes('PhotosPickerItem') && content.includes('.identifier')) {
            const lineNum = content.split('\n').findIndex((line, idx) => {
              const lineContent = line.includes('PhotosPickerItem') && line.includes('.identifier');
              return lineContent;
            }) + 1;
            checks.push({
              check: 'Swift API misuse: PhotosPickerItem.identifier',
              status: 'fail',
              evidence: 'PhotosPickerItem has no member "identifier" - verify API documentation for correct property/method | Line ~' + lineNum,
              file: relativePath,
              error: 'Value of type PhotosPickerItem has no member identifier',
            });
          }
          
          // Check for basic Swift syntax errors
          const openBraces = (content.match(/\{/g) || []).length;
          const closeBraces = (content.match(/\}/g) || []).length;
          if (openBraces !== closeBraces) {
            checks.push({
              check: `Swift syntax: brace mismatch in ${fileName}`,
              status: 'fail',
              evidence: `Mismatched braces: ${openBraces} open, ${closeBraces} close`,
              file: relativePath,
            });
          }
          
        } catch (error) {
          // Skip files that can't be read
        }
      }
    }

    // General check: Key iOS files exist per PRD-TestFlight.md requirements
    const requiredIOSFiles = [
      'BarrioCursorApp.swift',
      'ContentView.swift',
      'MainTabView.swift',
      'Views/Map/MapView.swift',
      'Views/Feed/FeedView.swift',
      'Views/Event/CreateEventView.swift',
      'Views/Event/EventDetailView.swift',
      'Services/LocationManager.swift',
      'Services/APIService.swift',
      'Config/AppConfig.swift',
      // PRD-TestFlight.md Section 6: Social features
      'Views/Profile/ProfileView.swift', // Required for user profiles
      // PRD-TestFlight.md Section 7: Plans feature (may not exist yet)
      // 'Views/Plans/PlansView.swift', // Optional - Plans feature
    ];

    let missingFiles: string[] = [];
    for (const requiredFile of requiredIOSFiles) {
      const fullPath = join(this.projectRoot, 'ios', 'BarrioCursor', 'BarrioCursor', requiredFile);
      if (!(await this.checkFileExists(fullPath))) {
        missingFiles.push(requiredFile);
      }
    }

    if (missingFiles.length > 0) {
      checks.push({
        check: 'iOS app structure (PRD-TestFlight.md Section 8)',
        status: 'fail',
        evidence: `Missing required files: ${missingFiles.slice(0, 3).join(', ')}${missingFiles.length > 3 ? '...' : ''}`,
      });
    } else {
      checks.push({
        check: 'iOS app structure (PRD-TestFlight.md Section 8)',
        status: 'pass',
        evidence: 'All required iOS files present',
      });
    }

    // Check Info.plist for required permissions (PRD: Section 3 location)
    const infoPlistPath = join(this.projectRoot, 'ios', 'BarrioCursor', 'BarrioCursor', 'Info.plist');
    if (await this.checkFileExists(infoPlistPath)) {
      try {
        const plistContent = await readFile(infoPlistPath, 'utf-8');
        const hasLocationPermission = plistContent.includes('NSLocationWhenInUseUsageDescription');
        const hasPhotoPermission = plistContent.includes('NSPhotoLibraryUsageDescription');
        
        if (!hasLocationPermission) {
          checks.push({
            check: 'iOS permissions: Location (PRD-TestFlight.md Section 2.1)',
            status: 'fail',
            evidence: 'NSLocationWhenInUseUsageDescription missing in Info.plist',
            file: 'Info.plist',
          });
        } else {
          checks.push({
            check: 'iOS permissions: Location (PRD-TestFlight.md Section 2.1)',
            status: 'pass',
            evidence: 'Location permission configured',
          });
        }

        if (!hasPhotoPermission) {
          checks.push({
            check: 'iOS permissions: Photos (PRD-TestFlight.md Section 4.1 media)',
            status: 'warn',
            evidence: 'NSPhotoLibraryUsageDescription missing (needed for event media)',
            file: 'Info.plist',
          });
        }
      } catch {
        // Skip if can't read plist
      }
    }

    return checks;
  }

  private generateSummary(data: {
    prdCompliance: PRDComplianceCheck[];
    guidelinesCompliance: GuidelinesComplianceCheck[];
    intentionAlignment: IntentionAlignmentCheck[];
    codeQuality: CodeQualityCheck[];
    iosBuildStatus: IOSBuildCheck[];
  }): QualitySummary {
    const allChecks = [
      ...data.prdCompliance,
      ...data.guidelinesCompliance,
      ...data.codeQuality,
    ];

    const failed = allChecks.filter((c) => c.status === 'fail').length;
    const warnings = allChecks.filter((c) => c.status === 'warn').length;
    const passed = allChecks.filter((c) => c.status === 'pass').length;

    // Focus on PRD, Guidelines, and iOS build failures as critical issues
    const criticalIssues = [
      ...data.prdCompliance
        .filter((c) => c.status === 'fail')
        .map((c) => `PRD [${c.section}]: ${c.requirement}`),
      ...data.guidelinesCompliance
        .filter((c) => c.status === 'fail' && c.category === 'security')
        .map((c) => `Security: ${c.rule}`),
      ...data.codeQuality
        .filter((c) => c.status === 'fail' && c.severity === 'error')
        .map((c) => c.rule),
      ...data.iosBuildStatus
        .filter((c) => c.status === 'fail')
        .map((c) => `iOS Build: ${c.check}${c.file ? ` (${c.file})` : ''}`),
    ];

    const overall =
      failed > 0 ? 'fail' : warnings > 0 ? 'warn' : 'pass';

    return {
      totalChecks: allChecks.length, // Focus on PRD, Guidelines, Code Quality only
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

    // Intention Alignment (optional - NEXT_STEPS.md may be outdated)
    if (report.intentionAlignment.length > 0) {
      lines.push('🎯 INTENTION ALIGNMENT (Optional - NEXT_STEPS.md may be outdated)');
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

    // iOS Build Status
    if (report.iosBuildStatus.length > 0) {
      lines.push('📱 iOS BUILD STATUS (PRD-TestFlight.md: TestFlight-ready MVP)');
      lines.push('-'.repeat(80));
      report.iosBuildStatus.forEach((check) => {
        const icon = check.status === 'pass' ? '✅' : check.status === 'fail' ? '❌' : '⚠️';
        lines.push(`${icon} ${check.check}`);
        lines.push(`   Status: ${check.status.toUpperCase()}`);
        lines.push(`   Evidence: ${check.evidence}`);
        if (check.file) {
          lines.push(`   File: ${check.file}`);
        }
        if (check.error) {
          lines.push(`   Error: ${check.error}`);
        }
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
      
      // Write to file - use __dirname which points to quality-control/, so go up one level
      const fs = await import('fs/promises');
      const reportPath = join(__dirname, '..', 'quality-report.txt');
      await fs.writeFile(reportPath, reportText, 'utf-8');
      console.log(`\n📄 Report saved to: ${reportPath}`);
      
      process.exit(report.summary.overall === 'fail' ? 1 : 0);
    } catch (error) {
      console.error('❌ Quality Agent Error:', error);
      // Still try to write error to file so user knows something went wrong
      try {
        const fs = await import('fs/promises');
        const reportPath = join(__dirname, '..', 'quality-report.txt');
        const errorMessage = `❌ Quality Agent Error: ${error instanceof Error ? error.message : String(error)}\n\nCheck console output for details.\n\nTimestamp: ${new Date().toISOString()}`;
        await fs.writeFile(reportPath, errorMessage, 'utf-8');
        console.log(`\n⚠️  Error saved to: ${reportPath}`);
      } catch {
        // Ignore write errors
      }
      process.exit(1);
    }
  })();
}

export { QualityAgent, type QualityReport };
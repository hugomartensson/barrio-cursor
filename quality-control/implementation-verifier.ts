#!/usr/bin/env tsx

/**
 * Implementation Verifier
 * 
 * This agent verifies that what was promised in chat/commits was actually implemented:
 * 1. What was said would be done → Actually done?
 * 2. Is it done fully? (not partially)
 * 3. Does it work as intended?
 * 
 * Run this after major work sessions to verify implementation completeness.
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

interface ImplementationCheck {
  feature: string;
  source: string; // "commit message" or "chat intention"
  status: 'complete' | 'partial' | 'missing' | 'broken';
  evidence: string;
  files: string[];
  issues: string[];
}

type Tier = 1 | 2 | 3;

interface VerificationReport {
  timestamp: string;
  gitStatus: {
    lastCommit?: string;
    recentCommits: string[];
    changedFiles: string[];
  };
  implementationChecks: ImplementationCheck[];
  completenessChecks: CompletenessCheck[];
  functionalityChecks: FunctionalityCheck[];
  summary: {
    totalChecks: number;
    complete: number;
    partial: number;
    missing: number;
    broken: number;
    overall: 'pass' | 'fail' | 'warn';
    criticalIssues: string[];
  };
}

interface CompletenessCheck {
  feature: string;
  requiredComponents: string[];
  foundComponents: string[];
  missingComponents: string[];
  status: 'complete' | 'partial' | 'missing';
}

interface FunctionalityCheck {
  check: string;
  status: 'pass' | 'fail' | 'warn';
  evidence: string;
  error?: string;
}

class ImplementationVerifier {
  private projectRoot: string;

  constructor(projectRoot: string = join(__dirname, '..')) {
    this.projectRoot = projectRoot;
  }

  async verify(options?: { tier?: Tier }): Promise<VerificationReport> {
    const tier: Tier = options?.tier ?? 2;

    console.log('🔍 Implementation Verifier - Starting verification...\n');
    console.log(`📋 Verifying: What was promised → What was delivered (Tier ${tier})\n`);

    const gitStatus = await this.checkGitStatus();
    const implementationChecks =
      tier >= 2 ? await this.checkImplementationFromCommits() : [];
    const completenessChecks = tier >= 2 ? await this.checkCompleteness() : [];
    const functionalityChecks = await this.checkFunctionality({ tier });

    const summary = this.generateSummary({
      implementationChecks,
      completenessChecks,
      functionalityChecks,
    });

    const timestamp = new Date().toISOString();

    return {
      timestamp,
      gitStatus,
      implementationChecks,
      completenessChecks,
      functionalityChecks,
      summary,
    };
  }

  private async checkGitStatus() {
    try {
      const { stdout: log } = await execAsync('git log --oneline -10', {
        cwd: this.projectRoot,
      });
      const { stdout: diff } = await execAsync('git diff --name-only HEAD', {
        cwd: this.projectRoot,
      }).catch(() => ({ stdout: '' }));
      const { stdout: lastCommit } = await execAsync(
        'git log -1 --pretty=format:"%h %s"',
        { cwd: this.projectRoot }
      ).catch(() => ({ stdout: '' }));

      return {
        lastCommit: lastCommit.trim() || undefined,
        recentCommits: log.trim().split('\n').filter(Boolean),
        changedFiles: diff.trim().split('\n').filter(Boolean),
      };
    } catch {
      return {
        lastCommit: undefined,
        recentCommits: [],
        changedFiles: [],
      };
    }
  }

  private async checkImplementationFromCommits(): Promise<ImplementationCheck[]> {
    const checks: ImplementationCheck[] = [];
    
    try {
      const gitStatus = await this.checkGitStatus();
      
      // Extract intentions from recent commits
      for (const commit of gitStatus.recentCommits.slice(0, 5)) {
        const commitMsg = commit.substring(commit.indexOf(' ') + 1); // Remove hash
        
        // Parse commit message for feature keywords
        const features = this.extractFeaturesFromCommit(commitMsg);
        
        for (const feature of features) {
          const check = await this.verifyFeatureImplementation(feature, commitMsg);
          checks.push(check);
        }
      }
    } catch (error) {
      checks.push({
        feature: 'Git status check',
        source: 'verifier',
        status: 'broken',
        evidence: `Error reading git status: ${error instanceof Error ? error.message : 'Unknown error'}`,
        files: [],
        issues: ['Could not read git commits'],
      });
    }

    return checks;
  }

  private extractFeaturesFromCommit(commitMsg: string): string[] {
    const features: string[] = [];
    
    // Common feature patterns
    const patterns = [
      { pattern: /(?:add|implement|create).*interested/i, feature: 'Interested endpoint' },
      { pattern: /(?:add|implement|create).*plan/i, feature: 'Plans feature' },
      { pattern: /(?:add|implement|create).*follow/i, feature: 'Following system' },
      { pattern: /(?:add|implement|create).*event.*edit/i, feature: 'Event edit' },
      { pattern: /(?:add|implement|create).*address/i, feature: 'Address field' },
      { pattern: /(?:add|implement|create).*private.*account/i, feature: 'Private accounts' },
      { pattern: /(?:add|implement|create).*story.*viewer/i, feature: 'Story viewer' },
      { pattern: /(?:add|implement|create).*text.*overlay/i, feature: 'Text overlay' },
      { pattern: /(?:fix|update).*terminology/i, feature: 'Terminology update' },
      { pattern: /(?:migrate|update).*database/i, feature: 'Database migration' },
    ];

    for (const { pattern, feature } of patterns) {
      if (pattern.test(commitMsg)) {
        features.push(feature);
      }
    }

    return features;
  }

  private async verifyFeatureImplementation(
    feature: string,
    source: string
  ): Promise<ImplementationCheck> {
    const check: ImplementationCheck = {
      feature,
      source,
      status: 'missing',
      evidence: '',
      files: [],
      issues: [],
    };

    switch (feature) {
      case 'Interested endpoint':
        return await this.verifyInterestedEndpoint(check);
      case 'Plans feature':
        return await this.verifyPlansFeature(check);
      case 'Following system':
        return await this.verifyFollowingSystem(check);
      case 'Event edit':
        return await this.verifyEventEdit(check);
      case 'Address field':
        return await this.verifyAddressField(check);
      case 'Private accounts':
        return await this.verifyPrivateAccounts(check);
      case 'Story viewer':
        return await this.verifyStoryViewer(check);
      case 'Text overlay':
        return await this.verifyTextOverlay(check);
      case 'Terminology update':
        return await this.verifyTerminologyUpdate(check);
      case 'Database migration':
        return await this.verifyDatabaseMigration(check);
      default:
        check.evidence = 'Unknown feature - cannot verify';
        return check;
    }
  }

  private async verifyInterestedEndpoint(
    check: ImplementationCheck
  ): Promise<ImplementationCheck> {
    const serverFiles = await this.getServerFiles();
    let foundEndpoint = false;
    let foundTable = false;
    let foundField = false;
    const files: string[] = [];

    // Check for endpoint
    for (const file of serverFiles) {
      if (file.includes('routes/interactions.ts') || file.includes('routes/events.ts')) {
        const content = await readFile(file, 'utf-8');
        if (/POST.*\/events\/:id\/interested|router\.post.*\/interested/i.test(content)) {
          foundEndpoint = true;
          files.push(relative(this.projectRoot, file));
        }
        if (/\/like|likesCount/i.test(content)) {
          check.issues.push('Found old "Like" terminology - should be "Interested"');
        }
      }
    }

    // Check for database table
    const schemaPath = join(this.projectRoot, 'server', 'prisma', 'schema.prisma');
    try {
      const schema = await readFile(schemaPath, 'utf-8');
      if (/model Interested/i.test(schema)) {
        foundTable = true;
        files.push('server/prisma/schema.prisma');
      }
      if (/model Like/i.test(schema)) {
        check.issues.push('Found old "Like" table - should be migrated to "Interested"');
      }
      if (/interestedCount/i.test(schema)) {
        foundField = true;
      }
    } catch {
      check.issues.push('Could not read Prisma schema');
    }

    if (foundEndpoint && foundTable && foundField) {
      check.status = 'complete';
      check.evidence = 'Interested endpoint, table, and field found';
    } else if (foundEndpoint || foundTable || foundField) {
      check.status = 'partial';
      check.evidence = `Partial: endpoint=${foundEndpoint}, table=${foundTable}, field=${foundField}`;
    } else {
      check.status = 'missing';
      check.evidence = 'Interested endpoint not found';
    }

    check.files = files;
    return check;
  }

  private async verifyPlansFeature(
    check: ImplementationCheck
  ): Promise<ImplementationCheck> {
    const requiredComponents = [
      'Database table: Plan',
      'Database table: PlanEvent',
      'Backend endpoint: POST /api/plans',
      'Backend endpoint: GET /api/plans',
      'Backend endpoint: POST /api/plans/:id/events/:eventId',
      'iOS view: PlansView or PlansListView',
      'iOS view: PlanDetailView',
    ];

    const foundComponents: string[] = [];
    const files: string[] = [];

    // Check database schema
    const schemaPath = join(this.projectRoot, 'server', 'prisma', 'schema.prisma');
    try {
      const schema = await readFile(schemaPath, 'utf-8');
      if (/model Plan\s*\{/i.test(schema)) {
        foundComponents.push('Database table: Plan');
        files.push('server/prisma/schema.prisma');
      }
      if (/model PlanEvent\s*\{/i.test(schema)) {
        foundComponents.push('Database table: PlanEvent');
      }
    } catch {
      check.issues.push('Could not read Prisma schema');
    }

    // Check backend endpoints
    const serverFiles = await this.getServerFiles();
    for (const file of serverFiles) {
      if (file.includes('routes/plans.ts')) {
        const content = await readFile(file, 'utf-8');
        if (/router\.post.*\/plans/i.test(content)) {
          foundComponents.push('Backend endpoint: POST /api/plans');
        }
        if (/router\.get.*\/plans/i.test(content)) {
          foundComponents.push('Backend endpoint: GET /api/plans');
        }
        if (/router\.post.*\/plans\/:id\/events/i.test(content)) {
          foundComponents.push('Backend endpoint: POST /api/plans/:id/events/:eventId');
        }
        files.push(relative(this.projectRoot, file));
      }
    }

    // Check iOS views
    const iosFiles = await this.getIOSFiles();
    for (const file of iosFiles) {
      if (file.includes('Plans') && file.endsWith('.swift')) {
        if (file.includes('PlansView') || file.includes('PlansListView')) {
          foundComponents.push('iOS view: PlansView or PlansListView');
        }
        if (file.includes('PlanDetailView')) {
          foundComponents.push('iOS view: PlanDetailView');
        }
        files.push(relative(this.projectRoot, file));
      }
    }

    const missingComponents = requiredComponents.filter(
      (c) => !foundComponents.includes(c)
    );

    if (missingComponents.length === 0) {
      check.status = 'complete';
      check.evidence = 'All required components found';
    } else if (foundComponents.length > 0) {
      check.status = 'partial';
      check.evidence = `Found ${foundComponents.length}/${requiredComponents.length} components`;
      check.issues.push(`Missing: ${missingComponents.join(', ')}`);
    } else {
      check.status = 'missing';
      check.evidence = 'Plans feature not found';
    }

    check.files = files;
    return check;
  }

  private async verifyFollowingSystem(
    check: ImplementationCheck
  ): Promise<ImplementationCheck> {
    const requiredComponents = [
      'Database table: Follow',
      'Database table: FollowRequest',
      'User field: isPrivate',
      'User field: followerCount',
      'Backend endpoint: POST /api/users/:id/follow',
      'Backend endpoint: GET /api/users/:id/followers',
    ];

    const foundComponents: string[] = [];
    const files: string[] = [];

    // Check database schema
    const schemaPath = join(this.projectRoot, 'server', 'prisma', 'schema.prisma');
    try {
      const schema = await readFile(schemaPath, 'utf-8');
      if (/model Follow\s*\{/i.test(schema)) {
        foundComponents.push('Database table: Follow');
        files.push('server/prisma/schema.prisma');
      }
      if (/model FollowRequest\s*\{/i.test(schema)) {
        foundComponents.push('Database table: FollowRequest');
      }
      if (/isPrivate\s+Boolean/i.test(schema)) {
        foundComponents.push('User field: isPrivate');
      }
      if (/followerCount\s+Int/i.test(schema)) {
        foundComponents.push('User field: followerCount');
      }
    } catch {
      check.issues.push('Could not read Prisma schema');
    }

    // Check backend endpoints
    const serverFiles = await this.getServerFiles();
    for (const file of serverFiles) {
      if (file.includes('routes/users.ts') || file.includes('routes/social.ts')) {
        const content = await readFile(file, 'utf-8');
        if (/router\.post.*\/users\/:id\/follow/i.test(content)) {
          foundComponents.push('Backend endpoint: POST /api/users/:id/follow');
        }
        if (/router\.get.*\/users\/:id\/followers/i.test(content)) {
          foundComponents.push('Backend endpoint: GET /api/users/:id/followers');
        }
        files.push(relative(this.projectRoot, file));
      }
    }

    const missingComponents = requiredComponents.filter(
      (c) => !foundComponents.includes(c)
    );

    if (missingComponents.length === 0) {
      check.status = 'complete';
      check.evidence = 'All required components found';
    } else if (foundComponents.length > 0) {
      check.status = 'partial';
      check.evidence = `Found ${foundComponents.length}/${requiredComponents.length} components`;
      check.issues.push(`Missing: ${missingComponents.join(', ')}`);
    } else {
      check.status = 'missing';
      check.evidence = 'Following system not found';
    }

    check.files = files;
    return check;
  }

  private async verifyEventEdit(check: ImplementationCheck): Promise<ImplementationCheck> {
    const serverFiles = await this.getServerFiles();
    let foundEndpoint = false;
    let foundPermissionCheck = false;
    const files: string[] = [];

    for (const file of serverFiles) {
      if (file.includes('routes/events.ts')) {
        const content = await readFile(file, 'utf-8');
        if (/router\.patch.*\/events\/:id|PATCH.*\/events\/:id/i.test(content)) {
          foundEndpoint = true;
          files.push(relative(this.projectRoot, file));
          
          // Check for edit permission validation
          if (/startTime.*>.*NOW|endTime.*>.*NOW|canEdit|editPermission/i.test(content)) {
            foundPermissionCheck = true;
          }
        }
      }
    }

    if (foundEndpoint && foundPermissionCheck) {
      check.status = 'complete';
      check.evidence = 'Event edit endpoint with permission check found';
    } else if (foundEndpoint) {
      check.status = 'partial';
      check.evidence = 'Event edit endpoint found but missing permission check';
      check.issues.push('Missing edit permission validation (future/ongoing events only)');
    } else {
      check.status = 'missing';
      check.evidence = 'Event edit endpoint not found';
    }

    check.files = files;
    return check;
  }

  private async verifyAddressField(check: ImplementationCheck): Promise<ImplementationCheck> {
    const schemaPath = join(this.projectRoot, 'server', 'prisma', 'schema.prisma');
    let foundField = false;
    const files: string[] = [];

    try {
      const schema = await readFile(schemaPath, 'utf-8');
      if (/address\s+String/i.test(schema)) {
        foundField = true;
        files.push('server/prisma/schema.prisma');
      }
    } catch {
      check.issues.push('Could not read Prisma schema');
    }

    if (foundField) {
      check.status = 'complete';
      check.evidence = 'Address field found in Event model';
    } else {
      check.status = 'missing';
      check.evidence = 'Address field not found in Event model';
    }

    check.files = files;
    return check;
  }

  private async verifyPrivateAccounts(check: ImplementationCheck): Promise<ImplementationCheck> {
    const schemaPath = join(this.projectRoot, 'server', 'prisma', 'schema.prisma');
    let foundField = false;
    let foundTable = false;
    const files: string[] = [];

    try {
      const schema = await readFile(schemaPath, 'utf-8');
      if (/isPrivate\s+Boolean/i.test(schema)) {
        foundField = true;
      }
      if (/model FollowRequest/i.test(schema)) {
        foundTable = true;
      }
      if (foundField || foundTable) {
        files.push('server/prisma/schema.prisma');
      }
    } catch {
      check.issues.push('Could not read Prisma schema');
    }

    if (foundField && foundTable) {
      check.status = 'complete';
      check.evidence = 'Private accounts (isPrivate field + FollowRequest table) found';
    } else if (foundField || foundTable) {
      check.status = 'partial';
      check.evidence = `Partial: isPrivate=${foundField}, FollowRequest=${foundTable}`;
    } else {
      check.status = 'missing';
      check.evidence = 'Private accounts not found';
    }

    check.files = files;
    return check;
  }

  private async verifyStoryViewer(check: ImplementationCheck): Promise<ImplementationCheck> {
    const iosFiles = await this.getIOSFiles();
    let foundViewer = false;
    const files: string[] = [];

    for (const file of iosFiles) {
      if (file.includes('EventDetailView') || file.includes('StoryView')) {
        const content = await readFile(file, 'utf-8');
        if (/TabView|swipeable|carousel/i.test(content)) {
          foundViewer = true;
          files.push(relative(this.projectRoot, file));
        }
      }
    }

    if (foundViewer) {
      check.status = 'complete';
      check.evidence = 'Story viewer implementation found';
    } else {
      check.status = 'missing';
      check.evidence = 'Story viewer not found';
    }

    check.files = files;
    return check;
  }

  private async verifyTextOverlay(check: ImplementationCheck): Promise<ImplementationCheck> {
    const iosFiles = await this.getIOSFiles();
    let foundOverlay = false;
    const files: string[] = [];

    for (const file of iosFiles) {
      if (file.includes('CreateEventView') || file.includes('MediaEditor')) {
        const content = await readFile(file, 'utf-8');
        if (/text.*overlay|addText|TextOverlay/i.test(content)) {
          foundOverlay = true;
          files.push(relative(this.projectRoot, file));
        }
      }
    }

    if (foundOverlay) {
      check.status = 'complete';
      check.evidence = 'Text overlay implementation found';
    } else {
      check.status = 'missing';
      check.evidence = 'Text overlay not found';
    }

    check.files = files;
    return check;
  }

  private async verifyTerminologyUpdate(
    check: ImplementationCheck
  ): Promise<ImplementationCheck> {
    const serverFiles = await this.getServerFiles();
    let foundOldTerminology = false;
    let foundNewTerminology = false;
    const files: string[] = [];

    for (const file of serverFiles) {
      const content = await readFile(file, 'utf-8');
      if (/\/like|likesCount|Going/i.test(content)) {
        foundOldTerminology = true;
        files.push(relative(this.projectRoot, file));
      }
      if (/\/interested|interestedCount/i.test(content)) {
        foundNewTerminology = true;
      }
    }

    if (foundNewTerminology && !foundOldTerminology) {
      check.status = 'complete';
      check.evidence = 'Terminology updated to "Interested" (no old terminology found)';
    } else if (foundNewTerminology && foundOldTerminology) {
      check.status = 'partial';
      check.evidence = 'New terminology found but old terminology still present';
      check.issues.push('Old "Like/Going" terminology still in codebase');
    } else {
      check.status = 'missing';
      check.evidence = 'Terminology update not found';
    }

    check.files = files;
    return check;
  }

  private async verifyDatabaseMigration(
    check: ImplementationCheck
  ): Promise<ImplementationCheck> {
    const migrationsPath = join(
      this.projectRoot,
      'server',
      'prisma',
      'migrations'
    );
    let foundMigration = false;
    const files: string[] = [];

    try {
      const migrations = await readdir(migrationsPath);
      const recentMigrations = migrations
        .filter((m) => m.match(/^\d{14}/))
        .sort()
        .slice(-3);

      for (const migration of recentMigrations) {
        const migrationPath = join(migrationsPath, migration);
        const migrationFiles = await readdir(migrationPath);
        for (const file of migrationFiles) {
          if (file.endsWith('.sql')) {
            const content = await readFile(
              join(migrationPath, file),
              'utf-8'
            );
            if (
              /CREATE TABLE|ALTER TABLE|ADD COLUMN|CREATE INDEX/i.test(content)
            ) {
              foundMigration = true;
              files.push(`server/prisma/migrations/${migration}/${file}`);
            }
          }
        }
      }
    } catch {
      check.issues.push('Could not read migrations directory');
    }

    if (foundMigration) {
      check.status = 'complete';
      check.evidence = 'Recent database migration found';
    } else {
      check.status = 'missing';
      check.evidence = 'No recent database migration found';
    }

    check.files = files;
    return check;
  }

  private async checkCompleteness(): Promise<CompletenessCheck[]> {
    const checks: CompletenessCheck[] = [];

    // Check Plans feature completeness
    const plansCheck: CompletenessCheck = {
      feature: 'Plans Feature',
      requiredComponents: [
        'Plan table',
        'PlanEvent table',
        'POST /api/plans endpoint',
        'GET /api/plans endpoint',
        'POST /api/plans/:id/events/:eventId endpoint',
        'PlansView (iOS)',
        'PlanDetailView (iOS)',
      ],
      foundComponents: [],
      missingComponents: [],
      status: 'missing',
    };

    // Check database
    const schemaPath = join(this.projectRoot, 'server', 'prisma', 'schema.prisma');
    try {
      const schema = await readFile(schemaPath, 'utf-8');
      if (/model Plan\s*\{/i.test(schema)) plansCheck.foundComponents.push('Plan table');
      if (/model PlanEvent\s*\{/i.test(schema))
        plansCheck.foundComponents.push('PlanEvent table');
    } catch {}

    // Check endpoints
    const serverFiles = await this.getServerFiles();
    for (const file of serverFiles) {
      if (file.includes('routes/plans.ts')) {
        const content = await readFile(file, 'utf-8');
        if (/router\.post.*\/plans/i.test(content))
          plansCheck.foundComponents.push('POST /api/plans endpoint');
        if (/router\.get.*\/plans/i.test(content))
          plansCheck.foundComponents.push('GET /api/plans endpoint');
        if (/router\.post.*\/plans\/:id\/events/i.test(content))
          plansCheck.foundComponents.push(
            'POST /api/plans/:id/events/:eventId endpoint'
          );
      }
    }

    // Check iOS views
    const iosFiles = await this.getIOSFiles();
    for (const file of iosFiles) {
      if (file.includes('PlansView')) plansCheck.foundComponents.push('PlansView (iOS)');
      if (file.includes('PlanDetailView'))
        plansCheck.foundComponents.push('PlanDetailView (iOS)');
    }

    plansCheck.missingComponents = plansCheck.requiredComponents.filter(
      (c) => !plansCheck.foundComponents.includes(c)
    );
    plansCheck.status =
      plansCheck.missingComponents.length === 0
        ? 'complete'
        : plansCheck.foundComponents.length > 0
        ? 'partial'
        : 'missing';

    checks.push(plansCheck);

    return checks;
  }

  private async checkFunctionality(options: { tier: Tier }): Promise<FunctionalityCheck[]> {
    const { tier } = options;
    const checks: FunctionalityCheck[] = [];

    // Tier 1: Quick checks only (tsc --noEmit and lint on changed files)
    if (tier === 1) {
      try {
        const { stdout, stderr } = await execAsync('npm run build -- --noEmit', {
          cwd: join(this.projectRoot, 'server'),
          timeout: 20000,
        }).catch((error) => ({
          stdout: '',
          stderr: error.stderr || error.message,
        }));

        const hasErrors = stderr.includes('error') || stdout.includes('error');
        checks.push({
          check: 'Backend TypeScript compilation (no emit)',
          status: hasErrors ? 'fail' : 'pass',
          evidence: hasErrors ? 'TypeScript errors found' : 'Quick build (no emit) successful',
          error: hasErrors ? stderr.substring(0, 500) : undefined,
        });
      } catch {
        checks.push({
          check: 'Backend TypeScript compilation (no emit)',
          status: 'warn',
          evidence: 'Could not run quick build check',
        });
      }

      try {
        // Lint only changed files
        const { stdout: diffStdout } = await execAsync('git diff --name-only HEAD', {
          cwd: this.projectRoot,
          timeout: 5000,
        }).catch(() => ({ stdout: '' }));
        const files = diffStdout
          .split('\n')
          .filter((f) => f.startsWith('server/') && (f.endsWith('.ts') || f.endsWith('.tsx')));

        if (files.length > 0) {
          const fileList = files.map((f) => `"${f.replace(/^server\//, '')}"`).join(' ');
          const { stdout, stderr } = await execAsync(`npm run lint -- ${fileList}`, {
            cwd: join(this.projectRoot, 'server'),
            timeout: 20000,
          }).catch((error) => ({
            stdout: '',
            stderr: error.stderr || error.message,
          }));

          const hasErrors = stderr.includes('error') || stdout.includes('error');
          checks.push({
            check: 'Backend linting (changed files)',
            status: hasErrors ? 'fail' : 'pass',
            evidence: hasErrors ? 'Linting errors found in changed files' : 'Changed files lint clean',
          });
        } else {
          checks.push({
            check: 'Backend linting (changed files)',
            status: 'pass',
            evidence: 'No changed backend files to lint',
          });
        }
      } catch {
        checks.push({
          check: 'Backend linting (changed files)',
          status: 'warn',
          evidence: 'Could not run lint on changed files',
        });
      }

      return checks;
    }

    // Tier 2+: Full backend build, tests, and lint
    try {
      const { stdout, stderr } = await execAsync('npm run build', {
        cwd: join(this.projectRoot, 'server'),
        timeout: 60000,
      }).catch((error) => ({
        stdout: '',
        stderr: error.stderr || error.message,
      }));

      const hasErrors = stderr.includes('error') || stdout.includes('error');
      checks.push({
        check: 'Backend TypeScript compilation',
        status: hasErrors ? 'fail' : 'pass',
        evidence: hasErrors ? 'TypeScript compilation errors found' : 'Build successful',
        error: hasErrors ? stderr.substring(0, 500) : undefined,
      });
    } catch {
      checks.push({
        check: 'Backend TypeScript compilation',
        status: 'warn',
        evidence: 'Could not run build check',
      });
    }

    try {
      const { stdout, stderr } = await execAsync('npm run test 2>&1', {
        cwd: join(this.projectRoot, 'server'),
        timeout: 60000,
      }).catch((error) => ({
        stdout: error.stdout || '',
        stderr: error.stderr || error.message,
      }));

      const hasFailures =
        stderr.includes('FAIL') ||
        stdout.includes('FAIL') ||
        stderr.includes('failing') ||
        stdout.includes('failing');
      checks.push({
        check: 'Backend tests',
        status: hasFailures ? 'fail' : 'pass',
        evidence: hasFailures ? 'Test failures found' : 'Tests pass',
        error: hasFailures ? stdout.substring(0, 500) : undefined,
      });
    } catch {
      checks.push({
        check: 'Backend tests',
        status: 'warn',
        evidence: 'Could not run tests',
      });
    }

    try {
      const { stdout, stderr } = await execAsync('npm run lint', {
        cwd: join(this.projectRoot, 'server'),
        timeout: 60000,
      }).catch((error) => ({
        stdout: '',
        stderr: error.stderr || error.message,
      }));

      const hasErrors = stderr.includes('error') || stdout.includes('error');
      checks.push({
        check: 'Backend linting',
        status: hasErrors ? 'fail' : 'pass',
        evidence: hasErrors ? 'Linting errors found' : 'Linting passes',
      });
    } catch {
      checks.push({
        check: 'Backend linting',
        status: 'warn',
        evidence: 'Could not run linting',
      });
    }

    return checks;
  }

  private generateSummary(data: {
    implementationChecks: ImplementationCheck[];
    completenessChecks: CompletenessCheck[];
    functionalityChecks: FunctionalityCheck[];
  }): VerificationReport['summary'] {
    const complete = [
      ...data.implementationChecks.filter((c) => c.status === 'complete'),
      ...data.completenessChecks.filter((c) => c.status === 'complete'),
      ...data.functionalityChecks.filter((c) => c.status === 'pass'),
    ].length;

    const partial = [
      ...data.implementationChecks.filter((c) => c.status === 'partial'),
      ...data.completenessChecks.filter((c) => c.status === 'partial'),
    ].length;

    const missing = [
      ...data.implementationChecks.filter((c) => c.status === 'missing'),
      ...data.completenessChecks.filter((c) => c.status === 'missing'),
    ].length;

    const broken = [
      ...data.implementationChecks.filter((c) => c.status === 'broken'),
      ...data.functionalityChecks.filter((c) => c.status === 'fail'),
    ].length;

    const criticalIssues = [
      ...data.implementationChecks
        .filter((c) => c.status === 'missing' || c.status === 'broken')
        .map((c) => `Missing: ${c.feature}`),
      ...data.functionalityChecks
        .filter((c) => c.status === 'fail')
        .map((c) => `Broken: ${c.check}`),
    ];

    const overall =
      broken > 0 ? 'fail' : missing > 0 ? 'fail' : partial > 0 ? 'warn' : 'pass';

    return {
      totalChecks:
        data.implementationChecks.length +
        data.completenessChecks.length +
        data.functionalityChecks.length,
      complete,
      partial,
      missing,
      broken,
      overall,
      criticalIssues,
    };
  }

  private async getServerFiles(): Promise<string[]> {
    const serverDir = join(this.projectRoot, 'server', 'src');
    return this.getAllFiles(serverDir, ['.ts', '.js']);
  }

  private async getIOSFiles(): Promise<string[]> {
    const iosDir = join(
      this.projectRoot,
      'ios',
      'BarrioCursor',
      'BarrioCursor',
      'BarrioCursor'
    );
    return this.getAllFiles(iosDir, ['.swift']);
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

  generateReport(report: VerificationReport): string {
    const lines: string[] = [];

    lines.push('═'.repeat(80));
    lines.push('  IMPLEMENTATION VERIFICATION REPORT');
    lines.push('═'.repeat(80));
    lines.push(`Timestamp: ${report.timestamp}\n`);

    // Summary
    lines.push('📊 SUMMARY');
    lines.push('-'.repeat(80));
    lines.push(`Overall Status: ${report.summary.overall.toUpperCase()}`);
    lines.push(`Total Checks: ${report.summary.totalChecks}`);
    lines.push(`✅ Complete: ${report.summary.complete}`);
    lines.push(`⚠️  Partial: ${report.summary.partial}`);
    lines.push(`❌ Missing: ${report.summary.missing}`);
    lines.push(`💥 Broken: ${report.summary.broken}\n`);

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
    if (report.gitStatus.lastCommit) {
      lines.push(`Last Commit: ${report.gitStatus.lastCommit}`);
    }
    if (report.gitStatus.changedFiles.length > 0) {
      lines.push(`Changed Files: ${report.gitStatus.changedFiles.length}`);
      report.gitStatus.changedFiles.slice(0, 5).forEach((f) => {
        lines.push(`   • ${f}`);
      });
    }
    lines.push('');

    // Implementation Checks
    if (report.implementationChecks.length > 0) {
      lines.push('🔍 IMPLEMENTATION CHECKS (What Was Promised → What Was Delivered)');
      lines.push('-'.repeat(80));
      report.implementationChecks.forEach((check) => {
        const icon =
          check.status === 'complete'
            ? '✅'
            : check.status === 'partial'
            ? '⚠️'
            : check.status === 'broken'
            ? '💥'
            : '❌';
        lines.push(`${icon} ${check.feature}`);
        lines.push(`   Source: ${check.source}`);
        lines.push(`   Status: ${check.status.toUpperCase()}`);
        lines.push(`   Evidence: ${check.evidence}`);
        if (check.files.length > 0) {
          lines.push(`   Files: ${check.files.slice(0, 3).join(', ')}`);
        }
        if (check.issues.length > 0) {
          lines.push(`   Issues: ${check.issues.join('; ')}`);
        }
        lines.push('');
      });
    }

    // Completeness Checks
    if (report.completenessChecks.length > 0) {
      lines.push('📦 COMPLETENESS CHECKS (Is It Done Fully?)');
      lines.push('-'.repeat(80));
      report.completenessChecks.forEach((check) => {
        const icon =
          check.status === 'complete'
            ? '✅'
            : check.status === 'partial'
            ? '⚠️'
            : '❌';
        lines.push(`${icon} ${check.feature}`);
        lines.push(`   Status: ${check.status.toUpperCase()}`);
        lines.push(`   Found: ${check.foundComponents.length}/${check.requiredComponents.length} components`);
        if (check.missingComponents.length > 0) {
          lines.push(`   Missing: ${check.missingComponents.join(', ')}`);
        }
        lines.push('');
      });
    }

    // Functionality Checks
    if (report.functionalityChecks.length > 0) {
      lines.push('⚙️  FUNCTIONALITY CHECKS (Does It Work?)');
      lines.push('-'.repeat(80));
      report.functionalityChecks.forEach((check) => {
        const icon = check.status === 'pass' ? '✅' : check.status === 'fail' ? '❌' : '⚠️';
        lines.push(`${icon} ${check.check}`);
        lines.push(`   Status: ${check.status.toUpperCase()}`);
        lines.push(`   Evidence: ${check.evidence}`);
        if (check.error) {
          lines.push(`   Error: ${check.error.substring(0, 200)}...`);
        }
        lines.push('');
      });
    }

    lines.push('═'.repeat(80));

    return lines.join('\n');
  }
}

// Main execution
const isMainModule =
  import.meta.url === `file://${process.argv[1]}` ||
  import.meta.url.endsWith('implementation-verifier.ts');

if (isMainModule) {
  (async () => {
    const verifier = new ImplementationVerifier();
    try {
      const report = await verifier.verify();
      const reportText = verifier.generateReport(report);
      console.log(reportText);

      // Write to file
      const fs = await import('fs/promises');
      const reportPath = join(__dirname, '..', 'implementation-verification.txt');
      await fs.writeFile(reportPath, reportText, 'utf-8');
      console.log(`\n📄 Report saved to: ${reportPath}`);

      process.exit(report.summary.overall === 'fail' ? 1 : 0);
    } catch (error) {
      console.error('❌ Implementation Verifier Error:', error);
      process.exit(1);
    }
  })();
}

export { ImplementationVerifier, type VerificationReport };

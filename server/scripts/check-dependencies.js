#!/usr/bin/env node
/**
 * Dependency Checker Script
 * 
 * Verifies all required dependencies are installed and services are running
 * before starting the server or running tests.
 * 
 * Usage: node scripts/check-dependencies.js
 */

import { execSync } from 'child_process';
import { existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const serverRoot = join(__dirname, '..');

const checks = {
  passed: [],
  failed: [],
  warnings: [],
};

function check(name, fn, required = true) {
  try {
    const result = fn();
    if (result) {
      checks.passed.push(`✅ ${name}`);
      return true;
    } else {
      if (required) {
        checks.failed.push(`❌ ${name}`);
      } else {
        checks.warnings.push(`⚠️  ${name} (optional)`);
      }
      return false;
    }
  } catch (error) {
    if (required) {
      checks.failed.push(`❌ ${name}: ${error.message}`);
    } else {
      checks.warnings.push(`⚠️  ${name} (optional): ${error.message}`);
    }
    return false;
  }
}

console.log('🔍 Checking dependencies...\n');

// Check Node.js version
check('Node.js 18+ installed', () => {
  const version = execSync('node --version', { encoding: 'utf-8' }).trim();
  const major = parseInt(version.replace('v', '').split('.')[0]);
  if (major < 18) {
    throw new Error(`Node.js ${version} found, but 18+ is required`);
  }
  console.log(`   Found: ${version}`);
  return true;
});

// Check npm
check('npm installed', () => {
  const version = execSync('npm --version', { encoding: 'utf-8' }).trim();
  console.log(`   Found: npm ${version}`);
  return true;
});

// Check Docker
check('Docker installed', () => {
  try {
    const version = execSync('docker --version', { encoding: 'utf-8' }).trim();
    console.log(`   Found: ${version}`);
    return true;
  } catch {
    throw new Error('Docker not found. Install Docker Desktop: https://www.docker.com/products/docker-desktop/');
  }
});

// Check Docker is running
check('Docker is running', () => {
  try {
    execSync('docker ps', { encoding: 'utf-8', stdio: 'pipe' });
    return true;
  } catch {
    throw new Error('Docker is not running. Start Docker Desktop and wait for it to initialize.');
  }
});

// Check PostgreSQL container
check('PostgreSQL container running', () => {
  try {
    const output = execSync('docker ps --format "{{.Names}}"', { encoding: 'utf-8' });
    if (output.includes('barrio-postgres')) {
      console.log('   Found: barrio-postgres container');
      return true;
    }
    throw new Error('PostgreSQL container not running. Run: docker-compose up -d');
  } catch (error) {
    if (error.message.includes('not running')) {
      throw error;
    }
    throw new Error('PostgreSQL container not found. Run: docker-compose up -d');
  }
});

// Check PostgreSQL is accepting connections
check('PostgreSQL accepting connections', () => {
  try {
    // Try pg_isready first (if installed)
    try {
      execSync('pg_isready -h localhost -p 5432', { encoding: 'utf-8', stdio: 'pipe' });
      return true;
    } catch {
      // Fallback: use docker exec to check inside the container
      const output = execSync('docker exec barrio-postgres pg_isready -U postgres', { 
        encoding: 'utf-8', 
        stdio: 'pipe' 
      });
      if (output.includes('accepting connections')) {
        return true;
      }
      throw new Error('PostgreSQL not accepting connections. Wait a few seconds and try again.');
    }
  } catch (error) {
    if (error.message.includes('not accepting')) {
      throw error;
    }
    throw new Error('PostgreSQL not accepting connections. Wait a few seconds and try again.');
  }
});

// Check node_modules
check('npm packages installed', () => {
  const nodeModulesPath = join(serverRoot, 'node_modules');
  if (!existsSync(nodeModulesPath)) {
    throw new Error('node_modules not found. Run: npm install');
  }
  return true;
});

// Check .env file
check('.env file exists', () => {
  const envPath = join(serverRoot, '.env');
  if (!existsSync(envPath)) {
    throw new Error('.env file not found. Copy .env.example to .env and configure it.');
  }
  return true;
});

// Check Prisma client
check('Prisma client generated', () => {
  const prismaClientPath = join(serverRoot, 'node_modules', '.prisma', 'client', 'index.js');
  if (!existsSync(prismaClientPath)) {
    throw new Error('Prisma client not generated. Run: npx prisma generate');
  }
  return true;
});

// Optional: Check Supabase CLI
check('Supabase CLI installed', () => {
  try {
    const version = execSync('supabase --version', { encoding: 'utf-8', stdio: 'pipe' }).trim();
    console.log(`   Found: ${version}`);
    return true;
  } catch {
    return false; // Optional, so return false but don't throw
  }
}, false);

console.log('\n📊 Summary:\n');

if (checks.passed.length > 0) {
  console.log('✅ Passed:');
  checks.passed.forEach((msg) => console.log(`   ${msg}`));
  console.log('');
}

if (checks.warnings.length > 0) {
  console.log('⚠️  Warnings (optional):');
  checks.warnings.forEach((msg) => console.log(`   ${msg}`));
  console.log('');
}

if (checks.failed.length > 0) {
  console.log('❌ Failed (required):');
  checks.failed.forEach((msg) => console.log(`   ${msg}`));
  console.log('\n💡 Fix the issues above before starting the server.\n');
  process.exit(1);
}

console.log('✨ All dependencies are ready!\n');
process.exit(0);

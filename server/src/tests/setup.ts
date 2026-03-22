/**
 * Test Setup - Phase 10: Database Connection Fix
 *
 * This file ensures tests use DIRECT_URL instead of pooled DATABASE_URL
 * to avoid circuit breaker issues with Supabase connection pooler.
 */

// Before createApp() loads grammy (via telegramWebhook), Node 18 needs global File.
import '../filePolyfill.js';

import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

// Load environment variables
dotenv.config();

// Override DATABASE_URL with DIRECT_URL for tests if available
// This bypasses the connection pooler and avoids circuit breaker issues
if (process.env['NODE_ENV'] === 'test' && process.env['DIRECT_URL']) {
  process.env['DATABASE_URL'] = process.env['DIRECT_URL'];
  console.log(
    '✅ Test setup: Using DIRECT_URL for database connection (bypassing pooler)'
  );
}

// Verify database connection is available
export async function verifyDatabaseConnection(): Promise<boolean> {
  try {
    const prisma = new PrismaClient();
    await prisma.$connect();
    await prisma.$disconnect();
    return true;
  } catch (error) {
    console.error('❌ Test setup: Database connection failed:', error);
    return false;
  }
}

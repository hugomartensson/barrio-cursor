import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
import { logger } from './logger.js';

// Load environment variables (needed for DIRECT_URL override in tests)
dotenv.config();

// Phase 10: Connection Strategy
// - TESTS: Use DIRECT_URL (direct connection) to avoid circuit breaker issues
// - PRODUCTION/DEV: Use DATABASE_URL (pooled connection) for better performance
//
// This conditional only applies to tests. In production/development, Prisma
// uses the default DATABASE_URL from schema.prisma, which is the pooled connection.
const prismaOptions: { datasources?: { db: { url: string } } } = {};

if (process.env['NODE_ENV'] === 'test' && process.env['DIRECT_URL']) {
  // Override to use direct connection ONLY for tests
  // This bypasses the connection pooler and avoids circuit breaker issues
  prismaOptions.datasources = {
    db: {
      url: process.env['DIRECT_URL'],
    },
  };
  logger.info('✅ Prisma: Using DIRECT_URL for test environment (bypassing pooler)');
}
// Note: If not in test mode, Prisma uses DATABASE_URL (pooled connection) from schema.prisma

// Prevent multiple instances during hot reload in development
const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma = globalForPrisma.prisma || new PrismaClient(prismaOptions);

if (process.env['NODE_ENV'] !== 'production') {
  globalForPrisma.prisma = prisma;
}

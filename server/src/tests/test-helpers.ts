/**
 * Test Helpers - Phase 10: End-to-End Testing Support
 *
 * Utilities for comprehensive testing of all user flows
 */

import { PrismaClient } from '@prisma/client';
import { supabaseAdmin } from '../services/supabase.js';

export const prisma = new PrismaClient();

/**
 * Create a test user and return auth token
 *
 * Note: Uses test-only password from environment or default.
 * This is safe as it's only used in test environment.
 */
export async function createTestUser(
  emailPrefix: string = `test-${Date.now()}`,
  name: string = 'Test User'
): Promise<{ userId: string; token: string; email: string }> {
  const email = `${emailPrefix}@example.com`;
  // Test-only password - safe to use in test environment
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  const password = process.env['TEST_USER_PASSWORD'] || 'TestPassword123!';

  const { data, error } = await supabaseAdmin.auth.signUp({
    email,
    password,
    options: { data: { name } },
  });

  if (error || !data.user || !data.session) {
    throw new Error(`Failed to create test user: ${error?.message || 'Unknown error'}`);
  }

  return {
    userId: data.user.id,
    token: data.session.access_token,
    email,
  };
}

/**
 * Clean up test user
 */
export async function cleanupTestUser(userId: string): Promise<void> {
  try {
    // Delete user from Supabase Auth
    await supabaseAdmin.auth.admin.deleteUser(userId);
  } catch (error) {
    console.warn(`Failed to delete test user ${userId}:`, error);
  }
}

/**
 * Wait for database operations to complete
 */
export async function waitForDb(ms: number = 100): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Verify event exists in database
 */
export async function verifyEventExists(eventId: string): Promise<boolean> {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
  });
  return event !== null;
}

/**
 * Verify event deleted from database
 */
export async function verifyEventDeleted(eventId: string): Promise<boolean> {
  const event = await prisma.event.findUnique({
    where: { id: eventId },
  });
  return event === null;
}

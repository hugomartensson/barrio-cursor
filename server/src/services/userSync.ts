import { prisma } from './prisma.js';
import { createLogger } from './logger.js';

const logger = createLogger({ component: 'user-sync' });

/**
 * Sync a user from Supabase Auth to our local database
 * Creates or updates the user record
 */
export async function syncUserToDatabase(
  id: string,
  email: string,
  name: string
): Promise<void> {
  try {
    // First, try to find if user exists by email or id
    // Try email first (most reliable since it's unique)
    let existingUser = await prisma.user.findUnique({
      where: { email },
    });

    // If not found by email, try by id
    if (!existingUser) {
      existingUser = await prisma.user.findUnique({
        where: { id },
      });
    }

    if (existingUser) {
      // User exists - update it
      // Note: We can't update the primary key (id), so if the id changed,
      // we need to handle it differently. For now, we'll just update name and email.
      const updateData: { email: string; name: string } = {
        email,
        name,
      };

      // Only update if something actually changed
      if (existingUser.email !== email || existingUser.name !== name) {
        await prisma.user.update({
          where: { id: existingUser.id },
          data: updateData,
        });
        logger.debug(
          { userId: existingUser.id, email, action: 'updated' },
          'User updated in database'
        );
      } else {
        logger.debug(
          { userId: existingUser.id, email, action: 'no_change' },
          'User already in sync'
        );
      }
    } else {
      // User doesn't exist - create it
      await prisma.user.create({
        data: {
          id,
          email,
          passwordHash: 'supabase-managed', // Password managed by Supabase Auth
          name,
        },
      });
      logger.debug({ userId: id, email, action: 'created' }, 'User created in database');
    }
  } catch (error) {
    // Log detailed error information
    const errorDetails = {
      name: error instanceof Error ? error.name : 'Unknown',
      message: error instanceof Error ? error.message : String(error),
      code: (error as { code?: string })?.code,
      meta: (error as { meta?: unknown })?.meta,
      stack: error instanceof Error ? error.stack : undefined,
    };

    logger.error(
      {
        error: errorDetails,
        userId: id,
        email,
        name,
      },
      'Failed to sync user to database'
    );

    // Re-throw with more context
    const errorMessage = error instanceof Error ? error.message : String(error);
    throw new Error(
      `Failed to sync user to database: ${errorMessage}. Code: ${errorDetails.code || 'N/A'}`
    );
  }
}

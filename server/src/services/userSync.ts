import { prisma } from './prisma.js';
import { createLogger } from './logger.js';
import { generateHandle, generateInitials } from './handleService.js';

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
      // User exists - only sync email (Supabase-authoritative).
      // Name is user-editable in the app and must not be overwritten by JWT metadata
      // on every request, otherwise PATCH /me name changes would be immediately reverted.
      if (existingUser.email !== email) {
        await prisma.user.update({
          where: { id: existingUser.id },
          data: { email },
        });
        logger.debug(
          { userId: existingUser.id, email, action: 'updated' },
          'User email updated in database'
        );
      } else {
        logger.debug(
          { userId: existingUser.id, email, action: 'no_change' },
          'User already in sync'
        );
      }
    } else {
      // User doesn't exist - create it (portal: set handle and initials)
      const handle = await generateHandle(name);
      const initials = generateInitials(name);
      await prisma.user.create({
        data: {
          id,
          email,
          passwordHash: 'supabase-managed', // Password managed by Supabase Auth
          name,
          handle,
          initials: initials || null,
        },
      });
      logger.debug(
        { userId: id, email, handle, action: 'created' },
        'User created in database'
      );
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

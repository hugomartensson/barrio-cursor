import { prisma } from './prisma.js';

/**
 * Sync a user from Supabase Auth to our local database
 * Creates or updates the user record
 */
export async function syncUserToDatabase(
  id: string,
  email: string,
  name: string
): Promise<void> {
  await prisma.user.upsert({
    where: { id },
    update: { email, name },
    create: {
      id,
      email,
      passwordHash: 'supabase-managed', // Password managed by Supabase Auth
      name,
    },
  });
}



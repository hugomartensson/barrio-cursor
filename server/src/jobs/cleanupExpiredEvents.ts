import { prisma } from '../services/prisma.js';
import { createLogger } from '../services/logger.js';

const logger = createLogger({ component: 'cleanup-job' });

/**
 * Hard deletes events where endTime < NOW() - 24 hours.
 * For events without endTime, uses startTime.
 */
export async function cleanupExpiredEvents(): Promise<number> {
  const twentyFourHoursAgo = new Date();
  twentyFourHoursAgo.setHours(twentyFourHoursAgo.getHours() - 24);

  const result = await prisma.$executeRaw`
    DELETE FROM events
    WHERE (
      (end_time IS NOT NULL AND end_time < ${twentyFourHoursAgo})
      OR
      (end_time IS NULL AND start_time < ${twentyFourHoursAgo})
    )
  `;

  return result;
}

export async function runCleanupWithLogging(): Promise<void> {
  try {
    const deletedCount = await cleanupExpiredEvents();

    logger.info(
      { deletedCount, threshold: '24 hours' },
      'Cleanup completed: Deleted expired events'
    );
  } catch (error) {
    logger.error({ error }, 'Error in cleanup job');
    throw error;
  }
}

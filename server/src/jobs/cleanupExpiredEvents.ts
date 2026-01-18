import { prisma } from '../services/prisma.js';
import { createLogger } from '../services/logger.js';

const logger = createLogger({ component: 'cleanup-job' });

/**
 * Cleanup expired events job
 * Hard deletes events where endTime < NOW() - 24 hours
 * Per PRD Section 8: Daily cron to hard-delete expired events
 *
 * SQL query uses Prisma's template literal syntax which automatically parameterizes queries
 * This prevents SQL injection - ${twentyFourHoursAgo} is safely parameterized
 */
export async function cleanupExpiredEvents(): Promise<number> {
  const twentyFourHoursAgo = new Date();
  twentyFourHoursAgo.setHours(twentyFourHoursAgo.getHours() - 24);

  // Delete events where endTime < NOW() - 24 hours
  // For events without endTime, use startTime
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

/**
 * Run cleanup and log results
 * Uses structured logging (pino) per guidelines
 */
export async function runCleanupWithLogging(): Promise<void> {
  try {
    const deletedCount = await cleanupExpiredEvents();
    logger.info(
      { deletedCount, threshold: '24 hours' },
      'Deleted expired events (endTime < NOW() - 24 hours)'
    );
  } catch (error) {
    logger.error({ error }, 'Error cleaning up expired events');
    throw error;
  }
}

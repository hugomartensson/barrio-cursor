import { prisma } from '../services/prisma.js';

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

  return result as number;
}

/**
 * Run cleanup and log results
 * Note: console.log is acceptable for MVP per guidelines
 * TODO: Migrate to structured logging (pino/winston) before TestFlight
 */
export async function runCleanupWithLogging(): Promise<void> {
  try {
    const deletedCount = await cleanupExpiredEvents();
    console.log(
      `[Cleanup Job] Deleted ${deletedCount} expired event(s) (endTime < NOW() - 24 hours)`
    );
  } catch (error) {
    console.error('[Cleanup Job] Error cleaning up expired events:', error);
    throw error;
  }
}

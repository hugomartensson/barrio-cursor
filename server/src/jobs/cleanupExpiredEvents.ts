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
 * Archive plans where all events are past
 * PRD Section 7.5: Plan Archiving - Archive plans where all events are past
 */
async function archiveExpiredPlans(): Promise<number> {
  const twentyFourHoursAgo = new Date();
  twentyFourHoursAgo.setHours(twentyFourHoursAgo.getHours() - 24);

  // Find plans where all events have endTime < NOW() - 24 hours
  // Only archive plans that have at least one event (empty plans stay active)
  const plansToArchive = await prisma.plan.findMany({
    where: {
      isArchived: false,
      planEvents: {
        some: {}, // Plan must have at least one event
        every: {
          event: {
            OR: [
              { endTime: { not: null, lt: twentyFourHoursAgo } },
              { endTime: null, startTime: { lt: twentyFourHoursAgo } },
            ],
          },
        },
      },
    },
  });

  if (plansToArchive.length === 0) {
    return 0;
  }

  const planIds = plansToArchive.map((p) => p.id);
  await prisma.plan.updateMany({
    where: {
      id: { in: planIds },
    },
    data: {
      isArchived: true,
    },
  });

  return plansToArchive.length;
}

/**
 * Run cleanup and log results
 * Uses structured logging (pino) per guidelines
 * PRD Section 8: Daily cron job for expired events cleanup
 * PRD Section 7.5: Plan Archiving - Archive plans where all events are past
 */
export async function runCleanupWithLogging(): Promise<void> {
  try {
    const deletedCount = await cleanupExpiredEvents();
    const archivedPlansCount = await archiveExpiredPlans();

    logger.info(
      { deletedCount, archivedPlansCount, threshold: '24 hours' },
      'Cleanup completed: Deleted expired events and archived plans with all events past'
    );
  } catch (error) {
    logger.error({ error }, 'Error in cleanup job');
    throw error;
  }
}

import { createApp } from './app.js';
import { config, isTest } from './config/index.js';
import { runCleanupWithLogging } from './jobs/cleanupExpiredEvents.js';
import { logger } from './services/logger.js';
import cron from 'node-cron';

const app = createApp();

// Bind to 0.0.0.0 to allow connections from iOS Simulator and physical devices
const server = app.listen(config.PORT, '0.0.0.0', () => {
  logger.info(
    {
      port: config.PORT,
      environment: config.NODE_ENV,
      host: '0.0.0.0',
      healthCheck: `http://localhost:${config.PORT}/api/health`,
    },
    '🚀 Server running'
  );

  // Start cron job for cleaning up expired events (daily at 2 AM)
  // Skip in test environment
  if (!isTest) {
    // Schedule: '0 2 * * *' = Every day at 2:00 AM
    cron.schedule('0 2 * * *', async () => {
      await runCleanupWithLogging();
    });
    logger.info({ schedule: '0 2 * * *' }, '🕐 Cleanup job scheduled: Daily at 2:00 AM');
  }
});

// Graceful shutdown
const gracefulShutdown = (signal: string): void => {
  logger.info({ signal }, 'Shutting down gracefully...');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });

  // Force close after 10s
  setTimeout(() => {
    logger.error('Forcing shutdown...');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

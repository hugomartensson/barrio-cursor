import { createApp } from './app.js';
import { config, isTest } from './config/index.js';
import { runCleanupWithLogging } from './jobs/cleanupExpiredEvents.js';
import cron from 'node-cron';

const app = createApp();

const server = app.listen(config.PORT, () => {
  console.info(`🚀 Server running on http://localhost:${config.PORT}`);
  console.info(`📍 Environment: ${config.NODE_ENV}`);
  console.info(`❤️  Health check: http://localhost:${config.PORT}/api/health`);

  // Start cron job for cleaning up expired events (daily at 2 AM)
  // Skip in test environment
  if (!isTest) {
    // Schedule: '0 2 * * *' = Every day at 2:00 AM
    cron.schedule('0 2 * * *', async () => {
      await runCleanupWithLogging();
    });
    console.info('🕐 Cleanup job scheduled: Daily at 2:00 AM');
  }
});

// Graceful shutdown
const gracefulShutdown = (signal: string): void => {
  console.info(`\n${signal} received. Shutting down gracefully...`);
  server.close(() => {
    console.info('Server closed');
    process.exit(0);
  });

  // Force close after 10s
  setTimeout(() => {
    console.error('Forcing shutdown...');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));



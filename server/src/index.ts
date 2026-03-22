import './filePolyfill.js';
import { createApp } from './app.js';
import { config, isTest } from './config/index.js';
import { runCleanupWithLogging } from './jobs/cleanupExpiredEvents.js';
import { logger } from './services/logger.js';
import cron from 'node-cron';
import { Bonjour } from 'bonjour-service';

function bootstrap(): void {
  const app = createApp();

  let bonjourInstance: InstanceType<typeof Bonjour> | null = null;

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

    // Advertise via Bonjour/mDNS so iOS devices can discover us instantly
    if (!isTest) {
      try {
        bonjourInstance = new Bonjour();
        bonjourInstance.publish({
          name: 'Barrio Dev Server',
          type: 'barrioapi',
          port: config.PORT,
          txt: { path: '/api' },
        });
        logger.info(
          { port: config.PORT, type: '_barrioapi._tcp' },
          '📡 Bonjour service advertised'
        );
      } catch (err) {
        logger.warn({ error: err }, 'Bonjour advertisement failed (non-fatal)');
      }

      cron.schedule('0 2 * * *', () => {
        void runCleanupWithLogging();
      });
      logger.info(
        { schedule: '0 2 * * *' },
        '🕐 Cleanup job scheduled: Daily at 2:00 AM'
      );
    }
  });

  // Graceful shutdown
  const gracefulShutdown = (signal: string): void => {
    logger.info({ signal }, 'Shutting down gracefully...');
    if (bonjourInstance) {
      bonjourInstance.unpublishAll();
      bonjourInstance.destroy();
    }
    server.close(() => {
      logger.info('Server closed');
      process.exit(0);
    });

    setTimeout(() => {
      logger.error('Forcing shutdown...');
      process.exit(1);
    }, 10000);
  };

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
}

try {
  bootstrap();
} catch (err: unknown) {
  logger.error({ err }, 'Bootstrap failed');
  process.exit(1);
}

import express, { Express } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as pinoHttpModule from 'pino-http';
import { webhookCallback } from 'grammy';
import { config } from './config/index.js';
import { logger } from './services/logger.js';
import { requestIdMiddleware } from './middleware/requestId.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import routes from './routes/index.js';
import type { RequestWithId } from './types/index.js';
import { createBot } from './tools/ingest/bot.js';

export const createApp = (): Express => {
  const app = express();
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const repoRoot = process.cwd();

  // Request ID middleware (must be first)
  app.use(requestIdMiddleware);

  // Required on Railway/reverse proxies so rate limit & IP detection work correctly.
  app.set('trust proxy', 1);

  // HTTP request logging middleware
  const pinoHttpOptions = {
    logger,
    genReqId: (req: express.Request) => (req as unknown as RequestWithId).id || 'unknown',
    customLogLevel: (_req: express.Request, res: express.Response, err?: Error) => {
      if (res.statusCode >= 400 && res.statusCode < 500) {
        return 'warn';
      } else if (res.statusCode >= 500 || err) {
        return 'error';
      }
      return 'info';
    },
    customSuccessMessage: (req: express.Request, res: express.Response) => {
      return `${req.method} ${req.url} ${res.statusCode}`;
    },
    customErrorMessage: (req: express.Request, res: express.Response, err?: Error) => {
      return `${req.method} ${req.url} ${res.statusCode} - ${err?.message}`;
    },
  };
  // Handle default export for ES modules
  const pinoHttpFn = ((
    pinoHttpModule as unknown as { default?: (opts?: unknown) => express.RequestHandler }
  ).default || pinoHttpModule) as (opts?: unknown) => express.RequestHandler;
  app.use(pinoHttpFn(pinoHttpOptions));

  // Security middleware
  app.use(helmet());

  // CORS configuration
  app.use(
    cors({
      origin: config.CORS_ORIGIN === '*' ? '*' : config.CORS_ORIGIN.split(','),
      credentials: true,
    })
  );

  // Rate limiting
  // More permissive in development for testing/debugging
  // Production should use stricter limits (e.g., 100 per 15 minutes)
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: config.NODE_ENV === 'production' ? 100 : 1000, // 1000 in dev, 100 in prod
    message: {
      error: {
        code: 'TOO_MANY_REQUESTS',
        message: 'Too many requests, please try again later',
      },
    },
    standardHeaders: true,
    legacyHeaders: false,
  });
  app.use(limiter);

  // Body parsing
  // Increased limit for video uploads: max video size is 50MB, base64 encoding adds ~33% overhead
  // So we need: 50MB * 1.33 ≈ 66MB, use 70MB to be safe
  app.use(express.json({ limit: '70mb' }));
  app.use(express.urlencoded({ extended: true, limit: '70mb' }));

  // API routes
  app.use('/api', routes);

  if (config.TELEGRAM_BOT_TOKEN) {
    const bot = createBot();
    app.use('/api/telegram/webhook', webhookCallback(bot, 'express'));
  }

  const adminAuth = (
    req: express.Request,
    res: express.Response,
    next: express.NextFunction
  ): void => {
    const username = config.ADMIN_USERNAME;
    const password = config.ADMIN_PASSWORD;
    if (!username || !password) {
      next();
      return;
    }

    const header = req.headers.authorization;
    if (!header?.startsWith('Basic ')) {
      res.set('WWW-Authenticate', 'Basic');
      res.status(401).send('Unauthorized');
      return;
    }

    const decoded = Buffer.from(header.slice(6), 'base64').toString('utf8');
    const [providedUser, providedPass] = decoded.split(':');
    if (providedUser !== username || providedPass !== password) {
      res.set('WWW-Authenticate', 'Basic');
      res.status(401).send('Unauthorized');
      return;
    }
    next();
  };
  const adminDistPath = path.join(__dirname, 'admin');
  const adminSourcePath = path.join(repoRoot, 'src', 'admin');
  app.use('/admin', adminAuth, express.static(adminDistPath));
  app.use('/admin', adminAuth, express.static(adminSourcePath));

  // Root endpoint
  app.get('/', (_req, res) => {
    res.json({
      name: 'Barrio API',
      version: '1.0.0',
      docs: '/api/health',
    });
  });

  // Error handling
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};

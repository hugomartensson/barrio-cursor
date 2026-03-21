import type { Express } from 'express';
import { webhookCallback } from 'grammy';
import { createBot } from './tools/ingest/bot.js';

/**
 * Register Telegram webhook route. Import `grammy` only from this module so
 * `filePolyfill` can run first from `index.ts`.
 */
export const registerTelegramWebhook = (app: Express): void => {
  const bot = createBot();
  app.use('/api/telegram/webhook', webhookCallback(bot, 'express'));
};

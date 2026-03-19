/* istanbul ignore file */
import { createBot } from './bot.js';
import { createLogger } from '../../services/logger.js';

const logger = createLogger({ component: 'ingest-bot-dev' });

const main = async (): Promise<void> => {
  const bot = createBot();
  logger.info('Starting Telegram bot in long polling mode');
  await bot.start();
};

void main();

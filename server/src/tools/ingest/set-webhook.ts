/* istanbul ignore file */
import { config } from '../../config/index.js';

const main = async (): Promise<void> => {
  if (!config.TELEGRAM_BOT_TOKEN) {
    throw new Error('TELEGRAM_BOT_TOKEN is required');
  }
  const base = config.PORTAL_API_URL ?? 'http://localhost:3000/api';
  const webhookBase = base.replace(/\/api\/?$/, '');
  const webhookUrl = `${webhookBase}/api/telegram/webhook`;
  const endpoint = `https://api.telegram.org/bot${config.TELEGRAM_BOT_TOKEN}/setWebhook?url=${encodeURIComponent(webhookUrl)}`;
  const response = await fetch(endpoint);
  const json = (await response.json()) as Record<string, unknown>;
  if (!response.ok || json['ok'] !== true) {
    throw new Error(`setWebhook failed: ${JSON.stringify(json)}`);
  }
  // eslint-disable-next-line no-console
  console.log(`Webhook set: ${webhookUrl}`);
};

void main();

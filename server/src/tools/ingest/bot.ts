/* istanbul ignore file */
import { Bot, type Context } from 'grammy';
import { config } from '../../config/index.js';
import { createLogger } from '../../services/logger.js';
import {
  extractDraftNameFromMastraResult,
  pollWorkflowRun,
  runIngestWorkflow,
  workflowAwaitingHumanReview,
  type IngestWorkflowInput,
} from './mastra-client.js';

const logger = createLogger({ component: 'ingest-bot' });

type Pending = { url: string; timer: ReturnType<typeof setTimeout> };
const pendingByChat = new Map<number, Pending>();

const URL_IN_TEXT = /https?:\/\/\S+/i;

const clearPending = (chatId: number): void => {
  const p = pendingByChat.get(chatId);
  if (p) {
    clearTimeout(p.timer);
  }
  pendingByChat.delete(chatId);
};

const scheduleDelayedLink = (
  chatId: number,
  url: string,
  run: (input: IngestWorkflowInput, opts: { skipGotIt: boolean }) => Promise<void>
): void => {
  clearPending(chatId);
  const timer = setTimeout(() => {
    pendingByChat.delete(chatId);
    void run(
      {
        inputType: 'telegram_link',
        rawInput: url,
        contextNote: null,
      },
      { skipGotIt: true }
    );
  }, 5000);
  pendingByChat.set(chatId, { url, timer });
};

export const createBot = (): Bot => {
  if (!config.TELEGRAM_BOT_TOKEN) {
    throw new Error('TELEGRAM_BOT_TOKEN is required');
  }

  const bot = new Bot(config.TELEGRAM_BOT_TOKEN);

  bot.use(async (ctx, next) => {
    if (
      config.TELEGRAM_ALLOWED_USER_ID &&
      ctx.from?.id.toString() !== config.TELEGRAM_ALLOWED_USER_ID
    ) {
      logger.warn(
        {
          fromId: ctx.from?.id,
          fromUsername: ctx.from?.username,
          expectedUserId: config.TELEGRAM_ALLOWED_USER_ID,
        },
        'Telegram update ignored: TELEGRAM_ALLOWED_USER_ID mismatch'
      );
      try {
        await ctx.reply(
          `Not authorized for this bot.\n\nYour Telegram user id: ${ctx.from?.id ?? 'unknown'}\n` +
            `Set Railway env TELEGRAM_ALLOWED_USER_ID to that number (or remove it to allow any user).`
        );
      } catch (replyErr) {
        logger.warn({ replyErr }, 'Could not send Telegram unauthorized reply');
      }
      return;
    }
    await next();
  });

  const runWorkflow = async (
    ctx: Context,
    input: IngestWorkflowInput,
    options?: { skipGotIt?: boolean }
  ): Promise<void> => {
    try {
      if (!options?.skipGotIt) {
        await ctx.reply('Got it ✓');
      }
      const { runId } = await runIngestWorkflow(input);
      logger.info({ runId }, 'Ingest workflow started');
      await ctx.reply("Processing... I'll let you know when the draft is ready.");
      void pollWorkflowRun(runId, async (result) => {
        const status = (result as { status?: string })?.status;
        if (workflowAwaitingHumanReview(result)) {
          const name = extractDraftNameFromMastraResult(result) ?? 'Unnamed';
          await ctx.reply(`Draft ready: ${name}\nOpen Admin → /admin/ingest/ to review.`);
        } else if (status === 'bailed') {
          await ctx.reply('Skipped — content not suitable for Portal.');
        } else if (status === 'success') {
          await ctx.reply('Published ✓');
        } else if (status === 'failed') {
          logger.warn({ result }, 'Workflow failed');
          await ctx.reply('Extraction failed — check Mastra logs or try another URL.');
        } else if (status === 'timeout') {
          await ctx.reply(
            'Timed out waiting for result — check /admin/ingest/ manually.'
          );
        } else {
          await ctx.reply('Extraction finished — check /admin/ingest/.');
        }
      });
    } catch (error) {
      logger.error({ error }, 'Mastra ingest workflow failed');
      await ctx.reply('Failed to start workflow — check dashboard / logs.');
    }
  };

  bot.on('message:text', async (ctx) => {
    const text = ctx.message.text.trim();
    const chatId = ctx.chat.id;

    const urlMatch = text.match(URL_IN_TEXT);
    const url = urlMatch?.[0];

    if (url) {
      scheduleDelayedLink(chatId, url, (inp, opts) => runWorkflow(ctx, inp, opts));
      await ctx.reply(
        'Got it ✓ — starting in 5s. Send a short note now if you want extra context.'
      );
      return;
    }

    const pending = pendingByChat.get(chatId);
    if (pending) {
      clearPending(chatId);
      await runWorkflow(ctx, {
        inputType: 'telegram_link',
        rawInput: pending.url,
        contextNote: text,
      });
      return;
    }

    await runWorkflow(ctx, {
      inputType: 'telegram_text',
      rawInput: text,
      contextNote: null,
    });
  });

  bot
    .on('message')
    .filter((ctx) => {
      const msg = ctx.message;
      if (!msg) {
        return false;
      }
      const hasText = 'text' in msg && typeof msg.text === 'string';
      return !hasText;
    })
    .use(async (ctx) => {
      logger.info(
        { chatId: ctx.chat?.id, keys: ctx.message ? Object.keys(ctx.message) : [] },
        'Telegram message type not supported for ingest'
      );
      await ctx.reply(
        'Send a text message with an https:// link (optional short note right after), or plain text to search.\n\n' +
          'Photo uploads are not used for this pipeline.'
      );
    });

  return bot;
};

/* istanbul ignore file */
import { Bot } from 'grammy';
import { DraftStatus, ItemType } from '@prisma/client';
import { config } from '../../config/index.js';
import { prisma } from '../../services/prisma.js';
import { createLogger } from '../../services/logger.js';
import { extractDraftFields } from './llm-mapper.js';
import { detectSourceType } from './source-detect.js';
import { fetchGooglePlace } from './fetchers/google-places.js';
import { fetchInstagramPost } from './fetchers/instagram.js';
import { fetchWebsite } from './fetchers/website.js';
import type { DraftFields } from './types.js';

const logger = createLogger({ component: 'ingest-bot' });
const chatContext = new Map<number, { draftId: string; atMs: number }>();

const createDraftFromExtraction = async (params: {
  inputType: string;
  sourceUrl?: string;
  rawInput?: string;
  imageUrl?: string | null;
  imageBase64?: string;
  imageMimeType?: string;
  partialFields?: Partial<DraftFields>;
  preferredType?: ItemType;
}): Promise<{ id: string; name: string | null }> => {
  const { fields, flaggedFields } = await extractDraftFields({
    rawText: params.rawInput,
    sourceUrl: params.sourceUrl,
    imageBase64: params.imageBase64,
    imageMimeType: params.imageMimeType,
    partialFields: params.partialFields,
    preferredType: params.preferredType,
  });

  const draft = await prisma.draft.create({
    data: {
      status: DraftStatus.PENDING,
      inputType: params.inputType,
      sourceUrl: params.sourceUrl ?? null,
      rawInput: params.rawInput ?? null,
      itemType: fields.itemType,
      name: fields.name,
      description: fields.description,
      category: fields.category,
      address: fields.address,
      neighborhood: fields.neighborhood,
      startTime: fields.startTime ? new Date(fields.startTime) : null,
      endTime: fields.endTime ? new Date(fields.endTime) : null,
      tags: fields.tags,
      imageUrl: params.imageUrl ?? fields.imageUrl,
      flaggedFields,
    },
  });
  return { id: draft.id, name: draft.name };
};

const loadImageFromTelegram = async (
  bot: Bot,
  fileId: string
): Promise<{ data: string; mimeType: string }> => {
  const file = await bot.api.getFile(fileId);
  if (!file.file_path || !config.TELEGRAM_BOT_TOKEN) {
    throw new Error('Could not resolve Telegram file path');
  }
  const fileUrl = `https://api.telegram.org/file/bot${config.TELEGRAM_BOT_TOKEN}/${file.file_path}`;
  const response = await fetch(fileUrl, { signal: AbortSignal.timeout(15000) });
  if (!response.ok) {
    throw new Error(`Failed to download Telegram image (${response.status})`);
  }
  const mimeType = response.headers.get('content-type') ?? 'image/jpeg';
  const data = Buffer.from(await response.arrayBuffer()).toString('base64');
  return { data, mimeType };
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

  bot.on('message:photo', async (ctx) => {
    try {
      await ctx.reply('Got it.');
      const largestPhoto = ctx.message.photo[ctx.message.photo.length - 1];
      if (!largestPhoto) {
        throw new Error('Photo payload missing');
      }
      const image = await loadImageFromTelegram(bot, largestPhoto.file_id);

      const caption = ctx.message.caption?.trim();
      const created = await createDraftFromExtraction({
        inputType: 'telegram_photo',
        rawInput: caption,
        imageBase64: image.data,
        imageMimeType: image.mimeType,
      });
      chatContext.set(ctx.chat.id, { draftId: created.id, atMs: Date.now() });
      await ctx.reply(`Draft ready: ${created.name ?? 'Unnamed'}`);
    } catch (error) {
      logger.error({ error }, 'Telegram photo handling failed');
      await ctx.reply('Extraction failed.');
    }
  });

  bot.on('message:text', async (ctx) => {
    const text = ctx.message.text.trim();
    try {
      await ctx.reply('Got it.');

      const previous = chatContext.get(ctx.chat.id);
      if (previous && Date.now() - previous.atMs < 60000 && !text.includes('http')) {
        const existing = await prisma.draft.findUnique({
          where: { id: previous.draftId },
        });
        if (existing) {
          const rawInput = [existing.rawInput, text].filter(Boolean).join('\n');
          const { fields, flaggedFields } = await extractDraftFields({
            rawText: rawInput,
            partialFields: {
              itemType: existing.itemType,
              name: existing.name,
              description: existing.description,
              category: existing.category,
              address: existing.address,
              neighborhood: existing.neighborhood,
              tags: existing.tags,
              imageUrl: existing.imageUrl,
            },
          });
          await prisma.draft.update({
            where: { id: existing.id },
            data: {
              rawInput,
              itemType: fields.itemType,
              name: fields.name,
              description: fields.description,
              category: fields.category,
              address: fields.address,
              neighborhood: fields.neighborhood,
              startTime: fields.startTime ? new Date(fields.startTime) : null,
              endTime: fields.endTime ? new Date(fields.endTime) : null,
              tags: fields.tags,
              imageUrl: fields.imageUrl,
              flaggedFields,
            },
          });
          await ctx.reply(`Draft updated: ${fields.name ?? 'Unnamed'}`);
          return;
        }
      }

      if (text.includes('http://') || text.includes('https://')) {
        const match = text.match(/https?:\/\/\S+/i);
        const url = match?.[0];
        if (!url) {
          throw new Error('Link text had no valid URL');
        }
        const sourceType = detectSourceType(url);
        const fetcherResult =
          sourceType === 'google_maps'
            ? await fetchGooglePlace(url)
            : sourceType === 'instagram_post'
              ? await fetchInstagramPost(url)
              : await fetchWebsite(url);

        const created = await createDraftFromExtraction({
          inputType: 'telegram_link',
          sourceUrl: url,
          rawInput: fetcherResult.rawText ?? text,
          imageUrl: fetcherResult.imageUrl,
          partialFields: fetcherResult,
        });
        chatContext.set(ctx.chat.id, { draftId: created.id, atMs: Date.now() });
        await ctx.reply(`Draft ready: ${created.name ?? 'Unnamed'}`);
        return;
      }

      const created = await createDraftFromExtraction({
        inputType: 'telegram_text',
        rawInput: text,
      });
      chatContext.set(ctx.chat.id, { draftId: created.id, atMs: Date.now() });
      await ctx.reply(`Draft ready: ${created.name ?? 'Unnamed'}`);
    } catch (error) {
      logger.error({ error }, 'Telegram text handling failed');
      await ctx.reply('Extraction failed.');
    }
  });

  // Anything that isn’t plain text or photo (e.g. document, voice, sticker, location-only)
  bot
    .on('message')
    .filter((ctx) => {
      const msg = ctx.message;
      if (!msg) {
        return false;
      }
      const hasPhoto = 'photo' in msg && Array.isArray(msg.photo) && msg.photo.length > 0;
      const hasText = 'text' in msg && typeof msg.text === 'string';
      return !hasPhoto && !hasText;
    })
    .use(async (ctx) => {
      logger.info(
        { chatId: ctx.chat?.id, keys: ctx.message ? Object.keys(ctx.message) : [] },
        'Telegram message type not supported for ingest'
      );
      await ctx.reply(
        'I only handle text (include a full https:// link for places) or photos.\n\n' +
          'Tip: paste the URL as plain text, or send a photo with optional caption.'
      );
    });

  return bot;
};

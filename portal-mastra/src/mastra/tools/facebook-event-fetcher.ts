import { createTool } from '@mastra/core/tools';
import * as cheerio from 'cheerio';
import { z } from 'zod';
import { BROWSER_USER_AGENT } from './constants.js';

const readMeta = ($: cheerio.CheerioAPI, key: string): string | undefined => {
  const content =
    $(`meta[property="${key}"]`).attr('content') ?? $(`meta[name="${key}"]`).attr('content');
  return content?.trim();
};

const parseJsonLdEvents = (html: string): Record<string, unknown>[] => {
  const out: Record<string, unknown>[] = [];
  const re = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html)) !== null) {
    try {
      const parsed = JSON.parse(m[1]!.trim()) as unknown;
      const arr = Array.isArray(parsed) ? parsed : [parsed];
      for (const item of arr) {
        if (item && typeof item === 'object') out.push(item as Record<string, unknown>);
      }
    } catch {
      /* skip */
    }
  }
  return out;
};

export const facebookEventFetcher = createTool({
  id: 'facebook-event-fetcher',
  description:
    'Fetches a public Facebook event page and extracts title, description, cover image (og:image), and event times from Open Graph and JSON-LD Event schema when present.',
  inputSchema: z.object({
    url: z.string().url(),
  }),
  outputSchema: z.object({
    name: z.string().nullable(),
    description: z.string().nullable(),
    imageUrl: z.string().nullable(),
    startTime: z.string().nullable(),
    endTime: z.string().nullable(),
    rawText: z.string(),
  }),
  execute: async (inputData) => {
    const { url } = inputData;
    try {
      const res = await fetch(url, {
        headers: { 'User-Agent': BROWSER_USER_AGENT },
        signal: AbortSignal.timeout(12_000),
        redirect: 'follow',
      });
      if (!res.ok) {
        return {
          name: null,
          description: null,
          imageUrl: null,
          startTime: null,
          endTime: null,
          rawText: '',
        };
      }
      const html = await res.text();
      const $ = cheerio.load(html);

      const ogTitle = readMeta($, 'og:title');
      const pageTitle = $('title').first().text().trim();
      const name = ogTitle ?? (pageTitle || null);
      const description = readMeta($, 'og:description') ?? null;
      const imageUrl = readMeta($, 'og:image') ?? null;

      let startTime: string | null = null;
      let endTime: string | null = null;

      for (const block of parseJsonLdEvents(html)) {
        const t = block['@type'];
        const types = Array.isArray(t) ? t.map(String) : t ? [String(t)] : [];
        if (!types.some((x) => /Event/i.test(x))) continue;
        if (typeof block.startDate === 'string') startTime = block.startDate;
        if (typeof block.endDate === 'string') endTime = block.endDate;
      }

      $('script, style, nav, footer').remove();
      const rawText = $('body').text().replace(/\s+/g, ' ').trim().slice(0, 6000);

      return {
        name,
        description,
        imageUrl,
        startTime,
        endTime,
        rawText,
      };
    } catch {
      return {
        name: null,
        description: null,
        imageUrl: null,
        startTime: null,
        endTime: null,
        rawText: '',
      };
    }
  },
});

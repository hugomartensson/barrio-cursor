import { createTool } from '@mastra/core/tools';
import * as cheerio from 'cheerio';
import { z } from 'zod';
import { BROWSER_USER_AGENT } from './constants.js';

export const instagramFetcher = createTool({
  id: 'instagram-fetcher',
  description: `Best-effort Instagram fetch for post (/p/) or profile URLs. Returns og:image and caption/description.
Often blocked; success:false when blocked. Flag image as unreliable in downstream extraction.`,
  inputSchema: z.object({
    url: z.string().url(),
  }),
  outputSchema: z.object({
    imageUrl: z.string().nullable(),
    caption: z.string().nullable(),
    success: z.boolean(),
  }),
  execute: async (inputData) => {
    const { url } = inputData;
    try {
      const res = await fetch(url, {
        headers: { 'User-Agent': BROWSER_USER_AGENT },
        signal: AbortSignal.timeout(10_000),
        redirect: 'follow',
      });
      if (!res.ok) {
        return { imageUrl: null, caption: null, success: false };
      }
      const html = await res.text();
      if (/login/i.test(html) && /instagram/i.test(html) && html.length < 50_000) {
        return { imageUrl: null, caption: null, success: false };
      }
      const $ = cheerio.load(html);
      const imageUrl = $('meta[property="og:image"]').attr('content')?.trim() ?? null;
      const caption =
        $('meta[property="og:description"]').attr('content')?.trim() ??
        $('meta[name="description"]').attr('content')?.trim() ??
        null;
      return {
        imageUrl,
        caption,
        success: Boolean(imageUrl || caption),
      };
    } catch {
      return { imageUrl: null, caption: null, success: false };
    }
  },
});

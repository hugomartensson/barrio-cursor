/* istanbul ignore file */
import * as cheerio from 'cheerio';
import type { FetcherResult } from '../types.js';

export const fetchInstagramPost = async (url: string): Promise<FetcherResult> => {
  try {
    const response = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0' },
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) {
      return {};
    }
    const html = await response.text();
    const $ = cheerio.load(html);
    const imageUrl = $('meta[property="og:image"]').attr('content')?.trim() ?? null;
    const caption = $('meta[property="og:description"]').attr('content')?.trim() ?? '';
    return {
      imageUrl,
      description: caption || null,
      rawText: caption || undefined,
    };
  } catch {
    return {};
  }
};

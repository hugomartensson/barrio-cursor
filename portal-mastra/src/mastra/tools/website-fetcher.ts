import { createTool } from '@mastra/core/tools';
import * as cheerio from 'cheerio';
import { z } from 'zod';
import { BROWSER_USER_AGENT } from './constants.js';

const readMeta = ($: cheerio.CheerioAPI, key: string): string | undefined => {
  const content =
    $(`meta[property="${key}"]`).attr('content') ?? $(`meta[name="${key}"]`).attr('content');
  return content?.trim();
};

const toAbsolute = (base: string, src: string | undefined): string | null => {
  if (!src?.trim()) return null;
  try {
    return new URL(src.trim(), base).href;
  } catch {
    return null;
  }
};

const parseJsonLdBlocks = (html: string): unknown[] => {
  const blocks: unknown[] = [];
  const re = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html)) !== null) {
    try {
      const parsed = JSON.parse(m[1]!.trim()) as unknown;
      if (Array.isArray(parsed)) {
        blocks.push(...parsed);
      } else {
        blocks.push(parsed);
      }
    } catch {
      // skip invalid JSON-LD
    }
  }
  return blocks;
};

const extractFromJsonLd = (
  blocks: unknown[],
): { name?: string; description?: string; address?: string; imageUrls: string[] } => {
  let name: string | undefined;
  let description: string | undefined;
  let address: string | undefined;
  const imageUrls: string[] = [];

  const collectImage = (v: unknown) => {
    if (typeof v === 'string') imageUrls.push(v);
    else if (v && typeof v === 'object' && 'url' in v && typeof (v as { url: string }).url === 'string') {
      imageUrls.push((v as { url: string }).url);
    }
  };

  for (const block of blocks) {
    if (!block || typeof block !== 'object') continue;
    const o = block as Record<string, unknown>;
    const t = o['@type'];
    const types = Array.isArray(t) ? t.map(String) : t ? [String(t)] : [];
    const isRelevant =
      types.some((x) =>
        /LocalBusiness|Restaurant|FoodEstablishment|Event|Place|Organization|WebPage/i.test(x),
      ) || types.length === 0;

    if (!isRelevant) continue;

    if (typeof o.name === 'string' && !name) name = o.name;
    if (typeof o.description === 'string' && !description) description = o.description;

    const addr = o.address;
    if (typeof addr === 'string' && !address) address = addr;
    if (addr && typeof addr === 'object') {
      const a = addr as Record<string, unknown>;
      const street = typeof a.streetAddress === 'string' ? a.streetAddress : '';
      const city = typeof a.addressLocality === 'string' ? a.addressLocality : '';
      const joined = `${street} ${city}`.trim();
      if (joined && !address) address = joined;
    }

    collectImage(o.image);
    const loc = o.location as Record<string, unknown> | undefined;
    if (loc?.image) collectImage(loc.image);
  }

  return { name, description, address, imageUrls };
};

export const websiteFetcher = createTool({
  id: 'website-fetcher',
  description: `Fetches and parses a webpage for venue/event info.
Extracts name, description, address, images, and JSON-LD (LocalBusiness, Restaurant, Event, Place).
Returns multiple image candidates ranked (og:image first, then larger images from main/article).`,
  inputSchema: z.object({
    url: z.string().url(),
  }),
  outputSchema: z.object({
    name: z.string().nullable(),
    description: z.string().nullable(),
    address: z.string().nullable(),
    imageUrl: z.string().nullable(),
    imageUrls: z.array(z.string()),
    rawText: z.string(),
    structuredData: z.any().nullable(),
    pageTitle: z.string().nullable(),
  }),
  execute: async (inputData) => {
    const { url } = inputData;
    const res = await fetch(url, {
      headers: { 'User-Agent': BROWSER_USER_AGENT },
      redirect: 'follow',
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) {
      return {
        name: null,
        description: null,
        address: null,
        imageUrl: null,
        imageUrls: [],
        rawText: '',
        structuredData: null,
        pageTitle: null,
      };
    }
    const html = await res.text();
    const $ = cheerio.load(html);

    const pageTitle = $('title').first().text().trim() || null;
    const ogTitle = readMeta($, 'og:title');
    const ogDescription = readMeta($, 'og:description') ?? readMeta($, 'description');
    const ogImage = readMeta($, 'og:image');

    const blocks = parseJsonLdBlocks(html);
    const ld = extractFromJsonLd(blocks);

    const candidates: { u: string; score: number }[] = [];
    const push = (u: string | null, score: number) => {
      if (u && !candidates.some((c) => c.u === u)) candidates.push({ u, score });
    };

    if (ogImage) push(toAbsolute(url, ogImage), 100);
    for (const u of ld.imageUrls) push(toAbsolute(url, u), 90);

    const main = $('main, article, [role="main"]').length ? $('main, article, [role="main"]') : $('body');
    main.find('img[src]').each((_, el) => {
      const src = $(el).attr('src');
      const w = parseInt($(el).attr('width') ?? '0', 10);
      const abs = toAbsolute(url, src);
      if (!abs) return;
      const lower = abs.toLowerCase();
      if (lower.includes('pixel') || lower.includes('tracking') || lower.includes('1x1')) return;
      const score = w >= 300 ? 50 + Math.min(w, 1200) / 20 : 20;
      push(abs, score);
    });

    const touch = $('link[rel="apple-touch-icon"]').attr('href');
    if (touch) push(toAbsolute(url, touch), 5);

    candidates.sort((a, b) => b.score - a.score);
    const imageUrls = candidates.map((c) => c.u);
    const imageUrl = imageUrls[0] ?? null;

    $('script, style, nav, footer, noscript').remove();
    const rawText = $('body').text().replace(/\s+/g, ' ').trim().slice(0, 8000);

    return {
      name: ogTitle ?? ld.name ?? pageTitle,
      description: ogDescription ?? ld.description ?? null,
      address: ld.address ?? null,
      imageUrl,
      imageUrls,
      rawText,
      structuredData: blocks.length ? blocks : null,
      pageTitle,
    };
  },
});

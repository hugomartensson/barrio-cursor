import Anthropic from '@anthropic-ai/sdk';
import * as cheerio from 'cheerio';
import { config } from '../config/index.js';
import { logger } from './logger.js';

export interface ScrapedData {
  url: string;
  title?: string;
  description?: string;
  imageUrls: string[];
  siteName?: string;
  textContent: string;
  jsonLd?: Record<string, unknown>;
}

export interface ExtractedEvent {
  title: string;
  description: string;
  category:
    | 'food_drink'
    | 'arts_culture'
    | 'music'
    | 'nightlife'
    | 'sports_outdoors'
    | 'community';
  address: string;
  venueName: string | null;
  startTime: string;
  endTime: string | null;
  isFree: boolean;
  ticketUrl: string | null;
  mediaUrls: string[];
  sourceUrl: string;
}

/**
 * Structure of Claude API response when extracting event data
 */
interface ClaudeEventResponse {
  title?: string;
  description?: string;
  category?: string;
  address?: string;
  venueName?: string | null;
  startTime?: string;
  endTime?: string | null;
  isFree?: boolean;
  ticketUrl?: string | null;
  mediaUrls?: string[];
}

/**
 * Scrape a URL and extract useful content for event extraction.
 * Grabs og: meta tags, JSON-LD structured data, and visible text.
 */
export async function scrapeUrl(url: string): Promise<ScrapedData> {
  logger.info({ url }, 'Scraping URL');

  const response = await fetch(url, {
    headers: {
      'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,es;q=0.8',
    },
    redirect: 'follow',
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch URL: ${response.status} ${response.statusText}`);
  }

  const html = await response.text();
  const $ = cheerio.load(html);

  // Extract Open Graph meta tags
  const ogTitle = $('meta[property="og:title"]').attr('content');
  const ogDescription = $('meta[property="og:description"]').attr('content');
  const ogImage = $('meta[property="og:image"]').attr('content');
  const ogSiteName = $('meta[property="og:site_name"]').attr('content');

  // Collect image URLs from various sources
  const imageUrls: string[] = [];
  if (ogImage) {
    imageUrls.push(ogImage);
  }

  // Look for other large images on the page
  $('img[src]').each((_, el) => {
    const src = $(el).attr('src');
    if (
      src &&
      !src.includes('icon') &&
      !src.includes('logo') &&
      !src.includes('avatar')
    ) {
      const absoluteUrl = src.startsWith('http') ? src : new URL(src, url).toString();
      if (!imageUrls.includes(absoluteUrl)) {
        imageUrls.push(absoluteUrl);
      }
    }
  });

  // Extract JSON-LD structured data (common on Eventbrite, Facebook, etc.)
  let jsonLd: Record<string, unknown> | undefined;
  $('script[type="application/ld+json"]').each((_, el) => {
    try {
      const parsed = JSON.parse($(el).html() ?? '');
      // Look for Event type specifically
      if (parsed['@type'] === 'Event' || parsed['@type']?.includes?.('Event')) {
        jsonLd = parsed;
      } else if (!jsonLd) {
        jsonLd = parsed;
      }
    } catch {
      // Ignore malformed JSON-LD
    }
  });

  // Extract visible text content (trimmed to keep Claude context reasonable)
  // Remove script, style, nav, footer elements
  $('script, style, nav, footer, header, noscript, iframe').remove();
  const textContent = $('body').text().replace(/\s+/g, ' ').trim().slice(0, 5000);

  const scraped: ScrapedData = {
    url,
    title: ogTitle ?? $('title').text() ?? undefined,
    description:
      ogDescription ?? $('meta[name="description"]').attr('content') ?? undefined,
    imageUrls: imageUrls.slice(0, 10), // Cap at 10 to avoid noise
    siteName: ogSiteName ?? undefined,
    textContent,
    jsonLd,
  };

  logger.info(
    {
      url,
      hasTitle: !!scraped.title,
      hasJsonLd: !!scraped.jsonLd,
      imageCount: scraped.imageUrls.length,
      textLength: scraped.textContent.length,
    },
    'URL scraped successfully'
  );

  return scraped;
}

/**
 * Use Claude to extract structured event data from scraped page content.
 */
export async function extractEventWithLLM(scraped: ScrapedData): Promise<ExtractedEvent> {
  const apiKey = config.ANTHROPIC_API_KEY;
  if (!apiKey) {
    throw new Error('ANTHROPIC_API_KEY is not configured');
  }

  const anthropic = new Anthropic({ apiKey });

  // Build context from scraped data
  const contextParts: string[] = [];

  if (scraped.title) {
    contextParts.push(`Page title: ${scraped.title}`);
  }
  if (scraped.description) {
    contextParts.push(`Page description: ${scraped.description}`);
  }
  if (scraped.siteName) {
    contextParts.push(`Site: ${scraped.siteName}`);
  }
  if (scraped.jsonLd) {
    contextParts.push(
      `Structured data (JSON-LD):\n${JSON.stringify(scraped.jsonLd, null, 2)}`
    );
  }
  if (scraped.imageUrls.length > 0) {
    contextParts.push(`Image URLs found:\n${scraped.imageUrls.join('\n')}`);
  }
  contextParts.push(`Page text content:\n${scraped.textContent}`);

  const pageContent = contextParts.join('\n\n---\n\n');

  logger.info(
    { url: scraped.url, contextLength: pageContent.length },
    'Sending to Claude for extraction'
  );

  const message = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    messages: [
      {
        role: 'user',
        content: `Extract event details from this web page content. The event is in Barcelona, Spain.

Return ONLY a JSON object (no markdown, no code fences) with these exact fields:
{
  "title": "event title",
  "description": "1-3 sentence description of the event, written naturally as if recommending it to a friend",
  "category": "one of: food_drink, arts_culture, music, nightlife, sports_outdoors, community",
  "address": "full street address of the venue including city (e.g. 'Carrer de Verdi 32, Barcelona'). If no specific street address is mentioned, use the venue name as the address instead.",
  "venueName": "name of the venue, bar, club, or host. Always try to identify this even if not explicitly labeled.",
  "startTime": "ISO 8601 datetime with timezone (e.g. '2026-02-21T21:00:00+01:00')",
  "endTime": "ISO 8601 datetime. If no clear end time is specified, default to 23:59 on the same day as startTime",
  "isFree": true or false,
  "ticketUrl": "URL to buy tickets or null",
  "mediaUrls": ["array of the best image URLs from the page, max 3"]
}

Rules:
- For dates, use the current year (2026) if year is not specified
- Barcelona timezone is CET (UTC+1) or CEST (UTC+2) in summer
- IMPORTANT: Always try to identify the venue name. If the address is just a city name (e.g. "Barcelona"), use the venue name as the address instead
- For category, use your best judgment based on the event content
- For mediaUrls, pick the highest quality event-related images (not icons, logos, or ads)
- Write the description in English, keep it concise and appealing

Page content:
${pageContent}`,
      },
    ],
  });

  // Extract the text response
  const textBlock = message.content.find((block) => block.type === 'text');
  if (!textBlock || textBlock.type !== 'text') {
    throw new Error('Claude returned no text response');
  }

  let parsed: ClaudeEventResponse;
  try {
    // Try to parse the response, stripping any markdown code fences if present
    let jsonStr = textBlock.text.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '');
    }
    parsed = JSON.parse(jsonStr) as ClaudeEventResponse;
  } catch (e) {
    logger.error({ response: textBlock.text }, 'Failed to parse Claude response as JSON');
    throw new Error(`Claude returned invalid JSON: ${(e as Error).message}`);
  }

  const extracted: ExtractedEvent = {
    title: String(parsed.title ?? scraped.title ?? 'Untitled Event'),
    description: String(parsed.description ?? scraped.description ?? ''),
    category: validateCategory(String(parsed.category ?? 'community')),
    address: String(parsed.address ?? ''),
    venueName: parsed.venueName ? String(parsed.venueName) : null,
    startTime: String(parsed.startTime ?? ''),
    endTime: parsed.endTime ? String(parsed.endTime) : null,
    isFree: Boolean(parsed.isFree ?? true),
    ticketUrl: parsed.ticketUrl ? String(parsed.ticketUrl) : null,
    mediaUrls: Array.isArray(parsed.mediaUrls)
      ? parsed.mediaUrls
          .filter((u: unknown): u is string => typeof u === 'string')
          .slice(0, 3)
      : scraped.imageUrls.slice(0, 3),
    sourceUrl: scraped.url,
  };

  logger.info(
    {
      url: scraped.url,
      title: extracted.title,
      category: extracted.category,
      address: extracted.address,
      mediaCount: extracted.mediaUrls.length,
    },
    'Event extracted successfully'
  );

  return extracted;
}

/**
 * Extract event data from raw pasted text (Instagram caption, flyer text, etc.)
 * No scraping — sends the text directly to Claude.
 */
export async function extractEventFromText(
  text: string,
  sourceUrl?: string
): Promise<ExtractedEvent> {
  const apiKey = config.ANTHROPIC_API_KEY;
  if (!apiKey) {
    throw new Error('ANTHROPIC_API_KEY is not configured');
  }

  const anthropic = new Anthropic({ apiKey });

  logger.info(
    { textLength: text.length, sourceUrl },
    'Sending pasted text to Claude for extraction'
  );

  const message = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    messages: [
      {
        role: 'user',
        content: `Extract event details from this text (likely copied from an Instagram caption or event flyer). The event is in Barcelona, Spain.

Return ONLY a JSON object (no markdown, no code fences) with these exact fields:
{
  "title": "event title",
  "description": "1-3 sentence description of the event, written naturally as if recommending it to a friend",
  "category": "one of: food_drink, arts_culture, music, nightlife, sports_outdoors, community",
  "address": "full street address of the venue including city (e.g. 'Carrer de Verdi 32, Barcelona'). If no specific street address is mentioned, use the venue name as the address instead.",
  "venueName": "name of the venue, bar, club, or host. Always try to identify this even if not explicitly labeled.",
  "startTime": "ISO 8601 datetime with timezone (e.g. '2026-02-21T21:00:00+01:00')",
  "endTime": "ISO 8601 datetime. If no clear end time is specified, default to 23:59 on the same day as startTime",
  "isFree": true or false,
  "ticketUrl": "URL to buy tickets or null"
}

Rules:
- For dates, use the current year (2026) if year is not specified
- Barcelona timezone is CET (UTC+1) or CEST (UTC+2) in summer
- IMPORTANT: Always try to identify the venue name. If the address is just a city name (e.g. "Barcelona"), use the venue name as the address instead
- Write the description in English, keep it concise and appealing

Text:
${text}`,
      },
    ],
  });

  const textBlock = message.content.find((block) => block.type === 'text');
  if (!textBlock || textBlock.type !== 'text') {
    throw new Error('Claude returned no text response');
  }

  let parsed: ClaudeEventResponse;
  try {
    let jsonStr = textBlock.text.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '');
    }
    parsed = JSON.parse(jsonStr) as ClaudeEventResponse;
  } catch (e) {
    logger.error({ response: textBlock.text }, 'Failed to parse Claude response as JSON');
    throw new Error(`Claude returned invalid JSON: ${(e as Error).message}`);
  }

  const extracted: ExtractedEvent = {
    title: String(parsed.title ?? 'Untitled Event'),
    description: String(parsed.description ?? ''),
    category: validateCategory(String(parsed.category ?? 'community')),
    address: String(parsed.address ?? ''),
    venueName: parsed.venueName ? String(parsed.venueName) : null,
    startTime: String(parsed.startTime ?? ''),
    endTime: parsed.endTime ? String(parsed.endTime) : null,
    isFree: Boolean(parsed.isFree ?? true),
    ticketUrl: parsed.ticketUrl ? String(parsed.ticketUrl) : null,
    mediaUrls: [],
    sourceUrl: sourceUrl ?? '',
  };

  logger.info(
    { title: extracted.title, category: extracted.category, address: extracted.address },
    'Event extracted from text successfully'
  );

  return extracted;
}

const VALID_CATEGORIES = [
  'food_drink',
  'arts_culture',
  'music',
  'nightlife',
  'sports_outdoors',
  'community',
] as const;

function validateCategory(category: string): ExtractedEvent['category'] {
  if (VALID_CATEGORIES.includes(category as ExtractedEvent['category'])) {
    return category as ExtractedEvent['category'];
  }
  return 'community';
}

/* istanbul ignore file */
import * as cheerio from 'cheerio';
import type { FetcherResult } from '../types.js';

const userAgent =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const readMeta = ($: cheerio.CheerioAPI, key: string): string | undefined => {
  const content =
    $(`meta[property="${key}"]`).attr('content') ??
    $(`meta[name="${key}"]`).attr('content');
  return content?.trim();
};

export const fetchWebsite = async (url: string): Promise<FetcherResult> => {
  const response = await fetch(url, {
    headers: { 'User-Agent': userAgent },
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) {
    return {};
  }

  const html = await response.text();
  const $ = cheerio.load(html);

  const ogTitle = readMeta($, 'og:title');
  const ogDescription = readMeta($, 'og:description');
  const ogImage = readMeta($, 'og:image');

  const rawJsonLd = $('script[type="application/ld+json"]').first().text();
  let jsonLdAddress: string | null = null;
  if (rawJsonLd) {
    try {
      const parsed = JSON.parse(rawJsonLd) as Record<string, unknown>;
      const location = parsed['location'] as Record<string, unknown> | undefined;
      const address = location?.['address'] as
        | Record<string, unknown>
        | string
        | undefined;
      if (typeof address === 'string') {
        jsonLdAddress = address;
      }
      if (address && typeof address === 'object') {
        const street =
          typeof address['streetAddress'] === 'string' ? address['streetAddress'] : '';
        const city =
          typeof address['addressLocality'] === 'string'
            ? address['addressLocality']
            : '';
        jsonLdAddress = `${street} ${city}`.trim() || null;
      }
    } catch {
      // Best-effort only.
    }
  }

  $('script, style, nav, footer, noscript').remove();
  const rawText = $('body').text().replace(/\s+/g, ' ').trim().slice(0, 6000);

  return {
    name: ogTitle ?? null,
    description: ogDescription ?? null,
    address: jsonLdAddress,
    imageUrl: ogImage ?? null,
    rawText,
  };
};

import { createTool } from '@mastra/core/tools';
import { z } from 'zod';

export const googleImageSearch = createTool({
  id: 'google-image-search',
  description: `Searches the web for images using Google Custom Search and returns up to 10 image URLs.
Use as a fallback when the original URL yields no good photos — search for "[venue/event name] [city]" to find press, editorial, or event photos.
For events, posters and illustrated graphics count as valid results.`,
  inputSchema: z.object({
    query: z.string().min(1),
  }),
  outputSchema: z.object({
    imageUrls: z.array(z.string()),
  }),
  execute: async (inputData) => {
    const apiKey = process.env.GOOGLE_CUSTOM_SEARCH_API_KEY;
    const cx = process.env.GOOGLE_CUSTOM_SEARCH_ENGINE_ID;
    if (!apiKey || !cx) {
      return { imageUrls: [] };
    }

    const url = new URL('https://www.googleapis.com/customsearch/v1');
    url.searchParams.set('key', apiKey);
    url.searchParams.set('cx', cx);
    url.searchParams.set('q', inputData.query);
    url.searchParams.set('searchType', 'image');
    url.searchParams.set('num', '10');

    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) {
      return { imageUrls: [] };
    }

    const data = (await res.json()) as {
      items?: { link?: string }[];
    };

    const imageUrls = (data.items ?? [])
      .map((item) => item.link ?? '')
      .filter((u) => u.startsWith('http'));

    return { imageUrls: imageUrls.slice(0, 10) };
  },
});

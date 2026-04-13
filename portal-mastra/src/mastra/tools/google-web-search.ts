import { createTool } from '@mastra/core/tools';
import { z } from 'zod';

export const googleWebSearch = createTool({
  id: 'google-web-search',
  description: `Search the web via Google Custom Search. Use to find addresses, blog/press photos, Instagram handles, or verify a venue.`,
  inputSchema: z.object({
    query: z.string().min(1),
  }),
  outputSchema: z.object({
    results: z.array(
      z.object({
        title: z.string(),
        snippet: z.string(),
        url: z.string(),
      }),
    ),
  }),
  execute: async (inputData) => {
    const apiKey = process.env.GOOGLE_CUSTOM_SEARCH_API_KEY;
    const cx = process.env.GOOGLE_CUSTOM_SEARCH_ENGINE_ID;
    if (!apiKey || !cx) {
      return { results: [] };
    }

    const url = new URL('https://www.googleapis.com/customsearch/v1');
    url.searchParams.set('key', apiKey);
    url.searchParams.set('cx', cx);
    url.searchParams.set('q', inputData.query);
    url.searchParams.set('num', '8');

    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) {
      return { results: [] };
    }

    const data = (await res.json()) as {
      items?: { title?: string; snippet?: string; link?: string }[];
    };

    return {
      results: (data.items ?? []).map((item) => ({
        title: item.title ?? '',
        snippet: item.snippet ?? '',
        url: item.link ?? '',
      })),
    };
  },
});

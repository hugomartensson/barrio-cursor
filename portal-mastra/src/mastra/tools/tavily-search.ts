import { createTool } from '@mastra/core/tools';
import { tavily } from '@tavily/core';
import { z } from 'zod';

export const tavilySearchTool = createTool({
  id: 'tavily-web-search',
  description: `Search the web via Tavily (AI-oriented snippets). Use to find addresses, blog photos, Instagram handles, or verify a venue.`,
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
    const apiKey = process.env.TAVILY_API_KEY;
    if (!apiKey) {
      return { results: [] };
    }
    const tvly = tavily({ apiKey });
    const response = await tvly.search(inputData.query, { maxResults: 8 });
    return {
      results: (response.results ?? []).map((r) => ({
        title: r.title ?? '',
        snippet: r.content ?? r.rawContent ?? '',
        url: r.url ?? '',
      })),
    };
  },
});

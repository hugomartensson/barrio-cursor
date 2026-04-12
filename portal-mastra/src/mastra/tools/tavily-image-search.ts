import { createTool } from '@mastra/core/tools';
import { tavily } from '@tavily/core';
import { z } from 'zod';

export const tavilyImageSearch = createTool({
  id: 'tavily-image-search',
  description: `Searches the web for images using Tavily and returns up to 10 image URLs.
Use as a fallback when the original URL yields no good photos — search for "[venue/event name] [city]" to find press, editorial, or event photos.`,
  inputSchema: z.object({
    query: z.string().min(1),
  }),
  outputSchema: z.object({
    imageUrls: z.array(z.string()),
  }),
  execute: async (inputData) => {
    const apiKey = process.env.TAVILY_API_KEY;
    if (!apiKey) {
      return { imageUrls: [] };
    }
    const tvly = tavily({ apiKey });
    const response = await tvly.search(inputData.query, {
      maxResults: 10,
      includeImages: true,
    });
    const imageUrls = (response.images ?? [])
      .map((img: unknown) => (typeof img === 'string' ? img : (img as { url?: string }).url ?? ''))
      .filter((u: string) => u.startsWith('http'));
    return { imageUrls: imageUrls.slice(0, 10) };
  },
});

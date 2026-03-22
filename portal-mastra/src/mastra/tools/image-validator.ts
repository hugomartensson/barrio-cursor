import { createTool } from '@mastra/core/tools';
import { GoogleGenAI } from '@google/genai';
import { z } from 'zod';

const PROMPT =
  'Analyze this image for a local discovery app cover photo. Respond with ONLY valid JSON (no markdown) with keys: isPhoto (boolean), isInterior (boolean), isExterior (boolean), isFood (boolean), isLogo (boolean), isIllustration (boolean), qualityScore (number 1-10), description (short string), recommendation (e.g. good cover photo or skip logo).';

export const imageValidator = createTool({
  id: 'image-validator',
  description:
    'Uses Gemini vision to tell if an image URL is a real venue photo vs logo or illustration, and scores cover-photo suitability.',
  inputSchema: z.object({
    imageUrl: z.string().url(),
  }),
  outputSchema: z.object({
    isPhoto: z.boolean(),
    isInterior: z.boolean(),
    isExterior: z.boolean(),
    isFood: z.boolean(),
    isLogo: z.boolean(),
    isIllustration: z.boolean(),
    qualityScore: z.number(),
    description: z.string(),
    recommendation: z.string(),
  }),
  execute: async (inputData) => {
    const apiKey = process.env.GOOGLE_GENERATIVE_AI_API_KEY;
    const fallback = {
      isPhoto: true,
      isInterior: false,
      isExterior: false,
      isFood: false,
      isLogo: false,
      isIllustration: false,
      qualityScore: 5,
      description: 'Could not analyze image',
      recommendation: 'Unable to validate',
    };
    if (!apiKey) return fallback;

    try {
      const res = await fetch(inputData.imageUrl, {
        signal: AbortSignal.timeout(15_000),
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
      });
      if (!res.ok) return fallback;
      const mimeType = res.headers.get('content-type')?.split(';')[0]?.trim() ?? 'image/jpeg';
      if (!mimeType.startsWith('image/')) return fallback;
      const buf = Buffer.from(await res.arrayBuffer());
      if (buf.length > 8 * 1024 * 1024) return fallback;
      const base64 = buf.toString('base64');

      const ai = new GoogleGenAI({ apiKey });
      const response = await ai.models.generateContent({
        model: 'gemini-2.5-flash',
        config: { responseMimeType: 'application/json' },
        contents: [
          {
            role: 'user',
            parts: [{ inlineData: { mimeType, data: base64 } }, { text: PROMPT }],
          },
        ],
      });

      const text = response.text;
      if (!text) return fallback;
      const parsed = JSON.parse(text.trim()) as Record<string, unknown>;
      const q = parsed['qualityScore'];
      return {
        isPhoto: Boolean(parsed['isPhoto']),
        isInterior: Boolean(parsed['isInterior']),
        isExterior: Boolean(parsed['isExterior']),
        isFood: Boolean(parsed['isFood']),
        isLogo: Boolean(parsed['isLogo']),
        isIllustration: Boolean(parsed['isIllustration']),
        qualityScore: typeof q === 'number' ? Math.min(10, Math.max(1, q)) : 5,
        description: typeof parsed['description'] === 'string' ? parsed['description'] : '',
        recommendation:
          typeof parsed['recommendation'] === 'string' ? parsed['recommendation'] : '',
      };
    } catch {
      return fallback;
    }
  },
});

/* istanbul ignore file */
import { GoogleGenAI } from '@google/genai';
import { Category, ItemType } from '@prisma/client';
import { config } from '../../config/index.js';
import { createLogger } from '../../services/logger.js';
import {
  EMPTY_DRAFT_FIELDS,
  type DraftFields,
  type MapperInput,
  REQUIRED_FIELDS,
} from './types.js';

const logger = createLogger({ component: 'ingest-llm-mapper' });

const SYSTEM_PROMPT = `Extract Portal app draft fields from user-submitted content.
Return only strict JSON with keys:
itemType, name, description, category, address, neighborhood, startTime, endTime, tags, imageUrl.
Rules:
- itemType is "spot" or "event".
- category one of: food, drinks, music, art, markets, community.
- startTime/endTime must be ISO strings when available.
- tags is an array of lowercase strings.
- if unknown use null (or [] for tags).`;

const ai = config.GEMINI_API_KEY
  ? new GoogleGenAI({ apiKey: config.GEMINI_API_KEY })
  : null;

const categorySet = new Set(Object.values(Category));
const itemTypeSet = new Set(Object.values(ItemType));

const safeParseCategory = (value: unknown): Category | null => {
  return typeof value === 'string' && categorySet.has(value as Category)
    ? (value as Category)
    : null;
};

const safeParseItemType = (value: unknown): ItemType | null => {
  return typeof value === 'string' && itemTypeSet.has(value as ItemType)
    ? (value as ItemType)
    : null;
};

const parseLlmJson = (text: string): Partial<DraftFields> => {
  const normalized = text
    .trim()
    .replace(/^```json\s*/i, '')
    .replace(/```$/i, '');
  const parsed = JSON.parse(normalized) as Record<string, unknown>;

  return {
    itemType: safeParseItemType(parsed['itemType']),
    name: typeof parsed['name'] === 'string' ? parsed['name'].trim() : null,
    description:
      typeof parsed['description'] === 'string' ? parsed['description'].trim() : null,
    category: safeParseCategory(parsed['category']),
    address: typeof parsed['address'] === 'string' ? parsed['address'].trim() : null,
    neighborhood:
      typeof parsed['neighborhood'] === 'string' ? parsed['neighborhood'].trim() : null,
    startTime: typeof parsed['startTime'] === 'string' ? parsed['startTime'] : null,
    endTime: typeof parsed['endTime'] === 'string' ? parsed['endTime'] : null,
    tags: Array.isArray(parsed['tags'])
      ? parsed['tags'].filter((value): value is string => typeof value === 'string')
      : [],
    imageUrl: typeof parsed['imageUrl'] === 'string' ? parsed['imageUrl'] : null,
  };
};

export const extractDraftFields = async (
  input: MapperInput
): Promise<{ fields: DraftFields; flaggedFields: string[] }> => {
  const baseFields: DraftFields = {
    ...EMPTY_DRAFT_FIELDS,
    ...input.partialFields,
    tags: input.partialFields?.tags ?? [],
    itemType: input.preferredType ?? input.partialFields?.itemType ?? null,
  };

  if (!ai) {
    return {
      fields: baseFields,
      flaggedFields: REQUIRED_FIELDS.filter((key) => {
        const value = baseFields[key];
        return value === null || (Array.isArray(value) && value.length === 0);
      }),
    };
  }

  try {
    const userParts: Array<{
      text?: string;
      inlineData?: { mimeType: string; data: string };
    }> = [];
    if (input.rawText) {
      userParts.push({ text: input.rawText });
    }
    if (input.sourceUrl) {
      userParts.push({ text: `Source URL: ${input.sourceUrl}` });
    }
    if (input.imageBase64 && input.imageMimeType) {
      userParts.push({
        inlineData: {
          mimeType: input.imageMimeType,
          data: input.imageBase64,
        },
      });
    }

    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      config: {
        systemInstruction: SYSTEM_PROMPT,
        responseMimeType: 'application/json',
      },
      contents: [{ role: 'user', parts: userParts }],
    });

    const text = response.text;
    if (!text) {
      return {
        fields: baseFields,
        flaggedFields: REQUIRED_FIELDS.map(String),
      };
    }

    const llmFields = parseLlmJson(text);
    const merged: DraftFields = {
      ...baseFields,
      ...llmFields,
      address: input.partialFields?.address ?? llmFields.address ?? null,
      name: input.partialFields?.name ?? llmFields.name ?? null,
      category: input.partialFields?.category ?? llmFields.category ?? null,
      tags: input.partialFields?.tags ?? llmFields.tags ?? [],
    };

    const flaggedFields = REQUIRED_FIELDS.filter((key) => {
      const value = merged[key];
      return value === null || (Array.isArray(value) && value.length === 0);
    }).map(String);

    return { fields: merged, flaggedFields };
  } catch (error) {
    logger.warn({ error }, 'Failed to extract draft fields with Gemini');
    return {
      fields: baseFields,
      flaggedFields: REQUIRED_FIELDS.map(String),
    };
  }
};

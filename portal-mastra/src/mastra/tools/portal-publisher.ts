import { createTool } from '@mastra/core/tools';
import { z } from 'zod';
import { draftToPublishPayload, getPortalClient } from '../lib/portal-client.js';
import type { Draft } from '../schemas/draft.js';

export const portalPublisher = createTool({
  id: 'portal-publisher',
  description:
    'Publishes a spot or event to the Portal API using configured Portal credentials. imageUrl must already be hosted (e.g. Supabase).',
  inputSchema: z.object({
    type: z.enum(['spot', 'event']),
    name: z.string(),
    description: z.string(),
    category: z.string(),
    address: z.string(),
    neighborhood: z.string(),
    imageUrl: z.string(),
    startTime: z.string().optional(),
    endTime: z.string().optional(),
    collectionId: z.string().optional(),
  }),
  outputSchema: z.object({
    portalId: z.string(),
    portalType: z.string(),
  }),
  execute: async (inputData) => {
    const draft: Draft = {
      type: inputData.type,
      name: inputData.name,
      description: inputData.description,
      category: inputData.category as Draft['category'],
      address: inputData.address,
      neighborhood: inputData.neighborhood,
      imageUrl: inputData.imageUrl,
      imageUrls: [],
      sourceUrl: null,
      flaggedFields: [],
      startTime: inputData.startTime ?? null,
      endTime: inputData.endTime ?? null,
    };
    const payload = draftToPublishPayload(
      { ...draft, collectionId: inputData.collectionId ?? null },
      inputData.imageUrl,
    );
    return getPortalClient().publish(payload);
  },
});

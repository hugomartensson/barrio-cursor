import { z } from 'zod';

export const portalCategorySchema = z.enum([
  'food',
  'drinks',
  'music',
  'art',
  'markets',
  'community',
]);

export const draftSchema = z.object({
  type: z.enum(['spot', 'event']),
  name: z.string().nullable(),
  description: z.string().nullable(),
  category: portalCategorySchema.nullable(),
  address: z.string().nullable(),
  neighborhood: z.string().nullable(),
  imageUrl: z.string().nullable(),
  imageUrls: z.array(z.string()),
  sourceUrl: z.string().nullable(),
  flaggedFields: z.array(z.string()),
  startTime: z.string().nullable(),
  endTime: z.string().nullable(),
  /** From enrich step or admin validate — forwarded to POST /spots|events to skip geocode. */
  latitude: z.number().nullable().optional(),
  longitude: z.number().nullable().optional(),
  resolvedAddress: z.string().nullable().optional(),
  placeId: z.string().nullable().optional(),
  publishReady: z.boolean().optional(),
  publishBlockers: z.array(z.string()).optional(),
});

export const verifiedDraftSchema = draftSchema.extend({
  verifierNotes: z.string().nullable(),
});

export const humanSuspendSchema = z.object({
  draft: verifiedDraftSchema,
  message: z.string(),
});

export const humanResumeSchema = z.object({
  approved: z.boolean(),
  correctedFields: draftSchema.partial().optional(),
  collectionId: z.string().nullable().optional(),
});

export const publishInputSchema = draftSchema.extend({
  collectionId: z.string().nullable().optional(),
});

export const workflowInputSchema = z.object({
  inputType: z.enum(['telegram_link', 'telegram_text', 'batch_yaml']),
  rawInput: z.string(),
  contextNote: z.string().nullable(),
});

export const publishOutputSchema = z.object({
  portalId: z.string(),
  portalType: z.string(),
});

export type Draft = z.infer<typeof draftSchema>;
export type VerifiedDraft = z.infer<typeof verifiedDraftSchema>;
export type WorkflowInput = z.infer<typeof workflowInputSchema>;

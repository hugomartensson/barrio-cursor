import { z } from 'zod';

export const suggestQuerySchema = z.object({
  q: z.string().min(1).max(200),
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  sessionToken: z.string().uuid('sessionToken must be a UUID'),
  limit: z.coerce.number().int().min(1).max(20).optional().default(8),
});

export const placeDetailsParamsSchema = z.object({
  placeId: z.string().min(1).max(500),
});

export const placeDetailsQuerySchema = z.object({
  sessionToken: z.string().uuid('sessionToken must be a UUID'),
});

export type SuggestQuery = z.infer<typeof suggestQuerySchema>;

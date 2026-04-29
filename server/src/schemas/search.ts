import { z } from 'zod';

export const suggestQuerySchema = z.object({
  q: z.string().min(1).max(200),
  // lat/lng are optional: the iOS client omits them when no GPS fix is
  // available so Google falls back to IP-based localization instead of
  // biasing to a stale fallback location (e.g. Stockholm).
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  sessionToken: z.string().uuid('sessionToken must be a UUID'),
  limit: z.coerce.number().int().min(1).max(20).optional().default(15),
});

export const placeDetailsParamsSchema = z.object({
  placeId: z.string().min(1).max(500),
});

export const placeDetailsQuerySchema = z.object({
  sessionToken: z.string().uuid('sessionToken must be a UUID'),
});

export type SuggestQuery = z.infer<typeof suggestQuerySchema>;

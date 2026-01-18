import { z } from 'zod';

// Category enum matching Prisma schema
export const categoryEnum = z.enum([
  'food_drink',
  'arts_culture',
  'music',
  'nightlife',
  'sports_outdoors',
  'community',
]);

export const createEventSchema = z.object({
  title: z.string().min(1, 'Title is required').max(200, 'Title too long'),
  description: z
    .string()
    .min(1, 'Description is required')
    .max(2000, 'Description too long'),
  category: categoryEnum,
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  startTime: z.string().datetime({ message: 'Invalid start time format' }),
  endTime: z.string().datetime({ message: 'Invalid end time format' }).optional(),
  media: z
    .array(
      z.object({
        url: z.string().url('Invalid media URL'),
        type: z.enum(['photo', 'video']),
      })
    )
    .max(3, 'Maximum 3 media items allowed')
    .optional()
    .default([]),
});

export const nearbyEventsSchema = z.object({
  lat: z.string().transform((v) => parseFloat(v)),
  lng: z.string().transform((v) => parseFloat(v)),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v, 10) : 50)),
});

export const eventIdSchema = z.object({
  id: z.string().uuid('Invalid event ID'),
});

export type CreateEventInput = z.infer<typeof createEventSchema>;
export type NearbyEventsQuery = z.infer<typeof nearbyEventsSchema>;

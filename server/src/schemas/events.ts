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
  address: z.string().min(1, 'Address is required'), // PRD: Address is primary, coordinates derived
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  startTime: z.string().datetime({ message: 'Invalid start time format' }),
  // PRD: Open-ended events are allowed; endTime is optional
  // - When provided, must be a valid ISO datetime string
  // - When omitted or null, the event is treated as having no explicit end time
  endTime: z
    .string()
    .datetime({ message: 'Invalid end time format' })
    .nullable()
    .optional(),
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

/**
 * Schema for updating an event
 * PRD Section 4.2: Edit Permissions - Users can edit future and ongoing events
 * All fields optional for partial updates
 */
export const updateEventSchema = z.object({
  title: z.string().min(1, 'Title is required').max(200, 'Title too long').optional(),
  description: z
    .string()
    .min(1, 'Description is required')
    .max(2000, 'Description too long')
    .optional(),
  category: categoryEnum.optional(),
  address: z.string().min(1, 'Address is required').optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  startTime: z.string().datetime({ message: 'Invalid start time format' }).optional(),
  endTime: z.string().datetime({ message: 'Invalid end time format' }).optional(),
  isFree: z.boolean().optional(),
  media: z
    .array(
      z.object({
        url: z.string().url('Invalid media URL'),
        type: z.enum(['photo', 'video']),
      })
    )
    .max(3, 'Maximum 3 media items allowed')
    .optional(),
});

export const nearbyEventsSchema = z.object({
  lat: z.string().transform((v) => parseFloat(v)),
  lng: z.string().transform((v) => parseFloat(v)),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v, 10) : 50)),
  followingOnly: z
    .string()
    .optional()
    .transform((v) => v === 'true' || v === '1'),
});

export const eventIdSchema = z.object({
  id: z.string().uuid('Invalid event ID'),
});

export type CreateEventInput = z.infer<typeof createEventSchema>;
export type UpdateEventInput = z.infer<typeof updateEventSchema>;
export type NearbyEventsQuery = z.infer<typeof nearbyEventsSchema>;

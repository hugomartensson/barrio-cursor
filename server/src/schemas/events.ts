import { z } from 'zod';

// PRD categories: Food, Drinks, Music, Art, Markets, Community
export const categoryEnum = z.enum([
  'food',
  'drinks',
  'music',
  'art',
  'markets',
  'community',
]);

export const createEventSchema = z.object({
  title: z.string().min(1, 'Title is required').max(200, 'Title too long'),
  description: z
    .string()
    .min(1, 'Description is required')
    .max(2000, 'Description too long'),
  category: categoryEnum,
  address: z.string().min(1, 'Address is required'),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  startTime: z.string().datetime({ message: 'Invalid start time format' }),
  endTime: z
    .string()
    .datetime({ message: 'Invalid end time format' })
    .nullable()
    .optional(),
  media: z
    .array(
      z.object({
        url: z.string().url('Invalid media URL'),
        type: z.enum(['photo']),
        thumbnailUrl: z.string().url('Invalid thumbnail URL').optional(),
      })
    )
    .min(1, 'At least one image is required')
    .max(1, 'Maximum 1 image allowed'),
  ticketUrl: z.string().url('Invalid ticket URL').optional(),
});

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
  media: z
    .array(
      z.object({
        url: z.string().url('Invalid media URL'),
        type: z.enum(['photo']),
        thumbnailUrl: z.string().url('Invalid thumbnail URL').optional(),
      })
    )
    .max(1, 'Maximum 1 image allowed')
    .optional(),
  ticketUrl: z.string().url('Invalid ticket URL').optional(),
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

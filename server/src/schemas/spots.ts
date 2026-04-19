import { z } from 'zod';
import { categoryEnum } from './events.js';

export const listSpotsQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().min(100).max(100_000).optional().default(5000),
  limit: z.coerce.number().min(1).max(100).optional().default(50),
  category: categoryEnum.optional(),
});

export const createSpotSchema = z
  .object({
    name: z.string().min(1, 'Name is required').max(200, 'Name too long'),
    description: z
      .string()
      .min(1, 'Description is required')
      .max(2000, 'Description too long'),
    category: categoryEnum,
    address: z.string().min(1, 'Address is required'),
    neighborhood: z.string().max(100).optional(),
    image: z.object({
      url: z.string().url('Invalid image URL'),
      thumbnailUrl: z.string().url('Invalid thumbnail URL').optional(),
    }),
    /** When both set (e.g. after validate / enrich), POST /spots skips Geocoding API. */
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional(),
  })
  .refine(
    (d) =>
      (d.latitude === undefined && d.longitude === undefined) ||
      (d.latitude !== undefined && d.longitude !== undefined),
    {
      message: 'latitude and longitude must both be provided or both omitted',
      path: ['latitude'],
    }
  );

export const updateSpotSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  description: z.string().min(1).max(2000).optional(),
  category: categoryEnum.optional(),
  address: z.string().min(1).optional(),
  neighborhood: z.string().max(100).optional(),
  image: z
    .object({
      url: z.string().url('Invalid image URL'),
      thumbnailUrl: z.string().url('Invalid thumbnail URL').optional(),
    })
    .optional(),
});

export const spotIdSchema = z.object({
  id: z.string().uuid('Invalid spot ID'),
});

export type ListSpotsQuery = z.infer<typeof listSpotsQuerySchema>;
export type CreateSpotInput = z.infer<typeof createSpotSchema>;
export type UpdateSpotInput = z.infer<typeof updateSpotSchema>;

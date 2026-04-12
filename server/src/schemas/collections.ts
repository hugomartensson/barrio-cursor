import { z } from 'zod';

const itemTypeSchema = z.enum(['spot', 'event']);
const visibilitySchema = z.enum(['private', 'friends', 'public']);

export const createCollectionSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100, 'Name too long'),
  description: z.string().max(500).optional(),
  visibility: visibilitySchema.optional(),
  /** Supabase public URL for collection cover (optional). */
  coverImageUrl: z.string().max(2048).optional(),
});

export const updateCollectionSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().max(500).optional().nullable(),
  visibility: visibilitySchema.optional(),
  coverImageUrl: z.string().max(2048).optional().nullable(),
});

export const collectionIdSchema = z.object({
  id: z.string().uuid('Invalid collection ID'),
});

export const saveToCollectionSchema = z.object({
  itemType: itemTypeSchema,
  itemId: z.string().uuid('Invalid item ID'),
});

export type CreateCollectionInput = z.infer<typeof createCollectionSchema>;
export type UpdateCollectionInput = z.infer<typeof updateCollectionSchema>;
export type SaveToCollectionInput = z.infer<typeof saveToCollectionSchema>;

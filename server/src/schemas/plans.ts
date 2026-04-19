import { z } from 'zod';

const itemTypeSchema = z.enum(['spot', 'event']);

export const createPlanSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100, 'Name too long'),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'startDate must be YYYY-MM-DD'),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'endDate must be YYYY-MM-DD'),
  initialItems: z
    .array(
      z.object({
        itemType: itemTypeSchema,
        itemId: z.string().uuid(),
        dayOffset: z.number().int().min(0).default(0),
      })
    )
    .optional(),
});

export const updatePlanSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  startDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
  endDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
});

export const planIdSchema = z.object({
  id: z.string().uuid('Invalid plan ID'),
});

export const addPlanItemsSchema = z.object({
  items: z
    .array(
      z.object({
        itemType: itemTypeSchema,
        itemId: z.string().uuid(),
        dayOffset: z.number().int().min(0).default(0),
      })
    )
    .min(1),
});

export const planItemIdSchema = z.object({
  id: z.string().uuid(),
  itemId: z.string().uuid(),
});

export const updatePlanItemSchema = z.object({
  dayOffset: z.number().int().min(0),
});

export type CreatePlanInput = z.infer<typeof createPlanSchema>;
export type UpdatePlanInput = z.infer<typeof updatePlanSchema>;
export type AddPlanItemsInput = z.infer<typeof addPlanItemsSchema>;
export type UpdatePlanItemInput = z.infer<typeof updatePlanItemSchema>;

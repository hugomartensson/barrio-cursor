import { z } from 'zod';

/**
 * Schema for creating a plan
 * PRD Section 7.1: Plan Creation
 */
export const createPlanSchema = z.object({
  name: z.string().min(1, 'Plan name is required').max(100, 'Plan name too long'),
  description: z.string().max(500, 'Description too long').optional(),
});

/**
 * Schema for updating a plan
 */
export const updatePlanSchema = z.object({
  name: z
    .string()
    .min(1, 'Plan name is required')
    .max(100, 'Plan name too long')
    .optional(),
  description: z.string().max(500, 'Description too long').optional(),
});

/**
 * Schema for plan ID in URL params
 */
export const planIdSchema = z.object({
  id: z.string().uuid('Invalid plan ID'),
});

/**
 * Schema for event ID in URL params (for adding to plan)
 */
export const eventIdParamSchema = z.object({
  planId: z.string().uuid('Invalid plan ID'),
  eventId: z.string().uuid('Invalid event ID'),
});

export type CreatePlanInput = z.infer<typeof createPlanSchema>;
export type UpdatePlanInput = z.infer<typeof updatePlanSchema>;
export type PlanIdParams = z.infer<typeof planIdSchema>;
export type EventIdParams = z.infer<typeof eventIdParamSchema>;

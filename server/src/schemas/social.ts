import { z } from 'zod';

/**
 * Schema for user ID in URL params
 */
export const userIdSchema = z.object({
  id: z.string().uuid('Invalid user ID'),
});

/**
 * Schema for follow request ID in URL params
 */
export const followRequestIdSchema = z.object({
  id: z.string().uuid('Invalid follow request ID'),
});

export type UserIdParams = z.infer<typeof userIdSchema>;
export type FollowRequestIdParams = z.infer<typeof followRequestIdSchema>;

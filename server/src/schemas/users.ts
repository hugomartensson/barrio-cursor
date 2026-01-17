import { z } from 'zod';

/**
 * Schema for updating user profile
 * Per PRD Section 7.5: Users can edit their name
 */
export const updateUserSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100, 'Name too long'),
});

export type UpdateUserInput = z.infer<typeof updateUserSchema>;

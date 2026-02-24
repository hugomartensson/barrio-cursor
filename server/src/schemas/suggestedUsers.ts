import { z } from 'zod';

export const suggestedUsersQuerySchema = z.object({
  city: z.string().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(50).optional().default(20),
});

export type SuggestedUsersQuery = z.infer<typeof suggestedUsersQuerySchema>;

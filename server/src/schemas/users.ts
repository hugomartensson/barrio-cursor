import { z } from 'zod';

/**
 * Schema for updating user profile
 * PRD Section 7.2: Profile Editing - name, profile picture, privacy toggle
 */
export const updateUserSchema = z
  .object({
    name: z.string().min(1, 'Name is required').max(100, 'Name too long').optional(),
    profilePictureUrl: z.string().url('Invalid URL').optional().nullable(),
    isPrivate: z.boolean().optional(),
  })
  .refine(
    (data) =>
      data.name !== undefined ||
      data.profilePictureUrl !== undefined ||
      data.isPrivate !== undefined,
    {
      message:
        'At least one field (name, profilePictureUrl, or isPrivate) must be provided',
    }
  );

export type UpdateUserInput = z.infer<typeof updateUserSchema>;

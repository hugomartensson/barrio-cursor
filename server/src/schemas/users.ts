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
    selectedCity: z.string().max(100).optional().nullable(), // portal: Discover feed city
  })
  .refine(
    (data) =>
      data.name !== undefined ||
      data.profilePictureUrl !== undefined ||
      data.isPrivate !== undefined ||
      data.selectedCity !== undefined,
    {
      message:
        'At least one field (name, profilePictureUrl, isPrivate, or selectedCity) must be provided',
    }
  );

export type UpdateUserInput = z.infer<typeof updateUserSchema>;

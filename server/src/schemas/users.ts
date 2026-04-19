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
    selectedCity: z.string().max(100).optional().nullable(),
    cities: z
      .array(z.string().trim().min(1).max(100))
      .max(10, 'Maximum 10 cities allowed')
      .optional(),
    bio: z.string().max(280, 'Bio too long').optional().nullable(),
  })
  .refine(
    (data) =>
      data.name !== undefined ||
      data.profilePictureUrl !== undefined ||
      data.isPrivate !== undefined ||
      data.selectedCity !== undefined ||
      data.cities !== undefined ||
      data.bio !== undefined,
    {
      message:
        'At least one field (name, profilePictureUrl, isPrivate, selectedCity, cities, or bio) must be provided',
    }
  );

export type UpdateUserInput = z.infer<typeof updateUserSchema>;

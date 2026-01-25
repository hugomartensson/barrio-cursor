import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { updateUserSchema } from '../schemas/users.js';
import type { UpdateUserInput } from '../schemas/users.js';
import type {
  AuthenticatedRequest,
  ApiErrorResponse,
  RequestWithId,
} from '../types/index.js';

const router = Router();

interface UserProfileResponse {
  data: {
    id: string;
    email: string;
    name: string;
    profilePictureUrl?: string | null;
    isPrivate?: boolean;
    followerCount?: number;
    followingCount?: number;
  };
}

interface UpdateUserResponse {
  data: {
    id: string;
    email: string;
    name: string;
    profilePictureUrl?: string | null;
    isPrivate?: boolean;
  };
}

type PatchRequest = Request<
  object,
  UpdateUserResponse | ApiErrorResponse,
  UpdateUserInput
>;

interface EventData {
  id: string;
  title: string;
  description: string;
  category: string;
  address: string; // PRD: Address is primary
  latitude: number;
  longitude: number;
  startTime: string;
  endTime: string | null;
  createdAt: string;
  interestedCount: number; // PRD: Replaces likesCount/goingCount
  media: {
    id: string;
    url: string;
    type: string;
    order: number;
    thumbnailUrl?: string;
  }[];
  user: { id: string; name: string };
}

interface EventsListResponse {
  data: EventData[];
}

/**
 * GET /users/me - Get current user profile (protected)
 */
router.get(
  '/me',
  requireAuth,
  asyncHandler(
    async (req: Request, res: Response<UserProfileResponse | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;

      const user = await prisma.user.findUnique({
        where: { id: authReq.user.userId },
        select: { id: true, email: true, name: true },
      });

      if (!user) {
        throw ApiError.notFound('User'); // This shouldn't happen if auth is working
      }

      res.json({ data: { id: user.id, email: user.email, name: user.name } });
    }
  )
);

/**
 * GET /users/:id - Get user profile by ID
 * PRD Section 6.3: User Profiles
 */
router.get(
  '/:id',
  requireAuth,
  validateRequest({ params: z.object({ id: z.string().uuid('Invalid user ID') }) }),
  asyncHandler(
    async (req: Request, res: Response<UserProfileResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const userId = req.params['id'] as string;

      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          email: true,
          name: true,
          profilePictureUrl: true,
          isPrivate: true,
          followerCount: true,
          followingCount: true,
        },
      });

      if (!user) {
        throw ApiError.notFound('User');
      }

      // PRD Section 6.1: Private account visibility
      // If private account, only show profile to followers (or self)
      if (user.isPrivate && userId !== authReq.user.userId) {
        const isFollowing = await prisma.follow.findUnique({
          where: {
            followerId_followingId: {
              followerId: authReq.user.userId,
              followingId: userId,
            },
          },
        });

        if (!isFollowing) {
          throw ApiError.forbidden('Profile is private');
        }
      }

      res.json({
        data: {
          id: user.id,
          email: user.email,
          name: user.name,
          profilePictureUrl: user.profilePictureUrl,
          isPrivate: user.isPrivate,
          followerCount: user.followerCount,
          followingCount: user.followingCount,
        },
      });
    }
  )
);

/**
 * PATCH /users/me - Update current user profile (protected)
 * PRD Section 7.2: Profile Editing - name, profile picture, privacy toggle
 */
router.patch(
  '/me',
  requireAuth,
  validateRequest({ body: updateUserSchema }),
  asyncHandler(
    async (req: PatchRequest, res: Response<UpdateUserResponse | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;
      const { name, profilePictureUrl, isPrivate } = req.body;

      // Build update data object (only include fields that are provided)
      const updateData: {
        name?: string;
        profilePictureUrl?: string | null;
        isPrivate?: boolean;
      } = {};

      if (name !== undefined) {
        updateData.name = name;
      }
      if (profilePictureUrl !== undefined) {
        updateData.profilePictureUrl = profilePictureUrl;
      }
      if (isPrivate !== undefined) {
        updateData.isPrivate = isPrivate;
      }

      const updatedUser = await prisma.user.update({
        where: { id: authReq.user.userId },
        data: updateData,
        select: {
          id: true,
          email: true,
          name: true,
          profilePictureUrl: true,
          isPrivate: true,
        },
      });

      res.json({
        data: {
          id: updatedUser.id,
          email: updatedUser.email,
          name: updatedUser.name,
          profilePictureUrl: updatedUser.profilePictureUrl,
          isPrivate: updatedUser.isPrivate ?? false,
        },
      });
    }
  )
);

/**
 * GET /users/me/events - Get events created by current user (protected)
 */
router.get(
  '/me/events',
  requireAuth,
  asyncHandler(
    async (req: Request, res: Response<EventsListResponse | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;

      const events = await prisma.event.findMany({
        where: { userId: authReq.user.userId },
        include: {
          media: { orderBy: { order: 'asc' } },
          user: { select: { id: true, name: true } },
        },
        orderBy: { createdAt: 'desc' },
      });

      res.json({
        data: events.map((event) => formatEvent(event)),
      });
    }
  )
);

/**
 * GET /users/me/interested - Get events current user is interested in (protected)
 * PRD Section 7.1: Profile View - Interested Events section
 */
router.get(
  '/me/interested',
  requireAuth,
  asyncHandler(
    async (req: Request, res: Response<EventsListResponse | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;

      // Get all events the user is interested in
      const interestedRecords = await prisma.interested.findMany({
        where: { userId: authReq.user.userId },
        include: {
          event: {
            include: {
              media: { orderBy: { order: 'asc' } },
              user: { select: { id: true, name: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      // Filter out expired events (PRD: Only show active events)
      const now = new Date();
      const activeEvents = interestedRecords
        .map((ir) => ir.event)
        .filter((event) => {
          // Event is active if: endTime > NOW() OR (endTime IS NULL AND startTime > NOW())
          return event.endTime ? event.endTime > now : event.startTime > now;
        });

      res.json({
        data: activeEvents.map((event) => formatEvent(event)),
      });
    }
  )
);

/**
 * GET /users/:id/events - Get events created by a specific user (protected)
 * PRD Section 6.3: User Profiles - Show user's events
 */
router.get(
  '/:id/events',
  requireAuth,
  validateRequest({ params: z.object({ id: z.string().uuid('Invalid user ID') }) }),
  asyncHandler(
    async (req: Request, res: Response<EventsListResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const userId = req.params['id'] as string;

      // PRD Section 6.1: Private account visibility
      // If private account, only show events to followers (or self)
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, isPrivate: true },
      });

      if (!user) {
        throw ApiError.notFound('User');
      }

      if (user.isPrivate && userId !== authReq.user.userId) {
        const isFollowing = await prisma.follow.findUnique({
          where: {
            followerId_followingId: {
              followerId: authReq.user.userId,
              followingId: userId,
            },
          },
        });

        if (!isFollowing) {
          throw ApiError.forbidden(
            'Events are only visible to followers of private accounts'
          );
        }
      }

      const events = await prisma.event.findMany({
        where: { userId },
        include: {
          media: { orderBy: { order: 'asc' } },
          user: { select: { id: true, name: true } },
        },
        orderBy: { createdAt: 'desc' },
      });

      res.json({
        data: events.map((event) => formatEvent(event)),
      });
    }
  )
);

/**
 * GET /users/:id/interested - Get events a user is interested in (protected)
 * PRD Section 8: Profile carousels - "Interested" for other users
 * Same privacy as /users/:id/events (private → followers only).
 */
router.get(
  '/:id/interested',
  requireAuth,
  validateRequest({ params: z.object({ id: z.string().uuid('Invalid user ID') }) }),
  asyncHandler(
    async (req: Request, res: Response<EventsListResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const userId = req.params['id'] as string;

      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, isPrivate: true },
      });

      if (!user) {
        throw ApiError.notFound('User');
      }

      if (user.isPrivate && userId !== authReq.user.userId) {
        const isFollowing = await prisma.follow.findUnique({
          where: {
            followerId_followingId: {
              followerId: authReq.user.userId,
              followingId: userId,
            },
          },
        });
        if (!isFollowing) {
          throw ApiError.forbidden(
            'Interested events are only visible to followers of private accounts'
          );
        }
      }

      const interestedRecords = await prisma.interested.findMany({
        where: { userId },
        include: {
          event: {
            include: {
              media: { orderBy: { order: 'asc' } },
              user: { select: { id: true, name: true } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      const now = new Date();
      const activeEvents = interestedRecords
        .map((ir) => ir.event)
        .filter((e) => (e.endTime ? e.endTime > now : e.startTime > now));

      res.json({
        data: activeEvents.map((event) => formatEvent(event)),
      });
    }
  )
);

// Helper: Format event for response
function formatEvent(event: {
  id: string;
  title: string;
  description: string;
  category: string;
  address: string; // PRD: Address is primary
  latitude: number;
  longitude: number;
  startTime: Date;
  endTime: Date | null;
  createdAt: Date;
  interestedCount: number; // PRD: Replaces likesCount/goingCount
  media: {
    id: string;
    url: string;
    type: string;
    order: number;
    thumbnailUrl?: string | null;
  }[];
  user: { id: string; name: string };
}): EventData {
  return {
    id: event.id,
    title: event.title,
    description: event.description,
    category: event.category,
    address: event.address,
    latitude: event.latitude,
    longitude: event.longitude,
    startTime: event.startTime.toISOString(),
    endTime: event.endTime?.toISOString() ?? null,
    createdAt: event.createdAt.toISOString(),
    interestedCount: event.interestedCount,
    media: event.media.map((m) => ({
      id: m.id,
      url: m.url,
      type: m.type,
      order: m.order,
      thumbnailUrl: m.thumbnailUrl ?? undefined,
    })),
    user: { id: event.user.id, name: event.user.name },
  };
}

export default router;

import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { updateUserSchema } from '../schemas/users.js';
import type { UpdateUserInput } from '../schemas/users.js';
import { suggestedUsersQuerySchema } from '../schemas/suggestedUsers.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';
import type { EventsListResponse } from '../types/responses.js';
import { formatEvent } from '../utils/eventFormatters.js';

const router = Router();

interface SuggestedUserSummary {
  id: string;
  handle: string | null;
  initials: string | null;
  followerCount: number;
  cities: string[];
  profilePictureUrl: string | null;
}

router.get(
  '/suggested',
  requireAuth,
  validateRequest({ query: suggestedUsersQuerySchema }),
  asyncHandler(
    async (
      req: Request,
      res: Response<{ data: SuggestedUserSummary[] } | ApiErrorResponse>
    ) => {
      const authReq = req as AuthenticatedRequest;
      const userId = authReq.user.userId;
      const query = req.query as unknown as { city?: string; limit?: number };
      const city = query.city;
      const limit = query.limit ?? 20;

      const where: { id?: { not: string }; cities?: { has: string } } = {
        id: { not: userId },
      };
      if (city) {
        where.cities = { has: city };
      }

      const users = await prisma.user.findMany({
        where,
        orderBy: { followerCount: 'desc' },
        take: limit,
        select: {
          id: true,
          handle: true,
          initials: true,
          followerCount: true,
          cities: true,
          profilePictureUrl: true,
        },
      });

      res.json({
        data: users.map((u) => ({
          id: u.id,
          handle: u.handle,
          initials: u.initials,
          followerCount: u.followerCount,
          cities: u.cities,
          profilePictureUrl: u.profilePictureUrl ?? null,
        })),
      });
    }
  )
);

interface UserProfileResponse {
  data: {
    id: string;
    email: string;
    name: string;
    handle?: string | null;
    initials?: string | null;
    profilePictureUrl?: string | null;
    isPrivate?: boolean;
    bio?: string | null;
    followerCount?: number;
    followingCount?: number;
    savedCount?: number;
    collectionsCount?: number;
    followedCount?: number;
    selectedCity?: string | null;
  };
}

interface UpdateUserResponse {
  data: {
    id: string;
    email: string;
    name: string;
    profilePictureUrl?: string | null;
    isPrivate?: boolean;
    selectedCity?: string | null;
    bio?: string | null;
  };
}

type PatchRequest = Request<
  object,
  UpdateUserResponse | ApiErrorResponse,
  UpdateUserInput
>;

/**
 * GET /users/me
 */
router.get(
  '/me',
  requireAuth,
  asyncHandler(
    async (req: Request, res: Response<UserProfileResponse | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;
      const userId = authReq.user.userId;

      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          email: true,
          name: true,
          handle: true,
          initials: true,
          profilePictureUrl: true,
          isPrivate: true,
          followerCount: true,
          followingCount: true,
          selectedCity: true,
          bio: true,
        },
      });

      if (!user) {
        throw ApiError.notFound('User');
      }

      const [savedCount, collectionsCount] = await Promise.all([
        prisma.save.count({ where: { userId } }),
        prisma.collection.count({ where: { userId } }),
      ]);

      res.json({
        data: {
          id: user.id,
          email: user.email,
          name: user.name,
          handle: user.handle ?? undefined,
          initials: user.initials ?? undefined,
          profilePictureUrl: user.profilePictureUrl ?? undefined,
          isPrivate: user.isPrivate,
          followerCount: user.followerCount,
          followingCount: user.followingCount,
          savedCount,
          collectionsCount,
          followedCount: user.followingCount,
          selectedCity: user.selectedCity ?? undefined,
          bio: user.bio ?? undefined,
        },
      });
    }
  )
);

interface SavedSpotItem {
  id: string;
  name: string;
  description: string | null;
  address: string;
  neighborhood: string | null;
  latitude: number;
  longitude: number;
  categoryTag: string | null;
  imageUrl: string | null;
  saveCount: number;
  savedAt: string;
}

interface SavedEventItem {
  id: string;
  title: string;
  description: string;
  category: string;
  address: string;
  latitude: number;
  longitude: number;
  startTime: string;
  endTime: string | null;
  createdAt: string;
  saveCount: number;
  media: {
    id: string;
    url: string;
    type: string;
    order: number;
    thumbnailUrl: string | null;
  }[];
  user: { id: string; name: string };
  savedAt: string;
}

/**
 * GET /users/me/saved-spots
 */
router.get(
  '/me/saved-spots',
  requireAuth,
  asyncHandler(
    async (req: Request, res: Response<{ data: SavedSpotItem[] } | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;
      const userId = authReq.user.userId;

      const saves = await prisma.save.findMany({
        where: { userId, itemType: 'spot' },
        orderBy: { createdAt: 'desc' },
      });
      const spotIds = saves.map((s) => s.itemId);
      const spots = await prisma.spot.findMany({
        where: { id: { in: spotIds } },
        include: { media: { orderBy: { order: 'asc' }, take: 1 } },
      });
      const spotMap = new Map(spots.map((s) => [s.id, s]));

      const data: SavedSpotItem[] = saves
        .map((s) => {
          const spot = spotMap.get(s.itemId);
          if (!spot) {
            return null;
          }
          return {
            id: spot.id,
            name: spot.name,
            description: spot.description,
            address: spot.address,
            neighborhood: spot.neighborhood,
            latitude: spot.latitude,
            longitude: spot.longitude,
            categoryTag: spot.categoryTag,
            imageUrl: spot.media[0]?.url ?? null,
            saveCount: spot.saveCount,
            savedAt: s.createdAt.toISOString(),
          };
        })
        .filter((x): x is SavedSpotItem => x !== null);

      res.json({ data });
    }
  )
);

/**
 * GET /users/me/saved-events
 */
router.get(
  '/me/saved-events',
  requireAuth,
  asyncHandler(
    async (
      req: Request,
      res: Response<{ data: SavedEventItem[] } | ApiErrorResponse>
    ) => {
      const authReq = req as AuthenticatedRequest;
      const userId = authReq.user.userId;

      const saves = await prisma.save.findMany({
        where: { userId, itemType: 'event' },
        orderBy: { createdAt: 'desc' },
      });
      const eventIds = saves.map((s) => s.itemId);
      const events = await prisma.event.findMany({
        where: { id: { in: eventIds } },
        include: {
          media: { orderBy: { order: 'asc' } },
          user: { select: { id: true, name: true } },
        },
      });
      const eventMap = new Map(events.map((e) => [e.id, e]));

      const data: SavedEventItem[] = saves
        .map((s) => {
          const event = eventMap.get(s.itemId);
          if (!event) {
            return null;
          }
          return {
            id: event.id,
            title: event.title,
            description: event.description,
            category: String(event.category),
            address: event.address,
            latitude: event.latitude,
            longitude: event.longitude,
            startTime: event.startTime.toISOString(),
            endTime: event.endTime?.toISOString() ?? null,
            createdAt: event.createdAt.toISOString(),
            saveCount: event.saveCount,
            media: event.media.map((m) => ({
              id: m.id,
              url: m.url,
              type: String(m.type),
              order: m.order,
              thumbnailUrl: m.thumbnailUrl,
            })),
            user: { id: event.user.id, name: event.user.name },
            savedAt: s.createdAt.toISOString(),
          };
        })
        .filter((x): x is SavedEventItem => x !== null);

      res.json({ data });
    }
  )
);

/**
 * GET /users/:id
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
          bio: true,
        },
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
          bio: user.bio ?? undefined,
        },
      });
    }
  )
);

/**
 * PATCH /users/me
 */
router.patch(
  '/me',
  requireAuth,
  validateRequest({ body: updateUserSchema }),
  asyncHandler(
    async (req: PatchRequest, res: Response<UpdateUserResponse | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;
      const { name, profilePictureUrl, isPrivate, selectedCity, bio } = req.body;

      const updateData: {
        name?: string;
        profilePictureUrl?: string | null;
        isPrivate?: boolean;
        selectedCity?: string | null;
        bio?: string | null;
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
      if (selectedCity !== undefined) {
        updateData.selectedCity = selectedCity;
      }
      if (bio !== undefined) {
        const trimmed = typeof bio === 'string' ? bio.trim() : '';
        updateData.bio = trimmed.length === 0 ? null : trimmed;
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
          selectedCity: true,
          bio: true,
        },
      });

      res.json({
        data: {
          id: updatedUser.id,
          email: updatedUser.email,
          name: updatedUser.name,
          profilePictureUrl: updatedUser.profilePictureUrl,
          isPrivate: updatedUser.isPrivate ?? false,
          selectedCity: updatedUser.selectedCity ?? undefined,
          bio: updatedUser.bio ?? undefined,
        },
      });
    }
  )
);

/**
 * GET /users/me/events
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
 * GET /users/me/saved — saved events for current user
 */
router.get(
  '/me/saved',
  requireAuth,
  asyncHandler(
    async (req: Request, res: Response<EventsListResponse | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;

      const saves = await prisma.save.findMany({
        where: { userId: authReq.user.userId, itemType: 'event' },
        orderBy: { createdAt: 'desc' },
        select: { itemId: true },
      });
      const eventIds = saves.map((s) => s.itemId);
      if (eventIds.length === 0) {
        res.json({ data: [] });
        return;
      }
      const events = await prisma.event.findMany({
        where: { id: { in: eventIds } },
        include: {
          media: { orderBy: { order: 'asc' } },
          user: { select: { id: true, name: true } },
        },
      });
      const eventMap = new Map(events.map((e) => [e.id, e]));
      const now = new Date();
      const activeEvents = eventIds
        .map((id) => eventMap.get(id))
        .filter((event): event is NonNullable<typeof event> => {
          if (!event) {
            return false;
          }
          return event.endTime ? event.endTime > now : event.startTime > now;
        });

      res.json({
        data: activeEvents.map((event) => formatEvent(event)),
      });
    }
  )
);

/**
 * GET /users/:id/events
 */
router.get(
  '/:id/events',
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
 * GET /users/:id/saved — saved events for another user (respects privacy)
 */
router.get(
  '/:id/saved',
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
            'Saved events are only visible to followers of private accounts'
          );
        }
      }

      const saves = await prisma.save.findMany({
        where: { userId, itemType: 'event' },
        orderBy: { createdAt: 'desc' },
        select: { itemId: true },
      });
      const eventIds = saves.map((s) => s.itemId);
      if (eventIds.length === 0) {
        res.json({ data: [] });
        return;
      }
      const events = await prisma.event.findMany({
        where: { id: { in: eventIds } },
        include: {
          media: { orderBy: { order: 'asc' } },
          user: { select: { id: true, name: true } },
        },
      });
      const eventMap = new Map(events.map((e) => [e.id, e]));
      const now = new Date();
      const activeEvents = eventIds
        .map((id) => eventMap.get(id))
        .filter((e): e is NonNullable<typeof e> => {
          if (!e) {
            return false;
          }
          return e.endTime ? e.endTime > now : e.startTime > now;
        });

      res.json({
        data: activeEvents.map((event) => formatEvent(event)),
      });
    }
  )
);

export default router;

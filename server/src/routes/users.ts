import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { updateUserSchema } from '../schemas/users.js';
import type { UpdateUserInput } from '../schemas/users.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';

const router = Router();

interface UserProfileResponse {
  data: { id: string; email: string; name: string };
}

interface UpdateUserResponse {
  data: { id: string; email: string; name: string };
}

type PatchRequest = Request<object, UpdateUserResponse | ApiErrorResponse, UpdateUserInput>;

interface EventData {
  id: string;
  title: string;
  description: string;
  category: string;
  latitude: number;
  longitude: number;
  startTime: string;
  endTime: string | null;
  createdAt: string;
  likesCount: number;
  goingCount: number;
  media: { id: string; url: string; type: string; order: number }[];
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
  asyncHandler(async (req: Request, res: Response<UserProfileResponse | ApiErrorResponse>) => {
    const authReq = req as AuthenticatedRequest;

    const user = await prisma.user.findUnique({
      where: { id: authReq.user.userId },
      select: { id: true, email: true, name: true },
    });

    if (!user) {
      throw ApiError.notFound('User'); // This shouldn't happen if auth is working
    }

    res.json({ data: { id: user.id, email: user.email, name: user.name } });
  })
);

/**
 * PATCH /users/me - Update current user profile (protected)
 * Per PRD Section 7.5: Users can edit their name
 */
router.patch(
  '/me',
  requireAuth,
  validateRequest({ body: updateUserSchema }),
  asyncHandler(
    async (req: PatchRequest, res: Response<UpdateUserResponse | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;
      const { name } = req.body;

      const updatedUser = await prisma.user.update({
        where: { id: authReq.user.userId },
        data: { name },
        select: { id: true, email: true, name: true },
      });

      res.json({
        data: {
          id: updatedUser.id,
          email: updatedUser.email,
          name: updatedUser.name,
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

// Helper: Format event for response
function formatEvent(event: {
  id: string;
  title: string;
  description: string;
  category: string;
  latitude: number;
  longitude: number;
  startTime: Date;
  endTime: Date | null;
  createdAt: Date;
  likesCount: number;
  goingCount: number;
  media: { id: string; url: string; type: string; order: number }[];
  user: { id: string; name: string };
}): EventData {
  return {
    id: event.id,
    title: event.title,
    description: event.description,
    category: event.category,
    latitude: event.latitude,
    longitude: event.longitude,
    startTime: event.startTime.toISOString(),
    endTime: event.endTime?.toISOString() ?? null,
    createdAt: event.createdAt.toISOString(),
    likesCount: event.likesCount,
    goingCount: event.goingCount,
    media: event.media.map((m) => ({
      id: m.id,
      url: m.url,
      type: m.type,
      order: m.order,
    })),
    user: { id: event.user.id, name: event.user.name },
  };
}

export default router;

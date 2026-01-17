import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { eventIdSchema } from '../schemas/events.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';

const router = Router();

interface InteractionResponse {
  data: {
    liked: boolean;
    going: boolean;
    likesCount: number;
    goingCount: number;
  };
}

type InteractionReq = Request<{ id: string }, InteractionResponse | ApiErrorResponse>;

/**
 * POST /events/:id/like - Toggle like on an event
 */
router.post(
  '/:id/like',
  requireAuth,
  validateRequest({ params: eventIdSchema }),
  asyncHandler(
    async (
      req: InteractionReq,
      res: Response<InteractionResponse | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const eventId = req.params.id;
      const userId = authReq.user.userId;

      // Check event exists
      const event = await prisma.event.findUnique({ where: { id: eventId } });
      if (!event) {
        throw ApiError.notFound('Event');
      }

      // Check if already liked
      const existingLike = await prisma.like.findUnique({
        where: { userId_eventId: { userId, eventId } },
      });

      if (existingLike) {
        // Unlike: remove like and decrement count
        await prisma.$transaction([
          prisma.like.delete({ where: { userId_eventId: { userId, eventId } } }),
          prisma.event.update({
            where: { id: eventId },
            data: { likesCount: { decrement: 1 } },
          }),
        ]);
      } else {
        // Like: add like and increment count
        await prisma.$transaction([
          prisma.like.create({ data: { userId, eventId } }),
          prisma.event.update({
            where: { id: eventId },
            data: { likesCount: { increment: 1 } },
          }),
        ]);
      }

      // Get updated counts and user status
      const updated = await prisma.event.findUnique({
        where: { id: eventId },
        select: { likesCount: true, goingCount: true },
      });
      const isGoing = await prisma.going.findUnique({
        where: { userId_eventId: { userId, eventId } },
      });

      res.json({
        data: {
          liked: !existingLike,
          going: !!isGoing,
          likesCount: updated?.likesCount ?? 0,
          goingCount: updated?.goingCount ?? 0,
        },
      });
    }
  )
);

/**
 * POST /events/:id/going - Toggle going status on an event
 */
router.post(
  '/:id/going',
  requireAuth,
  validateRequest({ params: eventIdSchema }),
  asyncHandler(
    async (
      req: InteractionReq,
      res: Response<InteractionResponse | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const eventId = req.params.id;
      const userId = authReq.user.userId;

      // Check event exists
      const event = await prisma.event.findUnique({ where: { id: eventId } });
      if (!event) {
        throw ApiError.notFound('Event');
      }

      // Check if already going
      const existingGoing = await prisma.going.findUnique({
        where: { userId_eventId: { userId, eventId } },
      });

      if (existingGoing) {
        // Remove going and decrement count
        await prisma.$transaction([
          prisma.going.delete({ where: { userId_eventId: { userId, eventId } } }),
          prisma.event.update({
            where: { id: eventId },
            data: { goingCount: { decrement: 1 } },
          }),
        ]);
      } else {
        // Add going and increment count
        await prisma.$transaction([
          prisma.going.create({ data: { userId, eventId } }),
          prisma.event.update({
            where: { id: eventId },
            data: { goingCount: { increment: 1 } },
          }),
        ]);
      }

      // Get updated counts and user status
      const updated = await prisma.event.findUnique({
        where: { id: eventId },
        select: { likesCount: true, goingCount: true },
      });
      const isLiked = await prisma.like.findUnique({
        where: { userId_eventId: { userId, eventId } },
      });

      res.json({
        data: {
          liked: !!isLiked,
          going: !existingGoing,
          likesCount: updated?.likesCount ?? 0,
          goingCount: updated?.goingCount ?? 0,
        },
      });
    }
  )
);

export default router;

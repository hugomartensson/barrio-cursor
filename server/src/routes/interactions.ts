import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { eventIdSchema } from '../schemas/events.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';
const router = Router();

interface SaveResponse {
  data: {
    saved: boolean;
    saveCount: number;
  };
}

type SaveReq = Request<{ id: string }, SaveResponse | ApiErrorResponse>;

/**
 * POST /events/:id/save — Toggle save on an event.
 * Saves are pure bookmarks, independent of any collection.
 */
router.post(
  '/:id/save',
  requireAuth,
  validateRequest({ params: eventIdSchema }),
  asyncHandler(async (req: SaveReq, res: Response<SaveResponse | ApiErrorResponse>) => {
    const authReq = req as unknown as AuthenticatedRequest;
    const eventId = req.params.id;
    const userId = authReq.user.userId;

    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      throw ApiError.notFound('Event');
    }

    const existing = await prisma.save.findUnique({
      where: { userId_itemType_itemId: { userId, itemType: 'event', itemId: eventId } },
    });

    if (existing) {
      await prisma.$transaction([
        prisma.save.delete({
          where: {
            userId_itemType_itemId: { userId, itemType: 'event', itemId: eventId },
          },
        }),
        prisma.event.update({
          where: { id: eventId },
          data: { saveCount: { decrement: 1 } },
        }),
      ]);
    } else {
      await prisma.$transaction([
        prisma.save.create({
          data: { userId, itemType: 'event', itemId: eventId, collectionId: null },
        }),
        prisma.event.update({
          where: { id: eventId },
          data: { saveCount: { increment: 1 } },
        }),
      ]);
    }

    const updated = await prisma.event.findUnique({
      where: { id: eventId },
      select: { saveCount: true },
    });
    const isSaved = await prisma.save.findUnique({
      where: { userId_itemType_itemId: { userId, itemType: 'event', itemId: eventId } },
    });

    res.json({
      data: {
        saved: !!isSaved,
        saveCount: updated?.saveCount ?? 0,
      },
    });
  })
);

export default router;

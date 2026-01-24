import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { eventIdSchema } from '../schemas/events.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';

const router = Router();

interface InterestedResponse {
  data: {
    interested: boolean;
    interestedCount: number;
  };
}

type InterestedReq = Request<{ id: string }, InterestedResponse | ApiErrorResponse>;

/**
 * POST /events/:id/interested - Toggle interested status on an event
 * PRD Section 5.3: Interested endpoint replaces Like/Going
 */
router.post(
  '/:id/interested',
  requireAuth,
  validateRequest({ params: eventIdSchema }),
  asyncHandler(
    async (req: InterestedReq, res: Response<InterestedResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const eventId = req.params.id;
      const userId = authReq.user.userId;

      // Check event exists
      const event = await prisma.event.findUnique({ where: { id: eventId } });
      if (!event) {
        throw ApiError.notFound('Event');
      }

      // Check if already interested
      const existingInterested = await prisma.interested.findUnique({
        where: { userId_eventId: { userId, eventId } },
      });

      if (existingInterested) {
        // Remove interested: delete and decrement count
        await prisma.$transaction([
          prisma.interested.delete({
            where: { userId_eventId: { userId, eventId } },
          }),
          prisma.event.update({
            where: { id: eventId },
            data: { interestedCount: { decrement: 1 } },
          }),
        ]);
      } else {
        // Add interested: create and increment count
        await prisma.$transaction([
          prisma.interested.create({ data: { userId, eventId } }),
          prisma.event.update({
            where: { id: eventId },
            data: { interestedCount: { increment: 1 } },
          }),
        ]);
      }

      // Get updated count and user status
      const updated = await prisma.event.findUnique({
        where: { id: eventId },
        select: { interestedCount: true },
      });
      const isInterested = await prisma.interested.findUnique({
        where: { userId_eventId: { userId, eventId } },
      });

      res.json({
        data: {
          interested: !!isInterested,
          interestedCount: updated?.interestedCount ?? 0,
        },
      });
    }
  )
);

export default router;

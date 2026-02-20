/**
 * User events endpoints
 * GET /users/me/events - Get events created by current user
 * GET /users/me/interested - Get events current user is interested in
 * GET /users/:id/events - Get events created by a specific user
 * GET /users/:id/interested - Get events a user is interested in
 */

import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { prisma } from '../../services/prisma.js';
import { requireAuth } from '../../middleware/auth.js';
import { validateRequest } from '../../middleware/validateRequest.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { ApiError } from '../../utils/ApiError.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../../types/index.js';
import type { EventsListResponse } from '../../types/responses.js';
import { formatEvent } from '../../utils/eventFormatters.js';

const router = Router();

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

export default router;

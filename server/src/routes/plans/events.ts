/**
 * Plan events management endpoints
 * POST /plans/:planId/events/:eventId - Add event to plan
 * DELETE /plans/:planId/events/:eventId - Remove event from plan
 */

import { Router, Request, Response } from 'express';
import { prisma } from '../../services/prisma.js';
import { requireAuth } from '../../middleware/auth.js';
import { validateRequest } from '../../middleware/validateRequest.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { ApiError } from '../../utils/ApiError.js';
import { logger } from '../../services/logger.js';
import { eventIdParamSchema } from '../../schemas/plans.js';
import type {
  AuthenticatedRequest,
  ApiErrorResponse,
  RequestWithId,
} from '../../types/index.js';

const router = Router();

/**
 * POST /plans/:planId/events/:eventId - Add event to plan
 * PRD Section 7.2: Adding Events to Plans
 */
router.post(
  '/:planId/events/:eventId',
  requireAuth,
  validateRequest({ params: eventIdParamSchema }),
  asyncHandler(
    async (
      req: Request<{ planId: string; eventId: string }>,
      res: Response<{ data: { message: string } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const planId = req.params['planId'];
      const eventId = req.params['eventId'];

      logger.info(
        {
          requestId,
          userId: currentUserId,
          planId,
          eventId,
        },
        '📋 Adding event to plan'
      );

      // Verify plan ownership
      const plan = await prisma.plan.findUnique({
        where: { id: planId },
        select: { id: true, userId: true },
      });

      if (!plan) {
        throw ApiError.notFound('Plan');
      }

      if (plan.userId !== currentUserId) {
        throw ApiError.forbidden('You can only add events to your own plans');
      }

      // Verify event exists
      const event = await prisma.event.findUnique({
        where: { id: eventId },
        select: { id: true },
      });

      if (!event) {
        throw ApiError.notFound('Event');
      }

      // Check if event is already in plan
      const existingPlanEvent = await prisma.planEvent.findUnique({
        where: {
          planId_eventId: {
            planId,
            eventId,
          },
        },
      });

      if (existingPlanEvent) {
        throw ApiError.badRequest('Event is already in this plan');
      }

      // Add event to plan
      await prisma.planEvent.create({
        data: {
          planId,
          eventId,
        },
      });

      logger.info(
        {
          requestId,
          planId,
          eventId,
        },
        '✅ Event added to plan'
      );

      res.json({ data: { message: 'Event added to plan successfully' } });
    }
  )
);

/**
 * DELETE /plans/:planId/events/:eventId - Remove event from plan
 * PRD Section 7.2: Adding Events to Plans
 */
router.delete(
  '/:planId/events/:eventId',
  requireAuth,
  validateRequest({ params: eventIdParamSchema }),
  asyncHandler(
    async (
      req: Request<{ planId: string; eventId: string }>,
      res: Response<{ data: { message: string } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const planId = req.params['planId'];
      const eventId = req.params['eventId'];

      logger.info(
        {
          requestId,
          userId: currentUserId,
          planId,
          eventId,
        },
        '📋 Removing event from plan'
      );

      // Verify plan ownership
      const plan = await prisma.plan.findUnique({
        where: { id: planId },
        select: { id: true, userId: true },
      });

      if (!plan) {
        throw ApiError.notFound('Plan');
      }

      if (plan.userId !== currentUserId) {
        throw ApiError.forbidden('You can only remove events from your own plans');
      }

      // Check if event is in plan
      const planEvent = await prisma.planEvent.findUnique({
        where: {
          planId_eventId: {
            planId,
            eventId,
          },
        },
      });

      if (!planEvent) {
        throw ApiError.notFound('Event is not in this plan');
      }

      // Remove event from plan
      await prisma.planEvent.delete({
        where: {
          planId_eventId: {
            planId,
            eventId,
          },
        },
      });

      logger.info(
        {
          requestId,
          planId,
          eventId,
        },
        '✅ Event removed from plan'
      );

      res.json({ data: { message: 'Event removed from plan successfully' } });
    }
  )
);

export default router;

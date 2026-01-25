import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { logger } from '../services/logger.js';
import {
  createPlanSchema,
  updatePlanSchema,
  planIdSchema,
  eventIdParamSchema,
} from '../schemas/plans.js';
import type { CreatePlanInput, UpdatePlanInput } from '../schemas/plans.js';
import type {
  AuthenticatedRequest,
  ApiErrorResponse,
  RequestWithId,
} from '../types/index.js';

const router = Router();

// Response types
interface PlanData {
  id: string;
  userId: string;
  name: string;
  description: string | null;
  isArchived: boolean;
  createdAt: string;
  updatedAt: string;
  eventCount: number;
}

interface PlanDetailData extends PlanData {
  events: {
    id: string;
    title: string;
    description: string;
    category: string;
    address: string;
    latitude: number;
    longitude: number;
    startTime: string;
    endTime: string | null;
    interestedCount: number;
    media: { id: string; url: string; type: string; order: number }[];
    user: { id: string; name: string };
  }[];
}

interface PlanResponse {
  data: PlanData;
}

interface PlanDetailResponse {
  data: PlanDetailData;
}

interface PlansListResponse {
  data: PlanData[];
}

// Request types
type CreatePlanReq = Request<object, PlanResponse | ApiErrorResponse, CreatePlanInput>;
type GetPlanReq = Request<{ id: string }, PlanDetailResponse | ApiErrorResponse>;
type UpdatePlanReq = Request<
  { id: string },
  PlanResponse | ApiErrorResponse,
  UpdatePlanInput
>;
type DeletePlanReq = Request<
  { id: string },
  { data: { message: string } } | ApiErrorResponse
>;
type GetPlansReq = Request<object, PlansListResponse | ApiErrorResponse>;

const MAX_ACTIVE_PLANS = 5; // PRD Section 7.1: Maximum 5 active plans

/**
 * POST /plans - Create a new plan
 * PRD Section 7.1: Plan Creation
 * - Max 5 active plans per user
 * - Returns friendly error if limit exceeded
 */
router.post(
  '/',
  requireAuth,
  validateRequest({ body: createPlanSchema }),
  asyncHandler(
    async (req: CreatePlanReq, res: Response<PlanResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const input = req.body;

      logger.info(
        {
          requestId,
          userId: currentUserId,
          planName: input.name,
        },
        '📋 Creating new plan'
      );

      // PRD Section 7.1: Check active plan limit (max 5)
      const activePlanCount = await prisma.plan.count({
        where: {
          userId: currentUserId,
          isArchived: false,
        },
      });

      if (activePlanCount >= MAX_ACTIVE_PLANS) {
        logger.warn(
          {
            requestId,
            userId: currentUserId,
            activePlanCount,
          },
          '⚠️ Plan creation failed: Maximum active plans reached'
        );
        throw ApiError.badRequest(
          `Maximum ${MAX_ACTIVE_PLANS} active plans. Please archive a plan to create a new one.`
        );
      }

      const plan = await prisma.plan.create({
        data: {
          userId: currentUserId,
          name: input.name,
          description: input.description ?? null,
        },
        include: {
          _count: {
            select: { planEvents: true },
          },
        },
      });

      logger.info(
        {
          requestId,
          planId: plan.id,
          planName: plan.name,
        },
        '✅ Plan created successfully'
      );

      res.status(201).json({
        data: {
          id: plan.id,
          userId: plan.userId,
          name: plan.name,
          description: plan.description,
          isArchived: plan.isArchived,
          createdAt: plan.createdAt.toISOString(),
          updatedAt: plan.updatedAt.toISOString(),
          eventCount: plan._count.planEvents,
        },
      });
    }
  )
);

/**
 * GET /plans - Get user's active plans
 * PRD Section 7.3: Viewing & Managing Plans
 */
router.get(
  '/',
  requireAuth,
  asyncHandler(
    async (req: GetPlansReq, res: Response<PlansListResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const currentUserId = authReq.user.userId;

      const plans = await prisma.plan.findMany({
        where: {
          userId: currentUserId,
          isArchived: false, // Only return active plans
        },
        include: {
          _count: {
            select: { planEvents: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      const data = plans.map((plan) => ({
        id: plan.id,
        userId: plan.userId,
        name: plan.name,
        description: plan.description,
        isArchived: plan.isArchived,
        createdAt: plan.createdAt.toISOString(),
        updatedAt: plan.updatedAt.toISOString(),
        eventCount: plan._count.planEvents,
      }));

      logger.info({ count: data.length }, 'GET /plans returning plans');
      res.json({ data });
    }
  )
);

/**
 * GET /plans/:id - Get plan details with events
 * PRD Section 7.3: Viewing & Managing Plans
 * - Events sorted chronologically by startTime
 */
router.get(
  '/:id',
  requireAuth,
  validateRequest({ params: planIdSchema }),
  asyncHandler(
    async (req: GetPlanReq, res: Response<PlanDetailResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const planId = req.params['id'];

      const plan = await prisma.plan.findUnique({
        where: { id: planId },
        include: {
          planEvents: {
            include: {
              event: {
                include: {
                  media: { orderBy: { order: 'asc' } },
                  user: { select: { id: true, name: true } },
                },
              },
            },
            orderBy: {
              event: {
                startTime: 'asc', // PRD: Chronological order
              },
            },
          },
          _count: {
            select: { planEvents: true },
          },
        },
      });

      if (!plan) {
        throw ApiError.notFound('Plan');
      }

      // PRD Section 7.3: Only plan owner can view plan
      if (plan.userId !== currentUserId) {
        throw ApiError.forbidden('You can only view your own plans');
      }

      res.json({
        data: {
          id: plan.id,
          userId: plan.userId,
          name: plan.name,
          description: plan.description,
          isArchived: plan.isArchived,
          createdAt: plan.createdAt.toISOString(),
          updatedAt: plan.updatedAt.toISOString(),
          eventCount: plan._count.planEvents,
          events: plan.planEvents.map((pe) => ({
            id: pe.event.id,
            title: pe.event.title,
            description: pe.event.description,
            category: pe.event.category,
            address: pe.event.address,
            latitude: pe.event.latitude,
            longitude: pe.event.longitude,
            startTime: pe.event.startTime.toISOString(),
            endTime: pe.event.endTime?.toISOString() ?? null,
            createdAt: pe.event.createdAt.toISOString(),
            interestedCount: pe.event.interestedCount,
            distance: null,
            media: pe.event.media.map((m) => ({
              id: m.id,
              url: m.url,
              type: m.type,
              order: m.order,
              thumbnailUrl: m.thumbnailUrl ?? null,
            })),
            user: { id: pe.event.user.id, name: pe.event.user.name },
          })),
        },
      });
    }
  )
);

/**
 * PATCH /plans/:id - Update plan details
 * PRD Section 7.3: Viewing & Managing Plans
 */
router.patch(
  '/:id',
  requireAuth,
  validateRequest({ params: planIdSchema, body: updatePlanSchema }),
  asyncHandler(
    async (req: UpdatePlanReq, res: Response<PlanResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const planId = req.params['id'];
      const input = req.body;

      // Verify ownership
      const plan = await prisma.plan.findUnique({
        where: { id: planId },
        select: { id: true, userId: true },
      });

      if (!plan) {
        throw ApiError.notFound('Plan');
      }

      if (plan.userId !== currentUserId) {
        throw ApiError.forbidden('You can only update your own plans');
      }

      const updatedPlan = await prisma.plan.update({
        where: { id: planId },
        data: {
          ...(input.name !== undefined && { name: input.name }),
          ...(input.description !== undefined && {
            description: input.description ?? null,
          }),
        },
        include: {
          _count: {
            select: { planEvents: true },
          },
        },
      });

      logger.info(
        {
          requestId,
          planId: updatedPlan.id,
        },
        '✅ Plan updated successfully'
      );

      res.json({
        data: {
          id: updatedPlan.id,
          userId: updatedPlan.userId,
          name: updatedPlan.name,
          description: updatedPlan.description,
          isArchived: updatedPlan.isArchived,
          createdAt: updatedPlan.createdAt.toISOString(),
          updatedAt: updatedPlan.updatedAt.toISOString(),
          eventCount: updatedPlan._count.planEvents,
        },
      });
    }
  )
);

/**
 * DELETE /plans/:id - Delete a plan
 * PRD Section 7.3: Viewing & Managing Plans
 * - Cascade deletes PlanEvent relationships
 */
router.delete(
  '/:id',
  requireAuth,
  validateRequest({ params: planIdSchema }),
  asyncHandler(
    async (
      req: DeletePlanReq,
      res: Response<{ data: { message: string } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const planId = req.params['id'];

      // Verify ownership
      const plan = await prisma.plan.findUnique({
        where: { id: planId },
        select: { id: true, userId: true },
      });

      if (!plan) {
        throw ApiError.notFound('Plan');
      }

      if (plan.userId !== currentUserId) {
        throw ApiError.forbidden('You can only delete your own plans');
      }

      // Delete plan (cascade deletes PlanEvent relationships)
      await prisma.plan.delete({
        where: { id: planId },
      });

      logger.info(
        {
          requestId,
          planId,
        },
        '✅ Plan deleted successfully'
      );

      res.json({ data: { message: 'Plan deleted successfully' } });
    }
  )
);

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

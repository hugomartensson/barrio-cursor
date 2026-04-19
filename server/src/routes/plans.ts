import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import {
  createPlanSchema,
  updatePlanSchema,
  planIdSchema,
  addPlanItemsSchema,
  planItemIdSchema,
  updatePlanItemSchema,
} from '../schemas/plans.js';
import type {
  CreatePlanInput,
  UpdatePlanInput,
  AddPlanItemsInput,
  UpdatePlanItemInput,
} from '../schemas/plans.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';
import { formatEvent } from '../utils/eventFormatters.js';
import type { EventData } from '../types/responses.js';

const router = Router();

// ---------------------------------------------------------------------------
// Response shapes
// ---------------------------------------------------------------------------

interface PlanItemSpotPayload {
  id: string;
  name: string;
  description: string | null;
  address: string;
  latitude: number;
  longitude: number;
  neighborhood: string | null;
  categoryTag: string | null;
  tags: string[];
  imageUrl: string | null;
  saveCount: number;
  distance: number;
  ownerId: string;
  ownerHandle: string | null;
}

export interface PlanItemEntry {
  id: string;
  itemType: 'spot' | 'event';
  dayOffset: number;
  order: number;
  addedAt: string;
  spot?: PlanItemSpotPayload;
  event?: EventData;
}

export interface PlanData {
  id: string;
  userId: string;
  name: string;
  startDate: string;
  endDate: string;
  itemCount: number;
  previewImageURLs: string[];
  createdAt: string;
  updatedAt: string;
}

export interface PlanDetailData extends PlanData {
  items: PlanItemEntry[];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Collect up to 4 thumbnail URLs for a plan's items (for the card strip). */
async function fetchPlanPreviewImages(planId: string): Promise<string[]> {
  const items = await prisma.planItem.findMany({
    where: { planId },
    orderBy: { createdAt: 'asc' },
    take: 4,
  });

  const spotIds = items.filter((i) => i.itemType === 'spot').map((i) => i.itemId);
  const eventIds = items.filter((i) => i.itemType === 'event').map((i) => i.itemId);

  const [spots, events] = await Promise.all([
    spotIds.length > 0
      ? prisma.spot.findMany({
          where: { id: { in: spotIds } },
          include: { media: { orderBy: { order: 'asc' }, take: 1 } },
        })
      : [],
    eventIds.length > 0
      ? prisma.event.findMany({
          where: { id: { in: eventIds } },
          include: { media: { orderBy: { order: 'asc' }, take: 1 } },
        })
      : [],
  ]);

  const spotImageMap = new Map(spots.map((s) => [s.id, s.media[0]?.url ?? null]));
  const eventImageMap = new Map(events.map((e) => [e.id, e.media[0]?.url ?? null]));

  return items
    .map((i) => {
      const url =
        i.itemType === 'spot' ? spotImageMap.get(i.itemId) : eventImageMap.get(i.itemId);
      return url ?? null;
    })
    .filter((u): u is string => u !== null)
    .slice(0, 4);
}

function formatPlan(
  plan: {
    id: string;
    userId: string;
    name: string;
    startDate: Date;
    endDate: Date;
    createdAt: Date;
    updatedAt: Date;
    _count: { items: number };
  },
  previewImageURLs: string[] = []
): PlanData {
  return {
    id: plan.id,
    userId: plan.userId,
    name: plan.name,
    startDate: plan.startDate.toISOString().slice(0, 10),
    endDate: plan.endDate.toISOString().slice(0, 10),
    itemCount: plan._count.items,
    previewImageURLs,
    createdAt: plan.createdAt.toISOString(),
    updatedAt: plan.updatedAt.toISOString(),
  };
}

async function hydrateItems(
  planItems: {
    id: string;
    itemType: string;
    itemId: string;
    dayOffset: number;
    order: number;
    createdAt: Date;
  }[]
): Promise<PlanItemEntry[]> {
  const spotIds = planItems.filter((i) => i.itemType === 'spot').map((i) => i.itemId);
  const eventIds = planItems.filter((i) => i.itemType === 'event').map((i) => i.itemId);

  const [spots, events] = await Promise.all([
    spotIds.length > 0
      ? prisma.spot.findMany({
          where: { id: { in: spotIds } },
          include: {
            media: { orderBy: { order: 'asc' }, take: 1 },
            owner: { select: { id: true, handle: true } },
          },
        })
      : [],
    eventIds.length > 0
      ? prisma.event.findMany({
          where: { id: { in: eventIds } },
          include: {
            media: { orderBy: { order: 'asc' } },
            user: { select: { id: true, name: true } },
          },
        })
      : [],
  ]);

  const spotMap = new Map(spots.map((s) => [s.id, s]));
  const eventMap = new Map(events.map((e) => [e.id, e]));

  return planItems.map((pi) => {
    const addedAt = pi.createdAt.toISOString();
    if (pi.itemType === 'spot') {
      const spot = spotMap.get(pi.itemId);
      const spotPayload: PlanItemSpotPayload | undefined = spot
        ? {
            id: spot.id,
            name: spot.name,
            description: spot.description,
            address: spot.address,
            latitude: spot.latitude,
            longitude: spot.longitude,
            neighborhood: spot.neighborhood,
            categoryTag: spot.categoryTag,
            tags: spot.tags,
            imageUrl: spot.media[0]?.url ?? null,
            saveCount: spot.saveCount,
            distance: 0,
            ownerId: spot.ownerId,
            ownerHandle: spot.owner.handle ?? null,
          }
        : undefined;
      return {
        id: pi.id,
        itemType: 'spot' as const,
        dayOffset: pi.dayOffset,
        order: pi.order,
        addedAt,
        spot: spotPayload,
      };
    } else {
      const event = eventMap.get(pi.itemId);
      const eventPayload: EventData | undefined = event
        ? formatEvent({
            ...event,
            startTime: event.startTime,
            endTime: event.endTime,
            media: event.media.map((m) => ({
              id: m.id,
              url: m.url,
              type: m.type,
              order: m.order,
              thumbnailUrl: m.thumbnailUrl,
            })),
            user: event.user,
          })
        : undefined;
      return {
        id: pi.id,
        itemType: 'event' as const,
        dayOffset: pi.dayOffset,
        order: pi.order,
        addedAt,
        event: eventPayload,
      };
    }
  });
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

/**
 * GET /plans — list current user's plans
 */
router.get(
  '/',
  requireAuth,
  asyncHandler(
    async (req: Request, res: Response<{ data: PlanData[] } | ApiErrorResponse>) => {
      const userId = (req as unknown as AuthenticatedRequest).user.userId;

      const plans = await prisma.plan.findMany({
        where: { userId },
        orderBy: { startDate: 'asc' },
        include: { _count: { select: { items: true } } },
      });

      const planIds = plans.map((p) => p.id);
      const imageMaps = await Promise.all(
        planIds.map((id) => fetchPlanPreviewImages(id))
      );

      const data: PlanData[] = plans.map((p, i) => formatPlan(p, imageMaps[i]));
      res.json({ data });
    }
  )
);

/**
 * POST /plans — create a plan, optionally pre-populating items
 */
router.post(
  '/',
  requireAuth,
  validateRequest({ body: createPlanSchema }),
  asyncHandler(
    async (
      req: Request<object, { data: PlanDetailData } | ApiErrorResponse, CreatePlanInput>,
      res: Response<{ data: PlanDetailData } | ApiErrorResponse>
    ) => {
      const userId = (req as unknown as AuthenticatedRequest).user.userId;
      const { name, startDate, endDate, initialItems } = req.body;

      const plan = await prisma.plan.create({
        data: {
          userId,
          name,
          startDate: new Date(startDate),
          endDate: new Date(endDate),
          items: initialItems
            ? {
                createMany: {
                  data: initialItems.map((item, idx) => ({
                    itemType: item.itemType,
                    itemId: item.itemId,
                    dayOffset: item.dayOffset ?? 0,
                    order: idx,
                  })),
                },
              }
            : undefined,
        },
        include: {
          items: { orderBy: [{ dayOffset: 'asc' }, { order: 'asc' }] },
          _count: { select: { items: true } },
        },
      });

      const hydratedItems = await hydrateItems(plan.items);
      const data: PlanDetailData = {
        ...formatPlan(plan),
        items: hydratedItems,
      };

      res.status(201).json({ data });
    }
  )
);

/**
 * GET /plans/:id — plan detail with hydrated items
 */
router.get(
  '/:id',
  requireAuth,
  validateRequest({ params: planIdSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }>,
      res: Response<{ data: PlanDetailData } | ApiErrorResponse>
    ) => {
      const userId = (req as unknown as AuthenticatedRequest).user.userId;
      const plan = await prisma.plan.findUnique({
        where: { id: req.params.id },
        include: {
          items: { orderBy: [{ dayOffset: 'asc' }, { order: 'asc' }] },
          _count: { select: { items: true } },
        },
      });

      if (!plan) {
        throw ApiError.notFound('Plan');
      }
      if (plan.userId !== userId) {
        throw ApiError.forbidden('You cannot view this plan');
      }

      const hydratedItems = await hydrateItems(plan.items);
      res.json({ data: { ...formatPlan(plan), items: hydratedItems } });
    }
  )
);

/**
 * PATCH /plans/:id — update name / dates
 */
router.patch(
  '/:id',
  requireAuth,
  validateRequest({ params: planIdSchema, body: updatePlanSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }, unknown, UpdatePlanInput>,
      res: Response<{ data: PlanData } | ApiErrorResponse>
    ) => {
      const userId = (req as unknown as AuthenticatedRequest).user.userId;
      const plan = await prisma.plan.findUnique({ where: { id: req.params.id } });
      if (!plan) {
        throw ApiError.notFound('Plan');
      }
      if (plan.userId !== userId) {
        throw ApiError.forbidden('You cannot edit this plan');
      }

      const { name, startDate, endDate } = req.body;
      const updated = await prisma.plan.update({
        where: { id: req.params.id },
        data: {
          ...(name !== undefined && { name }),
          ...(startDate !== undefined && { startDate: new Date(startDate) }),
          ...(endDate !== undefined && { endDate: new Date(endDate) }),
        },
        include: { _count: { select: { items: true } } },
      });

      const images = await fetchPlanPreviewImages(updated.id);
      res.json({ data: formatPlan(updated, images) });
    }
  )
);

/**
 * DELETE /plans/:id
 */
router.delete(
  '/:id',
  requireAuth,
  validateRequest({ params: planIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const userId = (req as unknown as AuthenticatedRequest).user.userId;
    const plan = await prisma.plan.findUnique({ where: { id: req.params.id } });
    if (!plan) {
      throw ApiError.notFound('Plan');
    }
    if (plan.userId !== userId) {
      throw ApiError.forbidden('You cannot delete this plan');
    }
    await prisma.plan.delete({ where: { id: req.params.id } });
    res.json({ data: { message: 'Plan deleted' } });
  })
);

/**
 * POST /plans/:id/items — add one or many items to a plan
 */
router.post(
  '/:id/items',
  requireAuth,
  validateRequest({ params: planIdSchema, body: addPlanItemsSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }, unknown, AddPlanItemsInput>,
      res: Response<{ data: PlanItemEntry[] } | ApiErrorResponse>
    ) => {
      const userId = (req as unknown as AuthenticatedRequest).user.userId;
      const plan = await prisma.plan.findUnique({
        where: { id: req.params.id },
        include: { _count: { select: { items: true } } },
      });
      if (!plan) {
        throw ApiError.notFound('Plan');
      }
      if (plan.userId !== userId) {
        throw ApiError.forbidden('You cannot edit this plan');
      }

      const currentCount = plan._count.items;
      const created = await prisma.$transaction(
        req.body.items.map((item, idx) =>
          prisma.planItem.create({
            data: {
              planId: req.params.id,
              itemType: item.itemType,
              itemId: item.itemId,
              dayOffset: item.dayOffset ?? 0,
              order: currentCount + idx,
            },
          })
        )
      );

      const hydratedItems = await hydrateItems(created);
      res.status(201).json({ data: hydratedItems });
    }
  )
);

/**
 * PATCH /plans/:id/items/:itemId — move a plan item to a different day
 */
router.patch(
  '/:id/items/:itemId',
  requireAuth,
  validateRequest({ params: planItemIdSchema, body: updatePlanItemSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string; itemId: string }, unknown, UpdatePlanItemInput>,
      res: Response
    ) => {
      const userId = (req as unknown as AuthenticatedRequest).user.userId;
      const plan = await prisma.plan.findUnique({ where: { id: req.params.id } });
      if (!plan) {
        throw ApiError.notFound('Plan');
      }
      if (plan.userId !== userId) {
        throw ApiError.forbidden('You cannot edit this plan');
      }

      const item = await prisma.planItem.findUnique({ where: { id: req.params.itemId } });
      if (!item || item.planId !== req.params.id) {
        throw ApiError.notFound('Plan item');
      }

      // Clamp dayOffset to valid range for this plan
      const start = new Date(plan.startDate);
      const end = new Date(plan.endDate);
      const maxDayOffset = Math.round((end.getTime() - start.getTime()) / 86400000);
      const clampedOffset = Math.max(0, Math.min(req.body.dayOffset, maxDayOffset));

      const updated = await prisma.planItem.update({
        where: { id: req.params.itemId },
        data: { dayOffset: clampedOffset },
      });

      res.json({ data: updated });
    }
  )
);

/**
 * DELETE /plans/:id/items/:itemId — remove a single plan item
 */
router.delete(
  '/:id/items/:itemId',
  requireAuth,
  validateRequest({ params: planItemIdSchema }),
  asyncHandler(async (req: Request<{ id: string; itemId: string }>, res: Response) => {
    const userId = (req as unknown as AuthenticatedRequest).user.userId;
    const plan = await prisma.plan.findUnique({ where: { id: req.params.id } });
    if (!plan) {
      throw ApiError.notFound('Plan');
    }
    if (plan.userId !== userId) {
      throw ApiError.forbidden('You cannot edit this plan');
    }

    const item = await prisma.planItem.findUnique({ where: { id: req.params.itemId } });
    if (!item || item.planId !== req.params.id) {
      throw ApiError.notFound('Plan item');
    }

    await prisma.planItem.delete({ where: { id: req.params.itemId } });
    res.json({ data: { message: 'Item removed' } });
  })
);

export default router;

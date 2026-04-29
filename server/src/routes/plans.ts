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
  inviteMembersSchema,
} from '../schemas/plans.js';
import type {
  CreatePlanInput,
  UpdatePlanInput,
  AddPlanItemsInput,
  UpdatePlanItemInput,
  InviteMembersInput,
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
  category: string;
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

export interface PlanMemberPayload {
  id: string;
  userId: string;
  name: string;
  profilePictureUrl: string | null;
  status: string;
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
  role: 'owner' | 'member';
  members: PlanMemberPayload[];
  memberStatus?: string;
  itemIds: string[];
  /** Owner's display name (creator of the plan). Used to render the creator in the Friends section. */
  ownerName?: string;
  /** Owner's profile picture URL. */
  ownerProfilePictureUrl?: string | null;
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
    user?: { name: string; profilePictureUrl: string | null } | null;
    members?: Array<{
      id: string;
      userId: string;
      status: string;
      user: { name: string; profilePictureUrl: string | null };
    }>;
    items?: Array<{ itemId: string }>;
  },
  previewImageURLs: string[] = [],
  currentUserId?: string,
  memberStatus?: string
): PlanData {
  const members: PlanMemberPayload[] = (plan.members ?? []).map((m) => ({
    id: m.id,
    userId: m.userId,
    name: m.user.name,
    profilePictureUrl: m.user.profilePictureUrl,
    status: m.status,
  }));

  const itemIds: string[] = (plan.items ?? []).map((i) => i.itemId);

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
    role: currentUserId && plan.userId !== currentUserId ? 'member' : 'owner',
    members,
    ...(memberStatus !== undefined && { memberStatus }),
    itemIds,
    ...(plan.user && {
      ownerName: plan.user.name,
      ownerProfilePictureUrl: plan.user.profilePictureUrl,
    }),
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
            category: String(spot.category),
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

/** Check if current user is allowed to view/edit a plan (owner or accepted member). */
async function assertPlanAccess(
  planId: string,
  userId: string,
  ownerOnly = false
): Promise<{ id: string; userId: string; startDate: Date; endDate: Date; name: string }> {
  const plan = await prisma.plan.findUnique({ where: { id: planId } });
  if (!plan) {
    throw ApiError.notFound('Plan');
  }

  if (plan.userId === userId) {
    return plan;
  }
  if (ownerOnly) {
    throw ApiError.forbidden('Only the plan owner can perform this action');
  }

  const membership = await prisma.planMember.findUnique({
    where: { planId_userId: { planId, userId } },
  });
  if (!membership || membership.status !== 'accepted') {
    throw ApiError.forbidden('You do not have access to this plan');
  }
  return plan;
}

/** Compute valid dayOffsets for an event within a plan's date range. Returns null if event has no date constraint. */
function validEventDayOffsets(
  eventStartTime: Date,
  eventEndTime: Date | null,
  planStartDate: Date,
  planEndDate: Date
): number[] | null {
  const eventStart = new Date(eventStartTime);
  eventStart.setHours(0, 0, 0, 0);
  const eventEnd = eventEndTime ? new Date(eventEndTime) : new Date(eventStartTime);
  eventEnd.setHours(23, 59, 59, 999);

  const planStart = new Date(planStartDate);
  planStart.setHours(0, 0, 0, 0);
  const planEnd = new Date(planEndDate);
  planEnd.setHours(23, 59, 59, 999);

  const validOffsets: number[] = [];
  const msPerDay = 86400000;
  const totalDays = Math.round((planEnd.getTime() - planStart.getTime()) / msPerDay) + 1;

  for (let i = 0; i < totalDays; i++) {
    const dayStart = new Date(planStart.getTime() + i * msPerDay);
    const dayEnd = new Date(dayStart.getTime() + msPerDay - 1);
    // Day overlaps with event if event starts before day ends and event ends after day starts
    if (eventStart <= dayEnd && eventEnd >= dayStart) {
      validOffsets.push(i);
    }
  }
  return validOffsets;
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

/**
 * GET /plans/invitations/count — count of pending invitations for current user
 * Must be defined before /:id to avoid route conflict
 */
router.get(
  '/invitations/count',
  requireAuth,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = (req as unknown as AuthenticatedRequest).user.userId;
    const count = await prisma.planMember.count({
      where: { userId, status: 'invited' },
    });
    res.json({ data: { count } });
  })
);

/**
 * GET /plans — list current user's plans (owned + accepted memberships) plus pending invitations
 */
router.get(
  '/',
  requireAuth,
  asyncHandler(
    async (req: Request, res: Response<{ data: PlanData[] } | ApiErrorResponse>) => {
      const userId = (req as unknown as AuthenticatedRequest).user.userId;

      const planInclude = {
        _count: { select: { items: true } },
        members: {
          include: { user: { select: { name: true, profilePictureUrl: true } } },
        },
        items: { select: { itemId: true } },
      } as const;

      // Owned plans
      const ownedPlans = await prisma.plan.findMany({
        where: { userId },
        orderBy: { startDate: 'asc' },
        include: planInclude,
      });

      // Plans the user is a member of (all statuses so invitations show up)
      const memberships = await prisma.planMember.findMany({
        where: { userId },
        include: {
          plan: { include: planInclude },
        },
      });

      const ownedIds = new Set(ownedPlans.map((p) => p.id));
      const memberPlans = memberships
        .filter((m) => !ownedIds.has(m.plan.id))
        .map((m) => ({ plan: m.plan, memberStatus: m.status }));

      const allPlans = [
        ...ownedPlans.map((p) => ({
          plan: p,
          memberStatus: undefined as string | undefined,
        })),
        ...memberPlans,
      ];

      const planIds = allPlans.map((p) => p.plan.id);
      const imageMaps = await Promise.all(
        planIds.map((id) => fetchPlanPreviewImages(id))
      );

      const data: PlanData[] = allPlans.map((entry, i) =>
        formatPlan(entry.plan, imageMaps[i], userId, entry.memberStatus)
      );

      // Sort: invited first, then by startDate
      data.sort((a, b) => {
        const aInvited = a.memberStatus === 'invited' ? 0 : 1;
        const bInvited = b.memberStatus === 'invited' ? 0 : 1;
        if (aInvited !== bInvited) {
          return aInvited - bInvited;
        }
        return a.startDate.localeCompare(b.startDate);
      });

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
                    dayOffset: item.dayOffset ?? -1,
                    order: idx,
                  })),
                },
              }
            : undefined,
        },
        include: {
          items: { orderBy: [{ dayOffset: 'asc' }, { order: 'asc' }] },
          _count: { select: { items: true } },
          members: {
            include: { user: { select: { name: true, profilePictureUrl: true } } },
          },
        },
      });

      const hydratedItems = await hydrateItems(plan.items);
      const data: PlanDetailData = {
        ...formatPlan({ ...plan, items: plan.items }, undefined, userId),
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
      const plan = await assertPlanAccess(req.params.id, userId);

      const fullPlan = await prisma.plan.findUnique({
        where: { id: plan.id },
        include: {
          user: { select: { name: true, profilePictureUrl: true } },
          items: { orderBy: [{ dayOffset: 'asc' }, { order: 'asc' }] },
          _count: { select: { items: true } },
          members: {
            include: { user: { select: { name: true, profilePictureUrl: true } } },
          },
        },
      });

      if (!fullPlan) {
        throw ApiError.notFound('Plan');
      }

      const hydratedItems = await hydrateItems(fullPlan.items);
      const memberStatus =
        fullPlan.userId !== userId
          ? (
              await prisma.planMember.findUnique({
                where: { planId_userId: { planId: plan.id, userId } },
              })
            )?.status
          : undefined;

      res.json({
        data: {
          ...formatPlan(
            { ...fullPlan, items: fullPlan.items },
            undefined,
            userId,
            memberStatus
          ),
          items: hydratedItems,
        },
      });
    }
  )
);

/**
 * PATCH /plans/:id — update name / dates (owner only)
 */
router.patch(
  '/:id',
  requireAuth,
  validateRequest({ params: planIdSchema, body: updatePlanSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }, unknown, UpdatePlanInput>,
      res: Response<{ data: PlanData; displacedCount?: number } | ApiErrorResponse>
    ) => {
      const userId = (req as unknown as AuthenticatedRequest).user.userId;
      await assertPlanAccess(req.params.id, userId, true);

      const { name, startDate, endDate } = req.body;
      const updated = await prisma.plan.update({
        where: { id: req.params.id },
        data: {
          ...(name !== undefined && { name }),
          ...(startDate !== undefined && { startDate: new Date(startDate) }),
          ...(endDate !== undefined && { endDate: new Date(endDate) }),
        },
        include: {
          _count: { select: { items: true } },
          members: {
            include: { user: { select: { name: true, profilePictureUrl: true } } },
          },
          items: { select: { itemId: true } },
        },
      });

      // Orphan handling: move items outside new date range to "To be scheduled"
      let displacedCount = 0;
      const newStart = new Date(updated.startDate);
      const newEnd = new Date(updated.endDate);
      const newMaxOffset = Math.round((newEnd.getTime() - newStart.getTime()) / 86400000);

      const allItems = await prisma.planItem.findMany({
        where: { planId: updated.id, dayOffset: { gte: 0 } },
        include: { plan: false },
      });

      for (const item of allItems) {
        let shouldDisplace = item.dayOffset > newMaxOffset;

        // For events, also check date overlap
        if (!shouldDisplace && item.itemType === 'event') {
          const event = await prisma.event.findUnique({ where: { id: item.itemId } });
          if (event) {
            const validOffsets = validEventDayOffsets(
              event.startTime,
              event.endTime,
              newStart,
              newEnd
            );
            if (
              validOffsets !== null &&
              validOffsets.length > 0 &&
              !validOffsets.includes(item.dayOffset)
            ) {
              shouldDisplace = true;
            }
          }
        }

        if (shouldDisplace) {
          await prisma.planItem.update({
            where: { id: item.id },
            data: { dayOffset: -1 },
          });
          displacedCount++;
        }
      }

      const images = await fetchPlanPreviewImages(updated.id);
      res.json({ data: formatPlan(updated, images, userId), displacedCount });
    }
  )
);

/**
 * DELETE /plans/:id (owner only)
 */
router.delete(
  '/:id',
  requireAuth,
  validateRequest({ params: planIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const userId = (req as unknown as AuthenticatedRequest).user.userId;
    await assertPlanAccess(req.params.id, userId, true);
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
      const plan = await assertPlanAccess(req.params.id, userId);

      // Duplicate check
      const existingItems = await prisma.planItem.findMany({
        where: { planId: req.params.id },
        select: { itemType: true, itemId: true },
      });
      const existingSet = new Set(existingItems.map((i) => `${i.itemType}:${i.itemId}`));
      const duplicates = req.body.items.filter((item) =>
        existingSet.has(`${item.itemType}:${item.itemId}`)
      );
      if (duplicates.length > 0) {
        res.status(409).json({
          error: 'Duplicate items',
          details: duplicates.map((d) => d.itemId),
        } as unknown as ApiErrorResponse);
        return;
      }

      // Event date validation
      for (const item of req.body.items) {
        if (item.itemType === 'event' && item.dayOffset !== -1) {
          const event = await prisma.event.findUnique({ where: { id: item.itemId } });
          if (event) {
            const validOffsets = validEventDayOffsets(
              event.startTime,
              event.endTime,
              plan.startDate,
              plan.endDate
            );
            if (
              validOffsets !== null &&
              validOffsets.length > 0 &&
              !validOffsets.includes(item.dayOffset)
            ) {
              const startStr = event.startTime.toLocaleDateString('en-US', {
                month: 'short',
                day: 'numeric',
              });
              const endStr = event.endTime
                ? event.endTime.toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                  })
                : null;
              const dateLabel =
                endStr && endStr !== startStr ? `${startStr}–${endStr}` : startStr;
              throw ApiError.badRequest(
                `Event runs on ${dateLabel}; dayOffset ${item.dayOffset} is outside its range`
              );
            }
          }
        }
      }

      const currentCount = await prisma.planItem.count({
        where: { planId: req.params.id },
      });
      const created = await prisma.$transaction(
        req.body.items.map((item, idx) =>
          prisma.planItem.create({
            data: {
              planId: req.params.id,
              itemType: item.itemType,
              itemId: item.itemId,
              dayOffset: item.dayOffset ?? -1,
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
      const plan = await assertPlanAccess(req.params.id, userId);

      const item = await prisma.planItem.findUnique({ where: { id: req.params.itemId } });
      if (!item || item.planId !== req.params.id) {
        throw ApiError.notFound('Plan item');
      }

      const newDayOffset = req.body.dayOffset;

      if (newDayOffset === -1) {
        // Moving to "To be scheduled" — always allowed
        const updated = await prisma.planItem.update({
          where: { id: req.params.itemId },
          data: { dayOffset: -1 },
        });
        res.json({ data: updated });
        return;
      }

      // Clamp to valid plan range
      const maxDayOffset = Math.round(
        (plan.endDate.getTime() - plan.startDate.getTime()) / 86400000
      );
      const clampedOffset = Math.max(0, Math.min(newDayOffset, maxDayOffset));

      // Event date validation
      if (item.itemType === 'event') {
        const event = await prisma.event.findUnique({ where: { id: item.itemId } });
        if (event) {
          const validOffsets = validEventDayOffsets(
            event.startTime,
            event.endTime,
            plan.startDate,
            plan.endDate
          );
          if (
            validOffsets !== null &&
            validOffsets.length > 0 &&
            !validOffsets.includes(clampedOffset)
          ) {
            const startStr = event.startTime.toLocaleDateString('en-US', {
              month: 'short',
              day: 'numeric',
            });
            const endStr = event.endTime
              ? event.endTime.toLocaleDateString('en-US', {
                  month: 'short',
                  day: 'numeric',
                })
              : null;
            const dateLabel =
              endStr && endStr !== startStr ? `${startStr}–${endStr}` : startStr;
            throw ApiError.badRequest(`This event is on ${dateLabel} only`);
          }
        }
      }

      const updated = await prisma.planItem.update({
        where: { id: req.params.itemId },
        data: { dayOffset: clampedOffset },
      });

      res.json({
        data: {
          id: updated.id,
          itemType: updated.itemType,
          itemId: updated.itemId,
          dayOffset: updated.dayOffset,
          order: updated.order,
          addedAt: updated.createdAt.toISOString(),
        },
      });
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
    await assertPlanAccess(req.params.id, userId);

    const item = await prisma.planItem.findUnique({ where: { id: req.params.itemId } });
    if (!item || item.planId !== req.params.id) {
      throw ApiError.notFound('Plan item');
    }

    await prisma.planItem.delete({ where: { id: req.params.itemId } });
    res.json({ data: { message: 'Item removed' } });
  })
);

// ---------------------------------------------------------------------------
// Collaborative Plan Endpoints
// ---------------------------------------------------------------------------

/**
 * GET /plans/:id/members — list plan members
 */
router.get(
  '/:id/members',
  requireAuth,
  validateRequest({ params: planIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const userId = (req as unknown as AuthenticatedRequest).user.userId;
    await assertPlanAccess(req.params.id, userId);

    const members = await prisma.planMember.findMany({
      where: { planId: req.params.id },
      include: { user: { select: { id: true, name: true, profilePictureUrl: true } } },
      orderBy: { createdAt: 'asc' },
    });

    res.json({
      data: members.map((m) => ({
        id: m.id,
        userId: m.userId,
        name: m.user.name,
        profilePictureUrl: m.user.profilePictureUrl,
        status: m.status,
      })),
    });
  })
);

/**
 * POST /plans/:id/members — invite users (owner only)
 */
router.post(
  '/:id/members',
  requireAuth,
  validateRequest({ params: planIdSchema, body: inviteMembersSchema }),
  asyncHandler(
    async (req: Request<{ id: string }, unknown, InviteMembersInput>, res: Response) => {
      const userId = (req as unknown as AuthenticatedRequest).user.userId;
      const plan = await assertPlanAccess(req.params.id, userId, true);

      const { userIds } = req.body;
      // Filter out the owner themselves and already-existing members
      const existing = await prisma.planMember.findMany({
        where: { planId: plan.id },
        select: { userId: true },
      });
      const existingUserIds = new Set([plan.userId, ...existing.map((m) => m.userId)]);
      const toInvite = userIds.filter((id) => !existingUserIds.has(id));

      if (toInvite.length > 0) {
        await prisma.planMember.createMany({
          data: toInvite.map((uid) => ({
            planId: plan.id,
            userId: uid,
            status: 'invited',
          })),
          skipDuplicates: true,
        });
      }

      res.json({ data: { invited: toInvite.length } });
    }
  )
);

/**
 * POST /plans/:id/members/accept — accept an invitation
 */
router.post(
  '/:id/members/accept',
  requireAuth,
  validateRequest({ params: planIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const userId = (req as unknown as AuthenticatedRequest).user.userId;
    const membership = await prisma.planMember.findUnique({
      where: { planId_userId: { planId: req.params.id, userId } },
    });
    if (!membership) {
      throw ApiError.notFound('Invitation');
    }

    await prisma.planMember.update({
      where: { planId_userId: { planId: req.params.id, userId } },
      data: { status: 'accepted' },
    });

    res.json({ data: { status: 'accepted' } });
  })
);

/**
 * POST /plans/:id/members/decline — decline an invitation
 */
router.post(
  '/:id/members/decline',
  requireAuth,
  validateRequest({ params: planIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const userId = (req as unknown as AuthenticatedRequest).user.userId;
    const membership = await prisma.planMember.findUnique({
      where: { planId_userId: { planId: req.params.id, userId } },
    });
    if (!membership) {
      throw ApiError.notFound('Invitation');
    }

    await prisma.planMember.delete({
      where: { planId_userId: { planId: req.params.id, userId } },
    });

    res.json({ data: { status: 'declined' } });
  })
);

/**
 * DELETE /plans/:id/members/me — leave a plan (non-owner member)
 */
router.delete(
  '/:id/members/me',
  requireAuth,
  validateRequest({ params: planIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const userId = (req as unknown as AuthenticatedRequest).user.userId;
    const plan = await prisma.plan.findUnique({ where: { id: req.params.id } });
    if (!plan) {
      throw ApiError.notFound('Plan');
    }
    if (plan.userId === userId) {
      throw ApiError.badRequest('Plan owner cannot leave their own plan');
    }

    await prisma.planMember.delete({
      where: { planId_userId: { planId: req.params.id, userId } },
    });

    res.json({ data: { message: 'Left plan' } });
  })
);

export default router;

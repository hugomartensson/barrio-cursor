import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { z } from 'zod';
import {
  createCollectionSchema,
  updateCollectionSchema,
  collectionIdSchema,
  saveToCollectionSchema,
} from '../schemas/collections.js';
import type {
  CreateCollectionInput,
  UpdateCollectionInput,
  SaveToCollectionInput,
} from '../schemas/collections.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';
import { canViewCollection, canSaveCollection } from '../services/collectionService.js';

const router = Router();

const RECOMMENDED_LIMIT = 20;

interface CollectionData {
  id: string;
  userId: string;
  name: string;
  description: string | null;
  visibility: string;
  itemCount: number;
  createdAt: string;
  updatedAt: string;
  owned: boolean;
  ownerHandle?: string | null;
  ownerInitials?: string | null;
}

/**
 * POST /collections - Create a collection
 */
router.post(
  '/',
  requireAuth,
  validateRequest({ body: createCollectionSchema }),
  asyncHandler(
    async (
      req: Request<
        object,
        { data: CollectionData } | ApiErrorResponse,
        CreateCollectionInput
      >,
      res: Response<{ data: CollectionData } | ApiErrorResponse>
    ) => {
      const authReq = req as AuthenticatedRequest;
      const userId = authReq.user.userId;
      const input = req.body;

      const collection = await prisma.collection.create({
        data: {
          userId,
          name: input.name,
          description: input.description ?? null,
          visibility: (input.visibility as 'private' | 'friends' | 'public') ?? 'private',
        },
      });

      const count = await prisma.save.count({ where: { collectionId: collection.id } });
      res.status(201).json({
        data: {
          id: collection.id,
          userId: collection.userId,
          name: collection.name,
          description: collection.description,
          visibility: collection.visibility,
          itemCount: count,
          createdAt: collection.createdAt.toISOString(),
          updatedAt: collection.updatedAt.toISOString(),
          owned: true,
        },
      });
    }
  )
);

/**
 * GET /collections - List current user's collections (owned + saved from others)
 */
router.get(
  '/',
  requireAuth,
  asyncHandler(
    async (
      req: Request,
      res: Response<{ data: CollectionData[] } | ApiErrorResponse>
    ) => {
      const authReq = req as AuthenticatedRequest;
      const userId = authReq.user.userId;

      const [owned, savedLinks] = await Promise.all([
        prisma.collection.findMany({
          where: { userId },
          orderBy: { updatedAt: 'desc' },
        }),
        prisma.savedCollection.findMany({
          where: { userId },
          include: {
            collection: {
              include: {
                user: { select: { id: true, handle: true, initials: true } },
              },
            },
          },
          orderBy: { createdAt: 'desc' },
        }),
      ]);

      const ownedCounts = await Promise.all(
        owned.map((c) => prisma.save.count({ where: { collectionId: c.id } }))
      );
      const savedCounts = await Promise.all(
        savedLinks.map((sc) =>
          prisma.save.count({ where: { collectionId: sc.collection.id } })
        )
      );

      const ownedData: CollectionData[] = owned.map((c, i) => ({
        id: c.id,
        userId: c.userId,
        name: c.name,
        description: c.description,
        visibility: c.visibility,
        itemCount: ownedCounts[i] ?? 0,
        createdAt: c.createdAt.toISOString(),
        updatedAt: c.updatedAt.toISOString(),
        owned: true,
      }));

      const savedData: CollectionData[] = savedLinks.map((sc, i) => ({
        id: sc.collection.id,
        userId: sc.collection.userId,
        name: sc.collection.name,
        description: sc.collection.description,
        visibility: sc.collection.visibility,
        itemCount: savedCounts[i] ?? 0,
        createdAt: sc.collection.createdAt.toISOString(),
        updatedAt: sc.collection.updatedAt.toISOString(),
        owned: false,
        ownerHandle: sc.collection.user.handle,
        ownerInitials: sc.collection.user.initials,
      }));

      const data = [...ownedData, ...savedData].sort(
        (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
      );
      res.json({ data });
    }
  )
);

/**
 * GET /collections/recommended - Public collections by most saved (for Discover)
 */
router.get(
  '/recommended',
  requireAuth,
  asyncHandler(
    async (
      req: Request,
      res: Response<{ data: CollectionData[] } | ApiErrorResponse>
    ) => {
      const collections = await prisma.collection.findMany({
        where: { visibility: 'public' },
        orderBy: { savedBy: { _count: 'desc' } },
        take: RECOMMENDED_LIMIT,
        include: {
          user: { select: { id: true, handle: true, initials: true } },
          _count: { select: { saves: true } },
        },
      });

      const data: CollectionData[] = collections.map((c) => ({
        id: c.id,
        userId: c.userId,
        name: c.name,
        description: c.description,
        visibility: c.visibility,
        itemCount: c._count.saves,
        createdAt: c.createdAt.toISOString(),
        updatedAt: c.updatedAt.toISOString(),
        owned: false,
        ownerHandle: c.user.handle,
        ownerInitials: c.user.initials,
      }));

      res.json({ data });
    }
  )
);

/**
 * GET /collections/:id - Get collection by ID (owner or allowed by visibility / saved)
 */
router.get(
  '/:id',
  requireAuth,
  validateRequest({ params: collectionIdSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }, { data: CollectionData } | ApiErrorResponse>,
      res: Response<{ data: CollectionData } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const id = req.params.id;
      const userId = authReq.user.userId;

      const collection = await prisma.collection.findUnique({
        where: { id },
        include: { user: { select: { handle: true, initials: true } } },
      });
      if (!collection) {
        throw ApiError.notFound('Collection');
      }

      const allowed = await canViewCollection(collection, userId);
      if (!allowed) {
        throw ApiError.forbidden('You cannot view this collection');
      }

      const itemCount = await prisma.save.count({ where: { collectionId: id } });
      const owned = collection.userId === userId;

      res.json({
        data: {
          id: collection.id,
          userId: collection.userId,
          name: collection.name,
          description: collection.description,
          visibility: collection.visibility,
          itemCount,
          createdAt: collection.createdAt.toISOString(),
          updatedAt: collection.updatedAt.toISOString(),
          owned,
          ...(owned
            ? {}
            : {
                ownerHandle: collection.user.handle,
                ownerInitials: collection.user.initials,
              }),
        },
      });
    }
  )
);

/**
 * PATCH /collections/:id - Update collection
 */
router.patch(
  '/:id',
  requireAuth,
  validateRequest({ params: collectionIdSchema, body: updateCollectionSchema }),
  asyncHandler(
    async (
      req: Request<
        { id: string },
        { data: CollectionData } | ApiErrorResponse,
        UpdateCollectionInput
      >,
      res: Response<{ data: CollectionData } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const id = req.params.id;
      const input = req.body;

      const collection = await prisma.collection.findUnique({ where: { id } });
      if (!collection) {
        throw ApiError.notFound('Collection');
      }
      if (collection.userId !== authReq.user.userId) {
        throw ApiError.forbidden('You can only update your own collections');
      }

      const updated = await prisma.collection.update({
        where: { id },
        data: {
          ...(input.name !== undefined && { name: input.name }),
          ...(input.description !== undefined && { description: input.description }),
          ...(input.visibility !== undefined && { visibility: input.visibility }),
        },
      });
      const itemCount = await prisma.save.count({ where: { collectionId: id } });

      res.json({
        data: {
          id: updated.id,
          userId: updated.userId,
          name: updated.name,
          description: updated.description,
          visibility: updated.visibility,
          itemCount,
          createdAt: updated.createdAt.toISOString(),
          updatedAt: updated.updatedAt.toISOString(),
          owned: true,
        },
      });
    }
  )
);

/**
 * DELETE /collections/:id - Delete collection
 */
router.delete(
  '/:id',
  requireAuth,
  validateRequest({ params: collectionIdSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }, { data: { message: string } } | ApiErrorResponse>,
      res: Response<{ data: { message: string } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const id = req.params.id;

      const collection = await prisma.collection.findUnique({ where: { id } });
      if (!collection) {
        throw ApiError.notFound('Collection');
      }
      if (collection.userId !== authReq.user.userId) {
        throw ApiError.forbidden('You can only delete your own collections');
      }

      await prisma.collection.delete({ where: { id } });
      res.json({ data: { message: 'Collection deleted' } });
    }
  )
);

/**
 * POST /collections/:id/save - Save another user's collection (link; visibility applies)
 */
router.post(
  '/:id/save',
  requireAuth,
  validateRequest({ params: collectionIdSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }, { data: { saved: boolean } } | ApiErrorResponse>,
      res: Response<{ data: { saved: boolean } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const userId = authReq.user.userId;
      const collectionId = req.params.id;

      const collection = await prisma.collection.findUnique({
        where: { id: collectionId },
      });
      if (!collection) {
        throw ApiError.notFound('Collection');
      }

      const allowed = await canSaveCollection(collection, userId);
      if (!allowed) {
        throw ApiError.forbidden('You cannot save this collection');
      }

      const existing = await prisma.savedCollection.findUnique({
        where: { userId_collectionId: { userId, collectionId } },
      });
      if (existing) {
        res.json({ data: { saved: true } });
        return;
      }

      await prisma.savedCollection.create({
        data: { userId, collectionId },
      });
      res.status(201).json({ data: { saved: true } });
    }
  )
);

/**
 * DELETE /collections/:id/save - Unsave a collection
 */
router.delete(
  '/:id/save',
  requireAuth,
  validateRequest({ params: collectionIdSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }, { data: { saved: boolean } } | ApiErrorResponse>,
      res: Response<{ data: { saved: boolean } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const userId = authReq.user.userId;
      const collectionId = req.params.id;

      const existing = await prisma.savedCollection.findUnique({
        where: { userId_collectionId: { userId, collectionId } },
      });
      if (!existing) {
        res.json({ data: { saved: false } });
        return;
      }

      await prisma.savedCollection.delete({
        where: { userId_collectionId: { userId, collectionId } },
      });
      res.json({ data: { saved: false } });
    }
  )
);

/**
 * POST /collections/:id/items - Save an item (spot or event) to a collection
 */
router.post(
  '/:id/items',
  requireAuth,
  validateRequest({ params: collectionIdSchema, body: saveToCollectionSchema }),
  asyncHandler(
    async (
      req: Request<
        { id: string },
        { data: { saved: boolean; saveCount?: number } } | ApiErrorResponse,
        SaveToCollectionInput
      >,
      res: Response<{ data: { saved: boolean; saveCount?: number } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const userId = authReq.user.userId;
      const collectionId = req.params.id;
      const { itemType, itemId } = req.body;

      const collection = await prisma.collection.findUnique({
        where: { id: collectionId },
      });
      if (!collection) {
        throw ApiError.notFound('Collection');
      }
      if (collection.userId !== userId) {
        throw ApiError.forbidden('You can only add items to your own collections');
      }

      if (itemType === 'event') {
        const event = await prisma.event.findUnique({ where: { id: itemId } });
        if (!event) {
          throw ApiError.notFound('Event');
        }
      } else {
        const spot = await prisma.spot.findUnique({ where: { id: itemId } });
        if (!spot) {
          throw ApiError.notFound('Spot');
        }
      }

      const existing = await prisma.save.findUnique({
        where: { userId_collectionId_itemId: { userId, collectionId, itemId } },
      });
      if (existing) {
        res.json({ data: { saved: true } });
        return;
      }

      await prisma.$transaction([
        prisma.save.create({
          data: { userId, collectionId, itemType, itemId },
        }),
        ...(itemType === 'event'
          ? [
              prisma.event.update({
                where: { id: itemId },
                data: { saveCount: { increment: 1 } },
              }),
            ]
          : []),
      ]);

      const saveCount =
        itemType === 'event'
          ? (
              await prisma.event.findUnique({
                where: { id: itemId },
                select: { saveCount: true },
              })
            )?.saveCount
          : undefined;
      res.status(201).json({ data: { saved: true, saveCount } });
    }
  )
);

/**
 * DELETE /collections/:id/items/:itemId - Remove an item from a collection
 */
router.delete(
  '/:id/items/:itemId',
  requireAuth,
  validateRequest({
    params: z.object({
      id: z.string().uuid(),
      itemId: z.string().uuid(),
    }),
  }),
  asyncHandler(
    async (
      req: Request<
        { id: string; itemId: string },
        { data: { saved: boolean; saveCount?: number } } | ApiErrorResponse
      >,
      res: Response<{ data: { saved: boolean; saveCount?: number } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const userId = authReq.user.userId;
      const { id: collectionId, itemId } = req.params;

      const collection = await prisma.collection.findUnique({
        where: { id: collectionId },
      });
      if (!collection) {
        throw ApiError.notFound('Collection');
      }
      if (collection.userId !== userId) {
        throw ApiError.forbidden('You can only remove items from your own collections');
      }

      const existing = await prisma.save.findUnique({
        where: { userId_collectionId_itemId: { userId, collectionId, itemId } },
      });
      if (!existing) {
        res.json({ data: { saved: false } });
        return;
      }

      const spotExists = await prisma.spot.findUnique({
        where: { id: itemId },
        select: { id: true },
      });
      const isEvent = !spotExists;

      await prisma.$transaction([
        prisma.save.delete({
          where: { userId_collectionId_itemId: { userId, collectionId, itemId } },
        }),
        ...(isEvent
          ? [
              prisma.event.update({
                where: { id: itemId },
                data: { saveCount: { decrement: 1 } },
              }),
            ]
          : []),
      ]);

      const saveCount = isEvent
        ? (
            await prisma.event.findUnique({
              where: { id: itemId },
              select: { saveCount: true },
            })
          )?.saveCount
        : undefined;
      res.json({ data: { saved: false, saveCount } });
    }
  )
);

export default router;

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
import { formatEvent } from '../utils/eventFormatters.js';
import type { EventData } from '../types/responses.js';

const router = Router();

/** Shape of a spot in collection items (matches spots route SpotData for client compatibility). */
interface CollectionItemSpotPayload {
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

export interface CollectionItemEntry {
  itemType: 'spot' | 'event';
  addedAt: string;
  spot?: CollectionItemSpotPayload;
  event?: EventData;
}

const RECOMMENDED_LIMIT = 20;
/** Default radius for Discover: match spots/events near search (5 km). */
const DEFAULT_NEAR_RADIUS_M = 5000;

/** Public collections that have at least one spot or non-expired event within `radiusMeters` of (lat, lng). */
async function fetchPublicCollectionIdsNear(
  lat: number,
  lng: number,
  radiusMeters: number
): Promise<string[]> {
  const rows = await prisma.$queryRawUnsafe<{ id: string }[]>(
    `
    SELECT DISTINCT c.id
    FROM collections c
    INNER JOIN collection_items ci ON ci.collection_id = c.id
    LEFT JOIN spots s ON ci.item_type = 'spot' AND ci.item_id = s.id
    LEFT JOIN events e ON ci.item_type = 'event' AND ci.item_id = e.id
    WHERE c.visibility = 'public'
      AND (
        (ci.item_type = 'spot' AND s.id IS NOT NULL
          AND ST_DWithin(
            ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography,
            ST_SetSRID(ST_MakePoint($2::float8, $1::float8), 4326)::geography,
            $3::float8
          )
        )
        OR
        (ci.item_type = 'event' AND e.id IS NOT NULL
          AND ST_DWithin(
            ST_SetSRID(ST_MakePoint(e.longitude, e.latitude), 4326)::geography,
            ST_SetSRID(ST_MakePoint($2::float8, $1::float8), 4326)::geography,
            $3::float8
          )
          AND ((e.end_time IS NULL AND e.start_time > NOW()) OR (e.end_time IS NOT NULL AND e.end_time > NOW()))
        )
      )
    `,
    lat,
    lng,
    radiusMeters
  );
  return rows.map((r) => r.id);
}

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
  coverImageURL?: string | null;
  previewSpotImageURLs?: string[];
  saveCount?: number;
}

/** Ordered first-media URLs per collection item (up to 3 items), for merging with DB `coverImageUrl`. */
async function fetchCollectionImageData(
  collectionIds: string[]
): Promise<Map<string, { itemImageUrls: string[] }>> {
  if (collectionIds.length === 0) {
    return new Map();
  }

  // Top 3 items per collection (most recently added first)
  const allTopItems = await Promise.all(
    collectionIds.map((id) =>
      prisma.collectionItem.findMany({
        where: { collectionId: id },
        orderBy: { createdAt: 'desc' },
        take: 3,
      })
    )
  );

  const itemsByCollection = new Map(
    collectionIds.map((id, i) => [id, allTopItems[i] ?? []])
  );
  const allItems = allTopItems.flat();

  const spotIds = [
    ...new Set(allItems.filter((i) => i.itemType === 'spot').map((i) => i.itemId)),
  ];
  const eventIds = [
    ...new Set(allItems.filter((i) => i.itemType === 'event').map((i) => i.itemId)),
  ];

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

  const spotMap = new Map(spots.map((s) => [s.id, s.media[0]?.url ?? null]));
  const eventMap = new Map(events.map((e) => [e.id, e.media[0]?.url ?? null]));

  const result = new Map<string, { itemImageUrls: string[] }>();
  for (const id of collectionIds) {
    const items = itemsByCollection.get(id) ?? [];
    const urls = items
      .map((item) =>
        item.itemType === 'spot' ? spotMap.get(item.itemId) : eventMap.get(item.itemId)
      )
      .filter((u): u is string => typeof u === 'string');
    result.set(id, { itemImageUrls: urls });
  }
  return result;
}

/** DB cover wins for main panel; item URLs go to the right strip only. Without DB cover, first item is main cover. */
function mergeCollectionCoverAndPreviews(
  dbCover: string | null | undefined,
  itemImageUrls: string[]
): { coverImageURL: string | null; previewSpotImageURLs: string[] } {
  const trimmed = dbCover?.trim();
  if (trimmed) {
    return {
      coverImageURL: trimmed,
      previewSpotImageURLs: itemImageUrls.slice(0, 2),
    };
  }
  return {
    coverImageURL: itemImageUrls[0] ?? null,
    previewSpotImageURLs: itemImageUrls.slice(1),
  };
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
      const coverRaw = input.coverImageUrl?.trim();
      const coverImageUrl = coverRaw && coverRaw.length > 0 ? coverRaw : null;

      const collection = await prisma.collection.create({
        data: {
          userId,
          name: input.name,
          description: input.description ?? null,
          visibility: (input.visibility as 'private' | 'friends' | 'public') ?? 'private',
          coverImageUrl,
        },
      });

      const count = await prisma.collectionItem.count({
        where: { collectionId: collection.id },
      });
      const imageData = await fetchCollectionImageData([collection.id]);
      const itemUrls = imageData.get(collection.id)?.itemImageUrls ?? [];
      const merged = mergeCollectionCoverAndPreviews(collection.coverImageUrl, itemUrls);
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
          coverImageURL: merged.coverImageURL,
          previewSpotImageURLs: merged.previewSpotImageURLs,
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

      const [currentUser, owned, savedLinks] = await Promise.all([
        prisma.user.findUnique({
          where: { id: userId },
          select: { handle: true, initials: true },
        }),
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

      const allCollectionIds = [
        ...owned.map((c) => c.id),
        ...savedLinks.map((sc) => sc.collection.id),
      ];

      const [ownedCounts, savedCounts, imageData] = await Promise.all([
        Promise.all(
          owned.map((c) => prisma.collectionItem.count({ where: { collectionId: c.id } }))
        ),
        Promise.all(
          savedLinks.map((sc) =>
            prisma.collectionItem.count({ where: { collectionId: sc.collection.id } })
          )
        ),
        fetchCollectionImageData(allCollectionIds),
      ]);

      const ownedData: CollectionData[] = owned.map((c, i) => {
        const itemUrls = imageData.get(c.id)?.itemImageUrls ?? [];
        const merged = mergeCollectionCoverAndPreviews(c.coverImageUrl, itemUrls);
        return {
          id: c.id,
          userId: c.userId,
          name: c.name,
          description: c.description,
          visibility: c.visibility,
          itemCount: ownedCounts[i] ?? 0,
          createdAt: c.createdAt.toISOString(),
          updatedAt: c.updatedAt.toISOString(),
          owned: true,
          ownerHandle: currentUser?.handle ?? null,
          ownerInitials: currentUser?.initials ?? null,
          coverImageURL: merged.coverImageURL,
          previewSpotImageURLs: merged.previewSpotImageURLs,
        };
      });

      const savedData: CollectionData[] = savedLinks.map((sc, i) => {
        const col = sc.collection;
        const itemUrls = imageData.get(col.id)?.itemImageUrls ?? [];
        const merged = mergeCollectionCoverAndPreviews(col.coverImageUrl, itemUrls);
        return {
          id: col.id,
          userId: col.userId,
          name: col.name,
          description: col.description,
          visibility: col.visibility,
          itemCount: savedCounts[i] ?? 0,
          createdAt: col.createdAt.toISOString(),
          updatedAt: col.updatedAt.toISOString(),
          owned: false,
          ownerHandle: col.user.handle,
          ownerInitials: col.user.initials,
          coverImageURL: merged.coverImageURL,
          previewSpotImageURLs: merged.previewSpotImageURLs,
        };
      });

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
      const latRaw = req.query['lat'];
      const lngRaw = req.query['lng'];
      const radiusRaw = req.query['radiusM'];
      const lat = latRaw !== undefined ? Number(latRaw) : NaN;
      const lng = lngRaw !== undefined ? Number(lngRaw) : NaN;
      const radiusM =
        radiusRaw !== undefined && !Number.isNaN(Number(radiusRaw))
          ? Number(radiusRaw)
          : DEFAULT_NEAR_RADIUS_M;

      let nearIds: string[] | null = null;
      if (Number.isFinite(lat) && Number.isFinite(lng)) {
        nearIds = await fetchPublicCollectionIdsNear(lat, lng, radiusM);
        if (nearIds.length === 0) {
          res.json({ data: [] });
          return;
        }
      }

      const collections = await prisma.collection.findMany({
        where: {
          visibility: 'public',
          ...(nearIds !== null ? { id: { in: nearIds } } : {}),
        },
        orderBy: { savedBy: { _count: 'desc' } },
        take: RECOMMENDED_LIMIT,
        include: {
          user: { select: { id: true, handle: true, initials: true } },
          _count: { select: { items: true, savedBy: true } },
        },
      });

      const imageData = await fetchCollectionImageData(collections.map((c) => c.id));

      const data: CollectionData[] = collections.map((c) => {
        const itemUrls = imageData.get(c.id)?.itemImageUrls ?? [];
        const merged = mergeCollectionCoverAndPreviews(c.coverImageUrl, itemUrls);
        return {
          id: c.id,
          userId: c.userId,
          name: c.name,
          description: c.description,
          visibility: c.visibility,
          itemCount: c._count.items,
          saveCount: c._count.savedBy,
          createdAt: c.createdAt.toISOString(),
          updatedAt: c.updatedAt.toISOString(),
          owned: false,
          ownerHandle: c.user.handle,
          ownerInitials: c.user.initials,
          coverImageURL: merged.coverImageURL,
          previewSpotImageURLs: merged.previewSpotImageURLs,
        };
      });

      res.json({ data });
    }
  )
);

/**
 * GET /collections/:id/items - Get items (spots and events) in a collection
 */
router.get(
  '/:id/items',
  requireAuth,
  validateRequest({ params: collectionIdSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }, { data: CollectionItemEntry[] } | ApiErrorResponse>,
      res: Response<{ data: CollectionItemEntry[] } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const collectionId = req.params.id;
      const userId = authReq.user.userId;

      const collection = await prisma.collection.findUnique({
        where: { id: collectionId },
      });
      if (!collection) {
        throw ApiError.notFound('Collection');
      }

      const allowed = await canViewCollection(collection, userId);
      if (!allowed) {
        throw ApiError.forbidden('You cannot view this collection');
      }

      const collectionItems = await prisma.collectionItem.findMany({
        where: { collectionId },
        orderBy: { createdAt: 'desc' },
      });

      const spotIds = collectionItems
        .filter((s) => s.itemType === 'spot')
        .map((s) => s.itemId);
      const eventIds = collectionItems
        .filter((s) => s.itemType === 'event')
        .map((s) => s.itemId);

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

      const data: CollectionItemEntry[] = collectionItems.map((s) => {
        const addedAt = s.createdAt.toISOString();
        if (s.itemType === 'spot') {
          const spot = spotMap.get(s.itemId);
          if (!spot) {
            return { itemType: 'spot' as const, addedAt };
          }
          const payload: CollectionItemSpotPayload = {
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
          };
          return { itemType: 'spot', addedAt, spot: payload };
        } else {
          const event = eventMap.get(s.itemId);
          if (!event) {
            return { itemType: 'event' as const, addedAt };
          }
          const eventData = formatEvent({
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
          });
          return { itemType: 'event', addedAt, event: eventData };
        }
      });

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

      const itemCount = await prisma.collectionItem.count({
        where: { collectionId: id },
      });
      const owned = collection.userId === userId;

      const imageData = await fetchCollectionImageData([id]);
      const itemUrls = imageData.get(id)?.itemImageUrls ?? [];
      const merged = mergeCollectionCoverAndPreviews(collection.coverImageUrl, itemUrls);

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
          ownerHandle: collection.user.handle,
          ownerInitials: collection.user.initials,
          coverImageURL: merged.coverImageURL,
          previewSpotImageURLs: merged.previewSpotImageURLs,
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
          ...(input.coverImageUrl !== undefined && {
            coverImageUrl:
              input.coverImageUrl === null || input.coverImageUrl.trim() === ''
                ? null
                : input.coverImageUrl.trim(),
          }),
        },
      });
      const itemCount = await prisma.collectionItem.count({
        where: { collectionId: id },
      });

      const imageData = await fetchCollectionImageData([id]);
      const itemUrls = imageData.get(id)?.itemImageUrls ?? [];
      const merged = mergeCollectionCoverAndPreviews(updated.coverImageUrl, itemUrls);

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
          coverImageURL: merged.coverImageURL,
          previewSpotImageURLs: merged.previewSpotImageURLs,
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

      const existing = await prisma.collectionItem.findFirst({
        where: { collectionId, itemId },
      });
      if (existing) {
        res.json({ data: { saved: true } });
        return;
      }

      // Add to collection, and also bookmark the item if not already saved
      const alreadySaved = await prisma.save.findUnique({
        where: { userId_itemType_itemId: { userId, itemType, itemId } },
      });

      await prisma.$transaction(async (tx) => {
        await tx.collectionItem.create({
          data: { collectionId, itemType, itemId },
        });
        if (!alreadySaved) {
          await tx.save.create({ data: { userId, itemType, itemId } });
          if (itemType === 'event') {
            await tx.event.update({
              where: { id: itemId },
              data: { saveCount: { increment: 1 } },
            });
          } else {
            await tx.spot.update({
              where: { id: itemId },
              data: { saveCount: { increment: 1 } },
            });
          }
        }
      });

      const saveCount =
        itemType === 'event'
          ? (
              await prisma.event.findUnique({
                where: { id: itemId },
                select: { saveCount: true },
              })
            )?.saveCount
          : (
              await prisma.spot.findUnique({
                where: { id: itemId },
                select: { saveCount: true },
              })
            )?.saveCount;
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

      const existing = await prisma.collectionItem.findFirst({
        where: { collectionId, itemId },
      });
      if (!existing) {
        res.json({ data: { saved: false } });
        return;
      }

      // Remove from collection only; the user's bookmark (Save) remains independent
      await prisma.collectionItem.delete({ where: { id: existing.id } });

      res.json({ data: { saved: false } });
    }
  )
);

export default router;

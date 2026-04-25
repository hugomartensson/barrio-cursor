import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { eventIdSchema } from '../schemas/events.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';
import { doesUserFollow } from '../services/collectionService.js';
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

/**
 * GET /events/:id/collections — collections containing this event that the viewer can see
 */
router.get(
  '/:id/collections',
  requireAuth,
  validateRequest({ params: eventIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const authReq = req as unknown as AuthenticatedRequest;
    const viewerId = authReq.user.userId;
    const eventId = req.params.id;

    const items = await prisma.collectionItem.findMany({
      where: { itemType: 'event', itemId: eventId },
      include: {
        collection: {
          include: {
            user: { select: { handle: true, initials: true } },
            items: { select: { id: true } },
          },
        },
      },
    });

    const visible = await Promise.all(
      items.map(async (item) => {
        const col = item.collection;
        if (col.userId === viewerId) {
          return col;
        }
        if (col.visibility === 'public') {
          return col;
        }
        if (col.visibility === 'friends') {
          const follows = await doesUserFollow(viewerId, col.userId);
          if (follows) {
            return col;
          }
        }
        return null;
      })
    );

    const collections = await Promise.all(
      visible.filter(Boolean).map(async (col) => {
        const colSpotItems = await prisma.collectionItem.findMany({
          where: { collectionId: col!.id, itemType: 'spot' },
          take: 3,
          select: { itemId: true },
        });
        const spotIds = colSpotItems.map((s) => s.itemId);
        const mediaItems = spotIds.length
          ? await prisma.mediaItem.findMany({
              where: { spotId: { in: spotIds } },
              select: { url: true },
              take: 3,
            })
          : [];
        const previewUrls = mediaItems.map((m) => m.url).slice(0, 2);
        const dbCover = col!.coverImageUrl?.trim();
        const coverImageURL = dbCover || previewUrls[0] || null;
        const previewSpotImageURLs = dbCover
          ? previewUrls.slice(0, 2)
          : previewUrls.slice(1);

        return {
          id: col!.id,
          name: col!.name,
          description: col!.description,
          visibility: col!.visibility,
          coverImageURL,
          previewSpotImageURLs,
          itemCount: col!.items.length,
          ownerHandle: col!.user.handle ?? null,
          ownerInitials: col!.user.initials ?? null,
          owned: col!.userId === viewerId,
          saveCount: 0,
          createdAt: col!.createdAt.toISOString(),
          updatedAt: col!.updatedAt.toISOString(),
        };
      })
    );

    res.json({ data: collections });
  })
);

/**
 * GET /events/:id/savers — all users who have saved this event
 */
router.get(
  '/:id/savers',
  requireAuth,
  validateRequest({ params: eventIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const authReq = req as unknown as AuthenticatedRequest;
    const viewerId = authReq.user.userId;
    const eventId = req.params.id;

    const saves = await prisma.save.findMany({
      where: { itemType: 'event', itemId: eventId },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            handle: true,
            initials: true,
            profilePictureUrl: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const savers = await Promise.all(
      saves.map(async (save) => {
        const isFollowing = await doesUserFollow(viewerId, save.user.id);
        return {
          id: save.user.id,
          name: save.user.name ?? save.user.handle ?? 'User',
          handle: save.user.handle ?? null,
          initials: save.user.initials ?? null,
          profilePictureUrl: save.user.profilePictureUrl ?? null,
          isFollowing,
        };
      })
    );

    res.json({ data: savers, total: savers.length });
  })
);

export default router;

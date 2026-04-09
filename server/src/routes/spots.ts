import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import type { Prisma } from '@prisma/client';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { fetchNearbySpots } from '../services/spotQueries.js';
import {
  listSpotsQuerySchema,
  createSpotSchema,
  updateSpotSchema,
  spotIdSchema,
} from '../schemas/spots.js';
import type { CreateSpotInput, UpdateSpotInput } from '../schemas/spots.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';
import { geocodeAddress } from '../services/geocoding.js';

const router = Router();

export interface SpotData {
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

/**
 * GET /spots — nearby spots
 */
router.get(
  '/',
  requireAuth,
  validateRequest({ query: listSpotsQuerySchema }),
  asyncHandler(
    async (req: Request, res: Response<{ data: SpotData[] } | ApiErrorResponse>) => {
      const query = req.query as unknown as {
        lat: number;
        lng: number;
        radius: number;
        limit: number;
        categoryTag?: string;
      };
      const rows = await fetchNearbySpots(
        query.lat,
        query.lng,
        query.limit,
        query.radius
      );
      const spotIds = rows.map((r) => r.id);
      if (spotIds.length === 0) {
        res.json({ data: [] });
        return;
      }
      const spots = await prisma.spot.findMany({
        where: { id: { in: spotIds } },
        include: {
          media: { orderBy: { order: 'asc' }, take: 1 },
          owner: { select: { id: true, handle: true } },
        },
      });
      const spotMap = new Map(spots.map((s) => [s.id, s]));
      const data: SpotData[] = rows
        .map((r) => {
          const spot = spotMap.get(r.id);
          if (!spot) {
            return null;
          }
          if (query.categoryTag && spot.categoryTag !== query.categoryTag) {
            return null;
          }
          return {
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
            distance: r.distance ?? 0,
            ownerId: spot.ownerId,
            ownerHandle: spot.owner.handle ?? null,
          };
        })
        .filter((x): x is SpotData => x !== null);
      res.json({ data });
    }
  )
);

/**
 * POST /spots — create a spot
 */
router.post(
  '/',
  requireAuth,
  validateRequest({ body: createSpotSchema }),
  asyncHandler(
    async (
      req: Request<object, { data: SpotData } | ApiErrorResponse, CreateSpotInput>,
      res: Response<{ data: SpotData } | ApiErrorResponse>
    ) => {
      const authReq = req as AuthenticatedRequest;
      const userId = authReq.user.userId;
      const input = req.body;

      let lat: number;
      let lng: number;
      if (input.latitude !== undefined && input.longitude !== undefined) {
        lat = input.latitude;
        lng = input.longitude;
      } else {
        try {
          const geocoded = await geocodeAddress(input.address);
          lat = geocoded.latitude;
          lng = geocoded.longitude;
        } catch {
          throw ApiError.badRequest(
            'Could not find location for this address. Please try a more specific address.'
          );
        }
      }

      const spot = await prisma.spot.create({
        data: {
          ownerId: userId,
          name: input.name,
          description: input.description,
          address: input.address,
          neighborhood: input.neighborhood ?? null,
          latitude: lat,
          longitude: lng,
          categoryTag: input.category,
          tags: input.tags ?? [],
          media: {
            create: {
              url: input.image.url,
              type: 'photo',
              order: 0,
              thumbnailUrl: input.image.thumbnailUrl ?? null,
            },
          },
        },
        include: {
          media: { orderBy: { order: 'asc' }, take: 1 },
          owner: { select: { id: true, handle: true } },
        },
      });

      res.status(201).json({
        data: {
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
        },
      });
    }
  )
);

/**
 * GET /spots/:id — spot detail
 */
router.get(
  '/:id',
  requireAuth,
  validateRequest({ params: spotIdSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }>,
      res: Response<{ data: SpotData } | ApiErrorResponse>
    ) => {
      const spot = await prisma.spot.findUnique({
        where: { id: req.params.id },
        include: {
          media: { orderBy: { order: 'asc' }, take: 1 },
          owner: { select: { id: true, handle: true } },
        },
      });

      if (!spot) {
        throw ApiError.notFound('Spot');
      }

      res.json({
        data: {
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
        },
      });
    }
  )
);

/**
 * PATCH /spots/:id — update spot (owner only)
 */
router.patch(
  '/:id',
  requireAuth,
  validateRequest({ params: spotIdSchema, body: updateSpotSchema }),
  asyncHandler(
    async (
      req: Request<
        { id: string },
        { data: SpotData } | ApiErrorResponse,
        UpdateSpotInput
      >,
      res: Response<{ data: SpotData } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const spotId = req.params.id;
      const input = req.body;

      const existing = await prisma.spot.findUnique({ where: { id: spotId } });
      if (!existing) {
        throw ApiError.notFound('Spot');
      }
      if (existing.ownerId !== authReq.user.userId) {
        throw ApiError.forbidden("You don't have permission to edit this spot");
      }

      const updateData: Prisma.SpotUpdateInput = {};
      if (input.name !== undefined) {
        updateData.name = input.name;
      }
      if (input.description !== undefined) {
        updateData.description = input.description;
      }
      if (input.category !== undefined) {
        updateData.categoryTag = input.category;
      }
      if (input.address !== undefined) {
        updateData.address = input.address;
        try {
          const geocoded = await geocodeAddress(input.address);
          updateData.latitude = geocoded.latitude;
          updateData.longitude = geocoded.longitude;
        } catch {
          throw ApiError.badRequest(
            'Could not find location for this address. Please try a more specific address.'
          );
        }
      }
      if (input.neighborhood !== undefined) {
        updateData.neighborhood = input.neighborhood;
      }
      if (input.tags !== undefined) {
        updateData.tags = input.tags;
      }

      if (input.image) {
        updateData.media = {
          deleteMany: {},
          create: {
            url: input.image.url,
            type: 'photo',
            order: 0,
            thumbnailUrl: input.image.thumbnailUrl ?? null,
          },
        };
      }

      const spot = await prisma.spot.update({
        where: { id: spotId },
        data: updateData,
        include: {
          media: { orderBy: { order: 'asc' }, take: 1 },
          owner: { select: { id: true, handle: true } },
        },
      });

      res.json({
        data: {
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
        },
      });
    }
  )
);

/**
 * DELETE /spots/:id — delete spot (owner only)
 */
router.delete(
  '/:id',
  requireAuth,
  validateRequest({ params: spotIdSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }>,
      res: Response<{ data: { message: string } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const spotId = req.params.id;

      const existing = await prisma.spot.findUnique({ where: { id: spotId } });
      if (!existing) {
        throw ApiError.notFound('Spot');
      }
      if (existing.ownerId !== authReq.user.userId) {
        throw ApiError.forbidden("You don't have permission to delete this spot");
      }

      await prisma.save.deleteMany({ where: { itemType: 'spot', itemId: spotId } });
      await prisma.spot.delete({ where: { id: spotId } });

      res.json({ data: { message: 'Spot deleted successfully' } });
    }
  )
);

/**
 * POST /spots/:id/save — toggle save on a spot
 */
router.post(
  '/:id/save',
  requireAuth,
  validateRequest({ params: spotIdSchema }),
  asyncHandler(
    async (
      req: Request<{ id: string }>,
      res: Response<{ data: { saved: boolean; saveCount: number } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const spotId = req.params.id;
      const userId = authReq.user.userId;

      const spot = await prisma.spot.findUnique({ where: { id: spotId } });
      if (!spot) {
        throw ApiError.notFound('Spot');
      }

      const existing = await prisma.save.findUnique({
        where: { userId_itemType_itemId: { userId, itemType: 'spot', itemId: spotId } },
      });

      if (existing) {
        await prisma.$transaction([
          prisma.save.delete({
            where: {
              userId_itemType_itemId: { userId, itemType: 'spot', itemId: spotId },
            },
          }),
          prisma.spot.update({
            where: { id: spotId },
            data: { saveCount: { decrement: 1 } },
          }),
        ]);
      } else {
        await prisma.$transaction([
          prisma.save.create({
            data: { userId, itemType: 'spot', itemId: spotId, collectionId: null },
          }),
          prisma.spot.update({
            where: { id: spotId },
            data: { saveCount: { increment: 1 } },
          }),
        ]);
      }

      const updated = await prisma.spot.findUnique({
        where: { id: spotId },
        select: { saveCount: true },
      });
      const isSaved = await prisma.save.findUnique({
        where: { userId_itemType_itemId: { userId, itemType: 'spot', itemId: spotId } },
      });

      res.json({
        data: {
          saved: !!isSaved,
          saveCount: updated?.saveCount ?? 0,
        },
      });
    }
  )
);

export default router;

import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { logger } from '../services/logger.js';
import {
  createEventSchema,
  updateEventSchema,
  nearbyEventsSchema,
  eventIdSchema,
} from '../schemas/events.js';
import type {
  CreateEventInput,
  UpdateEventInput,
  NearbyEventsQuery,
} from '../schemas/events.js';
import type {
  AuthenticatedRequest,
  ApiErrorResponse,
  RequestWithId,
} from '../types/index.js';
import type { EventResponse, EventsListResponse } from '../types/responses.js';
import type { Prisma } from '@prisma/client';
import { formatEvent, formatNearbyEvent } from '../utils/eventFormatters.js';
import {
  fetchNearbyEvents,
  fetchMediaForEvents,
  calcDistance,
} from '../services/eventQueries.js';
import { geocodeAddress } from '../services/geocoding.js';

const router = Router();

// Response types are now imported from shared types

// Request types
type CreateReq = Request<object, EventResponse | ApiErrorResponse, CreateEventInput>;
type GetReq = Request<{ id: string }, EventResponse | ApiErrorResponse>;
type DeleteReq = Request<
  { id: string },
  { data: { message: string } } | ApiErrorResponse
>;

/**
 * POST /events - Create a new event
 */
router.post(
  '/',
  requireAuth,
  validateRequest({ body: createEventSchema }),
  asyncHandler(
    async (req: CreateReq, res: Response<EventResponse | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;
      const requestId = (req as RequestWithId).id;
      const input = req.body;

      logger.info(
        {
          requestId,
          userId: authReq.user.userId,
          title: input.title,
          category: input.category,
          mediaCount: input.media.length,
        },
        '📝 Creating new event'
      );

      // Resolve location: spotId > explicit lat/lng > geocode.
      let lat: number;
      let lng: number;
      let resolvedAddress = input.address;
      let resolvedNeighborhood = input.neighborhood ?? null;
      let resolvedSpotId: string | null = null;

      if (input.spotId) {
        const spot = await prisma.spot.findUnique({ where: { id: input.spotId } });
        if (!spot) {
          throw ApiError.badRequest('Spot not found');
        }
        lat = spot.latitude;
        lng = spot.longitude;
        resolvedAddress = spot.address;
        resolvedNeighborhood = spot.neighborhood ?? null;
        resolvedSpotId = spot.id;
      } else if (input.latitude !== undefined && input.longitude !== undefined) {
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

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const eventData: any = {
        userId: authReq.user.userId,
        title: input.title,
        description: input.description,
        category: input.category,
        address: resolvedAddress,
        neighborhood: resolvedNeighborhood,
        latitude: lat,
        longitude: lng,
        spotId: resolvedSpotId,
        startTime: new Date(input.startTime),
        endTime: input.endTime ? new Date(input.endTime) : null,
        ticketUrl: input.ticketUrl,
        media: {
          create: input.media.map((m, i) => ({
            url: m.url,
            type: m.type,
            order: i,
            thumbnailUrl: m.thumbnailUrl ?? null,
          })),
        },
      };

      const event = await prisma.event.create({
        data: eventData,
        include: {
          media: { orderBy: { order: 'asc' } },
          user: { select: { id: true, name: true } },
        },
      });

      logger.info(
        {
          requestId,
          eventId: event.id,
          title: event.title,
        },
        '✅ Event created successfully'
      );

      res.status(201).json({ data: formatEvent(event) });
    }
  )
);

/**
 * GET /events/nearby - Get events within 5km radius
 * PRD Section 6.2: Following Filter
 */
router.get(
  '/nearby',
  requireAuth,
  validateRequest({ query: nearbyEventsSchema }),
  asyncHandler(
    async (req: Request, res: Response<EventsListResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const query = req.query as unknown as NearbyEventsQuery;
      const currentUserId = authReq.user.userId;
      const followingOnly = query.followingOnly ?? false;

      const events = await fetchNearbyEvents(
        query.lat,
        query.lng,
        query.limit,
        currentUserId,
        followingOnly
      );
      const mediaMap = await fetchMediaForEvents(events.map((e) => e.id));

      res.json({ data: events.map((e) => formatNearbyEvent(e, mediaMap)) });
    }
  )
);

/**
 * GET /events/:id - Get event by ID
 */
router.get(
  '/:id',
  requireAuth,
  validateRequest({ params: eventIdSchema }),
  asyncHandler(async (req: GetReq, res: Response<EventResponse | ApiErrorResponse>) => {
    const event = await prisma.event.findUnique({
      where: { id: req.params.id },
      include: {
        media: { orderBy: { order: 'asc' } },
        user: { select: { id: true, name: true } },
      },
    });

    if (!event) {
      throw ApiError.notFound('Event');
    }

    // PRD 5.1: Filter expired events - events visible until endTime > NOW() (or startTime > NOW() if no endTime)
    // Check if event is expired: endTime <= NOW() OR (endTime IS NULL AND startTime <= NOW())
    const now = new Date();
    const isExpired = event.endTime ? event.endTime <= now : event.startTime <= now;

    if (isExpired) {
      throw ApiError.notFound('Event');
    }

    const lat = parseFloat(req.query['lat'] as string) || null;
    const lng = parseFloat(req.query['lng'] as string) || null;
    const distance =
      lat && lng
        ? await calcDistance(event.latitude, event.longitude, lat, lng)
        : undefined;

    res.json({ data: formatEvent(event, distance) });
  })
);

/**
 * PATCH /events/:id - Update event
 * PRD Section 4.2: Edit Permissions
 * - Users can edit their own events if startTime > NOW() (future events) OR (startTime <= NOW() AND endTime > NOW()) (ongoing events)
 * - Users CANNOT edit past events (endTime < NOW())
 */
router.patch(
  '/:id',
  requireAuth,
  validateRequest({ params: eventIdSchema, body: updateEventSchema }),
  asyncHandler(async (req: Request, res: Response<EventResponse | ApiErrorResponse>) => {
    const authReq = req as unknown as AuthenticatedRequest;
    const requestId = (req as unknown as RequestWithId).id;
    const eventId = req.params['id'] as string;
    const input = req.body as UpdateEventInput;

    logger.info(
      {
        requestId,
        eventId,
        userId: authReq.user.userId,
        fields: Object.keys(input),
      },
      '📝 Updating event'
    );

    // Find event and verify ownership
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      select: {
        id: true,
        userId: true,
        startTime: true,
        endTime: true,
      },
    });

    if (!event) {
      throw ApiError.notFound('Event');
    }

    // Verify ownership
    if (event.userId !== authReq.user.userId) {
      throw ApiError.forbidden("You don't have permission to edit this event");
    }

    // PRD Section 4.2: Edit Permissions
    // Users can edit future events (startTime > NOW()) OR ongoing events (startTime <= NOW() AND endTime > NOW())
    // Users CANNOT edit past events (endTime < NOW())
    const now = new Date();
    const isFuture = event.startTime > now;
    const isOngoing =
      event.startTime <= now && event.endTime !== null && event.endTime > now;
    const canEdit = isFuture || isOngoing;

    if (!canEdit) {
      throw ApiError.forbidden('You can only edit future or ongoing events');
    }

    // Prepare update data
    const updateData: Prisma.EventUpdateInput = {};

    if (input.title !== undefined) {
      updateData.title = input.title;
    }
    if (input.description !== undefined) {
      updateData.description = input.description;
    }
    if (input.category !== undefined) {
      updateData.category = input.category;
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
    if (input.startTime !== undefined) {
      updateData.startTime = new Date(input.startTime);
    }
    if (input.endTime !== undefined) {
      updateData.endTime = input.endTime ? new Date(input.endTime) : null;
    }
    // Handle media updates (replace all media if provided)
    if (input.media !== undefined) {
      updateData.media = {
        deleteMany: {},
        create: input.media.map((m, i) => ({
          url: m.url,
          type: m.type,
          order: i,
          thumbnailUrl: m.thumbnailUrl ?? null,
        })),
      };
    }

    // Update event
    const updatedEvent = await prisma.event.update({
      where: { id: eventId },
      data: updateData,
      include: {
        media: { orderBy: { order: 'asc' } },
        user: { select: { id: true, name: true } },
      },
    });

    logger.info(
      {
        requestId,
        eventId,
      },
      '✅ Event updated successfully'
    );

    res.json({
      data: formatEvent(
        {
          id: updatedEvent.id,
          title: updatedEvent.title,
          description: updatedEvent.description,
          category: updatedEvent.category as string,
          address: updatedEvent.address,
          latitude: updatedEvent.latitude,
          longitude: updatedEvent.longitude,
          startTime: updatedEvent.startTime,
          endTime: updatedEvent.endTime,
          createdAt: updatedEvent.createdAt,
          saveCount: updatedEvent.saveCount,
          media: updatedEvent.media.map((m) => ({
            id: m.id,
            url: m.url,
            type: m.type as string,
            order: m.order,
            thumbnailUrl: m.thumbnailUrl,
          })),
          user: updatedEvent.user,
        },
        undefined
      ),
    });
  })
);

/**
 * DELETE /events/:id endpoint with ownership verification
 *
 * PRD Section 7.5: DELETE /events/:id endpoint with ownership verification
 * - Users can delete their own events
 * - Ownership verification: Only the event creator can delete their event
 * - Verifies event.userId matches authenticated user.userId before deletion
 * - Returns 403 Forbidden if user is not the event owner
 * - Returns 404 Not Found if event does not exist
 */
router.delete(
  '/:id',
  requireAuth,
  validateRequest({ params: eventIdSchema }),
  asyncHandler(
    async (
      req: DeleteReq,
      res: Response<{ data: { message: string } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const eventId = req.params.id;

      // Find event and check if it exists
      const event = await prisma.event.findUnique({
        where: { id: eventId },
        select: { id: true, userId: true },
      });

      if (!event) {
        throw ApiError.notFound('Event');
      }

      // PRD Section 7.5: DELETE /events/:id endpoint with ownership verification
      // Ownership verification: Only the event creator (userId matches authenticated user) can delete
      // This ensures users can only delete their own events, not events created by others
      if (event.userId !== authReq.user.userId) {
        throw ApiError.forbidden("You don't have permission to delete this event");
      }

      // Portal: remove saves pointing to this event (no FK cascade)
      await prisma.save.deleteMany({
        where: { itemType: 'event', itemId: eventId },
      });
      await prisma.event.delete({
        where: { id: eventId },
      });

      res.json({ data: { message: 'Event deleted successfully' } });
    }
  )
);

// Helper functions are now imported from utils/eventFormatters.ts and services/eventQueries.ts

export default router;

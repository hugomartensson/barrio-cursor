import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import {
  createEventSchema,
  nearbyEventsSchema,
  eventIdSchema,
} from '../schemas/events.js';
import type { CreateEventInput, NearbyEventsQuery } from '../schemas/events.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../types/index.js';

const router = Router();

const RADIUS_KM = 5;
const RADIUS_METERS = RADIUS_KM * 1000;

// Response types
interface EventData {
  id: string;
  title: string;
  description: string;
  category: string;
  latitude: number;
  longitude: number;
  startTime: string;
  endTime: string | null;
  createdAt: string;
  likesCount: number;
  goingCount: number;
  distance?: number;
  media: { id: string; url: string; type: string; order: number }[];
  user: { id: string; name: string };
}

interface EventResponse {
  data: EventData;
}

interface EventsListResponse {
  data: EventData[];
}

// Request types
type CreateReq = Request<object, EventResponse | ApiErrorResponse, CreateEventInput>;
type GetReq = Request<{ id: string }, EventResponse | ApiErrorResponse>;
type DeleteReq = Request<{ id: string }, { data: { message: string } } | ApiErrorResponse>;

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
      const input = req.body;

      const event = await prisma.event.create({
        data: {
          userId: authReq.user.userId,
          title: input.title,
          description: input.description,
          category: input.category,
          latitude: input.latitude,
          longitude: input.longitude,
          startTime: new Date(input.startTime),
          endTime: input.endTime ? new Date(input.endTime) : null,
          media: {
            create: input.media.map((m, i) => ({ url: m.url, type: m.type, order: i })),
          },
        },
        include: {
          media: { orderBy: { order: 'asc' } },
          user: { select: { id: true, name: true } },
        },
      });

      res.status(201).json({ data: formatEvent(event) });
    }
  )
);

/**
 * GET /events/nearby - Get events within 5km radius
 */
router.get(
  '/nearby',
  requireAuth,
  validateRequest({ query: nearbyEventsSchema }),
  asyncHandler(
    async (req: Request, res: Response<EventsListResponse | ApiErrorResponse>) => {
      const query = req.query as unknown as NearbyEventsQuery;
      const events = await fetchNearbyEvents(query.lat, query.lng, query.limit);
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
    const isExpired =
      event.endTime
        ? event.endTime <= now
        : event.startTime <= now;

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
 * DELETE /events/:id - Delete an event with ownership verification
 * Per PRD Section 7.5: Users can delete their own events
 * Ownership verification: Only the event creator can delete their event
 */
router.delete(
  '/:id',
  requireAuth,
  validateRequest({ params: eventIdSchema }),
  asyncHandler(
    async (req: DeleteReq, res: Response<{ data: { message: string } } | ApiErrorResponse>) => {
      const authReq = req as AuthenticatedRequest;
      const eventId = req.params.id;

      // Find event and check if it exists
      const event = await prisma.event.findUnique({
        where: { id: eventId },
        select: { id: true, userId: true },
      });

      if (!event) {
        throw ApiError.notFound('Event');
      }

      // PRD 7.5: Ownership verification - only event creator can delete
      if (event.userId !== authReq.user.userId) {
        throw ApiError.forbidden("You don't have permission to delete this event");
      }

      // Hard delete event (cascades to media, likes, going via Prisma schema)
      await prisma.event.delete({
        where: { id: eventId },
      });

      res.json({ data: { message: 'Event deleted successfully' } });
    }
  )
);

// Helper: Format event for response
function formatEvent(
  event: {
    id: string;
    title: string;
    description: string;
    category: string;
    latitude: number;
    longitude: number;
    startTime: Date;
    endTime: Date | null;
    createdAt: Date;
    likesCount: number;
    goingCount: number;
    media: { id: string; url: string; type: string; order: number }[];
    user: { id: string; name: string };
  },
  distance?: number
): EventData {
  return {
    id: event.id,
    title: event.title,
    description: event.description,
    category: event.category,
    latitude: event.latitude,
    longitude: event.longitude,
    startTime: event.startTime.toISOString(),
    endTime: event.endTime?.toISOString() ?? null,
    createdAt: event.createdAt.toISOString(),
    likesCount: event.likesCount,
    goingCount: event.goingCount,
    distance,
    media: event.media.map((m) => ({
      id: m.id,
      url: m.url,
      type: m.type,
      order: m.order,
    })),
    user: { id: event.user.id, name: event.user.name },
  };
}

// Helper: Raw query result type
interface NearbyEventRow {
  id: string;
  title: string;
  description: string;
  category: string;
  latitude: number;
  longitude: number;
  start_time: Date;
  end_time: Date | null;
  created_at: Date;
  likes_count: number;
  going_count: number;
  distance: number;
  user_id: string;
  user_name: string;
}

// Helper: Fetch nearby events with PostGIS
// Uses location geometry column with GIST index for optimal performance
// PRD 5.1: Filters expired events - events visible until endTime > NOW() (or startTime > NOW() if no endTime)
// SQL filter: WHERE endTime > NOW() OR (endTime IS NULL AND startTime > NOW())
async function fetchNearbyEvents(
  lat: number,
  lng: number,
  limit: number
): Promise<NearbyEventRow[]> {
  // All SQL queries use Prisma's template literal syntax which automatically parameterizes queries
  // This prevents SQL injection - ${variables} are safely parameterized
  return prisma.$queryRaw<NearbyEventRow[]>`
    SELECT e.id, e.title, e.description, e.category, e.latitude, e.longitude,
           e.start_time, e.end_time, e.created_at, e.likes_count, e.going_count,
           ST_Distance(e.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography) as distance,
           e.user_id, u.name as user_name
    FROM events e JOIN users u ON e.user_id = u.id
    WHERE e.location IS NOT NULL
      AND ST_DWithin(e.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography, ${RADIUS_METERS})
      AND ((e.end_time IS NULL AND e.start_time > NOW()) OR (e.end_time IS NOT NULL AND e.end_time > NOW()))
    ORDER BY e.created_at DESC LIMIT ${limit}
  `;
}

// Helper: Fetch media for multiple events
async function fetchMediaForEvents(
  eventIds: string[]
): Promise<Record<string, { id: string; url: string; type: string; order: number }[]>> {
  if (eventIds.length === 0) {
    return {};
  }
  const media = await prisma.mediaItem.findMany({
    where: { eventId: { in: eventIds } },
    orderBy: { order: 'asc' },
  });
  const result: Record<
    string,
    { id: string; url: string; type: string; order: number }[]
  > = {};
  for (const m of media) {
    if (!result[m.eventId]) {
      result[m.eventId] = [];
    }
    result[m.eventId]?.push({ id: m.id, url: m.url, type: m.type, order: m.order });
  }
  return result;
}

// Helper: Format nearby event row
function formatNearbyEvent(
  e: NearbyEventRow,
  mediaMap: Record<string, { id: string; url: string; type: string; order: number }[]>
): EventData {
  return {
    id: e.id,
    title: e.title,
    description: e.description,
    category: e.category,
    latitude: e.latitude,
    longitude: e.longitude,
    startTime: e.start_time.toISOString(),
    endTime: e.end_time?.toISOString() ?? null,
    createdAt: e.created_at.toISOString(),
    likesCount: e.likes_count,
    goingCount: e.going_count,
    distance: Math.round(e.distance),
    media: mediaMap[e.id] ?? [],
    user: { id: e.user_id, name: e.user_name },
  };
}

// Helper: Calculate distance using PostGIS
// SQL query uses Prisma's template literal syntax which automatically parameterizes queries
// This prevents SQL injection - ${variables} are safely parameterized
async function calcDistance(
  eventLat: number,
  eventLng: number,
  userLat: number,
  userLng: number
): Promise<number> {
  const result = await prisma.$queryRaw<{ distance: number }[]>`
    SELECT ST_Distance(
      ST_SetSRID(ST_MakePoint(${eventLng}, ${eventLat}), 4326)::geography,
      ST_SetSRID(ST_MakePoint(${userLng}, ${userLat}), 4326)::geography
    ) as distance
  `;
  return Math.round(result[0]?.distance ?? 0);
}

export default router;

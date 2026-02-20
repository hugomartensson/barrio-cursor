/**
 * Event query services
 * Database queries for event-related operations
 */

import { prisma } from './prisma.js';
import type { NearbyEventRow } from '../utils/eventFormatters.js';
import type { EventMedia } from '../types/responses.js';

const RADIUS_KM = 5;
const RADIUS_METERS = RADIUS_KM * 1000;

/**
 * Fetch nearby events with PostGIS
 * Uses location geometry column with GIST index for optimal performance
 * PRD 5.1: Filters expired events - events visible until endTime > NOW() (or startTime > NOW() if no endTime)
 * PRD Section 6.2: Following filter - when followingOnly=true, only show events from followed users
 * PRD Section 6.1: Private account visibility - non-followers can't see private account events
 */
export async function fetchNearbyEvents(
  lat: number,
  lng: number,
  limit: number,
  currentUserId: string,
  followingOnly: boolean
): Promise<NearbyEventRow[]> {
  // All SQL queries use Prisma's template literal syntax which automatically parameterizes queries
  // This prevents SQL injection - ${variables} are safely parameterized

  if (followingOnly) {
    // PRD Section 6.2: Following filter - only show events from followed users
    // Private account visibility is automatically respected (you can only see private account events if you follow them)
    return prisma.$queryRaw<NearbyEventRow[]>`
      SELECT e.id, e.title, e.description, e.category, e.address, e.latitude, e.longitude,
             e.start_time, e.end_time, e.created_at, e.interested_count,
             ST_Distance(e.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography) as distance,
             e.user_id, u.name as user_name
      FROM events e
      JOIN users u ON e.user_id = u.id
      JOIN follows f ON e.user_id = f.following_id AND f.follower_id = ${currentUserId}
      WHERE e.location IS NOT NULL
        AND ST_DWithin(e.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography, ${RADIUS_METERS})
        AND ((e.end_time IS NULL AND e.start_time > NOW()) OR (e.end_time IS NOT NULL AND e.end_time > NOW()))
      ORDER BY e.created_at DESC LIMIT ${limit}
    `;
  } else {
    // PRD Section 6.1: Private account visibility
    // Show all public account events, but only show private account events if current user follows them
    return prisma.$queryRaw<NearbyEventRow[]>`
      SELECT e.id, e.title, e.description, e.category, e.address, e.latitude, e.longitude,
             e.start_time, e.end_time, e.created_at, e.interested_count,
             ST_Distance(e.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography) as distance,
             e.user_id, u.name as user_name
      FROM events e
      JOIN users u ON e.user_id = u.id
      LEFT JOIN follows f ON e.user_id = f.following_id AND f.follower_id = ${currentUserId}
      WHERE e.location IS NOT NULL
        AND ST_DWithin(e.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography, ${RADIUS_METERS})
        AND ((e.end_time IS NULL AND e.start_time > NOW()) OR (e.end_time IS NOT NULL AND e.end_time > NOW()))
        AND (u.is_private = false OR f.follower_id IS NOT NULL)
      ORDER BY e.created_at DESC LIMIT ${limit}
    `;
  }
}

/**
 * Fetch media for multiple events
 */
export async function fetchMediaForEvents(
  eventIds: string[]
): Promise<Record<string, EventMedia[]>> {
  if (eventIds.length === 0) {
    return {};
  }
  const media = await prisma.mediaItem.findMany({
    where: { eventId: { in: eventIds } },
    orderBy: { order: 'asc' },
  });
  const result: Record<string, EventMedia[]> = {};
  for (const m of media) {
    if (!result[m.eventId]) {
      result[m.eventId] = [];
    }
    result[m.eventId]?.push({
      id: m.id,
      url: m.url,
      type: m.type,
      order: m.order,
      thumbnailUrl: m.thumbnailUrl,
    });
  }
  return result;
}

/**
 * Calculate distance using PostGIS
 * SQL query uses Prisma's template literal syntax which automatically parameterizes queries
 * This prevents SQL injection - ${variables} are safely parameterized
 */
export async function calcDistance(
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

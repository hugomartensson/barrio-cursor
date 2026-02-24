/**
 * Spot query services - PostGIS for "near you" / map viewport
 */

import { prisma } from './prisma.js';

const DEFAULT_RADIUS_METERS = 5000; // 5 km
const DEFAULT_LIMIT = 50;

export interface NearbySpotRow {
  id: string;
  owner_id: string;
  name: string;
  description: string | null;
  address: string;
  latitude: number;
  longitude: number;
  category_tag: string | null;
  neighborhood: string | null;
  price_range: string | null;
  distance: number;
}

/**
 * Fetch spots within radius of (lat, lng). Uses location geometry if available.
 */
export async function fetchNearbySpots(
  lat: number,
  lng: number,
  limit: number = DEFAULT_LIMIT,
  radiusMeters: number = DEFAULT_RADIUS_METERS
): Promise<NearbySpotRow[]> {
  const rows = await prisma.$queryRaw<NearbySpotRow[]>`
    SELECT s.id, s.owner_id, s.name, s.description, s.address, s.latitude, s.longitude,
           s.category_tag, s.neighborhood, s.price_range,
           COALESCE(
             ST_Distance(s.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography),
             0
           )::integer as distance
    FROM spots s
    WHERE s.location IS NOT NULL
      AND ST_DWithin(s.location::geography, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography, ${radiusMeters})
    ORDER BY distance ASC
    LIMIT ${limit}
  `;
  return rows;
}

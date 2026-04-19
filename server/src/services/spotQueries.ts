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
  category: string;
  neighborhood: string | null;
  distance: number;
}

/**
 * Fetch spots within radius of (lat, lng). Uses latitude/longitude (location column was removed).
 */
export async function fetchNearbySpots(
  lat: number,
  lng: number,
  limit: number = DEFAULT_LIMIT,
  radiusMeters: number = DEFAULT_RADIUS_METERS,
  category?: string
): Promise<NearbySpotRow[]> {
  const spotPointSql = `ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography`;
  const originSql = `ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography`;

  const categoryClause = category ? `AND s.category = '${category}'::"Category"` : '';

  const rows = await prisma.$queryRawUnsafe<NearbySpotRow[]>(
    `
    SELECT s.id, s.owner_id, s.name, s.description, s.address, s.latitude, s.longitude,
           s.category::text as category, s.neighborhood,
           ST_Distance(${spotPointSql}, ${originSql})::integer as distance
    FROM spots s
    WHERE ST_DWithin(${spotPointSql}, ${originSql}, $1)
    ${categoryClause}
    ORDER BY distance ASC
    LIMIT $2
  `,
    radiusMeters,
    limit
  );
  return rows;
}

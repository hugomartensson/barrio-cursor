/**
 * Spot query services - PostGIS for "near you" / map viewport, plus text search.
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

export interface TextSearchSpotRow {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  category: string;
  neighborhood: string | null;
  imageUrl: string | null;
  saveCount: number;
  distance: number;
}

/**
 * Full-text / ILIKE search across spot name, address, and neighborhood.
 * Returns up to `limit` results ordered by distance from (lat, lng).
 */
export async function fetchSpotsByText(
  query: string,
  lat: number,
  lng: number,
  limit = 5
): Promise<TextSearchSpotRow[]> {
  const pattern = `%${query.trim()}%`;
  const spotPointSql = `ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326)::geography`;
  const originSql = `ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)::geography`;

  const rows = await prisma.$queryRawUnsafe<
    Array<{
      id: string;
      name: string;
      address: string;
      latitude: number;
      longitude: number;
      category: string;
      neighborhood: string | null;
      image_url: string | null;
      save_count: number;
      distance: number;
    }>
  >(
    `
    SELECT
      s.id,
      s.name,
      s.address,
      s.latitude,
      s.longitude,
      s.category::text AS category,
      s.neighborhood,
      (SELECT m.url FROM media_items m WHERE m.spot_id = s.id ORDER BY m.order ASC LIMIT 1) AS image_url,
      s.save_count,
      ST_Distance(${spotPointSql}, ${originSql})::integer AS distance
    FROM spots s
    WHERE
      s.name ILIKE $1
      OR s.address ILIKE $1
      OR s.neighborhood ILIKE $1
    ORDER BY distance ASC
    LIMIT $2
    `,
    pattern,
    limit
  );

  return rows.map((r) => ({
    id: r.id,
    name: r.name,
    address: r.address,
    latitude: r.latitude,
    longitude: r.longitude,
    category: r.category,
    neighborhood: r.neighborhood,
    imageUrl: r.image_url,
    saveCount: r.save_count,
    distance: r.distance,
  }));
}

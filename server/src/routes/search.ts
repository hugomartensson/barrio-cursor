import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { logger } from '../services/logger.js';
import { fetchSpotsByText, type TextSearchSpotRow } from '../services/spotQueries.js';
import {
  getPlaceAutocomplete,
  getPlaceDetails,
  type PlaceDetails,
} from '../services/placesService.js';
import { searchNeighborhoods, type Neighborhood } from '../data/neighborhoods.js';
import {
  suggestQuerySchema,
  placeDetailsParamsSchema,
  placeDetailsQuerySchema,
  type SuggestQuery,
} from '../schemas/search.js';
import type { ApiErrorResponse } from '../types/index.js';

const router = Router();

// ---------------------------------------------------------------------------
// Response shape types
// ---------------------------------------------------------------------------

interface SpotResult {
  kind: 'spot';
  id: string;
  name: string;
  address: string;
  neighborhood: string | null;
  lat: number;
  lng: number;
  category: string;
  imageUrl: string | null;
  saveCount: number;
}

interface NeighborhoodResult {
  kind: 'neighborhood';
  slug: string;
  name: string;
  city: string;
  lat: number;
  lng: number;
}

interface PlaceResult {
  kind: 'place';
  placeId: string;
  primaryText: string;
  secondaryText: string;
  types: string[];
}

interface SuggestResponse {
  data: {
    spots: SpotResult[];
    neighborhoods: NeighborhoodResult[];
    places: PlaceResult[];
  };
}

interface PlaceDetailsResponse {
  data: PlaceDetails;
}

// ---------------------------------------------------------------------------
// Simple in-memory cache for suggest results (60-second TTL)
// Keyed by: q|lat_r3|lng_r3  (coordinates rounded to 3 dp ≈ 111m)
// ---------------------------------------------------------------------------

interface CacheEntry {
  data: SuggestResponse['data'];
  expiresAt: number;
}

const suggestCache = new Map<string, CacheEntry>();
const CACHE_TTL_MS = 60_000;
const MAX_CACHE_SIZE = 500;

function getCacheKey(q: string, lat: number, lng: number): string {
  return `${q.toLowerCase()}|${lat.toFixed(3)}|${lng.toFixed(3)}`;
}

function pruneCache(): void {
  if (suggestCache.size < MAX_CACHE_SIZE) {
    return;
  }
  const now = Date.now();
  for (const [key, entry] of suggestCache) {
    if (entry.expiresAt <= now) {
      suggestCache.delete(key);
    }
    if (suggestCache.size < MAX_CACHE_SIZE * 0.8) {
      break;
    }
  }
}

// ---------------------------------------------------------------------------
// Mappers
// ---------------------------------------------------------------------------

function toSpotResult(row: TextSearchSpotRow): SpotResult {
  return {
    kind: 'spot',
    id: row.id,
    name: row.name,
    address: row.address,
    neighborhood: row.neighborhood,
    lat: row.latitude,
    lng: row.longitude,
    category: row.category,
    imageUrl: row.imageUrl,
    saveCount: row.saveCount,
  };
}

function toNeighborhoodResult(n: Neighborhood): NeighborhoodResult {
  return {
    kind: 'neighborhood',
    slug: n.slug,
    name: n.name,
    city: n.city,
    lat: n.lat,
    lng: n.lng,
  };
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

/**
 * GET /search/suggest
 * Federated location search: Barrio spots + neighborhoods + Google Places.
 *
 * Query params: q, lat, lng, sessionToken, limit?
 */
router.get(
  '/suggest',
  requireAuth,
  validateRequest({ query: suggestQuerySchema }),
  asyncHandler(
    async (req: Request, res: Response<SuggestResponse | ApiErrorResponse>) => {
      const { q, lat, lng, sessionToken } = req.query as unknown as SuggestQuery;

      if (q.trim().length < 2) {
        res.json({ data: { spots: [], neighborhoods: [], places: [] } });
        return;
      }

      // For the Barrio spot text search the lat/lng only affects distance
      // sort order, so 0/0 is a safe default when the client has no fix.
      const spotLat = lat ?? 0;
      const spotLng = lng ?? 0;

      const cacheKey = getCacheKey(q, spotLat, spotLng);
      const cached = suggestCache.get(cacheKey);
      if (cached && cached.expiresAt > Date.now()) {
        res.json({ data: cached.data });
        return;
      }

      const start = Date.now();

      const [spotRows, neighborhoodHits, placeHits] = await Promise.all([
        fetchSpotsByText(q, spotLat, spotLng, 5).catch((err) => {
          logger.warn({ err }, 'search/suggest: spot query failed');
          return [] as TextSearchSpotRow[];
        }),
        Promise.resolve(searchNeighborhoods(q, 3)),
        getPlaceAutocomplete(q, lat, lng, sessionToken, 15).catch((err) => {
          logger.warn({ err }, 'search/suggest: Places Autocomplete failed');
          return [];
        }),
      ]);

      const data: SuggestResponse['data'] = {
        spots: spotRows.map(toSpotResult),
        neighborhoods: neighborhoodHits.map(toNeighborhoodResult),
        places: placeHits.map((p) => ({ kind: 'place' as const, ...p })),
      };

      const totalResults =
        data.spots.length + data.neighborhoods.length + data.places.length;
      logger.info(
        {
          q,
          spots: data.spots.length,
          neighborhoods: data.neighborhoods.length,
          places: data.places.length,
          totalResults,
          latencyMs: Date.now() - start,
        },
        'search/suggest'
      );

      pruneCache();
      suggestCache.set(cacheKey, { data, expiresAt: Date.now() + CACHE_TTL_MS });

      res.json({ data });
    }
  )
);

/**
 * GET /search/place/:placeId
 * Resolve a Google Place ID to coordinates and address details.
 *
 * Query params: sessionToken
 */
router.get(
  '/place/:placeId',
  requireAuth,
  validateRequest({ params: placeDetailsParamsSchema, query: placeDetailsQuerySchema }),
  asyncHandler(
    async (
      req: Request<{ placeId: string }>,
      res: Response<PlaceDetailsResponse | ApiErrorResponse>
    ) => {
      const { placeId } = req.params;
      const { sessionToken } = req.query as { sessionToken: string };

      const details = await getPlaceDetails(placeId, sessionToken);
      if (!details) {
        throw ApiError.notFound('Place');
      }

      res.json({ data: details });
    }
  )
);

export default router;

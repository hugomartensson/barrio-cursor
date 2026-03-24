import { Router, Response } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { createSpotSchema } from '../schemas/spots.js';
import { createEventSchema } from '../schemas/events.js';
import { geocodeAddress } from '../services/geocoding.js';
import { config } from '../config/index.js';
import { createLogger } from '../services/logger.js';

const router = Router();
const logger = createLogger({ component: 'ingest-validate' });

/** Try geocoding, then fall back to Places text search by name if the address alone fails. */
async function resolveCoords(
  address: string,
  name?: string
): Promise<{ latitude: number; longitude: number; formattedAddress: string | null }> {
  const googleKey = config.GOOGLE_MAPS_API_KEY ?? config.GOOGLE_PLACES_API_KEY;
  if (!googleKey) {
    throw Object.assign(
      new Error('GOOGLE_MAPS_API_KEY is not configured on this service'),
      { configMissing: true }
    );
  }

  // Primary: geocode the address directly
  try {
    const g = await geocodeAddress(address);
    return {
      latitude: g.latitude,
      longitude: g.longitude,
      formattedAddress: g.formattedAddress,
    };
  } catch (geocodeErr) {
    logger.warn(
      { address, err: String(geocodeErr) },
      'Geocoding failed, trying Places fallback'
    );
  }

  // Fallback: Places text search by name + city when address geocoding returns no results
  if (name) {
    const key = googleKey;
    const queries = [`${name} Barcelona`, `${name}, ${address}`];
    for (const query of queries) {
      const searchUrl = new URL(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
      );
      searchUrl.searchParams.set('query', query);
      searchUrl.searchParams.set('key', key);
      const searchRes = await fetch(searchUrl.toString(), {
        signal: AbortSignal.timeout(12_000),
      });
      if (!searchRes.ok) {
        continue;
      }
      const searchJson = (await searchRes.json()) as {
        status: string;
        results?: Array<{
          place_id?: string;
          geometry?: { location: { lat: number; lng: number } };
          formatted_address?: string;
        }>;
      };
      const first = searchJson.results?.[0];
      if (first?.geometry?.location) {
        logger.info({ query, placeId: first.place_id }, 'Resolved via Places fallback');
        return {
          latitude: first.geometry.location.lat,
          longitude: first.geometry.location.lng,
          formattedAddress: first.formatted_address ?? null,
        };
      }
    }
  }

  throw new Error(`Could not resolve location for "${address}"`);
}

type ValidateOk = {
  valid: true;
  type: 'spot' | 'event';
  latitude: number;
  longitude: number;
  formattedAddress: string | null;
};

type ValidateErr = {
  valid: false;
  type: 'spot' | 'event';
  error: { message: string; details?: Record<string, string> };
};

/**
 * POST /ingest/validate-draft — same validation as create spot/event, runs geocode when lat/lng omitted.
 * Returns coordinates so clients can pass them to POST /spots or /events and avoid a second geocode.
 */
router.post(
  '/validate-draft',
  requireAuth,
  asyncHandler(async (req, res: Response<ValidateOk | ValidateErr>) => {
    const raw = req.body as Record<string, unknown> & { type?: string };
    const kind = raw?.type;
    const stripType = (): Record<string, unknown> => {
      const { type: _t, ...rest } = raw;
      return rest;
    };

    if (kind === 'spot') {
      const spotParse = createSpotSchema.safeParse(stripType());
      if (!spotParse.success) {
        const details: Record<string, string> = {};
        spotParse.error.issues.forEach((e) => {
          details[e.path.join('.') || 'root'] = e.message;
        });
        res.status(200).json({
          valid: false,
          type: 'spot',
          error: { message: 'Invalid spot draft', details },
        });
        return;
      }
      const spot = spotParse.data;
      if (spot.latitude !== undefined && spot.longitude !== undefined) {
        res.json({
          valid: true,
          type: 'spot',
          latitude: spot.latitude,
          longitude: spot.longitude,
          formattedAddress: null,
        });
        return;
      }
      try {
        const g = await resolveCoords(spot.address, spot.name);
        res.json({
          valid: true,
          type: 'spot',
          latitude: g.latitude,
          longitude: g.longitude,
          formattedAddress: g.formattedAddress,
        });
        return;
      } catch (err) {
        const configMissing = (err as { configMissing?: boolean }).configMissing;
        res.status(200).json({
          valid: false,
          type: 'spot',
          error: {
            message: configMissing
              ? 'Geocoding is not configured on this server (GOOGLE_MAPS_API_KEY missing). Contact admin.'
              : 'Could not find location for this address. Try editing the address or name.',
          },
        });
        return;
      }
    }

    if (kind === 'event') {
      const eventParse = createEventSchema.safeParse(stripType());
      if (!eventParse.success) {
        const details: Record<string, string> = {};
        eventParse.error.issues.forEach((e) => {
          details[e.path.join('.') || 'root'] = e.message;
        });
        res.status(200).json({
          valid: false,
          type: 'event',
          error: { message: 'Invalid event draft', details },
        });
        return;
      }
      const ev = eventParse.data;
      if (ev.latitude !== undefined && ev.longitude !== undefined) {
        res.json({
          valid: true,
          type: 'event',
          latitude: ev.latitude,
          longitude: ev.longitude,
          formattedAddress: null,
        });
        return;
      }
      try {
        const g = await resolveCoords(ev.address, ev.title);
        res.json({
          valid: true,
          type: 'event',
          latitude: g.latitude,
          longitude: g.longitude,
          formattedAddress: g.formattedAddress,
        });
        return;
      } catch (err) {
        const configMissing = (err as { configMissing?: boolean }).configMissing;
        res.status(200).json({
          valid: false,
          type: 'event',
          error: {
            message: configMissing
              ? 'Geocoding is not configured on this server (GOOGLE_MAPS_API_KEY missing). Contact admin.'
              : 'Could not find location for this address. Try editing the address or name.',
          },
        });
        return;
      }
    }

    res.status(200).json({
      valid: false,
      type: 'spot',
      error: { message: 'Body must include type: "spot" or "event"' },
    });
  })
);

export default router;

import { Router, Response } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { createSpotSchema } from '../schemas/spots.js';
import { createEventSchema } from '../schemas/events.js';
import { geocodeAddress } from '../services/geocoding.js';

const router = Router();

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
        const g = await geocodeAddress(spot.address);
        res.json({
          valid: true,
          type: 'spot',
          latitude: g.latitude,
          longitude: g.longitude,
          formattedAddress: g.formattedAddress,
        });
        return;
      } catch {
        res.status(200).json({
          valid: false,
          type: 'spot',
          error: {
            message:
              'Could not find location for this address. Please try a more specific address.',
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
        const g = await geocodeAddress(ev.address);
        res.json({
          valid: true,
          type: 'event',
          latitude: g.latitude,
          longitude: g.longitude,
          formattedAddress: g.formattedAddress,
        });
        return;
      } catch {
        res.status(200).json({
          valid: false,
          type: 'event',
          error: {
            message:
              'Could not find location for this address. Please try a more specific address.',
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

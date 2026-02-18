import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { logger } from '../services/logger.js';
import { z } from 'zod';
import {
  scrapeUrl,
  extractEventWithLLM,
  extractEventFromText,
} from '../services/import.js';
import { geocodeAddress } from '../services/geocoding.js';
import { downloadAndUploadMultipleMedia } from '../services/importMedia.js';
import { uploadFile } from '../services/media.js';
import type { AuthenticatedRequest, RequestWithId } from '../types/index.js';

const router = Router();

/**
 * Smart geocoding: tries the address first. If the address is too vague
 * (just a city name like "Barcelona"), falls back to geocoding the venue name
 * with the city appended (e.g. "Sala Apolo, Barcelona").
 */
async function smartGeocode(
  address: string,
  venueName: string | null,
  requestId: string
): Promise<{ latitude: number; longitude: number; formattedAddress: string } | null> {
  const isVagueAddress = (addr: string) => {
    const trimmed = addr.trim().toLowerCase();
    const vaguePatterns = [
      'barcelona',
      'madrid',
      'spain',
      'españa',
      'catalonia',
      'catalunya',
    ];
    return vaguePatterns.some(
      (p) => trimmed === p || trimmed === p + ', spain' || trimmed === p + ', españa'
    );
  };

  // If the address is specific enough, geocode it directly
  if (address && !isVagueAddress(address)) {
    try {
      return await geocodeAddress(address);
    } catch (error) {
      logger.warn(
        { requestId, address, error: (error as Error).message },
        'Geocoding address failed'
      );
    }
  }

  // Fallback: try geocoding the venue name + city
  if (venueName) {
    const venueQuery = `${venueName}, Barcelona, Spain`;
    logger.info(
      { requestId, venueQuery },
      'Address too vague, geocoding venue name instead'
    );
    try {
      return await geocodeAddress(venueQuery);
    } catch (error) {
      logger.warn(
        { requestId, venueQuery, error: (error as Error).message },
        'Geocoding venue name also failed'
      );
    }
  }

  // Last resort: try the original address even if vague
  if (address) {
    try {
      return await geocodeAddress(address);
    } catch (error) {
      logger.warn(
        { requestId, address, error: (error as Error).message },
        'Final geocoding attempt failed'
      );
    }
  }

  return null;
}

// --- Schemas ---

const extractSchema = z.object({
  url: z.string().url('Must be a valid URL'),
});

const extractTextSchema = z.object({
  text: z.string().min(1, 'Text is required'),
  sourceUrl: z.string().url().optional(),
});

const uploadMediaSchema = z.object({
  image: z.string(), // base64 encoded
  contentType: z.string().default('image/jpeg'),
});

// --- Routes ---

/**
 * POST /api/import/extract
 * Takes a URL, scrapes it, extracts event data with Claude, geocodes the address,
 * and downloads/re-uploads media to Supabase Storage.
 * Returns a pre-filled draft ready for review.
 */
router.post(
  '/extract',
  requireAuth,
  validateRequest({ body: extractSchema }),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;
    const requestId = (req as RequestWithId).id;
    const { url } = req.body as z.infer<typeof extractSchema>;

    logger.info(
      { requestId, url, userId: authReq.user.userId },
      'Starting event import extraction'
    );

    // Step 1: Scrape the URL
    const scraped = await scrapeUrl(url);

    // Step 2: Extract event data with Claude
    const extracted = await extractEventWithLLM(scraped);

    // Step 3: Geocode the address (falls back to venue name if address is vague)
    const geocoded = await smartGeocode(
      extracted.address,
      extracted.venueName,
      requestId
    );

    // Step 4: Download and re-upload media to Supabase Storage
    let mediaResult: {
      uploaded: Array<{ url: string; type: 'photo' | 'video' }>;
      failed: Array<{ url: string; error: string }>;
    } = {
      uploaded: [],
      failed: [],
    };
    if (extracted.mediaUrls.length > 0) {
      mediaResult = await downloadAndUploadMultipleMedia(
        extracted.mediaUrls,
        authReq.user.userId
      );
    }

    // Build the draft response
    const draft = {
      title: extracted.title,
      description: extracted.description,
      category: extracted.category,
      address: geocoded?.formattedAddress ?? extracted.address,
      latitude: geocoded?.latitude ?? null,
      longitude: geocoded?.longitude ?? null,
      startTime: extracted.startTime,
      endTime: extracted.endTime,
      isFree: extracted.isFree,
      venueName: extracted.venueName,
      ticketUrl: extracted.ticketUrl,
      sourceUrl: extracted.sourceUrl,
      media: mediaResult.uploaded.map((m) => ({ url: m.url, type: m.type })),
      failedMediaUrls: mediaResult.failed,
      geocodingSucceeded: geocoded !== null,
    };

    logger.info(
      {
        requestId,
        title: draft.title,
        mediaUploaded: draft.media.length,
        mediaFailed: draft.failedMediaUrls.length,
        geocodingSucceeded: draft.geocodingSucceeded,
      },
      'Event extraction complete'
    );

    res.json({ data: draft });
  })
);

/**
 * POST /api/import/extract-text
 * Extract event data from raw pasted text (for Instagram captions, etc.)
 * No scraping needed -- sends the text directly to Claude.
 */
router.post(
  '/extract-text',
  requireAuth,
  validateRequest({ body: extractTextSchema }),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;
    const requestId = (req as RequestWithId).id;
    const { text, sourceUrl } = req.body as z.infer<typeof extractTextSchema>;

    logger.info(
      { requestId, textLength: text.length, sourceUrl },
      'Extracting event from pasted text'
    );

    // Send text directly to Claude (no scraping needed)
    const extracted = await extractEventFromText(text, sourceUrl);

    // Geocode the address (falls back to venue name if address is vague)
    const geocoded = await smartGeocode(
      extracted.address,
      extracted.venueName,
      requestId
    );

    const draft = {
      title: extracted.title,
      description: extracted.description,
      category: extracted.category,
      address: geocoded?.formattedAddress ?? extracted.address,
      latitude: geocoded?.latitude ?? null,
      longitude: geocoded?.longitude ?? null,
      startTime: extracted.startTime,
      endTime: extracted.endTime,
      isFree: extracted.isFree,
      venueName: extracted.venueName,
      ticketUrl: extracted.ticketUrl,
      sourceUrl: extracted.sourceUrl,
      media: [],
      failedMediaUrls: [],
      geocodingSucceeded: geocoded !== null,
    };

    logger.info({ requestId, title: draft.title }, 'Text extraction complete');

    res.json({ data: draft });
  })
);

/**
 * POST /api/import/upload-media
 * Upload a single image (base64) for events where auto-extraction failed.
 * Used by the admin page for manual drag-and-drop media.
 */
router.post(
  '/upload-media',
  requireAuth,
  validateRequest({ body: uploadMediaSchema }),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;
    const requestId = (req as RequestWithId).id;
    const { image, contentType } = req.body as z.infer<typeof uploadMediaSchema>;

    logger.info({ requestId, contentType }, 'Uploading manual import media');

    // Decode base64
    const base64Data = image.includes(',') ? (image.split(',')[1] ?? image) : image;
    const fileBuffer = Buffer.from(base64Data, 'base64');

    if (fileBuffer.length === 0) {
      res.status(400).json({ error: 'Empty file data' });
      return;
    }

    const result = await uploadFile(authReq.user.userId, fileBuffer, contentType);

    logger.info(
      { requestId, url: result.url, type: result.type },
      'Import media uploaded'
    );

    res.status(201).json({ data: { url: result.url, type: result.type } });
  })
);

/**
 * POST /api/import/geocode
 * Geocode an address string. Used when the admin edits the address field
 * and needs to re-geocode.
 */
router.post(
  '/geocode',
  requireAuth,
  validateRequest({ body: z.object({ address: z.string().min(1) }) }),
  asyncHandler(async (req: Request, res: Response) => {
    const requestId = (req as RequestWithId).id;
    const { address } = req.body as { address: string };

    logger.info({ requestId, address }, 'Geocoding address from admin');

    const result = await geocodeAddress(address);

    res.json({
      data: {
        latitude: result.latitude,
        longitude: result.longitude,
        formattedAddress: result.formattedAddress,
      },
    });
  })
);

export default router;

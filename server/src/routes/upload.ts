import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth.js';
import type { AuthenticatedRequest, RequestWithId } from '../types/index.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import {
  uploadFile,
  validateVideoDuration,
  createSignedUploadUrl,
  getPublicUrl,
} from '../services/media.js';
import { ApiError } from '../utils/ApiError.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { logger } from '../services/logger.js';
import { z } from 'zod';

const router = Router();

const uploadSchema = z.object({
  image: z.string(), // base64 encoded image or video
  contentType: z.string().default('image/jpeg'),
  duration: z.number().positive().optional(), // Video duration in seconds (required for videos)
});

// Query parameters come as strings, need to parse duration
const signedUrlSchema = z.object({
  contentType: z.string(),
  duration: z.string().optional(), // Video duration in seconds (required for videos) - will parse as number
});

// Accept base64 encoded images/videos in JSON
router.post(
  '/',
  requireAuth,
  validateRequest({ body: uploadSchema }),
  asyncHandler(async (req: Request, res: Response) => {
    const startTime = Date.now();
    const requestId = (req as RequestWithId).id;

    logger.info({ requestId }, '📤 Upload request received');

    const authReq = req as AuthenticatedRequest;
    const userId = authReq.user.userId;
    const { image, contentType, duration } = req.body as z.infer<typeof uploadSchema>;

    const base64SizeMB = (image.length * 3) / 4 / 1024 / 1024; // Approximate size
    logger.info(
      { requestId, contentType, base64SizeMB: base64SizeMB.toFixed(2) },
      '📦 Upload data received'
    );

    const isVideo = contentType.startsWith('video/');
    const isImage = contentType.startsWith('image/');

    if (!isImage && !isVideo) {
      throw ApiError.badRequest('Content-Type must be an image or video type');
    }

    // Validate video duration if it's a video
    if (isVideo) {
      if (duration === undefined || duration === null) {
        throw ApiError.badRequest('Video duration is required for video uploads');
      }
      validateVideoDuration(duration);
    }

    // Decode base64
    const decodeStart = Date.now();
    let fileBuffer: Buffer;
    try {
      // Remove data URL prefix if present (e.g., "data:image/jpeg;base64,")
      const base64Data = image.includes(',') ? (image.split(',')[1] ?? image) : image;
      fileBuffer = Buffer.from(base64Data, 'base64');
      const decodeTime = Date.now() - decodeStart;
      const fileSizeMB = fileBuffer.length / 1024 / 1024;
      logger.info(
        { requestId, fileSizeMB: fileSizeMB.toFixed(2), decodeTimeMs: decodeTime },
        '✅ Base64 decoded'
      );
    } catch (error) {
      logger.error({ requestId, error }, '❌ Base64 decode failed');
      throw ApiError.badRequest('Invalid base64 data');
    }

    if (fileBuffer.length === 0) {
      throw ApiError.badRequest('No file data received');
    }

    // Upload to Supabase
    const uploadStart = Date.now();
    logger.info({ requestId }, '☁️ Starting Supabase upload...');
    const result = await uploadFile(userId, fileBuffer, contentType);
    const uploadTime = Date.now() - uploadStart;
    const totalTime = Date.now() - startTime;

    logger.info(
      { requestId, uploadTimeMs: uploadTime, totalTimeMs: totalTime },
      '✅ Upload complete'
    );

    res.status(201).json({
      data: {
        url: result.url,
        type: result.type,
      },
    });
  })
);

/**
 * GET /upload/signed-url - Get signed upload URL for direct client upload
 * This allows iOS to upload directly to Supabase, bypassing our server
 * Much faster for large files (especially videos)
 */
router.get(
  '/signed-url',
  requireAuth,
  validateRequest({ query: signedUrlSchema }),
  asyncHandler(async (req: Request, res: Response) => {
    const requestId = (req as RequestWithId).id;
    const authReq = req as AuthenticatedRequest;
    const userId = authReq.user.userId;
    const { contentType, duration: durationStr } = req.query as {
      contentType: string;
      duration?: string;
    };
    const duration = durationStr ? Number(durationStr) : undefined;

    logger.info({ requestId, contentType, duration }, '🔑 Requesting signed upload URL');

    const isVideo = contentType.startsWith('video/');
    const isImage = contentType.startsWith('image/');

    if (!isImage && !isVideo) {
      throw ApiError.badRequest('Content-Type must be an image or video type');
    }

    // Validate video duration if it's a video
    if (isVideo) {
      if (duration === undefined || duration === null || isNaN(duration)) {
        throw ApiError.badRequest('Video duration is required for video uploads');
      }
      validateVideoDuration(duration);
    }

    // Generate signed upload URL
    const { uploadUrl, filePath } = await createSignedUploadUrl(userId, contentType);

    // Get public URL that will be available after upload
    const publicUrl = getPublicUrl(filePath);

    logger.info({ requestId, filePath }, '✅ Signed upload URL generated');

    res.json({
      data: {
        uploadUrl,
        filePath,
        publicUrl,
      },
    });
  })
);

export default router;

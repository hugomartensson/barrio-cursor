import { Router, Request, Response } from 'express';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { uploadFile, validateVideoDuration } from '../services/media.js';
import { ApiError } from '../utils/ApiError.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { z } from 'zod';

const router = Router();

const uploadSchema = z.object({
  image: z.string(), // base64 encoded image or video
  contentType: z.string().default('image/jpeg'),
  duration: z.number().positive().optional(), // Video duration in seconds (required for videos)
});

// Accept base64 encoded images/videos in JSON
router.post(
  '/',
  requireAuth,
  validateRequest({ body: uploadSchema }),
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as AuthenticatedRequest;
    const userId = authReq.user.userId;
    const { image, contentType, duration } = req.body as z.infer<typeof uploadSchema>;

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
    let fileBuffer: Buffer;
    try {
      // Remove data URL prefix if present (e.g., "data:image/jpeg;base64,")
      const base64Data = image.includes(',') ? image.split(',')[1] : image;
      fileBuffer = Buffer.from(base64Data, 'base64');
    } catch (error) {
      throw ApiError.badRequest('Invalid base64 data');
    }

    if (fileBuffer.length === 0) {
      throw ApiError.badRequest('No file data received');
    }

    // Upload to Supabase
    const result = await uploadFile(userId, fileBuffer, contentType);

    res.status(201).json({
      data: {
        url: result.url,
        type: result.type,
      },
    });
  })
);

export default router;


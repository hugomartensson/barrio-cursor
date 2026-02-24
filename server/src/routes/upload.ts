import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth.js';
import type { AuthenticatedRequest, RequestWithId } from '../types/index.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { uploadFile, createSignedUploadUrl, getPublicUrl } from '../services/media.js';
import { ApiError } from '../utils/ApiError.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { logger } from '../services/logger.js';
import { z } from 'zod';

const router = Router();

const uploadSchema = z.object({
  image: z.string(),
  contentType: z.string().default('image/jpeg'),
});

const signedUrlSchema = z.object({
  contentType: z.string(),
});

router.post(
  '/',
  requireAuth,
  validateRequest({ body: uploadSchema }),
  asyncHandler(async (req: Request, res: Response) => {
    const startTime = Date.now();
    const requestId = (req as RequestWithId).id;

    logger.info({ requestId }, 'Upload request received');

    const authReq = req as AuthenticatedRequest;
    const userId = authReq.user.userId;
    const { image, contentType } = req.body as z.infer<typeof uploadSchema>;

    if (!contentType.startsWith('image/')) {
      throw ApiError.badRequest('Content-Type must be an image type');
    }

    let fileBuffer: Buffer;
    try {
      const base64Data = image.includes(',') ? (image.split(',')[1] ?? image) : image;
      fileBuffer = Buffer.from(base64Data, 'base64');
    } catch (error) {
      logger.error({ requestId, error }, 'Base64 decode failed');
      throw ApiError.badRequest('Invalid base64 data');
    }

    if (fileBuffer.length === 0) {
      throw ApiError.badRequest('No file data received');
    }

    const result = await uploadFile(userId, fileBuffer, contentType);
    const totalTime = Date.now() - startTime;

    logger.info({ requestId, totalTimeMs: totalTime }, 'Upload complete');

    res.status(201).json({
      data: {
        url: result.url,
        type: result.type,
      },
    });
  })
);

router.get(
  '/signed-url',
  requireAuth,
  validateRequest({ query: signedUrlSchema }),
  asyncHandler(async (req: Request, res: Response) => {
    const requestId = (req as RequestWithId).id;
    const authReq = req as AuthenticatedRequest;
    const userId = authReq.user.userId;
    const { contentType } = req.query as { contentType: string };

    if (!contentType.startsWith('image/')) {
      throw ApiError.badRequest('Content-Type must be an image type');
    }

    const { uploadUrl, filePath } = await createSignedUploadUrl(userId, contentType);
    const publicUrl = getPublicUrl(filePath);

    logger.info({ requestId, filePath }, 'Signed upload URL generated');

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

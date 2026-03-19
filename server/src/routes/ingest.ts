/* istanbul ignore file */
import { ItemType, Category, DraftStatus } from '@prisma/client';
import { Router, type Request, type Response } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { prisma } from '../services/prisma.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { publisher } from '../tools/ingest/publisher.js';

const router = Router();

const draftIdSchema = z.object({ id: z.string().cuid() });
const draftPatchSchema = z.object({
  itemType: z.nativeEnum(ItemType).nullable().optional(),
  name: z.string().nullable().optional(),
  description: z.string().nullable().optional(),
  category: z.nativeEnum(Category).nullable().optional(),
  address: z.string().nullable().optional(),
  neighborhood: z.string().nullable().optional(),
  startTime: z.string().datetime().nullable().optional(),
  endTime: z.string().datetime().nullable().optional(),
  tags: z.array(z.string()).optional(),
  imageUrl: z.string().url().nullable().optional(),
  sourceUrl: z.string().url().nullable().optional(),
  flaggedFields: z.array(z.string()).optional(),
  collectionId: z.string().uuid().nullable().optional(),
  rawInput: z.string().nullable().optional(),
});

router.get(
  '/drafts',
  requireAuth,
  asyncHandler(async (_req: Request, res: Response) => {
    const drafts = await prisma.draft.findMany({
      where: { status: DraftStatus.PENDING },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ data: drafts });
  })
);

router.get(
  '/drafts/:id',
  requireAuth,
  validateRequest({ params: draftIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const draft = await prisma.draft.findUnique({ where: { id: req.params.id } });
    if (!draft) {
      throw ApiError.notFound('Draft');
    }
    res.json({ data: draft });
  })
);

router.patch(
  '/drafts/:id',
  requireAuth,
  validateRequest({ params: draftIdSchema, body: draftPatchSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const input = req.body as z.infer<typeof draftPatchSchema>;
    const updated = await prisma.draft.update({
      where: { id: req.params.id },
      data: {
        ...input,
        startTime:
          input.startTime === undefined
            ? undefined
            : input.startTime
              ? new Date(input.startTime)
              : null,
        endTime:
          input.endTime === undefined
            ? undefined
            : input.endTime
              ? new Date(input.endTime)
              : null,
      },
    });
    res.json({ data: updated });
  })
);

router.post(
  '/drafts/:id/approve',
  requireAuth,
  validateRequest({ params: draftIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const draft = await prisma.draft.findUnique({ where: { id: req.params.id } });
    if (!draft) {
      throw ApiError.notFound('Draft');
    }

    const portalId = await publisher.publishDraft(draft);
    const updated = await prisma.draft.update({
      where: { id: draft.id },
      data: { status: DraftStatus.APPROVED, portalId, errorMessage: null },
    });

    res.json({ data: updated });
  })
);

router.post(
  '/drafts/:id/skip',
  requireAuth,
  validateRequest({ params: draftIdSchema }),
  asyncHandler(async (req: Request<{ id: string }>, res: Response) => {
    const updated = await prisma.draft.update({
      where: { id: req.params.id },
      data: { status: DraftStatus.SKIPPED },
    });
    res.json({ data: updated });
  })
);

export default router;

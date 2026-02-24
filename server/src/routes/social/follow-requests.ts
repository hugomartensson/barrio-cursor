/**
 * Follow request management endpoints
 * GET /users/me/follow-requests - Get pending follow requests
 * POST /follow-requests/:id/accept - Accept a follow request
 * POST /follow-requests/:id/decline - Decline a follow request
 */

import { Router, Response } from 'express';
import { prisma } from '../../services/prisma.js';
import { requireAuth } from '../../middleware/auth.js';
import { validateRequest } from '../../middleware/validateRequest.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { ApiError } from '../../utils/ApiError.js';
import { logger } from '../../services/logger.js';
import { followRequestIdSchema } from '../../schemas/social.js';
import type {
  AuthenticatedRequest,
  ApiErrorResponse,
  RequestWithId,
} from '../../types/index.js';
import type {
  FollowRequestReq,
  AcceptFollowRequestReq,
  DeclineFollowRequestReq,
  FollowRequestResponse,
} from './types.js';

const router = Router();

/**
 * GET /users/me/follow-requests - Get pending follow requests for current user
 * PRD Section 6.1: Follow Requests (Private Accounts Only)
 */
router.get(
  '/users/me/follow-requests',
  requireAuth,
  asyncHandler(
    async (
      req: FollowRequestReq,
      res: Response<FollowRequestResponse | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const _requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;

      const requests = await prisma.followRequest.findMany({
        where: {
          toUserId: currentUserId,
          status: 'pending',
        },
        include: {
          fromUser: {
            select: {
              id: true,
              name: true,
              profilePictureUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      const followRequests = requests.map((req) => ({
        id: req.id,
        fromUserId: req.fromUser.id,
        fromUserName: req.fromUser.name,
        fromUserProfilePictureUrl: req.fromUser.profilePictureUrl,
        status: req.status as 'pending' | 'accepted' | 'declined',
        createdAt: req.createdAt.toISOString(),
      }));

      res.json({ data: followRequests });
    }
  )
);

/**
 * POST /follow-requests/:id/accept - Accept a follow request
 * PRD Section 6.1: Follow Requests (Private Accounts Only)
 */
router.post(
  '/follow-requests/:id/accept',
  requireAuth,
  validateRequest({ params: followRequestIdSchema }),
  asyncHandler(
    async (
      req: AcceptFollowRequestReq,
      res: Response<{ data: { message: string } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const requestIdParam = req.params.id;

      // Find follow request
      const followRequest = await prisma.followRequest.findUnique({
        where: { id: requestIdParam },
      });

      if (!followRequest) {
        throw ApiError.notFound('Follow request');
      }

      // Verify ownership (only recipient can accept)
      if (followRequest.toUserId !== currentUserId) {
        throw ApiError.forbidden('You can only accept follow requests sent to you');
      }

      if (followRequest.status !== 'pending') {
        throw ApiError.badRequest('Follow request is not pending');
      }

      // Accept: Create Follow relationship and delete request
      await prisma.$transaction([
        prisma.follow.create({
          data: {
            followerId: followRequest.fromUserId,
            followingId: followRequest.toUserId,
          },
        }),
        prisma.followRequest.update({
          where: { id: requestIdParam },
          data: { status: 'accepted' },
        }),
        prisma.user.update({
          where: { id: followRequest.toUserId },
          data: { followerCount: { increment: 1 } },
        }),
        prisma.user.update({
          where: { id: followRequest.fromUserId },
          data: { followingCount: { increment: 1 } },
        }),
      ]);

      logger.info(
        {
          requestId,
          followRequestId: requestIdParam,
          fromUserId: followRequest.fromUserId,
          toUserId: followRequest.toUserId,
        },
        '✅ Follow request accepted'
      );

      res.json({ data: { message: 'Follow request accepted' } });
    }
  )
);

/**
 * POST /follow-requests/:id/decline - Decline a follow request
 * PRD Section 6.1: Follow Requests (Private Accounts Only)
 */
router.post(
  '/follow-requests/:id/decline',
  requireAuth,
  validateRequest({ params: followRequestIdSchema }),
  asyncHandler(
    async (
      req: DeclineFollowRequestReq,
      res: Response<{ data: { message: string } } | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const requestIdParam = req.params.id;

      // Find follow request
      const followRequest = await prisma.followRequest.findUnique({
        where: { id: requestIdParam },
      });

      if (!followRequest) {
        throw ApiError.notFound('Follow request');
      }

      // Verify ownership (only recipient can decline)
      if (followRequest.toUserId !== currentUserId) {
        throw ApiError.forbidden('You can only decline follow requests sent to you');
      }

      if (followRequest.status !== 'pending') {
        throw ApiError.badRequest('Follow request is not pending');
      }

      // Decline: Update status to declined
      await prisma.followRequest.update({
        where: { id: requestIdParam },
        data: { status: 'declined' },
      });

      logger.info(
        {
          requestId,
          followRequestId: requestIdParam,
          fromUserId: followRequest.fromUserId,
          toUserId: followRequest.toUserId,
        },
        '✅ Follow request declined'
      );

      res.json({ data: { message: 'Follow request declined' } });
    }
  )
);

export default router;

/**
 * Follow/Unfollow endpoints
 * POST /users/:id/follow - Follow a user
 * DELETE /users/:id/follow - Unfollow a user
 */

import { Router, Response } from 'express';
import { prisma } from '../../services/prisma.js';
import { requireAuth } from '../../middleware/auth.js';
import { validateRequest } from '../../middleware/validateRequest.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { ApiError } from '../../utils/ApiError.js';
import { logger } from '../../services/logger.js';
import { userIdSchema } from '../../schemas/social.js';
import type {
  AuthenticatedRequest,
  ApiErrorResponse,
  RequestWithId,
} from '../../types/index.js';
import type { FollowReq, FollowResponse } from './types.js';

const router = Router();

/**
 * POST /users/:id/follow - Follow a user
 * PRD Section 6.1: Following System
 * - Public accounts: Instant follow
 * - Private accounts: Create follow request
 * - Self-follow prevention: Cannot follow yourself
 */
router.post(
  '/users/:id/follow',
  requireAuth,
  validateRequest({ params: userIdSchema }),
  asyncHandler(
    async (req: FollowReq, res: Response<FollowResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const targetUserId = req.params.id;

      logger.info(
        {
          requestId,
          currentUserId,
          targetUserId,
        },
        '👥 Follow request received'
      );

      // PRD Section 6.1: Self-follow prevention
      if (currentUserId === targetUserId) {
        throw ApiError.badRequest('You cannot follow yourself');
      }

      // Check if target user exists
      const targetUser = await prisma.user.findUnique({
        where: { id: targetUserId },
        select: { id: true, isPrivate: true },
      });

      if (!targetUser) {
        throw ApiError.notFound('User');
      }

      // Check if already following
      const existingFollow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: currentUserId,
            followingId: targetUserId,
          },
        },
      });

      if (existingFollow) {
        // Already following, return current state
        const [followerCount, followingCount] = await Promise.all([
          prisma.follow.count({ where: { followingId: targetUserId } }),
          prisma.follow.count({ where: { followerId: currentUserId } }),
        ]);

        res.json({
          data: {
            following: true,
            followerCount,
            followingCount,
          },
        });
        return;
      }

      // Check if there's a pending follow request (for private accounts)
      const existingRequest = await prisma.followRequest.findFirst({
        where: {
          fromUserId: currentUserId,
          toUserId: targetUserId,
          status: 'pending',
        },
      });

      if (existingRequest) {
        // Request already exists, return current state
        const [followerCount, followingCount] = await Promise.all([
          prisma.follow.count({ where: { followingId: targetUserId } }),
          prisma.follow.count({ where: { followerId: currentUserId } }),
        ]);

        res.json({
          data: {
            following: false, // Not following yet, request pending
            followerCount,
            followingCount,
          },
        });
        return;
      }

      // PRD Section 6.1: Handle public vs private accounts
      if (targetUser.isPrivate) {
        // Private account: Create follow request
        await prisma.followRequest.create({
          data: {
            fromUserId: currentUserId,
            toUserId: targetUserId,
            status: 'pending',
          },
        });

        logger.info(
          {
            requestId,
            currentUserId,
            targetUserId,
          },
          '✅ Follow request created (private account)'
        );
      } else {
        // Public account: Instant follow
        await prisma.$transaction([
          prisma.follow.create({
            data: {
              followerId: currentUserId,
              followingId: targetUserId,
            },
          }),
          prisma.user.update({
            where: { id: targetUserId },
            data: { followerCount: { increment: 1 } },
          }),
          prisma.user.update({
            where: { id: currentUserId },
            data: { followingCount: { increment: 1 } },
          }),
        ]);

        logger.info(
          {
            requestId,
            currentUserId,
            targetUserId,
          },
          '✅ User followed (public account)'
        );
      }

      // Get updated counts
      const [followerCount, followingCount] = await Promise.all([
        prisma.follow.count({ where: { followingId: targetUserId } }),
        prisma.follow.count({ where: { followerId: currentUserId } }),
      ]);

      res.json({
        data: {
          following: !targetUser.isPrivate, // true if public (instant follow), false if private (request pending)
          followerCount,
          followingCount,
        },
      });
    }
  )
);

/**
 * DELETE /users/:id/follow - Unfollow a user
 * PRD Section 6.1: Following System
 */
router.delete(
  '/users/:id/follow',
  requireAuth,
  validateRequest({ params: userIdSchema }),
  asyncHandler(
    async (req: FollowReq, res: Response<FollowResponse | ApiErrorResponse>) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const targetUserId = req.params.id;

      logger.info(
        {
          requestId,
          currentUserId,
          targetUserId,
        },
        '👥 Unfollow request received'
      );

      // Check if following
      const existingFollow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: currentUserId,
            followingId: targetUserId,
          },
        },
      });

      if (!existingFollow) {
        // Not following, check if there's a pending request to cancel
        const existingRequest = await prisma.followRequest.findFirst({
          where: {
            fromUserId: currentUserId,
            toUserId: targetUserId,
            status: 'pending',
          },
        });

        if (existingRequest) {
          // Cancel pending request
          await prisma.followRequest.delete({
            where: { id: existingRequest.id },
          });

          logger.info(
            {
              requestId,
              currentUserId,
              targetUserId,
            },
            '✅ Follow request cancelled'
          );
        }

        // Return current state (not following)
        const [followerCount, followingCount] = await Promise.all([
          prisma.follow.count({ where: { followingId: targetUserId } }),
          prisma.follow.count({ where: { followerId: currentUserId } }),
        ]);

        res.json({
          data: {
            following: false,
            followerCount,
            followingCount,
          },
        });
        return;
      }

      // Unfollow: Remove follow relationship and update counts
      await prisma.$transaction([
        prisma.follow.delete({
          where: {
            followerId_followingId: {
              followerId: currentUserId,
              followingId: targetUserId,
            },
          },
        }),
        prisma.user.update({
          where: { id: targetUserId },
          data: { followerCount: { decrement: 1 } },
        }),
        prisma.user.update({
          where: { id: currentUserId },
          data: { followingCount: { decrement: 1 } },
        }),
      ]);

      logger.info(
        {
          requestId,
          currentUserId,
          targetUserId,
        },
        '✅ User unfollowed'
      );

      // Get updated counts
      const [followerCount, followingCount] = await Promise.all([
        prisma.follow.count({ where: { followingId: targetUserId } }),
        prisma.follow.count({ where: { followerId: currentUserId } }),
      ]);

      res.json({
        data: {
          following: false,
          followerCount,
          followingCount,
        },
      });
    }
  )
);

export default router;

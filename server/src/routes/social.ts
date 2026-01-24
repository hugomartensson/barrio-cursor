import { Router, Request, Response } from 'express';
import { prisma } from '../services/prisma.js';
import { requireAuth } from '../middleware/auth.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { logger } from '../services/logger.js';
import { userIdSchema, followRequestIdSchema } from '../schemas/social.js';
import type {
  AuthenticatedRequest,
  ApiErrorResponse,
  RequestWithId,
} from '../types/index.js';

const router = Router();

// Response types
interface FollowResponse {
  data: {
    following: boolean;
    followerCount: number;
    followingCount: number;
  };
}

interface FollowersListResponse {
  data: {
    id: string;
    name: string;
    profilePictureUrl: string | null;
    followerCount: number;
    isFollowing: boolean; // Whether current user follows this user
  }[];
}

interface FollowingListResponse {
  data: {
    id: string;
    name: string;
    profilePictureUrl: string | null;
    followerCount: number;
    isFollowing: boolean; // Always true for following list
  }[];
}

interface FollowRequestResponse {
  data: {
    id: string;
    fromUserId: string;
    fromUserName: string;
    fromUserProfilePictureUrl: string | null;
    status: 'pending' | 'accepted' | 'declined';
    createdAt: string;
  }[];
}

// Request types
type FollowReq = Request<{ id: string }, FollowResponse | ApiErrorResponse>;
type FollowersReq = Request<{ id: string }, FollowersListResponse | ApiErrorResponse>;
type FollowingReq = Request<{ id: string }, FollowingListResponse | ApiErrorResponse>;
type FollowRequestReq = Request<object, FollowRequestResponse | ApiErrorResponse>;
type AcceptFollowRequestReq = Request<
  { id: string },
  { data: { message: string } } | ApiErrorResponse
>;
type DeclineFollowRequestReq = Request<
  { id: string },
  { data: { message: string } } | ApiErrorResponse
>;

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

/**
 * GET /users/:id/followers - Get list of followers
 * PRD Section 6.1: Following/Followers visibility
 * - Public accounts: All followers visible
 * - Private accounts: Only visible to followers
 */
router.get(
  '/users/:id/followers',
  requireAuth,
  validateRequest({ params: userIdSchema }),
  asyncHandler(
    async (
      req: FollowersReq,
      res: Response<FollowersListResponse | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const targetUserId = req.params.id;

      // Check if target user exists and is private
      const targetUser = await prisma.user.findUnique({
        where: { id: targetUserId },
        select: { id: true, isPrivate: true },
      });

      if (!targetUser) {
        throw ApiError.notFound('User');
      }

      // PRD Section 6.1: Private account visibility
      // If private account, only show followers list to followers
      if (targetUser.isPrivate) {
        const isFollowing = await prisma.follow.findUnique({
          where: {
            followerId_followingId: {
              followerId: currentUserId,
              followingId: targetUserId,
            },
          },
        });

        // Allow if viewing own profile or if following
        if (currentUserId !== targetUserId && !isFollowing) {
          throw ApiError.forbidden(
            'Followers list is only visible to followers of private accounts'
          );
        }
      }

      // Get followers
      const follows = await prisma.follow.findMany({
        where: { followingId: targetUserId },
        include: {
          follower: {
            select: {
              id: true,
              name: true,
              profilePictureUrl: true,
              followerCount: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      // Check which of these users the current user follows
      const followerIds = follows.map((f) => f.follower.id);
      const currentUserFollows = await prisma.follow.findMany({
        where: {
          followerId: currentUserId,
          followingId: { in: followerIds },
        },
      });

      const followingSet = new Set(currentUserFollows.map((f) => f.followingId));

      const followers = follows.map((f) => ({
        id: f.follower.id,
        name: f.follower.name,
        profilePictureUrl: f.follower.profilePictureUrl,
        followerCount: f.follower.followerCount,
        isFollowing: followingSet.has(f.follower.id),
      }));

      res.json({ data: followers });
    }
  )
);

/**
 * GET /users/:id/following - Get list of users being followed
 * PRD Section 6.1: Following/Followers visibility
 * - Public accounts: All following visible
 * - Private accounts: Only visible to followers
 */
router.get(
  '/users/:id/following',
  requireAuth,
  validateRequest({ params: userIdSchema }),
  asyncHandler(
    async (
      req: FollowingReq,
      res: Response<FollowingListResponse | ApiErrorResponse>
    ) => {
      const authReq = req as unknown as AuthenticatedRequest;
      const requestId = (req as unknown as RequestWithId).id;
      const currentUserId = authReq.user.userId;
      const targetUserId = req.params.id;

      // Check if target user exists and is private
      const targetUser = await prisma.user.findUnique({
        where: { id: targetUserId },
        select: { id: true, isPrivate: true },
      });

      if (!targetUser) {
        throw ApiError.notFound('User');
      }

      // PRD Section 6.1: Private account visibility
      // If private account, only show following list to followers
      if (targetUser.isPrivate) {
        const isFollowing = await prisma.follow.findUnique({
          where: {
            followerId_followingId: {
              followerId: currentUserId,
              followingId: targetUserId,
            },
          },
        });

        // Allow if viewing own profile or if following
        if (currentUserId !== targetUserId && !isFollowing) {
          throw ApiError.forbidden(
            'Following list is only visible to followers of private accounts'
          );
        }
      }

      // Get following
      const follows = await prisma.follow.findMany({
        where: { followerId: targetUserId },
        include: {
          following: {
            select: {
              id: true,
              name: true,
              profilePictureUrl: true,
              followerCount: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      });

      // All users in following list are followed by target user, so isFollowing is always true
      const following = follows.map((f) => ({
        id: f.following.id,
        name: f.following.name,
        profilePictureUrl: f.following.profilePictureUrl,
        followerCount: f.following.followerCount,
        isFollowing: true, // Always true for following list
      }));

      res.json({ data: following });
    }
  )
);

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
      const requestId = (req as unknown as RequestWithId).id;
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

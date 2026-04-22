/**
 * Followers/Following list endpoints
 * GET /users/:id/followers - Get list of followers
 * GET /users/:id/following - Get list of users being followed
 */

import { Router, Request, Response } from 'express';
import { prisma } from '../../services/prisma.js';
import { requireAuth } from '../../middleware/auth.js';
import { validateRequest } from '../../middleware/validateRequest.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import { ApiError } from '../../utils/ApiError.js';
import { userIdSchema } from '../../schemas/social.js';
import type { AuthenticatedRequest, ApiErrorResponse } from '../../types/index.js';
import type {
  FollowersReq,
  FollowingReq,
  FollowersListResponse,
  FollowingListResponse,
} from './types.js';

const router = Router();

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
 * GET /users/me/mutual-followers — users who follow me AND I follow them
 */
router.get(
  '/users/me/mutual-followers',
  requireAuth,
  asyncHandler(async (req: Request, res: Response) => {
    const authReq = req as unknown as AuthenticatedRequest;
    const currentUserId = authReq.user.userId;

    // Users I follow
    const iFollow = await prisma.follow.findMany({
      where: { followerId: currentUserId },
      select: { followingId: true },
    });
    const iFollowIds = new Set(iFollow.map((f) => f.followingId));

    // Of those, who follows me back
    const mutuals = await prisma.follow.findMany({
      where: {
        followerId: { in: [...iFollowIds] },
        followingId: currentUserId,
      },
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

    const data = mutuals.map((f) => ({
      id: f.follower.id,
      name: f.follower.name,
      profilePictureUrl: f.follower.profilePictureUrl,
      followerCount: f.follower.followerCount,
      isFollowing: true,
    }));

    res.json({ data });
  })
);

export default router;

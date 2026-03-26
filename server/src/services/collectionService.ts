import { prisma } from './prisma.js';
import type { Collection } from '@prisma/client';

/**
 * Check if viewer follows the given user (viewer is follower, userId is following).
 */
export async function doesUserFollow(
  followerId: string,
  followingId: string
): Promise<boolean> {
  if (followerId === followingId) {
    return true;
  }
  const row = await prisma.follow.findUnique({
    where: {
      followerId_followingId: { followerId, followingId },
    },
  });
  return !!row;
}

/**
 * Can the viewer see this collection? (owner, public, friends and follows owner, or has saved it)
 */
export async function canViewCollection(
  collection: Pick<Collection, 'id' | 'userId' | 'visibility'>,
  viewerId: string
): Promise<boolean> {
  if (collection.userId === viewerId) {
    return true;
  }
  if (collection.visibility === 'public') {
    return true;
  }
  if (collection.visibility === 'friends') {
    return doesUserFollow(viewerId, collection.userId);
  }
  // private: only owner; also allow if viewer has saved it (they had access when they saved)
  const saved = await prisma.savedCollection.findUnique({
    where: {
      userId_collectionId: { userId: viewerId, collectionId: collection.id },
    },
  });
  return !!saved;
}

/**
 * Can the requester save this collection? (public → anyone; friends → only if follows owner; not own)
 */
export async function canSaveCollection(
  collection: Pick<Collection, 'id' | 'userId' | 'visibility'>,
  requesterId: string
): Promise<boolean> {
  if (collection.userId === requesterId) {
    return false;
  } // cannot save own collection
  if (collection.visibility === 'public') {
    return true;
  }
  if (collection.visibility === 'friends') {
    return doesUserFollow(requesterId, collection.userId);
  }
  return false; // private
}

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

export interface CollectionImageData {
  coverImageURL: string | null;
  previewSpotImageURLs: string[];
}

/**
 * Resolve a collection's cover image and preview thumbnails. Falls back to the
 * first media item from up to 3 spots in the collection when no explicit cover
 * is set on the row.
 */
export async function resolveCollectionImages(
  collectionId: string,
  dbCoverImageUrl: string | null | undefined
): Promise<CollectionImageData> {
  const colSpotItems = await prisma.collectionItem.findMany({
    where: { collectionId, itemType: 'spot' },
    take: 3,
    select: { itemId: true },
  });
  const spotIds = colSpotItems.map((s) => s.itemId);
  const mediaItems = spotIds.length
    ? await prisma.mediaItem.findMany({
        where: { spotId: { in: spotIds } },
        select: { url: true },
        take: 3,
      })
    : [];
  const previewUrls = mediaItems.map((m) => m.url).slice(0, 2);
  const dbCover = dbCoverImageUrl?.trim();
  const coverImageURL = dbCover || previewUrls[0] || null;
  const previewSpotImageURLs = dbCover ? previewUrls.slice(0, 2) : previewUrls.slice(1);
  return { coverImageURL, previewSpotImageURLs };
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

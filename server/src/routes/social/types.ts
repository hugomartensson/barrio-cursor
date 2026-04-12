/**
 * Shared types for social routes
 */

import type { Request as ExpressRequest } from 'express';
import type { ApiErrorResponse } from '../../types/index.js';

type Request<TParams = object, TResBody = unknown> = ExpressRequest<TParams, TResBody>;

export interface FollowResponse {
  data: {
    following: boolean;
    followerCount: number;
    followingCount: number;
  };
}

export interface FollowersListResponse {
  data: {
    id: string;
    name: string;
    profilePictureUrl: string | null;
    followerCount: number;
    isFollowing: boolean; // Whether current user follows this user
  }[];
}

export interface FollowingListResponse {
  data: {
    id: string;
    name: string;
    profilePictureUrl: string | null;
    followerCount: number;
    isFollowing: boolean; // Always true for following list
  }[];
}

export interface FollowRequestResponse {
  data: {
    id: string;
    fromUserId: string;
    fromUserName: string;
    fromUserHandle: string | null;
    fromUserProfilePictureUrl: string | null;
    status: 'pending' | 'accepted' | 'declined';
    createdAt: string;
  }[];
}

// Request types
export type FollowReq = Request<{ id: string }, FollowResponse | ApiErrorResponse>;
export type FollowersReq = Request<
  { id: string },
  FollowersListResponse | ApiErrorResponse
>;
export type FollowingReq = Request<
  { id: string },
  FollowingListResponse | ApiErrorResponse
>;
export type FollowRequestReq = Request<object, FollowRequestResponse | ApiErrorResponse>;
export type AcceptFollowRequestReq = Request<
  { id: string },
  { data: { message: string } } | ApiErrorResponse
>;
export type DeclineFollowRequestReq = Request<
  { id: string },
  { data: { message: string } } | ApiErrorResponse
>;

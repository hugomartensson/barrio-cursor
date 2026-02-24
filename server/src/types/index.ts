import { Request } from 'express';

export interface User {
  id: string;
  email: string;
  name: string;
  profilePictureUrl: string | null;
  createdAt: Date;
}

export interface JwtPayload {
  userId: string;
  email: string;
}

export interface RequestWithId extends Request {
  id: string;
}

export interface AuthenticatedRequest extends Request {
  user: JwtPayload;
  id: string;
}

export interface ApiErrorResponse {
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

export interface ApiSuccessResponse<T> {
  data: T;
}

// PRD categories
export type Category = 'food' | 'drinks' | 'music' | 'art' | 'markets' | 'community';

export interface MediaItem {
  id: string;
  url: string;
  type: 'photo';
  order: number;
  thumbnailUrl?: string;
}

export interface Event {
  id: string;
  userId: string;
  title: string;
  description: string;
  category: Category;
  address: string;
  media: MediaItem[];
  latitude: number;
  longitude: number;
  startTime: Date;
  endTime: Date | null;
  createdAt: Date;
  saveCount: number;
  distance?: number;
}

export interface PaginationParams {
  limit: number;
  offset: number;
}

export interface GeoParams {
  latitude: number;
  longitude: number;
  radiusKm: number;
}

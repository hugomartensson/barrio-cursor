import { Request } from 'express';

// User type for JWT payload and database
export interface User {
  id: string;
  email: string;
  name: string;
  profilePictureUrl: string | null;
  createdAt: Date;
}

// JWT Payload
export interface JwtPayload {
  userId: string;
  email: string;
}

// Request with ID for logging
export interface RequestWithId extends Request {
  id: string;
}

// Authenticated request with user attached
export interface AuthenticatedRequest extends Request {
  user: JwtPayload;
  id: string;
}

// Standard API error response
export interface ApiErrorResponse {
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

// Standard API success response
export interface ApiSuccessResponse<T> {
  data: T;
}

// Category enum matching PRD
export type Category =
  | 'food_drink'
  | 'arts_culture'
  | 'music'
  | 'nightlife'
  | 'sports_outdoors'
  | 'community';

// Media item type
export interface MediaItem {
  id: string;
  url: string;
  type: 'photo' | 'video';
  order: number;
  thumbnailUrl?: string; // PRD: Thumbnail for videos
}

// Event type
export interface Event {
  id: string;
  userId: string;
  title: string;
  description: string;
  category: Category;
  address: string; // PRD: Address is primary, coordinates derived
  media: MediaItem[];
  latitude: number;
  longitude: number;
  startTime: Date;
  endTime: Date | null;
  createdAt: Date;
  interestedCount: number; // PRD: Replaces likesCount/goingCount
  distance?: number; // Calculated field
}

// Pagination params
export interface PaginationParams {
  limit: number;
  offset: number;
}

// Geolocation params
export interface GeoParams {
  latitude: number;
  longitude: number;
  radiusKm: number;
}

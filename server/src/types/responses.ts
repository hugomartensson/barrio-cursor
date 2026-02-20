/**
 * Shared response types for API endpoints
 * Consolidates duplicate type definitions across route files
 */

export interface EventMedia {
  id: string;
  url: string;
  type: string;
  order: number;
  thumbnailUrl?: string | null;
}

export interface EventData {
  id: string;
  title: string;
  description: string;
  category: string;
  address: string; // PRD: Address is primary
  latitude: number;
  longitude: number;
  startTime: string;
  endTime: string | null;
  createdAt: string;
  interestedCount: number; // PRD: Replaces likesCount/goingCount
  distance?: number;
  media: EventMedia[];
  user: { id: string; name: string };
}

export interface EventResponse {
  data: EventData;
}

export interface EventsListResponse {
  data: EventData[];
}

import type { EventData, EventMedia } from '../types/responses.js';

export interface NearbyEventRow {
  id: string;
  title: string;
  description: string;
  category: string;
  address: string;
  latitude: number;
  longitude: number;
  start_time: Date;
  end_time: Date | null;
  created_at: Date;
  save_count: number;
  distance: number;
  user_id: string;
  user_name: string;
}

export function formatEvent(
  event: {
    id: string;
    title: string;
    description: string;
    category: string;
    address: string;
    latitude: number;
    longitude: number;
    startTime: Date;
    endTime: Date | null;
    createdAt: Date;
    saveCount: number;
    media: {
      id: string;
      url: string;
      type: string;
      order: number;
      thumbnailUrl: string | null;
    }[];
    user: { id: string; name: string };
  },
  distance?: number
): EventData {
  return {
    id: event.id,
    title: event.title,
    description: event.description,
    category: event.category,
    address: event.address,
    latitude: event.latitude,
    longitude: event.longitude,
    startTime: event.startTime.toISOString(),
    endTime: event.endTime?.toISOString() ?? null,
    createdAt: event.createdAt.toISOString(),
    saveCount: event.saveCount,
    distance,
    media: event.media.map((m) => ({
      id: m.id,
      url: m.url,
      type: m.type,
      order: m.order,
      thumbnailUrl: m.thumbnailUrl ?? undefined,
    })),
    user: { id: event.user.id, name: event.user.name },
  };
}

export function formatNearbyEvent(
  e: NearbyEventRow,
  mediaMap: Record<string, EventMedia[]>
): EventData {
  return {
    id: e.id,
    title: e.title,
    description: e.description,
    category: e.category,
    address: e.address,
    latitude: e.latitude,
    longitude: e.longitude,
    startTime: e.start_time.toISOString(),
    endTime: e.end_time?.toISOString() ?? null,
    createdAt: e.created_at.toISOString(),
    saveCount: e.save_count,
    distance: Math.round(e.distance),
    media: (mediaMap[e.id] ?? []).map((m) => ({
      id: m.id,
      url: m.url,
      type: m.type,
      order: m.order,
      thumbnailUrl: m.thumbnailUrl ?? undefined,
    })),
    user: { id: e.user_id, name: e.user_name },
  };
}

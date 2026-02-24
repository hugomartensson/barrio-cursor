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
  address: string;
  latitude: number;
  longitude: number;
  startTime: string;
  endTime: string | null;
  createdAt: string;
  saveCount: number;
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

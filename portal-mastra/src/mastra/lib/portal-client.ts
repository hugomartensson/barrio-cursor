import type { Draft } from '../schemas/draft.js';

export interface PublishPayload {
  type: 'spot' | 'event';
  name: string;
  description: string;
  category: string;
  address: string;
  neighborhood: string | null;
  imageUrl: string;
  startTime?: string | null;
  endTime?: string | null;
  collectionId?: string | null;
}

interface LoginResponse {
  data?: { token?: string };
}

interface CreateResponse {
  data?: { id?: string };
}

const apiBase = (): string => {
  const u = process.env.PORTAL_API_URL?.replace(/\/$/, '');
  return u ?? 'http://localhost:3000/api';
};

const getCreds = (): { email: string; password: string } => {
  const email =
    process.env.PORTAL_EMAIL ?? process.env.PORTAL_TEAM_EMAIL ?? process.env.PORTAL_USER_EMAIL;
  const password =
    process.env.PORTAL_PASSWORD ??
    process.env.PORTAL_TEAM_PASSWORD ??
    process.env.PORTAL_USER_PASSWORD;
  if (!email || !password) {
    throw new Error('PORTAL_EMAIL and PORTAL_PASSWORD (or legacy PORTAL_TEAM_*) are required');
  }
  return { email, password };
};

export class PortalClient {
  private token: string | null = null;

  private async login(): Promise<string> {
    if (this.token) return this.token;
    const { email, password } = getCreds();
    const response = await fetch(`${apiBase()}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    if (!response.ok) {
      throw new Error(`Portal login failed: ${response.status}`);
    }
    const json = (await response.json()) as LoginResponse;
    const token = json.data?.token;
    if (!token) {
      throw new Error('Portal login returned no token');
    }
    this.token = token;
    return token;
  }

  private async authedFetch(path: string, init: RequestInit): Promise<Response> {
    const token = await this.login();
    const response = await fetch(`${apiBase()}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...(init.headers ?? {}),
      },
    });
    if (response.status === 401) {
      this.token = null;
      const refreshed = await this.login();
      return fetch(`${apiBase()}${path}`, {
        ...init,
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${refreshed}`,
          ...(init.headers ?? {}),
        },
      });
    }
    return response;
  }

  async publish(draft: PublishPayload): Promise<{ portalId: string; portalType: string }> {
    const { type, collectionId } = draft;

    if (type === 'spot') {
      const response = await this.authedFetch('/spots', {
        method: 'POST',
        body: JSON.stringify({
          name: draft.name,
          description: draft.description,
          category: draft.category,
          address: draft.address,
          neighborhood: draft.neighborhood ?? undefined,
          tags: [],
          image: { url: draft.imageUrl },
        }),
      });
      if (!response.ok) {
        const t = await response.text();
        throw new Error(`Spot publish failed: ${response.status} ${t}`);
      }
      const json = (await response.json()) as CreateResponse;
      const itemId = json.data?.id;
      if (!itemId) throw new Error('Spot publish returned no ID');
      if (collectionId) {
        await this.attachToCollection(collectionId, 'spot', itemId);
      }
      return { portalId: itemId, portalType: 'spot' };
    }

    const response = await this.authedFetch('/events', {
      method: 'POST',
      body: JSON.stringify({
        title: draft.name,
        description: draft.description,
        category: draft.category,
        address: draft.address,
        startTime: draft.startTime ?? new Date().toISOString(),
        endTime: draft.endTime ?? null,
        media: [{ url: draft.imageUrl, type: 'photo' }],
      }),
    });
    if (!response.ok) {
      const t = await response.text();
      throw new Error(`Event publish failed: ${response.status} ${t}`);
    }
    const json = (await response.json()) as CreateResponse;
    const itemId = json.data?.id;
    if (!itemId) throw new Error('Event publish returned no ID');
    if (collectionId) {
      await this.attachToCollection(collectionId, 'event', itemId);
    }
    return { portalId: itemId, portalType: 'event' };
  }

  async attachToCollection(
    collectionId: string,
    itemType: 'spot' | 'event',
    itemId: string,
  ): Promise<void> {
    const response = await this.authedFetch(`/collections/${collectionId}/items`, {
      method: 'POST',
      body: JSON.stringify({ itemType, itemId }),
    });
    if (!response.ok) {
      throw new Error(`Collection attach failed: ${response.status}`);
    }
  }

  async createCollection(name: string, description?: string): Promise<string> {
    const response = await this.authedFetch('/collections', {
      method: 'POST',
      body: JSON.stringify({
        name,
        description,
        visibility: 'public',
      }),
    });
    if (!response.ok) {
      throw new Error(`Collection create failed: ${response.status}`);
    }
    const json = (await response.json()) as CreateResponse;
    const id = json.data?.id;
    if (!id) throw new Error('Collection create returned no ID');
    return id;
  }
}

const singleton = new PortalClient();

export function getPortalClient(): PortalClient {
  return singleton;
}

/** Map workflow draft fields into publish payload.
 *  barrio-api's createSpotSchema requires non-empty name, description, address
 *  (all min(1)), so we must provide sensible fallbacks for nullable draft fields. */
export function draftToPublishPayload(
  d: Draft & { collectionId?: string | null },
  supabaseImageUrl: string,
): PublishPayload {
  return {
    type: d.type,
    name: d.name?.trim() || 'Unnamed',
    description: d.description?.trim() || d.name?.trim() || 'No description',
    category: d.category ?? 'community',
    address: d.address?.trim() || 'Unknown address',
    neighborhood: d.neighborhood,
    imageUrl: supabaseImageUrl,
    startTime: d.type === 'event' ? d.startTime : undefined,
    endTime: d.type === 'event' ? d.endTime : undefined,
    collectionId: d.collectionId ?? null,
  };
}

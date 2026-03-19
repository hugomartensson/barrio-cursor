/* istanbul ignore file */
import type { Draft, ItemType } from '@prisma/client';
import { config } from '../../config/index.js';

interface PublishLikeDraft {
  itemType: ItemType | null;
  name: string | null;
  description: string | null;
  category: string | null;
  address: string | null;
  neighborhood: string | null;
  tags: string[];
  imageUrl: string | null;
  startTime: Date | string | null;
  endTime: Date | string | null;
  collectionId: string | null;
}

interface LoginResponse {
  data?: { token?: string };
}

interface CreateResponse {
  data?: { id?: string };
}

class Publisher {
  private token: string | null = null;

  private get apiBaseUrl(): string {
    return config.PORTAL_API_URL ?? 'http://localhost:3000/api';
  }

  private async login(): Promise<string> {
    if (this.token) {
      return this.token;
    }
    if (!config.PORTAL_TEAM_EMAIL || !config.PORTAL_TEAM_PASSWORD) {
      throw new Error('Missing portal team credentials');
    }

    const response = await fetch(`${this.apiBaseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: config.PORTAL_TEAM_EMAIL,
        password: config.PORTAL_TEAM_PASSWORD,
      }),
    });

    if (!response.ok) {
      throw new Error(`Login failed: ${response.status}`);
    }

    const json = (await response.json()) as LoginResponse;
    const token = json.data?.token;
    if (!token) {
      throw new Error('Login returned no token');
    }
    this.token = token;
    return token;
  }

  private async authedFetch(path: string, init: RequestInit): Promise<Response> {
    const token = await this.login();
    const response = await fetch(`${this.apiBaseUrl}${path}`, {
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
      return fetch(`${this.apiBaseUrl}${path}`, {
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

  async rehostImage(externalUrl: string): Promise<string> {
    if (externalUrl.includes('supabase.co/storage')) {
      return externalUrl;
    }
    const imageRes = await fetch(externalUrl, { signal: AbortSignal.timeout(10000) });
    if (!imageRes.ok) {
      return externalUrl;
    }
    const contentType = imageRes.headers.get('content-type') ?? 'image/jpeg';
    const buffer = Buffer.from(await imageRes.arrayBuffer());
    const base64 = buffer.toString('base64');

    const uploadRes = await this.authedFetch('/upload', {
      method: 'POST',
      body: JSON.stringify({ image: base64, contentType }),
    });
    if (!uploadRes.ok) {
      return externalUrl;
    }
    const json = (await uploadRes.json()) as { data?: { url?: string } };
    return json.data?.url ?? externalUrl;
  }

  async publishDraft(draft: PublishLikeDraft | Draft): Promise<string> {
    if (
      !draft.itemType ||
      !draft.name ||
      !draft.description ||
      !draft.category ||
      !draft.address
    ) {
      throw new Error('Draft missing required publish fields');
    }

    const imageUrl = draft.imageUrl ? await this.rehostImage(draft.imageUrl) : null;

    if (draft.itemType === 'spot') {
      const response = await this.authedFetch('/spots', {
        method: 'POST',
        body: JSON.stringify({
          name: draft.name,
          description: draft.description,
          category: draft.category,
          address: draft.address,
          neighborhood: draft.neighborhood,
          tags: draft.tags ?? [],
          image: { url: imageUrl },
        }),
      });
      if (!response.ok) {
        throw new Error(`Spot publish failed: ${response.status}`);
      }
      const json = (await response.json()) as CreateResponse;
      const itemId = json.data?.id;
      if (!itemId) {
        throw new Error('Spot publish returned no ID');
      }
      if (draft.collectionId) {
        await this.attachToCollection(draft.collectionId, 'spot', itemId);
      }
      return itemId;
    }

    const response = await this.authedFetch('/events', {
      method: 'POST',
      body: JSON.stringify({
        title: draft.name,
        description: draft.description,
        category: draft.category,
        address: draft.address,
        startTime: new Date(draft.startTime ?? Date.now()).toISOString(),
        endTime: draft.endTime ? new Date(draft.endTime).toISOString() : null,
        media: imageUrl ? [{ url: imageUrl, type: 'photo' }] : [],
      }),
    });
    if (!response.ok) {
      throw new Error(`Event publish failed: ${response.status}`);
    }
    const json = (await response.json()) as CreateResponse;
    const itemId = json.data?.id;
    if (!itemId) {
      throw new Error('Event publish returned no ID');
    }
    if (draft.collectionId) {
      await this.attachToCollection(draft.collectionId, 'event', itemId);
    }
    return itemId;
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
    if (!id) {
      throw new Error('Collection create returned no ID');
    }
    return id;
  }

  async attachToCollection(
    collectionId: string,
    itemType: ItemType,
    itemId: string
  ): Promise<void> {
    const response = await this.authedFetch(`/collections/${collectionId}/items`, {
      method: 'POST',
      body: JSON.stringify({ itemType, itemId }),
    });
    if (!response.ok) {
      throw new Error(`Collection attach failed: ${response.status}`);
    }
  }
}

export const publisher = new Publisher();

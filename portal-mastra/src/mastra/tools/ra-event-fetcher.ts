import { createTool } from '@mastra/core/tools';
import { z } from 'zod';
import { BROWSER_USER_AGENT } from './constants.js';

const RA_GRAPHQL = 'https://ra.co/graphql';

const EVENT_QUERY = `
  query GET_EVENT($id: ID!) {
    event(id: $id) {
      id
      title
      content
      date
      startTime
      endTime
      images { filename }
      venue {
        name
        address
        area { name }
        location { lat lng }
      }
      artists { name }
      contentUrl
    }
  }
`;

export const raEventFetcher = createTool({
  id: 'ra-event-fetcher',
  description:
    'Fetches a Resident Advisor (ra.co) event page via the RA GraphQL API. Returns event title, description, venue name/address/coordinates, start/end times, and image URL.',
  inputSchema: z.object({
    url: z.string().url().describe('Full ra.co/events/... URL'),
  }),
  outputSchema: z.object({
    name: z.string().nullable(),
    description: z.string().nullable(),
    imageUrl: z.string().nullable(),
    startTime: z.string().nullable(),
    endTime: z.string().nullable(),
    venueName: z.string().nullable(),
    address: z.string().nullable(),
    neighborhood: z.string().nullable(),
    latitude: z.number().nullable(),
    longitude: z.number().nullable(),
    artists: z.array(z.string()),
    error: z.string().nullable(),
  }),
  execute: async (inputData) => {
    const { url } = inputData;
    const empty = {
      name: null,
      description: null,
      imageUrl: null,
      startTime: null,
      endTime: null,
      venueName: null,
      address: null,
      neighborhood: null,
      latitude: null,
      longitude: null,
      artists: [] as string[],
      error: null as string | null,
    };

    // Extract numeric event ID from URL (e.g. ra.co/events/2392108)
    const match = url.match(/ra\.co\/events\/(\d+)/i);
    if (!match) {
      return { ...empty, error: 'Could not extract event ID from URL' };
    }
    const id = match[1];

    try {
      const res = await fetch(RA_GRAPHQL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': BROWSER_USER_AGENT,
          Referer: 'https://ra.co/',
          Origin: 'https://ra.co',
        },
        body: JSON.stringify({ query: EVENT_QUERY, variables: { id } }),
        signal: AbortSignal.timeout(15_000),
      });

      if (!res.ok) {
        return { ...empty, error: `RA GraphQL HTTP ${res.status}` };
      }

      const json = (await res.json()) as {
        data?: {
          event?: {
            title?: string;
            content?: string;
            date?: string;
            startTime?: string;
            endTime?: string;
            images?: Array<{ filename?: string }>;
            venue?: {
              name?: string;
              address?: string;
              area?: { name?: string };
              location?: { lat?: number; lng?: number };
            };
            artists?: Array<{ name?: string }>;
          } | null;
        };
        errors?: Array<{ message: string }>;
      };

      if (json.errors?.length) {
        return { ...empty, error: json.errors.map((e) => e.message).join('; ') };
      }

      const ev = json.data?.event;
      if (!ev) {
        return { ...empty, error: 'Event not found in RA GraphQL response' };
      }

      // Build image URL from first image filename
      const filename = ev.images?.[0]?.filename;
      const imageUrl = filename ? `https://ra.co/images/events/${filename}` : null;

      return {
        name: ev.title ?? null,
        description: ev.content ? ev.content.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 1500) : null,
        imageUrl,
        startTime: ev.startTime ?? ev.date ?? null,
        endTime: ev.endTime ?? null,
        venueName: ev.venue?.name ?? null,
        address: ev.venue?.address ?? null,
        neighborhood: ev.venue?.area?.name ?? null,
        latitude: ev.venue?.location?.lat ?? null,
        longitude: ev.venue?.location?.lng ?? null,
        artists: (ev.artists ?? []).map((a) => a.name ?? '').filter(Boolean),
        error: null,
      };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { ...empty, error: `RA fetch failed: ${msg}` };
    }
  },
});

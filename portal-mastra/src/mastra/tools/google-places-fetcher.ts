import { createTool } from '@mastra/core/tools';
import { z } from 'zod';
import { GOOGLE_TYPE_TO_CATEGORY } from './constants.js';

const placesKey = (): string | undefined =>
  process.env.GOOGLE_PLACES_API_KEY ?? process.env.GOOGLE_MAPS_API_KEY;

const resolveUrl = async (url: string): Promise<string> => {
  const response = await fetch(url, {
    redirect: 'follow',
    signal: AbortSignal.timeout(10_000),
  });
  return response.url;
};

const extractQueryFromMapsUrl = (resolvedUrl: string): string => {
  try {
    const parsed = new URL(resolvedUrl);
    const q = parsed.searchParams.get('q');
    if (q) return q;
    const pathMatch = parsed.pathname.match(/\/place\/([^/]+)/i);
    return decodeURIComponent(pathMatch?.[1] ?? '').replace(/\+/g, ' ');
  } catch {
    return '';
  }
};

const mapTypesToCategory = (types: string[] | undefined): string | null => {
  if (!types?.length) return null;
  for (const t of types) {
    const c = GOOGLE_TYPE_TO_CATEGORY[t];
    if (c) return c;
  }
  return null;
};

const placePhotoUrl = (photoReference: string, key: string): string => {
  const u = new URL('https://maps.googleapis.com/maps/api/place/photo');
  u.searchParams.set('maxwidth', '1200');
  u.searchParams.set('photo_reference', photoReference);
  u.searchParams.set('key', key);
  return u.toString();
};

type PlaceResult = {
  place_id?: string;
  name?: string;
  formatted_address?: string;
  website?: string;
  types?: string[];
  photos?: { photo_reference?: string }[];
};

export const googlePlacesFetcher = createTool({
  id: 'google-places-fetcher',
  description: `Looks up a venue on Google Places. Pass either a Google Maps URL (short or long) OR venueName + city (e.g. Barcelona).
Returns name, address, category (Portal enum), website, photo URLs, placeId. Use to cross-check venue data.`,
  inputSchema: z.object({
    mapsUrl: z.string().optional(),
    venueName: z.string().optional(),
    city: z.string().optional(),
  }),
  outputSchema: z.object({
    name: z.string().nullable(),
    address: z.string().nullable(),
    category: z.string().nullable(),
    website: z.string().nullable(),
    photoUrls: z.array(z.string()),
    placeId: z.string().nullable(),
  }),
  execute: async (inputData) => {
    const key = placesKey();
    if (!key) {
      return {
        name: null,
        address: null,
        category: null,
        website: null,
        photoUrls: [],
        placeId: null,
      };
    }

    let place: PlaceResult | undefined;

    if (inputData.mapsUrl?.trim()) {
      const resolved = await resolveUrl(inputData.mapsUrl.trim());
      const query = extractQueryFromMapsUrl(resolved);
      if (query) {
        const apiUrl = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
        apiUrl.searchParams.set('query', query);
        apiUrl.searchParams.set('key', key);
        const response = await fetch(apiUrl.toString(), { signal: AbortSignal.timeout(10_000) });
        const payload = (await response.json()) as { results?: PlaceResult[] };
        place = payload.results?.[0];
      }
    } else if (inputData.venueName?.trim()) {
      const city = inputData.city?.trim() ?? 'Barcelona';
      const apiUrl = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
      apiUrl.searchParams.set('query', `${inputData.venueName.trim()} ${city}`);
      apiUrl.searchParams.set('key', key);
      const response = await fetch(apiUrl.toString(), { signal: AbortSignal.timeout(10_000) });
      const payload = (await response.json()) as { results?: PlaceResult[] };
      place = payload.results?.[0];
    }

    if (!place?.place_id) {
      return {
        name: place?.name ?? null,
        address: place?.formatted_address ?? null,
        category: mapTypesToCategory(place?.types),
        website: place?.website ?? null,
        photoUrls: [],
        placeId: null,
      };
    }

    const detailsUrl = new URL('https://maps.googleapis.com/maps/api/place/details/json');
    detailsUrl.searchParams.set('place_id', place.place_id);
    detailsUrl.searchParams.set(
      'fields',
      'name,formatted_address,website,types,photos,place_id',
    );
    detailsUrl.searchParams.set('key', key);

    const detailsRes = await fetch(detailsUrl.toString(), { signal: AbortSignal.timeout(10_000) });
    const detailsJson = (await detailsRes.json()) as { result?: PlaceResult };
    const d = detailsJson.result ?? place;

    const photoUrls =
      d.photos
        ?.map((p) => (p.photo_reference ? placePhotoUrl(p.photo_reference, key) : null))
        .filter((x): x is string => Boolean(x)) ?? [];

    return {
      name: d.name ?? null,
      address: d.formatted_address ?? null,
      category: mapTypesToCategory(d.types),
      website: d.website ?? null,
      photoUrls,
      placeId: d.place_id ?? place.place_id ?? null,
    };
  },
});

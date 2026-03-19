/* istanbul ignore file */
import { Category } from '@prisma/client';
import { config } from '../../../config/index.js';
import { fetchWebsite } from './website.js';
import type { FetcherResult } from '../types.js';

const typeCategoryMap: Record<string, Category> = {
  restaurant: Category.food,
  cafe: Category.food,
  bar: Category.drinks,
  night_club: Category.drinks,
  tourist_attraction: Category.community,
  museum: Category.art,
  art_gallery: Category.art,
  shopping_mall: Category.markets,
  store: Category.markets,
  park: Category.community,
};

const resolveUrl = async (url: string): Promise<string> => {
  const response = await fetch(url, {
    redirect: 'follow',
    signal: AbortSignal.timeout(10000),
  });
  return response.url;
};

const extractQuery = (resolvedUrl: string): string => {
  try {
    const parsed = new URL(resolvedUrl);
    const q = parsed.searchParams.get('q');
    if (q) {
      return q;
    }
    const pathMatch = parsed.pathname.match(/\/place\/([^/]+)/i);
    return decodeURIComponent(pathMatch?.[1] ?? '').replace(/\+/g, ' ');
  } catch {
    return '';
  }
};

export const fetchGooglePlace = async (url: string): Promise<FetcherResult> => {
  if (!config.GOOGLE_MAPS_API_KEY) {
    return {};
  }
  const resolved = await resolveUrl(url);
  const query = extractQuery(resolved);
  if (!query) {
    return {};
  }

  const apiUrl = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
  apiUrl.searchParams.set('query', query);
  apiUrl.searchParams.set('key', config.GOOGLE_MAPS_API_KEY);

  const response = await fetch(apiUrl.toString(), { signal: AbortSignal.timeout(10000) });
  if (!response.ok) {
    return {};
  }
  const payload = (await response.json()) as {
    results?: Array<{
      name?: string;
      formatted_address?: string;
      website?: string;
      types?: string[];
    }>;
  };
  const place = payload.results?.[0];
  if (!place) {
    return {};
  }

  const mappedCategory = (place.types ?? [])
    .map((type) => typeCategoryMap[type])
    .find(Boolean);

  const websiteData = place.website ? await fetchWebsite(place.website) : {};
  return {
    name: place.name ?? websiteData.name ?? null,
    address: place.formatted_address ?? null,
    category: mappedCategory ?? null,
    imageUrl: websiteData.imageUrl ?? null,
    description: websiteData.description ?? null,
    rawText: websiteData.rawText,
  };
};

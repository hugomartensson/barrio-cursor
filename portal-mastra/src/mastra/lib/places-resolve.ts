/**
 * Resolve lat/lng for a draft using Google Places (text search + details) with Geocoding API fallback.
 * Mirrors patterns from google-places-fetcher; shared env: GOOGLE_PLACES_API_KEY or GOOGLE_MAPS_API_KEY.
 */

const apiKey = (): string | undefined =>
  process.env.GOOGLE_PLACES_API_KEY ?? process.env.GOOGLE_MAPS_API_KEY;

export type PlaceResolveResult =
  | {
      ok: true;
      latitude: number;
      longitude: number;
      formattedAddress: string;
      placeId: string | null;
    }
  | { ok: false; reason: string };

async function geocodeFallback(address: string): Promise<PlaceResolveResult> {
  const key = apiKey();
  if (!key) {
    return { ok: false, reason: 'No Google Maps API key configured' };
  }
  const params = new URLSearchParams({ address, key });
  const url = `https://maps.googleapis.com/maps/api/geocode/json?${params.toString()}`;
  const response = await fetch(url, { signal: AbortSignal.timeout(12_000) });
  if (!response.ok) {
    return { ok: false, reason: `Geocoding HTTP ${response.status}` };
  }
  const data = (await response.json()) as {
    status: string;
    results: Array<{
      formatted_address: string;
      geometry: { location: { lat: number; lng: number } };
      place_id?: string;
    }>;
    error_message?: string;
  };
  if (data.status === 'ZERO_RESULTS' || !data.results?.[0]) {
    return { ok: false, reason: 'No geocoding results for this address' };
  }
  if (data.status !== 'OK') {
    return {
      ok: false,
      reason: `Geocoding: ${data.status} ${data.error_message ?? ''}`.trim(),
    };
  }
  const r = data.results[0];
  return {
    ok: true,
    latitude: r.geometry.location.lat,
    longitude: r.geometry.location.lng,
    formattedAddress: r.formatted_address,
    placeId: r.place_id ?? null,
  };
}

/**
 * Best-effort resolve coordinates for ingest publish (skip second geocode on barrio-api).
 */
export async function resolvePlaceCoordinates(input: {
  address: string;
  name?: string | null;
  neighborhood?: string | null;
}): Promise<PlaceResolveResult> {
  const addr = input.address?.trim();
  if (!addr) {
    return { ok: false, reason: 'Address is empty' };
  }

  const key = apiKey();
  if (!key) {
    return geocodeFallback(addr);
  }

  // Try with full query first (name + address), then fall back to name-only so a wrong
  // address extracted by the AI doesn't poison the search.
  const name = input.name?.trim();
  const queries = [
    [name, addr, input.neighborhood?.trim()].filter(Boolean).join(', '),
  ];
  if (name) {
    // Try name-only without hardcoded city — the address already contains the city
    queries.push(name);
  }

  let placeId: string | undefined;
  try {
    for (const query of queries) {
      const searchUrl = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
      searchUrl.searchParams.set('query', query);
      searchUrl.searchParams.set('key', key);
      const searchRes = await fetch(searchUrl.toString(), { signal: AbortSignal.timeout(12_000) });
      const searchJson = (await searchRes.json()) as {
        status: string;
        results?: Array<{ place_id?: string }>;
      };
      placeId = searchJson.results?.[0]?.place_id;
      if (placeId) break;
    }

    if (placeId) {
      const detailsUrl = new URL('https://maps.googleapis.com/maps/api/place/details/json');
      detailsUrl.searchParams.set('place_id', placeId);
      detailsUrl.searchParams.set(
        'fields',
        'geometry,formatted_address,place_id,name',
      );
      detailsUrl.searchParams.set('key', key);
      const detailsRes = await fetch(detailsUrl.toString(), { signal: AbortSignal.timeout(12_000) });
      const detailsJson = (await detailsRes.json()) as {
        result?: {
          geometry?: { location: { lat: number; lng: number } };
          formatted_address?: string;
          place_id?: string;
        };
      };
      const loc = detailsJson.result?.geometry?.location;
      if (loc) {
        return {
          ok: true,
          latitude: loc.lat,
          longitude: loc.lng,
          formattedAddress:
            detailsJson.result?.formatted_address ?? addr,
          placeId: detailsJson.result?.place_id ?? placeId,
        };
      }
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, reason: `Places lookup failed: ${msg}` };
  }

  return geocodeFallback(addr);
}

import { config } from '../config/index.js';
import { logger } from './logger.js';

export interface GeocodingResult {
  latitude: number;
  longitude: number;
  formattedAddress: string;
}

/**
 * Geocode an address string to coordinates using Google Maps Geocoding API.
 * Returns the first result's lat/lng and formatted address.
 */
export async function geocodeAddress(address: string): Promise<GeocodingResult> {
  const apiKey = config.GOOGLE_MAPS_API_KEY ?? config.GOOGLE_PLACES_API_KEY;
  if (!apiKey) {
    throw new Error('GOOGLE_MAPS_API_KEY is not configured');
  }

  const params = new URLSearchParams({
    address,
    key: apiKey,
  });

  const url = `https://maps.googleapis.com/maps/api/geocode/json?${params.toString()}`;

  logger.info({ address }, 'Geocoding address');

  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Geocoding API returned ${response.status}`);
  }

  const data = (await response.json()) as {
    status: string;
    results: Array<{
      formatted_address: string;
      geometry: {
        location: { lat: number; lng: number };
      };
    }>;
    error_message?: string;
  };

  if (data.status === 'ZERO_RESULTS') {
    throw new Error(`No geocoding results for address: "${address}"`);
  }

  if (data.status !== 'OK') {
    throw new Error(
      `Geocoding API error: ${data.status} - ${data.error_message ?? 'unknown'}`
    );
  }

  const result = data.results[0];
  if (!result) {
    throw new Error('Geocoding returned empty results');
  }

  const geocoded: GeocodingResult = {
    latitude: result.geometry.location.lat,
    longitude: result.geometry.location.lng,
    formattedAddress: result.formatted_address,
  };

  logger.info(
    {
      address,
      formattedAddress: geocoded.formattedAddress,
      lat: geocoded.latitude,
      lng: geocoded.longitude,
    },
    'Address geocoded successfully'
  );

  return geocoded;
}

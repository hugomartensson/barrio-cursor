export interface Neighborhood {
  slug: string;
  name: string;
  city: 'Stockholm' | 'Barcelona';
  lat: number;
  lng: number;
}

export const NEIGHBORHOODS: Neighborhood[] = [
  // Stockholm
  { slug: 'sodermalm', name: 'Södermalm', city: 'Stockholm', lat: 59.3145, lng: 18.0702 },
  { slug: 'ostermalm', name: 'Östermalm', city: 'Stockholm', lat: 59.34, lng: 18.085 },
  { slug: 'vasastan', name: 'Vasastan', city: 'Stockholm', lat: 59.343, lng: 18.05 },
  {
    slug: 'gamla-stan',
    name: 'Gamla Stan',
    city: 'Stockholm',
    lat: 59.325,
    lng: 18.0711,
  },
  {
    slug: 'kungsholmen',
    name: 'Kungsholmen',
    city: 'Stockholm',
    lat: 59.3327,
    lng: 18.0214,
  },
  { slug: 'norrmalm', name: 'Norrmalm', city: 'Stockholm', lat: 59.336, lng: 18.062 },
  { slug: 'djurgarden', name: 'Djurgården', city: 'Stockholm', lat: 59.327, lng: 18.11 },
  { slug: 'hornstull', name: 'Hornstull', city: 'Stockholm', lat: 59.3173, lng: 18.0388 },
  { slug: 'nacka', name: 'Nacka', city: 'Stockholm', lat: 59.3135, lng: 18.163 },
  { slug: 'lidingo', name: 'Lidingö', city: 'Stockholm', lat: 59.366, lng: 18.152 },
  {
    slug: 'hammarby-sjostad',
    name: 'Hammarby Sjöstad',
    city: 'Stockholm',
    lat: 59.3046,
    lng: 18.0895,
  },
  {
    slug: 'liljeholmen',
    name: 'Liljeholmen',
    city: 'Stockholm',
    lat: 59.308,
    lng: 18.0195,
  },

  // Barcelona
  { slug: 'eixample', name: 'Eixample', city: 'Barcelona', lat: 41.3916, lng: 2.162 },
  { slug: 'gracia', name: 'Gràcia', city: 'Barcelona', lat: 41.403, lng: 2.156 },
  { slug: 'born', name: 'El Born', city: 'Barcelona', lat: 41.3854, lng: 2.182 },
  { slug: 'gothic', name: 'Barri Gòtic', city: 'Barcelona', lat: 41.3826, lng: 2.1766 },
  { slug: 'raval', name: 'El Raval', city: 'Barcelona', lat: 41.381, lng: 2.168 },
  { slug: 'poblenou', name: 'Poblenou', city: 'Barcelona', lat: 41.402, lng: 2.2 },
  { slug: 'poble-sec', name: 'Poble-sec', city: 'Barcelona', lat: 41.3745, lng: 2.161 },
  {
    slug: 'sant-antoni',
    name: 'Sant Antoni',
    city: 'Barcelona',
    lat: 41.3805,
    lng: 2.1635,
  },
  {
    slug: 'barceloneta',
    name: 'Barceloneta',
    city: 'Barcelona',
    lat: 41.3806,
    lng: 2.189,
  },
  {
    slug: 'sarria-sant-gervasi',
    name: 'Sarrià-Sant Gervasi',
    city: 'Barcelona',
    lat: 41.4,
    lng: 2.136,
  },
  {
    slug: 'sants-montjuic',
    name: 'Sants-Montjuïc',
    city: 'Barcelona',
    lat: 41.377,
    lng: 2.144,
  },
  { slug: 'les-corts', name: 'Les Corts', city: 'Barcelona', lat: 41.388, lng: 2.139 },
];

/**
 * Filter neighborhoods by prefix match (case-insensitive, diacritic-tolerant).
 */
export function searchNeighborhoods(query: string, limit = 3): Neighborhood[] {
  if (!query || query.length < 2) {
    return [];
  }

  const normalized = normalizeForSearch(query);
  return NEIGHBORHOODS.filter(
    (n) =>
      normalizeForSearch(n.name).includes(normalized) ||
      normalizeForSearch(n.slug).includes(normalized) ||
      normalizeForSearch(n.city).startsWith(normalized)
  ).slice(0, limit);
}

function normalizeForSearch(s: string): string {
  return s
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

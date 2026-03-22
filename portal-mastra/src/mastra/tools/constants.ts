export const BROWSER_USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

/** Maps Google Places types to Portal categories */
export const GOOGLE_TYPE_TO_CATEGORY: Record<string, string> = {
  restaurant: 'food',
  cafe: 'food',
  bakery: 'food',
  meal_takeaway: 'food',
  bar: 'drinks',
  night_club: 'drinks',
  art_gallery: 'art',
  museum: 'art',
  market: 'markets',
  grocery_or_supermarket: 'markets',
  community_center: 'community',
  church: 'community',
  tourist_attraction: 'community',
  park: 'community',
};

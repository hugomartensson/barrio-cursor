/* istanbul ignore file */
export type SourceType = 'google_maps' | 'instagram_post' | 'website' | 'unknown';

export const detectSourceType = (value: string): SourceType => {
  const input = value.toLowerCase();
  if (input.includes('maps.google.') || input.includes('maps.app.goo.gl')) {
    return 'google_maps';
  }
  if (input.includes('instagram.com')) {
    return 'instagram_post';
  }
  if (input.startsWith('http://') || input.startsWith('https://')) {
    return 'website';
  }
  return 'unknown';
};

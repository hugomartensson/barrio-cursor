import { prisma } from './prisma.js';

const MIN_LENGTH = 2;
const MAX_LENGTH = 30;

/**
 * Derive a URL-safe handle from a display name.
 * Uses only lowercase letters, digits, and single hyphens; 2–30 chars.
 */
function slugify(name: string): string {
  const trimmed = name.trim().toLowerCase();
  const replaced = trimmed
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
  return replaced.slice(0, MAX_LENGTH);
}

/**
 * Generate initials from display name (e.g. "Jane Doe" → "JD"). Max 2 chars.
 */
export function generateInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) {
    return '';
  }
  if (parts.length === 1) {
    return parts[0]!.slice(0, 2).toUpperCase();
  }
  return (parts[0]!.charAt(0) + parts[parts.length - 1]!.charAt(0)).toUpperCase();
}

/**
 * Find a unique handle for the given display name.
 * Returns base handle or base-2, base-3, ... as needed.
 */
export async function generateHandle(name: string): Promise<string> {
  let base = slugify(name);
  if (base.length < MIN_LENGTH) {
    base = 'user-' + Math.random().toString(36).slice(2, 8);
  }
  let candidate = base;
  let suffix = 1;
  // eslint-disable-next-line no-constant-condition -- intentional loop until unique handle found
  while (true) {
    const existing = await prisma.user.findUnique({
      where: { handle: candidate },
      select: { id: true },
    });
    if (!existing) {
      return candidate;
    }
    suffix += 1;
    candidate = `${base}-${suffix}`;
    if (candidate.length > MAX_LENGTH) {
      candidate = base.slice(0, MAX_LENGTH - String(suffix).length - 1) + '-' + suffix;
    }
  }
}

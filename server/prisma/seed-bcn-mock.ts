/**
 * BCN Mock Data Seeder
 *
 * Creates 50 Barcelona-based users (1@1.com…50@1.com / Password123):
 *   - 10 pros  (city-guide influencers + 3 org accounts)
 *   - 20 amateurs (city enthusiasts)
 *   - 20 active followers (engagers)
 *
 * Pulls ~32 Unsplash queries into an in-memory pool (≤47 requests total),
 * uploads photos to Supabase Storage, and populates:
 *   ~225 spots · ~150 events · ~170 collections · ~120 plans · thousands of saves/follows
 *
 * Usage:
 *   UNSPLASH_ACCESS_KEY=xxx npm run seed:bcn
 */

import 'dotenv/config';
import { PrismaClient, Category, CollectionVisibility } from '@prisma/client';
import { createClient } from '@supabase/supabase-js';
import { randomUUID } from 'crypto';
import { faker } from '@faker-js/faker';

// ---------------------------------------------------------------------------
// Clients
// ---------------------------------------------------------------------------

const prisma = new PrismaClient();

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

const STORAGE_BUCKET = process.env.SUPABASE_STORAGE_BUCKET ?? 'media';
const UNSPLASH_KEY = process.env.UNSPLASH_ACCESS_KEY ?? '';
const SEED_FOLDER = 'seed-bcn';
const PASSWORD = 'Password123';
const TODAY = new Date('2026-04-19T12:00:00Z');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function daysFrom(base: Date, d: number): Date {
  return new Date(base.getTime() + d * 86_400_000);
}

function hoursFrom(base: Date, h: number): Date {
  return new Date(base.getTime() + h * 3_600_000);
}

/** Simple deterministic PRNG from a string key (mulberry32). */
function seededRand(key: string): number {
  let h = 0x12345678;
  for (let i = 0; i < key.length; i++) {
    h = Math.imul(h ^ key.charCodeAt(i), 0x9e3779b9);
    h ^= h >>> 16;
  }
  h = Math.imul(h ^ (h >>> 16), 0x85ebca6b);
  h = Math.imul(h ^ (h >>> 13), 0xc2b2ae35);
  h ^= h >>> 16;
  return (h >>> 0) / 0xffffffff;
}

function pick<T>(arr: T[], key?: string): T {
  const idx = key
    ? Math.floor(seededRand(key) * arr.length)
    : Math.floor(Math.random() * arr.length);
  return arr[idx % arr.length];
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function initials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .map((w) => w[0].toUpperCase())
    .slice(0, 2)
    .join('');
}

// ---------------------------------------------------------------------------
// Unsplash
// ---------------------------------------------------------------------------

interface UnsplashPhoto {
  id: string;
  urls: { regular: string; small: string };
  links: { download_location: string };
}

type PoolKey =
  | 'food-interior' | 'food-plated' | 'food-tapas' | 'food-streetfood'
  | 'drinks-bar' | 'drinks-cocktail' | 'drinks-wine'
  | 'cafe-interior' | 'cafe-coffee'
  | 'music-venue' | 'music-club' | 'music-jazz'
  | 'art-gallery' | 'art-museum' | 'art-streetart'
  | 'markets-produce' | 'markets-flea'
  | 'community-park' | 'community-yoga' | 'community-cowork'
  | 'event-running' | 'event-meetup' | 'event-winetasting' | 'event-outdoor' | 'event-bartender'
  | 'profile-woman' | 'profile-man' | 'profile-casual'
  | 'org-magazine' | 'org-skyline' | 'org-loft';

const POOL_QUERIES: Record<PoolKey, string> = {
  'food-interior':     'restaurant interior',
  'food-plated':       'restaurant food plated dish',
  'food-tapas':        'tapas bar spanish',
  'food-streetfood':   'street food market stall',
  'drinks-bar':        'bar interior',
  'drinks-cocktail':   'cocktail drink glass',
  'drinks-wine':       'wine bar',
  'cafe-interior':     'coffee shop interior',
  'cafe-coffee':       'coffee latte art cup',
  'music-venue':       'music venue stage',
  'music-club':        'nightclub crowd',
  'music-jazz':        'jazz club live band',
  'art-gallery':       'art gallery white wall',
  'art-museum':        'museum exhibition',
  'art-streetart':     'street art mural',
  'markets-produce':   'farmers market produce',
  'markets-flea':      'flea market vintage',
  'community-park':    'city park bench',
  'community-yoga':    'yoga outdoor class',
  'community-cowork':  'coworking space',
  'event-running':     'running group city',
  'event-meetup':      'group friends restaurant',
  'event-winetasting': 'wine tasting dinner',
  'event-outdoor':     'outdoor cinema night',
  'event-bartender':   'bartender making cocktail',
  'profile-woman':     'portrait woman professional',
  'profile-man':       'portrait man professional',
  'profile-casual':    'portrait smiling casual',
  'org-magazine':      'magazine editorial desk',
  'org-skyline':       'barcelona skyline cityscape',
  'org-loft':          'industrial loft creative studio',
};

const photoPool: Partial<Record<PoolKey, UnsplashPhoto[]>> = {};
const usedDownloadUrls: string[] = [];

async function fetchPool(key: PoolKey): Promise<void> {
  if (!UNSPLASH_KEY) {
    console.warn(`⚠️  UNSPLASH_ACCESS_KEY not set — skipping pool "${key}"`);
    photoPool[key] = [];
    return;
  }
  try {
    const query = encodeURIComponent(POOL_QUERIES[key]);
    const url = `https://api.unsplash.com/search/photos?query=${query}&per_page=30&orientation=landscape`;
    const r = await fetch(url, { headers: { Authorization: `Client-ID ${UNSPLASH_KEY}` } });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    const json = (await r.json()) as { results: UnsplashPhoto[] };
    photoPool[key] = json.results ?? [];
    console.log(`   ✓ pool "${key}" — ${photoPool[key]!.length} photos`);
  } catch (e) {
    console.warn(`   ⚠️  pool "${key}" failed: ${e}`);
    photoPool[key] = [];
  }
}

function pickPhoto(key: PoolKey, seedStr?: string): UnsplashPhoto | null {
  const pool = photoPool[key];
  if (!pool || pool.length === 0) return null;
  return pick(pool, seedStr);
}

// ---------------------------------------------------------------------------
// Storage upload
// ---------------------------------------------------------------------------

async function uploadPhoto(sourceUrl: string, userId: string): Promise<string> {
  try {
    const res = await fetch(sourceUrl);
    if (!res.ok) throw new Error(`fetch ${res.status}`);
    const buf = Buffer.from(await res.arrayBuffer());
    const path = `${SEED_FOLDER}/${userId}/${randomUUID()}.jpg`;
    const { error } = await supabaseAdmin.storage
      .from(STORAGE_BUCKET)
      .upload(path, buf, { contentType: 'image/jpeg', upsert: false });
    if (error) throw error;
    return supabaseAdmin.storage.from(STORAGE_BUCKET).getPublicUrl(path).data.publicUrl;
  } catch (e) {
    console.warn(`   ⚠️  uploadPhoto failed (${sourceUrl.slice(0, 60)}…): ${e}`);
    return sourceUrl; // fall back to hotlink
  }
}

async function photosForCategory(
  category: Category,
  userId: string,
  seedSuffix: string
): Promise<{ url: string; downloadLocation: string }[]> {
  const specs: { key: PoolKey; n: number }[] = (() => {
    switch (category) {
      case 'food':      return [{ key: 'food-interior', n: 2 }, { key: 'food-plated', n: 1 }];
      case 'drinks':    return [{ key: 'drinks-bar', n: 2 }, { key: 'drinks-cocktail', n: 1 }];
      case 'cafe':      return [{ key: 'cafe-interior', n: 2 }, { key: 'cafe-coffee', n: 1 }];
      case 'music':     return [{ key: 'music-venue', n: 1 }, { key: 'music-club', n: 1 }, { key: 'music-jazz', n: 1 }];
      case 'art':       return [{ key: 'art-gallery', n: 1 }, { key: 'art-museum', n: 1 }, { key: 'art-streetart', n: 1 }];
      case 'markets':   return [{ key: 'markets-produce', n: 2 }, { key: 'markets-flea', n: 1 }];
      case 'community': return [{ key: 'community-park', n: 1 }, { key: 'community-yoga', n: 1 }];
      default:          return [{ key: 'food-interior', n: 1 }];
    }
  })();

  const results: { url: string; downloadLocation: string }[] = [];
  let i = 0;
  for (const { key, n } of specs) {
    for (let j = 0; j < n; j++) {
      const photo = pickPhoto(key, `${seedSuffix}-${key}-${j}-${i++}`);
      if (!photo) continue;
      const url = await uploadPhoto(photo.urls.regular, userId);
      results.push({ url, downloadLocation: photo.links.download_location });
    }
  }
  return results;
}

async function photosForEvent(
  kind: string,
  userId: string,
  seedSuffix: string
): Promise<{ url: string; downloadLocation: string }[]> {
  const specs: { key: PoolKey; n: number }[] = (() => {
    switch (kind) {
      case 'tasting_menu':     return [{ key: 'food-plated', n: 2 }];
      case 'tapas_crawl':      return [{ key: 'food-tapas', n: 1 }, { key: 'drinks-bar', n: 1 }];
      case 'wine_tasting':     return [{ key: 'event-winetasting', n: 1 }, { key: 'drinks-wine', n: 1 }];
      case 'cocktail_class':   return [{ key: 'event-bartender', n: 1 }, { key: 'drinks-cocktail', n: 1 }];
      case 'jazz_night':       return [{ key: 'music-jazz', n: 1 }, { key: 'music-venue', n: 1 }];
      case 'dj_set':           return [{ key: 'music-club', n: 2 }];
      case 'gallery_opening':  return [{ key: 'art-gallery', n: 1 }, { key: 'event-meetup', n: 1 }];
      case 'street_art_tour':  return [{ key: 'art-streetart', n: 2 }];
      case 'flea_market':      return [{ key: 'markets-flea', n: 2 }];
      case 'run_club':         return [{ key: 'event-running', n: 2 }];
      case 'yoga_park':        return [{ key: 'community-yoga', n: 2 }];
      case 'language_exchange':return [{ key: 'event-meetup', n: 2 }];
      case 'film_screening':   return [{ key: 'event-outdoor', n: 2 }];
      case 'coffee_workshop':  return [{ key: 'cafe-coffee', n: 1 }, { key: 'cafe-interior', n: 1 }];
      case 'market_tour':      return [{ key: 'markets-produce', n: 1 }, { key: 'event-market', n: 1 }];
      default:                 return [{ key: 'event-meetup', n: 2 }];
    }
  })();

  const results: { url: string; downloadLocation: string }[] = [];
  let i = 0;
  for (const { key, n } of specs) {
    for (let j = 0; j < n; j++) {
      const photo = pickPhoto(key as PoolKey, `${seedSuffix}-${key}-${j}-${i++}`);
      if (!photo) continue;
      const url = await uploadPhoto(photo.urls.regular, userId);
      results.push({ url, downloadLocation: photo.links.download_location });
    }
  }
  return results;
}

// ---------------------------------------------------------------------------
// User roster
// ---------------------------------------------------------------------------

type UserRole = 'pro' | 'amateur' | 'follower';

interface UserDef {
  idx: number;           // 1-50
  email: string;
  name: string;
  handle: string;
  bio: string;
  role: UserRole;
  profilePool: PoolKey;
  isPrivate: boolean;
  niche?: string;        // for pros, their specialty for event/collection generation
}

const USER_ROSTER: UserDef[] = [
  // ── Pros 1-10 ──────────────────────────────────────────────────────────────
  {
    idx: 1, email: '1@1.com', name: 'Tapas Magazine', handle: 'tapasmag',
    bio: 'The definitive guide to Barcelona\'s dining scene. Chef interviews, tasting menus, and the stories behind every plate.',
    role: 'pro', profilePool: 'org-magazine', isPrivate: false, niche: 'finedining',
  },
  {
    idx: 2, email: '2@1.com', name: 'Que Pasa BCN', handle: 'quepasabcn',
    bio: 'Barcelona\'s weekly what\'s-on guide. Viral spots, pop-ups, and the things everyone\'s talking about right now.',
    role: 'pro', profilePool: 'org-skyline', isPrivate: false, niche: 'genz',
  },
  {
    idx: 3, email: '3@1.com', name: 'Poblenou Collective', handle: 'poblenou.collective',
    bio: 'Everything Poblenou. Studios, beach bars, 22@ creative spaces, and the neighbourhood\'s best-kept secrets.',
    role: 'pro', profilePool: 'org-loft', isPrivate: false, niche: 'poblenou',
  },
  {
    idx: 4, email: '4@1.com', name: 'Joel Torras', handle: 'joel.pinchos',
    bio: 'Born in Gràcia, eating my way through every bodega, vermu bar, and tapas counter Barcelona has to offer.',
    role: 'pro', profilePool: 'profile-man', isPrivate: false, niche: 'streetfood',
  },
  {
    idx: 5, email: '5@1.com', name: 'Clara Figueroa', handle: 'clara.gallery',
    bio: 'Art history graduate. I spend my weekends in galleries, museums, and watching street artists work at 2am.',
    role: 'pro', profilePool: 'profile-woman', isPrivate: false, niche: 'art',
  },
  {
    idx: 6, email: '6@1.com', name: 'Dani Moreno', handle: 'danilivebcn',
    bio: 'Live music is my religion. From jazz on Wednesdays to Razzmatazz on Fridays — I\'ve got Barcelona\'s ears.',
    role: 'pro', profilePool: 'profile-man', isPrivate: false, niche: 'music',
  },
  {
    idx: 7, email: '7@1.com', name: 'Jordi Casals', handle: 'jordi.catala',
    bio: 'Defending the old ways. Caves, calçotades, mercat stalls, and the festes majors that never make it to Instagram.',
    role: 'pro', profilePool: 'profile-man', isPrivate: false, niche: 'traditional',
  },
  {
    idx: 8, email: '8@1.com', name: 'Maya Ostrowski', handle: 'mayamovesbcn',
    bio: 'Personal trainer and outdoor enthusiast. Run clubs at dawn, padel at noon, açaí after. BCN is my gym.',
    role: 'pro', profilePool: 'profile-woman', isPrivate: false, niche: 'fitness',
  },
  {
    idx: 9, email: '9@1.com', name: 'Àlex Ribó', handle: 'alex.pours',
    bio: 'Natural wine dealer and cocktail nerd. I know every speakeasy door code and which winemaker just landed in town.',
    role: 'pro', profilePool: 'profile-man', isPrivate: false, niche: 'wine',
  },
  {
    idx: 10, email: '10@1.com', name: 'Thomas Leclerc', handle: 'thomas.cafes',
    bio: 'French expat. Specialty coffee obsessive, digital nomad, and the unofficial inspector of BCN\'s laptop-friendly cafés.',
    role: 'pro', profilePool: 'profile-man', isPrivate: false, niche: 'coffee',
  },

  // ── Amateurs 11-30 ────────────────────────────────────────────────────────
  {
    idx: 11, email: '11@1.com', name: 'Rosa Millán', handle: 'rosa.m',
    bio: 'Weekend escapes and brunch dates with the girls. Sants local, born and raised.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 12, email: '12@1.com', name: 'Kai Tanaka', handle: 'kaiinbcn',
    bio: 'Japanese expat, year one in BCN. Finding the best ramen, coworking spots, and weekend bike routes.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 13, email: '13@1.com', name: 'Aïda Benhaddou', handle: 'aida.kids',
    bio: 'Mum of two toddlers in Sants. Always hunting for family-friendly spots that don\'t make adults want to cry.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 14, email: '14@1.com', name: 'Leo Fernández', handle: 'leo.runs',
    bio: 'Runner, cyclist, and beach volleyball regular. If it\'s outdoors and active, I\'m probably already there.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 15, email: '15@1.com', name: 'Mireia Puig', handle: 'mireiawine',
    bio: 'Natural wine lover and occasional certified sommelier. Collects bottles and bar recommendations equally.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 16, email: '16@1.com', name: 'Nico Albers', handle: 'nico.gigs',
    bio: 'German transplant. Live music addict — Razzmatazz regular, jazz club Wednesday veteran, Apolo floor survivor.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 17, email: '17@1.com', name: 'Julia Costa', handle: 'julia.art',
    bio: 'Fine arts student at UB. Free exhibitions, open studios, and gallery openings are basically my social life.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 18, email: '18@1.com', name: 'Benji Ortiz', handle: 'benji.brunch',
    bio: 'Freelance graphic designer. My mornings exist to test every brunch spot and pastry counter in the city.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 19, email: '19@1.com', name: 'Sara López', handle: 'sara.vintage',
    bio: 'Vintage hunter and flea market addict. Encants every Monday, Palo Alto when it opens, Mercat de Sant Antoni every Sunday.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 20, email: '20@1.com', name: 'Marc Rovira', handle: 'marc.eats',
    bio: 'Architect by day, restaurant hunter by night. Building a map of every place worth a date in this city.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 21, email: '21@1.com', name: 'Lila Weiss', handle: 'lila.yoga',
    bio: 'Yoga instructor from Munich. Wellness spots, smoothie bowls, and the calmest corners of the city.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 22, email: '22@1.com', name: 'Pau Navarro', handle: 'pau.gotic',
    bio: 'Gòtic born and bred. History nerd, walking tour unofficial guide, and defender of the old neighbourhood.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 23, email: '23@1.com', name: 'Olga Petrova', handle: 'olga.bcn',
    bio: 'Russian expat, 3 years in. Coworking explorer and weekend brunch planner. Building my Barcelona from scratch.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 24, email: '24@1.com', name: 'David Riera', handle: 'david.climb',
    bio: 'Climber, hiker, and Collserola regular. When I\'m not on a rock face, I\'m finding post-session recovery spots.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 25, email: '25@1.com', name: 'Inès Fabre', handle: 'ines.design',
    bio: 'French interior designer based in Eixample. Obsessed with architecture, design shops, and the MACBA courtyard.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 26, email: '26@1.com', name: 'Carles Vidal', handle: 'carles.padel',
    bio: 'Padel court rat and beach volleyball regular. Also eats a lot of post-sport grilled food.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 27, email: '27@1.com', name: 'Valentina Russo', handle: 'valentina.dj',
    bio: 'Italian DJ and nightlife regular. If there\'s a good DJ set happening this weekend, I\'ve already got the flyer.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 28, email: '28@1.com', name: 'Henry Okafor', handle: 'henry.books',
    bio: 'Writer and bibliophile. Collecting the quietest cafés and the best bookshops in every neighbourhood.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 29, email: '29@1.com', name: 'Clara Tomàs', handle: 'clara.markets',
    bio: 'Local producer and market lover. Sundays are for Boqueria tours, Sant Antoni browsing, and overspending on cheese.',
    role: 'amateur', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 30, email: '30@1.com', name: 'Finn Dalsgaard', handle: 'finn.late',
    bio: 'Danish bartender working in BCN. Covers the late-night eating and after-hours bar scene nobody else maps.',
    role: 'amateur', profilePool: 'profile-man', isPrivate: false,
  },

  // ── Followers 31-50 ───────────────────────────────────────────────────────
  {
    idx: 31, email: '31@1.com', name: 'Sergi Pons', handle: 'sergipons_',
    bio: 'Gòtic local. Save everything, post nothing.', role: 'follower', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 32, email: '32@1.com', name: 'Elena Popescu', handle: 'elenaPB',
    bio: 'New to Barcelona. Building my BCN list one save at a time.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 33, email: '33@1.com', name: 'Omar Farouk', handle: 'omar_bcn',
    bio: 'Erasmus student, Raval. Budget eats and free gigs.', role: 'follower', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 34, email: '34@1.com', name: 'Jessie Xu', handle: 'jessie.xu',
    bio: 'Design tourist. Here for the architecture, the coffee, and the vibes.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 35, email: '35@1.com', name: 'Tom Wilson', handle: 'tom.dn',
    bio: 'Digital nomad, 3-month BCN stint. Café reviews from a laptop.', role: 'follower', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 36, email: '36@1.com', name: 'Sofia Ramírez', handle: 'sofia.r',
    bio: 'Planner of anniversary dinners and date nights.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 37, email: '37@1.com', name: 'Martin Søndergaard', handle: 'martin_dk',
    bio: 'Quick weekender from Copenhagen.', role: 'follower', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 38, email: '38@1.com', name: 'Priya Joshi', handle: 'priya.j',
    bio: 'Vegetarian, brunch obsessive, weekend yoga. Saving the gentle spots.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 39, email: '39@1.com', name: 'Mattia Russo', handle: 'mattia.it',
    bio: 'Italian in BCN. The pizza is wrong but everything else is perfect.', role: 'follower', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 40, email: '40@1.com', name: 'Hana Kim', handle: 'hana.kim',
    bio: 'K-food finder and specialty coffee obsessive.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 41, email: '41@1.com', name: 'Bea Serrat', handle: 'bea.gracia',
    bio: 'Gràcia resident since forever. The neighbourhood still surprises me.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 42, email: '42@1.com', name: 'Lukas Becker', handle: 'lukas.de',
    bio: 'Berlin transplant. Here for the gigs and the sunsets.', role: 'follower', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 43, email: '43@1.com', name: 'Emma Martin', handle: 'emma.m',
    bio: 'French expat, natural wine hunter.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 44, email: '44@1.com', name: 'Raj Patel', handle: 'raj.p',
    bio: 'London family visiting for a week. Need the full BCN hit list.', role: 'follower', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 45, email: '45@1.com', name: 'Clara Barbosa', handle: 'clara.b',
    bio: 'Brazilian expat. Beach, food, and endless sunshine.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 46, email: '46@1.com', name: 'Ivan Radic', handle: 'ivan.r',
    bio: 'Business traveler. Eixample hotels, good dinner spots, and fast wifi.', role: 'follower', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 47, email: '47@1.com', name: 'Lucía Méndez', handle: 'lucia.arg',
    bio: 'Argentinian in BCN. On a parrilla and asado mission.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 48, email: '48@1.com', name: 'Maya Lindberg', handle: 'maya.l',
    bio: 'Swedish honeymooner. Everything must be perfect.', role: 'follower', profilePool: 'profile-woman', isPrivate: false,
  },
  {
    idx: 49, email: '49@1.com', name: 'Yuki Sato', handle: 'yuki.j',
    bio: 'Japanese tourist, 1-week trip. Efficient sightseeing mode activated.', role: 'follower', profilePool: 'profile-man', isPrivate: false,
  },
  {
    idx: 50, email: '50@1.com', name: 'Alex Quintero', handle: 'alex.q',
    bio: 'Queer nightlife regular. Tracking the best parties and safe spaces.', role: 'follower', profilePool: 'profile-casual', isPrivate: false,
  },
];

// ---------------------------------------------------------------------------
// Venue master list (~225 real Barcelona venues)
// ---------------------------------------------------------------------------

interface VenueDef {
  name: string;
  category: Category;
  neighborhood: string;
  address: string;
  lat: number;
  lng: number;
  description: string;
  ownerIdx: number;
}

const VENUES: VenueDef[] = [
  // ── Pro 1 — Tapas Magazine (fine dining, food) ───────────────────────────
  { name: 'Disfrutar', category: 'food', neighborhood: 'Eixample', address: 'Carrer de Villarroel 163, Barcelona', lat: 41.3882, lng: 2.1560, ownerIdx: 1, description: 'The elBulli alumni playground. Book two months out for the full theatre.' },
  { name: 'Moments', category: 'food', neighborhood: 'Eixample', address: 'Passeig de Gràcia 38-40, Barcelona', lat: 41.3925, lng: 2.1656, ownerIdx: 1, description: 'Michelin-starred Catalan cuisine inside the Mandarin Oriental. Roser Cusí at the stoves.' },
  { name: 'Cinc Sentits', category: 'food', neighborhood: 'Eixample', address: 'Carrer d\'Aribau 58, Barcelona', lat: 41.3892, lng: 2.1598, ownerIdx: 1, description: 'Five senses tasting menu. Canadian-Catalan family-run and consistently exceptional.' },
  { name: 'Via Veneto', category: 'food', neighborhood: 'Sarrià-Sant Gervasi', address: 'Carrer de Ganduxer 10, Barcelona', lat: 41.3968, lng: 2.1382, ownerIdx: 1, description: 'Barcelona\'s grande dame. Opened 1967, two Michelin stars, white tablecloth grandeur.' },
  { name: 'Lasarte', category: 'food', neighborhood: 'Eixample', address: 'Carrer de Mallorca 259, Barcelona', lat: 41.3945, lng: 2.1622, ownerIdx: 1, description: 'Martin Berasategui\'s Barcelona outpost. Three Michelin stars and a perfectly composed menu.' },
  { name: 'Cocina Hermanos Torres', category: 'food', neighborhood: 'Sants-Montjuïc', address: 'Carrer del Taquígraf Serra 20, Barcelona', lat: 41.3773, lng: 2.1442, ownerIdx: 1, description: 'Breathtaking open kitchen inside a converted industrial warehouse. Two Michelin stars.' },
  { name: 'Angle Barcelona', category: 'food', neighborhood: 'Eixample', address: 'Carrer de Muntaner 50, Barcelona', lat: 41.3877, lng: 2.1572, ownerIdx: 1, description: 'Jordi Cruz\'s one-star restaurant with an affordable lunch tasting menu.' },
  { name: 'Pakta', category: 'food', neighborhood: 'Eixample', address: 'Carrer del Parlament 12, Barcelona', lat: 41.3793, lng: 2.1648, ownerIdx: 1, description: 'Nikkei cuisine by the Albert Adrià universe. Japanese-Peruvian fusion at its most refined.' },
  { name: 'Bodega Sepúlveda', category: 'food', neighborhood: 'Eixample', address: 'Carrer de Sepúlveda 173, Barcelona', lat: 41.3859, lng: 2.1553, ownerIdx: 1, description: 'Old-school Catalan bodega hidden behind a modern facade. Perfect patatas bravas.' },
  { name: 'Bar Mut', category: 'food', neighborhood: 'Eixample', address: 'Carrer de Pau Claris 192, Barcelona', lat: 41.3977, lng: 2.1632, ownerIdx: 1, description: 'The beautiful people of the right side of Eixample drink vermuт and eat pintxos here.' },
  { name: 'Cervecería Catalana', category: 'food', neighborhood: 'Eixample', address: 'Carrer de Mallorca 236, Barcelona', lat: 41.3944, lng: 2.1611, ownerIdx: 1, description: 'Perpetual queue, perpetual worth it. The benchmark tapas bar for everyone visiting BCN.' },
  { name: 'Parking Pizza', category: 'food', neighborhood: 'Les Corts', address: 'Carrer de Londres 98, Barcelona', lat: 41.3875, lng: 2.1392, ownerIdx: 1, description: 'Barcelona\'s best Neapolitan pizza. The waiting list is real but the sourdough base is worth it.' },
  { name: 'Hoja Santa', category: 'food', neighborhood: 'Eixample', address: 'Avenida de Mistral 54, Barcelona', lat: 41.3774, lng: 2.1572, ownerIdx: 1, description: 'Albert Adrià\'s Mexican fine dining. One Michelin star and extraordinary mole.' },
  { name: 'Boca Grande', category: 'food', neighborhood: 'Eixample', address: 'Passatge de la Concepció 12, Barcelona', lat: 41.3940, lng: 2.1643, ownerIdx: 1, description: 'Grand Basque-style seafood bar. The prawn croquetas are a city landmark.' },
  { name: 'Freixa Tradició', category: 'food', neighborhood: 'Sarrià-Sant Gervasi', address: 'Carrer de Sant Elies 22, Barcelona', lat: 41.4032, lng: 2.1378, ownerIdx: 1, description: 'Traditional Catalan cooking in a family restaurant that has been at it since 1895.' },
  { name: 'El 58', category: 'food', neighborhood: 'Born', address: 'Carrer del Rec Comtal 16, Barcelona', lat: 41.3856, lng: 2.1843, ownerIdx: 1, description: 'Intimate Born bistro with a short menu of beautifully executed market dishes.' },
  { name: 'Llamber', category: 'food', neighborhood: 'Born', address: 'Carrer de la Fusina 5, Barcelona', lat: 41.3840, lng: 2.1858, ownerIdx: 1, description: 'Asturian-Catalan tasting menu in the Born. Small, considered, seasonal.' },
  { name: 'Tickets Bar', category: 'food', neighborhood: 'Eixample', address: 'Avinguda del Paral·lel 164, Barcelona', lat: 41.3776, lng: 2.1560, ownerIdx: 1, description: 'Albert Adrià\'s tapas carnival. Book online two months ahead or join the walk-in queue.' },
  { name: 'Bodega 1900', category: 'drinks', neighborhood: 'Eixample', address: 'Carrer del Tamarit 91, Barcelona', lat: 41.3775, lng: 2.1607, ownerIdx: 1, description: 'Albert Adrià\'s reimagined vermouth bar. All the classic Spanish aperitivos, elevated.' },
  { name: 'Compartir', category: 'food', neighborhood: 'Barceloneta', address: 'Carrer del Baluard 13, Barcelona', lat: 41.3814, lng: 2.1862, ownerIdx: 1, description: 'The Cadaqués team\'s Barcelona restaurant. Sharing plates done with Adrià precision.' },
  { name: 'Quimet & Quimet', category: 'food', neighborhood: 'Poble-sec', address: 'Carrer del Poeta Cabanyes 25, Barcelona', lat: 41.3745, lng: 2.1618, ownerIdx: 1, description: 'Legendary Poble-sec bodega. Standing room only, conservas stacked to the ceiling.' },
  { name: 'Palo Cortao', category: 'food', neighborhood: 'Poble-sec', address: 'Carrer dels Nou de la Rambla 146, Barcelona', lat: 41.3745, lng: 2.1598, ownerIdx: 1, description: 'Modern Andalusian counter in Poble-sec. Exceptional fried fish and a great sherry list.' },

  // ── Pro 2 — Que Pasa BCN (trendy/genz, all categories) ──────────────────
  { name: 'Federal Café', category: 'cafe', neighborhood: 'Sant Antoni', address: 'Carrer del Parlament 39, Barcelona', lat: 41.3800, lng: 2.1648, ownerIdx: 2, description: 'The OG brunch spot that put Sant Antoni on the map. Still excellent avocado toast.' },
  { name: 'Nomad Coffee Lab', category: 'cafe', neighborhood: 'Born', address: 'Passatge de Sert 12, Barcelona', lat: 41.3861, lng: 2.1782, ownerIdx: 2, description: 'Specialty roasters and lab space tucked into the Born. The best espresso in the city.' },
  { name: 'Satan\'s Coffee Corner', category: 'cafe', neighborhood: 'Gòtic', address: 'Carrer de l\'Arc de Sant Ramon del Call 11, Barcelona', lat: 41.3821, lng: 2.1744, ownerIdx: 2, description: 'Tiny espresso bar with zero atmosphere and perfect coffee. Iconic.' },
  { name: 'Garage Beer Co', category: 'drinks', neighborhood: 'Eixample', address: 'Carrer del Consell de Cent 261, Barcelona', lat: 41.3896, lng: 2.1582, ownerIdx: 2, description: 'BCN\'s best craft brewery taproom. 15 rotating taps, great snacks, always packed.' },
  { name: 'Bar Calders', category: 'drinks', neighborhood: 'Sant Antoni', address: 'Carrer del Parlament 25, Barcelona', lat: 41.3797, lng: 2.1645, ownerIdx: 2, description: 'The living room of Sant Antoni. Order vermu, get anchovies, watch the neighbourhood.' },
  { name: 'El Jardi', category: 'drinks', neighborhood: 'Raval', address: 'Hospital 56, Barcelona', lat: 41.3798, lng: 2.1714, ownerIdx: 2, description: 'Courtyard bar inside the Gothic Hospital de la Santa Creu. Hidden gem, beautiful setting.' },
  { name: 'Bikini', category: 'music', neighborhood: 'Les Corts', address: 'Avinguda Diagonal 547, Barcelona', lat: 41.3885, lng: 2.1387, ownerIdx: 2, description: 'BCN\'s premier concert and club venue. Three rooms, major international acts.' },
  { name: 'Terrabacus', category: 'drinks', neighborhood: 'Poblenou', address: 'Carrer de Pujades 76, Barcelona', lat: 41.4001, lng: 2.1962, ownerIdx: 2, description: 'Wine bar in a Poblenou sidestreet. 500+ references, mostly natural, no pretension.' },
  { name: 'La Cova Fumada', category: 'food', neighborhood: 'Barceloneta', address: 'Carrer del Baluard 56, Barcelona', lat: 41.3806, lng: 2.1895, ownerIdx: 2, description: 'The birthplace of the bombas. No menu, cash only, locals only (mostly).' },
  { name: 'Creps al Born', category: 'food', neighborhood: 'Born', address: 'Carrer del Comerc 17, Barcelona', lat: 41.3847, lng: 2.1836, ownerIdx: 2, description: 'Beloved creperie in the Born. Sweet and savoury, always a queue.' },
  { name: 'Flax & Kale', category: 'food', neighborhood: 'Raval', address: 'Carrer dels Tallers 74b, Barcelona', lat: 41.3854, lng: 2.1677, ownerIdx: 2, description: 'The Barcelona healthy-eating flagship. Flexitarian menu with genuinely interesting cooking.' },
  { name: 'Paradiso', category: 'drinks', neighborhood: 'Born', address: 'Carrer de Rera Palau 4, Barcelona', lat: 41.3842, lng: 2.1845, ownerIdx: 2, description: 'Award-winning speakeasy behind a pastrami bar. Best cocktail bar in Spain, regularly.' },
  { name: 'Miriam\'s Bar', category: 'drinks', neighborhood: 'Gràcia', address: 'Carrer de la Perla 24, Barcelona', lat: 41.4028, lng: 2.1592, ownerIdx: 2, description: 'Old-school Gràcia bar with DJs, mixed crowd, and no attitude. Open late.' },
  { name: 'Meow Wolf BCN', category: 'art', neighborhood: 'Poblenou', address: 'Carrer de Pallars 122, Barcelona', lat: 41.4018, lng: 2.1995, ownerIdx: 2, description: 'Immersive art installation in a Poblenou warehouse. The most Instagrammed space in the city.' },
  { name: 'Electra', category: 'food', neighborhood: 'Sant Antoni', address: 'Ronda de Sant Antoni 72, Barcelona', lat: 41.3818, lng: 2.1622, ownerIdx: 2, description: 'The brunch and coffee spot that replaced Federal in the Instagram algorithm.' },
  { name: 'Cervecería Moritz', category: 'drinks', neighborhood: 'Eixample', address: 'Ronda de Sant Antoni 39, Barcelona', lat: 41.3820, lng: 2.1608, ownerIdx: 2, description: 'Beautifully restored beer factory. Craft beer, tapas, and a stunning interior.' },
  { name: 'Bar Marsella', category: 'drinks', neighborhood: 'Raval', address: 'Carrer de Sant Pau 65, Barcelona', lat: 41.3796, lng: 2.1729, ownerIdx: 2, description: 'Opened in 1820, still dusty, still perfect. Absinthe in the oldest bar in Barcelona.' },
  { name: 'Tiger Bar', category: 'drinks', neighborhood: 'Gràcia', address: 'Carrer del Torrent de l\'Olla 50, Barcelona', lat: 41.4025, lng: 2.1562, ownerIdx: 2, description: 'Tiny neighbourhood bar in upper Gràcia. No frills, good music, very local crowd.' },
  { name: 'La Baguetería del Born', category: 'cafe', neighborhood: 'Born', address: 'Carrer del Comerç 28, Barcelona', lat: 41.3849, lng: 2.1841, ownerIdx: 2, description: 'French-style boulangerie. Best croissants in the Born neighbourhood.' },
  { name: 'Brunch & Cake', category: 'cafe', neighborhood: 'Eixample', address: 'Carrer d\'Enric Granados 19, Barcelona', lat: 41.3896, lng: 2.1618, ownerIdx: 2, description: 'Healthy all-day brunch on the pedestrian Enric Granados. Book weekends.' },
  { name: 'Xurreria de Gràcia', category: 'food', neighborhood: 'Gràcia', address: 'Carrer de Verdi 33, Barcelona', lat: 41.4027, lng: 2.1560, ownerIdx: 2, description: 'Neighbourhood xurreria that hasn\'t changed since 1972. The chocolate is a religious experience.' },
  { name: 'Mercat de Sant Antoni', category: 'markets', neighborhood: 'Sant Antoni', address: 'Carrer del Comte d\'Urgell 1, Barcelona', lat: 41.3812, lng: 2.1629, ownerIdx: 2, description: 'Beautifully restored iron market. Food stalls weekdays, Sunday book market around the perimeter.' },

  // ── Pro 3 — Poblenou Collective (poblenou focus) ─────────────────────────
  { name: 'Rambla del Poblenou', category: 'community', neighborhood: 'Poblenou', address: 'Rambla del Poblenou, Barcelona', lat: 41.4025, lng: 2.2022, ownerIdx: 3, description: 'Poblenou\'s own Rambla. Less touristy, more neighbourhood, terrace cafés and locals on bikes.' },
  { name: 'Palo Alto Market', category: 'markets', neighborhood: 'Poblenou', address: 'Carrer dels Pellaires 30, Barcelona', lat: 41.4050, lng: 2.2018, ownerIdx: 3, description: 'Design and lifestyle market inside a former factory. First weekend of every month.' },
  { name: 'Playa de Bogatell', category: 'community', neighborhood: 'Poblenou', address: 'Platja del Bogatell, Barcelona', lat: 41.4010, lng: 2.2050, ownerIdx: 3, description: 'The locals\' beach. Less crowded than Barceloneta, better vibe, volleyball courts.' },
  { name: 'Hangar', category: 'art', neighborhood: 'Poblenou', address: 'Passatge del Marquès de Santa Isabel 40, Barcelona', lat: 41.4005, lng: 2.1992, ownerIdx: 3, description: 'Production centre for visual artists in a former textile factory. Open studios Thursdays.' },
  { name: 'Can Framis', category: 'art', neighborhood: 'Poblenou', address: 'Carrer de Roc Boronat 116-126, Barcelona', lat: 41.4032, lng: 2.1978, ownerIdx: 3, description: 'Catalan painting museum in a 15th-century farmhouse inside the 22@ tech district.' },
  { name: 'Espai Joliu', category: 'cafe', neighborhood: 'Poblenou', address: 'Carrer de Badajoz 95, Barcelona', lat: 41.4042, lng: 2.1980, ownerIdx: 3, description: 'Specialty coffee roaster and plant shop. The nicest smell in Poblenou.' },
  { name: 'La Pepita', category: 'food', neighborhood: 'Poblenou', address: 'Rambla del Poblenou 54, Barcelona', lat: 41.4022, lng: 2.2019, ownerIdx: 3, description: 'All-day café on the Rambla. Pastries, light lunches, and the best terrace in Poblenou.' },
  { name: 'Xiringuito Escribà', category: 'food', neighborhood: 'Poblenou', address: 'Ronda Litoral 42, Barcelona', lat: 41.3979, lng: 2.2035, ownerIdx: 3, description: 'Beachfront restaurant from the Escribà pastry dynasty. The best paella in the city, argued.' },
  { name: 'Café del Mar Poblenou', category: 'cafe', neighborhood: 'Poblenou', address: 'Carrer de Pallars 187, Barcelona', lat: 41.4015, lng: 2.1990, ownerIdx: 3, description: 'Low-key café with great filter coffee and a courtyard. Digital nomad haven.' },
  { name: 'El Tres', category: 'drinks', neighborhood: 'Poblenou', address: 'Carrer de Pujades 3, Barcelona', lat: 41.3989, lng: 2.1948, ownerIdx: 3, description: 'The neighbourhood wine bar. Local regulars, rotating bottles, no pretension.' },
  { name: 'Bloc', category: 'community', neighborhood: 'Poblenou', address: 'Carrer de Pallars 76, Barcelona', lat: 41.4007, lng: 2.1972, ownerIdx: 3, description: 'Creative coworking and events space inside a Poblenou industrial building.' },
  { name: 'Barcelona Glòries', category: 'markets', neighborhood: 'Poblenou', address: 'Avinguda Diagonal 211, Barcelona', lat: 41.4035, lng: 2.1905, ownerIdx: 3, description: 'Monday and Wednesday antiques and collectors market around the Torre Glòries area.' },
  { name: 'Pla dels Albers', category: 'community', neighborhood: 'Poblenou', address: 'Carrer de Pallars 46, Barcelona', lat: 41.4003, lng: 2.1967, ownerIdx: 3, description: 'Community garden and social space at the heart of the 22@ innovation district.' },
  { name: 'Negroni Poblenou', category: 'drinks', neighborhood: 'Poblenou', address: 'Rambla del Poblenou 34, Barcelona', lat: 41.4020, lng: 2.2018, ownerIdx: 3, description: 'Tiny cocktail bar on the Rambla. Very good Negroni, very friendly staff.' },
  { name: 'Razzmatazz', category: 'music', neighborhood: 'Poblenou', address: 'Carrer dels Almogàvers 122, Barcelona', lat: 41.4005, lng: 2.1920, ownerIdx: 3, description: 'Five rooms, international headliners, epic sound system. BCN\'s most iconic club.' },
  { name: 'Museu d\'Història de Catalunya - Poblenou Branch', category: 'community', neighborhood: 'Poblenou', address: 'Carrer del Pallars 195, Barcelona', lat: 41.4017, lng: 2.1988, ownerIdx: 3, description: 'Community heritage space documenting Poblenou\'s industrial and social history.' },
  { name: 'Ale & Hop', category: 'drinks', neighborhood: 'Born', address: 'Carrer del Baluard 54, Barcelona', lat: 41.3806, lng: 2.1870, ownerIdx: 3, description: 'Craft beer bar with 30 rotating taps. Gateway bottle shop and knowledgeable staff.' },
  { name: 'Beach Club Llevant', category: 'drinks', neighborhood: 'Poblenou', address: 'Platja de Llevant, Barcelona', lat: 41.4008, lng: 2.2071, ownerIdx: 3, description: 'Chiringuito at the quietest end of the Poblenou beach. Sundowners with the lighthouse.' },

  // ── Pro 4 — Joel Torras (street food, bodegas, vermouth) ─────────────────
  { name: 'Cal Pep', category: 'food', neighborhood: 'Born', address: 'Plaça de les Olles 8, Barcelona', lat: 41.3836, lng: 2.1848, ownerIdx: 4, description: 'The classic Barcelonian counter experience. Stand, eat fried seafood, drink cold cava.' },
  { name: 'La Ceba', category: 'food', neighborhood: 'Gràcia', address: 'Carrer de la Perla 3, Barcelona', lat: 41.4024, lng: 2.1588, ownerIdx: 4, description: 'Old Gràcia bodega. Formica tables, house vermu, and a menu written on the wall.' },
  { name: 'Bar Marsella', category: 'drinks', neighborhood: 'Raval', address: 'Carrer de Sant Pau 65, Barcelona', lat: 41.3796, lng: 2.1729, ownerIdx: 4, description: '1820 and still going. The absinthe is warm and so is the atmosphere.' },
  { name: 'La Mar Salada', category: 'food', neighborhood: 'Barceloneta', address: 'Passatge de la Pau 4, Barcelona', lat: 41.3780, lng: 2.1786, ownerIdx: 4, description: 'Seafood and rice dishes next to the port. Classic BCN, no tourists.' },
  { name: 'El Xampanyet', category: 'drinks', neighborhood: 'Born', address: 'Carrer de Montcada 22, Barcelona', lat: 41.3849, lng: 2.1816, ownerIdx: 4, description: 'Tiny cava bar on the most beautiful street in the Born. Tapas and house cava.' },
  { name: 'Bar Oveja Negra', category: 'drinks', neighborhood: 'Raval', address: 'Carrer de les Sitges 5, Barcelona', lat: 41.3820, lng: 2.1719, ownerIdx: 4, description: 'Chaotic Raval bodega with cheap beer and a mixed local crowd. Genuinely fun.' },
  { name: 'Bar Cañete', category: 'food', neighborhood: 'Raval', address: 'Carrer de la Unió 17, Barcelona', lat: 41.3802, lng: 2.1729, ownerIdx: 4, description: 'Long marble counter, top-tier local produce. The bomba de bacallà is unmissable.' },
  { name: 'La Esquina', category: 'food', neighborhood: 'Gràcia', address: 'Carrer de la Tordera 12, Barcelona', lat: 41.4041, lng: 2.1554, ownerIdx: 4, description: 'Corner bodega in upper Gràcia. Vermut from 11am, bocadillos, and zero pretension.' },
  { name: 'Bar Electricitat', category: 'drinks', neighborhood: 'Barceloneta', address: 'Carrer de Sant Carles 15, Barcelona', lat: 41.3788, lng: 2.1884, ownerIdx: 4, description: 'Fishermen\'s bar opened in 1929. Cheapest beer in Barceloneta, cash only.' },
  { name: 'Bodega Sepúlveda', category: 'food', neighborhood: 'Eixample', address: 'Carrer de Sepúlveda 183, Barcelona', lat: 41.3859, lng: 2.1560, ownerIdx: 4, description: 'The best tortilla in the Eixample, served on a marble counter with house wine.' },
  { name: 'Bar Pinocho', category: 'food', neighborhood: 'Raval', address: 'La Boqueria 96, Barcelona', lat: 41.3816, lng: 2.1726, ownerIdx: 4, description: 'The Boqueria counter that matters. Juanito serves breakfast from 7am, queue from 8.' },
  { name: 'La Pepita Gòtic', category: 'food', neighborhood: 'Gòtic', address: 'Carrer de la Corribia 17, Barcelona', lat: 41.3826, lng: 2.1758, ownerIdx: 4, description: 'Montaditos and local wines inside a beautiful old pharmacy in the Gothic Quarter.' },
  { name: 'Vaso de Oro', category: 'drinks', neighborhood: 'Barceloneta', address: 'Carrer de Balboa 6, Barcelona', lat: 41.3807, lng: 2.1875, ownerIdx: 4, description: 'The narrowest bar in BCN. Two taps, excellent tapas, very loud, very fun.' },
  { name: 'Bar Calders', category: 'drinks', neighborhood: 'Sant Antoni', address: 'Carrer del Parlament 25, Barcelona', lat: 41.3797, lng: 2.1645, ownerIdx: 4, description: 'The Sunday vermu ritual. Terrace, anchovies, chips, house vermu.' },
  { name: 'El Velódromo', category: 'food', neighborhood: 'Eixample', address: 'Carrer de Muntaner 213, Barcelona', lat: 41.3946, lng: 2.1570, ownerIdx: 4, description: '1930s café-bar with a Belle Époque interior. Open 24/7, excellent late-night bocadillo.' },
  { name: 'Bodega 1900', category: 'drinks', neighborhood: 'Eixample', address: 'Carrer del Tamarit 91, Barcelona', lat: 41.3775, lng: 2.1607, ownerIdx: 4, description: 'Adrià\'s vermouth bar. Worth the splurge for the upgraded classics.' },
  { name: 'Bar Lobo', category: 'drinks', neighborhood: 'Raval', address: 'Carrer del Pintor Fortuny 3, Barcelona', lat: 41.3840, lng: 2.1700, ownerIdx: 4, description: 'Pre-Raval tapas and cocktails. Perfect before Macba or a Raval evening.' },

  // ── Pro 5 — Clara Figueroa (art, galleries, museums) ────────────────────
  { name: 'MACBA', category: 'art', neighborhood: 'Raval', address: 'Plaça dels Àngels 1, Barcelona', lat: 41.3832, lng: 2.1681, ownerIdx: 5, description: 'The city\'s contemporary art museum. Bold, challenging, and essential.' },
  { name: 'Fundació Joan Miró', category: 'art', neighborhood: 'Montjuïc', address: 'Parc de Montjuïc, Barcelona', lat: 41.3683, lng: 2.1598, ownerIdx: 5, description: 'Miró\'s gift to Barcelona. Sert\'s architecture and the artist\'s universe, on the hill.' },
  { name: 'CCCB', category: 'art', neighborhood: 'Raval', address: 'Carrer de Montalegre 5, Barcelona', lat: 41.3839, lng: 2.1678, ownerIdx: 5, description: 'Contemporary cultural centre next to MACBA. Bold exhibitions and a rooftop terrace.' },
  { name: 'Museu Picasso', category: 'art', neighborhood: 'Born', address: 'Carrer de Montcada 15-23, Barcelona', lat: 41.3847, lng: 2.1806, ownerIdx: 5, description: 'Picasso\'s formative Barcelona years in five medieval palaces. Book ahead.' },
  { name: 'Fundació Antoni Tàpies', category: 'art', neighborhood: 'Eixample', address: 'Carrer d\'Aragó 255, Barcelona', lat: 41.3920, lng: 2.1618, ownerIdx: 5, description: 'Tàpies\' foundation in a Modernista publishing house. Essential for Catalan art understanding.' },
  { name: 'Galería Marlborough', category: 'art', neighborhood: 'Eixample', address: 'Carrer d\'Enric Granados 68, Barcelona', lat: 41.3904, lng: 2.1620, ownerIdx: 5, description: 'One of the city\'s most respected commercial galleries. The Enric Granados pedestrian strip.' },
  { name: 'Arts Santa Mònica', category: 'art', neighborhood: 'Raval', address: 'La Rambla 7, Barcelona', lat: 41.3784, lng: 2.1751, ownerIdx: 5, description: 'Former convent turned arts centre at the bottom of Las Ramblas. Free entry.' },
  { name: 'La Virreina', category: 'art', neighborhood: 'Raval', address: 'La Rambla 99, Barcelona', lat: 41.3840, lng: 2.1726, ownerIdx: 5, description: 'City-run exhibition and cultural programming centre. Free, excellent photography shows.' },
  { name: 'Galeria ProjecteSD', category: 'art', neighborhood: 'Eixample', address: 'Carrer del Consell de Cent 337, Barcelona', lat: 41.3902, lng: 2.1663, ownerIdx: 5, description: 'One of BCN\'s best contemporary galleries. Consistent programme of international artists.' },
  { name: 'Museu Nacional d\'Art de Catalunya', category: 'art', neighborhood: 'Montjuïc', address: 'Parc de Montjuïc s/n, Barcelona', lat: 41.3685, lng: 2.1531, ownerIdx: 5, description: 'Romanesque and Gothic art in a palace overlooking the city. The view from the steps alone.' },
  { name: 'Galería Senda', category: 'art', neighborhood: 'Eixample', address: 'Carrer de Provença 282, Barcelona', lat: 41.3948, lng: 2.1638, ownerIdx: 5, description: 'Contemporary painting and sculpture gallery with an active exhibitions programme.' },
  { name: 'Palau de la Virreina', category: 'art', neighborhood: 'Raval', address: 'La Rambla 99, Barcelona', lat: 41.3840, lng: 2.1726, ownerIdx: 5, description: 'The city\'s image and culture department programming space. Free, thought-provoking.' },
  { name: 'Barcelona Contemporary', category: 'art', neighborhood: 'Gòtic', address: 'Carrer del Pi 6, Barcelona', lat: 41.3828, lng: 2.1739, ownerIdx: 5, description: 'Small, focused contemporary gallery in the Gothic Quarter. Emerging Catalan artists.' },
  { name: 'Espai 13 - Fundació Miró', category: 'art', neighborhood: 'Montjuïc', address: 'Parc de Montjuïc, Barcelona', lat: 41.3683, lng: 2.1598, ownerIdx: 5, description: 'Experimental space inside the Miró Foundation for emerging artists. Often overlooked.' },
  { name: 'Museu d\'Art Modern - Ciutadella', category: 'art', neighborhood: 'Born', address: 'Parc de la Ciutadella, Barcelona', lat: 41.3874, lng: 2.1870, ownerIdx: 5, description: 'Catalan 19th and early 20th century art inside the Ciutadella park.' },

  // ── Pro 6 — Dani Moreno (music) ───────────────────────────────────────────
  { name: 'Sala Apolo', category: 'music', neighborhood: 'Poble-sec', address: 'Carrer Nou de la Rambla 113, Barcelona', lat: 41.3759, lng: 2.1649, ownerIdx: 6, description: 'BCN\'s legendary live music venue. Nitsa club nights and top-tier indie bookings.' },
  { name: 'Jamboree Jazz Club', category: 'music', neighborhood: 'Gòtic', address: 'Plaça Reial 17, Barcelona', lat: 41.3802, lng: 2.1749, ownerIdx: 6, description: 'Jazz in the Plaça Reial since 1960. Two sets nightly, walk-in welcome before midnight.' },
  { name: 'Harlem Jazz Club', category: 'music', neighborhood: 'Gòtic', address: 'Carrer de la Comtessa de Sobradiel 8, Barcelona', lat: 41.3815, lng: 2.1762, ownerIdx: 6, description: 'Tiny, intimate jazz club in the Gòtic. The best straight-ahead jazz in the city.' },
  { name: 'Sidecar Factory Club', category: 'music', neighborhood: 'Gòtic', address: 'Plaça Reial 7, Barcelona', lat: 41.3802, lng: 2.1748, ownerIdx: 6, description: 'Rock and indie venue in the Plaça Reial. Three decades of great live music.' },
  { name: 'Moog', category: 'music', neighborhood: 'Raval', address: 'Carrer de l\'Arc del Teatre 3, Barcelona', lat: 41.3780, lng: 2.1741, ownerIdx: 6, description: 'Small electronic and techno club in the lower Raval. Great sound, long nights.' },
  { name: 'La [2] de Apolo', category: 'music', neighborhood: 'Poble-sec', address: 'Carrer Nou de la Rambla 113, Barcelona', lat: 41.3759, lng: 2.1649, ownerIdx: 6, description: 'Apolo\'s second room. Electronica, DJs, and the best after-after party in BCN.' },
  { name: 'Sala Upload', category: 'music', neighborhood: 'Eixample', address: 'Ronda de la Universitat 7, Barcelona', lat: 41.3862, lng: 2.1652, ownerIdx: 6, description: 'The electronic music hub of the Eixample. Early doors, serious sound system.' },
  { name: 'Palau de la Música Catalana', category: 'music', neighborhood: 'Born', address: 'Carrer del Palau de la Música 4-6, Barcelona', lat: 41.3877, lng: 2.1763, ownerIdx: 6, description: 'Domènech i Montaner\'s Art Nouveau masterpiece. The most beautiful concert hall in the world.' },
  { name: 'Gran Teatre del Liceu', category: 'music', neighborhood: 'Raval', address: 'La Rambla 51-59, Barcelona', lat: 41.3808, lng: 2.1740, ownerIdx: 6, description: 'Barcelona\'s opera house. World-class productions and an incomparable interior.' },
  { name: 'Sala Barts', category: 'music', neighborhood: 'Poble-sec', address: 'Avinguda del Paral·lel 62, Barcelona', lat: 41.3760, lng: 2.1631, ownerIdx: 6, description: 'Mid-size live music venue on the Paral·lel. Top indie and alternative bookings.' },
  { name: 'Jazz Sí Club', category: 'music', neighborhood: 'Raval', address: 'Carrer de Requesens 2, Barcelona', lat: 41.3809, lng: 2.1700, ownerIdx: 6, description: 'Jazz school\'s public jam sessions. Cheap entry, great atmosphere, live improvisation every night.' },
  { name: 'Boulevard Culture Club', category: 'music', neighborhood: 'Eixample', address: 'Carrer de Diagonal 442, Barcelona', lat: 41.3978, lng: 2.1547, ownerIdx: 6, description: 'Large nightclub and concert venue on the Diagonal. Mainstream bookings, excellent production.' },
  { name: 'Sala Heliogàbal', category: 'music', neighborhood: 'Gràcia', address: 'Carrer de Ramon i Cajal 80, Barcelona', lat: 41.4050, lng: 2.1613, ownerIdx: 6, description: 'Basement venue in Gràcia. Underground, experimental, beloved by the music community.' },
  { name: 'Ateneu de Nou Barris', category: 'music', neighborhood: 'Nou Barris', address: 'Carrer de Marie Curie 16, Barcelona', lat: 41.4356, lng: 2.1712, ownerIdx: 6, description: 'Community music and theatre space. Free and affordable programming for the working-class north.' },
  { name: 'Luz de Gas', category: 'music', neighborhood: 'Eixample', address: 'Carrer de Muntaner 246, Barcelona', lat: 41.3960, lng: 2.1564, ownerIdx: 6, description: 'Belle Époque concert hall and club. Classic jazz, blues, and late-night dancing.' },

  // ── Pro 7 — Jordi Casals (traditional Catalan) ───────────────────────────
  { name: 'Can Culleretes', category: 'food', neighborhood: 'Gòtic', address: 'Carrer de Quintana 5, Barcelona', lat: 41.3822, lng: 2.1757, ownerIdx: 7, description: 'Opened 1786 — Barcelona\'s oldest restaurant. Escudella, carn d\'olla, and sopa de galets.' },
  { name: 'Els Quatre Gats', category: 'food', neighborhood: 'Gòtic', address: 'Carrer de Montsió 3, Barcelona', lat: 41.3843, lng: 2.1762, ownerIdx: 7, description: 'Picasso\'s local in the Gothic Quarter. More tourist trap than secret, but the Modernista interior is genuine.' },
  { name: 'Mercat de la Boqueria', category: 'markets', neighborhood: 'Raval', address: 'La Rambla 91, Barcelona', lat: 41.3818, lng: 2.1727, ownerIdx: 7, description: 'The most famous market in Spain. Go early, go for the perimeter stalls, skip the tourist counters.' },
  { name: 'Mercat de Santa Caterina', category: 'markets', neighborhood: 'Born', address: 'Avinguda de Francesc Cambó 16, Barcelona', lat: 41.3862, lng: 2.1789, ownerIdx: 7, description: 'Enric Miralles\' mosaic roof over an authentic neighbourhood market. Less touristy than Boqueria.' },
  { name: 'Fira de Artesania del Passeig de Gràcia', category: 'markets', neighborhood: 'Eixample', address: 'Passeig de Gràcia, Barcelona', lat: 41.3925, lng: 2.1656, ownerIdx: 7, description: 'Annual craft fair on the Passeig de Gràcia. Handmade ceramics, textiles, and foods.' },
  { name: 'La Barceloneta Restaurant', category: 'food', neighborhood: 'Barceloneta', address: 'Carrer de l\'Escar 22, Barcelona', lat: 41.3769, lng: 2.1863, ownerIdx: 7, description: 'No-frills seafood restaurant on the water. Real local paella, not for tourists.' },
  { name: 'Can Ros', category: 'food', neighborhood: 'Barceloneta', address: 'Carrer del Almirall Aixada 7, Barcelona', lat: 41.3793, lng: 2.1875, ownerIdx: 7, description: 'Fifth-generation family restaurant in Barceloneta. Arròs a la cassola as it was meant to be.' },
  { name: 'Granja M. Viader', category: 'cafe', neighborhood: 'Raval', address: 'Carrer den Xuclà 4-6, Barcelona', lat: 41.3838, lng: 2.1706, ownerIdx: 7, description: 'Family-run granja since 1870. Suís, cacaolat, and the original Catalan breakfast.' },
  { name: 'Bar La Plata', category: 'food', neighborhood: 'Gòtic', address: 'Carrer de la Mercè 28, Barcelona', lat: 41.3808, lng: 2.1780, ownerIdx: 7, description: 'One of the oldest bars in the Gòtic. Three items on the menu. All perfect.' },
  { name: 'La Pepita Montcada', category: 'food', neighborhood: 'Born', address: 'Carrer de Montcada 25, Barcelona', lat: 41.3849, lng: 2.1815, ownerIdx: 7, description: 'Catalan traditional tapes in a medieval Born building. Exactly what Barcelona used to taste like.' },
  { name: 'Casa de la Vall', category: 'food', neighborhood: 'Gràcia', address: 'Carrer de la Providència 22, Barcelona', lat: 41.4030, lng: 2.1570, ownerIdx: 7, description: 'Traditional Catalan restaurant in upper Gràcia. Calçots in season, stewed dishes year-round.' },
  { name: 'Antic Cafè de l\'Acadèmia', category: 'food', neighborhood: 'Gòtic', address: 'Carrer dels Llledoners 1, Barcelona', lat: 41.3817, lng: 2.1762, ownerIdx: 7, description: 'Old-school restaurant in a historic building. Menu del día at lunch, Catalan classics.' },
  { name: 'Cafè de l\'Acadèmia', category: 'food', neighborhood: 'Gòtic', address: 'Carrer dels Llledoners 1, Barcelona', lat: 41.3817, lng: 2.1762, ownerIdx: 7, description: 'Gothic Quarter classic. Slow lunch in a Gothic arch space, unchanged since the 1980s.' },
  { name: 'Festes de Gràcia (La Font)', category: 'community', neighborhood: 'Gràcia', address: 'Carrer de Verdi, Barcelona', lat: 41.4027, lng: 2.1560, ownerIdx: 7, description: 'The most famous street in the most famous Barcelona festival. August, decorated, magical.' },
  { name: 'Encants Flea Market', category: 'markets', neighborhood: 'Poblenou', address: 'Carrer de los Castillejos 158, Barcelona', lat: 41.4030, lng: 2.1895, ownerIdx: 7, description: 'The legendary BCN flea market, now under a giant mirrored canopy. Mon, Wed, Fri, Sat.' },

  // ── Pro 8 — Maya Ostrowski (fitness & wellness) ──────────────────────────
  { name: 'Parc de la Ciutadella', category: 'community', neighborhood: 'Born', address: 'Passeig de Pujades 1, Barcelona', lat: 41.3874, lng: 2.1870, ownerIdx: 8, description: 'Barcelona\'s main park. Morning run circuit, yoga on the grass, rowing on the lake.' },
  { name: 'Platja de la Nova Icària', category: 'community', neighborhood: 'Poblenou', address: 'Platja de la Nova Icària, Barcelona', lat: 41.3968, lng: 2.2018, ownerIdx: 8, description: 'Olympic beach with volleyball courts and a morning run path. Less crowded than Barceloneta.' },
  { name: 'Centre Esportiu Municipal Mar Bella', category: 'community', neighborhood: 'Poblenou', address: 'Avinguda del Litoral 86, Barcelona', lat: 41.3985, lng: 2.2048, ownerIdx: 8, description: 'Olympic pool on the waterfront. Open-air 50m pool in summer. One of the best sports facilities in BCN.' },
  { name: 'Club Natació Atlètic Barceloneta', category: 'community', neighborhood: 'Barceloneta', address: 'Plaça del Mar 1, Barcelona', lat: 41.3784, lng: 2.1892, ownerIdx: 8, description: 'Swimming club at the end of the Barceloneta pier. Open-air sea pool and sauna.' },
  { name: 'Parc de Collserola', category: 'community', neighborhood: 'Sarrià-Sant Gervasi', address: 'Ctra. de l\'Església 92, Barcelona', lat: 41.4180, lng: 2.1138, ownerIdx: 8, description: 'Barcelona\'s giant forest park. Trail running, mountain biking, and weekend hikes.' },
  { name: 'Bunkers del Carmel', category: 'community', neighborhood: 'Carmel', address: 'Carrer de Marià Labèrnia, Barcelona', lat: 41.4164, lng: 2.1548, ownerIdx: 8, description: 'Civil war anti-aircraft bunkers with the best 360° view of Barcelona. Sunrise spot.' },
  { name: 'Green Deli Organic', category: 'cafe', neighborhood: 'Eixample', address: 'Carrer del Consell de Cent 220, Barcelona', lat: 41.3892, lng: 2.1590, ownerIdx: 8, description: 'Organic café and juice bar. Post-workout nutrition in a clean, calm setting.' },
  { name: 'Açaí Lab', category: 'cafe', neighborhood: 'Born', address: 'Carrer del Parlament 21, Barcelona', lat: 41.3796, lng: 2.1641, ownerIdx: 8, description: 'BCN\'s best açaí bowls and smoothies. Fuel for the active crowd.' },
  { name: 'El Corte Inglés Sport', category: 'community', neighborhood: 'Eixample', address: 'Avinguda Diagonal 617, Barcelona', lat: 41.3948, lng: 2.1375, ownerIdx: 8, description: 'Rooftop running track and sports facilities. Often overlooked, excellent facilities.' },
  { name: 'Padel Indoor BCN', category: 'community', neighborhood: 'Sants', address: 'Carrer de la Constitució 19, Barcelona', lat: 41.3750, lng: 2.1435, ownerIdx: 8, description: 'Indoor padel courts in Sants. Book a week ahead for weekend slots.' },
  { name: 'Yoga Studio La Masia', category: 'community', neighborhood: 'Gràcia', address: 'Carrer de l\'Astúries 24, Barcelona', lat: 41.4008, lng: 2.1567, ownerIdx: 8, description: 'Beautiful yoga studio in Gràcia. Vinyasa, Yin, and meditation classes in a converted farmhouse.' },
  { name: 'Rock and Wall BCN', category: 'community', neighborhood: 'Poblenou', address: 'Carrer de Sancho de Ávila 78, Barcelona', lat: 41.4010, lng: 2.1930, ownerIdx: 8, description: 'The biggest climbing wall in BCN. Bouldering and lead climbing, beginner-friendly.' },
  { name: 'Surf House Barcelona', category: 'community', neighborhood: 'Barceloneta', address: 'Carrer de Baluard 84, Barcelona', lat: 41.3812, lng: 2.1897, ownerIdx: 8, description: 'Surf lessons and SUP rental at the Barceloneta beach. Beginners welcome.' },
  { name: 'Piscina Municipal de Montjuïc', category: 'community', neighborhood: 'Montjuïc', address: 'Avinguda de Miramar 31, Barcelona', lat: 41.3638, lng: 2.1572, ownerIdx: 8, description: 'The 1992 Olympics diving pool with a view of the city. Open to the public in summer.' },
  { name: 'Noi Sarrià', category: 'cafe', neighborhood: 'Sarrià', address: 'Carrer de Margenat 7, Barcelona', lat: 41.4028, lng: 2.1272, ownerIdx: 8, description: 'Specialty coffee and post-run brunch in the quiet Sarrià neighbourhood.' },

  // ── Pro 9 — Àlex Ribó (natural wine & cocktails) ─────────────────────────
  { name: 'Two Schmucks', category: 'drinks', neighborhood: 'Eixample', address: 'Carrer de Joaquin Costa 52, Barcelona', lat: 41.3847, lng: 2.1692, ownerIdx: 9, description: 'World\'s 50 Best Bars regular. The most fun cocktail bar in Europe, no debate.' },
  { name: 'Dry Martini', category: 'drinks', neighborhood: 'Eixample', address: 'Carrer d\'Aribau 162, Barcelona', lat: 41.3950, lng: 2.1597, ownerIdx: 9, description: 'Classic 1978 cocktail bar. Suit-wearing bartenders, perfect Martinis, time stands still.' },
  { name: 'Bobby Gin', category: 'drinks', neighborhood: 'Gràcia', address: 'Carrer del Francesc Giner 47, Barcelona', lat: 41.4010, lng: 2.1562, ownerIdx: 9, description: 'Gin and tonic specialists with 60+ gins. The terrace on a warm evening is perfect.' },
  { name: 'El Xalet de Montjuïc', category: 'drinks', neighborhood: 'Montjuïc', address: 'Carretera de Montjuïc 185, Barcelona', lat: 41.3710, lng: 2.1558, ownerIdx: 9, description: 'Rooftop cocktail bar on Montjuïc with panoramic city views. Sunset is the time.' },
  { name: 'Bar Calders', category: 'drinks', neighborhood: 'Sant Antoni', address: 'Carrer del Parlament 25, Barcelona', lat: 41.3797, lng: 2.1645, ownerIdx: 9, description: 'The best vermouth ritual in the city. Anchoas, chips, house vermut on the terrace.' },
  { name: 'La Vinateria del Call', category: 'drinks', neighborhood: 'Gòtic', address: 'Carrer de Sant Domènec del Call 9, Barcelona', lat: 41.3821, lng: 2.1748, ownerIdx: 9, description: 'Natural wine bar in the old Jewish quarter. A short list of extraordinary bottles.' },
  { name: 'Barrocho', category: 'drinks', neighborhood: 'Born', address: 'Carrer del Parlament 21, Barcelona', lat: 41.3796, lng: 2.1641, ownerIdx: 9, description: 'Beloved natural wine bar in the Born. Biodynamic producers, no-filter policy.' },
  { name: 'Vins i Caves La Catedral', category: 'drinks', neighborhood: 'Gòtic', address: 'Avinguda de la Catedral 6, Barcelona', lat: 41.3835, lng: 2.1763, ownerIdx: 9, description: 'Wine shop and tasting counter under the Gothic cathedral. Great Catalan producers.' },
  { name: 'Frank\'s Bar', category: 'drinks', neighborhood: 'Eixample', address: 'Carrer del Consell de Cent 235, Barcelona', lat: 41.3896, lng: 2.1592, ownerIdx: 9, description: 'Pre-theatre and after-work cocktail bar. Excellent classics, modern riffs.' },
  { name: 'Negroni BCN', category: 'drinks', neighborhood: 'Eixample', address: 'Carrer del Rosselló 201, Barcelona', lat: 41.3956, lng: 2.1588, ownerIdx: 9, description: 'BCN\'s most thoughtful Negroni bar. 20+ variations, all served perfectly cold.' },
  { name: 'Bar Marsella', category: 'drinks', neighborhood: 'Raval', address: 'Carrer de Sant Pau 65, Barcelona', lat: 41.3796, lng: 2.1729, ownerIdx: 9, description: 'The patriarch of BCN bars. Absinthe since 1820, nothing has changed, everything is right.' },
  { name: 'Cervecería Jazz', category: 'drinks', neighborhood: 'Born', address: 'Carrer del Parlament 11, Barcelona', lat: 41.3793, lng: 2.1638, ownerIdx: 9, description: 'Craft beer meets jazz ambience. The rotating tap list pairs perfectly with live music.' },
  { name: 'La Confiteria', category: 'drinks', neighborhood: 'Raval', address: 'Carrer de Sant Pau 128, Barcelona', lat: 41.3795, lng: 2.1713, ownerIdx: 9, description: '19th-century pharmacy-turned-cocktail-bar. All original fittings, excellent gimlets.' },
  { name: 'El Salón', category: 'drinks', neighborhood: 'Gòtic', address: 'Carrer de l\'Hostal del Sol 6, Barcelona', lat: 41.3814, lng: 2.1764, ownerIdx: 9, description: 'Intimate Gothic cocktail bar. Dark, beautiful, the best Old Fashioned in the neighbourhood.' },
  { name: 'La Cava del Palau', category: 'drinks', neighborhood: 'Born', address: 'Carrer del Vermell 9, Barcelona', lat: 41.3877, lng: 2.1762, ownerIdx: 9, description: 'Natural and biodynamic wine bar near the Palau de la Música. Sommelier-curated list.' },

  // ── Pro 10 — Thomas Leclerc (specialty coffee & cafés) ────────────────────
  { name: 'Nomad Coffee Lab', category: 'cafe', neighborhood: 'Born', address: 'Passatge de Sert 12, Barcelona', lat: 41.3861, lng: 2.1782, ownerIdx: 10, description: 'BCN\'s pioneering specialty roaster. The benchmark for espresso quality in the city.' },
  { name: 'Syra Coffee', category: 'cafe', neighborhood: 'Gràcia', address: 'Carrer de l\'Astúries 46, Barcelona', lat: 41.4008, lng: 2.1571, ownerIdx: 10, description: 'Gràcia specialty café with exceptional filter coffee. The beans are roasted downstairs.' },
  { name: 'Satan\'s Coffee Corner', category: 'cafe', neighborhood: 'Gòtic', address: 'Carrer de l\'Arc de Sant Ramon del Call 11, Barcelona', lat: 41.3821, lng: 2.1744, ownerIdx: 10, description: 'The most intense espresso bar in BCN. Three square metres, world-class quality.' },
  { name: 'Cafè Cometa', category: 'cafe', neighborhood: 'Gràcia', address: 'Carrer de la Providència 43, Barcelona', lat: 41.4030, lng: 2.1574, ownerIdx: 10, description: 'Bright Gràcia neighbourhood café. Good single origin, welcoming for working.' },
  { name: 'Federal Café', category: 'cafe', neighborhood: 'Sant Antoni', address: 'Carrer del Parlament 39, Barcelona', lat: 41.3800, lng: 2.1648, ownerIdx: 10, description: 'The Australian-style brunch café that started BCN\'s café culture revolution.' },
  { name: 'Cafè de l\'Acadèmia', category: 'cafe', neighborhood: 'Gòtic', address: 'Carrer dels Llledoners 1, Barcelona', lat: 41.3817, lng: 2.1762, ownerIdx: 10, description: 'Gothic café in a historic building. Good filter, quiet, Wi-Fi works.' },
  { name: 'Right Side Coffee', category: 'cafe', neighborhood: 'Eixample', address: 'Carrer d\'Enric Granados 9, Barcelona', lat: 41.3891, lng: 2.1617, ownerIdx: 10, description: 'Third-wave espresso bar on the pedestrian Enric Granados boulevard. Specialty only.' },
  { name: 'Cosa Nostra', category: 'cafe', neighborhood: 'Gràcia', address: 'Carrer de la Verge 4, Barcelona', lat: 41.4003, lng: 2.1587, ownerIdx: 10, description: 'Italian-owned café in Gràcia. The best moka-style espresso alongside specialty options.' },
  { name: 'El Hogar', category: 'cafe', neighborhood: 'Eixample', address: 'Carrer del Consell de Cent 275, Barcelona', lat: 41.3898, lng: 2.1593, ownerIdx: 10, description: 'Cosy Eixample café with long communal tables. Excellent for a working afternoon.' },
  { name: 'Morro Fi', category: 'cafe', neighborhood: 'Eixample', address: 'Carrer del Consell de Cent 171, Barcelona', lat: 41.3898, lng: 2.1562, ownerIdx: 10, description: 'The busiest specialty bar in BCN. Queue at the counter, no seating, worth it.' },
  { name: 'El Bloc', category: 'cafe', neighborhood: 'Poblenou', address: 'Carrer de Pallars 76, Barcelona', lat: 41.4007, lng: 2.1972, ownerIdx: 10, description: 'Coworking café hybrid in Poblenou. Reliable Wi-Fi, good filter, community noticeboard.' },
  { name: 'Café de Gràcia', category: 'cafe', neighborhood: 'Gràcia', address: 'Carrer de Gràcia 12, Barcelona', lat: 41.3952, lng: 2.1608, ownerIdx: 10, description: 'Old Gràcia neighbourhood café. Locals only, mediocre coffee, but charm to spare.' },
  { name: 'SlowMov', category: 'cafe', neighborhood: 'Sant Antoni', address: 'Carrer del Parlament 36, Barcelona', lat: 41.3799, lng: 2.1647, ownerIdx: 10, description: 'Specialty brunch and coffee in Sant Antoni. The matcha latte is the best in BCN.' },
  { name: 'Naïf', category: 'cafe', neighborhood: 'Sant Antoni', address: 'Carrer de la Creu dels Molers 6, Barcelona', lat: 41.3789, lng: 2.1638, ownerIdx: 10, description: 'Lovely all-day café near the Mercat de Sant Antoni. Relaxed vibe, good cold brew.' },
  { name: 'Cafè Adagio', category: 'cafe', neighborhood: 'Eixample', address: 'Carrer del Rosselló 139, Barcelona', lat: 41.3956, lng: 2.1555, ownerIdx: 10, description: 'Quiet Eixample café with an excellent breakfast menu and consistently good espresso.' },
];

// ---------------------------------------------------------------------------
// Event kinds per pro niche
// ---------------------------------------------------------------------------

interface EventKindDef {
  kind: string;
  titleTemplates: string[];
  category: Category;
  descriptions: string[];
}

const EVENT_KINDS_BY_NICHE: Record<string, EventKindDef[]> = {
  finedining: [
    { kind: 'tasting_menu', category: 'food', titleTemplates: ['Chef\'s Tasting Menu at {venue}', 'New Tasting Menu Launch — {venue}', 'Exclusive Chef\'s Counter at {venue}'], descriptions: ['An intimate evening with the kitchen team\'s latest seasonal menu.', 'Seven courses of precise, considered cooking. Paired wines available.', 'The chef opens the counter for an exclusive dinner service.'] },
    { kind: 'tapas_crawl', category: 'food', titleTemplates: ['Fine Tapas Tour — {neighborhood}', 'Premium Pintxos Evening in {neighborhood}'], descriptions: ['A curated route through the neighbourhood\'s best food counters.', 'Small plates at three spots — quality over quantity.'] },
    { kind: 'wine_tasting', category: 'drinks', titleTemplates: ['Wine Pairing Dinner at {venue}', 'Sommelier Night — {neighborhood}'], descriptions: ['Six wines matched to a seasonal menu.', 'The house sommelier guides you through a regional tasting.'] },
  ],
  genz: [
    { kind: 'tapas_crawl', category: 'food', titleTemplates: ['BCN Street Food Saturday — {neighborhood}', 'Tapas Crawl: {neighborhood} Edition'], descriptions: ['Start at the market, hit five spots, end with a cocktail.', 'The neighbourhood\'s tastiest cheap eats in two hours.'] },
    { kind: 'flea_market', category: 'markets', titleTemplates: ['Pop-Up Market @ {venue}', 'Sunday Market — {neighborhood}'], descriptions: ['Local designers, vintage finds, and street food.', 'The neighbourhood\'s best pop-up. Come early for the good stuff.'] },
    { kind: 'gallery_opening', category: 'art', titleTemplates: ['Opening Night: {venue}', 'Vernissage @ {venue}'], descriptions: ['Free drinks, new work, the art crowd.', 'Opening night for the new exhibition. Free entry.'] },
    { kind: 'cocktail_class', category: 'drinks', titleTemplates: ['Cocktail Masterclass @ {venue}', 'BCN Mixology Evening'], descriptions: ['Learn three classics, drink everything you make.', 'The bar team shares their recipes. Hands-on session.'] },
  ],
  poblenou: [
    { kind: 'gallery_opening', category: 'art', titleTemplates: ['Open Studios — Poblenou', 'Hangar Open Night'], descriptions: ['Artists open their studio doors. Come see what\'s being made in the 22@.', 'The production centre opens for a public evening of work-in-progress.'] },
    { kind: 'market_tour', category: 'markets', titleTemplates: ['Palo Alto Market Weekend', 'Poblenou Design Market'], descriptions: ['Monthly design and lifestyle market inside the Palo Alto complex.', 'Local makers, designers, and food producers.'] },
    { kind: 'run_club', category: 'community', titleTemplates: ['Poblenou Morning Run Club', 'Bogatell Beach Run'], descriptions: ['8km seafront run starting from the Rambla del Poblenou.', 'Sunday morning group run along the Olympic coast.'] },
  ],
  streetfood: [
    { kind: 'tapas_crawl', category: 'food', titleTemplates: ['Vermut & Tapas — {neighborhood}', 'Bodega Hop: {neighborhood}', 'Classic Tapas Tour — {neighborhood}'], descriptions: ['Sunday vermu tour through the best neighbourhood bodegas.', 'Three bodegas, three vermuts, three plates of anchoas.', 'The essential neighbourhood tapas crawl.'] },
    { kind: 'market_tour', category: 'markets', titleTemplates: ['Boqueria Early Morning Tour', 'Mercat de Santa Caterina Visit'], descriptions: ['Pre-tourist-hour Boqueria visit with a local guide.', 'Navigate the Santa Caterina market with a chef.'] },
  ],
  art: [
    { kind: 'gallery_opening', category: 'art', titleTemplates: ['Opening: {venue}', 'Vernissage — {neighborhood}', 'Exhibition Launch at {venue}'], descriptions: ['New exhibition opens. Free entry and drinks.', 'The artist in attendance. An evening with the work.', 'Launch event for the season\'s new programme.'] },
    { kind: 'street_art_tour', category: 'art', titleTemplates: ['Street Art Walk — {neighborhood}', 'Mural Tour: {neighborhood}'], descriptions: ['Two-hour walk through the neighbourhood\'s best outdoor art.', 'Guided tour of the murals and their makers.'] },
    { kind: 'film_screening', category: 'art', titleTemplates: ['Outdoor Cinema — {neighborhood}', 'Film Night @ {venue}'], descriptions: ['Classic film projected in a courtyard. Bring your own drinks.', 'Outdoor screening with an introduction from the programmer.'] },
  ],
  music: [
    { kind: 'jazz_night', category: 'music', titleTemplates: ['Jazz Night @ {venue}', 'Live Jazz — {neighborhood}', 'Wednesday Jazz @ {venue}'], descriptions: ['Two sets from the resident quartet. Doors at 9, first set at 10.', 'Straight-ahead jazz in the neighbourhood\'s best small venue.', 'The Wednesday jazz session. Walk-in before midnight.'] },
    { kind: 'dj_set', category: 'music', titleTemplates: ['DJ Set @ {venue}', '{venue} Club Night', 'Electronic Night — {neighborhood}'], descriptions: ['Four hours from a resident DJ. The dancefloor opens at midnight.', 'Electronic music in the venue\'s best room.', 'The monthly electronic session.'] },
  ],
  traditional: [
    { kind: 'tapas_crawl', category: 'food', titleTemplates: ['Catalan Classics Tour — {neighborhood}', 'Traditional Bodega Evening'], descriptions: ['Three stops, three classic Catalan plates, one neighbourhood.', 'An evening in the old bodegas of the Gothic Quarter.'] },
    { kind: 'market_tour', category: 'markets', titleTemplates: ['Mercat de la Boqueria — Early Birds', 'Santa Caterina Market Tour'], descriptions: ['6am market visit with a local chef. What the professionals buy.', 'Guided tour of the most authentic market in the city.'] },
  ],
  fitness: [
    { kind: 'run_club', category: 'community', titleTemplates: ['Sunday Run Club — Bogatell', 'Morning 5K — {neighborhood}', 'Sunrise Run — Bunkers del Carmel'], descriptions: ['8km seafront run. All paces welcome. Coffee after at La Pepita.', '5km neighbourhood loop. Meet at the park entrance.', 'Sunrise run to the bunkers and back. 7am sharp.'] },
    { kind: 'yoga_park', category: 'community', titleTemplates: ['Yoga in Ciutadella Park', 'Outdoor Yoga — Bogatell Beach', 'Sunrise Yoga — Montjuïc'], descriptions: ['One-hour vinyasa flow in the park. Mat provided if needed.', 'Beach yoga at sunrise. Bring your own mat.', 'Yoga with a city view. 7am, free, all levels.'] },
  ],
  wine: [
    { kind: 'wine_tasting', category: 'drinks', titleTemplates: ['Natural Wine Evening @ {venue}', 'Winemaker Dinner — {neighborhood}', 'Biodynamic Tasting @ {venue}'], descriptions: ['Six natural wines with the importer. Producers who actually farm.', 'The winemaker is in town. Dinner and a tasting.', 'Biodynamic producers from Catalonia and beyond.'] },
    { kind: 'cocktail_class', category: 'drinks', titleTemplates: ['Cocktail Workshop @ {venue}', 'Classic Cocktails Masterclass'], descriptions: ['Make three cocktails with the head bartender. Drink them all.', 'The classics, done properly. A two-hour hands-on session.'] },
  ],
  coffee: [
    { kind: 'coffee_workshop', category: 'cafe', titleTemplates: ['Coffee Cupping @ {venue}', 'Barista Workshop — {neighborhood}', 'Filter Coffee Morning @ {venue}'], descriptions: ['Cupping session with the roaster. Taste six origins blind.', 'Learn espresso technique from a certified barista.', 'Guided filter coffee morning. Three methods, six coffees.'] },
    { kind: 'language_exchange', category: 'community', titleTemplates: ['Digital Nomad Meetup @ {venue}', 'Café Meetup — {neighborhood}'], descriptions: ['Monthly gathering for remote workers. Bring a laptop or just a coffee.', 'Language exchange in a café setting. Spanish and English.'] },
  ],
};

// ---------------------------------------------------------------------------
// Collection templates per role/niche
// ---------------------------------------------------------------------------

interface CollectionDef {
  name: string;
  description: string;
  visibility: CollectionVisibility;
}

const PRO_COLLECTIONS_BY_NICHE: Record<string, CollectionDef[]> = {
  finedining: [
    { name: 'Barcelona\'s Best Tasting Menus', description: 'Worth every euro and every booking battle.', visibility: 'public' },
    { name: 'Chef\'s Counter Experiences', description: 'The most intimate dining experiences in the city.', visibility: 'public' },
    { name: 'Michelin Barcelona', description: 'Every starred restaurant we\'ve reviewed.', visibility: 'public' },
    { name: 'Natural Wine Dinners', description: 'Where the food and wine list match.', visibility: 'public' },
    { name: 'Seafood and Rice', description: 'The best paellas and caldosos in Barcelona.', visibility: 'public' },
    { name: 'Classic Catalan', description: 'Old-school cooking that hasn\'t been ruined by trends.', visibility: 'public' },
    { name: 'Bar Dining', description: 'Counter eating and high-top excellence.', visibility: 'public' },
    { name: 'Hidden Gems', description: 'Places that need no reservation, yet.', visibility: 'public' },
    { name: 'Private Dining Rooms', description: 'For when you need the whole space.', visibility: 'friends' },
    { name: 'Saved for Later', description: 'Places to revisit and review properly.', visibility: 'private' },
    { name: 'Opening Soon', description: 'New restaurants on the radar.', visibility: 'private' },
  ],
  genz: [
    { name: 'Trending Now BCN', description: 'What everyone is talking about this week.', visibility: 'public' },
    { name: 'Best Brunches', description: 'Saturday mornings sorted.', visibility: 'public' },
    { name: 'Instagrammable Spots', description: 'Not ashamed. These places are genuinely beautiful.', visibility: 'public' },
    { name: 'Free Things to Do', description: 'Culture, markets, and outdoor events with no ticket price.', visibility: 'public' },
    { name: 'Nightlife Route', description: 'The perfect Friday night, start to finish.', visibility: 'public' },
    { name: 'Coffee Shops to Work From', description: 'Good wifi, good coffee, no one staring.', visibility: 'public' },
    { name: 'BCN for Visitors', description: 'What we send people when they arrive.', visibility: 'public' },
    { name: 'Pop-Ups and Collabs', description: 'Short-life events that won\'t come back.', visibility: 'public' },
    { name: 'BCN Cheap Eats', description: 'Under 15 euros. Seriously good.', visibility: 'public' },
    { name: 'Events Calendar', description: 'What\'s happening this month.', visibility: 'public' },
    { name: 'Team Favourites', description: 'Editorial picks from the Que Pasa team.', visibility: 'friends' },
  ],
  poblenou: [
    { name: 'Poblenou in 48 Hours', description: 'My perfect Poblenou weekend, hour by hour.', visibility: 'public' },
    { name: 'Creative Studios — Poblenou', description: 'Where to find artists and designers at work.', visibility: 'public' },
    { name: 'Best of the Rambla', description: 'Every terrace worth sitting at on the Rambla del Poblenou.', visibility: 'public' },
    { name: 'Poblenou Coffee Route', description: 'Three cafés, one morning, zero regrets.', visibility: 'public' },
    { name: 'Poblenou Night Life', description: 'From sunset to last call along the Olympic coast.', visibility: 'public' },
    { name: '22@ Design Week Picks', description: 'The innovation district\'s best programming.', visibility: 'public' },
    { name: 'Beach & Sea', description: 'The Poblenou coastline from Bogatell to Mar Bella.', visibility: 'public' },
    { name: 'Local Eats', description: 'No tourists, all neighbourhood.', visibility: 'public' },
    { name: 'Markets & Makers', description: 'Palo Alto, Encants, and the studio open days.', visibility: 'public' },
    { name: 'Collab Spots', description: 'Spaces available for events and productions.', visibility: 'friends' },
    { name: 'Research — New Openings', description: 'Poblenou\'s newest spots under investigation.', visibility: 'private' },
  ],
  streetfood: [
    { name: 'Bodegas That Matter', description: 'The surviving old bodegas of Barcelona. Drink here.', visibility: 'public' },
    { name: 'Best Tapas Bars', description: 'Ranked by the quality of the patatas bravas.', visibility: 'public' },
    { name: 'Sunday Vermouth Route', description: 'The ideal Sunday from 12pm to 4pm.', visibility: 'public' },
    { name: 'Market Food Counters', description: 'Every mercat counter worth queuing at.', visibility: 'public' },
    { name: 'Cheap Eats', description: 'Under 10 euros. Genuinely good.', visibility: 'public' },
    { name: 'Bocadillo Map', description: 'The city\'s best sandwiches, mapped.', visibility: 'public' },
    { name: 'Bar Crawl Route — Barceloneta', description: 'From noon to dark along the waterfront.', visibility: 'public' },
    { name: 'Gràcia Bodegas', description: 'The neighbourhood with the best density of great local bars.', visibility: 'public' },
    { name: 'Hidden Counters', description: 'Spots you have to know about.', visibility: 'public' },
    { name: 'Tourist Traps to Avoid', description: 'What not to eat and where.', visibility: 'friends' },
    { name: 'My Favourites', description: 'Personal saves.', visibility: 'private' },
  ],
  art: [
    { name: 'Best Free Exhibitions', description: 'Culture doesn\'t have to cost money in Barcelona.', visibility: 'public' },
    { name: 'Museum Must-Visits', description: 'The permanent collections worth returning to.', visibility: 'public' },
    { name: 'Gallery Map — Eixample', description: 'The commercial gallery district on foot.', visibility: 'public' },
    { name: 'Street Art Barcelona', description: 'The best murals and outdoor work in the city.', visibility: 'public' },
    { name: 'Photography Shows', description: 'The city\'s best photography programming.', visibility: 'public' },
    { name: 'Opening Nights Calendar', description: 'Vernissages and launch events.', visibility: 'public' },
    { name: 'Art + Dinner Evenings', description: 'Gallery, then nearby restaurant. The full evening.', visibility: 'public' },
    { name: 'Emerging Artists', description: 'Under-40 artists making work in the city.', visibility: 'public' },
    { name: 'Studio Visits', description: 'Artists who occasionally open their studios.', visibility: 'friends' },
    { name: 'Upcoming Research', description: 'Exhibitions and artists to write about.', visibility: 'private' },
    { name: 'Archive', description: 'Shows that have closed but should be remembered.', visibility: 'private' },
  ],
  music: [
    { name: 'Best Live Venues', description: 'Ranked by sound, sight lines, and soul.', visibility: 'public' },
    { name: 'Jazz Nights', description: 'Every jazz club and session in the city.', visibility: 'public' },
    { name: 'Electronic Music Guide', description: 'From Razzmatazz to the underground.', visibility: 'public' },
    { name: 'Intimate Gig Spots', description: 'Small venues where music gets close.', visibility: 'public' },
    { name: 'Classical BCN', description: 'Palau de la Música and beyond.', visibility: 'public' },
    { name: 'Summer Festivals', description: 'Primavera, Sonar, and the smaller ones that matter.', visibility: 'public' },
    { name: 'After Hours', description: 'Where the gig ends and the night continues.', visibility: 'public' },
    { name: 'Upcoming Gigs', description: 'Shows worth getting tickets for now.', visibility: 'public' },
    { name: 'Latin Music', description: 'Rumba, salsa, and everything in between.', visibility: 'public' },
    { name: 'Sets to Catch', description: 'DJs and artists I\'m following.', visibility: 'friends' },
    { name: 'Notes', description: 'Research and venue notes.', visibility: 'private' },
  ],
  traditional: [
    { name: 'Catalan Classics', description: 'The restaurants that have been here forever and will outlast all of us.', visibility: 'public' },
    { name: 'Festes Majors Guide', description: 'Every neighbourhood festival and its best bar.', visibility: 'public' },
    { name: 'Mercat Guide', description: 'Every market in Barcelona worth visiting.', visibility: 'public' },
    { name: 'Traditional Cafès', description: 'The granges and cafès that make Barcelona Barcelona.', visibility: 'public' },
    { name: 'Calçotada Season', description: 'Where to eat calçots from January to March.', visibility: 'public' },
    { name: 'Cava Routes', description: 'Penedès, Anoia, and the caves of Sant Sadurní.', visibility: 'public' },
    { name: 'History and Food', description: 'Restaurants inside historic buildings.', visibility: 'public' },
    { name: 'Traditional Bars', description: 'Bars that opened before 1970 and haven\'t changed.', visibility: 'public' },
    { name: 'Craft Producers', description: 'Artisan food and drink producers worth seeking out.', visibility: 'public' },
    { name: 'Old Neighbourhood Walks', description: 'Routes through the oldest parts of the city.', visibility: 'friends' },
    { name: 'Research', description: 'Traditions to document and protect.', visibility: 'private' },
  ],
  fitness: [
    { name: 'Best Run Routes', description: 'From the waterfront to Collserola — the routes that matter.', visibility: 'public' },
    { name: 'Outdoor Yoga Spots', description: 'Parks, rooftops, and beaches for a morning practice.', visibility: 'public' },
    { name: 'Sports Facilities', description: 'The city\'s municipal courts, pools, and gyms.', visibility: 'public' },
    { name: 'Post-Workout Nutrition', description: 'Smoothie bars, açaí spots, and recovery cafés.', visibility: 'public' },
    { name: 'Beach Sports', description: 'Volleyball, paddleboarding, and open-water swimming.', visibility: 'public' },
    { name: 'Climbing Walls', description: 'Indoor and outdoor climbing in and around BCN.', visibility: 'public' },
    { name: 'BCN Hiking Trails', description: 'Day hikes accessible by metro and regional train.', visibility: 'public' },
    { name: 'Padel Courts', description: 'The best padel facilities in each neighbourhood.', visibility: 'public' },
    { name: 'Recovery Spots', description: 'Saunas, float tanks, and massage therapists.', visibility: 'public' },
    { name: 'Run Club Spots', description: 'Meeting points for the city\'s running groups.', visibility: 'friends' },
    { name: 'Personal Training Notes', description: 'Locations for outdoor sessions.', visibility: 'private' },
  ],
  wine: [
    { name: 'Natural Wine Bars BCN', description: 'Every bar with a serious natural wine list.', visibility: 'public' },
    { name: 'Speakeasy Guide', description: 'Hidden bars and cocktail basements. Don\'t tell everyone.', visibility: 'public' },
    { name: 'Classic Cocktail Bars', description: 'The original Barcelona cocktail bars. Still the best.', visibility: 'public' },
    { name: 'Vermouth Bars', description: 'Where to drink vermu in this city.', visibility: 'public' },
    { name: 'Wine Shops', description: 'The best wine retail in Barcelona.', visibility: 'public' },
    { name: 'Catalan Producers', description: 'Winemakers from the Penedès, Priorat, and DOQ Empordà.', visibility: 'public' },
    { name: 'Gin & Tonic Route', description: 'Spanish gin, tonic, and garnish.', visibility: 'public' },
    { name: 'Wine Dinners', description: 'Pairing events and producer evenings.', visibility: 'public' },
    { name: 'Bottle Shop to Bar Route', description: 'Buy a bottle, drink it here.', visibility: 'public' },
    { name: 'Staff Picks', description: 'What I\'m drinking this week.', visibility: 'friends' },
    { name: 'Cellar Notes', description: 'Private notes on producers and bottles.', visibility: 'private' },
  ],
  coffee: [
    { name: 'Specialty Coffee BCN', description: 'The definitive guide to specialty coffee in Barcelona.', visibility: 'public' },
    { name: 'Best Work Cafés', description: 'Laptop-friendly, excellent coffee, no judgement.', visibility: 'public' },
    { name: 'Roasters Guide', description: 'Every roaster based in or shipping to BCN.', visibility: 'public' },
    { name: 'Filter Coffee Tour', description: 'For those who prefer slow extraction.', visibility: 'public' },
    { name: 'Morning Espresso Route', description: 'The best espresso bars for a pre-work hit.', visibility: 'public' },
    { name: 'Brunch & Coffee', description: 'Where the food matches the coffee.', visibility: 'public' },
    { name: 'Coffee Shops by Neighbourhood', description: 'Your local, curated.', visibility: 'public' },
    { name: 'Barista Competitions', description: 'Events and competitions in the speciality coffee world.', visibility: 'public' },
    { name: 'Afternoon Cafés', description: 'Somewhere to sit, think, and drink a good filter.', visibility: 'public' },
    { name: 'Coffee Community', description: 'BCN coffee people worth following.', visibility: 'friends' },
    { name: 'Bean Notes', description: 'Roaster and origin research.', visibility: 'private' },
  ],
};

const AMATEUR_COLLECTIONS: CollectionDef[][] = [
  // 11 - Rosa
  [{ name: 'Brunch Dates', description: 'Weekend mornings with the girls.', visibility: 'public' }, { name: 'Terrace Season', description: 'Every terrace worth sitting at in BCN.', visibility: 'public' }, { name: 'Finde Plans', description: 'What to do this weekend.', visibility: 'friends' }, { name: 'Saved for Later', description: 'Places to try.', visibility: 'private' }],
  // 12 - Kai
  [{ name: 'BCN Ramen & Asian', description: 'Finding the best Asian food in the city.', visibility: 'public' }, { name: 'Work From Here', description: 'Cafés that actually have good wifi.', visibility: 'public' }, { name: 'Weekend Bike Routes', description: 'Great cycling spots around Barcelona.', visibility: 'friends' }],
  // 13 - Aïda
  [{ name: 'Family-Friendly Barcelona', description: 'Places that survive two toddlers.', visibility: 'public' }, { name: 'Parks & Playgrounds', description: 'Every playground I\'ve rated in BCN.', visibility: 'public' }, { name: 'Rainy Day Plans', description: 'When the weather kills the park plan.', visibility: 'friends' }, { name: 'Birthday Venues', description: 'Places for kids\' birthdays.', visibility: 'private' }, { name: 'Kid-Friendly Restaurants', description: 'No side-eye from the waiter.', visibility: 'public' }],
  // 14 - Leo
  [{ name: 'Morning Run Spots', description: 'The routes I come back to.', visibility: 'public' }, { name: 'Beach Volleyball Courts', description: 'Every court in BCN and the surrounding coast.', visibility: 'public' }, { name: 'Post-Run Recovery', description: 'Cafés and food for after a long run.', visibility: 'friends' }],
  // 15 - Mireia
  [{ name: 'Natural Wine Bars', description: 'My personal hit list.', visibility: 'public' }, { name: 'Wine & Dinner', description: 'The full evening.', visibility: 'friends' }, { name: 'Bottles to Try', description: 'Wine list items I\'m hunting down.', visibility: 'private' }, { name: 'Saved Collections', description: 'Collections from people I trust.', visibility: 'private' }],
  // 16 - Nico
  [{ name: 'Live Music Diary', description: 'Gigs I\'ve seen and want to see.', visibility: 'public' }, { name: 'Razzmatazz Pre-Game', description: 'Dinner and bars before a Razz night.', visibility: 'friends' }, { name: 'Jazz Nights', description: 'Wednesday jazz, forever.', visibility: 'public' }],
  // 17 - Julia
  [{ name: 'Free Art BCN', description: 'Culture without a budget.', visibility: 'public' }, { name: 'Open Studios', description: 'Artists who share their space.', visibility: 'public' }, { name: 'Art + Drinks', description: 'Gallery opening, then the nearest bar.', visibility: 'friends' }],
  // 18 - Benji
  [{ name: 'Best Brunch in Barcelona', description: 'Personal rankings updated monthly.', visibility: 'public' }, { name: 'Pastry Tour', description: 'The croissants and cakes that matter.', visibility: 'public' }, { name: 'Coffee & Work', description: 'Where I actually get things done.', visibility: 'public' }, { name: 'Secret Finds', description: 'Too good to tell everyone.', visibility: 'private' }],
  // 19 - Sara
  [{ name: 'Flea Markets BCN', description: 'Every market, ranked by finds.', visibility: 'public' }, { name: 'Vintage Shops', description: 'The best second-hand clothing.', visibility: 'public' }, { name: 'Sunday Market Route', description: 'From Encants to Sant Antoni.', visibility: 'friends' }],
  // 20 - Marc
  [{ name: 'Date Night BCN', description: 'Tested and approved for important evenings.', visibility: 'public' }, { name: 'Architecture & Food', description: 'Restaurants inside beautiful spaces.', visibility: 'public' }, { name: 'New Openings', description: 'Places worth investigating.', visibility: 'private' }],
  // 21 - Lila
  [{ name: 'Wellness Barcelona', description: 'The city\'s best yoga, meditation, and healing spaces.', visibility: 'public' }, { name: 'Healthy Eats', description: 'Genuinely nutritious food in BCN.', visibility: 'public' }, { name: 'Quiet Corners', description: 'For when you need to breathe.', visibility: 'private' }],
  // 22 - Pau
  [{ name: 'Gòtic Hidden Spots', description: 'My neighbourhood, its secrets.', visibility: 'public' }, { name: 'History Walks', description: 'Where Roman Barcelona meets medieval.', visibility: 'public' }, { name: 'Old Barcelona', description: 'The city before 1992.', visibility: 'friends' }],
  // 23 - Olga
  [{ name: 'BCN Expat Essentials', description: 'What I wished I\'d known in year one.', visibility: 'public' }, { name: 'Coworking & Coffee', description: 'A working expat\'s office map.', visibility: 'public' }, { name: 'Weekend Brunch', description: 'Sunday plans.', visibility: 'friends' }],
  // 24 - David
  [{ name: 'Climbing BCN', description: 'All walls, all levels.', visibility: 'public' }, { name: 'Trail Running', description: 'Collserola and beyond.', visibility: 'public' }, { name: 'Post-Climb Eats', description: 'Caloric recovery spots.', visibility: 'friends' }],
  // 25 - Inès
  [{ name: 'Design Barcelona', description: 'The city\'s most beautiful spaces.', visibility: 'public' }, { name: 'Architecture Walks', description: 'Eixample blocks and beyond.', visibility: 'public' }, { name: 'Design Shops', description: 'Furniture, objects, and the things I can\'t afford.', visibility: 'private' }],
  // 26 - Carles
  [{ name: 'Padel Spots BCN', description: 'Every court, reviewed.', visibility: 'public' }, { name: 'Beach Sports', description: 'Volleyball, SUP, and beach football.', visibility: 'public' }, { name: 'Sports Bars', description: 'Where to watch the match.', visibility: 'friends' }],
  // 27 - Valentina
  [{ name: 'Best DJ Sets BCN', description: 'What I\'ve danced to and what\'s coming.', visibility: 'public' }, { name: 'Pre-Party Spots', description: 'Dinner and drinks before the club.', visibility: 'friends' }, { name: 'After Hours', description: 'Dawn in Barcelona.', visibility: 'private' }],
  // 28 - Henry
  [{ name: 'Bookshops BCN', description: 'English, Spanish, and Catalan.', visibility: 'public' }, { name: 'Quiet Cafés', description: 'Where to read and think.', visibility: 'public' }, { name: 'Literary Barcelona', description: 'Where the writers drank.', visibility: 'public' }],
  // 29 - Clara T.
  [{ name: 'Sunday Mercat Route', description: 'From breakfast to lunch via three markets.', visibility: 'public' }, { name: 'Artisan Food', description: 'The producers worth paying for.', visibility: 'public' }, { name: 'Market Saves', description: 'Things to buy before they sell out.', visibility: 'private' }],
  // 30 - Finn
  [{ name: 'Late Night Eats', description: 'Good food after midnight.', visibility: 'public' }, { name: 'After-Hours Bars', description: 'Still open after 3am.', visibility: 'friends' }, { name: 'Industry Spots', description: 'Where the hospitality people eat and drink.', visibility: 'private' }],
];

// ---------------------------------------------------------------------------
// Plan templates (amateurs and followers)
// ---------------------------------------------------------------------------

interface PlanDef {
  name: string;
  daysOffset: number; // from TODAY; negative = past
  duration: number;   // in days
}

const AMATEUR_PLANS: PlanDef[][] = [
  // 11 - Rosa
  [{ name: 'Mamá en Barcelona', daysOffset: 14, duration: 3 }, { name: 'Cumpleaños de Sandra', daysOffset: -30, duration: 1 }, { name: 'Finde romántico mayo', daysOffset: 45, duration: 2 }, { name: 'Visita de la abuela — marzo', daysOffset: -48, duration: 2 }],
  // 12 - Kai
  [{ name: 'Cousin visiting May', daysOffset: 25, duration: 3 }, { name: 'Golden Week solo explore', daysOffset: -20, duration: 2 }, { name: 'Montjuïc Sunday', daysOffset: 7, duration: 1 }],
  // 13 - Aïda
  [{ name: 'Easter Week with Kids', daysOffset: 5, duration: 5 }, { name: 'Grandparents visit', daysOffset: 60, duration: 4 }, { name: 'Rainy Sunday Plan', daysOffset: -14, duration: 1 }, { name: 'Birthday party planning', daysOffset: -7, duration: 1 }],
  // 14 - Leo
  [{ name: 'Marathon Training Week', daysOffset: 10, duration: 5 }, { name: 'Valencia weekend run', daysOffset: -45, duration: 2 }, { name: 'Collserola hike day', daysOffset: 20, duration: 1 }],
  // 15 - Mireia
  [{ name: 'Penedès wine trip', daysOffset: 30, duration: 2 }, { name: 'Natural wine week BCN', daysOffset: -60, duration: 5 }, { name: 'Saturday wine tour', daysOffset: 8, duration: 1 }, { name: 'Friends birthday dinner', daysOffset: 42, duration: 1 }],
  // 16 - Nico
  [{ name: 'Primavera Sound Weekend', daysOffset: 35, duration: 3 }, { name: 'Last month\'s gig diary', daysOffset: -15, duration: 5 }, { name: 'Brothers visiting — Razz', daysOffset: 21, duration: 2 }],
  // 17 - Julia
  [{ name: 'Gallery Week May', daysOffset: 20, duration: 5 }, { name: 'MACBA retrospective day', daysOffset: -8, duration: 1 }, { name: 'Open Studios Sunday', daysOffset: 6, duration: 1 }],
  // 18 - Benji
  [{ name: 'Brunch Week Challenge', daysOffset: 5, duration: 7 }, { name: 'Sant Antoni Brunch Map', daysOffset: -30, duration: 1 }, { name: 'Friends from Berlin', daysOffset: 50, duration: 3 }, { name: 'Pastry tour Saturday', daysOffset: 3, duration: 1 }],
  // 19 - Sara
  [{ name: 'Flea Market Weekend', daysOffset: 7, duration: 2 }, { name: 'Vintage haul — March', daysOffset: -50, duration: 2 }, { name: 'Sunday market loop', daysOffset: 14, duration: 1 }],
  // 20 - Marc
  [{ name: 'Anniversary Dinner', daysOffset: 3, duration: 1 }, { name: 'Valentines — where we went', daysOffset: -64, duration: 1 }, { name: 'Her birthday weekend', daysOffset: 55, duration: 2 }, { name: 'New restaurant hunt', daysOffset: 28, duration: 1 }],
  // 21 - Lila
  [{ name: 'Wellness Retreat Week', daysOffset: 40, duration: 5 }, { name: 'Yoga & Beach Morning', daysOffset: -10, duration: 1 }, { name: 'Recovery weekend', daysOffset: 12, duration: 2 }],
  // 22 - Pau
  [{ name: 'Gothic Quarter Walk', daysOffset: 2, duration: 1 }, { name: 'History tour for visitors', daysOffset: -20, duration: 1 }, { name: 'Neighbourhood festival', daysOffset: 90, duration: 5 }],
  // 23 - Olga
  [{ name: 'First Month Exploring', daysOffset: -180, duration: 30 }, { name: 'Moscow friends visiting', daysOffset: 70, duration: 4 }, { name: 'Saturday coworking + lunch', daysOffset: 5, duration: 1 }],
  // 24 - David
  [{ name: 'Climbing Week', daysOffset: 15, duration: 5 }, { name: 'Montserrat day trip', daysOffset: -25, duration: 1 }, { name: 'Pyrenees weekend', daysOffset: 80, duration: 2 }],
  // 25 - Inès
  [{ name: 'Architecture Walk Weekend', daysOffset: 8, duration: 2 }, { name: 'Design week BCN', daysOffset: 65, duration: 4 }, { name: 'MNAC visit — March', daysOffset: -35, duration: 1 }],
  // 26 - Carles
  [{ name: 'Padel Tournament Prep', daysOffset: 18, duration: 3 }, { name: 'Beach volleyball season opener', daysOffset: 10, duration: 1 }, { name: 'Last season highlights', daysOffset: -40, duration: 1 }],
  // 27 - Valentina
  [{ name: 'Sónar Weekend', daysOffset: 55, duration: 3 }, { name: 'Last month\'s best nights', daysOffset: -20, duration: 4 }, { name: 'Italian friends visiting', daysOffset: 30, duration: 2 }, { name: 'Saturday night plan', daysOffset: 6, duration: 1 }],
  // 28 - Henry
  [{ name: 'Bookshop Saturday', daysOffset: 5, duration: 1 }, { name: 'Literary Barcelona walk', daysOffset: -15, duration: 1 }, { name: 'Writing retreat week', daysOffset: 45, duration: 5 }],
  // 29 - Clara T.
  [{ name: 'Mercat Sunday Loop', daysOffset: 7, duration: 1 }, { name: 'Spring market season', daysOffset: 20, duration: 5 }, { name: 'Boqueria tour — last week', daysOffset: -7, duration: 1 }],
  // 30 - Finn
  [{ name: 'Late Night BCN Week', daysOffset: 5, duration: 5 }, { name: 'Industry dinner March', daysOffset: -30, duration: 1 }, { name: 'Summer cocktail tour', daysOffset: 70, duration: 3 }],
];

const FOLLOWER_PLANS: PlanDef[][] = [
  // 31 - Sergi
  [{ name: 'Anniversary dinner', daysOffset: 3, duration: 1 }, { name: 'Cousin BCN trip', daysOffset: 30, duration: 3 }],
  // 32 - Elena
  [{ name: 'First month exploring', daysOffset: -100, duration: 30 }, { name: 'Work trip Eixample', daysOffset: 10, duration: 2 }],
  // 33 - Omar
  [{ name: 'Erasmus week one', daysOffset: -140, duration: 5 }, { name: 'Weekend with Marrakech friends', daysOffset: 40, duration: 2 }],
  // 34 - Jessie
  [{ name: 'Design tour weekend', daysOffset: 5, duration: 2 }, { name: 'MACBA + Palau day', daysOffset: -10, duration: 1 }],
  // 35 - Tom
  [{ name: 'Remote work month BCN', daysOffset: -60, duration: 30 }, { name: 'Goodbye week', daysOffset: 25, duration: 5 }],
  // 36 - Sofia
  [{ name: 'Anniversary dinner', daysOffset: 2, duration: 1 }, { name: 'Date night collection', daysOffset: -30, duration: 1 }],
  // 37 - Martin
  [{ name: 'BCN weekend', daysOffset: 8, duration: 2 }],
  // 38 - Priya
  [{ name: 'Wellness weekend', daysOffset: 12, duration: 2 }, { name: 'Yoga retreat Saturday', daysOffset: -5, duration: 1 }],
  // 39 - Mattia
  [{ name: 'First BCN week', daysOffset: -150, duration: 7 }, { name: 'Italian friends visiting', daysOffset: 35, duration: 3 }],
  // 40 - Hana
  [{ name: 'Coffee tour Saturday', daysOffset: 3, duration: 1 }, { name: 'Korean food hunt', daysOffset: -15, duration: 2 }],
  // 41 - Bea
  [{ name: 'Gràcia festival week', daysOffset: 110, duration: 7 }, { name: 'Neighbourhood Saturday', daysOffset: 4, duration: 1 }],
  // 42 - Lukas
  [{ name: 'Primavera Sound trip', daysOffset: 40, duration: 4 }, { name: 'March gigs', daysOffset: -20, duration: 3 }],
  // 43 - Emma
  [{ name: 'Natural wine week', daysOffset: 18, duration: 5 }, { name: 'French friends in BCN', daysOffset: 55, duration: 3 }],
  // 44 - Raj
  [{ name: 'Family Barcelona trip', daysOffset: 20, duration: 7 }],
  // 45 - Clara B.
  [{ name: 'Brazilian summer in BCN', daysOffset: 60, duration: 10 }, { name: 'Beach week', daysOffset: -30, duration: 5 }],
  // 46 - Ivan
  [{ name: 'Business trip dinners', daysOffset: 5, duration: 3 }],
  // 47 - Lucía
  [{ name: 'Parrilla hunt weekend', daysOffset: 10, duration: 2 }, { name: 'Argentine friends visit', daysOffset: 45, duration: 3 }],
  // 48 - Maya L.
  [{ name: 'Honeymoon BCN', daysOffset: 5, duration: 5 }],
  // 49 - Yuki
  [{ name: 'BCN 7 days', daysOffset: 2, duration: 7 }],
  // 50 - Alex Q.
  [{ name: 'Pride month plans', daysOffset: 55, duration: 5 }, { name: 'Regular Friday night route', daysOffset: 4, duration: 1 }],
];

// ---------------------------------------------------------------------------
// Main seeder
// ---------------------------------------------------------------------------

async function main() {
  console.log('\n🌱 BCN Mock Data Seeder starting...\n');
  faker.seed(42);

  // ── 1. Wipe ────────────────────────────────────────────────────────────────
  console.log('🧹 Wiping existing data...');

  // Wipe Supabase Auth users that match seed pattern
  const { data: authList } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
  for (const u of authList?.users ?? []) {
    if (u.email?.match(/^\d+@1\.com$/)) {
      await supabaseAdmin.auth.admin.deleteUser(u.id);
    }
  }

  // Wipe Storage seed folder
  const { data: storageFiles } = await supabaseAdmin.storage.from(STORAGE_BUCKET).list(SEED_FOLDER);
  if (storageFiles && storageFiles.length > 0) {
    // List subfolders and delete
    for (const folder of storageFiles) {
      const { data: subFiles } = await supabaseAdmin.storage
        .from(STORAGE_BUCKET)
        .list(`${SEED_FOLDER}/${folder.name}`);
      if (subFiles && subFiles.length > 0) {
        const paths = subFiles.map((f) => `${SEED_FOLDER}/${folder.name}/${f.name}`);
        await supabaseAdmin.storage.from(STORAGE_BUCKET).remove(paths);
      }
    }
  }

  // Wipe Prisma (FK order)
  await prisma.planItem.deleteMany({});
  await prisma.plan.deleteMany({});
  await prisma.save.deleteMany({});
  await prisma.savedCollection.deleteMany({});
  await prisma.collectionItem.deleteMany({});
  await prisma.collection.deleteMany({});
  await prisma.mediaItem.deleteMany({});
  await prisma.follow.deleteMany({});
  await prisma.followRequest.deleteMany({});
  await prisma.event.deleteMany({});
  await prisma.spot.deleteMany({});
  await prisma.user.deleteMany({});

  console.log('✅ Wipe complete\n');

  // ── 2. Unsplash pools ──────────────────────────────────────────────────────
  console.log('📸 Fetching Unsplash photo pools...');
  const poolKeys = Object.keys(POOL_QUERIES) as PoolKey[];
  for (const key of poolKeys) {
    await fetchPool(key);
    // Small delay to avoid hitting rate limit
    await new Promise((r) => setTimeout(r, 200));
  }
  console.log(`✅ ${poolKeys.length} pools fetched\n`);

  // ── 3. Create users ────────────────────────────────────────────────────────
  console.log('👥 Creating 50 users...');
  const dbUsers: Record<number, { id: string; def: UserDef }> = {};

  for (const def of USER_ROSTER) {
    // Create Supabase Auth user
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: def.email,
      password: PASSWORD,
      email_confirm: true,
      user_metadata: { name: def.name },
    });
    if (authError) {
      console.error(`   ❌ Auth creation failed for ${def.email}: ${authError.message}`);
      continue;
    }
    const userId = authData.user!.id;

    // Profile picture
    const profilePhoto = pickPhoto(def.profilePool, `profile-${def.idx}`);
    let profilePictureUrl: string | null = null;
    if (profilePhoto) {
      profilePictureUrl = await uploadPhoto(profilePhoto.urls.small, userId);
      usedDownloadUrls.push(profilePhoto.links.download_location);
    }

    // Create Prisma user row
    const colorPalette = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A', '#98D8C8', '#DDA0DD', '#F0E68C', '#87CEEB'];
    await prisma.user.create({
      data: {
        id: userId,
        email: def.email,
        passwordHash: 'supabase-managed',
        name: def.name,
        handle: def.handle,
        initials: initials(def.name),
        color: pick(colorPalette, `color-${def.idx}`),
        bio: def.bio,
        cities: ['Barcelona'],
        selectedCity: 'Barcelona',
        profilePictureUrl,
        isPrivate: def.isPrivate,
        followerCount: 0,
        followingCount: 0,
      },
    });

    dbUsers[def.idx] = { id: userId, def };
    console.log(`   ✓ ${def.email} — @${def.handle} (${def.role})`);
  }
  console.log(`✅ ${Object.keys(dbUsers).length} users created\n`);

  // ── 4. Create spots (owned by pros 1-10) ──────────────────────────────────
  console.log('📍 Creating ~225 spots...');
  const allSpots: { id: string; category: Category; neighborhood: string }[] = [];

  for (const venue of VENUES) {
    const owner = dbUsers[venue.ownerIdx];
    if (!owner) continue;

    const spot = await prisma.spot.create({
      data: {
        ownerId: owner.id,
        name: venue.name,
        description: venue.description,
        address: venue.address,
        latitude: venue.lat,
        longitude: venue.lng,
        category: venue.category,
        neighborhood: venue.neighborhood,
        saveCount: 0,
      },
    });

    // Photos
    const photos = await photosForCategory(venue.category, owner.id, `spot-${spot.id}`);
    for (let i = 0; i < photos.length; i++) {
      await prisma.mediaItem.create({
        data: { spotId: spot.id, url: photos[i].url, type: 'photo', order: i },
      });
      usedDownloadUrls.push(photos[i].downloadLocation);
    }

    allSpots.push({ id: spot.id, category: venue.category, neighborhood: venue.neighborhood });
  }
  console.log(`✅ ${allSpots.length} spots created\n`);

  // ── 5. Create events (hosted by pros 1-10) ─────────────────────────────────
  console.log('🎉 Creating ~150 events...');
  const allEvents: { id: string; category: Category; neighborhood: string }[] = [];

  for (const [idxStr, { id: userId, def }] of Object.entries(dbUsers)) {
    const idx = Number(idxStr);
    if (idx > 10 || def.role !== 'pro') continue;

    const niche = def.niche ?? 'genz';
    const kindPool = EVENT_KINDS_BY_NICHE[niche] ?? EVENT_KINDS_BY_NICHE['genz'];
    const eventCount = 15 + Math.floor(seededRand(`ec-${idx}`) * 4); // 15-18

    // Pick venues owned by this pro for event locations
    const proVenues = VENUES.filter((v) => v.ownerIdx === idx);

    for (let i = 0; i < eventCount; i++) {
      const kindDef = pick(kindPool, `kind-${idx}-${i}`);
      const venue = proVenues[i % proVenues.length];

      // Timing: 15% past (last 60 days), 85% upcoming (next 180 days)
      const r = seededRand(`timing-${idx}-${i}`);
      let startTime: Date;
      if (r < 0.15) {
        startTime = daysFrom(TODAY, -Math.floor(r * 400));
      } else {
        startTime = daysFrom(TODAY, Math.floor((r - 0.15) * 212));
      }
      const startHour = 18 + Math.floor(seededRand(`hour-${idx}-${i}`) * 6); // 18-23
      startTime.setHours(startHour, 0, 0, 0);
      const endTime = hoursFrom(startTime, 2 + Math.floor(seededRand(`dur-${idx}-${i}`) * 3));

      const titleTemplate = pick(kindDef.titleTemplates, `title-${idx}-${i}`);
      const title = titleTemplate
        .replace('{venue}', venue?.name ?? 'TBC')
        .replace('{neighborhood}', venue?.neighborhood ?? 'Barcelona');

      const event = await prisma.event.create({
        data: {
          userId,
          title,
          description: pick(kindDef.descriptions, `desc-${idx}-${i}`),
          category: kindDef.category,
          address: venue?.address ?? 'Barcelona',
          neighborhood: venue?.neighborhood ?? 'Barcelona',
          latitude: venue?.lat ?? 41.3851,
          longitude: venue?.lng ?? 2.1734,
          startTime,
          endTime,
          saveCount: 0,
        },
      });

      const photos = await photosForEvent(kindDef.kind, userId, `event-${event.id}`);
      for (let j = 0; j < photos.length; j++) {
        await prisma.mediaItem.create({
          data: { eventId: event.id, url: photos[j].url, type: 'photo', order: j },
        });
        usedDownloadUrls.push(photos[j].downloadLocation);
      }

      allEvents.push({ id: event.id, category: kindDef.category, neighborhood: venue?.neighborhood ?? 'Barcelona' });
    }

    console.log(`   ✓ Pro ${idx} (${def.handle}) — events created`);
  }
  console.log(`✅ ${allEvents.length} events created\n`);

  // ── 6. Create collections ──────────────────────────────────────────────────
  console.log('📚 Creating collections...');
  const allCollections: Record<number, { id: string; userId: string }[]> = {};

  // Pro collections
  for (const [idxStr, { id: userId, def }] of Object.entries(dbUsers)) {
    const idx = Number(idxStr);
    if (idx > 10 || def.role !== 'pro') continue;

    const niche = def.niche ?? 'genz';
    const collDefs = PRO_COLLECTIONS_BY_NICHE[niche] ?? PRO_COLLECTIONS_BY_NICHE['genz'];

    allCollections[idx] = [];
    for (const collDef of collDefs) {
      const coll = await prisma.collection.create({
        data: {
          userId,
          name: collDef.name,
          description: collDef.description,
          visibility: collDef.visibility,
        },
      });
      allCollections[idx].push({ id: coll.id, userId });
    }
  }

  // Amateur collections
  for (const [idxStr, { id: userId }] of Object.entries(dbUsers)) {
    const idx = Number(idxStr);
    if (idx < 11 || idx > 30) continue;

    const amateurIdx = idx - 11;
    const collDefs = AMATEUR_COLLECTIONS[amateurIdx] ?? AMATEUR_COLLECTIONS[0];

    allCollections[idx] = [];
    for (const collDef of collDefs) {
      const coll = await prisma.collection.create({
        data: {
          userId,
          name: collDef.name,
          description: collDef.description,
          visibility: collDef.visibility,
        },
      });
      allCollections[idx].push({ id: coll.id, userId });
    }
  }

  const totalColls = Object.values(allCollections).flat().length;
  console.log(`✅ ${totalColls} collections created\n`);

  // ── 7. Pro cross-saves ─────────────────────────────────────────────────────
  console.log('💾 Creating pro cross-saves...');
  let totalSaves = 0;

  // Each pro saves 25-30 spots/events from other pros
  for (const [idxStr, { id: userId }] of Object.entries(dbUsers)) {
    const idx = Number(idxStr);
    if (idx > 10) continue;

    const otherProSpots = allSpots.filter((s) => {
      const ownerIdx = VENUES.find((v) => v.name === s.id)?.ownerIdx ?? 0;
      return ownerIdx !== idx;
    });
    const shuffledSpots = shuffle(allSpots).slice(0, 28);
    const shuffledEvents = shuffle(allEvents).slice(0, 10);
    const myCollections = allCollections[idx] ?? [];

    for (const spot of shuffledSpots) {
      const coll = myCollections.length > 0 ? pick(myCollections.filter((c) => c.userId === userId)) : null;
      try {
        await prisma.save.create({
          data: { userId, itemType: 'spot', itemId: spot.id, collectionId: coll?.id ?? null },
        });
        if (coll) {
          await prisma.collectionItem.create({
            data: { collectionId: coll.id, itemType: 'spot', itemId: spot.id, order: totalSaves },
          });
        }
        await prisma.spot.update({ where: { id: spot.id }, data: { saveCount: { increment: 1 } } });
        totalSaves++;
      } catch { /* duplicate save — skip */ }
    }

    for (const event of shuffledEvents) {
      const coll = myCollections.length > 0 ? pick(myCollections.filter((c) => c.userId === userId)) : null;
      try {
        await prisma.save.create({
          data: { userId, itemType: 'event', itemId: event.id, collectionId: coll?.id ?? null },
        });
        if (coll) {
          await prisma.collectionItem.create({
            data: { collectionId: coll.id, itemType: 'event', itemId: event.id, order: totalSaves },
          });
        }
        await prisma.event.update({ where: { id: event.id }, data: { saveCount: { increment: 1 } } });
        totalSaves++;
      } catch { /* skip */ }
    }
  }
  console.log(`   ✓ Pro cross-saves: ${totalSaves}\n`);

  // ── 8. Amateur saves ───────────────────────────────────────────────────────
  console.log('💾 Amateur and follower saves...');

  // Helper to upsert a save
  async function saveItem(userId: string, itemType: 'spot' | 'event', itemId: string, collId: string | null) {
    try {
      await prisma.save.create({ data: { userId, itemType, itemId, collectionId: collId } });
      if (collId) {
        await prisma.collectionItem.upsert({
          where: { id: `${collId}-${itemType}-${itemId}` },
          update: {},
          create: { collectionId: collId, itemType, itemId, order: totalSaves },
        }).catch(() => {
          return prisma.collectionItem.create({
            data: { collectionId: collId, itemType, itemId, order: totalSaves },
          });
        });
      }
      if (itemType === 'spot') {
        await prisma.spot.update({ where: { id: itemId }, data: { saveCount: { increment: 1 } } });
      } else {
        await prisma.event.update({ where: { id: itemId }, data: { saveCount: { increment: 1 } } });
      }
      totalSaves++;
    } catch { /* duplicate */ }
  }

  // Amateur saves: 30+ spots, 5-10 events, 1-3 public pro collections
  for (const [idxStr, { id: userId }] of Object.entries(dbUsers)) {
    const idx = Number(idxStr);
    if (idx < 11 || idx > 30) continue;

    const spotCount = 30 + Math.floor(seededRand(`sc-${idx}`) * 15);
    const eventCount = 5 + Math.floor(seededRand(`ec-am-${idx}`) * 6);
    const myColls = allCollections[idx] ?? [];
    const publicMyColls = myColls;

    const pickedSpots = shuffle(allSpots).slice(0, spotCount);
    for (const spot of pickedSpots) {
      const coll = publicMyColls.length > 0 ? (Math.random() < 0.6 ? pick(publicMyColls) : null) : null;
      await saveItem(userId, 'spot', spot.id, coll?.id ?? null);
    }

    const pickedEvents = shuffle(allEvents).slice(0, eventCount);
    for (const event of pickedEvents) {
      const coll = publicMyColls.length > 0 ? (Math.random() < 0.4 ? pick(publicMyColls) : null) : null;
      await saveItem(userId, 'event', event.id, coll?.id ?? null);
    }

    // Save 1-3 public pro collections
    const allProColls = Object.entries(allCollections)
      .filter(([k]) => Number(k) <= 10)
      .flatMap(([, cs]) => cs);
    const colCountToSave = 1 + Math.floor(seededRand(`cc-${idx}`) * 3);
    const proCollsToSave = shuffle(allProColls).slice(0, colCountToSave);
    for (const pc of proCollsToSave) {
      try {
        await prisma.savedCollection.create({ data: { userId, collectionId: pc.id } });
      } catch { /* skip */ }
    }
  }

  // Follower saves: 10-15 spots, 5-8 events, 2-5 pro collections
  for (const [idxStr, { id: userId }] of Object.entries(dbUsers)) {
    const idx = Number(idxStr);
    if (idx < 31) continue;

    const spotCount = 10 + Math.floor(seededRand(`sc-f-${idx}`) * 6);
    const eventCount = 5 + Math.floor(seededRand(`ec-f-${idx}`) * 4);

    const pickedSpots = shuffle(allSpots).slice(0, spotCount);
    for (const spot of pickedSpots) {
      await saveItem(userId, 'spot', spot.id, null);
    }

    const pickedEvents = shuffle(allEvents).slice(0, eventCount);
    for (const event of pickedEvents) {
      await saveItem(userId, 'event', event.id, null);
    }

    // Save 2-5 public pro collections
    const allProColls = Object.entries(allCollections)
      .filter(([k]) => Number(k) <= 10)
      .flatMap(([, cs]) => cs);
    const colCountToSave = 2 + Math.floor(seededRand(`cc-f-${idx}`) * 4);
    const proCollsToSave = shuffle(allProColls).slice(0, colCountToSave);
    for (const pc of proCollsToSave) {
      try {
        await prisma.savedCollection.create({ data: { userId, collectionId: pc.id } });
      } catch { /* skip */ }
    }
  }

  console.log(`✅ Total saves: ${totalSaves}\n`);

  // ── 9. Follow graph ────────────────────────────────────────────────────────
  console.log('👥 Building follow graph...');

  const userIdsByRole: { pros: string[]; amateurs: string[]; followers: string[] } = {
    pros: [], amateurs: [], followers: [],
  };
  for (const [idxStr, { id, def }] of Object.entries(dbUsers)) {
    if (def.role === 'pro') userIdsByRole.pros.push(id);
    else if (def.role === 'amateur') userIdsByRole.amateurs.push(id);
    else userIdsByRole.followers.push(id);
  }

  async function follow(followerId: string, followingId: string) {
    if (followerId === followingId) return;
    try {
      await prisma.follow.create({ data: { followerId, followingId } });
    } catch { /* already follows */ }
  }

  // Pros: follow 10-15 other pros + 5 amateurs
  for (const proId of userIdsByRole.pros) {
    const otherPros = shuffle(userIdsByRole.pros.filter((id) => id !== proId)).slice(0, 10);
    const someAmateurs = shuffle(userIdsByRole.amateurs).slice(0, 5);
    for (const id of [...otherPros, ...someAmateurs]) await follow(proId, id);
  }

  // Amateurs: follow all 10 pros + 10-20 other amateurs + 5 followers
  for (const amateurId of userIdsByRole.amateurs) {
    const others = shuffle(userIdsByRole.amateurs.filter((id) => id !== amateurId)).slice(0, 15);
    const someFollowers = shuffle(userIdsByRole.followers).slice(0, 5);
    for (const id of [...userIdsByRole.pros, ...others, ...someFollowers]) await follow(amateurId, id);
  }

  // Followers: follow all 10 pros + 15-30 amateurs + some followers
  for (const followerId of userIdsByRole.followers) {
    const someAmateurs = shuffle(userIdsByRole.amateurs).slice(0, 20);
    const someFollowers = shuffle(userIdsByRole.followers.filter((id) => id !== followerId)).slice(0, 10);
    for (const id of [...userIdsByRole.pros, ...someAmateurs, ...someFollowers]) await follow(followerId, id);
  }

  // Recompute follower/following counts
  for (const { id: userId } of Object.values(dbUsers)) {
    const followerCount = await prisma.follow.count({ where: { followingId: userId } });
    const followingCount = await prisma.follow.count({ where: { followerId: userId } });
    await prisma.user.update({ where: { id: userId }, data: { followerCount, followingCount } });
  }

  const totalFollows = await prisma.follow.count();
  console.log(`✅ ${totalFollows} follow relationships created\n`);

  // ── 10. Plans ──────────────────────────────────────────────────────────────
  console.log('📅 Creating plans...');
  let totalPlans = 0;

  async function createPlan(userId: string, planDef: PlanDef) {
    const startDate = daysFrom(TODAY, planDef.daysOffset);
    const endDate = daysFrom(startDate, Math.max(0, planDef.duration - 1));

    const plan = await prisma.plan.create({
      data: { userId, name: planDef.name, startDate, endDate },
    });

    // Add 3-8 items to the plan (mix of spots and events)
    const itemCount = 3 + Math.floor(seededRand(`pi-${plan.id}`) * 6);
    const planSpots = shuffle(allSpots).slice(0, Math.ceil(itemCount * 0.6));
    const planEvents = shuffle(allEvents).slice(0, Math.floor(itemCount * 0.4));
    let order = 0;

    for (const spot of planSpots) {
      const day = Math.floor(seededRand(`pd-${plan.id}-${order}`) * Math.max(1, planDef.duration));
      await prisma.planItem.create({
        data: { planId: plan.id, itemType: 'spot', itemId: spot.id, dayOffset: day, order: order++ },
      });
    }
    for (const event of planEvents) {
      const day = Math.floor(seededRand(`ped-${plan.id}-${order}`) * Math.max(1, planDef.duration));
      await prisma.planItem.create({
        data: { planId: plan.id, itemType: 'event', itemId: event.id, dayOffset: day, order: order++ },
      });
    }

    totalPlans++;
  }

  for (const [idxStr, { id: userId, def }] of Object.entries(dbUsers)) {
    const idx = Number(idxStr);
    if (def.role === 'pro') continue;

    if (def.role === 'amateur') {
      const plans = AMATEUR_PLANS[idx - 11] ?? [];
      for (const planDef of plans) await createPlan(userId, planDef);
    } else {
      const plans = FOLLOWER_PLANS[idx - 31] ?? [];
      for (const planDef of plans) await createPlan(userId, planDef);
    }
  }

  console.log(`✅ ${totalPlans} plans created\n`);

  // ── 11. Unsplash download tracking pings ──────────────────────────────────
  if (UNSPLASH_KEY && usedDownloadUrls.length > 0) {
    console.log(`📡 Firing ${usedDownloadUrls.length} Unsplash download tracking pings...`);
    for (const url of usedDownloadUrls) {
      void fetch(url, { headers: { Authorization: `Client-ID ${UNSPLASH_KEY}` } });
      await new Promise((r) => setTimeout(r, 50)); // Non-blocking fire-and-forget
    }
    console.log('✅ Tracking pings sent\n');
  }

  // ── 12. Final counts ───────────────────────────────────────────────────────
  const [userCount, spotCount, eventCount, collCount, planCount, saveCount, followCount] = await Promise.all([
    prisma.user.count(),
    prisma.spot.count(),
    prisma.event.count(),
    prisma.collection.count(),
    prisma.plan.count(),
    prisma.save.count(),
    prisma.follow.count(),
  ]);

  console.log('\n═══════════════════════════════════════════════');
  console.log('✅ SEED COMPLETE');
  console.log('═══════════════════════════════════════════════');
  console.log(`   Users:         ${userCount}`);
  console.log(`   Spots:         ${spotCount}`);
  console.log(`   Events:        ${eventCount}`);
  console.log(`   Collections:   ${collCount}`);
  console.log(`   Plans:         ${planCount}`);
  console.log(`   Saves:         ${saveCount}`);
  console.log(`   Follows:       ${followCount}`);
  console.log('═══════════════════════════════════════════════\n');

  console.log('LOGIN REFERENCE (password for all: Password123)');
  console.log('─────────────────────────────────────────────────────────────────');
  const header = 'EMAIL'.padEnd(16) + 'ROLE'.padEnd(12) + 'HANDLE'.padEnd(28) + 'NAME';
  console.log(header);
  console.log('─────────────────────────────────────────────────────────────────');
  for (const def of USER_ROSTER) {
    const roleLabel = def.role === 'pro' ? 'PRO' : def.role === 'amateur' ? 'AMATEUR' : 'FOLLOWER';
    console.log(
      def.email.padEnd(16) +
      roleLabel.padEnd(12) +
      `@${def.handle}`.padEnd(28) +
      def.name
    );
  }
  console.log('─────────────────────────────────────────────────────────────────\n');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

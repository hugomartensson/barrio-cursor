/**
 * BCN Extra Events Seeder
 *
 * Additive script — runs against an already-seeded database.
 * Looks up existing users (1@1.com–50@1.com) and spots, then creates
 * 200 spring/summer events (April 27 – June 15 2026):
 *   - 10 pros  × 10 events = 100
 *   - 20 amateurs × 5 events = 100
 *
 * Priority kinds: concert, dj_set, flea_market, market_tour
 *
 * Usage:
 *   UNSPLASH_ACCESS_KEY=xxx npm run seed:bcn:events
 */

import 'dotenv/config';
import { PrismaClient, Category } from '@prisma/client';
import { createClient } from '@supabase/supabase-js';
import { randomUUID } from 'crypto';

const prisma = new PrismaClient();

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

const STORAGE_BUCKET = process.env.SUPABASE_STORAGE_BUCKET ?? 'media';
const UNSPLASH_KEY = process.env.UNSPLASH_ACCESS_KEY ?? '';
const SEED_FOLDER = 'seed-bcn-extra';

// April 19 anchor (same as original seed)
const ANCHOR = new Date('2026-04-19T12:00:00Z');
// Window: April 27 (+8 days) to June 15 (+57 days)
const WINDOW_START_DAY = 8;
const WINDOW_END_DAY = 57;
const WINDOW_DAYS = WINDOW_END_DAY - WINDOW_START_DAY; // 49

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function daysFrom(base: Date, d: number): Date {
  return new Date(base.getTime() + d * 86_400_000);
}

function hoursFrom(base: Date, h: number): Date {
  return new Date(base.getTime() + h * 3_600_000);
}

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

// ---------------------------------------------------------------------------
// Unsplash
// ---------------------------------------------------------------------------

interface UnsplashPhoto {
  id: string;
  urls: { regular: string };
  links: { download_location: string };
}

type PoolKey =
  | 'music-venue' | 'music-club' | 'music-jazz'
  | 'markets-flea' | 'markets-produce'
  | 'food-tapas' | 'food-plated' | 'food-streetfood'
  | 'drinks-bar' | 'drinks-cocktail' | 'drinks-wine'
  | 'art-gallery' | 'art-streetart'
  | 'event-running' | 'event-meetup' | 'event-winetasting' | 'event-outdoor' | 'event-bartender'
  | 'cafe-coffee' | 'cafe-interior'
  | 'community-yoga';

const POOL_QUERIES: Record<PoolKey, string> = {
  'music-venue':       'music venue stage concert',
  'music-club':        'nightclub crowd dj',
  'music-jazz':        'jazz club live band',
  'markets-flea':      'flea market vintage',
  'markets-produce':   'farmers market produce food',
  'food-tapas':        'tapas bar spanish',
  'food-plated':       'restaurant food plated dish',
  'food-streetfood':   'street food market stall',
  'drinks-bar':        'bar interior',
  'drinks-cocktail':   'cocktail drink glass',
  'drinks-wine':       'wine bar',
  'art-gallery':       'art gallery white wall',
  'art-streetart':     'street art mural',
  'event-running':     'running group city',
  'event-meetup':      'group friends restaurant',
  'event-winetasting': 'wine tasting dinner',
  'event-outdoor':     'outdoor cinema night',
  'event-bartender':   'bartender making cocktail',
  'cafe-coffee':       'coffee latte art cup',
  'cafe-interior':     'coffee shop interior',
  'community-yoga':    'yoga outdoor class',
};

const photoPool: Partial<Record<PoolKey, UnsplashPhoto[]>> = {};
const usedDownloadUrls: string[] = [];

async function fetchPool(key: PoolKey): Promise<void> {
  if (!UNSPLASH_KEY) {
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
    console.warn(`   ⚠️  uploadPhoto failed: ${e}`);
    return sourceUrl;
  }
}

async function photosForKind(
  kind: string,
  userId: string,
  seedSuffix: string
): Promise<{ url: string; downloadLocation: string }[]> {
  const specs: { key: PoolKey; n: number }[] = (() => {
    switch (kind) {
      case 'concert':          return [{ key: 'music-venue', n: 2 }, { key: 'music-club', n: 1 }];
      case 'dj_set':           return [{ key: 'music-club', n: 2 }];
      case 'jazz_night':       return [{ key: 'music-jazz', n: 1 }, { key: 'music-venue', n: 1 }];
      case 'flea_market':      return [{ key: 'markets-flea', n: 2 }];
      case 'market_tour':      return [{ key: 'markets-produce', n: 1 }, { key: 'food-streetfood', n: 1 }];
      case 'tapas_crawl':      return [{ key: 'food-tapas', n: 1 }, { key: 'drinks-bar', n: 1 }];
      case 'tasting_menu':     return [{ key: 'food-plated', n: 2 }];
      case 'wine_tasting':     return [{ key: 'event-winetasting', n: 1 }, { key: 'drinks-wine', n: 1 }];
      case 'cocktail_class':   return [{ key: 'event-bartender', n: 1 }, { key: 'drinks-cocktail', n: 1 }];
      case 'gallery_opening':  return [{ key: 'art-gallery', n: 1 }, { key: 'event-meetup', n: 1 }];
      case 'street_art_tour':  return [{ key: 'art-streetart', n: 2 }];
      case 'run_club':         return [{ key: 'event-running', n: 2 }];
      case 'yoga_park':        return [{ key: 'community-yoga', n: 2 }];
      case 'language_exchange':return [{ key: 'event-meetup', n: 2 }];
      case 'film_screening':   return [{ key: 'event-outdoor', n: 2 }];
      case 'coffee_workshop':  return [{ key: 'cafe-coffee', n: 1 }, { key: 'cafe-interior', n: 1 }];
      default:                 return [{ key: 'event-meetup', n: 2 }];
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

// ---------------------------------------------------------------------------
// Event kind definitions
// ---------------------------------------------------------------------------

interface KindDef {
  kind: string;
  category: Category;
  titles: string[];
  descriptions: string[];
}

const KIND_DEFS: Record<string, KindDef> = {
  concert: {
    kind: 'concert', category: 'music',
    titles: [
      'Live @ {venue} — May', 'Spring Concert Series: {venue}', 'One Night Only @ {venue}',
      'Live Show — {neighborhood}', 'Primavera Warm-Up: {venue}', 'Summer Gig @ {venue}',
      'Live Music Night @ {venue}', '{venue} Presents: Live', 'May Concert Series — {neighborhood}',
      'Live Session @ {venue}', 'Concert Night — {neighborhood}', 'BCN Live @ {venue}',
    ],
    descriptions: [
      'One night, one stage. Doors at 8, music at 9.',
      'Live from Barcelona. An evening of honest music at one of the city\'s best rooms.',
      'The band is in town. This is the one not to miss.',
      'A sold-out night of live sound and energy. Last tickets at the door.',
      'Raw, live, and loud. Come early, stay late.',
      'Primavera Sound warm-up vibes — live on the {neighborhood} stage.',
      'An intimate live session in a room that rewards proper listening.',
      'The stage is small. The music is not.',
      'Every summer starts with a live show. This is yours.',
      'An evening of high-quality live music in one of BCN\'s hidden rooms.',
    ],
  },
  dj_set: {
    kind: 'dj_set', category: 'music',
    titles: [
      'Club Night @ {venue}', 'DJ Set — {venue} Terrace', 'Saturday Night @ {venue}',
      'Primavera After-Party @ {venue}', 'Late Night Sessions — {neighborhood}',
      'Opening Party: {venue}', 'Rooftop Sessions @ {venue}', 'Night Out — {venue}',
      'Summer Terrace DJ Night @ {venue}', 'All Night @ {venue}', 'Back to {venue}',
      'Friday Night: {venue}', 'Terrace Sessions — {neighborhood}', 'May Club Night @ {venue}',
    ],
    descriptions: [
      'The DJ starts at midnight. The terrace opens at 10.',
      'Resident DJ, terrace bar, Barcelona skyline. That\'s all you need.',
      'A proper club night — dark room, good sound, no nonsense.',
      'Primavera is over. The after-party is just starting.',
      'Late-night sessions at one of Barcelona\'s favourite rooms.',
      'From sunset to sunrise. Free entry before 11.',
      'The city doesn\'t sleep. Neither does {venue}.',
      'Electronic music on the terrace. Barcelona summer mode: on.',
      'Opening season party — come for the set, stay for the sunrise.',
      'House, disco, and the occasional left-turn. Standard Saturday.',
    ],
  },
  flea_market: {
    kind: 'flea_market', category: 'markets',
    titles: [
      'Encants Spring Special', 'Sant Antoni Sunday Flea', 'Vintage & Makers Market — {neighborhood}',
      'Spring Flea @ {venue}', 'Pop-Up Flea Market — {neighborhood}', 'Design & Vintage — May',
      'Sunday Flea @ {neighborhood}', 'BCN Flea Market — {venue}', 'Spring Market — {neighborhood}',
      'Makers & Vintage Fair @ {venue}', 'Weekend Flea — {neighborhood}', 'Open-Air Flea @ {venue}',
    ],
    descriptions: [
      'Vintage clothing, vinyl, ceramics, and the occasional gem. Every Sunday.',
      'Sixty stalls of secondhand and handmade. Arrive early for the good stuff.',
      'Local makers meet weekend hunters. Street food included.',
      'The city\'s best flea — open-air, spring edition.',
      'Encants-style chaos. Bring cash, leave with something you didn\'t expect.',
      'Ceramics, textiles, furniture, vinyl. A proper rummage.',
      'Handmade goods, vintage finds, and Barcelona sunshine.',
      'Two hundred stalls. Zero guarantees. That\'s the point.',
      'The neighbourhood comes out for this one. Arrive at 10, stay for lunch.',
      'Rare finds and local makers in one of the city\'s best courtyards.',
    ],
  },
  market_tour: {
    kind: 'market_tour', category: 'markets',
    titles: [
      'Boqueria Morning Market Tour', 'Food Market Walk — {neighborhood}',
      'Street Food Saturday @ {neighborhood}', 'La Barceloneta Food Market',
      'Producers Market — {venue}', 'Spring Harvest Market — {neighborhood}',
      'Morning Market Walk @ {venue}', 'BCN Food Market — {neighborhood}',
      'Seasonal Produce Market @ {venue}', 'Sunday Food Market — {neighborhood}',
      'Market Morning — {venue}', 'Artisan Food Fair @ {neighborhood}',
    ],
    descriptions: [
      'Fresh produce, local vendors, and the best breakfast the city has to offer.',
      'A guided walk through the neighbourhood\'s market. Tastings included.',
      'Street food stalls, seasonal produce, and local makers. Free entry.',
      'The best of what\'s growing right now. Farm-to-stall, every weekend.',
      'Market morning at its finest — cheese, cured meats, and fresh veg.',
      'A slow Saturday at the food market. Bring a bag and leave with dinner.',
      'Local producers, seasonal tastings, and the kind of bread you can\'t buy at a supermarket.',
      'Spring produce at its peak. The growers are here in person.',
      'Artisan food, fresh fish, and Catalan wines. One stop, everything you need.',
      'Morning market culture — everything is fresh, everything is local.',
    ],
  },
  jazz_night: {
    kind: 'jazz_night', category: 'music',
    titles: [
      'Jazz al Fresc — {venue}', 'Open-Air Jazz Night @ {neighborhood}',
      'Wednesday Jazz @ {venue}', 'Spring Jazz Sessions — {venue}',
      'Jazz Night — {neighborhood}', 'Live Jazz @ {venue}',
    ],
    descriptions: [
      'Wednesday night jazz in the best room in town. Doors at 8.',
      'Outdoor jazz as the sun goes down. Free, informal, beautiful.',
      'The quartet plays from 9. Terrace bar open from 7.',
      'Jazz standards and originals in an intimate space. Limited capacity.',
      'Open-air jazz on a warm spring evening. Bring a blanket if you want a seat.',
    ],
  },
  tapas_crawl: {
    kind: 'tapas_crawl', category: 'food',
    titles: [
      'El Born Terrace Crawl', 'Gràcia Vermouth Tour — Spring Edition',
      'Spring Tapas Route — {neighborhood}', 'Bar Crawl: {neighborhood}',
      'Terrace Tapas Night — {neighborhood}', 'Pintxos & Vermouth @ {neighborhood}',
    ],
    descriptions: [
      'Three bars, six tapas, one neighbourhood. Start at 7, end whenever.',
      'Vermouth, patatas bravas, and sunshine on the terrace. Spring is here.',
      'A self-guided crawl through the best pintxos bars in the barrio.',
      'El Born in the spring is exactly as good as it sounds.',
      'Late afternoon tapas, terrace tables, and the neighbourhood in full bloom.',
    ],
  },
  wine_tasting: {
    kind: 'wine_tasting', category: 'drinks',
    titles: [
      'Rosé & Terrace Evening @ {venue}', 'Natural Wine Saturday — {neighborhood}',
      'Spring Wine Tasting @ {venue}', 'Winemaker Dinner — {venue}',
      'Terrace Wine Night @ {venue}', 'Natural Wine Fair — {neighborhood}',
    ],
    descriptions: [
      'Six natural wines, the winemaker in person, and a terrace with a view.',
      'Rosé season is officially open. Terrace tables, chilled bottles, long evening.',
      'A curated selection of Catalan and Spanish producers. Tastings from 7pm.',
      'The winemaker is in town for one night. Limited seats.',
      'Natural wine, cheese board, and the best sunset in the neighbourhood.',
    ],
  },
  gallery_opening: {
    kind: 'gallery_opening', category: 'art',
    titles: [
      'Summer Exhibition Opens @ {venue}', 'Group Show Vernissage — {neighborhood}',
      'Opening Night @ {venue}', 'Spring Vernissage — {venue}',
      'New Show @ {venue}', 'Exhibition Launch — {neighborhood}',
    ],
    descriptions: [
      'Free drinks, new work, the art crowd. Opening night at one of BCN\'s best spaces.',
      'Group show vernissage — ten artists, one room, free entry.',
      'The exhibition opens tonight. Come for the work, stay for the conversation.',
      'A summer show of new painting, sculpture, and photography. Free and open to all.',
      'Opening night: meet the artists, see the work, drink the wine.',
    ],
  },
  tasting_menu: {
    kind: 'tasting_menu', category: 'food',
    titles: [
      'Spring Menu Debut — {venue}', 'Seasonal Tasting Night @ {venue}',
      'Chef\'s Spring Menu @ {venue}', 'New Tasting Menu — {venue}',
    ],
    descriptions: [
      'Seven courses built around what\'s in season right now. Paired wines available.',
      'The spring menu launches tonight. Intimate counter seating, full kitchen view.',
      'Seasonal, precise, and worth every euro. Book in advance.',
      'Chef unveils the new spring menu. One seating only.',
    ],
  },
  street_art_tour: {
    kind: 'street_art_tour', category: 'art',
    titles: [
      'Poblenou Murals Walking Tour', 'Raval Street Art Route — May Edition',
      'BCN Street Art Walk — {neighborhood}', 'Mural Tour @ {neighborhood}',
    ],
    descriptions: [
      'Two hours, fifteen murals, the stories behind them. Free walking tour.',
      'Raval\'s walls are its gallery. This is the guided version.',
      'Poblenou has more street art per square metre than anywhere in Europe. Come see it.',
      'A self-guided tour of the neighbourhood\'s best outdoor art.',
    ],
  },
  run_club: {
    kind: 'run_club', category: 'community',
    titles: [
      'Sunrise 5K — Bogatell Beach', 'Montjuïc Trail Run — May',
      'Morning Run Club @ {neighborhood}', 'Sunday Group Run — {neighborhood}',
    ],
    descriptions: [
      'Early morning 5K along the seafront. All paces welcome, coffee after.',
      'Montjuïc trail run — 8km loop, stunning views, terrible hills.',
      'Sunday morning run through the neighbourhood. Meet at the park entrance at 8am.',
      'Sunrise run club: we meet, we run, we eat pastries. In that order.',
    ],
  },
  yoga_park: {
    kind: 'yoga_park', category: 'community',
    titles: [
      'Ciutadella Morning Flow — June', 'Beach Yoga @ Mar Bella',
      'Outdoor Yoga @ {neighborhood}', 'Morning Yoga — {venue}',
    ],
    descriptions: [
      'One hour of morning yoga in Ciutadella. Mat provided if needed.',
      'Beach yoga at sunrise. Bring your own mat and sunscreen.',
      'Outdoor vinyasa in the park. Free, all levels, Sundays.',
      'Morning yoga with a view. 7am, donation-based.',
    ],
  },
  language_exchange: {
    kind: 'language_exchange', category: 'community',
    titles: [
      'Springtime Language Meetup @ {venue}', 'BCN Polyglots — May Edition',
      'Language Exchange — {neighborhood}', 'Conversation Night @ {venue}',
    ],
    descriptions: [
      'Spanish, Catalan, English, whatever you\'ve got. Weekly language meetup.',
      'Polyglots of Barcelona: come speak, listen, and meet new people.',
      'No structured lessons. Just conversation, coffee, and language.',
      'Language exchange every week. Bring your Spanish, take home some English.',
    ],
  },
  film_screening: {
    kind: 'film_screening', category: 'art',
    titles: [
      'Open-Air Cinema Kickoff @ {neighborhood}', 'Rooftop Film Night — {venue}',
      'Outdoor Screening @ {venue}', 'Summer Cinema — {neighborhood}',
    ],
    descriptions: [
      'Open-air cinema season is officially open. Bring a blanket, bring a friend.',
      'Rooftop screening with city views. Bar open from 8, film at 10.',
      'Classic film under the Barcelona sky. Free entry, seats are first come.',
      'Summer cinema in the best courtyard in the neighbourhood.',
    ],
  },
  coffee_workshop: {
    kind: 'coffee_workshop', category: 'cafe',
    titles: [
      'Cold Brew Workshop @ {venue}', 'Spring Specialty Coffee Morning',
      'Barista Workshop @ {venue}', 'Coffee Cupping — {venue}',
    ],
    descriptions: [
      'Cold brew season starts now. Learn the method, take home the recipe.',
      'A morning of specialty coffee: cupping, tasting, and the science behind it all.',
      'The head barista runs through everything. Hands-on, small group.',
      'Coffee cupping session — six origins, one morning, no bad cups.',
    ],
  },
  cocktail_class: {
    kind: 'cocktail_class', category: 'drinks',
    titles: [
      'Summer Cocktail Workshop @ {venue}', 'Aperitivo Hour Masterclass',
      'Cocktail Class — {venue}', 'Mixology Evening @ {venue}',
    ],
    descriptions: [
      'Learn to make three summer classics. Drink everything you shake.',
      'Aperitivo season: negroni, spritz, and the one they\'re not supposed to share.',
      'The bar team teaches you the good stuff. Hands-on, two hours, very messy.',
      'Cocktail masterclass with the head bartender. Limited to 12.',
    ],
  },
};

// ---------------------------------------------------------------------------
// Weighted kind pool — heavier weight on priority kinds
// ---------------------------------------------------------------------------

const KIND_WEIGHTS: string[] = [
  ...Array(35).fill('concert'),
  ...Array(33).fill('dj_set'),
  ...Array(28).fill('flea_market'),
  ...Array(25).fill('market_tour'),
  ...Array(14).fill('jazz_night'),
  ...Array(14).fill('tapas_crawl'),
  ...Array(12).fill('wine_tasting'),
  ...Array(10).fill('gallery_opening'),
  ...Array(6).fill('tasting_menu'),
  ...Array(6).fill('street_art_tour'),
  ...Array(6).fill('run_club'),
  ...Array(4).fill('yoga_park'),
  ...Array(4).fill('language_exchange'),
  ...Array(5).fill('film_screening'),
  ...Array(5).fill('coffee_workshop'),
  ...Array(3).fill('cocktail_class'),
];

// Per-user kind overrides: 50% from this list, 50% from global pool
const AMATEUR_KIND_BIAS: Record<number, string[]> = {
  11: ['tapas_crawl', 'flea_market', 'market_tour'],
  12: ['language_exchange', 'concert', 'coffee_workshop'],
  13: ['flea_market', 'market_tour', 'run_club'],
  14: ['run_club', 'concert', 'yoga_park'],
  15: ['wine_tasting', 'market_tour', 'tapas_crawl'],
  16: ['concert', 'dj_set', 'jazz_night'],
  17: ['gallery_opening', 'concert', 'street_art_tour'],
  18: ['flea_market', 'tapas_crawl', 'coffee_workshop'],
  19: ['flea_market', 'market_tour', 'street_art_tour'],
  20: ['tasting_menu', 'market_tour', 'wine_tasting'],
  21: ['yoga_park', 'concert', 'run_club'],
  22: ['market_tour', 'flea_market', 'tapas_crawl'],
  23: ['concert', 'dj_set', 'film_screening'],
  24: ['run_club', 'yoga_park', 'concert'],
  25: ['wine_tasting', 'concert', 'tapas_crawl'],
  26: ['concert', 'jazz_night', 'dj_set'],
  27: ['gallery_opening', 'flea_market', 'market_tour'],
  28: ['coffee_workshop', 'flea_market', 'tapas_crawl'],
  29: ['language_exchange', 'film_screening', 'concert'],
  30: ['tapas_crawl', 'market_tour', 'flea_market'],
};

const PRO_KIND_BIAS: Record<number, string[]> = {
  1:  ['tasting_menu', 'wine_tasting', 'market_tour', 'concert'],          // finedining
  2:  ['dj_set', 'concert', 'flea_market', 'tapas_crawl'],                 // genz
  3:  ['concert', 'dj_set', 'flea_market', 'gallery_opening'],             // poblenou
  4:  ['market_tour', 'flea_market', 'tapas_crawl', 'concert'],            // streetfood
  5:  ['gallery_opening', 'street_art_tour', 'concert', 'flea_market'],    // art
  6:  ['concert', 'jazz_night', 'dj_set'],                                 // music
  7:  ['market_tour', 'tapas_crawl', 'flea_market', 'wine_tasting'],       // traditional
  8:  ['run_club', 'yoga_park', 'concert', 'market_tour'],                 // fitness
  9:  ['wine_tasting', 'market_tour', 'concert', 'tapas_crawl'],           // wine
  10: ['coffee_workshop', 'concert', 'market_tour', 'flea_market'],        // coffee
};

function pickKind(userIdx: number, isAmateur: boolean, eventIdx: number): string {
  const bias = isAmateur ? AMATEUR_KIND_BIAS[userIdx] : PRO_KIND_BIAS[userIdx];
  // 60% from bias pool, 40% from global weights
  const r = seededRand(`kind-extra-${userIdx}-${eventIdx}`);
  if (bias && r < 0.60) {
    return pick(bias, `kind-bias-${userIdx}-${eventIdx}`);
  }
  return pick(KIND_WEIGHTS, `kind-global-${userIdx}-${eventIdx}`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log('🌱 BCN Extra Events Seeder\n');

  // ── 1. Fetch Unsplash pools ────────────────────────────────────────────────
  if (UNSPLASH_KEY) {
    console.log('📸 Fetching Unsplash photo pools...');
    const keys = Object.keys(POOL_QUERIES) as PoolKey[];
    for (const key of keys) {
      await fetchPool(key);
      await new Promise((r) => setTimeout(r, 300));
    }
    console.log('✅ Photo pools ready\n');
  } else {
    console.warn('⚠️  UNSPLASH_ACCESS_KEY not set — events will have no photos\n');
  }

  // ── 2. Look up existing users ──────────────────────────────────────────────
  console.log('👤 Looking up users...');
  const userEmails = Array.from({ length: 50 }, (_, i) => `${i + 1}@1.com`);
  const dbUsers = await prisma.user.findMany({
    where: { email: { in: userEmails } },
    select: { id: true, email: true },
  });

  const userByEmail = new Map(dbUsers.map((u) => [u.email, u.id]));
  console.log(`   ✓ Found ${userByEmail.size} users\n`);

  // ── 3. Load all spots for venue data ───────────────────────────────────────
  console.log('📍 Loading spots...');
  const allSpots = await prisma.spot.findMany({
    select: { id: true, name: true, address: true, neighborhood: true, latitude: true, longitude: true },
  });
  console.log(`   ✓ ${allSpots.length} spots loaded\n`);

  if (allSpots.length === 0) {
    throw new Error('No spots found — run seed:bcn first');
  }

  // ── 4. Generate events ─────────────────────────────────────────────────────
  console.log('🎉 Creating 200 events (April 27 – June 15 2026)...\n');
  let totalCreated = 0;

  async function createEventsForUser(
    userIdx: number,
    userId: string,
    count: number,
    isAmateur: boolean
  ) {
    for (let i = 0; i < count; i++) {
      const kind = pickKind(userIdx, isAmateur, i);
      const kindDef = KIND_DEFS[kind] ?? KIND_DEFS['concert'];

      // Random spot as venue
      const venue = pick(allSpots, `venue-extra-${userIdx}-${i}`);

      // Date within window: April 27 – June 15
      const dayOffset = WINDOW_START_DAY + Math.floor(seededRand(`day-extra-${userIdx}-${i}`) * WINDOW_DAYS);
      const startTime = daysFrom(ANCHOR, dayOffset);
      // Hour: 10–22 (broader range for markets/daytime events)
      const startHour = 10 + Math.floor(seededRand(`hour-extra-${userIdx}-${i}`) * 13);
      startTime.setHours(startHour, 0, 0, 0);
      const durationH = 1.5 + seededRand(`dur-extra-${userIdx}-${i}`) * 2.5;
      const endTime = hoursFrom(startTime, durationH);

      const titleTemplate = pick(kindDef.titles, `title-extra-${userIdx}-${i}`);
      const title = titleTemplate
        .replace('{venue}', venue.name ?? 'TBC')
        .replace('{neighborhood}', venue.neighborhood ?? 'Barcelona');

      const description = pick(kindDef.descriptions, `desc-extra-${userIdx}-${i}`)
        .replace('{neighborhood}', venue.neighborhood ?? 'Barcelona');

      const event = await prisma.event.create({
        data: {
          userId,
          spotId: venue.id,
          title,
          description,
          category: kindDef.category,
          address: venue.address,
          neighborhood: venue.neighborhood ?? 'Barcelona',
          latitude: venue.latitude,
          longitude: venue.longitude,
          startTime,
          endTime,
          saveCount: 0,
        },
      });

      const photos = await photosForKind(kind, userId, `extra-${event.id}`);
      for (let j = 0; j < photos.length; j++) {
        await prisma.mediaItem.create({
          data: { eventId: event.id, url: photos[j].url, type: 'photo', order: j },
        });
        usedDownloadUrls.push(photos[j].downloadLocation);
      }

      totalCreated++;
    }
  }

  // Pros: 10 events each
  for (let idx = 1; idx <= 10; idx++) {
    const userId = userByEmail.get(`${idx}@1.com`);
    if (!userId) { console.warn(`   ⚠️  User ${idx}@1.com not found, skipping`); continue; }
    await createEventsForUser(idx, userId, 10, false);
    console.log(`   ✓ Pro ${idx} — 10 events created`);
  }

  // Amateurs: 5 events each
  for (let idx = 11; idx <= 30; idx++) {
    const userId = userByEmail.get(`${idx}@1.com`);
    if (!userId) { console.warn(`   ⚠️  User ${idx}@1.com not found, skipping`); continue; }
    await createEventsForUser(idx, userId, 5, true);
    console.log(`   ✓ Amateur ${idx} — 5 events created`);
  }

  console.log(`\n✅ ${totalCreated} events created\n`);

  // ── 5. Unsplash download tracking pings ────────────────────────────────────
  if (UNSPLASH_KEY && usedDownloadUrls.length > 0) {
    console.log(`📡 Firing ${usedDownloadUrls.length} Unsplash tracking pings...`);
    for (const url of usedDownloadUrls) {
      void fetch(url, { headers: { Authorization: `Client-ID ${UNSPLASH_KEY}` } });
      await new Promise((r) => setTimeout(r, 50));
    }
    console.log('✅ Tracking pings sent\n');
  }

  // ── 6. Final count ─────────────────────────────────────────────────────────
  const totalEvents = await prisma.event.count();
  console.log(`📊 Total events in DB: ${totalEvents}`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  prisma.$disconnect();
  process.exit(1);
});

/**
 * Fake Data Seed Script - Barcelona Portal
 *
 * Creates realistic test data with:
 * - User types: Organizers, Connectors, Selective Planners, Lurkers, Social Connectors
 * - Barcelona-based events and spots across neighborhoods
 * - Category-specific photos (Picsum)
 * - Collections (public, friends, private) with saved items
 * - Follow relationships
 *
 * Usage:
 *   npm run seed:fake
 */

import { PrismaClient, Category } from '@prisma/client';
import { faker } from '@faker-js/faker';
import { supabaseAdmin, STORAGE_BUCKET } from '../src/services/supabase.js';

const prisma = new PrismaClient();

const USE_EXTERNAL_URLS = process.env.SEED_USE_EXTERNAL_URLS === 'true';

// ---------------------------------------------------------------------------
// Barcelona neighborhoods with coordinates
// ---------------------------------------------------------------------------

const BARCELONA_NEIGHBORHOODS = [
  { name: 'Gràcia', lat: 41.4026, lng: 2.1564 },
  { name: 'Eixample', lat: 41.3936, lng: 2.163 },
  { name: 'Barceloneta', lat: 41.3802, lng: 2.1897 },
  { name: 'Raval', lat: 41.38, lng: 2.17 },
  { name: 'Poblenou', lat: 41.402, lng: 2.203 },
  { name: 'Born', lat: 41.384, lng: 2.183 },
];

// ---------------------------------------------------------------------------
// Category-specific image sources (Picsum Photos — no API key needed)
// ---------------------------------------------------------------------------

const CATEGORY_IMAGE_SOURCES: Record<Category, string[]> = {
  food: [
    'https://picsum.photos/seed/food1/800/600',
    'https://picsum.photos/seed/restaurant/800/600',
    'https://picsum.photos/seed/tapas/800/600',
    'https://picsum.photos/seed/brunch/800/600',
    'https://picsum.photos/seed/paella/800/600',
    'https://picsum.photos/seed/bakery/800/600',
  ],
  drinks: [
    'https://picsum.photos/seed/wine/800/600',
    'https://picsum.photos/seed/cocktail/800/600',
    'https://picsum.photos/seed/bar/800/600',
    'https://picsum.photos/seed/vermut/800/600',
    'https://picsum.photos/seed/beer/800/600',
    'https://picsum.photos/seed/cafe/800/600',
  ],
  music: [
    'https://picsum.photos/seed/music1/800/600',
    'https://picsum.photos/seed/concert/800/600',
    'https://picsum.photos/seed/livemusic/800/600',
    'https://picsum.photos/seed/guitar/800/600',
    'https://picsum.photos/seed/djset/800/600',
    'https://picsum.photos/seed/flamenco/800/600',
  ],
  art: [
    'https://picsum.photos/seed/art1/800/600',
    'https://picsum.photos/seed/gallery/800/600',
    'https://picsum.photos/seed/streetart/800/600',
    'https://picsum.photos/seed/museum/800/600',
    'https://picsum.photos/seed/theater/800/600',
    'https://picsum.photos/seed/cinema/800/600',
  ],
  markets: [
    'https://picsum.photos/seed/market1/800/600',
    'https://picsum.photos/seed/flea/800/600',
    'https://picsum.photos/seed/vintage/800/600',
    'https://picsum.photos/seed/farmstand/800/600',
    'https://picsum.photos/seed/bazaar/800/600',
    'https://picsum.photos/seed/crafts/800/600',
  ],
  community: [
    'https://picsum.photos/seed/community1/800/600',
    'https://picsum.photos/seed/park/800/600',
    'https://picsum.photos/seed/games/800/600',
    'https://picsum.photos/seed/volunteer/800/600',
    'https://picsum.photos/seed/language/800/600',
    'https://picsum.photos/seed/meetup/800/600',
  ],
};

// ---------------------------------------------------------------------------
// Event templates by category
// ---------------------------------------------------------------------------

const EVENT_TEMPLATES: Record<Category, string[]> = {
  food: [
    'Tapas Crawl - {neighborhood}',
    'Restaurant Opening: {location}',
    'Brunch Meetup @ {location}',
    'Paella Workshop - {neighborhood}',
    'Food Tour: {neighborhood}',
    'Supper Club @ {location}',
  ],
  drinks: [
    'Vermut at {location}',
    'Wine Tasting Evening',
    'Cocktail Masterclass - {neighborhood}',
    'Natural Wine Pop-Up @ {location}',
    'Craft Beer Tasting - {neighborhood}',
    'Café Hopping - {neighborhood}',
  ],
  music: [
    'Live Jazz @ {location}',
    'Acoustic Session - {neighborhood}',
    'Flamenco Night @ {location}',
    'DJ Set @ {location}',
    'Vinyl Listening Session',
    'Open Mic Night - {neighborhood}',
  ],
  art: [
    'Gallery Opening: {location}',
    'Street Art Walking Tour - {neighborhood}',
    'Museum Night',
    'Theater Performance @ {location}',
    'Film Screening - {neighborhood}',
    'Ceramics Workshop @ {location}',
  ],
  markets: [
    'Flea Market - {neighborhood}',
    'Vintage Pop-Up @ {location}',
    'Artisan Market - {neighborhood}',
    'Local Farmers Market',
    'Design Market @ {location}',
    'Book Fair - {neighborhood}',
  ],
  community: [
    'Neighborhood Clean-up - {neighborhood}',
    'Language Exchange Meetup',
    'Board Game Night - {neighborhood}',
    'Community Garden Workshop',
    'Café Meetup - {neighborhood}',
    'Yoga in the Park - {neighborhood}',
  ],
};

// ---------------------------------------------------------------------------
// Spot templates by category
// ---------------------------------------------------------------------------

const SPOT_TEMPLATES: Record<Category, { names: string[]; tagSets: string[][] }> = {
  food: {
    names: [
      'Cal Pep',
      'Can Culleretes',
      'La Boqueria',
      'Bar Mut',
      'Tickets Bar',
      'Cervecería Catalana',
      'Els Quatre Gats',
    ],
    tagSets: [
      ['tapas', 'local'],
      ['seafood', 'traditional'],
      ['market', 'fresh'],
      ['wine', 'pintxos'],
    ],
  },
  drinks: {
    names: [
      'Paradiso',
      'Bobby Gin',
      'Bar Marsella',
      'Dry Martini',
      'Two Schmucks',
      'El Xampanyet',
      'La Vinateria del Call',
    ],
    tagSets: [
      ['cocktails', 'speakeasy'],
      ['gin', 'classic'],
      ['vermut', 'terrace'],
      ['wine', 'cozy'],
    ],
  },
  music: {
    names: [
      'Jamboree Jazz Club',
      'Razzmatazz',
      'Sala Apolo',
      'Harlem Jazz Club',
      'Sidecar Factory Club',
      'Moog',
      'La [2] de Apolo',
    ],
    tagSets: [
      ['jazz', 'live'],
      ['electronic', 'club'],
      ['indie', 'live'],
      ['flamenco', 'authentic'],
    ],
  },
  art: {
    names: [
      'MACBA',
      'Fundació Joan Miró',
      'CCCB',
      'Museu Picasso',
      'Arts Santa Mònica',
      'Galería Marlborough',
      'La Virreina',
    ],
    tagSets: [
      ['contemporary', 'museum'],
      ['gallery', 'exhibitions'],
      ['photography', 'installations'],
      ['street art', 'murals'],
    ],
  },
  markets: {
    names: [
      'Mercat de Sant Antoni',
      'Encants Flea Market',
      'Mercat de la Boqueria',
      'Mercat de Santa Caterina',
      'Palo Alto Market',
      'Lost & Found Market',
    ],
    tagSets: [
      ['vintage', 'flea'],
      ['food', 'fresh'],
      ['design', 'artisan'],
      ['antiques', 'books'],
    ],
  },
  community: {
    names: [
      'Parc de la Ciutadella',
      'Espai Jove La Fontana',
      'Ateneu Popular 9 Barris',
      'Can Batlló',
      'Fabra i Coats',
      'Centre Cívic Cotxeres de Sants',
    ],
    tagSets: [
      ['coworking', 'community'],
      ['garden', 'green'],
      ['social', 'events'],
      ['workshop', 'creative'],
    ],
  },
};

// ---------------------------------------------------------------------------
// Collection templates
// ---------------------------------------------------------------------------

const COLLECTION_TEMPLATES: {
  name: string;
  description: string;
  visibility: 'private' | 'friends' | 'public';
}[] = [
  { name: 'Favorites', description: 'My favorite spots and events', visibility: 'private' },
  { name: 'Date Night', description: 'Romantic spots for date nights', visibility: 'private' },
  { name: 'Best of Barcelona', description: 'Top picks in the city', visibility: 'public' },
  { name: 'Hidden Gems', description: 'Off the beaten path', visibility: 'public' },
  { name: 'Weekend Plans', description: 'Things to do this weekend', visibility: 'friends' },
  { name: 'With Visitors', description: 'Places to take friends visiting', visibility: 'friends' },
];

// ---------------------------------------------------------------------------
// User type definitions & behavior profiles
// ---------------------------------------------------------------------------

type UserType = 'organizer' | 'connector' | 'selective_planner' | 'lurker' | 'social_connector';

interface UserTypeConfig {
  count: number;
  eventsToCreate: number;
  spotsToCreate: number;
  saves: number;
  follows: number;
  collections: number;
}

const USER_TYPES: Record<UserType, UserTypeConfig> = {
  organizer: { count: 4, eventsToCreate: 7, spotsToCreate: 3, saves: 5, follows: 3, collections: 2 },
  connector: { count: 5, eventsToCreate: 0, spotsToCreate: 2, saves: 12, follows: 4, collections: 3 },
  selective_planner: { count: 4, eventsToCreate: 0, spotsToCreate: 1, saves: 3, follows: 2, collections: 1 },
  lurker: { count: 3, eventsToCreate: 0, spotsToCreate: 0, saves: 1, follows: 1, collections: 1 },
  social_connector: { count: 3, eventsToCreate: 1, spotsToCreate: 1, saves: 6, follows: 10, collections: 2 },
};

const EVENT_TAGS = ['outdoor', 'family-friendly', 'free', 'local', 'popular', 'new', 'late-night', 'daytime'];

// ---------------------------------------------------------------------------
// Category distribution for random selection
// ---------------------------------------------------------------------------

const CATEGORY_WEIGHTS: { category: Category; weight: number }[] = [
  { category: 'food', weight: 0.2 },
  { category: 'drinks', weight: 0.15 },
  { category: 'music', weight: 0.15 },
  { category: 'art', weight: 0.15 },
  { category: 'markets', weight: 0.15 },
  { category: 'community', weight: 0.2 },
];

function getRandomCategory(): Category {
  const rand = Math.random();
  let cumulative = 0;
  for (const { category, weight } of CATEGORY_WEIGHTS) {
    cumulative += weight;
    if (rand <= cumulative) return category;
  }
  return 'community';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function uploadToSupabaseStorage(sourceUrl: string, userId: string): Promise<string> {
  try {
    const response = await fetch(sourceUrl);
    if (!response.ok) throw new Error(`Failed to fetch: ${response.statusText}`);

    const buffer = Buffer.from(await response.arrayBuffer());
    const filename = `${faker.string.uuid()}.jpg`;
    const filePath = `seed-data/${userId}/${filename}`;

    const { error } = await supabaseAdmin.storage
      .from(STORAGE_BUCKET)
      .upload(filePath, buffer, { contentType: 'image/jpeg', upsert: false });

    if (error) throw error;

    const {
      data: { publicUrl },
    } = supabaseAdmin.storage.from(STORAGE_BUCKET).getPublicUrl(filePath);
    return publicUrl;
  } catch {
    console.warn(`⚠️  Upload failed for ${sourceUrl}, using direct URL`);
    return sourceUrl;
  }
}

async function getCategoryImageUrl(category: Category, userId: string): Promise<string> {
  const sourceUrl = faker.helpers.arrayElement(CATEGORY_IMAGE_SOURCES[category]);
  if (USE_EXTERNAL_URLS) return sourceUrl;
  return uploadToSupabaseStorage(sourceUrl, userId);
}

function getAvatarUrl(): string {
  return `https://api.dicebear.com/7.x/avataaars/svg?seed=${faker.string.uuid()}`;
}

function generateBarcelonaLocation() {
  const neighborhood = faker.helpers.arrayElement(BARCELONA_NEIGHBORHOODS);
  const offset = 0.01; // ~1 km radius jitter
  return {
    neighborhood: neighborhood.name,
    address: `${faker.location.street()}, ${neighborhood.name}, Barcelona`,
    latitude: neighborhood.lat + (Math.random() - 0.5) * offset,
    longitude: neighborhood.lng + (Math.random() - 0.5) * offset,
  };
}

function generateEventTiming(): { startTime: Date; endTime: Date | null } {
  const now = new Date();
  const hours = (h: number) => h * 60 * 60 * 1000;
  const days = (d: number) => d * 24 * hours(1);
  const rand = Math.random();

  let startTime: Date;
  let endTime: Date | null;

  if (rand < 0.1) {
    // 10 % past events (up to 3 months ago)
    startTime = new Date(now.getTime() - faker.number.int({ min: 1, max: 90 }) * days(1));
    endTime = new Date(startTime.getTime() + hours(faker.number.int({ min: 1, max: 4 })));
  } else if (rand < 0.25) {
    // 15 % today / tonight
    startTime = new Date(now.getTime() + hours(faker.number.int({ min: 0, max: 12 })));
    endTime = new Date(startTime.getTime() + hours(faker.number.int({ min: 1, max: 4 })));
  } else if (rand < 0.55) {
    // 30 % this week
    startTime = new Date(now.getTime() + days(faker.number.int({ min: 1, max: 7 })));
    endTime = new Date(startTime.getTime() + hours(faker.number.int({ min: 1, max: 5 })));
  } else if (rand < 0.8) {
    // 25 % next two weeks
    startTime = new Date(now.getTime() + days(faker.number.int({ min: 8, max: 14 })));
    endTime = new Date(startTime.getTime() + hours(faker.number.int({ min: 1, max: 5 })));
  } else {
    // 20 % two-four weeks out
    startTime = new Date(now.getTime() + days(faker.number.int({ min: 15, max: 28 })));
    endTime = new Date(startTime.getTime() + hours(faker.number.int({ min: 2, max: 6 })));
  }

  if (Math.random() < 0.3) endTime = null;

  return { startTime, endTime };
}

function generateEventTitle(category: Category, address: string, neighborhood: string): string {
  const template = faker.helpers.arrayElement(EVENT_TEMPLATES[category]);
  return template.replace('{location}', address).replace('{neighborhood}', neighborhood);
}

// ---------------------------------------------------------------------------
// Event creation helper
// ---------------------------------------------------------------------------

async function createEvent(userId: string) {
  const category = getRandomCategory();
  const location = generateBarcelonaLocation();
  const { startTime, endTime } = generateEventTiming();
  const title = generateEventTitle(category, location.address, location.neighborhood);

  const event = await prisma.event.create({
    data: {
      userId,
      title,
      description: faker.lorem.paragraphs({ min: 1, max: 2 }),
      category,
      categoryTag: category,
      address: location.address,
      neighborhood: location.neighborhood,
      latitude: location.latitude,
      longitude: location.longitude,
      startTime,
      endTime,
      tags: faker.helpers.arrayElements(EVENT_TAGS, { min: 1, max: 3 }),
      saveCount: 0,
    },
  });


  if (Math.random() < 0.9) {
    const numImages = faker.number.int({ min: 1, max: 3 });
    for (let j = 0; j < numImages; j++) {
      const imageUrl = await getCategoryImageUrl(category, userId);
      await prisma.mediaItem.create({
        data: { eventId: event.id, url: imageUrl, type: 'photo', order: j },
      });
    }
  }

  return event;
}

// ---------------------------------------------------------------------------
// Spot creation helper
// ---------------------------------------------------------------------------

async function createSpot(ownerId: string) {
  const category = getRandomCategory();
  const location = generateBarcelonaLocation();
  const templates = SPOT_TEMPLATES[category];

  const spot = await prisma.spot.create({
    data: {
      ownerId,
      name: faker.helpers.arrayElement(templates.names),
      description: faker.lorem.sentence(),
      address: location.address,
      latitude: location.latitude,
      longitude: location.longitude,
      categoryTag: category,
      neighborhood: location.neighborhood,
      tags: faker.helpers.arrayElement(templates.tagSets),
      saveCount: 0,
    },
  });


  if (Math.random() < 0.8) {
    const numImages = faker.number.int({ min: 1, max: 2 });
    for (let j = 0; j < numImages; j++) {
      const imageUrl = await getCategoryImageUrl(category, ownerId);
      await prisma.mediaItem.create({
        data: { spotId: spot.id, url: imageUrl, type: 'photo', order: j },
      });
    }
  }

  return spot;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log('🌱 Starting Barcelona fake data seed...\n');

  // -- Cleanup --
  console.log('🧹 Cleaning up existing data...');
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
  console.log('✅ Cleanup complete\n');

  faker.seed(42);

  // ==========================================================================
  // 1. Users
  // ==========================================================================
  console.log('👥 Creating users...');

  const usersByType: Record<UserType, any[]> = {
    organizer: [],
    connector: [],
    selective_planner: [],
    lurker: [],
    social_connector: [],
  };

  for (const [type, config] of Object.entries(USER_TYPES)) {
    for (let i = 0; i < config.count; i++) {
      const userId = faker.string.uuid();
      const avatarUrl = USE_EXTERNAL_URLS
        ? getAvatarUrl()
        : await getCategoryImageUrl('community', userId);

      const user = await prisma.user.create({
        data: {
          id: userId,
          email: faker.internet.email(),
          passwordHash: 'supabase-managed',
          name: faker.person.fullName(),
          handle: faker.internet.userName().toLowerCase().replace(/[^a-z0-9_]/g, '').slice(0, 20) + i,
          bio: faker.lorem.sentence(),
          cities: ['Barcelona'],
          selectedCity: 'Barcelona',
          profilePictureUrl: avatarUrl,
          isPrivate: faker.datatype.boolean({ probability: 0.15 }),
          followerCount: 0,
          followingCount: 0,
        },
      });

      usersByType[type as UserType].push(user);
    }
    console.log(`   ✅ ${config.count} ${type} users`);
  }

  const allUsers = Object.values(usersByType).flat();
  console.log(`✅ Total users: ${allUsers.length}\n`);

  // ==========================================================================
  // 2. Events
  // ==========================================================================
  console.log('🎉 Creating events...');
  const allEvents: any[] = [];

  for (const organizer of usersByType.organizer) {
    const count = faker.number.int({ min: 5, max: 8 });
    for (let i = 0; i < count; i++) {
      allEvents.push(await createEvent(organizer.id));
    }
  }

  for (const user of usersByType.social_connector) {
    allEvents.push(await createEvent(user.id));
  }

  // Fill up to 40-50 total
  const targetEvents = faker.number.int({ min: 40, max: 50 });
  while (allEvents.length < targetEvents) {
    const host = faker.helpers.arrayElement(allUsers);
    allEvents.push(await createEvent(host.id));
  }

  console.log(`✅ Created ${allEvents.length} events\n`);

  // ==========================================================================
  // 3. Spots
  // ==========================================================================
  console.log('📍 Creating spots...');
  const allSpots: any[] = [];

  for (const [type, users] of Object.entries(usersByType)) {
    const config = USER_TYPES[type as UserType];
    for (const user of users) {
      for (let i = 0; i < config.spotsToCreate; i++) {
        allSpots.push(await createSpot(user.id));
      }
    }
  }

  console.log(`✅ Created ${allSpots.length} spots\n`);

  // ==========================================================================
  // 4. Follow relationships
  // ==========================================================================
  console.log('👥 Creating follow relationships...');

  for (const [type, users] of Object.entries(usersByType)) {
    const config = USER_TYPES[type as UserType];
    for (const user of users) {
      const followsToCreate =
        type === 'social_connector'
          ? faker.number.int({ min: 8, max: 12 })
          : config.follows;

      const targets = faker.helpers
        .shuffle(allUsers.filter((u) => u.id !== user.id))
        .slice(0, followsToCreate);

      for (const target of targets) {
        await prisma.follow.upsert({
          where: {
            followerId_followingId: { followerId: user.id, followingId: target.id },
          },
          update: {},
          create: { followerId: user.id, followingId: target.id },
        });
      }

      await prisma.user.update({
        where: { id: user.id },
        data: { followingCount: targets.length },
      });
    }
  }

  for (const user of allUsers) {
    const count = await prisma.follow.count({ where: { followingId: user.id } });
    await prisma.user.update({ where: { id: user.id }, data: { followerCount: count } });
  }

  console.log('✅ Follow relationships created\n');

  // ==========================================================================
  // 5. Collections
  // ==========================================================================
  console.log('📚 Creating collections...');

  const userCollections = new Map<string, any[]>();

  for (const [type, users] of Object.entries(usersByType)) {
    const config = USER_TYPES[type as UserType];
    for (const user of users) {
      const templates = faker.helpers
        .shuffle([...COLLECTION_TEMPLATES])
        .slice(0, config.collections);

      const collections: any[] = [];
      for (const tmpl of templates) {
        const collection = await prisma.collection.create({
          data: {
            userId: user.id,
            name: tmpl.name,
            description: tmpl.description,
            visibility: tmpl.visibility,
          },
        });
        collections.push(collection);
      }
      userCollections.set(user.id, collections);
    }
  }

  const totalCollections = [...userCollections.values()].flat().length;
  console.log(`✅ Created ${totalCollections} collections\n`);

  // ==========================================================================
  // 6. Saves (events & spots into user collections)
  // ==========================================================================
  console.log('💾 Creating saves...');

  const allSaveables = [
    ...allEvents.map((e) => ({ itemType: 'event' as const, itemId: e.id })),
    ...allSpots.map((s) => ({ itemType: 'spot' as const, itemId: s.id })),
  ];

  let totalSaves = 0;

  for (const [type, users] of Object.entries(usersByType)) {
    const config = USER_TYPES[type as UserType];
    for (const user of users) {
      const savesToCreate =
        type === 'connector'
          ? faker.number.int({ min: 10, max: 15 })
          : type === 'lurker'
            ? faker.number.int({ min: 0, max: 1 })
            : config.saves;

      const collections = userCollections.get(user.id) ?? [];
      if (collections.length === 0) continue;

      const items = faker.helpers.shuffle([...allSaveables]).slice(0, savesToCreate);

      for (const item of items) {
        const collection = faker.helpers.arrayElement(collections);
        try {
          await prisma.save.create({
            data: {
              userId: user.id,
              collectionId: collection.id,
              itemType: item.itemType,
              itemId: item.itemId,
            },
          });

          await prisma.collectionItem.create({
            data: {
              collectionId: collection.id,
              itemType: item.itemType,
              itemId: item.itemId,
              order: totalSaves,
            },
          });

          if (item.itemType === 'event') {
            await prisma.event.update({
              where: { id: item.itemId },
              data: { saveCount: { increment: 1 } },
            });
          } else {
            await prisma.spot.update({
              where: { id: item.itemId },
              data: { saveCount: { increment: 1 } },
            });
          }

          totalSaves++;
        } catch {
          // Duplicate save — skip silently
        }
      }
    }
  }

  console.log(`✅ Created ${totalSaves} saves\n`);

  // ==========================================================================
  // Done
  // ==========================================================================
  console.log('🎉 Seed completed successfully!');
  console.log('\n📊 Summary:');
  console.log(`   Users:       ${allUsers.length}`);
  console.log(`   Events:      ${allEvents.length}`);
  console.log(`   Spots:       ${allSpots.length}`);
  console.log(`   Collections: ${totalCollections}`);
  console.log(`   Saves:       ${totalSaves}`);
  console.log(`   User types:  ${Object.keys(USER_TYPES).join(', ')}`);
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

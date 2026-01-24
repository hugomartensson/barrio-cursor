/**
 * Fake Data Seed Script - Barcelona Hyperlocal Events
 * 
 * Creates realistic test data for the Barrio app with:
 * - User types: Organizers, Curators, Selective Planners, Lurkers, Social Connectors
 * - Barcelona-based events across neighborhoods
 * - Category-specific media (images/videos)
 * - Realistic timing distribution
 * 
 * Usage:
 *   npm run seed:fake
 * 
 * Note: This script uploads media to Supabase Storage for realistic testing.
 */

import { PrismaClient, Category } from '@prisma/client';
import { faker } from '@faker-js/faker';
import { supabaseAdmin, STORAGE_BUCKET } from '../src/services/supabase.js';

const prisma = new PrismaClient();

// Configuration
const USE_EXTERNAL_URLS = process.env.SEED_USE_EXTERNAL_URLS === 'true';

// Barcelona neighborhoods with coordinates
const BARCELONA_NEIGHBORHOODS = [
  { name: 'Gràcia', lat: 41.4026, lng: 2.1564 },
  { name: 'Eixample', lat: 41.3936, lng: 2.1630 },
  { name: 'Barceloneta', lat: 41.3802, lng: 2.1897 },
  { name: 'Raval', lat: 41.3800, lng: 2.1700 },
  { name: 'Poblenou', lat: 41.4020, lng: 2.2030 },
  { name: 'Born', lat: 41.3840, lng: 2.1830 },
];

// Category-specific image sources (using Picsum Photos - reliable, no key needed)
// Using random seeds to get different images for each category
const CATEGORY_IMAGE_SOURCES: Record<Category, string[]> = {
  sports_outdoors: [
    'https://picsum.photos/seed/sports1/800/600',
    'https://picsum.photos/seed/football/800/600',
    'https://picsum.photos/seed/yoga/800/600',
    'https://picsum.photos/seed/running/800/600',
    'https://picsum.photos/seed/climbing/800/600',
    'https://picsum.photos/seed/fitness/800/600',
    'https://picsum.photos/seed/athletics/800/600',
  ],
  food_drink: [
    'https://picsum.photos/seed/food1/800/600',
    'https://picsum.photos/seed/restaurant/800/600',
    'https://picsum.photos/seed/market/800/600',
    'https://picsum.photos/seed/wine/800/600',
    'https://picsum.photos/seed/brunch/800/600',
    'https://picsum.photos/seed/tapas/800/600',
    'https://picsum.photos/seed/cafe/800/600',
  ],
  arts_culture: [
    'https://picsum.photos/seed/art1/800/600',
    'https://picsum.photos/seed/gallery/800/600',
    'https://picsum.photos/seed/concert/800/600',
    'https://picsum.photos/seed/theater/800/600',
    'https://picsum.photos/seed/cinema/800/600',
    'https://picsum.photos/seed/streetart/800/600',
    'https://picsum.photos/seed/museum/800/600',
  ],
  nightlife: [
    'https://picsum.photos/seed/nightlife1/800/600',
    'https://picsum.photos/seed/nightclub/800/600',
    'https://picsum.photos/seed/dj/800/600',
    'https://picsum.photos/seed/bar/800/600',
    'https://picsum.photos/seed/dance/800/600',
    'https://picsum.photos/seed/party/800/600',
  ],
  community: [
    'https://picsum.photos/seed/community1/800/600',
    'https://picsum.photos/seed/community/800/600',
    'https://picsum.photos/seed/park/800/600',
    'https://picsum.photos/seed/games/800/600',
    'https://picsum.photos/seed/volunteer/800/600',
    'https://picsum.photos/seed/language/800/600',
    'https://picsum.photos/seed/meetup/800/600',
  ],
  music: [
    'https://picsum.photos/seed/music1/800/600',
    'https://picsum.photos/seed/concert/800/600',
    'https://picsum.photos/seed/livemusic/800/600',
    'https://picsum.photos/seed/guitar/800/600',
    'https://picsum.photos/seed/dj/800/600',
  ],
};

// Category-specific video sources (short clips)
const CATEGORY_VIDEO_SOURCES: Record<Category, string[]> = {
  sports_outdoors: [
    'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4', // Placeholder - replace with sports videos
  ],
  food_drink: [
    'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
  ],
  arts_culture: [
    'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
  ],
  nightlife: [
    'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
  ],
  community: [
    'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
  ],
  music: [
    'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
  ],
};

// Event templates by category
const EVENT_TEMPLATES: Record<Category, string[]> = {
  sports_outdoors: [
    '5-a-side football @ {location}',
    'Yoga in the Park - {neighborhood}',
    'Morning Running Club - {neighborhood}',
    'Rock Climbing Session',
    'Beach Volleyball @ Barceloneta',
    'Cycling Group Ride',
  ],
  food_drink: [
    'Vermut at {location}',
    'Restaurant Opening: {location}',
    'Mercat de la Llibertat Food Tour',
    'Wine Tasting Evening',
    'Brunch Meetup @ {location}',
    'Tapas Crawl - {neighborhood}',
  ],
  arts_culture: [
    'Gallery Opening: {location}',
    'Live Concert @ {location}',
    'Theater Performance',
    'Film Screening: {location}',
    'Street Art Walking Tour',
    'Museum Night',
  ],
  nightlife: [
    'Nit de Swing at Apolo',
    'DJ Set @ {location}',
    'Bar Crawl - {neighborhood}',
    'Club Night: {location}',
    'Electronic Music Night',
  ],
  community: [
    'Neighborhood Clean-up - {neighborhood}',
    'Language Exchange Meetup',
    'Board Game Night',
    'Community Garden Workshop',
    'Local Market Visit',
    'Café Meetup - {neighborhood}',
  ],
  music: [
    'Live Jazz @ {location}',
    'Acoustic Session',
    'Electronic Music Night',
    'Flamenco Performance',
  ],
};

// User type definitions
type UserType = 'organizer' | 'curator' | 'selective_planner' | 'lurker' | 'social_connector';

interface UserTypeConfig {
  count: number;
  eventsToCreate: number;
  interestedMarks: number;
  follows: number;
}

const USER_TYPES: Record<UserType, UserTypeConfig> = {
  organizer: { count: 4, eventsToCreate: 7, interestedMarks: 5, follows: 3 },
  curator: { count: 5, eventsToCreate: 0, interestedMarks: 12, follows: 4 },
  selective_planner: { count: 4, eventsToCreate: 0, interestedMarks: 3, follows: 2 },
  lurker: { count: 3, eventsToCreate: 0, interestedMarks: 1, follows: 1 },
  social_connector: { count: 3, eventsToCreate: 1, interestedMarks: 6, follows: 10 },
};

/**
 * Upload media to Supabase Storage
 */
async function uploadToSupabaseStorage(
  sourceUrl: string,
  userId: string,
  contentType: 'image' | 'video'
): Promise<string> {
  try {
    const response = await fetch(sourceUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch: ${response.statusText}`);
    }

    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    const extension = contentType === 'image' ? 'jpg' : 'mp4';
    const filename = `${faker.string.uuid()}.${extension}`;
    const filePath = `seed-data/${userId}/${filename}`;

    const { data, error } = await supabaseAdmin.storage
      .from(STORAGE_BUCKET)
      .upload(filePath, buffer, {
        contentType: contentType === 'image' ? 'image/jpeg' : 'video/mp4',
        upsert: false,
      });

    if (error) throw error;

    const {
      data: { publicUrl },
    } = supabaseAdmin.storage.from(STORAGE_BUCKET).getPublicUrl(filePath);

    return publicUrl;
  } catch (error) {
    console.warn(`⚠️  Upload failed for ${sourceUrl}, using direct URL`);
    return sourceUrl;
  }
}

/**
 * Get category-specific image URL
 */
async function getCategoryImageUrl(category: Category, userId: string): Promise<string> {
  const sources = CATEGORY_IMAGE_SOURCES[category];
  const sourceUrl = faker.helpers.arrayElement(sources);

  if (USE_EXTERNAL_URLS) return sourceUrl;
  return uploadToSupabaseStorage(sourceUrl, userId, 'image');
}

/**
 * Get category-specific video URL
 * Note: Using direct URLs for videos (not uploading to Supabase Storage)
 */
async function getCategoryVideoUrl(category: Category, userId: string): Promise<string> {
  const sources = CATEGORY_VIDEO_SOURCES[category];
  const sourceUrl = faker.helpers.arrayElement(sources);
  
  // Always use direct URLs for videos (not uploading to Supabase Storage)
  return sourceUrl;
}

/**
 * Get avatar URL
 */
function getAvatarUrl(): string {
  return `https://api.dicebear.com/7.x/avataaars/svg?seed=${faker.string.uuid()}`;
}

/**
 * Generate Barcelona location
 */
function generateBarcelonaLocation() {
  const neighborhood = faker.helpers.arrayElement(BARCELONA_NEIGHBORHOODS);
  const offset = 0.01; // ~1km radius
  const latOffset = (Math.random() - 0.5) * offset;
  const lngOffset = (Math.random() - 0.5) * offset;

  return {
    neighborhood: neighborhood.name,
    address: `${faker.location.street()}, ${neighborhood.name}, Barcelona`,
    latitude: neighborhood.lat + latOffset,
    longitude: neighborhood.lng + lngOffset,
  };
}

/**
 * Generate event timing based on distribution
 */
function generateEventTiming(): { startTime: Date; endTime: Date | null } {
  const now = new Date();
  const rand = Math.random();

  let startTime: Date;
  let endTime: Date | null;

  if (rand < 0.1) {
    // 10% past events
    startTime = faker.date.past({ years: 1 });
    endTime = faker.date.soon({ days: 1, refDate: startTime });
  } else if (rand < 0.25) {
    // 15% today/tonight
    const hoursFromNow = faker.number.int({ min: 0, max: 12 });
    startTime = new Date(now.getTime() + hoursFromNow * 60 * 60 * 1000);
    endTime = new Date(startTime.getTime() + faker.number.int({ min: 1, max: 4 }) * 60 * 60 * 1000);
  } else if (rand < 0.55) {
    // 30% this week
    startTime = faker.date.soon({ days: 7 });
    endTime = faker.date.soon({ days: 1, refDate: startTime });
  } else if (rand < 0.8) {
    // 25% next week
    startTime = faker.date.future({ days: 14 });
    endTime = faker.date.soon({ days: 1, refDate: startTime });
  } else {
    // 20% 2-4 weeks out
    startTime = faker.date.future({ days: 28 });
    endTime = faker.date.soon({ days: 1, refDate: startTime });
  }

  // 30% have no end time
  if (Math.random() < 0.3) {
    endTime = null;
  }

  return { startTime, endTime };
}

/**
 * Generate event title from template
 */
function generateEventTitle(category: Category, location: string, neighborhood: string): string {
  const templates = EVENT_TEMPLATES[category];
  const template = faker.helpers.arrayElement(templates);
  return template.replace('{location}', location).replace('{neighborhood}', neighborhood);
}

/**
 * Main seed function
 */
async function main() {
  console.log('🌱 Starting Barcelona fake data seed...\n');

  // Clean up existing seed data (optional - comment out if you want to keep existing data)
  console.log('🧹 Cleaning up existing seed data...');
  await prisma.mediaItem.deleteMany({});
  await prisma.interested.deleteMany({});
  await prisma.follow.deleteMany({});
  await prisma.followRequest.deleteMany({});
  await prisma.planEvent.deleteMany({});
  await prisma.plan.deleteMany({});
  await prisma.event.deleteMany({});
  await prisma.user.deleteMany({});
  console.log('✅ Cleanup complete\n');

  faker.seed(42); // Reproducible results

  // Create users by type
  console.log('👥 Creating users by type...');
  const usersByType: Record<UserType, any[]> = {
    organizer: [],
    curator: [],
    selective_planner: [],
    lurker: [],
    social_connector: [],
  };

  for (const [type, config] of Object.entries(USER_TYPES)) {
    for (let i = 0; i < config.count; i++) {
      const userId = faker.string.uuid();
      const avatarUrl = USE_EXTERNAL_URLS ? getAvatarUrl() : await getCategoryImageUrl('community', userId);

      const user = await prisma.user.create({
        data: {
          id: userId,
          email: faker.internet.email(),
          passwordHash: 'supabase-managed',
          name: faker.person.fullName(),
          profilePictureUrl: avatarUrl,
          isPrivate: faker.datatype.boolean({ probability: 0.15 }),
          followerCount: 0,
          followingCount: 0,
        },
      });

      usersByType[type as UserType].push(user);
    }
    console.log(`   ✅ Created ${config.count} ${type} users`);
  }

  const allUsers = Object.values(usersByType).flat();
  console.log(`✅ Total users: ${allUsers.length}\n`);

  // Create events with category distribution
  console.log('🎉 Creating events...');
  // Distribution: Sports 20%, Food 25%, Arts 20%, Nightlife 15%, Community 20%
  // Note: Using 'music' category for some concerts (part of arts_culture conceptually)
  const categoryDistribution: { category: Category; percentage: number }[] = [
    { category: 'sports_outdoors', percentage: 0.20 },
    { category: 'food_drink', percentage: 0.25 },
    { category: 'arts_culture', percentage: 0.15 }, // Some concerts will use 'music'
    { category: 'music', percentage: 0.05 }, // Concerts/music events
    { category: 'nightlife', percentage: 0.15 },
    { category: 'community', percentage: 0.20 },
  ];

  const allEvents: any[] = [];
  let eventIndex = 0;

  // Helper to get category based on distribution
  function getRandomCategory(): Category {
    const rand = Math.random();
    let cumulative = 0;
    for (const catData of categoryDistribution) {
      cumulative += catData.percentage;
      if (rand <= cumulative) {
        return catData.category;
      }
    }
    return 'community'; // fallback
  }

  // Create events for organizers (5-8 events each)
  for (const organizer of usersByType.organizer) {
    const eventsToCreate = faker.number.int({ min: 5, max: 8 });
    for (let i = 0; i < eventsToCreate; i++) {
      const category = getRandomCategory();

      const location = generateBarcelonaLocation();
      const { startTime, endTime } = generateEventTiming();
      const title = generateEventTitle(category, location.address, location.neighborhood);

      const event = await prisma.event.create({
        data: {
          userId: organizer.id,
          title,
          description: faker.lorem.paragraphs({ min: 1, max: 2 }),
          category,
          address: location.address,
          latitude: location.latitude,
          longitude: location.longitude,
          startTime,
          endTime,
          isFree: faker.datatype.boolean({ probability: 0.75 }),
          interestedCount: 0,
        },
      });

      // Set location geometry
      await prisma.$executeRaw`
        UPDATE events
        SET location = ST_SetSRID(ST_MakePoint(${location.longitude}, ${location.latitude}), 4326)
        WHERE id = ${event.id}
      `;

      // Add media (60% images only, 30% videos, 10% no media)
      const mediaRand = Math.random();
      if (mediaRand < 0.6) {
        // Images only
        const numImages = faker.number.int({ min: 1, max: 3 });
        for (let j = 0; j < numImages; j++) {
          const imageUrl = await getCategoryImageUrl(category, organizer.id);
          await prisma.mediaItem.create({
            data: {
              eventId: event.id,
              url: imageUrl,
              type: 'photo',
              order: j,
            },
          });
        }
      } else if (mediaRand < 0.9) {
        // Videos (with thumbnail)
        const numVideos = faker.number.int({ min: 1, max: 2 });
        for (let j = 0; j < numVideos; j++) {
          const videoUrl = await getCategoryVideoUrl(category, organizer.id);
          const thumbnailUrl = await getCategoryImageUrl(category, organizer.id);
          await prisma.mediaItem.create({
            data: {
              eventId: event.id,
              url: videoUrl,
              type: 'video',
              order: j,
              thumbnailUrl,
            },
          });
        }
      }
      // 10% no media

      allEvents.push(event);
      eventIndex++;
    }
  }

  // Create additional events to reach 40-50 total
  const targetTotal = faker.number.int({ min: 40, max: 50 });
  const remainingEvents = Math.max(0, targetTotal - allEvents.length);
  for (let i = 0; i < remainingEvents; i++) {
    const host = faker.helpers.arrayElement(allUsers);
    const category = getRandomCategory();
    const location = generateBarcelonaLocation();
    const { startTime, endTime } = generateEventTiming();
    const title = generateEventTitle(category, location.address, location.neighborhood);

    const event = await prisma.event.create({
      data: {
        userId: host.id,
        title,
        description: faker.lorem.paragraphs({ min: 1, max: 2 }),
        category,
        address: location.address,
        latitude: location.latitude,
        longitude: location.longitude,
        startTime,
        endTime,
        isFree: faker.datatype.boolean({ probability: 0.75 }),
        interestedCount: 0,
      },
    });

    await prisma.$executeRaw`
      UPDATE events
      SET location = ST_SetSRID(ST_MakePoint(${location.longitude}, ${location.latitude}), 4326)
      WHERE id = ${event.id}
    `;

    // Add media
    const mediaRand = Math.random();
    if (mediaRand < 0.6) {
      const numImages = faker.number.int({ min: 1, max: 3 });
      for (let j = 0; j < numImages; j++) {
        const imageUrl = await getCategoryImageUrl(category, host.id);
        await prisma.mediaItem.create({
          data: {
            eventId: event.id,
            url: imageUrl,
            type: 'photo',
            order: j,
          },
        });
      }
    } else if (mediaRand < 0.9) {
      const videoUrl = await getCategoryVideoUrl(category, host.id);
      const thumbnailUrl = await getCategoryImageUrl(category, host.id);
      await prisma.mediaItem.create({
        data: {
          eventId: event.id,
          url: videoUrl,
          type: 'video',
          order: 0,
          thumbnailUrl,
        },
      });
    }

    allEvents.push(event);
  }

  console.log(`✅ Created ${allEvents.length} events\n`);

  // Create follow relationships
  console.log('👥 Creating follow relationships...');
  for (const [type, users] of Object.entries(usersByType)) {
    const config = USER_TYPES[type as UserType];
    for (const user of users) {
      let followsToCreate: number;
      if (type === 'social_connector') {
        followsToCreate = faker.number.int({ min: 8, max: 12 });
      } else {
        followsToCreate = config.follows;
      }
      const targets = allUsers.filter((u) => u.id !== user.id);
      const shuffled = faker.helpers.shuffle(targets).slice(0, followsToCreate);

      for (const target of shuffled) {
        await prisma.follow.upsert({
          where: {
            followerId_followingId: {
              followerId: user.id,
              followingId: target.id,
            },
          },
          update: {},
          create: {
            followerId: user.id,
            followingId: target.id,
          },
        });
      }

      // Update following count
      await prisma.user.update({
        where: { id: user.id },
        data: { followingCount: followsToCreate },
      });
    }
  }
  console.log('✅ Created follow relationships\n');

  // Create interested relationships
  console.log('❤️  Creating interested relationships...');
  for (const [type, users] of Object.entries(usersByType)) {
    const config = USER_TYPES[type as UserType];
    for (const user of users) {
      let interestedToCreate: number;
      if (type === 'curator') {
        interestedToCreate = faker.number.int({ min: 10, max: 15 });
      } else if (type === 'selective_planner') {
        interestedToCreate = faker.number.int({ min: 2, max: 4 });
      } else if (type === 'lurker') {
        interestedToCreate = faker.number.int({ min: 0, max: 1 });
      } else {
        interestedToCreate = config.interestedMarks;
      }
      const shuffled = faker.helpers.shuffle(allEvents).slice(0, interestedToCreate);

      for (const event of shuffled) {
        await prisma.interested.upsert({
          where: {
            userId_eventId: {
              userId: user.id,
              eventId: event.id,
            },
          },
          update: {},
          create: {
            userId: user.id,
            eventId: event.id,
          },
        });

        // Update interested count
        await prisma.event.update({
          where: { id: event.id },
          data: { interestedCount: { increment: 1 } },
        });
      }
    }
  }
  console.log('✅ Created interested relationships\n');

  console.log('🎉 Seed completed successfully!');
  console.log(`\n📊 Summary:`);
  console.log(`   - Users: ${allUsers.length}`);
  console.log(`   - Events: ${allEvents.length}`);
  console.log(`   - User types: ${Object.keys(USER_TYPES).join(', ')}`);
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

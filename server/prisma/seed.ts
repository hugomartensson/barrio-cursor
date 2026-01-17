import { PrismaClient, Category } from '@prisma/client';

const prisma = new PrismaClient();

/**
 * Seed script for local development and testing
 * Creates test users and events with varied scenarios:
 * - Events with past endTime (for testing expiration filter)
 * - Events with future endTime
 * - Events with null endTime
 * - Events at exactly 5km boundary
 */
async function main() {
  console.log('🌱 Starting seed...');

  // Create test user
  const testUser = await prisma.user.upsert({
    where: { email: 'test@example.com' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000001',
      email: 'test@example.com',
      passwordHash: 'supabase-managed', // Password managed by Supabase Auth
      name: 'Test User',
    },
  });

  console.log('✅ Created test user:', testUser.email);

  // Base location (NYC coordinates)
  const baseLat = 40.7128;
  const baseLng = -74.006;

  // Calculate coordinates for 5km boundary
  // 1 degree latitude ≈ 111 km, so 5km ≈ 0.045 degrees
  // For longitude, need to account for latitude: 1 degree ≈ 111 km * cos(latitude)
  const latOffset5km = 5 / 111; // ~0.045 degrees
  const lngOffset5km = 5 / (111 * Math.cos((baseLat * Math.PI) / 180)); // ~0.056 degrees

  const now = new Date();
  const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
  const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);
  const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);
  const twoHoursFromNow = new Date(now.getTime() + 2 * 60 * 60 * 1000);
  const oneDayFromNow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  // Clear existing events for this user
  await prisma.event.deleteMany({
    where: { userId: testUser.id },
  });

  const events = [
    // Event with past endTime (should NOT appear in queries)
    {
      title: 'Expired Event (Past EndTime)',
      description: 'This event has ended - should not appear in nearby events',
      category: 'music' as Category,
      latitude: baseLat,
      longitude: baseLng,
      startTime: twoHoursAgo,
      endTime: oneHourAgo,
    },
    // Event with past startTime but no endTime (should NOT appear)
    {
      title: 'Expired Event (No EndTime)',
      description: 'This event started in the past with no end time',
      category: 'food_drink' as Category,
      latitude: baseLat + 0.01,
      longitude: baseLng + 0.01,
      startTime: oneHourAgo,
      endTime: null,
    },
    // Event with future endTime (should appear)
    {
      title: 'Upcoming Music Event',
      description: 'This event is happening soon',
      category: 'music' as Category,
      latitude: baseLat,
      longitude: baseLng,
      startTime: oneHourFromNow,
      endTime: twoHoursFromNow,
    },
    // Event with future startTime but no endTime (should appear)
    {
      title: 'Future Community Event',
      description: 'This event is in the future with no end time',
      category: 'community' as Category,
      latitude: baseLat - 0.01,
      longitude: baseLng - 0.01,
      startTime: oneDayFromNow,
      endTime: null,
    },
    // Event at exactly 5km boundary (edge case)
    {
      title: 'Event at 5km Boundary',
      description: 'This event is exactly 5km away - edge case for testing',
      category: 'sports_outdoors' as Category,
      latitude: baseLat + latOffset5km,
      longitude: baseLng,
      startTime: oneHourFromNow,
      endTime: twoHoursFromNow,
    },
    // Event just inside 5km (should appear)
    {
      title: 'Event Just Inside 5km',
      description: 'This event is just inside the 5km radius',
      category: 'arts_culture' as Category,
      latitude: baseLat + latOffset5km * 0.9, // 90% of 5km
      longitude: baseLng,
      startTime: oneHourFromNow,
      endTime: twoHoursFromNow,
    },
    // Event just outside 5km (should NOT appear in nearby)
    {
      title: 'Event Just Outside 5km',
      description: 'This event is just outside the 5km radius',
      category: 'nightlife' as Category,
      latitude: baseLat + latOffset5km * 1.1, // 110% of 5km
      longitude: baseLng,
      startTime: oneHourFromNow,
      endTime: twoHoursFromNow,
    },
    // Multiple future events for variety
    {
      title: 'Food & Drink Event',
      description: 'A great food event happening soon',
      category: 'food_drink' as Category,
      latitude: baseLat + 0.02,
      longitude: baseLng + 0.02,
      startTime: oneHourFromNow,
      endTime: twoHoursFromNow,
    },
  ];

  for (const eventData of events) {
    const event = await prisma.event.create({
      data: {
        userId: testUser.id,
        ...eventData,
      },
    });

    // Create location geometry for the event (trigger will handle this, but we can also set it)
    // The trigger should handle it, but let's ensure it's set
    await prisma.$executeRaw`
      UPDATE events
      SET location = ST_SetSRID(ST_MakePoint(${eventData.longitude}, ${eventData.latitude}), 4326)
      WHERE id = ${event.id}
    `;

    console.log(`✅ Created event: ${event.title}`);
  }

  console.log(`\n🎉 Seed completed! Created ${events.length} events for testing.`);
  console.log('\nTest scenarios:');
  console.log('  - Expired events (past endTime): Should NOT appear in queries');
  console.log('  - Future events: Should appear in queries');
  console.log('  - Events at 5km boundary: Edge case testing');
  console.log('  - Events outside 5km: Should NOT appear in nearby queries');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

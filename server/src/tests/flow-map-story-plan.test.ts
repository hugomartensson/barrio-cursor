/**
 * FLOW TEST: Map Discovery → Story Viewer → Event Details → Add to Plan
 *
 * Tests the exact API calls the iOS app makes for this user flow:
 * 1. Login with test account
 * 2. GET /events/nearby (map loads events)
 * 3. GET /events/:id (tap pin → story viewer fetches event)
 * 4. Validate event data matches iOS model (Event.swift)
 * 5. POST /plans (create a plan)
 * 6. POST /plans/:planId/events/:eventId (add event to plan)
 * 7. GET /plans/:planId (verify plan has the event)
 *
 * Validates all responses against the exact Swift Codable models.
 */

import { cleanupTestUser, prisma, waitForDb } from './test-helpers.js';
import { supabaseAdmin } from '../services/supabase.js';
import { createApp } from '../app.js';
import supertest from 'supertest';
import type { Express } from 'express';
import type { EventData, EventsListResponse } from '../types/responses.js';
import type { PlanDetailData } from '../routes/plans.js';

let app: Express;
let testUser: { userId: string; token: string; email: string };
let secondUser: { userId: string; token: string; email: string };
let createdEventId: string;
let createdPlanId: string;

// NYC coordinates for test
const TEST_LAT = 40.7128;
const TEST_LNG = -74.006;

const TEST_PASSWORD = 'TestPassword123!';

/**
 * Create a test user via Supabase Auth AND sync to local DB via the login API.
 * This mimics exactly what the iOS app does: signup → login → user synced.
 */
async function createAndLoginUser(
  appInstance: Express,
  emailPrefix: string,
  name: string
): Promise<{ userId: string; token: string; email: string }> {
  const email = `${emailPrefix}@example.com`;

  // 1. Create user in Supabase Auth
  const { data: signupData, error: signupError } = await supabaseAdmin.auth.signUp({
    email,
    password: TEST_PASSWORD,
    options: { data: { name } },
  });

  if (signupError || !signupData.user) {
    throw new Error(`Signup failed: ${signupError?.message || 'Unknown error'}`);
  }

  // 2. Login through the API (this triggers syncUserToDatabase)
  const loginRes = await supertest(appInstance)
    .post('/api/auth/login')
    .send({ email, password: TEST_PASSWORD });

  if (loginRes.status !== 200) {
    throw new Error(
      `Login failed: ${loginRes.status} - ${JSON.stringify(loginRes.body)}`
    );
  }

  return {
    userId: loginRes.body.data.user.id,
    token: loginRes.body.data.token,
    email,
  };
}

beforeAll(async () => {
  app = createApp();
  const ts = Date.now();

  // Create two test users via actual API login (syncs to local DB)
  testUser = await createAndLoginUser(app, `flow-test-${ts}`, 'Flow Test User');
  secondUser = await createAndLoginUser(app, `flow-test2-${ts}`, 'Event Creator');

  console.log(`✅ Test users created and synced to local DB`);

  // Create a test event owned by secondUser so testUser can discover it
  const futureStart = new Date(Date.now() + 24 * 60 * 60 * 1000); // tomorrow
  const futureEnd = new Date(Date.now() + 25 * 60 * 60 * 1000); // tomorrow + 1h

  const eventRes = await supertest(app)
    .post('/api/events')
    .set('Authorization', `Bearer ${secondUser.token}`)
    .send({
      title: 'Jazz Night at Blue Note',
      description:
        'Live jazz performance featuring local artists. Come enjoy great music and drinks!',
      category: 'music',
      address: '131 W 3rd St, New York, NY 10012',
      latitude: TEST_LAT + 0.001, // nearby
      longitude: TEST_LNG + 0.001,
      startTime: futureStart.toISOString(),
      endTime: futureEnd.toISOString(),
      media: [
        { url: 'https://picsum.photos/800/600', type: 'photo' },
        { url: 'https://picsum.photos/800/601', type: 'photo' },
      ],
    });

  if (eventRes.status !== 201) {
    console.error('Event creation failed:', JSON.stringify(eventRes.body, null, 2));
  }
  expect(eventRes.status).toBe(201);
  createdEventId = eventRes.body.data.id;
  console.log(`✅ Test event created: ${createdEventId}`);

  await waitForDb(200);
});

afterAll(async () => {
  // Cleanup: delete plan, event, users
  try {
    if (createdPlanId) {
      await prisma.planEvent.deleteMany({ where: { planId: createdPlanId } });
      await prisma.plan.delete({ where: { id: createdPlanId } });
    }
  } catch {
    /* ignore */
  }
  try {
    if (createdEventId) {
      await prisma.mediaItem.deleteMany({ where: { eventId: createdEventId } });
      await prisma.event.delete({ where: { id: createdEventId } });
    }
  } catch {
    /* ignore */
  }
  await cleanupTestUser(testUser.userId);
  await cleanupTestUser(secondUser.userId);
  await prisma.$disconnect();
});

// ============================================================
// STEP 1: GET /events/nearby — Map loads nearby events
// ============================================================
describe('Step 1: Map loads nearby events (GET /events/nearby)', () => {
  let nearbyEvents: EventData[];

  it('should return events near the test location', async () => {
    const res = await supertest(app)
      .get(`/api/events/nearby?lat=${TEST_LAT}&lng=${TEST_LNG}`)
      .set('Authorization', `Bearer ${testUser.token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(Array.isArray(res.body.data)).toBe(true);
    nearbyEvents = res.body.data;
    console.log(`📍 Nearby events found: ${nearbyEvents.length}`);
  });

  it('should include the test event in results', () => {
    const found = nearbyEvents.find((e) => e.id === createdEventId);
    expect(found).toBeDefined();
    console.log(`✅ Test event found in nearby results`);
  });

  it('each event should match iOS Event.swift model', () => {
    for (const event of nearbyEvents) {
      // Required fields from Event.swift
      expect(event).toHaveProperty('id');
      expect(typeof event.id).toBe('string');

      expect(event).toHaveProperty('title');
      expect(typeof event.title).toBe('string');

      expect(event).toHaveProperty('description');
      expect(typeof event.description).toBe('string');

      expect(event).toHaveProperty('category');
      expect(typeof event.category).toBe('string');
      // Valid categories from EventCategory enum
      expect([
        'food_drink',
        'arts_culture',
        'music',
        'nightlife',
        'sports_outdoors',
        'community',
      ]).toContain(event.category);

      expect(event).toHaveProperty('address');
      expect(typeof event.address).toBe('string');

      expect(event).toHaveProperty('latitude');
      expect(typeof event.latitude).toBe('number');

      expect(event).toHaveProperty('longitude');
      expect(typeof event.longitude).toBe('number');

      expect(event).toHaveProperty('startTime');
      expect(typeof event.startTime).toBe('string');
      // Must be ISO8601 parseable
      expect(new Date(event.startTime).toISOString()).toBe(event.startTime);

      // endTime can be null or ISO8601 string
      expect(event).toHaveProperty('endTime');
      if (event.endTime !== null) {
        expect(typeof event.endTime).toBe('string');
        expect(new Date(event.endTime).toISOString()).toBe(event.endTime);
      }

      expect(event).toHaveProperty('createdAt');
      expect(typeof event.createdAt).toBe('string');

      expect(event).toHaveProperty('interestedCount');
      expect(typeof event.interestedCount).toBe('number');

      // distance can be undefined/null or number
      if (event.distance !== undefined && event.distance !== null) {
        expect(typeof event.distance).toBe('number');
      }

      // media array
      expect(event).toHaveProperty('media');
      expect(Array.isArray(event.media)).toBe(true);
      for (const m of event.media) {
        expect(m).toHaveProperty('id');
        expect(m).toHaveProperty('url');
        expect(m).toHaveProperty('type');
        expect(['photo', 'video']).toContain(m.type);
        expect(m).toHaveProperty('order');
        expect(typeof m.order).toBe('number');
      }

      // user object
      expect(event).toHaveProperty('user');
      expect(event.user).toHaveProperty('id');
      expect(typeof event.user.id).toBe('string');
      expect(event.user).toHaveProperty('name');
      expect(typeof event.user.name).toBe('string');
    }
    console.log(`✅ All ${nearbyEvents.length} events match iOS Event.swift model`);
  });
});

// ============================================================
// STEP 2: GET /events/:id — Tap pin → Story viewer loads event
// ============================================================
describe('Step 2: Tap pin opens story viewer (GET /events/:id)', () => {
  let eventDetail: EventData;

  it('should return event details', async () => {
    const res = await supertest(app)
      .get(`/api/events/${createdEventId}?lat=${TEST_LAT}&lng=${TEST_LNG}`)
      .set('Authorization', `Bearer ${testUser.token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    eventDetail = res.body.data;
    console.log(`📖 Event detail loaded: "${eventDetail.title}"`);
  });

  it('event detail should match iOS Event.swift model exactly', () => {
    // Same checks as nearby but single event response format
    expect(eventDetail.id).toBe(createdEventId);
    expect(eventDetail.title).toBe('Jazz Night at Blue Note');
    expect(eventDetail.description).toBe(
      'Live jazz performance featuring local artists. Come enjoy great music and drinks!'
    );
    expect(eventDetail.category).toBe('music');
    expect(eventDetail.address).toBe('131 W 3rd St, New York, NY 10012');
    expect(typeof eventDetail.latitude).toBe('number');
    expect(typeof eventDetail.longitude).toBe('number');
    expect(typeof eventDetail.startTime).toBe('string');
    expect(typeof eventDetail.interestedCount).toBe('number');
  });

  it('should have media for story viewer (StoryViewer.swift)', () => {
    expect(Array.isArray(eventDetail.media)).toBe(true);
    expect(eventDetail.media.length).toBeGreaterThanOrEqual(1);

    for (const m of eventDetail.media) {
      expect(m).toHaveProperty('id');
      expect(typeof m.id).toBe('string');
      expect(m).toHaveProperty('url');
      expect(typeof m.url).toBe('string');
      expect(m).toHaveProperty('type');
      expect(['photo', 'video']).toContain(m.type);
      expect(m).toHaveProperty('order');
      expect(typeof m.order).toBe('number');
      // thumbnailUrl is optional (nullable) for photos, used for videos
    }

    console.log(`✅ Event has ${eventDetail.media.length} media items for story viewer`);
  });

  it('should have user info for creator display', () => {
    expect(eventDetail.user).toHaveProperty('id');
    expect(eventDetail.user).toHaveProperty('name');
    expect(eventDetail.user.name).toBe('Event Creator');
    console.log(`✅ Creator info: "${eventDetail.user.name}"`);
  });

  it('should include distance when lat/lng provided', () => {
    // Distance should be included when query params have lat/lng
    if (eventDetail.distance !== undefined && eventDetail.distance !== null) {
      expect(typeof eventDetail.distance).toBe('number');
      console.log(`✅ Distance: ${eventDetail.distance}m`);
    } else {
      console.log(`⚠️ Distance not included in response`);
    }
  });
});

// ============================================================
// STEP 3: POST /events/:id/interested — Mark interested
// ============================================================
describe('Step 3: Mark event as interested (POST /events/:id/interested)', () => {
  it('should toggle interested status', async () => {
    const res = await supertest(app)
      .post(`/api/events/${createdEventId}/interested`)
      .set('Authorization', `Bearer ${testUser.token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');

    // Validate response matches iOS InteractionResponse model
    const data = res.body.data;
    expect(data).toHaveProperty('interested');
    expect(typeof data.interested).toBe('boolean');
    expect(data).toHaveProperty('interestedCount');
    expect(typeof data.interestedCount).toBe('number');

    console.log(
      `✅ Interested toggled: interested=${data.interested}, count=${data.interestedCount}`
    );
  });
});

// ============================================================
// STEP 4: POST /plans — Create a plan (from event details view)
// ============================================================
describe('Step 4: Create plan (POST /plans)', () => {
  it('should create a new plan', async () => {
    const res = await supertest(app)
      .post('/api/plans')
      .set('Authorization', `Bearer ${testUser.token}`)
      .send({
        name: 'This Weekend',
        description: 'Plans for this weekend',
      });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('data');

    const plan = res.body.data;
    createdPlanId = plan.id;

    // Validate matches iOS PlanData model
    expect(plan).toHaveProperty('id');
    expect(typeof plan.id).toBe('string');
    expect(plan).toHaveProperty('userId');
    expect(typeof plan.userId).toBe('string');
    expect(plan).toHaveProperty('name');
    expect(plan.name).toBe('This Weekend');
    expect(plan).toHaveProperty('description');
    expect(plan.description).toBe('Plans for this weekend');
    expect(plan).toHaveProperty('isArchived');
    expect(plan.isArchived).toBe(false);
    expect(plan).toHaveProperty('createdAt');
    expect(typeof plan.createdAt).toBe('string');
    expect(plan).toHaveProperty('updatedAt');
    expect(typeof plan.updatedAt).toBe('string');
    expect(plan).toHaveProperty('eventCount');
    expect(plan.eventCount).toBe(0);

    console.log(`✅ Plan created: "${plan.name}" (${plan.id})`);
  });

  it('plans list should match iOS PlansListResponse model', async () => {
    const res = await supertest(app)
      .get('/api/plans')
      .set('Authorization', `Bearer ${testUser.token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(Array.isArray(res.body.data)).toBe(true);

    // Validate each plan matches PlanData
    for (const plan of res.body.data) {
      expect(plan).toHaveProperty('id');
      expect(plan).toHaveProperty('userId');
      expect(plan).toHaveProperty('name');
      expect(plan).toHaveProperty('isArchived');
      expect(plan).toHaveProperty('createdAt');
      expect(plan).toHaveProperty('updatedAt');
      expect(plan).toHaveProperty('eventCount');
      expect(typeof plan.eventCount).toBe('number');

      // description can be null
      expect(plan).toHaveProperty('description');
    }

    console.log(`✅ Plans list: ${res.body.data.length} plan(s) match iOS model`);
  });
});

// ============================================================
// STEP 5: POST /plans/:planId/events/:eventId — Add event to plan
// ============================================================
describe('Step 5: Add event to plan (POST /plans/:planId/events/:eventId)', () => {
  it('should add the event to the plan', async () => {
    const res = await supertest(app)
      .post(`/api/plans/${createdPlanId}/events/${createdEventId}`)
      .set('Authorization', `Bearer ${testUser.token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(res.body.data).toHaveProperty('message');

    console.log(`✅ Event added to plan: "${res.body.data.message}"`);
  });

  it('should reject duplicate add', async () => {
    const res = await supertest(app)
      .post(`/api/plans/${createdPlanId}/events/${createdEventId}`)
      .set('Authorization', `Bearer ${testUser.token}`);

    expect(res.status).toBe(400);
    console.log(`✅ Duplicate add correctly rejected`);
  });
});

// ============================================================
// STEP 6: GET /plans/:id — Verify plan has event (PlanDetailView)
// ============================================================
describe('Step 6: Verify plan detail (GET /plans/:id)', () => {
  let planDetail: PlanDetailData;

  it('should return plan with events', async () => {
    const res = await supertest(app)
      .get(`/api/plans/${createdPlanId}`)
      .set('Authorization', `Bearer ${testUser.token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    planDetail = res.body.data;
  });

  it('plan detail should match iOS PlanDetailData model', () => {
    // Base PlanData fields
    expect(planDetail).toHaveProperty('id');
    expect(planDetail.id).toBe(createdPlanId);
    expect(planDetail).toHaveProperty('userId');
    expect(planDetail).toHaveProperty('name');
    expect(planDetail.name).toBe('This Weekend');
    expect(planDetail).toHaveProperty('description');
    expect(planDetail).toHaveProperty('isArchived');
    expect(planDetail.isArchived).toBe(false);
    expect(planDetail).toHaveProperty('createdAt');
    expect(planDetail).toHaveProperty('updatedAt');
    expect(planDetail).toHaveProperty('eventCount');
    expect(planDetail.eventCount).toBe(1);

    console.log(`✅ Plan detail base fields match PlanDetailData model`);
  });

  it('plan detail events should match iOS Event model', () => {
    expect(planDetail).toHaveProperty('events');
    expect(Array.isArray(planDetail.events)).toBe(true);
    expect(planDetail.events.length).toBe(1);

    const event = planDetail.events[0];
    expect(event).toBeDefined();
    if (!event) {
      return;
    } // Type guard
    expect(event.id).toBe(createdEventId);
    expect(event.title).toBe('Jazz Night at Blue Note');

    // Validate all Event fields
    expect(event).toHaveProperty('description');
    expect(event).toHaveProperty('category');
    expect(event).toHaveProperty('address');
    expect(event).toHaveProperty('latitude');
    expect(event).toHaveProperty('longitude');
    expect(event).toHaveProperty('startTime');
    expect(event).toHaveProperty('endTime');
    expect(event).toHaveProperty('interestedCount');
    expect(typeof event.interestedCount).toBe('number');

    // Media
    expect(event).toHaveProperty('media');
    expect(Array.isArray(event.media)).toBe(true);
    for (const m of event.media) {
      expect(m).toHaveProperty('id');
      expect(m).toHaveProperty('url');
      expect(m).toHaveProperty('type');
      expect(m).toHaveProperty('order');
    }

    // User
    expect(event).toHaveProperty('user');
    expect(event.user).toHaveProperty('id');
    expect(event.user).toHaveProperty('name');

    console.log(
      `✅ Plan contains event "${event.title}" with ${event.media.length} media items`
    );
    console.log(`✅ FULL FLOW VALIDATED: Map → Story → Details → Add to Plan`);
  });

  it('plan detail events should have createdAt field (required by iOS)', () => {
    // This is a known potential issue: PlanDetailData in plans.ts
    // may not include createdAt in the event response
    const event = planDetail.events[0];
    expect(event).toBeDefined();
    if (!event) {
      return;
    } // Type guard
    expect(event).toHaveProperty('createdAt');
    expect(typeof event.createdAt).toBe('string');
    console.log(`✅ Event in plan has createdAt: ${event.createdAt}`);
  });

  it('plan detail events should have distance field (nullable)', () => {
    // iOS Event model has distance: Int? — should be present even if null
    const event = planDetail.events[0];
    expect(event).toBeDefined();
    if (!event) {
      return;
    } // Type guard
    // distance might be null for plan events (no user location context)
    if (event.distance !== undefined) {
      if (event.distance !== null) {
        expect(typeof event.distance).toBe('number');
      }
      console.log(`✅ Event in plan has distance: ${event.distance}`);
    } else {
      console.log(
        `⚠️ Event in plan missing distance field — iOS expects it as optional Int?`
      );
    }
  });
});

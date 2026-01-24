import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';
import type { ApiErrorResponse } from '../types/index.js';
import { prisma } from '../services/prisma.js';
import { supabaseAdmin } from '../services/supabase.js';

describe('Events API - Expiration Filtering', () => {
  let app: Express;
  let authToken: string;
  let userId: string;

  beforeAll(async () => {
    app = createApp();

    // Create test user and get auth token
    const email = `test-expiration-${Date.now()}@example.com`;
    const password = 'SecurePass123';
    const name = 'Test User';

    const { data: authData, error: signupError } = await supabaseAdmin.auth.signUp({
      email,
      password,
      options: { data: { name } },
    });

    if (signupError || !authData.user || !authData.session) {
      throw new Error('Failed to create test user');
    }

    userId = authData.user.id;
    authToken = authData.session.access_token;
  });

  afterAll(async () => {
    // Clean up test data
    await prisma.event.deleteMany({
      where: { userId },
    });
    await prisma.user.deleteMany({
      where: { id: userId },
    });
  });

  describe('GET /events/nearby - should exclude expired events', () => {
    it('should not return events with past endTime', async () => {
      // Create expired event (endTime in the past)
      const pastDate = new Date();
      pastDate.setHours(pastDate.getHours() - 1);

      await prisma.event.create({
        data: {
          userId,
          title: 'Expired Event',
          description: 'This event has ended',
          category: 'music',
          address: '123 Test St, New York, NY 10001', // PRD: Address is primary
          latitude: 40.7128,
          longitude: -74.006,
          startTime: new Date(pastDate.getTime() - 2 * 60 * 60 * 1000), // 2 hours ago
          endTime: pastDate,
        },
      });

      // Create active event (endTime in the future)
      const futureDate = new Date();
      futureDate.setHours(futureDate.getHours() + 2);

      await prisma.event.create({
        data: {
          userId,
          title: 'Active Event',
          description: 'This event is upcoming',
          category: 'music',
          address: '123 Test St, New York, NY 10001', // PRD: Address is primary
          latitude: 40.7128,
          longitude: -74.006,
          startTime: new Date(),
          endTime: futureDate,
        },
      });

      const response = await request(app)
        .get('/api/events/nearby?lat=40.7128&lng=-74.006')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data).toBeInstanceOf(Array);

      // Should only return active event, not expired one
      const eventTitles = response.body.data.map((e: { title: string }) => e.title);
      expect(eventTitles).toContain('Active Event');
      expect(eventTitles).not.toContain('Expired Event');
    });

    it('should not return events with past startTime when endTime is in the past', async () => {
      // Create expired event (endTime in the past, event has ended)
      const pastDate = new Date();
      pastDate.setHours(pastDate.getHours() - 1);

      await prisma.event.create({
        data: {
          userId,
          title: 'Expired Event',
          description: 'This event started and ended in the past',
          category: 'music',
          address: '123 Test St, New York, NY 10001', // PRD: Address is primary
          latitude: 40.7128,
          longitude: -74.006,
          startTime: new Date(pastDate.getTime() - 2 * 60 * 60 * 1000), // 2 hours before endTime
          endTime: pastDate, // PRD: endTime is required
        },
      });

      const response = await request(app)
        .get('/api/events/nearby?lat=40.7128&lng=-74.006')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data).toBeInstanceOf(Array);

      // Should not return expired event
      const eventTitles = response.body.data.map((e: { title: string }) => e.title);
      expect(eventTitles).not.toContain('Expired Event');
    });

    it('should return events with future startTime', async () => {
      // Create future event (startTime and endTime in the future)
      const futureDate = new Date();
      futureDate.setHours(futureDate.getHours() + 2);
      const futureEndDate = new Date();
      futureEndDate.setHours(futureEndDate.getHours() + 4);

      await prisma.event.create({
        data: {
          userId,
          title: 'Future Event',
          description: 'This event is in the future',
          category: 'music',
          address: '123 Test St, New York, NY 10001', // PRD: Address is primary
          latitude: 40.7128,
          longitude: -74.006,
          startTime: futureDate,
          endTime: futureEndDate, // PRD: endTime is required
        },
      });

      const response = await request(app)
        .get('/api/events/nearby?lat=40.7128&lng=-74.006')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data).toBeInstanceOf(Array);

      // Should return future event
      const eventTitles = response.body.data.map((e: { title: string }) => e.title);
      expect(eventTitles).toContain('Future Event');
    });
  });

  describe('GET /events/:id - should return 404 for expired events', () => {
    it('should return 404 for event with past endTime', async () => {
      const pastDate = new Date();
      pastDate.setHours(pastDate.getHours() - 1);

      const expiredEvent = await prisma.event.create({
        data: {
          userId,
          title: 'Expired Event for Get',
          description: 'This event has ended',
          category: 'music',
          address: '123 Test St, New York, NY 10001', // PRD: Address is primary
          latitude: 40.7128,
          longitude: -74.006,
          startTime: new Date(pastDate.getTime() - 2 * 60 * 60 * 1000),
          endTime: pastDate,
        },
      });

      const response = await request(app)
        .get(`/api/events/${expiredEvent.id}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(404);
      expect((response.body as ApiErrorResponse).error.code).toBe('NOT_FOUND');
    });

    it('should return 404 for event with past endTime', async () => {
      const pastDate = new Date();
      pastDate.setHours(pastDate.getHours() - 1);

      const expiredEvent = await prisma.event.create({
        data: {
          userId,
          title: 'Expired Event for Get',
          description: 'This event ended in the past',
          category: 'music',
          address: '123 Test St, New York, NY 10001', // PRD: Address is primary
          latitude: 40.7128,
          longitude: -74.006,
          startTime: new Date(pastDate.getTime() - 2 * 60 * 60 * 1000), // 2 hours before endTime
          endTime: pastDate, // PRD: endTime is required
        },
      });

      const response = await request(app)
        .get(`/api/events/${expiredEvent.id}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(404);
      expect((response.body as ApiErrorResponse).error.code).toBe('NOT_FOUND');
    });

    it('should return event with future endTime', async () => {
      const futureDate = new Date();
      futureDate.setHours(futureDate.getHours() + 2);

      const activeEvent = await prisma.event.create({
        data: {
          userId,
          title: 'Active Event for Get',
          description: 'This event is upcoming',
          category: 'music',
          address: '123 Test St, New York, NY 10001', // PRD: Address is primary
          latitude: 40.7128,
          longitude: -74.006,
          startTime: new Date(),
          endTime: futureDate,
        },
      });

      const response = await request(app)
        .get(`/api/events/${activeEvent.id}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data).toHaveProperty('id', activeEvent.id);
      expect(response.body.data).toHaveProperty('title', 'Active Event for Get');
    });
  });
});

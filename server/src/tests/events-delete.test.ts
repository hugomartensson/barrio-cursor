import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';
import type { ApiErrorResponse } from '../types/index.js';
import { prisma } from '../services/prisma.js';
import { supabaseAdmin } from '../services/supabase.js';

describe('Events API - Delete Event', () => {
  let app: Express;
  let ownerToken: string;
  let ownerId: string;
  let otherUserToken: string;
  let otherUserId: string;

  beforeAll(async () => {
    app = createApp();

    // Create owner user
    const ownerEmail = `owner-delete-${Date.now()}@example.com`;
    const { data: ownerData, error: ownerError } = await supabaseAdmin.auth.signUp({
      email: ownerEmail,
      password: 'SecurePass123',
      options: { data: { name: 'Owner User' } },
    });

    if (ownerError || !ownerData.user || !ownerData.session) {
      throw new Error('Failed to create owner user');
    }

    ownerId = ownerData.user.id;
    ownerToken = ownerData.session.access_token;

    // Create other user
    const otherEmail = `other-delete-${Date.now()}@example.com`;
    const { data: otherData, error: otherError } = await supabaseAdmin.auth.signUp({
      email: otherEmail,
      password: 'SecurePass123',
      options: { data: { name: 'Other User' } },
    });

    if (otherError || !otherData.user || !otherData.session) {
      throw new Error('Failed to create other user');
    }

    otherUserId = otherData.user.id;
    otherUserToken = otherData.session.access_token;
  });

  afterAll(async () => {
    // Clean up test data
    await prisma.event.deleteMany({
      where: { userId: { in: [ownerId, otherUserId] } },
    });
    await prisma.user.deleteMany({
      where: { id: { in: [ownerId, otherUserId] } },
    });
  });

  describe('DELETE /events/:id - successful deletion by owner', () => {
    it('should delete event when user is the owner', async () => {
      // Create event owned by owner
      const futureDate = new Date();
      futureDate.setHours(futureDate.getHours() + 2);

      const event = await prisma.event.create({
        data: {
          userId: ownerId,
          title: 'Event to Delete',
          description: 'This event will be deleted',
          category: 'music',
          latitude: 40.7128,
          longitude: -74.006,
          startTime: new Date(),
          endTime: futureDate,
        },
      });

      // Add media, likes, and going to test cascade deletion
      await prisma.mediaItem.create({
        data: {
          eventId: event.id,
          url: 'https://example.com/image.jpg',
          type: 'photo',
          order: 0,
        },
      });

      await prisma.like.create({
        data: {
          userId: otherUserId,
          eventId: event.id,
        },
      });

      await prisma.going.create({
        data: {
          userId: otherUserId,
          eventId: event.id,
        },
      });

      // Delete the event
      const response = await request(app)
        .delete(`/api/events/${event.id}`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data).toHaveProperty('message', 'Event deleted successfully');

      // Verify event is deleted
      const deletedEvent = await prisma.event.findUnique({
        where: { id: event.id },
      });
      expect(deletedEvent).toBeNull();

      // Verify cascade deletion of related records
      const media = await prisma.mediaItem.findMany({
        where: { eventId: event.id },
      });
      expect(media).toHaveLength(0);

      const likes = await prisma.like.findMany({
        where: { eventId: event.id },
      });
      expect(likes).toHaveLength(0);

      const going = await prisma.going.findMany({
        where: { eventId: event.id },
      });
      expect(going).toHaveLength(0);
    });
  });

  describe('DELETE /events/:id - permission errors', () => {
    it('should return 403 when user is not the owner', async () => {
      // Create event owned by owner
      const futureDate = new Date();
      futureDate.setHours(futureDate.getHours() + 2);

      const event = await prisma.event.create({
        data: {
          userId: ownerId,
          title: 'Event Not Owned by Other User',
          description: 'This event belongs to owner',
          category: 'music',
          latitude: 40.7128,
          longitude: -74.006,
          startTime: new Date(),
          endTime: futureDate,
        },
      });

      // Try to delete as other user
      const response = await request(app)
        .delete(`/api/events/${event.id}`)
        .set('Authorization', `Bearer ${otherUserToken}`);

      expect(response.status).toBe(403);
      expect((response.body as ApiErrorResponse).error.code).toBe('FORBIDDEN');
      expect((response.body as ApiErrorResponse).error.message).toContain(
        "You don't have permission to delete this event"
      );

      // Verify event still exists
      const existingEvent = await prisma.event.findUnique({
        where: { id: event.id },
      });
      expect(existingEvent).not.toBeNull();

      // Clean up
      await prisma.event.delete({ where: { id: event.id } });
    });

    it('should return 404 when event does not exist', async () => {
      const fakeEventId = '123e4567-e89b-12d3-a456-426614174000';

      const response = await request(app)
        .delete(`/api/events/${fakeEventId}`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(response.status).toBe(404);
      expect((response.body as ApiErrorResponse).error.code).toBe('NOT_FOUND');
      expect((response.body as ApiErrorResponse).error.message).toContain(
        'Event not found'
      );
    });
  });

  describe('DELETE /events/:id - authentication', () => {
    it('should reject without auth token', async () => {
      const fakeEventId = '123e4567-e89b-12d3-a456-426614174000';

      const response = await request(app).delete(`/api/events/${fakeEventId}`);

      expect(response.status).toBe(401);
      expect((response.body as ApiErrorResponse).error.code).toBe('UNAUTHORIZED');
    });

    it('should reject with invalid token', async () => {
      const fakeEventId = '123e4567-e89b-12d3-a456-426614174000';

      const response = await request(app)
        .delete(`/api/events/${fakeEventId}`)
        .set('Authorization', 'Bearer invalid-token');

      expect(response.status).toBe(401);
      expect((response.body as ApiErrorResponse).error.code).toBe('UNAUTHORIZED');
    });
  });
});

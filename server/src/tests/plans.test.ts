import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';
import type { ApiErrorResponse } from '../types/index.js';
import {
  createPlanSchema,
  updatePlanSchema,
  addPlanItemsSchema,
  updatePlanItemSchema,
  inviteMembersSchema,
} from '../schemas/plans.js';

describe('Plan Schemas', () => {
  describe('createPlanSchema', () => {
    it('accepts valid input', () => {
      const result = createPlanSchema.safeParse({
        name: 'Barcelona Trip',
        startDate: '2026-06-01',
        endDate: '2026-06-05',
      });
      expect(result.success).toBe(true);
    });

    it('defaults initialItems dayOffset to -1', () => {
      const result = createPlanSchema.safeParse({
        name: 'Trip',
        startDate: '2026-06-01',
        endDate: '2026-06-05',
        initialItems: [
          { itemType: 'spot', itemId: '00000000-0000-0000-0000-000000000001' },
        ],
      });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.initialItems?.[0]?.dayOffset).toBe(-1);
      }
    });

    it('rejects invalid date format', () => {
      const result = createPlanSchema.safeParse({
        name: 'Trip',
        startDate: '06-01-2026',
        endDate: '2026-06-05',
      });
      expect(result.success).toBe(false);
    });

    it('rejects empty name', () => {
      const result = createPlanSchema.safeParse({
        name: '',
        startDate: '2026-06-01',
        endDate: '2026-06-05',
      });
      expect(result.success).toBe(false);
    });
  });

  describe('updatePlanSchema', () => {
    it('accepts partial update', () => {
      const result = updatePlanSchema.safeParse({ name: 'New Name' });
      expect(result.success).toBe(true);
    });

    it('accepts empty object', () => {
      const result = updatePlanSchema.safeParse({});
      expect(result.success).toBe(true);
    });
  });

  describe('addPlanItemsSchema', () => {
    it('accepts items with explicit dayOffset -1', () => {
      const result = addPlanItemsSchema.safeParse({
        items: [
          {
            itemType: 'spot',
            itemId: '00000000-0000-0000-0000-000000000001',
            dayOffset: -1,
          },
        ],
      });
      expect(result.success).toBe(true);
    });

    it('accepts items with dayOffset 0', () => {
      const result = addPlanItemsSchema.safeParse({
        items: [
          {
            itemType: 'event',
            itemId: '00000000-0000-0000-0000-000000000002',
            dayOffset: 0,
          },
        ],
      });
      expect(result.success).toBe(true);
    });

    it('rejects dayOffset below -1', () => {
      const result = addPlanItemsSchema.safeParse({
        items: [
          {
            itemType: 'spot',
            itemId: '00000000-0000-0000-0000-000000000001',
            dayOffset: -2,
          },
        ],
      });
      expect(result.success).toBe(false);
    });

    it('rejects empty items array', () => {
      const result = addPlanItemsSchema.safeParse({ items: [] });
      expect(result.success).toBe(false);
    });
  });

  describe('updatePlanItemSchema', () => {
    it('accepts dayOffset -1 for unscheduling', () => {
      const result = updatePlanItemSchema.safeParse({ dayOffset: -1 });
      expect(result.success).toBe(true);
    });

    it('accepts positive dayOffset', () => {
      const result = updatePlanItemSchema.safeParse({ dayOffset: 3 });
      expect(result.success).toBe(true);
    });

    it('rejects non-integer dayOffset', () => {
      const result = updatePlanItemSchema.safeParse({ dayOffset: 1.5 });
      expect(result.success).toBe(false);
    });
  });

  describe('inviteMembersSchema', () => {
    it('accepts non-empty userIds', () => {
      const result = inviteMembersSchema.safeParse({ userIds: ['user-1', 'user-2'] });
      expect(result.success).toBe(true);
    });

    it('rejects empty userIds array', () => {
      const result = inviteMembersSchema.safeParse({ userIds: [] });
      expect(result.success).toBe(false);
    });
  });
});

describe('Plans API - Auth Guards', () => {
  let app: Express;

  beforeAll(() => {
    app = createApp();
  });

  const endpoints: { method: 'get' | 'post' | 'patch' | 'delete'; path: string }[] = [
    { method: 'get', path: '/api/plans' },
    { method: 'post', path: '/api/plans' },
    { method: 'get', path: '/api/plans/invitations/count' },
    { method: 'get', path: '/api/plans/some-id' },
    { method: 'patch', path: '/api/plans/some-id' },
    { method: 'delete', path: '/api/plans/some-id' },
    { method: 'post', path: '/api/plans/some-id/items' },
    { method: 'patch', path: '/api/plans/some-id/items/item-id' },
    { method: 'delete', path: '/api/plans/some-id/items/item-id' },
    { method: 'get', path: '/api/plans/some-id/members' },
    { method: 'post', path: '/api/plans/some-id/members' },
    { method: 'post', path: '/api/plans/some-id/members/accept' },
    { method: 'post', path: '/api/plans/some-id/members/decline' },
    { method: 'delete', path: '/api/plans/some-id/members/me' },
  ];

  endpoints.forEach(({ method, path }) => {
    it(`${method.toUpperCase()} ${path} requires authentication`, async () => {
      const response = await request(app)[method](path);
      expect(response.status).toBe(401);
      expect((response.body as ApiErrorResponse).error.code).toBe('UNAUTHORIZED');
    });
  });

  endpoints.forEach(({ method, path }) => {
    it(`${method.toUpperCase()} ${path} rejects invalid token`, async () => {
      const response = await request(app)
        [method](path)
        .set('Authorization', 'Bearer invalid-token');
      expect(response.status).toBe(401);
      expect((response.body as ApiErrorResponse).error.code).toBe('UNAUTHORIZED');
    });
  });
});

import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';

describe('Events API - Get Event Auth', () => {
  let app: Express;
  beforeAll(() => {
    app = createApp();
  });

  it('should reject without auth token', async () => {
    const response = await request(app).get(
      '/api/events/123e4567-e89b-12d3-a456-426614174000'
    );
    expect(response.status).toBe(401);
  });

  it('should reject with invalid token', async () => {
    const response = await request(app)
      .get('/api/events/123e4567-e89b-12d3-a456-426614174000')
      .set('Authorization', 'Bearer fake-token');
    expect(response.status).toBe(401);
  });
});

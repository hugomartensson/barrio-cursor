import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';

describe('Events API - Nearby Events Auth', () => {
  let app: Express;
  beforeAll(() => {
    app = createApp();
  });

  it('should reject without auth token', async () => {
    const response = await request(app).get('/api/events/nearby?lat=40.7&lng=-74.0');
    expect(response.status).toBe(401);
  });

  it('should reject with invalid token', async () => {
    const response = await request(app)
      .get('/api/events/nearby?lat=40.7&lng=-74.0')
      .set('Authorization', 'Bearer fake-token');
    expect(response.status).toBe(401);
  });
});

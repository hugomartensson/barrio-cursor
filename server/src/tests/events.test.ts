import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';

describe('Events API - Create Event Auth', () => {
  let app: Express;
  beforeAll(() => {
    app = createApp();
  });

  it('should reject without auth token', async () => {
    const response = await request(app).post('/api/events').send({});
    expect(response.status).toBe(401);
  });

  it('should reject with invalid auth token', async () => {
    const response = await request(app)
      .post('/api/events')
      .set('Authorization', 'Bearer fake-token')
      .send({ title: 'Test', description: 'Test', category: 'music' });
    expect(response.status).toBe(401);
  });
});

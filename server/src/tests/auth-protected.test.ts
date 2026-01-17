import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';
import type { ApiErrorResponse } from '../types/index.js';

describe('Auth API - Protected Routes', () => {
  let app: Express;

  beforeAll(() => {
    app = createApp();
  });

  it('should reject requests without auth header', async () => {
    const response = await request(app).get('/api/users/me');

    expect(response.status).toBe(401);
    expect((response.body as ApiErrorResponse).error.code).toBe('UNAUTHORIZED');
  });

  it('should reject requests with invalid token', async () => {
    const response = await request(app)
      .get('/api/users/me')
      .set('Authorization', 'Bearer invalid-token');

    expect(response.status).toBe(401);
    expect((response.body as ApiErrorResponse).error.code).toBe('UNAUTHORIZED');
  });

  it('should reject reset with invalid email', async () => {
    const response = await request(app)
      .post('/api/auth/reset-password')
      .send({ email: 'not-an-email' });

    expect(response.status).toBe(400);
    expect((response.body as ApiErrorResponse).error.code).toBe('VALIDATION_ERROR');
  });
});



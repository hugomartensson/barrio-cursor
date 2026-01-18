import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';
import type { ApiErrorResponse } from '../types/index.js';

// Note: Test passwords like 'password123' are acceptable in test files
// These are not real secrets and are only used for test validation

describe('Auth API - Login Validation', () => {
  let app: Express;

  beforeAll(() => {
    app = createApp();
  });

  it('should reject login with invalid email', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'not-an-email', password: 'password123' });

    expect(response.status).toBe(400);
    expect((response.body as ApiErrorResponse).error.code).toBe('VALIDATION_ERROR');
  });

  it('should reject login without password', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com' });

    expect(response.status).toBe(400);
    expect((response.body as ApiErrorResponse).error.code).toBe('VALIDATION_ERROR');
  });
});

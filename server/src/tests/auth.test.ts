import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';
import type { ApiErrorResponse } from '../types/index.js';

describe('Auth API - Signup Validation', () => {
  let app: Express;

  beforeAll(() => {
    app = createApp();
  });

  it('should reject signup with invalid email', async () => {
    const response = await request(app)
      .post('/api/auth/signup')
      .send({ email: 'not-an-email', password: 'SecurePass123', name: 'Test User' });

    expect(response.status).toBe(400);
    expect((response.body as ApiErrorResponse).error.code).toBe('VALIDATION_ERROR');
  });

  it('should reject signup with weak password', async () => {
    const response = await request(app)
      .post('/api/auth/signup')
      .send({ email: 'test@example.com', password: 'weak', name: 'Test User' });

    expect(response.status).toBe(400);
    expect((response.body as ApiErrorResponse).error.code).toBe('VALIDATION_ERROR');
  });

  it('should reject signup without name', async () => {
    const response = await request(app)
      .post('/api/auth/signup')
      .send({ email: 'test@example.com', password: 'SecurePass123' });

    expect(response.status).toBe(400);
    expect((response.body as ApiErrorResponse).error.code).toBe('VALIDATION_ERROR');
  });
});

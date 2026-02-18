import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';
import type { ApiErrorResponse } from '../types/index.js';
import { prisma } from '../services/prisma.js';
import { supabaseAdmin } from '../services/supabase.js';

describe('Users API - PATCH /users/me', () => {
  let app: Express;
  let authToken: string;
  let userId: string;
  const originalName = 'Original Name';

  beforeAll(async () => {
    app = createApp();

    // Create test user and get auth token
    const email = `test-patch-${Date.now()}@example.com`;
    const password = 'SecurePass123';
    const name = originalName;

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

    // Login via API to sync user to local DB (required for Prisma FK constraints)
    const loginRes = await request(app).post('/api/auth/login').send({ email, password });
    if (loginRes.status === 200 && loginRes.body.data?.token) {
      authToken = loginRes.body.data.token;
    }
  });

  afterAll(async () => {
    // Clean up test data
    await prisma.user.deleteMany({
      where: { id: userId },
    });
  });

  describe('PATCH /users/me - successful name update', () => {
    it('should update user name successfully', async () => {
      const newName = 'Updated Name';
      const response = await request(app)
        .patch('/api/users/me')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: newName });

      expect(response.status).toBe(200);
      expect(response.body.data).toMatchObject({
        id: userId,
        name: newName,
      });
      expect(response.body.data.email).toBeDefined();

      // Verify in database
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { name: true },
      });
      expect(user?.name).toBe(newName);
    });

    it('should return updated user object with all fields', async () => {
      const newName = 'Another Updated Name';
      const response = await request(app)
        .patch('/api/users/me')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: newName });

      expect(response.status).toBe(200);
      expect(response.body.data).toHaveProperty('id');
      expect(response.body.data).toHaveProperty('email');
      expect(response.body.data).toHaveProperty('name');
      expect(response.body.data.name).toBe(newName);
    });
  });

  describe('PATCH /users/me - validation errors', () => {
    it('should reject empty name', async () => {
      const response = await request(app)
        .patch('/api/users/me')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: '' });

      expect(response.status).toBe(400);
      expect((response.body as ApiErrorResponse).error.code).toBe('VALIDATION_ERROR');
      expect((response.body as ApiErrorResponse).error.details).toHaveProperty('name');
    });

    it('should reject name that is too long (over 100 characters)', async () => {
      const longName = 'a'.repeat(101);
      const response = await request(app)
        .patch('/api/users/me')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: longName });

      expect(response.status).toBe(400);
      expect((response.body as ApiErrorResponse).error.code).toBe('VALIDATION_ERROR');
      expect((response.body as ApiErrorResponse).error.details).toHaveProperty('name');
    });

    it('should reject request without name field', async () => {
      const response = await request(app)
        .patch('/api/users/me')
        .set('Authorization', `Bearer ${authToken}`)
        .send({});

      expect(response.status).toBe(400);
      expect((response.body as ApiErrorResponse).error.code).toBe('VALIDATION_ERROR');
    });

    it('should accept name at maximum length (100 characters)', async () => {
      const maxLengthName = 'a'.repeat(100);
      const response = await request(app)
        .patch('/api/users/me')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: maxLengthName });

      expect(response.status).toBe(200);
      expect(response.body.data.name).toBe(maxLengthName);
    });
  });

  describe('PATCH /users/me - auth required', () => {
    it('should reject request without auth header', async () => {
      const response = await request(app)
        .patch('/api/users/me')
        .send({ name: 'New Name' });

      expect(response.status).toBe(401);
      expect((response.body as ApiErrorResponse).error.code).toBe('UNAUTHORIZED');
    });

    it('should reject request with invalid token', async () => {
      const response = await request(app)
        .patch('/api/users/me')
        .set('Authorization', 'Bearer invalid-token')
        .send({ name: 'New Name' });

      expect(response.status).toBe(401);
      expect((response.body as ApiErrorResponse).error.code).toBe('UNAUTHORIZED');
    });
  });
});

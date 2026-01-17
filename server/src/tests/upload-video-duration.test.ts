import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';
import type { ApiErrorResponse } from '../types/index.js';
import { supabaseAdmin } from '../services/supabase.js';

describe('Upload API - Video Duration Validation', () => {
  let app: Express;
  let authToken: string;

  beforeAll(async () => {
    app = createApp();

    // Create test user and get auth token
    const email = `test-video-${Date.now()}@example.com`;
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

    authToken = authData.session.access_token;
  });

  describe('POST /upload - video duration validation', () => {
    it('should reject video without duration parameter', async () => {
      // Create a minimal base64 video (just a placeholder)
      const base64Video = 'data:video/mp4;base64,AAAAIGZ0eXBpc29t';

      const response = await request(app)
        .post('/api/upload')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          image: base64Video,
          contentType: 'video/mp4',
        });

      expect(response.status).toBe(400);
      expect((response.body as ApiErrorResponse).error.code).toBe('BAD_REQUEST');
      expect((response.body as ApiErrorResponse).error.message).toContain('duration');
    });

    it('should reject video with duration > 15 seconds', async () => {
      // Create a minimal base64 video (just a placeholder)
      const base64Video = 'data:video/mp4;base64,AAAAIGZ0eXBpc29t';

      const response = await request(app)
        .post('/api/upload')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          image: base64Video,
          contentType: 'video/mp4',
          duration: 16, // 16 seconds - exceeds limit
        });

      expect(response.status).toBe(422);
      expect((response.body as ApiErrorResponse).error.code).toBe('UNPROCESSABLE_ENTITY');
      expect((response.body as ApiErrorResponse).error.message).toContain('15 seconds or less');
    });

    it('should accept video with duration = 15 seconds', async () => {
      // Create a minimal base64 video (just a placeholder)
      const base64Video = 'data:video/mp4;base64,AAAAIGZ0eXBpc29t';

      const response = await request(app)
        .post('/api/upload')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          image: base64Video,
          contentType: 'video/mp4',
          duration: 15, // Exactly 15 seconds - should be accepted
        });

      // Note: This will fail at Supabase upload, but duration validation should pass
      // We're testing the duration validation, not the actual upload
      expect(response.status).not.toBe(422);
      expect((response.body as ApiErrorResponse).error?.code).not.toBe('UNPROCESSABLE_ENTITY');
    });

    it('should accept video with duration < 15 seconds', async () => {
      // Create a minimal base64 video (just a placeholder)
      const base64Video = 'data:video/mp4;base64,AAAAIGZ0eXBpc29t';

      const response = await request(app)
        .post('/api/upload')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          image: base64Video,
          contentType: 'video/mp4',
          duration: 10, // 10 seconds - should be accepted
        });

      // Note: This will fail at Supabase upload, but duration validation should pass
      expect(response.status).not.toBe(422);
      expect((response.body as ApiErrorResponse).error?.code).not.toBe('UNPROCESSABLE_ENTITY');
    });

    it('should accept image without duration parameter', async () => {
      // Create a minimal base64 image (1x1 pixel PNG)
      const base64Image =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      const response = await request(app)
        .post('/api/upload')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          image: base64Image,
          contentType: 'image/png',
          // No duration - should be fine for images
        });

      // Note: This will fail at Supabase upload, but duration validation should pass
      expect(response.status).not.toBe(400);
      expect((response.body as ApiErrorResponse).error?.message).not.toContain('duration');
    });
  });
});

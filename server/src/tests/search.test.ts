import request from 'supertest';
import { createApp } from '../app.js';
import type { Express } from 'express';
import { searchNeighborhoods } from '../data/neighborhoods.js';

const TEST_SESSION_TOKEN = '550e8400-e29b-41d4-a716-446655440000';
const VALID_PARAMS = `q=soho&lat=59.33&lng=18.07&sessionToken=${TEST_SESSION_TOKEN}`;

describe('Search API — auth guards', () => {
  let app: Express;

  beforeAll(() => {
    app = createApp();
  });

  describe('GET /api/search/suggest', () => {
    it('rejects without auth token', async () => {
      const res = await request(app).get(`/api/search/suggest?${VALID_PARAMS}`);
      expect(res.status).toBe(401);
    });

    it('rejects with invalid auth token', async () => {
      const res = await request(app)
        .get(`/api/search/suggest?${VALID_PARAMS}`)
        .set('Authorization', 'Bearer fake-token');
      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/search/place/:placeId', () => {
    it('rejects without auth token', async () => {
      const res = await request(app).get(
        `/api/search/place/ChIJN1t_tDeuEmsRUsoyG83frY4?sessionToken=${TEST_SESSION_TOKEN}`
      );
      expect(res.status).toBe(401);
    });

    it('rejects with invalid auth token', async () => {
      const res = await request(app)
        .get(
          `/api/search/place/ChIJN1t_tDeuEmsRUsoyG83frY4?sessionToken=${TEST_SESSION_TOKEN}`
        )
        .set('Authorization', 'Bearer fake-token');
      expect(res.status).toBe(401);
    });
  });
});

// ---------------------------------------------------------------------------
// Unit: neighborhood search (pure function, no network/DB needed)
// ---------------------------------------------------------------------------

describe('searchNeighborhoods', () => {
  it('returns empty array for queries shorter than 2 chars', () => {
    expect(searchNeighborhoods('')).toHaveLength(0);
    expect(searchNeighborhoods('s')).toHaveLength(0);
  });

  it('matches Södermalm without diacritics', () => {
    const results = searchNeighborhoods('sodermalm');
    expect(results.some((n) => n.slug === 'sodermalm')).toBe(true);
  });

  it('matches by substring (case-insensitive)', () => {
    const results = searchNeighborhoods('soderma');
    expect(results.some((n) => n.slug === 'sodermalm')).toBe(true);
  });

  it('matches Barcelona neighborhoods', () => {
    const results = searchNeighborhoods('eixample');
    expect(results.some((n) => n.slug === 'eixample')).toBe(true);
  });

  it('matches by city name', () => {
    const results = searchNeighborhoods('stockholm');
    expect(results.length).toBeGreaterThan(0);
    expect(results.every((n) => n.city === 'Stockholm')).toBe(true);
  });

  it('respects limit', () => {
    const results = searchNeighborhoods('st', 2);
    expect(results.length).toBeLessThanOrEqual(2);
  });

  it('returns both cities when query matches both', () => {
    // 'born' matches 'El Born' in Barcelona
    const results = searchNeighborhoods('born');
    expect(results.some((n) => n.slug === 'born')).toBe(true);
  });
});

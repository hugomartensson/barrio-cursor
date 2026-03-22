import { normalizeMastraApiBase } from './mastraUrl.js';

describe('normalizeMastraApiBase', () => {
  it('strips trailing slashes', () => {
    expect(normalizeMastraApiBase('https://m.example.com/')).toBe(
      'https://m.example.com'
    );
    expect(normalizeMastraApiBase('https://m.example.com///')).toBe(
      'https://m.example.com'
    );
  });

  it('strips trailing /api', () => {
    expect(normalizeMastraApiBase('https://m.example.com/api')).toBe(
      'https://m.example.com'
    );
    expect(normalizeMastraApiBase('https://m.example.com/api/')).toBe(
      'https://m.example.com'
    );
  });
});

import { createClient } from '@supabase/supabase-js';
import { config } from '../config/index.js';

// Custom fetch with extended timeout for large file uploads
// Supabase storage uploads can be slow, especially for videos
const customFetch = (input: string | Request | URL, init?: RequestInit) => {
  // Increase timeout for storage operations (5 minutes for large uploads)
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 5 * 60 * 1000); // 5 minutes

  return fetch(input, {
    ...init,
    signal: controller.signal,
  }).finally(() => {
    clearTimeout(timeoutId);
  });
};

// Supabase client for server-side operations (uses service key)
export const supabaseAdmin = createClient(
  config.SUPABASE_URL,
  config.SUPABASE_SERVICE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    global: {
      fetch: customFetch,
    },
  }
);

// Supabase client for client-facing operations (uses anon key)
export const supabase = createClient(config.SUPABASE_URL, config.SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

// Storage bucket name for media uploads
export const STORAGE_BUCKET = config.SUPABASE_STORAGE_BUCKET;

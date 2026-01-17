import { createClient } from '@supabase/supabase-js';
import { config } from '../config/index.js';

// Supabase client for server-side operations (uses service key)
export const supabaseAdmin = createClient(
  config.SUPABASE_URL,
  config.SUPABASE_SERVICE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
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

import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z
    .string()
    .default('3000')
    .transform((val) => parseInt(val, 10)),
  DATABASE_URL: z.string(),
  DIRECT_URL: z.string().optional(), // Phase 10: Optional direct connection URL for tests
  JWT_SECRET: z.string().min(32),
  JWT_EXPIRES_IN: z.string().default('7d'),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_KEY: z.string(),
  SUPABASE_ANON_KEY: z.string(),
  SUPABASE_STORAGE_BUCKET: z.string().default('media'),
  CORS_ORIGIN: z.string().default('*'),
  ANTHROPIC_API_KEY: z.string().optional(),
  GEMINI_API_KEY: z.string().optional(),
  GOOGLE_MAPS_API_KEY: z.string().optional(),
  TELEGRAM_BOT_TOKEN: z.string().optional(),
  TELEGRAM_ALLOWED_USER_ID: z.string().optional(),
  PORTAL_TEAM_EMAIL: z.string().email().optional(),
  PORTAL_TEAM_PASSWORD: z.string().optional(),
  PORTAL_EMAIL: z.string().email().optional(),
  PORTAL_PASSWORD: z.string().optional(),
  PORTAL_API_URL: z.string().url().optional(),
  MASTRA_API_URL: z.string().url().optional(),
  MASTRA_SERVER_TOKEN: z.string().optional(),
  ADMIN_USERNAME: z.string().optional(),
  ADMIN_PASSWORD: z.string().optional(),
});

const parseEnv = (): z.infer<typeof envSchema> => {
  const parsed = envSchema.safeParse(process.env);

  if (!parsed.success) {
    // Use console.error here since logger depends on config
    // This is a bootstrap error before logger is initialized
    console.error('❌ Invalid environment variables:');
    console.error(parsed.error.flatten().fieldErrors);
    process.exit(1);
  }

  return parsed.data;
};

export const config = parseEnv();

export const isProduction = config.NODE_ENV === 'production';
export const isDevelopment = config.NODE_ENV === 'development';
export const isTest = config.NODE_ENV === 'test';

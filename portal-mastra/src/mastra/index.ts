import 'dotenv/config';
import { Mastra } from '@mastra/core/mastra';
import { PostgresStore } from '@mastra/pg';
import { extractorAgent } from './agents/extractor.js';
import { verifierAgent } from './agents/verifier.js';
import { ingestWorkflow } from './workflows/ingest.js';

/**
 * Persistent Postgres storage via the existing Supabase database.
 * Mastra auto-creates its tables (mastra_*) on first connect.
 * Requires DATABASE_URL (pooler) or DIRECT_URL env var.
 */
function getConnectionString(): string {
  const url =
    process.env.MASTRA_DATABASE_URL?.trim() ||
    process.env.DATABASE_URL?.trim() ||
    process.env.DIRECT_URL?.trim();
  if (!url) {
    throw new Error(
      'DATABASE_URL (or MASTRA_DATABASE_URL / DIRECT_URL) is required for Mastra storage',
    );
  }
  return url;
}

const storage = new PostgresStore({
  connectionString: getConnectionString(),
});

export const mastra = new Mastra({
  agents: {
    extractor: extractorAgent,
    verifier: verifierAgent,
  },
  workflows: {
    ingest: ingestWorkflow,
  },
  storage,
  server: {
    port: Number.parseInt(process.env.PORT ?? '4111', 10),
    host: process.env.HOST ?? '0.0.0.0',
    auth: {
      authenticateToken: async (token: string) => {
        // Trim secret — Railway/UI pastes often include a trailing newline, which breaks ===
        const secret = process.env.MASTRA_SERVER_TOKEN?.trim();
        if (!secret) {
          return { id: 'open', sub: 'mastra-dev' };
        }
        // Mastra strips "Bearer " in most paths; normalize in case a proxy passes the full header
        const raw = (token ?? '').trim().replace(/^Bearer\s+/i, '').trim();
        if (raw !== secret) {
          return null;
        }
        return { id: 'ingest-client', sub: 'mastra' };
      },
    },
  },
});

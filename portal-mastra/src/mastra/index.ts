import 'dotenv/config';
import { Mastra } from '@mastra/core/mastra';
import { LibSQLStore } from '@mastra/libsql';
import { extractorAgent } from './agents/extractor.js';
import { verifierAgent } from './agents/verifier.js';
import { ingestWorkflow } from './workflows/ingest.js';

/**
 * LibSQL file URLs must point at a writable path. Railway runs from `.mastra/output`;
 * `./.mastra/mastra.db` is missing/read-only there → SQLite error 14. Use /tmp on hosts
 * without a persistent project dir, or set MASTRA_STORAGE_URL to Turso for durable storage.
 */
function resolveMastraStorageUrl(): string {
  const explicit = process.env.MASTRA_STORAGE_URL?.trim();
  if (explicit) return explicit;

  const onRailway = Boolean(
    process.env.RAILWAY_ENVIRONMENT || process.env.RAILWAY_SERVICE_NAME
  );
  const prod = process.env.NODE_ENV === 'production';
  if (onRailway || prod) {
    return 'file:/tmp/mastra.db';
  }

  return 'file:./.mastra/mastra.db';
}

const storage = new LibSQLStore({
  id: 'portal-mastra-store',
  url: resolveMastraStorageUrl(),
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
        let raw = (token ?? '').trim().replace(/^Bearer\s+/i, '').trim();
        if (raw !== secret) {
          return null;
        }
        return { id: 'ingest-client', sub: 'mastra' };
      },
    },
  },
});

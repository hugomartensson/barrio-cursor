import 'dotenv/config';
import { Mastra } from '@mastra/core/mastra';
import { LibSQLStore } from '@mastra/libsql';
import { extractorAgent } from './agents/extractor.js';
import { verifierAgent } from './agents/verifier.js';
import { ingestWorkflow } from './workflows/ingest.js';

const storage = new LibSQLStore({
  id: 'portal-mastra-store',
  url: process.env.MASTRA_STORAGE_URL ?? 'file:./.mastra/mastra.db',
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
        const secret = process.env.MASTRA_SERVER_TOKEN;
        if (!secret) {
          return { id: 'open', sub: 'mastra-dev' };
        }
        const raw = (token ?? '').trim();
        if (raw !== secret) {
          return null;
        }
        return { id: 'ingest-client', sub: 'mastra' };
      },
    },
  },
});

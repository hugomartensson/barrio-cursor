# Portal Mastra — ingest pipeline

Agentic extraction (Gemini + tools), verification, human-in-the-loop suspend, then publish to the Portal API.

## Local dev

1. Copy `.env.example` → `.env` and fill keys.
2. From repo root, run the Barrio API (`server`) on port 3000.
3. `npm run dev` — Studio + API default to port **4111**.

## Environment

See `.env.example`. Important:

- `GOOGLE_GENERATIVE_AI_API_KEY` — Gemini for agents + image validator
- `GOOGLE_PLACES_API_KEY` — Places Text Search + Details + Photos
- `TAVILY_API_KEY` — optional web search
- `PORTAL_*` + `SUPABASE_*` — publish + ingest image bucket
- `MASTRA_SERVER_TOKEN` — set in production; **must be identical** to the Barrio API’s `MASTRA_SERVER_TOKEN` (generate once, paste on both services — mismatched values → **401/403**)

Create a **public** Supabase Storage bucket (default name `ingest-images`) or set `SUPABASE_INGEST_BUCKET`.

### Workflow storage (LibSQL)

- **Local:** default `file:./.mastra/mastra.db` under the project.
- **Railway / `NODE_ENV=production`:** defaults to **`file:/tmp/mastra.db`** so the container can create the DB (the bundled app cwd is not writable for `./.mastra/…`).
- **`/tmp` is ephemeral** on PaaS (lost on redeploy). For durable suspended runs across deploys, set **`MASTRA_STORAGE_URL`** to a [Turso](https://turso.tech/) `libsql://…` database (+ auth token per LibSQL docs).

## Production (Railway)

1. New service from this directory; start command: `npm run start` (runs `mastra start` → built output).
2. Run `npm run build` in CI or use Mastra’s Docker/deploy docs; artifact is `.mastra/output`.
3. Set `PORT` / `HOST` as provided by Railway.
4. Point the Barrio `server` service `MASTRA_API_URL` at this service’s public URL (e.g. `https://portal-mastra.up.railway.app`).

## HTTP API (for Express proxy)

- `POST /api/workflows/ingest/start-async` — body `{ "inputData": { "inputType", "rawInput", "contextNote" } }` — waits until suspend or finish
- `GET /api/workflows/ingest/runs?status=suspended`
- `GET /api/workflows/ingest/runs/:runId`
- `POST /api/workflows/ingest/resume-async?runId=...` — body `{ "step": "human-review", "resumeData": { ... } }`

Send `Authorization: Bearer <MASTRA_SERVER_TOKEN>` when the token is configured.

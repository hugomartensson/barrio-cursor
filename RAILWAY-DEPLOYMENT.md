# Railway deployment — Barrio API + Portal Mastra (ingest)

Paste this document (or sections of it) into **Railway’s agent** or use it as a runbook. Paths and URLs match the **barrio-cursor** repo as implemented.

> **Git / GitHub:** The **`portal-mastra/`** app must exist **in the remote repository**. If it only lives on your machine as an **untracked** folder (`git status` shows `?? portal-mastra/`), clones and Railway deploys will **not** include it. Run `git add portal-mastra` (and commit + push). `node_modules/` and `.mastra/` under `portal-mastra` stay ignored; source, `package.json`, and `package-lock.json` are what you commit.

## Architecture

| Service | Root directory | Role |
|--------|----------------|------|
| **Barrio API** | `server` | Express: REST API, Prisma/Postgres, static `/admin`, Telegram webhook, **proxy** `/api/workflows/*` → Mastra |
| **Portal Mastra** | `portal-mastra` | Mastra server: ingest workflow, agents, tools; publishes to Portal API |
| **PostgreSQL** | (Railway plugin) | API database |

- **No Mastra Cloud account** — Mastra runs as your own Node service.
- **No “Mastra API key”** — you generate `MASTRA_SERVER_TOKEN` yourself (shared secret).

### Critical: one token, two places

`MASTRA_SERVER_TOKEN` must be **exactly the same string** on **both** the Barrio API service and the Portal Mastra service.

- **Generate it once** (e.g. `openssl rand -hex 32`), then **paste the same value** into each service’s Variables panel.
- **Do not** use Railway’s “generate” (or similar) **independently on each service** — that produces **two different** secrets and you will get **401/403** when the API proxies to Mastra or when the Telegram relay calls Mastra.
- **Verify:** open **Variables** on both services and confirm the `MASTRA_SERVER_TOKEN` values are **byte-for-byte identical** (no extra spaces/newlines).

---

## 1. Barrio API (`server/`)

### Railway settings

- **Root directory:** `server`
- **Build / start:** `server/railway.toml` is the source of truth:
  - **Build:** `npm run build && npx prisma generate`
  - **Start:** `npx prisma migrate deploy && node dist/index.js`
- Listen on **`process.env.PORT`** (Railway sets `PORT`).

### Environment variables (API service)

**Required (core API)**

| Variable | Notes |
|----------|--------|
| `NODE_ENV` | `production` |
| `DATABASE_URL` | From linked Postgres |
| `JWT_SECRET` | ≥ 32 characters |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Service role key |
| `SUPABASE_ANON_KEY` | Anon key |

**Required for Mastra ingest (proxy + Telegram relay)**

| Variable | Notes |
|----------|--------|
| `MASTRA_API_URL` | **Mastra service only** — public origin, **no `/api` suffix** (routes already use `/api/workflows/...`). Wrong service or `.../api` → **404 "Application not found"**. Example: `https://portal-mastra-xxxx.up.railway.app` |
| `MASTRA_SERVER_TOKEN` | Long random string; **identical** on Mastra service. If unset locally, Mastra accepts any caller (**do not** leave unset in production). |

**Telegram ingest bot (optional but needed for Telegram → ingest)**

| Variable | Notes |
|----------|--------|
| `TELEGRAM_BOT_TOKEN` | From BotFather |
| `TELEGRAM_ALLOWED_USER_ID` | Numeric Telegram user ID; bot ignores others |

**Optional**

| Variable | Notes |
|----------|--------|
| `DIRECT_URL` | Often same as `DATABASE_URL` for Prisma |
| `JWT_EXPIRES_IN` | Default `7d` |
| `SUPABASE_STORAGE_BUCKET` | Default `media` (main app uploads) |
| `CORS_ORIGIN` | `*` or comma-separated origins |
| `PORTAL_API_URL` | **Recommended in production:** your public API base **with** `/api`, e.g. `https://<api>.up.railway.app/api`. Used by `npm run bot:set-webhook` and `npm run batch` to know where the API lives (defaults to `http://localhost:3000/api` if unset). |

**Publishing** is performed **from the Mastra service** using `PORTAL_EMAIL` / `PORTAL_PASSWORD` / `PORTAL_API_URL` there — not required on the API for ingest publish.

### Routes (exact paths)

| Path | Behavior |
|------|----------|
| `GET /api/health` | Smoke test |
| `POST /api/telegram/webhook` | Telegram webhook (**only registered if** `TELEGRAM_BOT_TOKEN` is set). Mounted **before** generic `/api` routes. |
| `POST /api/auth/login` | Body `{ "email", "password" }` — returns JWT for admin UI |
| `/api/workflows/*` | **`requireAuth`** (user JWT). Proxied to `{MASTRA_API_URL}{originalUrl}` with **`Authorization: Bearer {MASTRA_SERVER_TOKEN}`** to Mastra. |
| `/admin/ingest/` | Ingest review UI (login via `/api/auth/login`). **No HTTP Basic Auth** in code — JWT in `localStorage`. |

### Telegram webhook URL

Set Telegram’s webhook to:

```text
https://<YOUR_API_RAILWAY_DOMAIN>/api/telegram/webhook
```

From your machine (with `TELEGRAM_BOT_TOKEN` and **`PORTAL_API_URL`** pointing at your **public** API URL in env), after API is live:

```bash
cd server && npm run bot:set-webhook
```

That script strips `/api` from `PORTAL_API_URL` and appends `/api/telegram/webhook` (see `server/src/tools/ingest/set-webhook.ts`). If `PORTAL_API_URL` is unset, it targets `http://localhost:3000/api` — wrong for Railway.

### How the bot reaches Mastra

Server-side (`server/src/tools/ingest/mastra-client.ts`):

- **POST** `{MASTRA_API_URL}/api/workflows/ingest/start-async`
- Headers: `Content-Type: application/json`, and if set, `Authorization: Bearer {MASTRA_SERVER_TOKEN}`
- Body: `{ "inputData": { "inputType", "rawInput", "contextNote" } }`
- `inputType`: `telegram_link` | `telegram_text` | `batch_yaml`

The **browser dashboard** never talks to Mastra directly; it calls **`/api/workflows/...`** on the API with the **user JWT**.

---

## 2. Portal Mastra (`portal-mastra/`)

### Railway settings

- **Root directory:** `portal-mastra`
- **Node:** Use **Node ≥ 22.13** (`engines` in `portal-mastra/package.json`).
- **Install:** `npm ci` (or `npm install`)
- **Build:** `npm run build` → runs `mastra build` (output under `.mastra/output`)
- **Start:** `npm run start` → runs `mastra start`
- **Host/port:** `portal-mastra/src/mastra/index.ts` uses `HOST` (default `0.0.0.0`) and `PORT` (default `4111`). Railway should set `PORT`.

### Environment variables (Mastra service)

| Variable | Required | Notes |
|----------|----------|--------|
| `GOOGLE_GENERATIVE_AI_API_KEY` | Yes | Gemini (agents + image validator) |
| `GOOGLE_PLACES_API_KEY` | Yes | Places (separate product/billing from AI Studio) |
| `PORTAL_EMAIL` | Yes | Portal user that owns published content |
| `PORTAL_PASSWORD` | Yes | |
| `PORTAL_API_URL` | Yes | **Must include `/api`**, e.g. `https://<api>.up.railway.app/api` |
| `SUPABASE_URL` | Yes | Same project as API |
| `SUPABASE_SERVICE_KEY` | Yes | Upload ingest images |
| `MASTRA_SERVER_TOKEN` | Yes (prod) | Same value as API; Mastra compares Bearer token to this string |

| Variable | Required | Notes |
|----------|----------|--------|
| `TAVILY_API_KEY` | No | Web search; optional |
| `SUPABASE_INGEST_BUCKET` | No | Default **`ingest-images`** (`portal-mastra/src/mastra/lib/ingest-image.ts`) |
| `MASTRA_STORAGE_URL` | No | Omit to use **`file:/tmp/mastra.db`** when Railway env vars are present (writable). `/tmp` resets on redeploy; set a **Turso** `libsql://…` URL for durable workflow state |

### Supabase

- Create a **public** storage bucket **`ingest-images`** (or set `SUPABASE_INGEST_BUCKET` to your bucket name).

### Mastra HTTP API (called by API proxy or bot)

Examples (Mastra base = your Mastra public URL):

| Method | Path | Notes |
|--------|------|--------|
| POST | `/api/workflows/ingest/start-async` | Start workflow until suspend/terminal |
| GET | `/api/workflows/ingest/runs?status=suspended&perPage=50` | Queue |
| GET | `/api/workflows/ingest/runs/:runId?fields=steps,status,payload` | Detail |
| POST | `/api/workflows/ingest/resume-async?runId=...` | Body includes `step: 'human-review'`, `resumeData` |

When `MASTRA_SERVER_TOKEN` is set, send **`Authorization: Bearer <same token>`** (raw secret, not a JWT).

---

## 3. Recommended deploy order

1. Deploy **Postgres** + **Barrio API** (`server`). Confirm `GET https://<api>/api/health`.
2. Ensure **`PORTAL_EMAIL`** exists in **Supabase Auth** and can log in via `POST /api/auth/login`.
3. Create Supabase bucket **`ingest-images`** (public).
4. Deploy **Portal Mastra** with `PORTAL_API_URL=https://<api>/api` and all keys.
5. Generate **`MASTRA_SERVER_TOKEN` once**; paste the **same** value on **both** API and Mastra (see **Critical: one token, two places** above); set **`MASTRA_API_URL`** on API to Mastra’s **https** origin (no trailing slash).
6. Restart/redeploy API if needed.
7. Run **`npm run bot:set-webhook`** (from `server/`) so Telegram points at `https://<api>/api/telegram/webhook`.
8. Smoke: send a link to the bot → open **`https://<api>/admin/ingest/`** → login → see suspended run → approve.

---

## 4. Ingest admin UI

- URL: **`/admin/ingest/`** (and redirects from older `/admin/` entry points if configured).
- Login: same credentials as the mobile/API user (`/api/auth/login`).
- API calls from the page go to **`/api/workflows/...`** (same origin); Express adds the Mastra bearer token when proxying.

---

## 5. Troubleshooting

| Symptom | Check |
|---------|--------|
| 502 on `/api/workflows/*` | `MASTRA_API_URL`, Mastra service up, no typo/trailing slash |
| 401 from Mastra | `MASTRA_SERVER_TOKEN` match on API proxy and Mastra |
| Publish fails from Mastra | `PORTAL_API_URL` ends with `/api`; user/password correct; Supabase user confirmed |
| Telegram 404 on webhook | `TELEGRAM_BOT_TOKEN` set so webhook route registers; path exactly `/api/telegram/webhook` |
| Mastra build fails | Node **22+** on Railway |
| Image upload fails | Bucket exists; `SUPABASE_INGEST_BUCKET` if not default; public read if app expects public URLs |

---

## 6. Related docs

- `server/DEPLOY-RAILWAY.md` — API-focused deploy notes
- `portal-mastra/README.md` — Mastra env + local dev
- `portal-mastra/.env.example` — Mastra variable checklist

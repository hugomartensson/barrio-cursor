# Deploy Barrio API to Railway

Use this to run the backend in production (e.g. for TestFlight). Railway will build the server, run migrations, and start the API. The iOS app points to the deployed URL via `AppConfig.productionAPIBaseURL`.

**Full stack (API + Mastra ingest + exact routes):** see **[`RAILWAY-DEPLOYMENT.md`](../RAILWAY-DEPLOYMENT.md)** at the repo root — suitable to paste into Railway’s agent.

## 1. Create a Railway project

- Go to [railway.app](https://railway.app) and sign in.
- **New Project** → **Deploy from GitHub repo** (or **Empty project** and connect later).
- If from repo: choose this repo and set **Root Directory** to `server` (so `server/package.json` is the app root).
- If empty: add a **GitHub** service and point it at this repo; set **Root Directory** to `server`.

## 2. Add PostgreSQL

- In the project, click **+ New** → **Database** → **PostgreSQL**.
- Railway creates a Postgres instance and sets `DATABASE_URL` (and often `PGHOST`, `PGPORT`, etc.). Use the variable **`DATABASE_URL`** for the API.
- Optionally set **`DIRECT_URL`** to the same value if you don’t use a pooler (or copy the direct connection string from the Postgres service).

## 3. Set environment variables

In the Railway service (your API), open **Variables** and add (or confirm):

| Variable | Required | Notes |
|----------|----------|--------|
| `NODE_ENV` | Yes | Set to `production` |
| `DATABASE_URL` | Yes | Set automatically if you added Postgres; otherwise paste your Postgres URL |
| `DIRECT_URL` | No | Same as `DATABASE_URL` unless you use PgBouncer |
| `JWT_SECRET` | Yes | Long random string (min 32 chars) |
| `JWT_EXPIRES_IN` | No | Default `7d` |
| `SUPABASE_URL` | Yes | Your Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Yes | Supabase service role key |
| `SUPABASE_ANON_KEY` | Yes | Supabase anon key |
| `SUPABASE_STORAGE_BUCKET` | No | Default `media` |
| `MASTRA_API_URL` | Yes (ingest) | Mastra service origin, e.g. `https://your-mastra.up.railway.app` |
| `MASTRA_SERVER_TOKEN` | Yes (ingest) | **Same value** as on the Mastra service (generate once, paste both — if they differ → 401/403) |
| `PORTAL_EMAIL` / `PORTAL_PASSWORD` | Yes (publish) | Portal user used by Mastra to POST spots/events (see `portal-mastra/.env.example`) |
| `CORS_ORIGIN` | No | `*` or your iOS app’s origin |

Use `server/.env.example` as a checklist. Do not commit `.env`; set everything in Railway’s UI.

## 4. Deploy

- Push to the branch Railway watches (or trigger a deploy from the dashboard).
- Railway runs `buildCommand` then `startCommand` from `server/railway.toml` (build, Prisma generate, migrate deploy, then start).
- After a successful deploy, open the **Settings** tab and use **Generate Domain** to get a public URL, e.g. `https://your-app-name.up.railway.app`.

## 5. Point the iOS app at the API

- Base URL for the API is the Railway domain **plus** `/api` (e.g. `https://your-app-name.up.railway.app/api`).
- In the iOS app set:
  - `AppConfig.productionAPIBaseURL = "https://your-app-name.up.railway.app/api"`
  - in `ios/BarrioCursor/BarrioCursor/BarrioCursor/Config/AppConfig.swift` (or via xcconfig).
- Build the app in **Release** (or archive for TestFlight); the app will use this URL when not in Debug.

## 6. Seed the database (optional)

After the first deploy you can seed data:

- **Option A (Railway CLI):**  
  `railway run npm run seed` (or `railway run npm run seed:fake`) from the repo root with the `server` directory as context, or from `server/` with Railway linked to the project.
- **Option B:** From your machine with a DB URL:  
  `DATABASE_URL="postgresql://..." npm run seed` (run from `server/`).

Then verify with `GET https://your-app-name.up.railway.app/api/health` and a quick test from the iOS app.

## 7. Portal team user (Supabase + API login)

`/api/auth/login` checks **Supabase Auth**, not only your Postgres `User` table. If that email was never registered, login returns `401 Invalid email or password`.

**Create the account via the API** (recommended — also runs `syncUserToDatabase` when signup returns a session):

```bash
API="https://your-app-name.up.railway.app/api"

curl -sS -X POST "$API/auth/signup" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "you@example.com",
    "password": "YourPassword1",
    "name": "Portal Team"
  }'
```

Password must satisfy the API rules: **≥8 characters**, at least **one uppercase**, **one lowercase**, and **one number**.

**If signup returns `token: ""` and a message about email confirmation:** Supabase has “Confirm email” enabled. Either confirm the email from the inbox, or in Supabase **Authentication → Providers → Email** turn off “Confirm email” for testing, then sign up again (or use **Authentication → Users → Add user** with email + password and mark email confirmed).

**After the user exists in Supabase**, `POST /api/auth/login` with the same email/password returns a JWT. The **Mastra ingest** UI is at **`/admin/ingest/`** (token in `localStorage`). `/admin/` redirects there.

**Build note:** `npm run build` runs `tsc` and **recursively** copies `src/admin/**/*.html` and `**/*.js` into `dist/admin` (including `admin/ingest/`).

## 8. Mastra ingest service (second Railway service)

- Add a second service with **root directory** `portal-mastra` (see `portal-mastra/README.md`).
- Set `MASTRA_SERVER_TOKEN` to **one** long random string: generate once, paste the **identical** value on **both** the Mastra service and the Barrio API (check the Variables panel on each — mismatched tokens cause **401/403**).
- On the Barrio API, set **`MASTRA_API_URL`** to the Mastra service public origin (no trailing slash), e.g. `https://portal-mastra.up.railway.app`.
- Telegram and the ingest UI call the API; the API proxies **`/api/workflows/*`** to Mastra with `Authorization: Bearer <MASTRA_SERVER_TOKEN>`.

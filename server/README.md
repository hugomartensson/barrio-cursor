# Barrio Backend API

Backend server for Barrio - a hyperlocal events discovery app.

## Status (April 2026)

Telegram bot ingestion and Mastra workflow integration are currently disabled. Code is preserved in `src/telegramWebhook.ts`, `src/middleware/mastraWorkflowProxy.ts`, `src/routes/ingest.ts`, and `src/tools/ingest/`. To revive, uncomment the wiring in `src/app.ts` and `src/routes/index.ts` and restore the relevant env vars from `.env.example`.

## Tech Stack

- **Runtime**: Node.js 20+
- **Framework**: Express.js with TypeScript
- **Database**: PostgreSQL 14+ with PostGIS
- **ORM**: Prisma
- **Storage**: Supabase Storage
- **Auth**: Supabase Auth

## Prerequisites

- Node.js 20+
- Docker & Docker Compose
- Supabase account (for storage)

## Getting Started

### 1. Verify Dependencies (Recommended First Step)

Before starting, check that all required dependencies are installed and services are running:

```bash
cd server
npm run check-deps
```

This will verify:
- ✅ Node.js 18+ is installed
- ✅ Docker is installed and running
- ✅ PostgreSQL container is running
- ✅ npm packages are installed
- ✅ Environment variables are configured
- ✅ Prisma client is generated

**If any checks fail, fix them before proceeding.**

### 2. Install npm packages

```bash
npm install
```

### 3. Set up environment variables

```bash
cp .env.example .env
# Edit .env with your configuration
```

### 4. Start the database

```bash
docker-compose up -d
```

Wait 10-15 seconds for PostgreSQL to start, then verify:

```bash
npm run check-deps
```

### 5. Run database migrations

```bash
npm run migrate
```

### 6. Start the development server

```bash
npm run dev
```

The API will be available at `http://localhost:5000`

## Available Scripts

| Command | Description |
|---------|-------------|
| `npm run check-deps` | **Verify all dependencies are installed and services are running** |
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Compile TypeScript to JavaScript |
| `npm run start` | Run production build |
| `npm run lint` | Run ESLint |
| `npm run lint:fix` | Fix ESLint errors |
| `npm run test` | Run tests with coverage |
| `npm run test:watch` | Run tests in watch mode |
| `npm run migrate` | Run Prisma migrations |
| `npm run db:studio` | Open Prisma Studio |

## API Endpoints

### Health
- `GET /api/health` - Health check

### Auth (Coming Soon)
- `POST /api/auth/signup` - Register new user
- `POST /api/auth/login` - Login
- `POST /api/auth/reset` - Password reset

### Events (Coming Soon)
- `POST /api/events` - Create event
- `GET /api/events/nearby` - Get nearby events
- `GET /api/events/:id` - Get event by ID
- `POST /api/events/:id/like` - Toggle like
- `POST /api/events/:id/going` - Toggle going

### Users (Coming Soon)
- `GET /api/users/me` - Get current user profile
- `PUT /api/users/me` - Update profile
- `GET /api/users/me/events` - Get user's events

## Project Structure

```
server/
├── src/
│   ├── config/         # Configuration and env validation
│   ├── jobs/           # Background jobs (cron tasks)
│   ├── middleware/     # Express middleware
│   ├── routes/         # API route handlers
│   ├── services/       # Business logic
│   ├── types/          # TypeScript types
│   ├── utils/          # Utility functions
│   ├── tests/          # Test files
│   ├── app.ts          # Express app setup
│   └── index.ts        # Server entry point
├── prisma/
│   └── schema.prisma   # Database schema
├── docker-compose.yml  # Local database setup
└── package.json
```

## Background Jobs

### Cleanup Expired Events

A daily cron job runs at 2:00 AM to hard-delete expired events:
- Deletes events where `endTime < NOW() - 24 hours`
- For events without `endTime`, uses `startTime < NOW() - 24 hours`
- Logs the number of deleted events

The job is automatically started when the server starts (skipped in test environment).

**Note:** For production deployment, ensure the server process stays running 24/7, or use a separate cron service/worker process.

## Code Quality

This project enforces strict code quality rules:

- **Cyclomatic complexity**: max 10
- **Max nesting depth**: 3
- **Max lines per file**: 300
- **Max lines per function**: 50
- **Max parameters**: 4
- **Max statements per function**: 20

Run `npm run lint` before committing.

## Testing

Tests use Jest with Supertest for integration testing against a real Postgres database.

```bash
npm run test
```

Target coverage: 80% statements/branches.

## License

Private - All rights reserved




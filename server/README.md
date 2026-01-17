# Barrio Backend API

Backend server for Barrio - a hyperlocal events discovery app.

## Tech Stack

- **Runtime**: Node.js 18+
- **Framework**: Express.js with TypeScript
- **Database**: PostgreSQL 14+ with PostGIS
- **ORM**: Prisma
- **Storage**: Supabase Storage
- **Auth**: JWT

## Prerequisites

- Node.js 18+
- Docker & Docker Compose
- Supabase account (for storage)

## Getting Started

### 1. Clone and install dependencies

```bash
cd server
npm install
```

### 2. Set up environment variables

```bash
cp .env.example .env
# Edit .env with your configuration
```

### 3. Start the database

```bash
docker-compose up -d
```

### 4. Run database migrations

```bash
npm run migrate
```

### 5. (Optional) Seed the database

```bash
npm run seed
```

### 6. Start the development server

```bash
npm run dev
```

The API will be available at `http://localhost:5000`

## Available Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Compile TypeScript to JavaScript |
| `npm run start` | Run production build |
| `npm run lint` | Run ESLint |
| `npm run lint:fix` | Fix ESLint errors |
| `npm run test` | Run tests with coverage |
| `npm run test:watch` | Run tests in watch mode |
| `npm run migrate` | Run Prisma migrations |
| `npm run seed` | Seed the database |
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




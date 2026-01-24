# Quick Start Guide

## 🚀 Starting All Services

### Option 1: Automated Script (Recommended)

```bash
cd server
./start-services.sh
```

This script will:
1. ✅ Check Docker is running
2. 🐳 Start PostgreSQL container
3. 🔍 Verify all dependencies
4. 📦 Setup Prisma
5. 🌐 Start the development server

### Option 2: Manual Steps

#### 1. Start Docker Desktop
- Open Docker Desktop application
- Wait until it shows "Docker Desktop is running"

#### 2. Start PostgreSQL Container
```bash
cd server
docker-compose up -d
```

Wait 10-15 seconds for PostgreSQL to start.

#### 3. Verify Dependencies
```bash
npm run check-deps
```

#### 4. Run Database Migrations (if needed)
```bash
npm run migrate
```

#### 5. Start the Server
```bash
npm run dev
```

## 🔍 Check Status

To check the status of all services:

```bash
cd server
./check-status.sh
```

Or use the dependency checker:

```bash
npm run check-deps
```

## 📋 Service Status

### Docker & PostgreSQL
- **Container**: `barrio-postgres`
- **Port**: `5432`
- **Database**: `barrio`
- **User**: `postgres`
- **Password**: `postgres`

### Server
- **Port**: `3000`
- **Health Check**: `http://localhost:3000/api/health`
- **Environment**: Development

### Supabase
- **Storage**: Used for media uploads
- **Connection**: Configured via `.env` file
- **Health**: Checked via `/api/health` endpoint

## 🐛 Troubleshooting

### Docker Not Running
```bash
# Start Docker Desktop manually, then:
docker ps  # Verify Docker is running
```

### PostgreSQL Container Not Starting
```bash
# Check logs
docker-compose logs postgres

# Restart container
docker-compose restart postgres
```

### Port 3000 Already in Use
```bash
# Find process using port 3000
lsof -ti:3000

# Kill the process (replace PID with actual process ID)
kill -9 <PID>
```

### Database Connection Issues
```bash
# Verify PostgreSQL is accepting connections
docker exec barrio-postgres pg_isready -U postgres

# Check database URL in .env file
grep DATABASE_URL .env
```

### Supabase Connection Issues
```bash
# Verify Supabase credentials in .env
grep SUPABASE .env

# Test connection via health endpoint
curl http://localhost:3000/api/health
```

## 📝 Environment Variables

Required variables in `.env`:
- `DATABASE_URL` - PostgreSQL connection string
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_KEY` - Supabase service role key
- `SUPABASE_ANON_KEY` - Supabase anonymous key
- `JWT_SECRET` - JWT signing secret (min 32 chars)

## ✅ Verification

Once everything is running, verify:

1. **Health Check**:
   ```bash
   curl http://localhost:3000/api/health
   ```

2. **Database Connection**:
   ```bash
   npm run db:studio
   ```

3. **Supabase Storage**:
   ```bash
   npm run check-deps
   # Should show Supabase connection status
   ```

## 🎯 Next Steps

After services are running:
- ✅ Server should be accessible at `http://localhost:3000`
- ✅ API endpoints available at `http://localhost:3000/api/*`
- ✅ Health check: `http://localhost:3000/api/health`
- ✅ Database admin UI: `http://localhost:8080` (Adminer)

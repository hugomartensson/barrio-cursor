# Database Migration Plan: Current Schema → PRD-TestFlight Schema

## Overview

This migration plan updates the database schema to match PRD-TestFlight.md requirements:
- Replace `Like`/`Going` with `Interested`
- Add social features: `Follow`, `FollowRequest`
- Add plans feature: `Plan`, `PlanEvent`
- Update `User` and `Event` models with PRD-required fields

## Current State

**Existing Models:**
- `User` (missing: `isPrivate`, `followerCount`, `followingCount`)
- `Event` (missing: `address`, `isFree`, `interestedCount`; has old `likesCount`, `goingCount`)
- `MediaItem` (missing: `thumbnailUrl` for videos)
- `Like` (to be replaced by `Interested`)
- `Going` (to be removed)

**Missing Models:**
- `Interested` (replaces `Like`)
- `Follow`
- `FollowRequest`
- `Plan`
- `PlanEvent`

## Migration Strategy

**Phase 1: Add new fields/tables (non-breaking)**
1. Add new fields to `User` and `Event`
2. Create new tables (`Interested`, `Follow`, `FollowRequest`, `Plan`, `PlanEvent`)
3. Add `thumbnailUrl` to `MediaItem`

**Phase 2: Migrate data**
1. Copy data from `Like` → `Interested`
2. Update `likesCount` → `interestedCount` on events

**Phase 3: Update code**
1. Update all code to use new schema
2. Remove references to old `Like`/`Going` tables

**Phase 4: Cleanup**
1. Drop old `Like` and `Going` tables

## Step-by-Step Instructions

### Step 1: Update Prisma Schema

The updated `schema.prisma` file is ready. Review it, then:

```bash
cd /Users/hugo/Desktop/barrio-cursor/server
npx prisma migrate dev --name migrate_to_prd_testflight
```

This will:
- Create migration SQL
- Apply it to your Supabase database
- Regenerate Prisma Client

### Step 2: Verify Migration

```bash
# Check migration was created
ls -la prisma/migrations/

# Verify Prisma Client regenerated
npx prisma generate
```

### Step 3: Data Migration (if you have existing data)

If you have existing `Like` records, run this SQL in Supabase SQL Editor:

```sql
-- Copy Like records to Interested
INSERT INTO interested (user_id, event_id, created_at)
SELECT user_id, event_id, created_at FROM likes;

-- Update interestedCount on events
UPDATE events e
SET interested_count = (
  SELECT COUNT(*) FROM interested i WHERE i.event_id = e.id
);
```

### Step 4: Verify Schema Matches PRD

Run this query in Supabase to verify all tables exist:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

Expected tables:
- `users`
- `events`
- `media_items`
- `interested` (not `likes`)
- `follow`
- `follow_request`
- `plan`
- `plan_event`

## Rollback Plan

If something goes wrong:

```bash
# Rollback last migration
npx prisma migrate resolve --rolled-back <migration_name>

# Or reset database (WARNING: deletes all data)
npx prisma migrate reset
```

## Next Steps After Migration

1. Update backend code to use new schema
2. Update iOS models to match new schema
3. Run Tier 2 QC: `./quality-control/verify-after-work.sh 2`
4. Test critical flows (create event, mark interested, follow user)

# Next Steps - Implementation Plan

## Immediate Priority (Do First)

### 1. Fix GIST Index for PostGIS Performance ⚡
**Time:** 15 minutes  
**Priority:** Critical  
**Action:**
- Create Prisma migration to:
  - Drop existing B-tree index on `(latitude, longitude)`
  - Add GIST spatial index on location geometry column
- SQL:
  ```sql
  DROP INDEX IF EXISTS events_latitude_longitude_idx;
  CREATE INDEX events_location_idx ON events USING GIST (location);
  ```
- Test query performance with EXPLAIN ANALYZE
- Update Prisma schema if needed

**Why:** Current B-tree index is suboptimal for PostGIS geospatial queries. GIST index will improve nearby events query performance.

---

### 2. Add Event Expiration Filtering 🔍
**Time:** 30 minutes  
**Priority:** Critical  
**Action:**
- Update `fetchNearbyEvents` in `server/src/routes/events.ts`
- Add WHERE clause: `WHERE (endTime IS NULL AND startTime > NOW()) OR (endTime > NOW())`
- Update `GET /events/:id` to also check expiration
- Add tests for:
  - Events with past endTime (should not appear)
  - Events with future endTime (should appear)
  - Events with null endTime (use startTime)

**Why:** PRD Section 5.1 requires events to be filtered by expiration. Currently all events are returned regardless of time.

---

### 3. Implement DELETE /events/:id Endpoint 🗑️
**Time:** 45 minutes  
**Priority:** High  
**Action:**
- Add route in `server/src/routes/events.ts`
- Verify ownership: `event.userId === authReq.user.userId`
- Hard delete event (cascades to media, likes, going via Prisma)
- Return 403 if not owner, 404 if not found
- Add tests for:
  - Successful deletion by owner
  - 403 when not owner
  - 404 when event doesn't exist
  - Cascade deletion of related records

**Why:** PRD Section 7.5 requires users to delete their own events. Currently not implemented.

---

## High Priority (Do Next)

### 4. Add Daily Cron Job for Expired Events 🕐
**Time:** 1 hour  
**Priority:** High  
**Action:**
- Create `server/src/jobs/cleanupExpiredEvents.ts`
- Hard delete events where `endTime < NOW() - 24 hours`
- Set up cron schedule (daily at 2 AM)
- Options:
  - Use `node-cron` package
  - Or Supabase Edge Function (if using Supabase hosting)
- Add logging for deleted count
- Document in deployment README

**Why:** Keeps database clean by removing old events. PRD Section 8 requires this background job.

---

### 5. Add Video Duration Validation 🎥
**Time:** 1 hour  
**Priority:** High  
**Action:**
- Backend: Add duration check in `server/src/services/media.ts`
  - Extract duration from video metadata
  - Reject if > 15 seconds
  - Return 422 error: "Videos must be 15 seconds or less"
- iOS: Add AVAsset duration validation before upload
  - Check duration in `CreateEventView.swift`
  - Show error: "Videos must be 15 seconds or less"
- Add tests for:
  - Video > 15 seconds (rejected)
  - Video ≤ 15 seconds (accepted)

**Why:** PRD Section 7.4 requires 15-second video limit. Currently only size is validated.

---

### 6. Update Seed Data for Testing 🌱
**Time:** 30 minutes  
**Priority:** Medium  
**Action:**
- Update `prisma/seed.ts` to include:
  - Events with past endTime (for testing expiration filter)
  - Events with future endTime
  - Events with null endTime
  - Events at exactly 5km boundary
- Ensure all test scenarios are covered

**Why:** Guidelines require varied endTime values for proper testing of expiration logic.

---

## Medium Priority (Before TestFlight)

### 7. Implement PATCH /users/me Endpoint ✏️
**Time:** 45 minutes  
**Priority:** Medium  
**Action:**
- Add route in `server/src/routes/users.ts`
- Validate: name is required, string, max length
- Update user name in database
- Return updated user object
- Add tests for:
  - Successful name update
  - Validation errors (empty, too long)
  - Auth required

**Why:** PRD Section 7.5 allows name editing. Currently in backlog but should be implemented before TestFlight.

---

### 8. Add Location Permission Fallback (iOS) 📍
**Time:** 2 hours  
**Priority:** Medium  
**Action:**
- Update `LocationManager.swift` to handle permission denial
- Add manual address entry UI
- Use MapKit geocoding to convert address to coordinates
- Update `CreateEventView.swift` to show address field when location denied
- Test scenarios:
  - Location allowed (normal flow)
  - Location denied (manual entry)
  - Invalid address (error handling)

**Why:** PRD Section 3 and 9.1 require graceful fallback when location permission is denied.

---

### 9. Migrate to Structured Logging 📝
**Time:** 2 hours  
**Priority:** Low (Before TestFlight)  
**Action:**
- Install `pino` or `winston`
- Replace all `console.log` with structured logger
- Add request ID middleware
- Configure log levels per environment
- Update error handler to use logger

**Why:** Guidelines require structured logging before TestFlight. Currently using console.log.

---

## Low Priority (When Deploying)

### 10. Split Environment Files 🔐
**Time:** 30 minutes  
**Priority:** Low  
**Action:**
- Create `.env.development`, `.env.test`, `.env.production`
- Update `config/index.ts` to load based on NODE_ENV
- Keep `.env` for local dev (gitignored)
- Document in README

**Why:** Guidelines recommend splitting env files before deployment. Not needed for local development.

---

### 11. Migrate to /api/v1/ Versioning 🔄
**Time:** 1 hour  
**Priority:** Low (At TestFlight)  
**Action:**
- Update all routes from `/api/` to `/api/v1/`
- Update iOS app `AppConfig.swift` API base URL
- Update all tests
- Update documentation

**Why:** Guidelines say to version at TestFlight release. Not needed for MVP development.

---

## Testing Checklist

After implementing each feature, verify:
- [ ] All tests pass: `npm run test`
- [ ] Linting passes: `npm run lint`
- [ ] Build succeeds: `npm run build`
- [ ] Manual testing in iOS app
- [ ] Edge cases covered
- [ ] Error handling works
- [ ] Performance is acceptable

---

## Notes

- **Hard deletes everywhere:** No soft deletes in MVP (resolved conflict)
- **API versioning:** Keep `/api/` for now, migrate to `/api/v1/` at TestFlight
- **Solo workflow:** Working directly on main, no feature branches needed
- **GIST index:** Critical for performance, fix immediately
- **Event expiration:** Must be implemented before any real usage

---

## Estimated Total Time

- Immediate Priority: ~1.5 hours
- High Priority: ~3 hours
- Medium Priority: ~4.5 hours
- Low Priority: ~2.5 hours

**Total:** ~11.5 hours of focused development

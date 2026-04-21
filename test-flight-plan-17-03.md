# TestFlight Plan — 17 March 2026

Items to iron out before or alongside the first TestFlight build.  
**Status:** Living doc; update as blockers clear.

---

## Blocked (waiting on Apple)


| #   | Item                           | Notes                                                                                                         |
| --- | ------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| 1   | **Apple Developer Program**    | Enrollment in progress; waiting for acceptance.                                                               |
| 6   | **App Store Connect record**   | Create app record (bundle ID `com.hugo.BarrioCursor`), name, language, category. Do once program is accepted. |
| 7   | **Bundle ID / final identity** | Reserve or confirm final bundle ID (e.g. `com.yourcompany.portal`) when creating the App Store Connect app.   |


---

## Backend & environment


| #   | Item                          | Notes                                                                                                                                                                                                                             |
| --- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 3   | **Deploy backend to Railway** | Follow `**server/DEPLOY-RAILWAY.md`**. Use `server/.env.example` as a variable checklist. Root directory = `server`. After deploy, set iOS `AppConfig.productionAPIBaseURL` to `https://<your-railway-domain>/api`.               |
| 8   | **Add test users and data**   | Create test users via Supabase Auth and populate mock content manually or via a dedicated seed script (TBD). |


---

## Deferred / on hold


| #   | Item               | Notes                                                                                                                             |
| --- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| 13  | **Privacy policy** | On hold. Required before public release; optional for TestFlight. Host a simple page and add URL in App Store Connect when ready. |


---

## Done in codebase (17 Mar 2026)

- **App icon** — Catalog is at `ios/BarrioCursor/BarrioCursor/BarrioCursor/Assets.xcassets/AppIcon.appiconset/` and expects a single file named `AppIcon.png` (1024×1024). Use your uploaded icon there (replace the existing file if present).
- **Permission strings** — Cleaned in Xcode project (single clear sentence per key).
- **Debug logging** — All `print` calls wrapped in `#if DEBUG` (BarrioCursorApp, ErrorView, ProfileView, UserProfileView, CreateEventView, EventDetailView, StorageService, NetworkDiscoveryService, APIService, FeedView, MapView).
- **Launch screen** — Branded teal background via `UILaunchScreen` + `LaunchScreenBackground` in Assets.
- **Empty state** — Discover feed `EmptyStateView` updated to icon + “Nothing here yet” + short subtitle (on-design).
- **Error states** — Existing ErrorView/errorOverlay on feed, map, profile retained.
- **Production API URL** — `AppConfig.productionAPIBaseURL` (optional). Set to your Railway URL (e.g. `"https://your-app.railway.app/api"`) for TestFlight/Release; in Release, `AppConfig.getAPIBaseURL()` uses it when set. APIService uses `AppConfig.getAPIBaseURL()`.

---

## Next steps (in order)

1. **Deploy API to Railway** — Follow `server/DEPLOY-RAILWAY.md`. Add Postgres, set variables from `server/.env.example`, deploy. Generate a public domain and note the URL.
2. **Wire iOS to production** — In `AppConfig.swift` set `productionAPIBaseURL = "https://<your-railway-domain>/api"` (no trailing slash). Archive in Release to verify the app hits the live API.
3. **Add test users and data** — Create test users via Supabase Auth and populate mock content (TBD).
4. **When Apple approves** — Create the app in App Store Connect (bundle ID `com.hugo.BarrioCursor`), then Archive → Distribute App → TestFlight. Add internal/external testers.

---

## Pre-upload checklist (run before first Archive)

- Apple Developer Program accepted.
- App icon present and correct in asset catalog.
- Backend deployed to Railway and healthy (HTTPS).
- iOS app uses production API URL in Release (or TestFlight) build.
- Database seeded with enough data for testers.
- App Store Connect app created; bundle ID matches Xcode.
- Version and build number set (e.g. 1.0 / 1).


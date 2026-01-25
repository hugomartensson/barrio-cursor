# TestFlight Fix Plan — Implementation & Verification

This plan maps each bug/UX issue to concrete code changes, verification steps, and open questions. Follow the **Mandatory Verification Protocol** when claiming any fix complete.

---

## CRITICAL BUGS (BLOCK TESTFLIGHT — FIX FIRST)

### 1. PLANS VIEW — COMPLETE FAILURE

**Error:** `Failed to parse response: The data couldn't be read because it is missing`  
**Domain:** `BarrioCursor.APIError`, **Code:** 1  
**Observed in:** **PlanDetailView** (single plan screen), not PlansListView.

**Root cause (identified):**  
- `GET /plans/:id` returns events **without** `createdAt` or `distance`.  
- iOS `Event` model requires `createdAt: Date`; `distance` is optional.  
- Decoding fails → `APIError.decodingError` → "data is missing" user message.

**Required fixes:**

| Step | Owner | Action |
|------|--------|--------|
| 1.1 | Server | **`server/src/routes/plans.ts`** — In `GET /:id` handler, include `createdAt` and `distance` in each event in the `events` array. Use `event.createdAt.toISOString()`; `distance` can be `null` or omit (iOS has optional). |
| 1.2 | iOS | **`APIService`** — Add logging in `performRequest` when decoding fails: log raw response string (truncated), `DecodingError.keyNotFound` key path, and `DecodingError` description. |
| 1.3 | iOS | **`PlanDetailView`** — Ensure `ErrorView` shows user-friendly message only. The "Error Details" debug box (Code, Domain, Description) should be **removed** or hidden in production; keep wording like "Failed to load data. Please try again." |
| 1.4 | QA | Test **empty plans** (user has no plans) and **populated plans** (plan with 0 events, plan with 1+ events). Confirm no decode errors. |

**Files to modify:**
- `server/src/routes/plans.ts` (events mapping in `GET /:id`)
- `ios/.../Services/APIService.swift` (decoding error logging)
- `ios/.../Views/Plans/PlanDetailView.swift` (error UI)

---

### 2. EVENT CREATION — MEDIA UPLOAD BUTTONS NON-FUNCTIONAL

**Issue:** Photo, Video, and "Select from Library" buttons are unresponsive.

**Current implementation:**
- **Photo / Video:** `CreateEventView` sets `activeCapture = .photo | .video`; `.sheet(item: $activeCapture)` presents `ImagePicker` or `VideoRecorder`. Buttons already have `print` logging.
- **Select from Library:** `PhotosPicker` (SwiftUI) with `selection: $selectedPhotos`, `matching: .any(of: [.images, .videos])`.

**Required fixes:**

| Step | Owner | Action |
|------|--------|--------|
| 2.1 | iOS | Verify tap targets: ensure no overlay (e.g. `contentShape`, `onTapGesture` on Form) is capturing taps before the buttons. Check `CreateEventView` Form / `mediaSection` structure. |
| 2.2 | iOS | **Photo/Video:** On `.authorized`, set `activeCapture` and ensure sheet presents. If using `requestAccess` async callback, confirm `activeCapture` is set on `@MainActor` and that the sheet modifier is bound correctly. Add `print` in sheet `onAppear` to confirm presentation. |
| 2.3 | iOS | **Select from Library:** Confirm `PhotosPicker` is not `disabled` when it shouldn’t be. Check `photoData.count + videoData.count >= 3` disable logic. Add `print` in `onChange(of: selectedPhotos)` to verify picks register. |
| 2.4 | iOS | Verify **photo library permission** (NSPhotoLibraryUsageDescription) and that we request access before presenting PhotosPicker if required. |
| 2.5 | QA | Test on **physical device**: Photo button → camera; Video → video; Select from Library → photo picker. Confirm console logs for each tap. |

**Files to modify:**
- `ios/.../Views/Event/CreateEventView.swift` (media section, sheet, logging)

---

### 3. LOGIN — KEYBOARD DOESN’T DISMISS

**Issue:** Keyboard stays open when tapping outside the text field.

**Required fixes:**

| Step | Owner | Action |
|------|--------|--------|
| 3.1 | iOS | Add tap-to-dismiss: either `@FocusState` for the fields plus a tap gesture on the root view that sets `focusedField = nil`, or a `simultaneousGesture(TapGesture())` on the parent that calls `UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), ...)`. |
| 3.2 | iOS | Apply to **LoginView** (and **SignupView** for consistency). Ensure the gesture doesn’t block "Log In", "Sign Up", "Don't have an account?" etc. |
| 3.3 | QA | Tap Email, then tap background; tap Password, then tap background. Keyboard must dismiss. |

**Files to modify:**
- `ios/.../Views/Auth/LoginView.swift`
- `ios/.../Views/Auth/SignupView.swift` (same behavior)
- Consider shared modifier or `AuthView` container if both use same layout.

---

## HIGH PRIORITY UX ISSUES

### 4. MAP VIEW — FILTER SYSTEM

| Issue | Fix | Files |
|-------|-----|--------|
| **4.A** No visual indication of active filters in dropdown | Add checkmark (e.g. `Image(systemName: "checkmark")`) next to selected categories in the category Menu. | `MapView.swift` (category Menu) |
| **4.B** No "All" option for categories | Add "All" at top of category filter Menu; selecting it clears `selectedCategories`. | `MapView.swift` |
| **4.C** No way to clear all filters at once | Add "Clear all" / X control (e.g. next to filter chips or in overlay) that resets time, categories, and location filters. | `MapView.swift` (filter overlay) |
| **4.D** Two location buttons | Keep **one** location-related control. Today: `MapUserLocationButton` in `mapControls` + custom "recenter" (location.fill) in overlay. Remove one; document which remains (e.g. keep overlay recenter, remove `MapUserLocationButton`, or vice versa). | `MapView.swift` |

---

### 5. EVENT FEED — SEARCH

| Issue | Fix | Files |
|-------|-----|--------|
| **5.A** Search only event names | Extend search to **event name**, **description**, **location** (address), **organizer name**. Current implementation already uses title, organizer, address; add **description**. | `FeedView.swift` (`filteredEvents` / search logic) |
| **5.B** Keyboard doesn’t dismiss | Same approach as Login: tap outside search field dismisses keyboard (e.g. `@FocusState` + tap gesture or `resignFirstResponder`). | `FeedView.swift` |

---

### 6. EVENT FEED — ZOOM BEHAVIOR (Feed Overview)

| Issue | Fix | Files |
|-------|-----|--------|
| **6.A** Zoomed-out view is carousel, not grid | Replace horizontal `ScrollView` + `LazyHStack` with a **grid**: e.g. `LazyVGrid` with columns. First zoom: **3 columns**; max zoom: **up to 12 columns** (small thumbnails). Multiple rows as needed. | `FeedView.swift` (`FeedOverviewView`, `overviewSection`) |
| **6.B** Two X buttons to exit zoom | **Remove both** X buttons (FeedView toolbar X when `showFeedOverview` + FeedOverviewView navbar X). Exit only by **zooming back in** (pinch). | `FeedView.swift`, `FeedOverviewView` |
| **6.C** Redundant filter display | When category dropdown has checkmarks (and filter state is clear from it), **remove** the separate `FilterSummaryView` grey "Active Filters" / "Clear all" box **in the Feed Overview context** (or remove it entirely if we consolidate filter UI per 4.C). Clarify: remove only in overview, or everywhere? | `FeedView.swift` |
| **6.D** Interested count not on overview cards | Add interested count (e.g. `\(event.interestedCount)`) next to star icon on **OverviewEventCard**. | `FeedView.swift` (`OverviewEventCard`) |
| **6.E** Unnecessary "Add to Plan" on card | Remove the small "Add to Plan" icon from **EventCard** bottom-right. Plan is added via swipe-left only. | `FeedView.swift` (`EventCard`) |

**Note:** 6.C may interact with 4.C (map) and general filter UX — clarify whether "redundant" box is Feed-only or map+feed.

---

### 7. STORY VIEW — DUPLICATE ORGANIZER NAME

**Issue:** Organizer name appears twice (e.g. "by Carlos Ward" and again below buttons).

**Required fixes:**

| Step | Owner | Action |
|------|--------|--------|
| 7.1 | iOS | In **StoryViewer**, show organizer **once** only. Today: "by \(event.user.name)" button above Interested / Add to Plan. Remove any duplicate label (e.g. second "by …" or plain name) below the action buttons. | `StoryViewer.swift` |

---

## MEDIUM PRIORITY — PROFILE VIEWS (CAROUSELS)

### 8. PROFILE VIEWS — CAROUSEL STRUCTURE

**Other users’ profiles:**

- **Carousels (order):** 1) **Interested** 2) **Organizing** 3) **Organized**
- **Hide** carousels with no events.
- **Layout:** 3 miniatures per row; each shows **event image + venue name** only.

**Own profile (nav bar):**

- **Do not** show these carousels; use a different layout (e.g. list).

**Required fixes:**

| Step | Owner | Action |
|------|--------|--------|
| 8.1 | iOS | **UserProfileView** (other user): Replace or extend current "Events" section with three carousels: Interested, Organizing, Organized. Fetch interested vs created (organizing/organized) from API. |
| 8.2 | iOS | **ProfileView** (own): Remove or bypass carousel UI; use list or other non-carousel layout. |
| 8.3 | Backend | If missing: provide endpoints or fields for "events user is interested in" vs "organizing" vs "past organized". |

**Files to modify:**
- `UserProfileView.swift`, `ProfileView.swift`
- API layer / `APIService` if new endpoints or response shapes.

---

## IMPLEMENTATION ORDER (RECOMMENDED)

1. **#1 Plans** — Fix decode failure (server + optional iOS logging/error UI).
2. **#2 Media buttons** — Fix CreateEventView photo/video/library.
3. **#3 Keyboard** — Login (and Signup) tap-to-dismiss.
4. **#4 Map filters** — 4.A–4.D.
5. **#5 Search** — 5.A, 5.B.
6. **#6 Feed zoom** — 6.A–6.E.
7. **#7 Story** — Remove duplicate organizer.
8. **#8 Profile** — Carousels for others, no carousels for own.

---

## VERIFICATION PROTOCOL (SUMMARY)

For **every** fix:

1. **Code:** Implement in the files above; ensure project compiles.
2. **Evidence:** Note file(s), line ranges, and what was changed.
3. **Testing:** Follow issue-specific checks (e.g. empty vs populated plans, tap logging for buttons, keyboard dismiss).
4. **Build:** Clean build, fix warnings, run relevant flows in simulator/device.
5. **Response format:** Use the **FIX COMPLETE** template from the Mandatory Verification Protocol when marking an item done.

---

## OPEN QUESTIONS

1. **Plans (#1):** Confirm that **PlanDetailView** (single plan) is the only screen showing this error, or if **PlansListView** also fails in some cases (e.g. empty state).

2. **Map 4.D:** Which single "location" control should remain: **MapUserLocationButton** (system) or the **custom recenter** (location.fill) in the top bar?

3. **Feed 6.C:** Should we remove the **FilterSummaryView** grey box only when in **Feed Overview** (zoomed-out), or **everywhere** in Feed (including normal list)? The spec says "if adding checkmarks to category dropdown, remove the separate grey box" — should that apply to both Map and Feed?

4. **Feed 6.A — Zoom levels:** Are there exactly **two** zoom levels (3 cols vs 12 cols), or a **gradient** (e.g. 3 → 6 → 9 → 12) as the user pinches? How is "first" vs "maximum" zoom defined (gesture threshold)?

5. **Profile 8 — "Organizing" vs "Organized":**  
   - **Organizing** = events they host that haven’t started yet (or are ongoing)?  
   - **Organized** = past events they hosted?  
   Confirm exact definitions and that API can distinguish them.

6. **Profile 8 — "Venue name":** Use `event.address` as "venue name", or is there a separate venue/location field we should use?

7. **Media buttons (#2):** Are you testing on **simulator** or **device**? Camera is unavailable in simulator; Photo Library works. Confirm which environment shows "non-functional" buttons.

---

## PRE-BUILD CHECKLIST (ABRIDGED)

Before tagging a TestFlight build, confirm:

- [ ] Plans list and plan detail load (empty + populated).
- [ ] Photo, Video, Select from Library all work on device.
- [ ] Keyboard dismisses on background tap (Login, Signup, Feed search).
- [ ] Map: category checkmarks, "All", single location button, clear-all filters.
- [ ] Feed search: name, description, location, organizer; keyboard dismisses.
- [ ] Feed overview: grid (3 → 12 cols), no X buttons, interested count on cards, no add-to-plan icon on card.
- [ ] Story: organizer name once only.
- [ ] Other-user profile: Interested / Organizing / Organized carousels; own profile: no carousels.

---

*Generated from TESTFLIGHT-FIX-PLAN. Update this doc as fixes are implemented and questions are resolved.*

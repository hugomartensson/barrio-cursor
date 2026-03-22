# PRD UI & Design Implementation Review

**Document:** MASTER-PRD-2402 (portal. — Product Requirements Document v1)  
**Review focus:** UI and design system alignment across the iOS app  
**Date:** February 2026 (design audit update: March 2026)

---

## Executive summary

The app has **strong alignment** with the PRD in many areas: three-tab structure, filter pills (time + category), feed sections, map with pins and preview card, profile with saves/collections/events/spots, and the core editorial color palette. A **March 2026 design audit** resolved typography direction (DM Sans–only bundle: Black for display titles, Italic for editorial accents), image gradient legibility, discover section chrome (wide-tracked headers, hidden empty EVENTS), location search keyboard scrolling, unified **PortalSaveButton** affordance, teal primary for Follow, map pin semantics (all teal; events use `ticket.fill`), and several polish items. **Gaps** that remain include some PRD feed sections (“From Friends”, featured collection hero), Discover tab compass icon, sticky blurred header, event detail “top fold” grouping, and motion/stagger specs.

---

## 1. Design system

### 1.1 Typography — **Aligned (March 2026 direction)**

| Spec | Implementation | Status |
|------|----------------|--------|
| Display / titles — strong sans | **DM Sans Black** (`DMSans-Black.ttf`) for `portalWordmark`, `portalDisplay*`, and dynamic `portalDisplayBlack(size:)` | ✅ |
| Editorial italic accent (no system serif) | **DM Sans Italic** (`DMSans-Italic.ttf`) for `portalSerifItalic` / `portalSerifItalicSmall` / `portalItalic(size:)` | ✅ |
| UI body, metadata, labels, pills | **System San Francisco** — `portalBody`, `portalMetadata`, `portalLabel*`, section titles | ✅ |
| Section labels | `portalSectionLabel` — 11pt semibold; apply **~1.2pt tracking** in views where used | ✅ |
| Discover section headers (EVENTS, SPOTS, …) | `portalSectionTitle` — **14pt bold** with **~1.8pt tracking** in `FeedView` | ✅ |

**Note:** MASTER-PRD may still mention Instrument Serif; the **product decision** for this codebase is **DM Sans only** for bundled display fonts (Instrument Serif / Archivo removed from the bundle).

---

### 1.2 Color — **Updated (Feb 2026)**

| PRD / Request | Implementation | Status |
|---------------|-----------------|--------|
| Background: grayish off-white (not creamy) | `portalBackground` #F2F2F0 | ✅ |
| Foreground: near-black | `portalForeground` #1F1810 | ✅ |
| Primary accent: teal green (reference swatch) | `portalPrimary` #2F7168, `portalGradientPrimary` teal | ✅ |
| Live accent: warm rose | `portalLive` #F25C8C | ✅ |
| Muted/border: neutral greys | `portalMuted` #E0E0DE, `portalMutedForeground` #6B6B68 | ✅ |
| Cards: pure white | `portalCard` #FFFFFF | ✅ |
| Image card bottom scrim | `portalGradientOverlay`: **clear → black 0.9** (readable white type on light photos) | ✅ |

**Trust-layer coding:**  
PRD: Orange = editorial/authority; personal colors (blue, teal, amber) = friends; dashed ring + muted = pending.  
**Implementation:** Orange used for primary/editorial; `signatureColors` and `portalAccent` used for variety; no explicit “dashed ring + muted” for pending follow state in the reviewed UI.

---

### 1.3 Surfaces and depth — **Mostly aligned**

| PRD | Implementation | Status |
|-----|-----------------|--------|
| Cards: pure white, soft two-layer shadow | `portalCard` + double shadow (opacity 0.05/0.07, radius 1 & 6) | ✅ |
| Border radius consistent (1rem) | `portalRadius` = **16pt** | ✅ |
| Small UI radius | `portalRadiusSm` = **8pt** | ✅ |
| Gradient overlay on image bottom third | `portalGradientOverlay` (strong dark scrim); EventCard still uses date sidebar layout | ⚠️ Layout varies by component |
| Frosted glass on floating badges | Detail hero nav uses `.ultraThinMaterial`; save uses **PortalSaveButton** (teal circle / outline) | ⚠️ Partial |

---

### 1.4 Layout — **Aligned**

- Single column, mobile-first: Discover feed is one scroll. ✅  
- Horizontal carousels for collections, “People to follow,” spots. ✅  
- Section labels: 11pt semibold, wide tracking (~1.2), muted (`portalSectionLabel`). ✅  
- Feed section titles: 14pt bold, wide tracking (~1.8). ✅  
- Location dropdown: **ScrollView** + search field focus + scroll-dismiss keyboard for keyboard overlap. ✅  
- Sticky header: PRD says “Sticky header with backdrop blur”. **Implementation:** Header is in the scroll content; no explicit sticky + blur in the Discover view. ⚠️

---

### 1.5 Motion — **Partially aligned**

| PRD | Implementation | Status |
|-----|-----------------|--------|
| Fade-in (0.4s, ease-out, Y+8px) | Not clearly defined in code | ❌ |
| Slide-up (0.5s, Y+20px) for sections | Not clearly defined | ❌ |
| Pulse-glow for live events (2s interval) | `LiveEventHalo` pulse; `EventPin` scale animation for live | ✅ |
| Staggered delays on grids (80ms/item) | Not present in feed/carousels | ❌ |

---

## 2. Product surfaces

### 2.1 Bottom navigation — **Mostly aligned**

- Three tabs only: Discover, Map, Profile. ✅  
- PRD: “Compass icon” for Discover, “Map icon” for Map, “User icon” for Profile.  
- **Implementation:** Discover = `safari`, Map = `map`, Profile = `person`.  
- **Gap:** Discover should use a compass icon (e.g. `location.compass` or custom) per PRD. ⚠️

Active state (primary color, scale, dot) is implemented. ✅

---

### 2.2 Discover (Tab 1)

**Header**

| PRD | Implementation | Status |
|-----|-----------------|--------|
| City name prominent, tappable, city switcher | Location pill with “New York City” / “Custom location”, opens `LocationFilterSheetView` | ✅ (copy: “New York City” hardcoded; reverse geocode TODO) |
| Wordmark visible | `PortalWordmark` in header | ✅ |

**Filter rows**

| PRD | Implementation | Status |
|-----|-----------------|--------|
| Row 1 — Time: Tonight, Tomorrow, This Weekend, Sat, Sun, Pick a date; single-select; tap again to deselect | `DiscoverTimeIntent` pills; single-select; tap to deselect | ✅ |
| Row 2 — Category: Food, Drinks, Music, Art, Markets, Community; multi-select | `DiscoverCategory` pills; multi-select | ✅ |
| No “Apply” — content updates in real time | Filters drive `filteredEvents` and feed sections | ✅ |
| Filters sticky at top | Header is in scroll content, not sticky | ⚠️ |

**Feed sections (browse mode)**

| PRD section | Implementation | Status |
|-------------|-----------------|--------|
| **Events and spots** — interleaved main stream | Events as main list; spots in horizontal “Near you” / “Options nearby” | ✅ (structure present; “interleaved” is more mixed in PRD) |
| **From Friends** — “From people you trust”, horizontal cards with friend attribution | **Not present** — no “From Friends” block or “From people you trust” copy | ❌ |
| **Featured collection** — one hero-sized public collection | **Not present** — no single featured hero collection | ❌ |
| **People to follow** — horizontal avatars + context (e.g. “42 saves in Barcelona”) | “People to follow” + `SuggestedUserCard` (avatar, name, follower count); no “saves in [city]” copy | ⚠️ Partial |
| **Public collections** — horizontal collection cards | “Public collections” + `PortalCollectionCard` | ✅ |

**Feed behavior (planning mode)**  
When a time filter is active, events are filtered and “For your time” / “Happening Now” and “Options nearby” are shown; people/collections follow. Aligned with PRD intent. ✅

**Search**  
Search bar in main tab; PRD says “search bar accessible from discover feed” and query across users, spots, events, collections. UI exists; backend behavior not verified here. ✅

**Cards in feed**  
- PRD: Hero image, name, category, neighborhood, trust (avatar + handle), save count; events also date/time.  
- **Implementation:**  
  - **PortalEventCard:** Date sidebar, category, title, date/time, address, host attribution, save button. No hero image filling card; uses date strip + body. ⚠️  
  - **PortalSpotCard:** Image, name, neighborhood, price, owner attribution, save. ✅  
- So: event cards do not use “hero image filling the card frame” as in PRD; they use the date-sidebar layout.

---

### 2.3 Map (Tab 2)

| PRD | Implementation | Status |
|-----|-----------------|--------|
| Full-screen map, same data as Discover | Map with events + spots, shared filters | ✅ |
| Pin color | **Both** `EventPin` and `SpotPin` use **`portalPrimary` (teal)** background (March 2026 audit) | ✅ (differs from older PRD “dark spots / orange events”) |
| Event vs spot identity | **Event:** `ticket.fill` + title; **Spot:** `mappin` + name | ✅ |
| Live events: “LIVE” badge on pin | **“LIVE”** capsule on `EventPin` when `event.isLive`; scale pulse | ✅ |
| Layer toggle: All / Spots / Events | In Map filter sheet as “Content” picker | ✅ |
| Filters shared with Discover | `DiscoverFilters` shared via environment | ✅ |
| Tap pin → card preview at top | Preview card with title, time, address, creator, save button | ✅ |
| Tap card → full detail | Opens `EventDetailView` in sheet | ✅ |
| Save on card preview | Save button on preview | ✅ |
| Long-press → create with location pre-filled | Long-press opens `CreateEventView(initialLocation:)` | ✅ |
| Recenter button | Recenter to user/city center | ✅ |

**Spec note:** Map pins are intentionally **uniform teal** with **iconography** to distinguish entity types (better colorblind safety than orange-vs-dark alone).

---

### 2.4 Profile (Tab 3)

**Own profile**

| PRD | Implementation | Status |
|-----|-----------------|--------|
| Header: Avatar (initial + color), name, handle, current city | Avatar (initial + orange), name, **email** (no handle/city) | ⚠️ Handle and city missing |
| Stats: Saved, Collections, Following | Metric cards: SAVED, COLLECTIONS, FOLLOWING | ✅ |
| My Saves — reverse chronological, same card treatment | `MySavesView` with mixed spots/events, reverse chronological | ✅ |
| My Collections — name, visibility badge, item count, cover; “Create collection” | List with name, item count; create via toolbar; **no visibility badge or cover image** in list row | ⚠️ Partial |
| My Spots — spot cards, “+” to create | “My Spots” placeholder; no “+” create yet | ⚠️ Placeholder |
| My Events — event cards, “+” to create | `MyEventsView` with `PortalEventCard`; create via other entry points | ✅ (no “+” on Profile itself in reviewed code) |
| Following — horizontal avatars + names | Horizontal scroll of following | ✅ |

**Other user profile**  
`UserProfileView`: avatar, name, follower/following, follow state, events. **Follow** CTA uses **`portalGradientPrimary` (teal)** (was coral). Empty “no events” state uses neutral **calendar** icon (not exclamation). Public collections and “Saved items” (only when following) behavior not fully re-verified here; structure exists.

---

## 3. Detail screen (event) — “Top fold”

PRD: Top fold without scrolling answers: *What?* (name, category, tags), *When?* (date/time or “Open”), *Where?* (neighborhood + distance), *Why trust?* (creator, savers, save count). Primary action: **Save**, prominent, one tap.

**Implementation:**  
- `EventDetailView`: hero image, date strip + title on hero, **Save** via **`PortalSaveButton`** in the hero top bar (one tap; separate “Add to collection” control).  
- **Gaps:** No explicit grouped “above the fold” summary block; category/tags and “Why trust?” (creator + save count) not consolidated; distance/neighborhood not always called out in one block.

**Recommendation:** Add a compact “top fold” section (name, category, when, where, creator + save count) and keep Save as the primary action; optionally move Save into that fold on desktop or large screens.

---

## 4. Save behavior

- One-tap save without “which collection?” required: ✅  
- Save on card (feed), map preview, and detail: ✅ — shared **`PortalSaveButton`** (teal-filled circle when saved; outlined when not; count adjacent).  
- “Add to collection” remains a **separate** explicit action (not chained to Save). ✅  
- Default to unsorted personal saves: ✅ (no forced collection pick)

---

## 5. Collections

- Create from Profile → My Collections: ✅  
- Name, description, visibility (Private/Friends/Public): Create sheet includes **visibility** (`CreateCollectionVisibility`). ✅  
- Collection card: cover, name, creator, item count; PRD also “save count” for public collections — not clearly on `PortalCollectionCard`. ⚠️  
- Sharing (link, read-only web view): Not verified in UI review.

---

## 6. Cold start

PRD: First session must not be empty; location or city picker then populated feed; no “follow 5 people” or tutorial.  
Implementation: Feed loads with location/filters; city picker exists via location sheet; no forced onboarding steps seen. ✅

---

## 7. Summary of gaps (UI/design)

**Resolved in March 2026 audit (non-exhaustive)**

- DM Sans Black / Italic bundle; display vs editorial italic tokens.  
- `portalGradientOverlay` legibility; `portalRadiusSm` = 8pt.  
- Discover: hide **EVENTS** section when `filteredEvents` is empty; section title tracking + bold 14pt.  
- Location dropdown scroll + keyboard dismiss.  
- **PortalSaveButton** across feed, map preview, detail, profile grids.  
- Follow CTA teal; user-profile empty state icon.  
- Map: teal pins + `ticket.fill` for events + LIVE on pin.  
- New collection: stronger name placeholder contrast; shorter cover aspect (4:1).

**High impact (still open)**

1. **Discover feed sections:** “From Friends” / “From people you trust” and **featured collection** hero.  
2. **Discover tab icon:** Compass instead of `safari`.  
3. **Event detail “top fold”:** Single grouped block (what/when/where/why trust).

**Medium impact**

4. **Sticky header:** Discover header sticky + backdrop blur.  
5. **Profile own header:** Handle + current city.  
6. **Collection list rows:** Visibility badge + cover in list (if still missing).  
7. **Event cards in feed:** Optional hero-image variant per PRD.  
8. **Motion:** Fade-in, slide-up, staggered grid per PRD.

**Lower impact**

9. Frosted glass consistency on floating controls over photography.  
10. “People to follow” context copy (e.g. saves in city).  
11. MASTER-PRD text refresh: typography and map pin strategy now follow **DM Sans–only** and **teal + icon** map pins.

---

## 8. What’s working well

- Three-tab structure and shared filter state.  
- Time and category filter pills (single/multi, no Apply).  
- Portal color palette, card shadows, and **strong image scrims**.  
- Map preview card, **PortalSaveButton** on preview, long-press create.  
- Profile stats, My Saves (mixed, chronological), My Collections list, Following strip.  
- PortalEventCard date sidebar and live styling.  
- PortalSpotCard and PortalCollectionCard layout and attribution.  
- One-tap save, **no** automatic “pick a collection” sheet on Save.  
- Collection create flow includes **visibility** and improved cover/name UX.

---

*End of PRD UI & Design Implementation Review.*

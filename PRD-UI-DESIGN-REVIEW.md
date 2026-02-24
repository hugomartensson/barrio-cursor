# PRD UI & Design Implementation Review

**Document:** MASTER-PRD-2402 (portal. — Product Requirements Document v1)  
**Review focus:** UI and design system alignment across the iOS app  
**Date:** February 2026

---

## Executive summary

The app has **strong alignment** with the PRD in many areas: three-tab structure, filter pills (time + category), feed sections, map with pins and preview card, profile with saves/collections/events/spots, and the core “editorial” color palette. Several **gaps** remain: typography (fonts), a few PRD-specified feed sections, tab iconography, detail-screen “top fold” structure, and some design tokens (radius, map pin colors). This review lists what’s implemented, what’s partial, and what’s missing from a UI/design perspective.

---

## 1. Design system

### 1.1 Typography — **Not aligned**

| PRD | Implementation | Status |
|-----|-----------------|--------|
| **Instrument Serif** — headlines, collection names, spot/event titles, wordmark | **System default / Archivo** — `PortalTypography.swift` uses system fonts; comments reference Archivo Black/Archivo | ❌ Not implemented |
| **DM Sans** — UI text, metadata, labels, filter pills | Same — system fonts, no DM Sans | ❌ Not implemented |
| Italic variant for wordmark (*portal.*) | Wordmark is "portal" + "·" in regular weight, no italic | ❌ Not implemented |

**Recommendation:** Add Instrument Serif and DM Sans to the app bundle and switch display/headline styles to Instrument Serif and body/UI to DM Sans. Use italic for the “portal” wordmark if the PRD’s *portal.* is intended visually.

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

**Trust-layer coding:**  
PRD: Orange = editorial/authority; personal colors (blue, teal, amber) = friends; dashed ring + muted = pending.  
**Implementation:** Orange used for primary/editorial; `signatureColors` and `portalAccent` used for variety; no explicit “dashed ring + muted” for pending follow state in the reviewed UI.

---

### 1.3 Surfaces and depth — **Mostly aligned**

| PRD | Implementation | Status |
|-----|-----------------|--------|
| Cards: pure white, soft two-layer shadow | `portalCard` + double shadow (opacity 0.05/0.07, radius 1 & 6) | ✅ |
| Border radius consistent (1rem) | `portalRadius` = **12pt** (PRD implies ~16pt for 1rem) | ⚠️ Minor |
| Gradient overlay on image bottom third | `portalGradientOverlay`; used in some cards; EventCard uses date sidebar instead of hero image | ⚠️ Varies by component |
| Frosted glass on floating badges | Not consistently used (e.g. save button often solid card/muted) | ⚠️ Partial |

---

### 1.4 Layout — **Aligned**

- Single column, mobile-first: Discover feed is one scroll. ✅  
- Horizontal carousels for collections, “People to follow,” spots. ✅  
- Section labels: small, semibold, uppercase, wide-tracking, muted (e.g. `portalSectionLabel` + tracking 0.18). ✅  
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
| Spots: dark pins | `SpotPin`: `portalPrimary` (orange) background | ⚠️ PRD says “dark-colored” for spots |
| Events: accent (orange) pins | `EventPin`: `portalAccent` (blue) background | ❌ PRD says orange for events |
| Live events: “LIVE” badge on pin | “NOW” in pill on card; EventPin has scale animation for live | ⚠️ No “LIVE” on map pin itself |
| Layer toggle: All / Spots / Events | In Map filter sheet as “Content” picker | ✅ |
| Filters shared with Discover | `DiscoverFilters` shared via environment | ✅ |
| Tap pin → card preview at top | Preview card with title, time, address, creator, save button | ✅ |
| Tap card → full detail | Opens `EventDetailView` in sheet | ✅ |
| Save on card preview | Save button on preview | ✅ |
| Long-press → create with location pre-filled | Long-press opens `CreateEventView(initialLocation:)` | ✅ |
| Recenter button | Recenter to user/city center | ✅ |

**Fix:** Swap map pin semantics: **events = orange** (`portalPrimary`), **spots = dark** (e.g. dark gray/charcoal), and add a small “LIVE” badge on the map for live events if desired.

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
`UserProfileView`: avatar, name, follower/following, follow state, events. Public collections and “Saved items” (only when following) behavior not fully re-verified here; structure exists.

---

## 3. Detail screen (event) — “Top fold”

PRD: Top fold without scrolling answers: *What?* (name, category, tags), *When?* (date/time or “Open”), *Where?* (neighborhood + distance), *Why trust?* (creator, savers, save count). Primary action: **Save**, prominent, one tap.

**Implementation:**  
- `EventDetailView`: hero image (16:9), then title, date/time, address, description, “by …”.  
- Save is in a bottom safe-area inset (Save button with count).  
- **Gaps:** No explicit “above the fold” summary block; category/tags and “Why trust?” (creator + save count) are not grouped in one clear top fold; distance/neighborhood not clearly called out. Save is prominent but not in a single “top fold” block.

**Recommendation:** Add a compact “top fold” section (name, category, when, where, creator + save count) and keep Save as the primary action; optionally move Save into that fold on desktop or large screens.

---

## 4. Save behavior

- One-tap save without “which collection?” required: ✅  
- Save on card (feed), map preview, and detail: ✅  
- Default to unsorted personal saves: ✅ (no forced collection pick)

---

## 5. Collections

- Create from Profile → My Collections: ✅  
- Name, description, visibility (Private/Friends/Public): Create sheet has name + description; **visibility not in create sheet** in reviewed code. ⚠️  
- Collection card: cover, name, creator, item count; PRD also “save count” for public collections — not clearly on `PortalCollectionCard`. ⚠️  
- Sharing (link, read-only web view): Not verified in UI review.

---

## 6. Cold start

PRD: First session must not be empty; location or city picker then populated feed; no “follow 5 people” or tutorial.  
Implementation: Feed loads with location/filters; city picker exists via location sheet; no forced onboarding steps seen. ✅

---

## 7. Summary of gaps (UI/design)

**High impact**

1. **Typography:** Use Instrument Serif (display/headlines) and DM Sans (UI) per PRD; add italic wordmark if desired.  
2. **Discover feed sections:** Add “From Friends” (“From people you trust”) and “Featured collection” (one hero collection).  
3. **Map pins:** Events = orange, spots = dark; add “LIVE” on map for live events if specified.  
4. **Discover tab icon:** Use compass icon instead of safari.  
5. **Event detail “top fold”:** Add a clear top-fold block (what/when/where/why trust) and ensure Save is the primary action in that context.

**Medium impact**

6. **Sticky header:** Make Discover header (city + wordmark + filters) sticky with backdrop blur.  
7. **Profile own header:** Show handle and current city in addition to name.  
8. **Collections:** Visibility in create flow; visibility badge and save count on collection cards.  
9. **Event cards in feed:** Consider a “hero image filling card” variant for events to match PRD card description.  
10. **Motion:** Add fade-in, slide-up, and staggered grid animations per PRD.

**Lower impact**

11. Border radius: Consider 16pt (1rem) for consistency with PRD.  
12. Frosted glass for floating badges over photography.  
13. “People to follow” context: e.g. “42 saves in Barcelona” where data exists.

---

## 8. What’s working well

- Three-tab structure and shared filter state.  
- Time and category filter pills (single/multi, no Apply).  
- Portal color palette and card styling.  
- Map preview card, save on preview, long-press create.  
- Profile stats, My Saves (mixed, chronological), My Collections list, Following strip.  
- PortalEventCard date sidebar and live styling.  
- PortalSpotCard and PortalCollectionCard layout and attribution.  
- One-tap save and no forced collection selection.

---

*End of PRD UI & Design Implementation Review.*

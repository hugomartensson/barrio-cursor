# Portal Web Preview

A **web UI copy of the Barrio (Portal) iOS app** for **Cursor Browser visual editing**. The preview matches iPhone screen dimensions (390×844) and mirrors the Portal design system so that edits in Cursor’s Browser can be translated back into SwiftUI.

## Purpose

- Open this app in **Cursor’s Browser** and use the visual editor (drag-and-drop, point-and-prompt, style controls).
- After making design changes, apply the same updates to the real iOS app in `ios/BarrioCursor/BarrioCursor/BarrioCursor/` using the design system and view files.
- **Single source of truth for tokens:** `src/design-tokens.css` — change a variable here, then mirror it in `PortalColors.swift`, `PortalSpacing.swift`, or `PortalTypography.swift`.

## How to run

```bash
cd portal-web-preview
npm install
npm run dev
```

Then open **http://localhost:5173** in Cursor’s Browser (or any browser). The viewport is fixed to **390×844** (iPhone 14/15 logical size); on larger screens the “phone” is centered with a simple frame.

## Viewport & dimensions

- **Width:** 390px  
- **Min height:** 844px (content can scroll)  
- **Meta viewport:** `width=390, initial-scale=1, maximum-scale=1, user-scalable=no`  
- Root container: `max-width: 390px`, `min-height: 844px`, centered. Optional phone frame (rounded corners) is applied so it’s obvious this is an iPhone-sized copy.

## What’s included

- **Main shell:** Bottom tab bar (Discover, Map, Profile) and optional search bar for Discover/Map.
- **Discover:** Header (location pill, wordmark, time + category filter pills), section headers (EVENTS, SPOTS, PEOPLE), event cards, spot cards, people-to-follow cards — layout and styling aligned with `DiscoverView` and `Views/Components/`.
- **Profile:** YOUR / Profile title, metric cards (Saved, Collections, Following), edit-profile row, nav rows (My Saves, My Collections, My Spots, My Events), following strip, Log out.
- **Map:** Placeholder screen with same chrome (search bar, tab bar, Filter + Recenter controls) for consistent frame.

Content uses **placeholder copy and mock data**; no backend or auth.

## Creation — minimum required fields

**Event:** Title, description, category (food, drinks, music, art, markets, community), address, start time, end time, at least one image.

**Spot:** Name, description, category (same set as events), address, image.

*(Coordinates are derived from address; users enter address only.)*

## Design tokens → SwiftUI mapping

All design tokens live in **`src/design-tokens.css`** as CSS custom properties. When you change a value in the Browser (e.g. “make the primary darker”), update the corresponding SwiftUI constant so the iOS app stays in sync.

| CSS variable | SwiftUI / file |
|--------------|----------------|
| `--portal-background` | `Color.portalBackground` — PortalColors.swift |
| `--portal-foreground` | `Color.portalForeground` |
| `--portal-card` | `Color.portalCard` |
| `--portal-primary` | `Color.portalPrimary` |
| `--portal-primary-foreground` | `Color.portalPrimaryForeground` |
| `--portal-secondary` | `Color.portalSecondary` |
| `--portal-muted` | `Color.portalMuted` |
| `--portal-muted-foreground` | `Color.portalMutedForeground` |
| `--portal-accent` | `Color.portalAccent` |
| `--portal-live` | `Color.portalLive` |
| `--portal-destructive` | `Color.portalDestructive` |
| `--portal-border` | `Color.portalBorder` |
| `--portal-gradient-primary-start/end` | `portalGradientPrimary` (LinearGradient) — PortalColors.swift |
| `--portal-page-padding` | `CGFloat.portalPagePadding` (16) — PortalSpacing.swift |
| `--portal-section-spacing` | `CGFloat.portalSectionSpacing` (24) |
| `--portal-card-gap` | `CGFloat.portalCardGap` (12) |
| `--portal-radius` | `CGFloat.portalRadius` (16) |
| `--portal-date-sidebar-width` | `CGFloat.portalDateSidebarWidth` (72) |
| `--portal-bottom-nav-height` | `CGFloat.portalBottomNavHeight` (49) |
| `--portal-bottom-nav-with-search-height` | `CGFloat.portalBottomNavWithSearchHeight` (96) |
| `--portal-section-label-size` | `Font.portalSectionLabel` (10pt semibold) — PortalTypography.swift |
| `--portal-body-size` | `Font.portalBody` (17pt regular) |
| `--portal-label-size` | `Font.portalLabel` (15pt medium) |
| `--portal-label-semibold-size` | `Font.portalLabelSemibold` (12pt semibold) |
| `--portal-metadata-size` | `Font.portalMetadata` (13pt regular) |
| `--portal-display-22`, `--portal-display-28` | `Font.portalDisplay22`, `Font.portalDisplay28` |
| `--portal-wordmark-size` | `Font.portalWordmark` (48pt) |

**Examples:**

- **“Make the primary darker”** → set `--portal-primary` in `design-tokens.css`, then update `Color.portalPrimary` in `PortalColors.swift` to the same hex.
- **“Increase card padding”** → increase `--portal-page-padding` or the padding used on cards; then update `portalPagePadding` or the relevant `CGFloat` in `PortalSpacing.swift` to the same pt value.

## Tech

- **Vite + React** — single dev server, no backend; ideal for Cursor Browser visual editing and testing component states.
- **Local use only** — no deployment, no API, no auth.

## Success criteria

- Opening the web app in Cursor Browser at 390×844 feels like the iPhone app.
- You can use the Cursor Browser visual editor to drag, point-and-prompt, and adjust styles.
- After edits, you (or another agent) can describe or screenshot the result and apply the same design changes to the iOS app in `ios/BarrioCursor/...` using the design system and view files.

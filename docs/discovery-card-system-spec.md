# Discovery Card System — Complete Spec

Overview of the four card types used in the portal· Discover feed. Each has a distinct visual metaphor to help users scan quickly.

---

## 1. Event Card — Ticket Style

**File:** `docs/event-card-ticket-spec.md`

- **Metaphor:** Physical admission ticket.
- **Layout:** Horizontal: image strip (112pt) | perforated divider | ticket info. Full width, vertical stack in feed.
- **Corners:** `rounded-2xl`
- **Key elements:** Date badge (primary), save count (muted), title (display), date block (primary tint), time + venue.
- **Expand:** "See more" expands in-place; header pins for "See less".

---

## 2. Spot Card — Magazine Clipping Style

**File:** `docs/spot-card-magazine-spec.md`

- **Metaphor:** Clipping torn from a magazine.
- **Layout:** Vertical: image (4:5) with dark gradient overlay, then metadata row below. 200pt wide (or full width when expanded).
- **Corners:** `rounded-sm` (sharp, editorial).
- **Key elements:** Category pill (white, collections-style), drop-cap + serif italic title, neighborhood, avatar stack + "+12", save button top-right (theme green when saved).
- **Expand:** "See more" expands to vertical list with full-width cards.

---

## 3. User Card — Vinyl Sleeve Style

**File:** `docs/user-card-vinyl-spec.md`

- **Metaphor:** Vinyl record sleeve.
- **Layout:** Center-aligned column, 140pt wide. No card background or border.
- **Avatar:** 96pt ring (neutral `border-border`), 78pt image inside; optional groove rings.
- **Key elements:** Name (display font, centered), stats row (icon + number only: MapPin city, Bookmark saves, Users mutuals), category pills (8pt, rounded-full, 10% bg).
- **Differentiators:** Only round/centered card; rounded-full pills; no overlay text.

---

## 4. Collection Card — Magazine Cover with Side Miniatures

**File:** `docs/collection-card-magazine-spec.md`

- **Metaphor:** Magazine cover with table-of-contents strip.
- **Layout:** Horizontal: main cover (flex) + 52pt vertical thumbnail strip. 260pt wide (or full width when expanded). 4:5 aspect.
- **Corners:** `rounded-sm`
- **Key elements:** Dark gradient overlay, glassmorphic save badge + save button, category pills (primary/secondary), title (serif bold italic), "by {curator}", miniature strip with "+N".
- **Expand:** "See more" expands to vertical list with full-width cards.

---

## Shared Conventions

| Concern | Events | Spots | Users | Collections |
|--------|--------|-------|--------|-------------|
| Save icon | Bookmark | Bookmark (top-right, green when saved) | Bookmark (stats) | Bookmark (badge + button) |
| Display font | Title, date number | Drop-cap only | Name | — |
| Serif italic | — | Title rest, neighborhood | — | Title, byline |
| Corners | rounded-2xl | rounded-sm | — (no card) | rounded-sm |
| Alignment | Left | Left | Center | Left |
| Expand in feed | Yes (in-place) | Yes (in-place) | No | Yes (in-place) |

---

## Design Tokens (Cross-Card)

- **Primary (theme green):** Date blocks, save when active, primary pills.
- **Card background:** `portalCard` for ticket/editorial cards; not used for User.
- **Border:** `portalBorder` (neutral); User ring uses this only.
- **Muted text:** `portalMutedForeground` for secondary copy.
- **Category pills:** HSL per category, 10% bg + full color text; User uses 8pt and Capsule; Spots/Collections use 8pt and rounded-sm.

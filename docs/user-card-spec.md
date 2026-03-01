# User Card (Suggested Curator) — Discovery

## Concept

The User card represents a **curator/user** whose recommendations you can follow. It uses a circular profile photo layout with metadata stacked underneath. No full-bleed image or gradient overlay — the card is a simple flex column, left-aligned, fixed at **140px** wide.

## Structure

- **Profile image** — 80pt circle (`w-20 h-20 rounded-full object-cover`) with a 2px card-colored border (`border-2 border-card`) and `shadow-card`. Scales up 5% on hover over 300ms. Wrapped in a `relative mb-2` container.
- **Text content** (left-aligned below image):
  - **Name** — `font-display text-sm leading-tight text-foreground font-bold`. Display font (DMSans Bold) at 14px.
  - **Metadata row (mt-1)** — Flex row with `gap-2`, `text-[10px] text-muted-foreground`. Contains three inline items:
    - Location: `MapPin` icon (10px) + city abbreviation (e.g., "NYC")
    - Saves: `Bookmark` icon (10px) + number of saved spots (or follower count as "saves")
    - Mutuals: `Users` icon (10px) + number of mutual connections
  - **Category pills (mt-1.5)** — Flex row with `gap-1 flex-wrap`. Each pill uses the shared category pill style (e.g., Food, Music, Art) with HSL inline styles: 10% opacity backgrounds and full-opacity text.

## Layout

User cards scroll horizontally in the USERS section of the Discover feed. Each card is `flex-shrink-0` at **140px** wide.

## Design Tokens Used

| Token | Value | Usage |
|-------|-------|--------|
| `text-foreground` | `hsl(25 12% 10%)` | Name |
| `text-muted-foreground` | `hsl(25 8% 48%)` | Metadata row |
| `font-display` | DMSans Bold | Name at 14px |
| `border-card` | Card background | Profile circle border |
| `shadow-card` | Double shadow | Profile image elevation |
| Category pill colors | HSL per category | Food, Music, Art pills |

## Icons (SF Symbols)

- `mappin` — location / city
- `bookmark` — save count
- `person.2` — mutual connections

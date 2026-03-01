# User Card — Vinyl Sleeve Style

## Concept

The User card is designed to evoke a **vinyl record sleeve** — a circular avatar framed by a subtle ring, centered layout, and compact metadata. Unlike the editorial sharp-cornered cards used for Spots and Collections, the User card is intentionally round and centered to feel personal and approachable. The circular motif differentiates "people" from "places" at a glance.

## Structure

A vertically stacked, center-aligned container at a fixed width of `140px`. No background card or border — the avatar ring *is* the visual anchor. Everything below it is centered text.

```
  {/* Avatar with ring */}
  {/* Name */}
  {/* Stats row */}
  {/* Category pills */}
```

## Avatar Ring

The avatar sits inside a `w-24 h-24` (`96px`) circular frame. The ring is a neutral border using `border border-border` — no color tinting, just a clean subtle outline that frames the photo.

Inside, the avatar image is `78px` rounded-full object-cover, leaving a small gap between the image edge and the outer ring. On hover, the image scales up over 300ms.

A decorative `pointer-events-none` overlay adds faint concentric "groove" lines (e.g. inset ring shadows) — a subtle nod to vinyl grooves without being heavy-handed.

## Name

Displayed in `font-display` (Archivo Black / DMSans Bold) at `text-sm leading-tight text-foreground font-bold`. Centered below the avatar. No serif italic — the display font keeps User cards feeling punchy and distinct from the editorial serif used on Spots and Collections.

## Stats Row

A horizontal flex row with three icon+number pairs. No text labels — strictly the minimalist "icon + number" pattern:

- `MapPin` — city abbreviation (e.g., "NYC", "BKN", "LA")
- `Bookmark` — number of saved spots
- `Users` — number of mutual connections

All icons are 8px; text is 9px, `text-muted-foreground`. Compact layout.

## Category Pills

A row of rounded pills (`rounded-full` / Capsule) below the stats, each with a tinted HSL background and matching text color. Uses `text-[8px] font-semibold` — smaller than other cards to stay proportional to the compact layout. These represent the user's recommendation "specialties" (e.g., Food, Music, Wine).

Each pill's background is the category color at 10% opacity, with the text in the full color.

## Layout

User cards scroll horizontally in the USERS section. At `140px` wide, roughly 2.5 cards are visible at once.

## Design Tokens Used

| Token | Value | Usage |
|-------|-------|--------|
| `text-foreground` | `hsl(25 12% 10%)` | Name |
| `text-muted-foreground` | `hsl(25 8% 48%)` | Stats row |
| `border-border` | `hsl(40 10% 88%)` | Avatar ring, groove shadows |
| `font-display` (DMSans Bold) | — | Name (bold, not serif) |
| Category HSL at 10% | — | Pill backgrounds |
| Category HSL at 100% | — | Pill text |

## Icons (SF Symbols)

- `mappin` — city location
- `bookmark` — saved spots count
- `person.2` — mutual connections count

## Key Differentiators from Other Cards

- **Round vs sharp**: Only card type using circular imagery and `rounded-full` pills (Spots/Collections use `rounded-sm`)
- **Centered layout**: Only card type with center alignment (others are left-aligned or flex-row)
- **No image overlay text**: Name and stats sit *below* the avatar, not over a gradient
- **Display font, not serif**: Keeps user names bold and modern vs. editorial italic for venue/collection names
- **No card background**: No background or border container; the avatar ring is the anchor

# Event Card — Ticket Style

## Concept

The Event card is designed to look like a physical **admission ticket**. It uses a horizontal (landscape) layout split into two halves — a photo strip on the left and ticket information on the right — connected by a perforated tear-line divider. Cards stack vertically at full width rather than scrolling horizontally, reinforcing the "stack of tickets" metaphor.

## Structure

The card is a `flex` row inside a rounded container (`rounded-2xl`) with a card background, a thin border (`border border-border`), and the standard card shadow (`shadow-card`). On hover, the shadow warms up (`hover:shadow-warm`).

```tsx
{/* Left image | Divider | Right info */}
```

## Left Panel — Image Strip

A fixed-width image column (`w-28`, ~112px) acts as the "stub" of the ticket. The image is absolutely positioned to fill the panel and uses `object-cover`. A subtle right-fading gradient (`bg-gradient-to-r from-transparent to-card/20`) softens the transition into the divider. On hover, the image scales up slightly over 700ms (`group-hover:scale-105`).

## Center — Perforated Divider

The divider mimics a tear-off perforation found on real tickets. It consists of:

1. A **top circle** (`w-4 h-4 rounded-full`) filled with `bg-background` and bordered, positioned so it overlaps the top edge (`-mt-2`), creating the illusion of a punched-out semicircle.
2. A **dashed vertical line** (`border-l border-dashed border-border/60`) filling the remaining height via `flex-1`.
3. A **bottom circle** identical to the top but overlapping the bottom edge (`-mb-2`).

The entire divider column is `w-4`, uses negative horizontal margin (`-mx-2`) to tuck snugly between the image and info panels, and sits above them (`z-10`).

## Right Panel — Ticket Information

The info panel is `flex-1` with padding `p-3 pl-2` and uses `flex flex-col justify-between` to space the content vertically into two groups: **header** and **details**.

### Header Group

- A top row with a category label on the left (`text-[9px] font-bold uppercase tracking-[0.16em] text-muted-foreground`) and a save count on the right (Bookmark icon + count, both `text-muted-foreground`).
- The event title below (`font-display text-sm leading-tight text-foreground mt-1 line-clamp-2`), clamped to 2 lines.

```tsx
Event          {saves}
{title}
```

### Details Group

A horizontal flex row (`flex items-center gap-3 mt-2`) containing:

1. **Date block** — A compact rounded box (`px-2 py-1 rounded-lg bg-primary/10`) showing the month abbreviation in `text-[9px] font-bold uppercase tracking-wider text-primary` and the day number in `font-display text-lg leading-none text-primary font-extrabold`. This creates a bold calendar-chip effect tinted in the primary amber color.

2. **Time & venue** — A vertical stack (`flex flex-col gap-0.5 text-xs text-muted-foreground`) with Clock icon + time and MapPin icon + venue name (truncated).

```tsx
{month}    {time}
{day}      {venue}
```

## Layout — Vertical Stack

Unlike Spot and Collection cards that scroll horizontally, event tickets stack vertically in a `flex flex-col gap-3 px-4` container. Each card occupies the full width. This stacking reinforces the "pile of tickets" visual and gives each event more breathing room.

## Design Tokens Used

| Token | Value | Usage |
|-------|-------|--------|
| `bg-card` | `hsl(0 0% 100%)` | Card background |
| `border-border` | `hsl(40 10% 88%)` | Card border, circle borders |
| `bg-background` | `hsl(40 12% 96%)` | Perforation circles (match page bg) |
| `text-primary` / `bg-primary/10` | Amber `hsl(32 95% 52%)` | Date block text and tinted background |
| `text-muted-foreground` | `hsl(25 8% 48%)` | All secondary text, icons |
| `text-foreground` | `hsl(25 12% 10%)` | Title |
| `font-display` | Archivo Black | Title, date number |
| `shadow-card` | Subtle double shadow | Default elevation |
| `shadow-warm` | Amber-tinted glow | Hover state |

## Icons (Lucide)

- `Bookmark` — save count (top right of info panel)
- `Clock` — event time
- `MapPin` — venue name
- `Calendar` — imported but not used in this variant (available for future use)

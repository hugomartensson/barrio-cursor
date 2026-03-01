# Spot Card — Magazine Clipping Style

## Concept

The Spot card is designed to look like a **clipping torn from a high-end magazine**. It uses sharp corners (`rounded-sm`) instead of the rounded-2xl used elsewhere, creating a deliberate visual break that says "this was cut out." Typography mixes a bold display drop-cap with serif italic body text, giving each card an editorial, curated feel rather than a utilitarian listing.

## Structure

The card is a vertical stack: an image container on top and a metadata row below it. The outer wrapper has a fixed width of `200px` and no background — the image *is* the card. Below the image, social proof and saves sit outside the photo on the page background.

## Image Panel

The image fills the container absolutely at a **4:5 aspect ratio** — taller than the event ticket but shorter than a full portrait. On hover, it scales up over 700ms (`group-hover:scale-105`).

A dark gradient overlays the image from bottom to top using the foreground color: `bg-gradient-to-t from-foreground/80 via-foreground/20 to-transparent`. This is different from the other cards which use `from-card` — here the overlay is intentionally dark/moody to match the editorial print aesthetic.

## Text Overlay (Bottom of Image)

All text sits inside an absolutely positioned bottom container over the gradient.

- **Category label** — A tiny uppercase tag in primary amber (`text-[9px] font-bold uppercase tracking-[0.2em] text-primary`). This acts like a magazine section header (e.g., "FOOD", "BAR", "ITALIAN").
- **Title** — Drop-cap + serif italic treatment:
  - The first character is rendered in Archivo Black (`font-display text-2xl not-italic font-extrabold`) — large, bold, and upright.
  - The remaining characters use Georgia serif in italic (`fontFamily: "Georgia, 'Times New Roman', serif"`, `fontStyle: "italic"`, `fontWeight: 400`).
  - The text color is `text-card` (white) to contrast against the dark gradient.
- **Neighborhood** — Below the title, a small italic location line with a MapPin icon (`text-[10px] text-card/70`, `fontStyle: "italic"`).

## Metadata Row (Below Image)

A flex row sitting on the page background (not on the image). Contains two groups:

- **Left — Avatar stack** with negative spacing. Each avatar is a `w-4 h-4` circle with a custom HSL background color, white initials in `text-[6px] font-bold`, and a `border border-card` to create separation. A "+12" count label in `text-[9px] text-muted-foreground` follows.
- **Right — Save count** with a Bookmark icon (`w-2.5 h-2.5`) and count in `text-[10px] font-semibold text-muted-foreground`.

## Layout

Spot cards scroll horizontally in a `flex gap-3 overflow-x-auto px-4 pb-2 scrollbar-hide` container. Each card is `flex-shrink-0` at `200px` wide, so roughly 1.5 cards are visible at a time, with the next card peeking from the right.

## Design Tokens Used

| Token | Value | Usage |
|-------|-------|--------|
| `text-card` | `hsl(0 0% 100%)` | Title text over dark gradient |
| `text-card/70` | White at 70% | Neighborhood, secondary text |
| `text-primary` | Amber `hsl(32 95% 52%)` | Category label |
| `text-muted-foreground` | `hsl(25 8% 48%)` | Metadata below image |
| `from-foreground/80` | Dark at 80% | Bottom gradient (editorial dark) |
| `shadow-card` | Subtle double shadow | Card elevation |
| `rounded-sm` | Small radius | Sharp "clipped" corners |
| `font-display` (Archivo Black) | — | Drop-cap first letter |
| Georgia serif italic | — | Title body + neighborhood |

## Icons (Lucide / SF Symbols)

- `MapPin` — neighborhood location
- `Bookmark` — save count

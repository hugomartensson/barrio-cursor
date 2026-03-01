# Collection Card — Magazine Cover with Side Miniatures

## Concept

The Collection card is designed to look like a **magazine cover** with a vertical strip of preview thumbnails on the right edge. The main image acts as the cover photo, editorial text overlays the bottom, and the side strip gives a visual "table of contents" showing what's inside. The combination of a large hero image + small previews immediately communicates "this contains multiple curated spots."

## Structure

The card is a horizontal `flex` container at a fixed width of `260px` with a **4:5 aspect ratio**, using `rounded-sm` for the editorial sharp-corner treatment. It contains two children: the main cover image (flex-1) and a narrow vertical thumbnail strip (fixed 52px).

## Main Cover Image (Left)

The cover image is `flex-1`, positioned relatively, with the image absolutely filling it. On hover it scales over 700ms (`group-hover:scale-105`).

The gradient overlay uses the same dark editorial treatment as the Spot card: `bg-gradient-to-t from-foreground/90 via-foreground/40 to-foreground/10` — heavier at the bottom (90% opacity) to ensure text legibility.

## Save Badge (Top Right of Cover)

A glassmorphic pill badge positioned at `absolute top-2.5 right-2.5`. Uses `bg-card/80 backdrop-blur-sm border border-card/20` for the frosted glass effect. Contains a Bookmark icon (`w-3 h-3 text-foreground/70`) and the count in `text-[10px] font-semibold text-foreground/80`. This is more prominent than the Spot card's metadata-row save count — it's intentionally eye-catching because collections are meant to be saved.

## Bottom Content (Over Cover Image)

Positioned at `absolute inset-x-0 bottom-0 p-3 z-10`, contains three elements stacked vertically:

- **Category pills** — Primary category uses `text-primary bg-primary/20`, secondary uses `text-card/60 bg-card/10`. Both are `rounded-sm text-[8px] font-bold uppercase tracking-wider`.
- **Title** — Uses Georgia serif in bold italic. Color is `text-card` (white). Size is `text-lg leading-tight`. No drop-cap here (unlike Spot) — the full title is in serif italic because collection names are longer phrases.
- **Curator byline** — A row with a small avatar circle (`w-5 h-5 rounded-full`) filled with primary color, showing the curator's initials. Next to it, "by {curator}" in `text-[10px] text-card/70` with `fontStyle: "italic"`.

## Right — Vertical Miniature Strip

A narrow column (`width: 52px`) with `flex flex-col gap-1 p-1 bg-foreground/5` that sits flush against the right edge of the card. It serves as a visual preview of the collection's contents.

Each thumbnail is `flex-1 rounded-sm overflow-hidden` with its image filling via `object-cover`. The thumbnails stretch equally to fill the card height.

If the collection has more spots than images provided, a final "+N" box appears: `flex-1 rounded-sm bg-foreground/30` centered with `text-[9px] font-bold text-card/80`.

## Layout

Collection cards scroll horizontally in a `flex gap-3 overflow-x-auto px-4 pb-2 scrollbar-hide` container, same as Spots. At `260px` wide, roughly one full card is visible with the next peeking from the right.

## Design Tokens Used

| Token | Value | Usage |
|-------|-------|--------|
| `text-card` | `hsl(0 0% 100%)` | Title, curator text over dark gradient |
| `text-card/70` | White at 70% | Byline |
| `text-card/80` | White at 80% | "+N" count |
| `text-primary` / `bg-primary/20` | Amber | Primary category pill, curator avatar |
| `text-foreground/70`, `/80` | Near-black | Save badge icon and text |
| `bg-card/80` | White at 80% | Glassmorphic save badge |
| `bg-foreground/5` | Very subtle dark tint | Miniature strip background |
| `bg-foreground/30` | Dark tint | "+N" overflow thumbnail |
| `from-foreground/90` | Heavy dark | Bottom gradient |
| `shadow-card` | Double shadow | Card elevation |
| `rounded-sm` | Sharp corners | Editorial / print aesthetic |
| Georgia serif italic bold | — | Collection title |

## Icons (Lucide / SF Symbols)

- `Bookmark` — save badge (glassmorphic pill, top right)
- `MapPin` — not used on the collection card (spot count removed; miniatures communicate content volume visually)

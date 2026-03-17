# Design tokens — Portal Web Preview ↔ SwiftUI

This file documents every design token used in the web preview and its **exact mapping** to the iOS app. When you change a value in Cursor Browser (or in `src/design-tokens.css`), update the corresponding SwiftUI constant so both stay in sync.

## Colors (`PortalColors.swift`)

| CSS variable | SwiftUI | Hex (current) |
|--------------|---------|----------------|
| `--portal-background` | `Color.portalBackground` | #F2F2F0 |
| `--portal-foreground` | `Color.portalForeground` | #1F1810 |
| `--portal-card` | `Color.portalCard` | #FFFFFF |
| `--portal-primary` | `Color.portalPrimary` | #2F7168 |
| `--portal-primary-foreground` | `Color.portalPrimaryForeground` | #FFFFFF |
| `--portal-secondary` | `Color.portalSecondary` | #E8E8E6 |
| `--portal-muted` | `Color.portalMuted` | #E0E0DE |
| `--portal-muted-foreground` | `Color.portalMutedForeground` | #6B6B68 |
| `--portal-accent` | `Color.portalAccent` | #2563EB |
| `--portal-live` | `Color.portalLive` | #F25C8C |
| `--portal-destructive` | `Color.portalDestructive` | #E03E3E |
| `--portal-border` | `Color.portalBorder` | #E0E0DE |
| `--portal-gradient-primary-start` | `portalGradientPrimary` start | #2F7168 |
| `--portal-gradient-primary-end` | `portalGradientPrimary` end | #3D8A80 |

## Spacing & layout (`PortalSpacing.swift`)

| CSS variable | SwiftUI | Value |
|--------------|---------|--------|
| `--portal-page-padding` | `CGFloat.portalPagePadding` | 16px |
| `--portal-section-spacing` | `CGFloat.portalSectionSpacing` | 24px |
| `--portal-card-gap` | `CGFloat.portalCardGap` | 12px |
| `--portal-radius` | `CGFloat.portalRadius` | 16px |
| `--portal-date-sidebar-width` | `CGFloat.portalDateSidebarWidth` | 72px |
| `--portal-bottom-nav-height` | `CGFloat.portalBottomNavHeight` | 49px |
| `--portal-bottom-nav-with-search-height` | `CGFloat.portalBottomNavWithSearchHeight` | 96px |

## Typography (`PortalTypography.swift`)

| CSS variable | SwiftUI | Size | Weight |
|--------------|---------|------|--------|
| `--portal-wordmark-size` | `Font.portalWordmark` | 48pt | SemiBold (DMSans) |
| `--portal-display-72` | `Font.portalDisplay72` | 72pt | SemiBold |
| `--portal-display-28` | `Font.portalDisplay28` | 28pt | SemiBold |
| `--portal-display-22` | `Font.portalDisplay22` | 22pt | SemiBold |
| `--portal-section-label-size` | `Font.portalSectionLabel` | 10pt | Semibold |
| `--portal-body-size` | `Font.portalBody` | 17pt | Regular |
| `--portal-label-semibold-size` | `Font.portalLabelSemibold` | 12pt | Semibold |
| `--portal-label-size` | `Font.portalLabel` | 15pt | Medium |
| `--portal-metadata-size` | `Font.portalMetadata` | 13pt | Regular |

Display/wordmark use **DMSans** (bundled in iOS, loaded via Google Fonts in web). Body uses **system sans**.

## Shadows

| CSS variable | SwiftUI |
|--------------|---------|
| `--portal-shadow-card-1` | `portalCardShadow()` — 1pt + 6pt shadow |
| `--portal-shadow-card-2` | (same modifier) |
| `--portal-shadow-warm` | `portalWarmShadow()` — primary CTA shadow |

## Quick reference: “I changed X in the Browser”

- **Primary color** → `--portal-primary` + `Color.portalPrimary` (hex)
- **Card padding / page padding** → `--portal-page-padding` + `CGFloat.portalPagePadding`
- **Section spacing** → `--portal-section-spacing` + `CGFloat.portalSectionSpacing`
- **Card corner radius** → `--portal-radius` + `CGFloat.portalRadius`
- **Section label size** → `--portal-section-label-size` + `Font.portalSectionLabel` (size)
- **Body text size** → `--portal-body-size` + `Font.portalBody` (size)

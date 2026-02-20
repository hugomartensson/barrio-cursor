# Concept G: Editorial Minimalism — Design System Specification

## Overview

This document provides concrete implementation specifications for Concept G: Editorial Minimalism. It includes SwiftUI-specific code patterns, color palettes, typography scales, component specifications, and animation guidelines.

---

## Color System

### Base Colors

```swift
extension Color {
    // Pure backgrounds
    static let editorialWhite = Color(hex: "#FFFFFF")
    static let editorialBlack = Color(hex: "#000000")
    
    // Signature event colors (for duotone overlays and live event halos)
    static let signatureMustard = Color(hex: "#FFC107")      // Mustard yellow
    static let signaturePurple = Color(hex: "#7B2CBF")        // Deep purple
    static let signatureGreen = Color(hex: "#00E676")        // Electric green
    static let signatureCoral = Color(hex: "#FF6B6B")         // Coral
    static let signatureIndigo = Color(hex: "#3F51B5")       // Indigo
    
    // System colors (minimal use)
    static let editorialPrimary = Color.primary               // Black/White based on mode
    static let editorialSecondary = Color.secondary           // Gray for metadata
    
    // Auth (dark) – login/signup screen only, for an "exciting" first impression
    static let editorialAuthBackground = Color(hex: "#0D0D0D")
    static let editorialAuthPrimary   = Color.white
    static let editorialAuthSecondary = Color.white.opacity(0.7)
    static let editorialAuthUnderline = Color.white.opacity(0.4)
}
```

### Color Usage Rules

- **Backgrounds**: Always pure white (`#FFFFFF`) or pure black (`#000000`)
- **Text**: Use `.primary` for main content, `.secondary` for metadata
- **Event Colors**: Assign signature colors per event (stored in event model or derived from category)
- **Live Events**: Use signature color for halos and glows (intensified)

---

## Typography System

### Type Scale

```swift
extension Font {
    // Hero headlines - event titles
    static let editorialHero: Font = .system(size: 56, weight: .bold, design: .default)
    static let editorialHeroLarge: Font = .system(size: 72, weight: .bold, design: .default)
    
    // Section headers - category/time groupings
    static let editorialSection: Font = .system(size: 36, weight: .semibold, design: .default)
    
    // Body text - descriptions
    static let editorialBody: Font = .system(size: 17, weight: .regular, design: .default)
    
    // Metadata - dates, locations, organizers
    static let editorialMetadata: Font = .system(size: 13, weight: .light, design: .default)
    
    // UI labels - buttons, filters
    static let editorialLabel: Font = .system(size: 15, weight: .medium, design: .default)
}
```

### Typography Usage

```swift
// Event title (hero)
Text(event.title)
    .font(.editorialHero)
    .foregroundColor(.editorialPrimary)

// Section header
Text("Happening Now")
    .font(.editorialSection)
    .foregroundColor(.editorialSecondary)

// Body text
Text(event.description)
    .font(.editorialBody)
    .foregroundColor(.editorialPrimary)
    .lineSpacing(4)

// Metadata
HStack {
    Text(event.startTime, style: .date)
    Text("•")
    Text(event.address)
}
.font(.editorialMetadata)
.foregroundColor(.editorialSecondary)
```

---

## Spacing System

### Spacing Scale

```swift
extension CGFloat {
    static let editorialXS: CGFloat = 4
    static let editorialSM: CGFloat = 8
    static let editorialMD: CGFloat = 16
    static let editorialLG: CGFloat = 32
    static let editorialXL: CGFloat = 48
    static let editorialXXL: CGFloat = 64
    static let editorialHero: CGFloat = 96  // For hero image heights
}
```

### Spacing Rules

- **Between events**: `.editorialLG` (32pt) minimum
- **Within event cards**: `.editorialMD` (16pt) for content, `.editorialSM` (8pt) for tight groupings
- **Screen edges**: `.editorialMD` (16pt) horizontal padding
- **Hero images**: Full-bleed (no padding) or `.editorialMD` inset

---

## Component Specifications

### Event Card (Feed View)

```swift
struct EditorialEventCard: View {
    let event: Event
    let isLive: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Hero image - 16:9 aspect ratio, modern feel
            EditorialEventImage(
                imageURL: event.media.first?.url,
                signatureColor: event.signatureColor,
                isLive: isLive
            )
            .aspectRatio(16/9, contentMode: .fill)
            .frame(height: UIScreen.main.bounds.width * (9/16))  // Maintains 16:9
            
            // Content - minimal, typography-focused
            VStack(alignment: .leading, spacing: .editorialSM) {
                // Title - massive headline
                Text(event.title)
                    .font(.editorialHero)
                    .foregroundColor(.editorialPrimary)
                    .lineLimit(2)
                
                // Metadata - whispers
                HStack(spacing: .editorialSM) {
                    Text(event.startTime, style: .date)
                    Text("•")
                    Text(event.address)
                }
                .font(.editorialMetadata)
                .foregroundColor(.editorialSecondary)
                
                // Organizer - minimal
                Text("by \(event.user.name)")
                    .font(.editorialMetadata)
                    .foregroundColor(.editorialSecondary)
            }
            .padding(.editorialMD)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.editorialWhite)  // or .editorialBlack in dark mode
        .overlay(
            // Live event halo
            isLive ? LiveEventHalo(color: event.signatureColor) : nil
        )
    }
}
```

### Editorial Event Image

```swift
struct EditorialEventImage: View {
    let imageURL: String?
    let signatureColor: Color
    let isLive: Bool
    
    var body: some View {
        ZStack {
            // Base image
            AsyncImage(url: URL(string: imageURL ?? "")) { phase in
                switch phase {
                case .empty:
                    Color.editorialSecondary.opacity(0.1)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Color.editorialSecondary.opacity(0.1)
                @unknown default:
                    Color.editorialSecondary.opacity(0.1)
                }
            }
            
            // Duotone overlay
            signatureColor
                .opacity(0.25)
                .blendMode(.multiply)
            
            // Gradient fade (optional)
            LinearGradient(
                colors: [
                    .clear,
                    signatureColor.opacity(0.3)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .clipped()
    }
}
```

### Live Event Halo

```swift
struct LiveEventHalo: View {
    let color: Color
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.3
    
    var body: some View {
        RoundedRectangle(cornerRadius: 0)  // Sharp edges
            .stroke(color, lineWidth: 3)
            .shadow(color: color.opacity(0.5), radius: 8)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .animation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                value: pulseScale
            )
            .onAppear {
                withAnimation {
                    pulseScale = 1.02
                    pulseOpacity = 0.7
                }
            }
    }
}
```

### Text-Based Filter

```swift
struct EditorialFilter: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.editorialLabel)
                .foregroundColor(isActive ? .editorialPrimary : .editorialSecondary)
                .underline(isActive)
                .padding(.horizontal, .editorialMD)
                .padding(.vertical, .editorialSM)
        }
        .buttonStyle(.plain)
    }
}
```

### Minimal Button

```swift
struct EditorialButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.editorialLabel)
                .foregroundColor(.editorialPrimary)
                .padding(.horizontal, .editorialLG)
                .padding(.vertical, .editorialMD)
                .overlay(
                    Rectangle()
                        .stroke(Color.editorialPrimary, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
```

### Auth & Landing (Exciting Flow)

The login/signup flow is an **editorial moment**: dark background, one bold statement, underlined inputs, one clear CTA.

**Auth screen structure:**
1. **Background**: Dark (`editorialAuthBackground` — e.g. `#0D0D0D`) for focus and contrast.
2. **Brand block**: Icon + app name (“Barrio”) in large type; one **statement line** below (e.g. “100% local.” or “Discover local events.”) in `editorialStatement` (large, bold, light color).
3. **Form**: Underlined inputs only; optional small **uppercase labels** above fields (“YOUR EMAIL”, “PASSWORD”) in `editorialMetadata`, light grey.
4. **Primary CTA**: Single bordered button (thin light border, light text). Use `EditorialButton` with light-theme variant for dark background (stroke + text = white/off-white).
5. **Secondary**: Text link with underline to switch login ↔ signup; same font, secondary light color.

**Colors for dark auth:**
```swift
// Auth (dark) – use for login/signup screen only
static let editorialAuthBackground = Color(hex: "#0D0D0D")
static let editorialAuthPrimary   = Color.white
static let editorialAuthSecondary = Color.white.opacity(0.7)
static let editorialAuthUnderline = Color.white.opacity(0.4)
```

**Typography for auth:**
- App name: `editorialHeroLarge` (72pt bold), `editorialAuthPrimary`
- Statement line: `editorialSection` or `editorialHero` (36–56pt), `editorialAuthPrimary`
- Field labels (optional): `editorialMetadata`, uppercase, `editorialAuthSecondary`
- Input text: `editorialBody`, `editorialAuthPrimary`
- Primary button: `editorialLabel`, `editorialAuthPrimary`
- Link: `editorialLabel`, `editorialAuthSecondary`, underline

**Auth input (underlined, dark theme):**
- No icon or minimal icon; thin bottom border `editorialAuthUnderline`
- Placeholder and text: `editorialAuthPrimary` / `editorialAuthSecondary`

**Auth primary button (dark):**
- Border: 1pt `editorialAuthPrimary`
- Background: clear or very subtle fill
- Text: `editorialAuthPrimary`
- Press: opacity 0.8

---

## Layout Patterns

### Feed View Layout

```swift
struct EditorialFeedView: View {
    let events: [Event]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: .editorialLG) {
                // Live events section (if any)
                if let liveEvents = liveEvents, !liveEvents.isEmpty {
                    EditorialSectionHeader(title: "Happening Now")
                    ForEach(liveEvents) { event in
                        EditorialEventCard(event: event, isLive: true)
                    }
                }
                
                // Upcoming events
                EditorialSectionHeader(title: "Upcoming")
                ForEach(upcomingEvents) { event in
                    EditorialEventCard(event: event, isLive: false)
                }
            }
            .padding(.horizontal, .editorialMD)
            .padding(.vertical, .editorialLG)
        }
        .background(Color.editorialWhite)  // or .editorialBlack
    }
}
```

### Event Detail View Layout

```swift
struct EditorialEventDetailView: View {
    let event: Event
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero image - full bleed, 16:9 aspect ratio
                EditorialEventImage(
                    imageURL: event.media.first?.url,
                    signatureColor: event.signatureColor,
                    isLive: event.isLive
                )
                .aspectRatio(16/9, contentMode: .fill)
                .frame(height: UIScreen.main.bounds.width * (9/16))  // Maintains 16:9
                
                // Content - minimal padding
                VStack(alignment: .leading, spacing: .editorialLG) {
                    // Title - massive
                    Text(event.title)
                        .font(.editorialHeroLarge)
                        .foregroundColor(.editorialPrimary)
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: .editorialSM) {
                        HStack {
                            Text(event.startTime, style: .date)
                            Text("•")
                            Text(event.startTime, style: .time)
                        }
                        Text(event.address)
                    }
                    .font(.editorialMetadata)
                    .foregroundColor(.editorialSecondary)
                    
                    // Description
                    Text(event.description)
                        .font(.editorialBody)
                        .foregroundColor(.editorialPrimary)
                        .lineSpacing(6)
                }
                .padding(.editorialMD)
            }
        }
        .background(Color.editorialWhite)
    }
}
```

---

## Animation Guidelines

### Live Event Pulse Animation

```swift
struct LiveEventPulse: ViewModifier {
    let color: Color
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.02 : 1.0)
                    .opacity(isPulsing ? 0.7 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func liveEventPulse(color: Color) -> some View {
        modifier(LiveEventPulse(color: color))
    }
}
```

### Subtle Hover/Press States

```swift
struct EditorialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

---

## Dark Mode Support

### Color Adaptations

```swift
extension Color {
    static var editorialBackground: Color {
        // Automatically adapts based on color scheme
        Color(uiColor: .systemBackground)
    }
    
    static var editorialForeground: Color {
        Color(uiColor: .label)
    }
}
```

### Implementation

- Use `.systemBackground` and `.label` for automatic dark mode support
- Or explicitly check `@Environment(\.colorScheme)` and switch between white/black
- Ensure signature colors maintain visibility in both modes (may need opacity adjustments)

---

## Accessibility Considerations

### Contrast Ratios

- **Hero headlines**: Ensure WCAG AA contrast (4.5:1 minimum)
- **Body text**: WCAG AA contrast required
- **Metadata**: May fall below contrast requirements—ensure it's supplementary info only
- **Live event indicators**: Must be perceivable (consider adding text label "LIVE")

### Dynamic Type Support

```swift
Text(event.title)
    .font(.system(size: 56, weight: .bold))
    .dynamicTypeSize(...dynamicTypeSize)  // Support accessibility scaling
```

### VoiceOver Labels

```swift
EditorialEventCard(event: event, isLive: true)
    .accessibilityLabel("\(event.title), happening now at \(event.address)")
    .accessibilityHint("Double tap to view event details")
```

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Create color system extension
- [ ] Create typography system extension
- [ ] Create spacing system extension
- [ ] Set up base backgrounds (white/black)

### Phase 2: Core Components
- [ ] Implement `EditorialEventCard`
- [ ] Implement `EditorialEventImage` with duotone overlay
- [ ] Implement `LiveEventHalo` animation
- [ ] Create text-based filter components
- [ ] Create minimal button components

### Phase 3: Views
- [ ] Redesign Feed View with editorial layout
- [ ] Redesign Event Detail View with hero image
- [ ] Update navigation bars (minimal styling)
- [ ] Implement live event detection and pulsing

### Phase 4: Polish
- [ ] Implement algorithmic signature color assignment
- [ ] Fine-tune animations (subtle, purposeful)
- [ ] Test dark mode support
- [ ] Verify accessibility (contrast, VoiceOver)
- [ ] Performance optimization (image loading, animation efficiency)

---

## Design Decisions

### ✅ Signature Color Assignment: Algorithmic

Signature colors are assigned algorithmically based on event properties (title, category, image analysis). This ensures each event gets a unique visual identity while maintaining consistency.

**Implementation Approach:**
```swift
extension Event {
    var signatureColor: Color {
        // Hash-based color assignment for consistency
        let colors: [Color] = [
            .signatureMustard,
            .signaturePurple,
            .signatureGreen,
            .signatureCoral,
            .signatureIndigo
        ]
        
        // Use event ID or title hash to deterministically assign color
        let hash = abs(self.id.hashValue)
        return colors[hash % colors.count]
    }
}
```

**Alternative (more sophisticated):**
- Analyze dominant colors in event image
- Match to nearest signature color
- Fallback to hash-based assignment if no image

### ✅ Image Aspect Ratios: 16:9 (Modern)

Hero images use a **16:9 aspect ratio** for a modern, contemporary feel. This works well for both photography and video content.

**Implementation:**
```swift
EditorialEventImage(...)
    .aspectRatio(16/9, contentMode: .fill)
    .frame(height: UIScreen.main.bounds.width * (9/16))  // Maintains 16:9
```

### ✅ Live Event Detection: Exact Time Window

Live events are detected using exact time window: `startTime <= now && endTime > now`. No buffer time—events are "live" only when they're actually happening.

**Implementation:**
```swift
extension Event {
    var isLive: Bool {
        let now = Date()
        return startTime <= now && (endTime ?? startTime) > now
    }
}
```

### ✅ Typography: Always System Fonts

Always use system fonts (Helvetica Neue/SF Pro) for consistency, performance, and native feel. No custom font loading required.

**Implementation:**
- All typography uses `.system()` font family
- Leverages iOS Dynamic Type automatically
- No font files or licensing concerns

---

## Event Model Extensions

Add these computed properties to the `Event` model for editorial design support:

```swift
extension Event {
    /// Algorithmically assigned signature color for this event
    var signatureColor: Color {
        let colors: [Color] = [
            .signatureMustard,
            .signaturePurple,
            .signatureGreen,
            .signatureCoral,
            .signatureIndigo
        ]
        
        // Use event ID hash for deterministic color assignment
        let hash = abs(self.id.hashValue)
        return colors[hash % colors.count]
    }
    
    /// Whether this event is currently happening (live)
    var isLive: Bool {
        let now = Date()
        return startTime <= now && (endTime ?? startTime) > now
    }
}
```

**Note:** The `signatureColor` property uses a hash-based approach for consistency—the same event will always get the same color. For more sophisticated color assignment, consider analyzing the dominant colors in the event's primary image.

---

*This design system transforms Barrio into an editorial experience while maintaining functionality and accessibility.*

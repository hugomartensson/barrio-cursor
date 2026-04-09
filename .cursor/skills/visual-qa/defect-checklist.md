# Visual QA Defect Checklist — Barrio iOS

Reference for the human reviewer and context for the AI. Organised by priority.

---

## Priority 1 — Always flag (would stop a user cold)

### Text you cannot read
- Event title, spot name, or any primary label is too small to read without zooming
- Text colour blends into the background (e.g. dark text on dark card in dark mode)
- A label is clipped mid-character at a container edge
- Debug or placeholder text visible: `nil`, `Optional(...)`, `undefined`, `Lorem ipsum`, raw UUID

### Content hidden behind hardware
- Any text or button is behind the Dynamic Island or notch at the top
- Any tappable element is hidden behind the home indicator swipe zone at the bottom
- The floating map pill (bottom-right) is clipped or sits behind the home indicator

### Broken images
- Hero image in event detail shows a grey placeholder when the event has media
- A spot image or collection cover shows a grey placeholder when it should be loaded
- Any photo is visibly stretched or squashed (wrong aspect ratio)
- A video thumbnail shows a blank black or grey rectangle with no frame

### Blank or near-blank screens
- The discover feed shows nothing — no events, no spots, no users, no collections — with no empty state message and no loading indicator
- A screen push results in a completely white or black screen with no content and no spinner
- An error occurred but no error message or retry option is shown

### Obvious layout collapse
- A card renders at near-zero height (invisible or a thin line)
- A form field is outside the visible screen area
- A sheet presentation shows only a sliver of content when it should fill the screen

---

## Priority 2 — Flag if clearly obvious

### Overflow and truncation
- Event or spot title runs outside its card boundary without truncation (missing `.lineLimit()`)
- A long address or username is cut off with no ellipsis and no indication content is missing
- Text in a filter pill or category badge is larger than the pill background

### Duplication
- The same event card appears twice consecutively in the feed
- Two save buttons are visible on the same card simultaneously
- The profile icon appears twice in the header
- A section header (EVENTS, SPOTS, USERS, COLLECTIONS) appears twice

### Dark mode failures
- A card or list row has dark text on a dark background making it unreadable
- The wordmark or a key icon is invisible against the dark background
- A filter pill or button is invisible (blends into the dark background) when it should be distinct

### Interactive elements that look broken
- The save button (bookmark icon) has no visible icon — shows empty space
- A filter pill (Location, Time, Categories) shows no label text
- The profile icon (top-right) is not visible or is partially clipped
- The map pill (bottom-right) is not visible or overlaps other content
- A form submit button is invisible or indistinguishable from the background

### Safe area issues (beyond hardware chrome)
- Content in the discover feed scrolls behind the sticky header and becomes unreadable underneath it
- The map view tiles render behind the navigation bar, obscuring the close/back control
- The create event or create spot form has a submit button unreachable because it is scrolled behind the keyboard

---

## Priority 3 — Flag only if clearly broken (not just imperfect)

### Spacing
- Card padding is so small that text or images touch the card edge
- Section headers (EVENTS, SPOTS, etc.) have no visible breathing room above them, colliding with cards from the previous section
- Cards in the feed have wildly inconsistent vertical gaps (some touching, others with large empty space)

### Alignment
- Event metadata (date icon + text, location icon + text) icons and labels are clearly on different baselines
- The section header label and "See more (N)" button are at very different vertical positions within the same header row
- A card's save button (top-right overlay) is clearly not in the corner — centred or on the wrong side

### Icons
- A category icon (SF Symbol: fork.knife, wineglass, music.note, etc.) fails to render and shows a question mark or blank space
- Icons within the same toolbar or row are at noticeably different sizes

### Images (secondary)
- The hero image in event detail has visible grey margins on the sides when it should fill the full width
- A profile avatar shows a default silhouette even though the user has a profile picture loaded

---

## Screen-specific things to check

### Discover feed
- [ ] Wordmark visible top-left
- [ ] Location, Time, Categories pills all visible and labelled
- [ ] Profile icon visible top-right
- [ ] At least the EVENTS or SPOTS section renders with content (if data is present)
- [ ] Section headers (EVENTS, SPOTS, USERS, COLLECTIONS) readable
- [ ] "See more (N)" / "See less" controls visible on expandable sections
- [ ] Floating map pill visible bottom-right (not clipped, not overlapping content)
- [ ] Empty state shows a message if all sections have no content

### Event detail
- [ ] Hero media fills full width (no grey side margins)
- [ ] Event title readable (2-line max with ellipsis if long)
- [ ] Organiser name and date/time readable
- [ ] Address readable
- [ ] Save button visible and not overlapping title

### Map view
- [ ] Map tiles load (no blank grey tiles)
- [ ] Event pins visible on the map
- [ ] Close/back control not hidden behind Dynamic Island

### Auth screens (Login / Signup)
- [ ] Email and password fields visible and labelled
- [ ] Submit button visible and readable
- [ ] No content hidden behind keyboard when form is active

### Profile sheet
- [ ] Avatar or placeholder shows correctly (not clipped)
- [ ] Display name readable
- [ ] Follow/Unfollow button (on other user profiles) visible and distinct

### Create Event / Create Spot
- [ ] All form fields visible and labelled
- [ ] Media preview (if captured) not tiny or blank
- [ ] Submit button reachable (not hidden behind keyboard)

# BARRIO - Product Requirements Document (PRD)
## TestFlight Release Version

**Document Version:** 1.1  
**Last Updated:** January 18, 2026  
**Status:** Ready for Development  
**Target Release:** TestFlight Beta (Friends & Family)

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Product Vision & Goals](#product-vision--goals)
3. [Problem Statements](#problem-statements)
4. [User Personas](#user-personas)
5. [Core User Flows](#core-user-flows)
6. [Feature Specifications](#feature-specifications)
7. [Technical Architecture](#technical-architecture)
8. [Design Requirements](#design-requirements)
9. [Out of Scope](#out-of-scope)

---

## Executive Summary

Barrio is a hyperlocal events discovery and planning application that solves the fragmentation problem of finding local experiences. The app enables users to discover curated events from trusted sources (friends, local influencers, venues) within their area, and easily plan activities by organizing events into shareable plans.

**Core Value Propositions:**
- **For Users:** "See everything happening around you from sources you trust, and effortlessly plan your time"
- **For Event Creators:** "Reach people in your neighborhood who are actively looking for things to do"

**TestFlight Scope:** This PRD defines the feature set for our initial TestFlight release with friends and family, focusing on core discovery, social curation, and planning functionality.

---

## Product Vision & Goals

### Product Vision
Create the definitive platform where locals discover and plan experiences in their city through trusted curation, making it effortless to answer "What should I do this weekend?"

### Product Philosophy
1. **Planning over browsing:** Success = plans made, not time spent in app
2. **Geographic discovery:** Map-first experience creates emotional connection to local buzz
3. **Social curation:** Follow trusted sources (friends, influencers) for quality signals
4. **Simplicity:** Focused feature set that does one thing exceptionally well

### TestFlight Goals
1. **Validate core hypothesis:** Do users find this useful for weekend planning?
2. **Test social mechanics:** Does following friends/influencers improve curation?
3. **Gather feedback:** What's missing? What's confusing? What delights?
4. **Stress test:** Performance with real-world usage patterns
5. **Iterate rapidly:** Ship updates based on user feedback weekly

---

## Problem Statements

### Consumer Problem (User Perspective)

**Problem Statement:**  
*"When I want to know what's going on in my city, I don't have all the info at hand and I'm missing out on stuff."*

**Current Pain Points:**
- Information is scattered across 5+ sources (Instagram, newsletters, flyers, TikTok, etc.)
- Social media algorithms bury local content with global brand noise
- Can't filter for local-only or time-relevant content
- Photos of flyers aren't searchable
- Even places I follow don't reliably reach me with event updates
- No single place to see curated overview for planning

**What Success Looks Like:**
User can sit down Thursday evening, see a curated overview of everything happening this weekend from sources they trust, and confidently make plans knowing they're not missing the good stuff.

### Business Problem (Event Creator Perspective)

**Problem Statement:**  
*"It's extremely hard to reach people in our neighborhood who are actively looking for things to do."*

**Current Pain Points:**
- Can't target hyperlocal audience (within walking distance)
- Compete with global brands on same algorithmic feed
- Even followers don't see posts reliably
- No platform where locals browse for discovery
- Event platforms (Eventbrite) are too broad and not curated
- Google requires active search, not passive discovery

**What Success Looks Like:**
When a restaurant has a special event this weekend, people in the neighborhood who follow them (or follow local food bloggers who share it) see it while planning their weekend.

---

## User Personas

### Primary Persona: "Hugo the Local Explorer"
**Age:** 28  
**Location:** Barcelona, Gràcia neighborhood  
**Occupation:** Product Manager  

**Behaviors:**
- Active social life, plans 2-3 activities per weekend
- Follows local food bloggers and music venues on Instagram
- Frustrated by missing cool events he hears about after they happen
- Values local, unique experiences over tourist attractions
- Plans activities 2-7 days in advance
- Uses phone for everything (no desktop workflow)

**Goals:**
- Discover events from trusted sources (friends, influencers, venues he knows)
- Easily plan weekend with spatial context (what's near what)
- Share plans with friends for coordination
- Feel confident he's not missing out on the "good stuff"

**Quote:** *"I follow all these cool accounts but their posts get buried. I need a place that just shows me what's happening this weekend from sources I trust."*

### Secondary Persona: "Maria the Event Creator"
**Age:** 32  
**Location:** Barcelona, Born neighborhood  
**Occupation:** Gallery owner  

**Behaviors:**
- Hosts weekly events (art openings, DJ nights, workshops)
- Posts on Instagram but reach is declining
- Wants to attract neighborhood locals, not just tourists
- Limited marketing budget
- Already comfortable sharing platform with nearby businesses

**Goals:**
- Reach people within walking distance who are looking for things to do
- Build regular community, not one-time visitors
- Get discovered by people who don't know about the gallery yet
- Compete on equal footing (not against global brand budgets)

**Quote:** *"I have something special happening this Friday but the people in my neighborhood won't see it unless they happen to check Instagram at the right time."*

### Tertiary Persona: "Sofia the Trip Planner"
**Age:** 26  
**Location:** Madrid (visiting Barcelona next month)  
**Occupation:** Marketing Manager  

**Behaviors:**
- Plans trips 2-4 weeks in advance
- Researches local experiences, not tourist traps
- Wants insider recommendations
- Creates detailed itineraries
- Travels solo or with partner

**Goals:**
- Discover what's happening in Barcelona during her visit dates
- Get curated recommendations from locals
- Plan spatial routes (brunch → gallery → dinner)
- Have backup options if plans change

**Quote:** *"When I visit a new city, I want to see it like a local, but I have no idea what's actually happening there."*

---

## Core User Flows

### Flow 1: Weekend Planning (Primary Use Case)

**Context:** Thursday evening, Hugo wants to plan his weekend

**Steps:**
1. Opens Barrio → sees Map view centered on his location
2. Sees pulsating pins for ongoing events, static pins for upcoming events
3. Taps time filter → selects "This Week"
4. Sees events Friday-Sunday from everyone in his area
5. Taps "Following" filter → narrows to events from people/venues he follows
6. Sees interesting DJ event Saturday night
7. Taps pin → Story-style viewer opens full-screen
8. Swipes through media (photos/videos of the venue)
9. Swipes up → Event details sheet appears
10. Taps "Add to Plan" → Selects "This Weekend" plan
11. Returns to map, discovers tapas special near the DJ venue
12. Adds tapas to same plan
13. Shares "This Weekend" plan with friend via message

**Success Criteria:**
- User completes flow in under 3 minutes
- Creates plan with 2+ events
- Feels confident about weekend plans

### Flow 2: Spontaneous Discovery (Secondary Use Case)

**Context:** Saturday afternoon, Hugo is bored at home

**Steps:**
1. Opens Barrio → sees Map view
2. Taps time filter → "Right Now"
3. Sees 3 ongoing events within walking distance
4. Taps nearest pin (flea market)
5. Views photos/videos in story format
6. Swipes up for details
7. Sees "Free" badge, "Public" indicator
8. Taps location pin → sees on full map with distance
9. Taps "Interested" → event saved for later reference
10. Closes app, decides to walk over

**Success Criteria:**
- Discovers event and decides to go within 2 minutes
- Low friction from discovery to action
- Clear information about logistics (free, public, distance)

### Flow 3: Creating an Event

**Context:** Maria wants to promote her Friday gallery opening

**Steps:**
1. Opens Barrio → Map view
2. Taps "+" button → Create Event screen
3. Taps "Add Media" → selects 3 photos from camera roll
4. Drags to reorder photos
5. Sees upload progress indicator (photos uploading)
6. Enters event title: "Opening Night: New Photography Exhibition"
7. Enters description with details
8. Selects category: "Arts & Culture"
9. Sets start time: Friday 7:00 PM (5-minute increments)
10. Sets end time: Friday 11:00 PM
11. Taps "Set Location" → map interface appears
12. Searches "Born Cultural Center" → map centers on result
13. Fine-tunes by dragging pin
14. Sees address preview: "Carrer del Comerç, 36"
15. Taps "Confirm Location"
16. Toggles "Free Event" → ON
17. Toggles "Public" → ON
18. Taps "Create Event"
19. Event appears on map and in feed

**Success Criteria:**
- Event created in under 4 minutes
- Media upload progress visible
- Location accurately set
- Event immediately discoverable by nearby users

### Flow 4: Following & Curation

**Context:** Hugo discovers a food blogger posts great restaurant events

**Steps:**
1. Hugo viewing event from unknown creator
2. Taps creator's name/avatar
3. Profile sheet slides up showing:
   - Name, follower count
   - Past events created
   - "Follow" button
4. Taps "Follow"
5. Button changes to "Following"
6. Returns to map
7. Toggles "Following" filter
8. Now sees all events from people he follows
9. Discovers 3 new restaurants he didn't know about

**Success Criteria:**
- Easy to discover and follow quality creators
- Following immediately affects content curation
- Clear value from following (better event quality)

### Flow 5: Managing Plans

**Context:** Hugo managing his "Bachelor Party" plan as date approaches

**Steps:**
1. Opens Barrio → taps Profile tab
2. Sees section "My Plans" with 3 active plans
3. Taps "Bachelor Party" plan
4. Sees list of 5 events added (restaurant, bar crawl, club, brunch)
5. Events shown in suggested chronological order
6. Taps on event → views full details
7. Decides to remove brunch (people will be tired)
8. Swipes left on brunch event → "Remove"
9. Taps "Share Plan" → shares via message to group chat
10. After bachelor party weekend, plan automatically archives

**Success Criteria:**
- Plans are easy to manage and edit
- Chronological ordering makes sense
- Sharing is frictionless
- Auto-archiving keeps interface clean

---

## Feature Specifications

### 1. AUTHENTICATION

**Current State:** Email/password auth working

**New Requirements:**
- No changes for TestFlight
- Keep existing email/password system
- Defer social login (Google, Apple) to post-TestFlight

**Acceptance Criteria:**
- Users can sign up with email/password
- Users can log in
- Sessions persist securely
- Token refresh works automatically

---

### 2. MAP VIEW (PRIMARY SCREEN)

**Map Provider Decision: Google Maps vs Apple Maps**

**Current:** Apple Maps (MapKit)

**Considerations for Google Maps:**

**Pros of Google Maps:**
- More comprehensive global data (especially outside US/Western Europe)
- Better geocoding accuracy
- More detailed location information
- Better search functionality
- Superior place data (reviews, hours, photos)
- Cross-platform consistency (if Android app in future)
- More familiar to users globally
- Better public transit integration

**Pros of Apple Maps (Current):**
- Native iOS integration (better performance)
- No API costs for basic usage
- Seamless with iOS location services
- Lighter weight SDK
- Better privacy defaults
- Simpler implementation (fewer API keys to manage)
- Apple Design Language consistency

**Recommendation:** For TestFlight, **stay with Apple Maps** (MapKit) for speed and simplicity. The app is iOS-only, and most testing will be in urban areas where Apple Maps coverage is good. Google Maps can be evaluated post-TestFlight if geocoding accuracy becomes an issue or if Android development begins.

**Implementation Note:** Design the map abstraction layer to make switching providers easier in the future if needed.

---

#### 2.1 Map Interface

**Requirements:**

**Default State:**
- Opens centered on user's current GPS location
- 5km radius circle visible (subtle, not intrusive)
- Event pins immediately visible
- Smooth 60 FPS performance

**Pin Visualization:**
- **Ongoing events:** Pulsating animation, thumbnail of first media item shown in pin
- **Upcoming events:** Static pin, thumbnail of first media item
- **Pin design:** Small Instagram story-style circle with media preview
- **Color coding:** Category-based accent color on pin border
- **Tap interaction:** Opens full-screen story viewer

**Location Handling:**
- User can pan/zoom freely
- When map moves >500m from center, show "Search this area" button
- Tapping button loads events for new map center
- "Current location" button to return to GPS position
- Events automatically reload when searching new area

**Performance:**
- Debounced loading (3 second delay after map stops moving)
- Distance throttling (15m minimum movement to trigger reload)
- Time throttling (8s minimum between loads)
- Smooth pin animations
- Non-blocking error states

**Acceptance Criteria:**
- Map loads in <1 second
- Pins update smoothly when filtering
- Pulsating animation is smooth (60 FPS)
- Clear visual distinction between ongoing and upcoming events
- Pins show media thumbnail preview
- User can easily pan to explore different neighborhoods

#### 2.2 Filters & Controls

**Time Filters:**
- **Right Now:** Only events currently happening (start time < now < end time)
- **Today:** Events starting or ongoing today
- **This Week:** Events within next 7 days
- **Custom:** Date range picker

**Category Filters:**
- Multi-select chips for 6 categories:
  1. Food & Drink
  2. Arts & Culture
  3. Music
  4. Nightlife
  5. Sports & Outdoors
  6. Community
- "All" option to clear filters

**Social Filters:**
- **Toggle: "Following Only"** - Shows only events from people user follows
- Default: OFF (shows all events)
- Visual indicator when filter is active

**Location Override:**
- Search bar at top: "Search location"
- User can type city name or address
- Map centers on searched location
- Shows events in that area
- "Current Location" button to return to GPS

**Filter UI Design:**
- Horizontal scrolling filter chips below search bar
- Active filters highlighted
- Number badges showing result count
- Clear all filters button when multiple active

**Acceptance Criteria:**
- Filters apply instantly (<200ms)
- Multiple filters work together (AND logic)
- Clear visual feedback on active filters
- Easy to clear filters
- Filter state persists during session

#### 2.3 Story-Style Pin Interaction

**Tap Pin → Story Viewer:**

**Full-Screen Story Viewer:**
- Black background
- Media fills screen (photos/videos)
- Media is swipeable horizontally (manual swipe only - no auto-advance for TestFlight)
- Top: Progress bars (one per media item) - visual indicators only, no auto-advance
- Top corners: Close button (X), creator info
- Videos auto-play
- Tap left/right of screen to navigate media

**Swipe Up → Event Details:**
- Sheet slides up from bottom
- Contains all event information (see Event Viewer section)
- Can be dismissed by swiping down

**Acceptance Criteria:**
- Smooth transition from pin tap to full-screen
- Media loads quickly
- Video auto-plays
- Swipe gestures are responsive
- Easy to exit back to map

---

### 3. FEED VIEW (SECONDARY SCREEN)

**Philosophy:** Alternative way to browse events in list format, useful for comparing options

#### 3.1 Feed Interface

**Default State:**
- List of events sorted by start time (soonest first)
- Shows events within 5km of current location
- Same 5km radius as map

**Location Header:**
- Top of feed shows: "Events near [City/Neighborhood]"
- Tappable to open location search
- Shows user's current search location

**Event Cards:**
- Thumbnail (first media item)
- Event title
- Creator name (tappable → profile)
- Category badge
- Date/time (formatted: "Today 8:00 PM", "Sat 7:00 PM", etc.)
- Distance from user ("250m", "2.5km")
- "Interested" button (heart icon) - shows if already marked
- "Add to Plan" button (plus icon)

**Scrolling Behavior:**
- Lazy loading (LazyVStack)
- Pull-to-refresh
- Infinite scroll (load more as scrolling down)

**Empty States:**
- "No events found" when filters are too restrictive
- Suggestion to adjust filters or check back later

**Acceptance Criteria:**
- Feed loads in <1 second
- Smooth scrolling (60 FPS)
- Cards are visually scannable
- Easy to tap through to event details
- Location is always clear

#### 3.2 Feed Filters

**Same filters as Map View:**
- Time filters (Right Now / Today / This Week / Custom)
- Category filters (multi-select)
- Following filter (toggle)

**Additional Feed-Specific Features:**
- Sort options: "Soonest" (default), "Distance", "Popular" (most interested)

**Acceptance Criteria:**
- Filters match map behavior
- Sort options work correctly
- Filter state syncs between Map and Feed views

---

### 4. EVENT CREATION

**Philosophy:** Should be quick and delightful to create events, prioritizing media and location accuracy. Location is stored as a human-readable address, not just coordinates.

#### 4.1 Create Event Flow

**Entry Points:**
- "+" button in Feed view
- Tap and hold anywhere on Map view

**Step 1: Add Media (Required)**

**Requirements:**
- User MUST add at least 1 media item (photo or video)
- Maximum 3 media items
- Mixed media allowed (photos + videos)
- Photo support: JPEG, PNG, HEIC
- Video support: .mov, .mp4
- Video max duration: 15 seconds
- Video max size: 50 MB

**Media Selection UI:**
- Grid view of user's photo library
- **Live camera capture** (take photo/video directly in app)
- Multi-select (up to 3)
- Preview selected items
- Drag to reorder after selection
- Remove button on each item
- **Text overlay tool** (Instagram-style, basic features):
  - Add text to photos/videos
  - Multiple text color options
  - Font size adjustment
  - Position text anywhere on media
  - Note: Basic features only for TestFlight (no advanced styling, shadows, or multiple text layers)

**Upload Handling:**
- Progress indicator for each item
- Upload to Supabase Storage directly (signed URLs)
- Compressed photos (max 500KB each)
- Video thumbnail auto-generated
- Cancel upload option
- Error handling with retry

**Acceptance Criteria:**
- Cannot proceed without at least 1 media item
- Upload progress is visible
- Large videos show clear progress
- User can reorder media
- Errors are clear and actionable

**Step 2: Event Details**

**Required Fields:**
- Title (max 200 characters)
- Description (max 2000 characters)
- Category (select from 6 options)
- Start time (date + time)
- End time (date + time)
- Location (address)

**Optional Fields:**
- Free vs Paid toggle

**Time Selection:**
- Date picker for day
- Time picker with 5-minute increments (not every minute)
- Default start time: next whole hour from now
- End time defaults to 3 hours after start

**Validation:**
- All required fields must be filled
- Start time must be in the future
- End time must be after start time
- Title and description must not be empty

**Acceptance Criteria:**
- Form is intuitive and clear
- Validation happens on submit
- Error messages are specific
- User doesn't lose progress if they navigate away (auto-save draft)

**Step 3: Set Location**

**Requirements:**
- Location is required
- Multiple ways to set location:
  1. Search address/place name
  2. Drop pin on map
  3. Use current GPS location

**Location Search:**
- Search bar at top: "Search for a location"
- Autocomplete suggestions as user types
- Powered by Apple Maps geocoding
- Tapping result centers map and places pin

**Map Pin Interface:**
- Interactive map showing area
- Draggable pin (user can fine-tune)
- **Address preview shown below map** - this is what gets saved
- Address updates in real-time as pin moves (reverse geocoding)
- Coordinates (lat/lng) are derived from address for map display
- "Confirm Location" button

**Location Storage:**
- **Primary field:** Address string (e.g., "Carrer del Comerç, 36, 08003 Barcelona")
- **Derived fields:** Latitude and longitude (for map positioning and radius queries)
- Address is always reverse-geocoded from pin position (whether user searches, drops pin, or uses GPS)
- Address updates in real-time as pin moves via reverse geocoding
- Address is human-readable and can be displayed to users
- Coordinates enable geospatial queries via PostGIS

**Favorites (Future Enhancement):**
- Not in TestFlight scope
- But design with favorites in mind

**Acceptance Criteria:**
- Search returns relevant results
- Pin is draggable and responsive
- Address preview is accurate
- Map defaults to user's current location
- Easy to set precise location

**Step 4: Review & Create**

**Review Screen:**
- Shows all entered information
- Media carousel preview
- Edit buttons for each section
- "Create Event" primary button

**On Create:**
- Loading state while processing
- Success message
- Navigate to event detail view
- Event immediately visible on map

**Draft Handling:**
- Auto-save draft if user navigates away
- "Resume Draft" option next time
- Drafts persist until explicitly deleted or event is created

**Acceptance Criteria:**
- Review is comprehensive
- Easy to edit any field
- Loading states are clear
- Success feedback is satisfying
- Event is immediately discoverable

#### 4.2 Edit Event

**Requirements:**
- Users can edit their own events
- Can edit: Title, description, category, media, times, location, free/paid

**Edit Entry Point:**
- Three-dot menu on event detail view (own events only)
- "Edit Event" option

**Edit Flow:**
- Same form as creation
- Pre-populated with existing data
- Can add/remove/reorder media
- Save changes

**Edit Permissions:**
- Users can edit future events (startTime > NOW())
- Users can edit ongoing events (startTime <= NOW() < endTime)
- Users cannot edit past events (endTime < NOW())
- This prevents confusion and maintains event integrity

**Acceptance Criteria:**
- Only creator can edit
- Only future and ongoing events can be edited
- Changes save successfully
- Updated event reflects changes immediately
- Edit history not visible (no audit trail in TestFlight)

#### 4.3 Delete Event

**Requirements:**
- Users can delete their own events
- Confirmation dialog required
- Cascade delete (removes interested, media)

**Delete Entry Point:**
- Three-dot menu on event detail view (own events only)
- "Delete Event" option in red

**Confirmation:**
- Alert dialog: "Are you sure you want to delete this event? This cannot be undone."
- "Cancel" and "Delete" buttons

**Acceptance Criteria:**
- Only creator can delete
- Confirmation prevents accidents
- Event removed from map/feed immediately
- No orphaned data

---

### 5. EVENT VIEWER (DETAIL VIEW)

**Philosophy:** Rich, immersive detail view that helps user decide if they want to attend

#### 5.1 Story-Style Media Display

**Requirements:**
- Full-screen media carousel
- Swipeable between media items (horizontal)
- Photos display full-screen
- Videos auto-play with sound
- Progress indicators at top (one bar per media item)

**Video Controls:**
- Tap to pause/play
- Volume control
- Replay button when finished

**Acceptance Criteria:**
- Smooth swiping between media
- Videos load and play quickly
- Progress bars are intuitive
- No awkward black bars or cropping

#### 5.2 Event Information

**Displayed Information:**

**Primary Info:**
- Event title (large, bold)
- Creator name + avatar (tappable → profile)
- Category badge with icon
- Date and time (formatted clearly)
- Location address (tappable → map view)
- Distance from user

**Secondary Info:**
- Description (full text, expandable if long)
- Free vs Paid indicator
- Number of people interested (count)

**Location Features:**
- Tappable location pin icon
- Opens mini map view showing event location
- "Get Directions" button (opens Apple Maps)

**Acceptance Criteria:**
- All information is clear and scannable
- Location is easy to find on map
- Directions link works
- Creator profile is easily accessible

#### 5.3 Interaction Buttons

**Primary Actions:**

**"Interested" Button:**
- Heart icon
- Single tap to toggle interested/not interested
- If marking interested for first time, optionally prompts: "Add to a plan?"
- If yes → shows plan selector sheet
- If no → just marks as interested
- Saved to "Interested" list in profile
- Visual state shows if already marked interested (filled heart vs outline)
- Shows count of total interested users on event

**"Add to Plan" Button:**
- Plus icon with "Add to Plan" label
- Tap opens plan selector:
  - List of user's active plans
  - "Create new plan" option
  - Each plan shows event count
- Selecting plan adds event
- Visual feedback on success
- If event already in a plan, shows checkmark and plan name

**"Share" Button:**
- Standard iOS share sheet
- For TestFlight: Shares event details in text format (name, time, location, description)
- Deep links and web preview deferred to post-TestFlight

**Acceptance Criteria:**
- Buttons are obvious and well-labeled
- Actions complete successfully
- Visual feedback is immediate
- Share functionality works
- Interested count updates in real-time
- Clear indication when event is already in a plan

#### 5.4 Creator Profile Link

**Requirements:**
- Tapping creator name/avatar opens profile sheet
- Sheet slides up from bottom (modal)

**Profile Sheet Contents:**
- Creator name
- Follower count / Following count
- "Follow" / "Following" button
- Grid of past events created
- Tapping event → navigates to that event

**Follow Button Behavior:**
- If not following → "Follow" button (blue)
- If following → "Following" button (gray)
- Tap to toggle
- Confirmation haptic feedback

**Acceptance Criteria:**
- Profile loads quickly
- Past events are visible
- Follow button works
- Easy to dismiss sheet

---

### 6. SOCIAL FEATURES (NEW)

**Philosophy:** Single user type - everyone can create and follow. No business accounts. Social graph enables curation, not social obligation.

#### 6.1 Following System & Account Privacy

**Account Types:**

**Public Accounts (Default):**
- Anyone can follow without approval
- Events visible to all users
- Profile visible to all users
- Follower/following lists visible to all

**Private Accounts:**
- Follow requests require approval
- Events only visible to followers
- Profile visible but events hidden from non-followers
- Follower/following lists only visible to followers

**Privacy Toggle:**
- Users can switch between public/private in settings
- Default: Public
- Changing to private doesn't remove existing followers
- Changing to public auto-approves pending follow requests

**Requirements:**

**Follow Actions:**
- **Public accounts:** Follow button → instantly following
- **Private accounts:** Follow button → "Requested" state → awaits approval
- No mutual relationship required (Twitter-style, not Facebook-style)
- Follow button on user profiles
- Self-follow prevention: Users cannot follow themselves (validation: followerId !== followingId)

**Follow Requests (Private Accounts Only):**
- Follow request notifications appear in-app (no push notifications for TestFlight)
- Owner discovers requests when viewing their profile (pending requests count/badge)
- Owner can approve or deny from profile
- Pending requests shown in separate list in profile
- Requestor sees "Requested" state on follow button

**Following/Followers:**
- Each user has:
  - Following count (people they follow)
  - Follower count (people following them)
- Tapping counts → shows list of users (if allowed by privacy)
- List shows: Avatar, Name, Follower count, Follow button

**Discovery:**
- Discover users through:
  - Events they create (public accounts or accounts you follow)
  - **Same events attended:** See public users and followed users who marked "Interested" in same event
  - Popular creators (algorithm suggests based on followers)
  - Search (future)

**Event Attendee Visibility:**
- Event detail view shows list of users who marked "Interested"
- Always visible: Public accounts
- Always visible: Accounts you follow
- Hidden: Private accounts you don't follow

**Notifications:**
- Push notifications not in TestFlight scope
- In-app notifications: Follow requests appear as badge/count in profile (user discovers when checking profile)
- Design with push notifications in mind for post-TestFlight (follow requests, new followers, etc.)

**Acceptance Criteria:**
- Follow/unfollow works instantly
- Counts update correctly
- Following list is accurate
- No bugs with mutual follows

#### 6.2 Following Filter

**Requirements:**

**Filter Behavior:**
- Toggle in Map and Feed views: "Following Only"
- Default: OFF (shows all events)
- When ON: Shows only events created by people user follows
- Visual indicator when active
- Filter state persists during session

**Use Cases:**
- User wants curated view from trusted sources
- User wants to support friends' events
- User wants to filter out noise

**Acceptance Criteria:**
- Filter works on both Map and Feed
- Results update immediately
- Clear visual feedback
- Easy to toggle on/off

#### 6.3 User Profiles

**Profile Sections:**

**Header:**
- Avatar (colored circle with initial if no photo)
- Name
- Follower count
- Following count
- "Follow" / "Requested" / "Following" button (if viewing someone else)
- "Edit Profile" button (if viewing own profile)
- Privacy indicator (public/private badge)

**Interested Events:** (Own profile only, shown first)
- List of events marked as interested
- Can remove from list
- Can add to plan from here

**My Plans:** (Own profile only)
- List of active plans
- Shows plan name and event count
- Tapping plan → plan detail view

**My Events:**
- Grid/list of events created by this user
- Sorted by newest first
- Shows upcoming and past events
- Tapping event → event detail view
- Note: On private accounts, only visible to followers

**Acceptance Criteria:**
- Profile loads quickly
- Counts are accurate
- Events display correctly
- Own vs other profiles have appropriate features

#### 6.4 Profile Editing

**Editable Fields:**
- Name
- Profile photo (future - not in TestFlight)

**Edit Flow:**
- Tap "Edit Profile"
- Form with name field
- Save button
- Changes reflect immediately

**Acceptance Criteria:**
- Name updates successfully
- Changes visible across app
- Validation prevents empty name

---

### 7. PLANS FEATURE (NEW)

**Philosophy:** Plans help users organize events by purpose/occasion. Planning is the end goal - discovery is the means.

#### 7.1 Plan Creation

**Requirements:**

**Creating a Plan:**
- User can create multiple named plans
- Plan requires: Name (e.g., "Bachelor Party", "Date Night", "Mom's Visit")
- Optional: Description, dates
- Limit: 5 active plans per user (to keep focused)
- If user tries to create 6th plan: Show friendly message: "Maximum 5 active plans. Please archive a plan to create a new one."

**Entry Points:**
- When adding event to plan → "Create new plan" option
- From Profile → "Create Plan" button
- When marking event "Interested" → optionally create plan

**Plan Properties:**
- Name (required, max 50 chars)
- Created date
- Events list (order by start time)
- Auto-archive when all events have passed

**Acceptance Criteria:**
- Creating plan is quick (under 30 seconds)
- Name is editable later
- Plan appears in profile immediately
- Limit enforced with clear message

#### 7.2 Adding Events to Plans

**Requirements:**

**Add to Plan Flow:**
1. User taps "Add to Plan" on event
2. Sheet slides up showing:
   - List of user's active plans
   - Each plan shows: Name, event count, dates
   - "Create new plan" option at top
3. User selects plan
4. Event added to plan
5. Success feedback

**Multiple Plans:**
- Same event can be in multiple plans
- Visual indicator if event already in a plan

**Acceptance Criteria:**
- Adding event is 2 taps
- Plan selector is clear
- Success feedback is satisfying
- Events appear in plan immediately

#### 7.3 Viewing & Managing Plans

**Plan Detail View:**

**Contents:**
- Plan name (editable)
- List of events in plan
- Events sorted by start time (suggested order)
- Each event shows: Thumbnail, title, time, location
- Swipe to remove from plan
- "Share Plan" button at top

**Interaction:**
- Tap event → event detail view
- Swipe left on event → "Remove" button
- Tap plan name → edit name
- Long-press event → drag to reorder (nice-to-have)

**Empty State:**
- "No events in this plan yet"
- Suggestion to explore map/feed

**Acceptance Criteria:**
- Events are clearly listed
- Easy to remove events
- Chronological order makes sense
- Share functionality works

#### 7.4 Plan Sharing

**Requirements:**

**Share Flow:**
- Tap "Share Plan" button
- iOS share sheet opens
- Share options:
  - Message
  - Email
  - Copy link
  - Other apps

**Shared Plan Format:**
- Text format with event list
- Includes: Plan name, each event (name, time, location)
- Link to open plan in Barrio (deep link)

**Recipient Experience:**
- For TestFlight: Text format only (no deep links or web preview)
- Shared text includes: Plan name, each event (name, time, location)
- Deep links and web preview deferred to post-TestFlight

**Acceptance Criteria:**
- Share sheet opens correctly
- Text format is readable
- Links work for app users
- Non-users see useful information

#### 7.5 Plan Archiving

**Requirements:**

**Auto-Archive Logic:**
- Plan is archived when:
  - All events in plan have passed (end time < now)
  - OR plan has no events and is 7+ days old
- Archived plans move to "Archived Plans" section
- Archive happens automatically (same daily background job as expired events cleanup)

**Manual Archive:**
- User can manually archive a plan
- "Archive Plan" option in plan menu
- Confirmation dialog

**Viewing Archives:**
- "Archived Plans" section in profile
- Read-only view
- Can delete archived plans
- Cannot unarchive (this is not undo)

**Acceptance Criteria:**
- Auto-archive happens correctly
- Manual archive works
- Archived plans are accessible
- Clear distinction from active plans

---

### 8. NAVIGATION & UI STRUCTURE

**App Structure:**

**Tab Bar (Bottom):**
1. **Map** (default) - SF Symbol: map
2. **Feed** - SF Symbol: list.bullet
3. **Profile** - SF Symbol: person.circle

**Create Event Access:**
- "+" button in Feed view (top-right)
- Tap and hold anywhere on Map view

**Acceptance Criteria:**
- Tab bar always visible
- Active tab is highlighted
- Smooth transitions between tabs
- Tap-and-hold gesture is discoverable

**Navigation Patterns:**
- Map/Feed → Event Detail: Push navigation
- Event Detail → Creator Profile: Modal sheet
- Create Event: Modal full-screen
- Plans: Push navigation from Profile

---

### 9. PERFORMANCE REQUIREMENTS

**Load Times:**
- App launch: < 2 seconds
- Map initial load: < 1 second
- Event feed load: < 1 second
- Event detail view: < 500ms
- Media upload: Progress indicator for anything > 2 seconds

**Responsiveness:**
- All tap interactions: < 100ms response
- Filter application: < 200ms
- Smooth scrolling: 60 FPS minimum
- No janky animations

**Media Handling:**
- Image compression: Max 500KB per photo
- Video size limit: 50 MB
- Video duration: Max 15 seconds
- Thumbnail generation: < 2 seconds

**Network Efficiency:**
- Debounced API calls (map movement)
- Cached images
- Failed uploads can be retried
- Graceful offline handling

**Acceptance Criteria:**
- No janky animations
- Smooth map panning
- Fast event loading
- Media uploads show clear progress

---

### 10. ERROR HANDLING & EDGE CASES

**Network Errors:**
- Show non-intrusive banner
- Auto-retry with exponential backoff
- Offline mode: Show cached content with indicator
- Failed uploads: Save draft, allow retry

**Empty States:**
- No events found: Clear message with filter suggestions
- No followers: Suggestion to follow people
- No plans: Encouragement to create first plan
- No events created: Prompt to create first event

**Permission Errors:**
- Location denied: Explain need, link to settings
- Photo library denied: Explain need, link to settings
- Camera denied: Explain need, link to settings

**Validation Errors:**
- Clear, specific error messages
- Highlight problematic fields
- Prevent submission until fixed

**Server Errors:**
- Generic: "Something went wrong. Please try again."
- Specific: Show API error message if helpful
- Always allow retry

**Acceptance Criteria:**
- No silent failures
- Errors are actionable
- User is never stuck
- Recovery is clear

---

## Technical Architecture

### Platform & Stack

**iOS Application:**
- Language: Swift 5.9+
- Framework: SwiftUI (iOS 17+)
- Target Devices: iPhone only
- Orientation: Portrait only
- Deployment: TestFlight → App Store

**Backend:**
- Runtime: Node.js 18+
- Language: TypeScript 5.3+
- Framework: Express.js
- Database: PostgreSQL (Supabase)
- Storage: Supabase Storage
- Auth: Supabase Auth

**Infrastructure:**
- Backend hosting: Railway / Render / Fly.io
- Database: Supabase (managed PostgreSQL + PostGIS)
- Storage: Supabase Storage
- CDN: Supabase CDN for media

### Data Models

**User:**
```typescript
{
  id: UUID
  email: string
  name: string
  isPrivate: boolean (default: false)
  createdAt: timestamp
  followerCount: integer
  followingCount: integer
}
```

**Event:**
```typescript
{
  id: UUID
  userId: UUID (creator)
  title: string (max 200)
  description: string (max 2000)
  category: enum (6 options)
  startTime: timestamp
  endTime: timestamp | null
  address: string (PRIMARY - human-readable location)
  latitude: float (derived from address)
  longitude: float (derived from address)
  location: geography (PostGIS - for geospatial queries)
  isFree: boolean
  interestedCount: integer
  createdAt: timestamp
  updatedAt: timestamp
}
```

**MediaItem:**
```typescript
{
  id: UUID
  eventId: UUID
  url: string (Supabase Storage URL)
  type: enum (photo, video)
  order: integer (0-2)
  thumbnailUrl: string | null (for videos)
}
```

**Follow:**
```typescript
{
  followerId: UUID (person doing the following)
  followingId: UUID (person being followed)
  createdAt: timestamp
  
  composite primary key: (followerId, followingId)
}
```

**FollowRequest:**
```typescript
{
  requesterId: UUID (person requesting to follow)
  targetId: UUID (private account being requested)
  status: enum (pending, approved, denied)
  createdAt: timestamp
  updatedAt: timestamp
  
  composite primary key: (requesterId, targetId)
}
```

**Interested:**
```typescript
{
  userId: UUID
  eventId: UUID
  createdAt: timestamp
  
  composite primary key: (userId, eventId)
}
```

**Plan:**
```typescript
{
  id: UUID
  userId: UUID
  name: string (max 50)
  description: string | null
  isArchived: boolean
  createdAt: timestamp
}
```

**PlanEvent:**
```typescript
{
  planId: UUID
  eventId: UUID
  addedAt: timestamp
  
  composite primary key: (planId, eventId)
}
```

### API Endpoints

**Authentication:**
- POST /api/auth/signup
- POST /api/auth/login
- POST /api/auth/refresh
- POST /api/auth/reset-password

**Events:**
- POST /api/events (create)
- GET /api/events/nearby?lat=&lng= (list nearby - fixed 5km radius)
- GET /api/events/:id (get detail)
- PATCH /api/events/:id (update - ownership required, future/ongoing events only)
- DELETE /api/events/:id (delete - ownership required)

**Interactions:**
- POST /api/events/:id/interested (toggle)

**Social:**
- POST /api/users/:id/follow (create follow or follow request depending on privacy)
- DELETE /api/users/:id/follow (unfollow)
- GET /api/users/:id/followers (list)
- GET /api/users/:id/following (list)
- GET /api/users/me/feed (following-only feed)
- GET /api/users/me/follow-requests (list pending requests - for private accounts)
- POST /api/follow-requests/:id/approve (approve follow request)
- POST /api/follow-requests/:id/deny (deny follow request)
- PATCH /api/users/me/privacy (toggle public/private)

**Plans:**
- POST /api/plans (create)
- GET /api/plans (list user's plans)
- GET /api/plans/:id (get plan detail)
- PATCH /api/plans/:id (update name)
- DELETE /api/plans/:id (delete)
- POST /api/plans/:id/events/:eventId (add event to plan)
- DELETE /api/plans/:id/events/:eventId (remove event from plan)
- POST /api/plans/:id/archive (manual archive)

**Users:**
- GET /api/users/me (current user)
- GET /api/users/:id (other user profile)
- PATCH /api/users/me (update name)
- GET /api/users/me/events (my created events)
- GET /api/users/me/interested (my interested events)

**Media:**
- GET /api/upload/signed-url (get signed URL for direct upload)

**Health:**
- GET /api/health

### Geospatial Queries

**PostGIS Integration:**
- Store location as geography type (lat/lng)
- GIST index on location column for performance
- Use ST_DWithin for radius queries
- Use ST_Distance for distance calculations

**Nearby Events Query:**
```sql
SELECT * FROM events
WHERE ST_DWithin(
  location::geography,
  ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography,
  5000  -- 5km in meters
)
AND (endTime > NOW() OR (endTime IS NULL AND startTime > NOW()))
AND isArchived = false
ORDER BY startTime ASC
LIMIT 50
```

### Media Upload Architecture

**Direct Client Upload (Primary):**
1. iOS requests signed URL from server
2. Server validates request (auth, video duration, file type)
3. Server generates Supabase signed URL (valid 10 min)
4. iOS uploads directly to Supabase Storage
5. iOS sends media URL to server when creating event
6. Server validates URL belongs to Supabase bucket

**Benefits:**
- Faster uploads (no server proxy)
- Reduced server bandwidth
- Better scalability
- Progress tracking on client

### Security

**Authentication:**
- JWT tokens stored in iOS Keychain
- Automatic token refresh on 401
- Secure session management

**Authorization:**
- Ownership verification for edit/delete
- Follow relationships validated server-side
- Plan ownership verified

**Data Protection:**
- HTTPS only
- Rate limiting (100 requests/15min per user)
- Input validation (Zod schemas)
- SQL injection prevention (Prisma ORM)

**Media Security:**
- Signed URLs for uploads
- File type validation
- File size limits enforced
- Video duration validation

---

## Design Requirements

### Visual Design Principles

1. **Map-first:** Map is hero element, full-screen by default
2. **Story-style media:** Instagram-inspired media viewing
3. **Minimal chrome:** Let content shine, UI elements subtle
4. **Spatial thinking:** Design reinforces geographic context
5. **Delight in details:** Smooth animations, satisfying interactions

**Note:** Specific color palettes, typography, spacing, and icons will be provided separately as design assets.

---

## Out of Scope (Post-TestFlight)

**Explicitly NOT in TestFlight:**

**Features:**
- Social login (Google, Apple ID)
- Push notifications
- "Strolling mode" (background location + alerts)
- GPS turn-by-turn directions (will link to Apple Maps)
- Live location sharing ("See where friends are")
- Comments on events
- Event ratings/reviews
- Saved posts/collections
- Business accounts / verified badges
- In-app messaging
- Calendar integration / export
- Ticket purchasing integration
- Event analytics for creators
- Global keyword search
- Venue pages / information
- User profile photos
- Photo filters / editing
- Video compression before upload
- AI auto-population from images
- Multi-city / travel mode
- Custom radius selection
- Recommended events algorithm
- Trending events
- Event categories customization
- Waitlist for popular events
- RSVP confirmations
- Recurring events

**Technical:**
- Android app
- Web app
- Desktop app
- Offline mode (beyond caching)
- Background sync
- Image caching layer
- Video streaming optimization
- Automated tests (beyond manual testing)
- Analytics dashboard
- Admin panel

---

**END OF PRD**

---

## Document Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-18 | Hugo | Initial PRD for TestFlight release |
| 1.1 | 2026-01-18 | Hugo | Clarifications: Terminology (Interested), Edit permissions, Plan limits, Story viewer (manual), Text overlay (basic), Follow requests (in-app), Deep links (post-TestFlight), Location storage (reverse geocoding) |
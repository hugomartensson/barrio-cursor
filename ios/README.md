# BarrioCursor iOS App

SwiftUI iOS app for BarrioCursor - a hyperlocal events discovery platform.

## Requirements

- Xcode 15+
- iOS 17+
- macOS Sonoma or later

## Setup Instructions

### 1. Create Xcode Project

1. Open **Xcode**
2. **File → New → Project**
3. Choose **iOS → App**
4. Settings:
   - Product Name: `BarrioCursor`
   - Organization Identifier: `com.yourname`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" (for now)
5. Save to `/ios/BarrioCursor`

### 2. Add Source Files

After creating the project, drag all the Swift files from this folder into Xcode:

```
BarrioCursor/
├── BarrioCursorApp.swift   (replace generated file)
├── ContentView.swift       (replace generated file)
├── Config/
│   └── AppConfig.swift
├── Models/
│   ├── User.swift
│   ├── Event.swift
│   └── APIError.swift
├── Services/
│   ├── APIService.swift
│   ├── AuthManager.swift
│   └── LocationManager.swift
└── Views/
    ├── MainTabView.swift
    ├── Auth/
    │   ├── AuthView.swift
    │   ├── LoginView.swift
    │   └── SignupView.swift
    ├── Map/
    │   └── MapView.swift
    ├── Feed/
    │   └── FeedView.swift
    ├── Profile/
    │   └── ProfileView.swift
    └── Event/
        ├── EventDetailView.swift
        └── CreateEventView.swift
```

### 3. Configure Info.plist

Add these keys to your `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Barrio needs your location to show nearby events</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Barrio needs access to your photos to add images to events</string>

<key>NSCameraUsageDescription</key>
<string>Barrio needs camera access to take photos for events</string>
```

### 4. Update API Base URL

In `BarrioCursor/Config/AppConfig.swift`, update the API URL for your setup:

```swift
// For Simulator (localhost)
static let apiBaseURL = "http://localhost:5001/api"

// For Physical Device (use your Mac's IP)
static let apiBaseURL = "http://192.168.x.x:5001/api"
```

To find your Mac's IP:
```bash
ipconfig getifaddr en0
```

### 5. Run the Backend

Make sure the backend is running:

```bash
cd ../server
npm run dev
```

### 6. Build & Run

1. Select an iPhone simulator (iPhone 15 Pro recommended)
2. Press **⌘R** to build and run
3. Grant location permissions when prompted

## Project Structure

```
├── Config/           # App configuration
├── Models/           # Data models (User, Event, etc.)
├── Services/         # API, Auth, Location services
└── Views/            # SwiftUI views
    ├── Auth/         # Login & Signup
    ├── Map/          # Map with event pins
    ├── Feed/         # Event list
    ├── Profile/      # User profile
    └── Event/        # Event detail & creation
```

## Features

- ✅ Email authentication (login/signup)
- ✅ Map view with event pins
- ✅ Nearby events feed
- ✅ Event detail view
- ✅ Like & Going interactions
- ✅ Create event form
- ✅ Location picker
- ✅ Photo selection
- 🔄 Photo upload (TODO)

## API Endpoints Used

| Endpoint | Description |
|----------|-------------|
| POST /auth/signup | Create account |
| POST /auth/login | Sign in |
| GET /events/nearby | Get nearby events |
| GET /events/:id | Get event details |
| POST /events | Create event |
| POST /events/:id/like | Toggle like |
| POST /events/:id/going | Toggle going |

## Troubleshooting

### "Could not connect to server"
- Ensure backend is running: `npm run dev`
- Check API URL in AppConfig.swift
- For physical device, use Mac's IP address

### "Location not working"
- Check Location permissions in Settings
- Simulator: Features → Location → Custom Location

### Build errors
- Clean build: **Product → Clean Build Folder** (⇧⌘K)
- Delete DerivedData if needed


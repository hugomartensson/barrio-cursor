# Network Troubleshooting Guide

## Problem: "Network error: The request timed out"

This error occurs when your iPhone cannot connect to the Mac running the server.

## Quick Fix Steps

### 1. Find Your Mac's Current IP Address

**Option A: Terminal Command**
```bash
ipconfig getifaddr en0
```

**Option B: Use the Helper Script**
```bash
cd server
./find-mac-ip.sh
```

**Option C: System Settings**
1. Open System Settings → Network
2. Select WiFi
3. Click "Details"
4. Note the IP Address (e.g., `192.168.1.100`)

### 2. Update AppConfig.swift

Open `ios/BarrioCursor/BarrioCursor/BarrioCursor/Config/AppConfig.swift` and update:

```swift
// Change this line:
nonisolated static let apiBaseURL = "http://172.20.10.10:3000/api"

// To your Mac's current IP (e.g.):
nonisolated static let apiBaseURL = "http://192.168.1.100:3000/api"
```

### 3. Verify Both Devices Are on Same Network

- Mac: System Settings → Network → WiFi → Network Name
- iPhone: Settings → WiFi → Network Name

**They must match!**

### 4. Test Server Accessibility

**From Mac Terminal:**
```bash
curl http://localhost:3000/api/health
```
Should return: `{"status":"healthy",...}`

**From iPhone Safari:**
1. Open Safari on iPhone
2. Go to: `http://<YOUR_MAC_IP>:3000/api/health`
   - Example: `http://192.168.1.100:3000/api/health`
3. Should see JSON response

If Safari shows "Safari cannot open the page", the server is not accessible from your iPhone.

### 5. Check Mac Firewall

1. System Settings → Network → Firewall
2. Click "Options"
3. Make sure Node.js is allowed, OR
4. Temporarily disable firewall to test

### 6. Verify Server is Running

```bash
cd server
npm run dev
```

Should see: `🚀 Server running` with port 3000

### 7. Common IP Address Ranges

- **Home WiFi**: Usually `192.168.1.x` or `192.168.0.x`
- **iPhone Hotspot**: Usually `172.20.10.x`
- **Corporate WiFi**: Varies (may have restrictions)

## Still Not Working?

### Check Server Logs

When you make a request from iPhone, check the server terminal. You should see:
```
GET /api/events/nearby 200
```

If you don't see any logs, the request isn't reaching the server.

### Test Network Connectivity

**From iPhone Terminal (if you have it) or use a network testing app:**
```bash
ping <MAC_IP>
```

Should get responses. If not, there's a network connectivity issue.

### Alternative: Use ngrok for Testing

If you can't get local network working, use ngrok:

```bash
# Install ngrok
brew install ngrok

# Start tunnel
ngrok http 3000

# Use the ngrok URL in AppConfig.swift
# Example: https://abc123.ngrok.io/api
```

**Note:** ngrok free tier has limitations. Only use for testing.

## For iOS Simulator

If using iOS Simulator (not physical device), use:
```swift
nonisolated static let apiBaseURL = "http://127.0.0.1:3000/api"
```

Simulator shares the Mac's network, so localhost works.

## Summary Checklist

- [ ] Found Mac's IP address
- [ ] Updated AppConfig.swift with correct IP
- [ ] Both devices on same WiFi network
- [ ] Server is running (`npm run dev`)
- [ ] Server accessible from Mac (`curl http://localhost:3000/api/health`)
- [ ] Server accessible from iPhone Safari (`http://<MAC_IP>:3000/api/health`)
- [ ] Mac firewall allows connections on port 3000
- [ ] Rebuilt iOS app after changing AppConfig.swift

# Dynamic IP Auto-Discovery

## Overview

The app now **automatically detects** the server IP address! No more manual configuration needed when switching between:
- iPhone hotspot (172.20.10.x)
- Home WiFi (192.168.1.x)
- Corporate WiFi (10.0.0.x)
- iOS Simulator (127.0.0.1)

## How It Works

### Auto-Discovery Process

When the app makes its first API call, it automatically:

1. **Checks saved IP** - Uses previously working IP (fastest)
2. **Tries localhost** - For iOS Simulator (127.0.0.1)
3. **Network discovery** - Queries server's `/api/health/network` endpoint
4. **Scans common ranges** - Tries common IP ranges:
   - 192.168.1.x (home WiFi)
   - 192.168.0.x (home WiFi alternative)
   - 172.20.10.x (iPhone hotspot)
   - 10.0.0.x (corporate/other)

Once a working IP is found, it's **saved automatically** for future use.

### Server Endpoint

The server now provides a network discovery endpoint:

```
GET /api/health/network
```

Returns:
```json
{
  "serverIPs": ["192.168.1.100", "172.20.10.10"],
  "localhostIPs": ["127.0.0.1", "localhost"],
  "port": 3000,
  "baseURL": "http://localhost:3000/api",
  "suggestedURLs": [
    "http://127.0.0.1:3000/api",
    "http://192.168.1.100:3000/api",
    "http://172.20.10.10:3000/api"
  ]
}
```

## Benefits

✅ **Zero configuration** - Works automatically  
✅ **Network switching** - Handles WiFi/hotspot changes  
✅ **Fast** - Caches working IP for instant connection  
✅ **Smart scanning** - Tries common IPs first  
✅ **Fallback** - Multiple discovery strategies  

## Manual Override (If Needed)

If auto-discovery fails, you can manually set the IP:

```swift
// In your code
await NetworkDiscoveryService.shared.setManualIP("192.168.1.100", port: 3000)
```

Or clear saved IP to force re-discovery:

```swift
await NetworkDiscoveryService.shared.clearSavedIP()
```

## Troubleshooting

### Auto-discovery is slow

The first connection may take a few seconds while scanning. Subsequent connections use the cached IP and are instant.

### Still can't connect

1. **Check server is running**: `curl http://localhost:3000/api/health`
2. **Test from iPhone Safari**: `http://<MAC_IP>:3000/api/health`
3. **Check firewall**: Mac firewall may block port 3000
4. **Reset discovery**: Clear saved IP to force re-scan

### Force re-discovery

If you switch networks and it's not working:

```swift
// Reset and re-discover
await NetworkDiscoveryService.shared.clearSavedIP()
await APIService.shared.resetBaseURL()
```

## Technical Details

### Storage

- Saved IP stored in `UserDefaults`
- Keys: `barrio_server_ip`, `barrio_server_port`
- Persists across app restarts

### Performance

- **First connection**: 1-5 seconds (scanning)
- **Subsequent connections**: Instant (cached)
- **Network change**: Auto-detects on next request

### Scanning Strategy

1. Tries common last octets first (1, 10, 100-105, 254)
2. Then scans 2-99 if needed
3. Stops on first successful connection

## Migration from Hardcoded IP

The old hardcoded IP in `AppConfig.swift` is now a fallback only. The app will:

1. Try auto-discovery first
2. Fall back to `127.0.0.1:3000` if all discovery fails
3. Show error with helpful diagnostics

No code changes needed - it works automatically!

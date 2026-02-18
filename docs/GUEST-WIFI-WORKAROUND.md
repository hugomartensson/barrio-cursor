# Guest WiFi / Client Isolation Workaround

When your home WiFi uses **guest network** or **client isolation**, your iPhone cannot reach your Mac on the local network. The app’s auto-discovery fails because devices are blocked from talking to each other.

## Solution: ngrok Tunnel

Use **ngrok** to expose your local server to the internet. Both your Mac and iPhone connect through ngrok, so client isolation no longer matters.

### 1. Install ngrok

```bash
# macOS with Homebrew
brew install ngrok

# Or download from https://ngrok.com/download
```

Sign up at [ngrok.com](https://ngrok.com) (free) and authenticate:

```bash
ngrok config add-authtoken YOUR_TOKEN
```

### 2. Start the server

In one terminal:

```bash
cd server
npm run dev
```

### 3. Start the ngrok tunnel

In another terminal:

```bash
ngrok http 3000
```

You’ll see output like:

```
Forwarding   https://abc123def456.ngrok-free.app -> http://localhost:3000
```

### 4. Configure the app

1. Open the app on your iPhone
2. Go to **Profile** → **Set server address**
3. Enter the ngrok URL (e.g. `https://abc123def456.ngrok-free.app`)
4. Tap **Save**

The app will use this URL for all API requests. Both devices reach the server through the internet, bypassing client isolation.

### 5. Important notes

- **URL changes**: On the free tier, the ngrok URL changes each time you restart ngrok. You’ll need to update it in the app.
- **Keep both running**: Keep `npm run dev` and `ngrok http 3000` running while testing.
- **Clear when done**: When back on normal WiFi, go to Profile → Set server address → **Clear and use auto-discovery** to revert to local discovery.

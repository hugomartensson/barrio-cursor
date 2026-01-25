#!/bin/bash

# Script to find Mac's IP address for iOS device connection
# Run this to get the IP address to use in AppConfig.swift

echo "🔍 Finding Mac's IP address..."
echo ""

# Try different methods to get IP
if command -v ipconfig &> /dev/null; then
    # Try en0 (Ethernet/WiFi)
    IP_EN0=$(ipconfig getifaddr en0 2>/dev/null)
    if [ -n "$IP_EN0" ]; then
        echo "✅ Found IP on en0: $IP_EN0"
        echo ""
        echo "📱 Update AppConfig.swift with:"
        echo "   nonisolated static let apiBaseURL = \"http://$IP_EN0:3000/api\""
        echo ""
    fi
    
    # Try en1 (alternative interface)
    IP_EN1=$(ipconfig getifaddr en1 2>/dev/null)
    if [ -n "$IP_EN1" ]; then
        echo "✅ Found IP on en1: $IP_EN1"
        echo ""
        echo "📱 Update AppConfig.swift with:"
        echo "   nonisolated static let apiBaseURL = \"http://$IP_EN1:3000/api\""
        echo ""
    fi
fi

# Alternative: use networksetup
if command -v networksetup &> /dev/null; then
    echo "🌐 Checking network interfaces..."
    networksetup -listallhardwareports | grep -A 1 "Hardware Port" | grep -E "Ethernet|Wi-Fi" | while read line; do
        PORT=$(echo "$line" | sed 's/Hardware Port: //')
        echo "   Interface: $PORT"
    done
fi

echo ""
echo "🧪 Testing server connectivity..."
if curl -s --max-time 2 http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "✅ Server is running on port 3000"
else
    echo "❌ Server is NOT accessible on localhost:3000"
    echo "   Make sure the server is running: cd server && npm run dev"
fi

echo ""
echo "💡 Tips:"
echo "   - Both Mac and iPhone must be on the same WiFi network"
echo "   - Make sure Mac's firewall allows connections on port 3000"
echo "   - Test from iPhone: Open Safari and go to http://<MAC_IP>:3000/api/health"

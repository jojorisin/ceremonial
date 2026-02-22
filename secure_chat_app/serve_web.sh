#!/bin/bash
# Serve the built Flutter web app on your network so your phone can access it.
# Usage: ./serve_web.sh
# Then on your phone, open: http://YOUR_IP:8080
# Find your IP: ipconfig getifaddr en0  (Mac)

cd "$(dirname "$0")"

echo "Building for production..."
flutter build web

IP=$(ipconfig getifaddr en0 2>/dev/null || echo "YOUR_IP")
echo ""
echo "Starting server on port 8080 (accessible from other devices)"
echo "On your phone, open: http://$IP:8080"
echo ""
echo "Press Ctrl+C to stop"
echo ""

cd build/web && python3 -m http.server 8080 --bind 0.0.0.0

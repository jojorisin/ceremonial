#!/bin/bash
# Serve the Flutter web app and expose it via ngrok so you can access from your phone.
# Uses Node server (server.js) for message sync between devices; falls back to Python if Node missing.
# Prerequisites: ngrok installed, auth token configured (ngrok config add-authtoken YOUR_TOKEN)
# Install: brew install ngrok

cd "$(dirname "$0")"

PORT=8080

# Check ngrok is installed
if ! command -v ngrok &> /dev/null; then
  echo "ngrok is not installed. Install with: brew install ngrok"
  echo "Then sign up at https://ngrok.com and run: ngrok config add-authtoken YOUR_TOKEN"
  exit 1
fi

# Free port if already in use (e.g. from a previous run)
if lsof -ti :$PORT >/dev/null 2>&1; then
  echo "Port $PORT is in use. Stopping the process using it..."
  lsof -ti :$PORT | xargs kill -9 2>/dev/null || true
  sleep 1
fi

echo "Building for production..."
flutter build web

echo ""
if command -v node &> /dev/null; then
  echo "Starting Node server (app + message sync API) on port $PORT..."
  node server.js &
else
  echo "Starting Python server on port $PORT (no message sync - install Node for sync)..."
  cd build/web && python3 -m http.server $PORT --bind 127.0.0.1 &
  cd "$OLDPWD"
fi
SERVER_PID=$!

sleep 2

echo ""
echo "Starting ngrok tunnel..."
ngrok http $PORT --log=stdout > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!
sleep 3
# Print the public URL from ngrok's local API
NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4)
if [ -n "$NGROK_URL" ]; then
  echo ""
  echo "=============================================="
  echo "  Open this URL on your phone (and computer):"
  echo "  $NGROK_URL"
  echo "=============================================="
  echo ""
else
  echo "Ngrok started. Check the ngrok dashboard at http://127.0.0.1:4040 for your URL."
  echo "Or run 'ngrok http 8080' in another terminal to see the URL."
fi
trap "kill $SERVER_PID $NGROK_PID 2>/dev/null; exit" INT TERM
wait $NGROK_PID 2>/dev/null || true
kill $SERVER_PID $NGROK_PID 2>/dev/null

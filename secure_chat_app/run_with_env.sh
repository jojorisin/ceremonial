#!/usr/bin/env bash
# Run the Flutter app with RELAY_URL from .env (if present).
# Copy .env.example to .env and set RELAY_URL for local testing.
set -e
RELAY_URL=""
if [ -f .env ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^#.*$ ]] && continue
    if [[ "$line" =~ ^RELAY_URL=(.*)$ ]]; then
      RELAY_URL="${BASH_REMATCH[1]%$'\r'}"
      RELAY_URL="${RELAY_URL#[\"']}"
      RELAY_URL="${RELAY_URL%[\"']}"
      RELAY_URL="${RELAY_URL#"${RELAY_URL%%[![:space:]]*}"}"
      RELAY_URL="${RELAY_URL%"${RELAY_URL##*[![:space:]]}"}"
      break
    fi
  done < .env
fi
# Pass RELAY_URL to Flutter so relay_config.dart gets it via String.fromEnvironment
exec flutter run --dart-define=RELAY_URL="$RELAY_URL" "$@"

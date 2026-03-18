#!/usr/bin/env bash
# exit on error
set -o errexit

echo "Installing Flutter..."
# Clone Flutter stable branch
git clone https://github.com/flutter/flutter.git -b stable

# Add Flutter to the path for this script
export PATH="$PATH:`pwd`/flutter/bin"

# Enable web support
flutter config --enable-web

# Build the web app
# We read the API_URL injected by Render and ensure it has '/api' at the end.
# Render native 'host' property returns just the domain without 'https://'. Let's ensure it's formatted.

if [[ "$API_URL" != http* ]]; then
  API_URL="https://$API_URL"
fi

if [[ "$API_URL" != */api ]]; then
  API_URL="$API_URL/api"
fi

echo "Building Flutter Web with API_URL: $API_URL"

flutter pub get
flutter build web --release --dart-define=API_URL="$API_URL"

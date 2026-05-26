#!/usr/bin/env bash
set -euo pipefail

# Netlify build environment doesn't ship Flutter. Install on the fly.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.38.0}"
FLUTTER_CHANNEL="beta"
FLUTTER_DIR="${HOME}/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "==> Installing Flutter $FLUTTER_VERSION ($FLUTTER_CHANNEL)"
  git clone --depth 1 --branch "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version
flutter config --enable-web --no-analytics
flutter pub get

: "${AZAR_WS_URL:?Set AZAR_WS_URL in Netlify env vars (e.g. wss://azar-chat-server.fly.dev)}"

echo "==> Building Flutter web with AZAR_WS_URL=$AZAR_WS_URL"
flutter build web --release --dart-define=AZAR_WS_URL="$AZAR_WS_URL"

#!/usr/bin/env bash
# Provisions the Flutter SDK inside the dev container and primes the project.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_DIR="/opt/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Installing Flutter ($FLUTTER_VERSION)..."
  sudo git clone --depth 1 -b "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  sudo chown -R "$(whoami)" "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

git config --global --add safe.directory "$FLUTTER_DIR"

flutter config --no-analytics --enable-web
flutter precache

# Seed a local .env from the example if the developer hasn't created one yet.
if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
  echo "Created .env from .env.example — fill in your Supabase credentials."
fi

flutter pub get
echo "Dev container ready. Run: flutter run -d chrome"

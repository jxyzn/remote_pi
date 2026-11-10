#!/usr/bin/env bash
# Build Remote Pi Flutter web client and ensure /var/www/remote-pi symlink is intact.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app"
BUILD_DIR="$APP_DIR/build/web"
WWW_LINK="/var/www/remote-pi"

export PATH="$HOME/flutter/bin:$HOME/.pub-cache/bin:$PATH"

echo "==> Building Remote Pi web client..."
cd "$APP_DIR"
flutter build web --base-href "/remote-pi/"

echo "==> Verifying web distribution link..."
if [[ -L "$WWW_LINK" ]]; then
  echo "Symlink $WWW_LINK -> $(readlink "$WWW_LINK") [OK]"
elif [[ -e "$WWW_LINK" ]]; then
  echo "Warning: $WWW_LINK exists but is not a symlink."
else
  echo "Creating symlink $WWW_LINK -> $BUILD_DIR (requires sudo)"
  sudo ln -s "$BUILD_DIR" "$WWW_LINK"
fi

echo "==> Remote Pi Web successfully built and served at http://$(hostname)/remote-pi/"

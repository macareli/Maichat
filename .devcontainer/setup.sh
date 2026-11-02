#!/usr/bin/env bash
# Prepare the pinned Flutter development environment.
set -euo pipefail

flutter_version="$(flutter --version)"
case "$flutter_version" in
  "Flutter 3.44.9 "*) ;;
  *)
    echo "Flutter 3.44.9 is required by this project's development environment." >&2
    exit 1
    ;;
esac

echo "==> Disabling Flutter analytics"
flutter config --no-analytics >/dev/null 2>&1

echo "==> Fetching Dart/Flutter package dependencies"
flutter pub get

echo "==> Accepting Android SDK licenses"
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true

echo "==> Pre-caching Android build artifacts"
flutter precache --android

echo "==> Flutter diagnostics"
flutter doctor -v || true

echo "Setup complete."
echo "  Analyze: flutter analyze"
echo "  Test:    flutter test"
echo "  Build:   flutter build apk --release"

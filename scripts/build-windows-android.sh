#!/usr/bin/env bash
# Builds the Windows and Android release packages on a Windows machine.
#
# Requirements: Flutter (stable), Visual Studio 2022 with "Desktop development
# with C++", Android SDK + JDK 17 (Android Studio installs both).
# Run from Git Bash in the repository root:
#   bash scripts/build-windows-android.sh
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION=$(grep '^version:' pubspec.yaml | sed -E 's/version: *([0-9.]+).*/\1/')
DIST=dist
mkdir -p "$DIST"

echo "== Checking the toolchain"
flutter --version
flutter pub get
flutter analyze
flutter test

echo "== Android"
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "$DIST/RadioApp-v$VERSION-android.apk"

echo "== Windows"
flutter build windows --release
powershell -NoProfile -Command \
  "Compress-Archive -Force -Path 'build/windows/x64/runner/Release/*' -DestinationPath '$DIST/RadioApp-v$VERSION-windows-x64.zip'"

echo
echo "Done:"
ls -la "$DIST"

#!/usr/bin/env bash
# Sync shared/words.json to iOS and Android bundle locations.
# shared/words.json is the single source of truth; this script copies it to the platform-specific locations.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$REPO_ROOT/shared/words.json"
IOS_DEST="$REPO_ROOT/ios/StackSpeak/Resources/words.json"
ANDROID_DEST="$REPO_ROOT/android/app/src/main/assets/words.json"

if [[ ! -f "$SOURCE" ]]; then
  echo "Error: source file not found at $SOURCE" >&2
  exit 1
fi

echo "Synced $SOURCE"

# iOS — sync if the iOS project exists
if [[ -d "$REPO_ROOT/ios" ]]; then
  mkdir -p "$(dirname "$IOS_DEST")"
  cp "$SOURCE" "$IOS_DEST"
  echo "  -> $IOS_DEST"
else
  echo "  (skipped iOS — no ios/ directory yet)"
fi

# Android — sync if the Android project exists (Phase 2)
if [[ -d "$REPO_ROOT/android" ]]; then
  mkdir -p "$(dirname "$ANDROID_DEST")"
  cp "$SOURCE" "$ANDROID_DEST"
  echo "  -> $ANDROID_DEST"
else
  echo "  (skipped Android — not yet in scope)"
fi

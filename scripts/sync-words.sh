#!/usr/bin/env bash
# Sync shared/words-index.json and shared/stacks/*.json to iOS and Android bundle locations.
# shared/ is the single source of truth; this script copies it to the platform-specific locations.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_INDEX="$REPO_ROOT/shared/words-index.json"
SOURCE_STACKS_DIR="$REPO_ROOT/shared/stacks"
IOS_RESOURCES="$REPO_ROOT/ios/StackSpeak/Resources"
ANDROID_ASSETS="$REPO_ROOT/android/app/src/main/assets"

if [[ ! -f "$SOURCE_INDEX" ]]; then
  echo "Error: index file not found at $SOURCE_INDEX" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_STACKS_DIR" ]]; then
  echo "Error: stacks directory not found at $SOURCE_STACKS_DIR" >&2
  exit 1
fi

echo "Syncing word data from shared/ to platform bundles..."

# iOS — sync if the iOS project exists
if [[ -d "$REPO_ROOT/ios" ]]; then
  mkdir -p "$IOS_RESOURCES/stacks"
  cp "$SOURCE_INDEX" "$IOS_RESOURCES/"
  cp "$SOURCE_STACKS_DIR"/*.json "$IOS_RESOURCES/stacks/"
  echo "  ✓ iOS: words-index.json + $(ls "$SOURCE_STACKS_DIR"/*.json | wc -l | xargs) stack files"
else
  echo "  (skipped iOS — no ios/ directory yet)"
fi

# Android — sync if the Android project exists (Phase 2)
if [[ -d "$REPO_ROOT/android" ]]; then
  mkdir -p "$ANDROID_ASSETS/stacks"
  cp "$SOURCE_INDEX" "$ANDROID_ASSETS/"
  cp "$SOURCE_STACKS_DIR"/*.json "$ANDROID_ASSETS/stacks/"
  echo "  ✓ Android: words-index.json + $(ls "$SOURCE_STACKS_DIR"/*.json | wc -l | xargs) stack files"
else
  echo "  (skipped Android — not yet in scope)"
fi

echo "Done."

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

mkdir -p "$(dirname "$IOS_DEST")"
mkdir -p "$(dirname "$ANDROID_DEST")"

cp "$SOURCE" "$IOS_DEST"
cp "$SOURCE" "$ANDROID_DEST"

echo "Synced $SOURCE"
echo "  -> $IOS_DEST"
echo "  -> $ANDROID_DEST"

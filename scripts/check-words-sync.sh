#!/usr/bin/env bash
# Verify that shared/words.json, iOS words.json, and Android words.json are identical.
# Useful for CI or pre-commit hooks.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$REPO_ROOT/shared/words.json"
IOS_DEST="$REPO_ROOT/ios/StackSpeak/Resources/words.json"
ANDROID_DEST="$REPO_ROOT/android/app/src/main/assets/words.json"

status=0

if [[ ! -f "$SOURCE" ]]; then
  echo "Error: source file not found at $SOURCE" >&2
  exit 1
fi

if [[ -f "$IOS_DEST" ]] && ! diff -q "$SOURCE" "$IOS_DEST" > /dev/null; then
  echo "iOS words.json is out of sync with shared/words.json"
  status=1
fi

if [[ -f "$ANDROID_DEST" ]] && ! diff -q "$SOURCE" "$ANDROID_DEST" > /dev/null; then
  echo "Android words.json is out of sync with shared/words.json"
  status=1
fi

if [[ $status -eq 0 ]]; then
  echo "All words.json files are in sync."
fi

exit $status

#!/usr/bin/env bash
# Verify that shared/ word data is synced to iOS and Android bundles.
# Useful for CI or pre-commit hooks.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_INDEX="$REPO_ROOT/shared/words-index.json"
SOURCE_STACKS_DIR="$REPO_ROOT/shared/stacks"
IOS_RESOURCES="$REPO_ROOT/ios/StackSpeak/Resources"
ANDROID_ASSETS="$REPO_ROOT/android/app/src/main/assets"

status=0

if [[ ! -f "$SOURCE_INDEX" ]]; then
  echo "Error: source index not found at $SOURCE_INDEX" >&2
  exit 1
fi

# Check iOS
if [[ -d "$IOS_RESOURCES" ]]; then
  if [[ ! -f "$IOS_RESOURCES/words-index.json" ]]; then
    echo "iOS words-index.json missing"
    status=1
  elif ! diff -q "$SOURCE_INDEX" "$IOS_RESOURCES/words-index.json" > /dev/null; then
    echo "iOS words-index.json is out of sync"
    status=1
  fi

  for stack_file in "$SOURCE_STACKS_DIR"/*.json; do
    filename="$(basename "$stack_file")"
    ios_stack="$IOS_RESOURCES/stacks/$filename"
    if [[ ! -f "$ios_stack" ]]; then
      echo "iOS stacks/$filename missing"
      status=1
    elif ! diff -q "$stack_file" "$ios_stack" > /dev/null; then
      echo "iOS stacks/$filename is out of sync"
      status=1
    fi
  done
fi

# Check Android
if [[ -d "$ANDROID_ASSETS" ]]; then
  if [[ ! -f "$ANDROID_ASSETS/words-index.json" ]]; then
    echo "Android words-index.json missing"
    status=1
  elif ! diff -q "$SOURCE_INDEX" "$ANDROID_ASSETS/words-index.json" > /dev/null; then
    echo "Android words-index.json is out of sync"
    status=1
  fi

  for stack_file in "$SOURCE_STACKS_DIR"/*.json; do
    filename="$(basename "$stack_file")"
    android_stack="$ANDROID_ASSETS/stacks/$filename"
    if [[ ! -f "$android_stack" ]]; then
      echo "Android stacks/$filename missing"
      status=1
    elif ! diff -q "$stack_file" "$android_stack" > /dev/null; then
      echo "Android stacks/$filename is out of sync"
      status=1
    fi
  done
fi

if [[ $status -eq 0 ]]; then
  echo "✓ All word data files are in sync."
fi

exit $status

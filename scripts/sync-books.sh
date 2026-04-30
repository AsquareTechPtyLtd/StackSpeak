#!/usr/bin/env bash
# Sync shared/books-catalog.json and shared/books/<bookId>/** to the iOS bundle.
# shared/ is the single source of truth; this script copies it to platform locations.
# Mirrors scripts/sync-words.sh — see CLAUDE.md "Data Synchronization".
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_CATALOG="$REPO_ROOT/shared/books-catalog.json"
SOURCE_BOOKS_DIR="$REPO_ROOT/shared/books"
IOS_RESOURCES="$REPO_ROOT/ios/StackSpeak/Resources"
ANDROID_ASSETS="$REPO_ROOT/android/app/src/main/assets"

if [[ ! -f "$SOURCE_CATALOG" ]]; then
  echo "  (no books-catalog.json at $SOURCE_CATALOG — skipping; create it before running this script)"
  exit 0
fi

if [[ ! -d "$SOURCE_BOOKS_DIR" ]]; then
  echo "  (no shared/books directory yet — skipping)"
  exit 0
fi

echo "Syncing book data from shared/ to platform bundles..."

# iOS — sync if the iOS project exists
if [[ -d "$REPO_ROOT/ios" ]]; then
  cp "$SOURCE_CATALOG" "$IOS_RESOURCES/"
  rm -rf "$IOS_RESOURCES/books"
  mkdir -p "$IOS_RESOURCES/books"
  # Preserve directory structure so books/<bookId>/manifest.json + chapters/ + images/ keep their layout.
  cp -R "$SOURCE_BOOKS_DIR"/* "$IOS_RESOURCES/books/" 2>/dev/null || true
  book_count=$(find "$SOURCE_BOOKS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | xargs)
  echo "  ✓ iOS: books-catalog.json + $book_count book(s)"
else
  echo "  (skipped iOS — no ios/ directory)"
fi

# Android — Phase 2; mirror sync-words.sh's pattern.
if [[ -d "$REPO_ROOT/android" ]]; then
  cp "$SOURCE_CATALOG" "$ANDROID_ASSETS/"
  rm -rf "$ANDROID_ASSETS/books"
  mkdir -p "$ANDROID_ASSETS/books"
  cp -R "$SOURCE_BOOKS_DIR"/* "$ANDROID_ASSETS/books/" 2>/dev/null || true
  book_count=$(find "$SOURCE_BOOKS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | xargs)
  echo "  ✓ Android: books-catalog.json + $book_count book(s)"
else
  echo "  (skipped Android — not yet in scope)"
fi

echo "Done."

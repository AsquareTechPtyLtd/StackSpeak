#!/usr/bin/env bash
# Verify that shared/ book data is synced to the iOS (and Android) bundles.
# Suitable for CI or pre-commit hooks. Mirrors scripts/check-words-sync.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_CATALOG="$REPO_ROOT/shared/books-catalog.json"
SOURCE_BOOKS_DIR="$REPO_ROOT/shared/books"
IOS_RESOURCES="$REPO_ROOT/ios/StackSpeak/Resources"
ANDROID_ASSETS="$REPO_ROOT/android/app/src/main/assets"

# If there is no source catalog, there is nothing to check yet.
if [[ ! -f "$SOURCE_CATALOG" ]]; then
  echo "✓ No books-catalog.json yet (nothing to verify)."
  exit 0
fi

status=0

check_dir_in_sync() {
  local platform_label="$1"
  local platform_resources="$2"

  if [[ ! -d "$platform_resources" ]]; then
    return 0
  fi

  if [[ ! -f "$platform_resources/books-catalog.json" ]]; then
    echo "$platform_label books-catalog.json missing"
    status=1
  elif ! diff -q "$SOURCE_CATALOG" "$platform_resources/books-catalog.json" > /dev/null; then
    echo "$platform_label books-catalog.json is out of sync"
    status=1
  fi

  if [[ -d "$SOURCE_BOOKS_DIR" ]]; then
    # Walk every file under shared/books and check it exists & matches under platform resources.
    while IFS= read -r -d '' src_file; do
      rel="${src_file#$SOURCE_BOOKS_DIR/}"
      platform_file="$platform_resources/books/$rel"
      if [[ ! -f "$platform_file" ]]; then
        echo "$platform_label books/$rel missing"
        status=1
      elif ! diff -q "$src_file" "$platform_file" > /dev/null; then
        echo "$platform_label books/$rel is out of sync"
        status=1
      fi
    done < <(find "$SOURCE_BOOKS_DIR" -type f -print0)
  fi
}

check_dir_in_sync "iOS" "$IOS_RESOURCES"
check_dir_in_sync "Android" "$ANDROID_ASSETS"

if [[ $status -eq 0 ]]; then
  echo "✓ All book data files are in sync."
fi

exit $status

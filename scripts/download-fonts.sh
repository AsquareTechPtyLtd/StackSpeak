#!/usr/bin/env bash
# download-fonts.sh — Downloads Inter, JetBrains Mono, and Instrument Serif Italic
# into ios/StackSpeak/Resources/Fonts/ at pinned versions.
#
# Run once after cloning:
#   ./scripts/download-fonts.sh
#
# Requirements: curl, unzip (both ship with macOS)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FONTS_DIR="$REPO_ROOT/ios/StackSpeak/Resources/Fonts"
mkdir -p "$FONTS_DIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── Versions ─────────────────────────────────────────────────────────────────
INTER_VERSION="4.0"
JBM_VERSION="2.304"

echo "==> Downloading Inter $INTER_VERSION..."
curl -fsSL \
  "https://github.com/rsms/inter/releases/download/v${INTER_VERSION}/Inter-${INTER_VERSION}.zip" \
  -o "$TMP/inter.zip"
unzip -q "$TMP/inter.zip" -d "$TMP/inter"

for weight in Regular Medium SemiBold Bold; do
  src=$(find "$TMP/inter" -name "Inter-${weight}.ttf" | head -1)
  if [ -z "$src" ]; then
    echo "ERROR: Inter-${weight}.ttf not found in zip" >&2
    exit 1
  fi
  cp "$src" "$FONTS_DIR/Inter-${weight}.ttf"
  echo "    Inter-${weight}.ttf"
done

echo "==> Downloading JetBrains Mono $JBM_VERSION..."
curl -fsSL \
  "https://github.com/JetBrains/JetBrainsMono/releases/download/v${JBM_VERSION}/JetBrainsMono-${JBM_VERSION}.zip" \
  -o "$TMP/jbm.zip"
unzip -q "$TMP/jbm.zip" -d "$TMP/jbm"

for weight in Regular Medium SemiBold; do
  src=$(find "$TMP/jbm" -name "JetBrainsMono-${weight}.ttf" | head -1)
  if [ -z "$src" ]; then
    echo "ERROR: JetBrainsMono-${weight}.ttf not found in zip" >&2
    exit 1
  fi
  cp "$src" "$FONTS_DIR/JetBrainsMono-${weight}.ttf"
  echo "    JetBrainsMono-${weight}.ttf"
done

echo "==> Downloading Instrument Serif (main branch)..."
curl -fsSL \
  "https://github.com/Instrument/instrument-serif/archive/refs/heads/main.zip" \
  -o "$TMP/instrument.zip"
unzip -q "$TMP/instrument.zip" -d "$TMP/instrument"

src=$(find "$TMP/instrument" -name "InstrumentSerif-Italic.ttf" | head -1)
if [ -z "$src" ]; then
  echo "ERROR: InstrumentSerif-Italic.ttf not found in zip" >&2
  exit 1
fi
cp "$src" "$FONTS_DIR/InstrumentSerif-Italic.ttf"
echo "    InstrumentSerif-Italic.ttf"

echo ""
echo "Done. Fonts installed to:"
echo "  $FONTS_DIR"
echo ""
ls -1 "$FONTS_DIR"
echo ""
echo "Next steps:"
echo "  1. Run: cd ios && xcodegen generate"
echo "  2. Open ios/StackSpeak.xcodeproj"
echo "  3. Set your Development Team in Signing & Capabilities"

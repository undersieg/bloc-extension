#!/bin/bash
# Builds the DevTools extension, commits the build output, and publishes.
# Run from the bloc_devtools_extension root.
#
# Usage:
#   chmod +x publish.sh
#   ./publish.sh           # interactive (asks for confirmation)
#   ./publish.sh --dry-run # just validate, don't actually publish

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

DRY_RUN=""
if [ "$1" = "--dry-run" ]; then
  DRY_RUN="--dry-run"
  echo "=== DRY RUN MODE ==="
  echo ""
fi

# ── Step 1: Build the DevTools extension ─────────────────────────────────────
echo "=== Step 1/4: Building DevTools extension ==="
cd "$SCRIPT_DIR/devtools_extension"
flutter pub get
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest="$SCRIPT_DIR/extension/devtools"

echo ""
echo "=== Step 2/4: Validating extension ==="
dart run devtools_extensions validate --package="$SCRIPT_DIR"

# ── Step 3: Commit the build output so git is clean ──────────────────────────
cd "$SCRIPT_DIR"
echo ""
echo "=== Step 3/4: Committing build output ==="

if git diff --quiet extension/devtools/build/ 2>/dev/null && \
   git diff --cached --quiet extension/devtools/build/ 2>/dev/null; then
  echo "No changes in extension/devtools/build/ — already up to date."
else
  git add extension/devtools/build/
  git commit -m "Rebuild DevTools extension for publish" --no-verify
  echo "Committed updated build output."
fi

# ── Step 4: Publish ──────────────────────────────────────────────────────────
echo ""
echo "=== Step 4/4: Publishing ==="
flutter pub get
flutter pub publish $DRY_RUN

echo ""
echo "=== Done! ==="
#!/bin/bash
# Builds the DevTools extension web app and copies it into extension/devtools/build/.
# Run from the bloc_devtools_extension root.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_SRC="$SCRIPT_DIR/devtools_extension"
PKG_ROOT="$SCRIPT_DIR"

echo "=== Building DevTools extension ==="
cd "$EXT_SRC"
flutter pub get
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest="$PKG_ROOT/extension/devtools"

echo ""
echo "=== Validating ==="
dart run devtools_extensions validate --package="$PKG_ROOT"

echo ""
echo "Done. Build output is in extension/devtools/build/"
echo ""
echo "To publish, run:  ./publish.sh"
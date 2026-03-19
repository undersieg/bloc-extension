#!/bin/bash
# Builds the DevTools extension web app and copies it into the
# extension/devtools/build/ directory where Flutter DevTools expects it.
#
# Run from the bloc_devtools_extension root:
#   chmod +x build_extension.sh
#   ./build_extension.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_SRC="$SCRIPT_DIR/devtools_extension"
EXT_OUT="$SCRIPT_DIR/extension/devtools/build"

echo "Building DevTools extension web app..."
cd "$EXT_SRC"
flutter pub get
flutter build web --release --no-tree-shake-icons

echo "Copying build output to extension/devtools/build/..."
rm -rf "$EXT_OUT"
mkdir -p "$EXT_OUT"
cp -r build/web/* "$EXT_OUT/"

echo ""
echo "Done! The extension is ready at: $EXT_OUT"
echo "Users who depend on this package will see the tab in Flutter DevTools."

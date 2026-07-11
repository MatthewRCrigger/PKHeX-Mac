#!/bin/bash
# Builds a Release configuration of PKHeXMac and installs it to /Applications,
# replacing any existing copy. Run this whenever you want the Dock-pinned app
# to pick up code changes — it does not happen automatically.
#
# Usage: Scripts/install_app.sh

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="PKHeXMac"
CONFIGURATION="Release"
DEST_APP="/Applications/PKHeXMac.app"

echo "Building $SCHEME ($CONFIGURATION)…"
xcodebuild -project PKHeXMac.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  build

DERIVED_DATA_APP=$(xcodebuild -project PKHeXMac.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -showBuildSettings 2>/dev/null \
  | awk -F'= ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')/PKHeXMac.app

if [ ! -d "$DERIVED_DATA_APP" ]; then
  echo "error: built app not found at $DERIVED_DATA_APP" >&2
  exit 1
fi

echo "Installing to $DEST_APP…"

# Quit the running app first, if any, so Finder/LaunchServices isn't holding it open.
osascript -e 'tell application "PKHeXMac" to quit' >/dev/null 2>&1 || true
sleep 1

rm -rf "$DEST_APP"
cp -R "$DERIVED_DATA_APP" "$DEST_APP"
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

# Re-sign the whole bundle (app + embedded frameworks) as one unit. Xcode signs each
# piece with its own ad-hoc identity at build time; copying the .app out of DerivedData
# without re-signing leaves the outer binary and PKHeXCore.framework with mismatched
# ad-hoc Team IDs, which dyld refuses to load ("different Team IDs") and the app
# crashes on launch. --deep re-signs nested frameworks/binaries with the same identity.
echo "Re-signing bundle…"
codesign --force --deep --sign - "$DEST_APP"

echo "Done. Installed at $DEST_APP"

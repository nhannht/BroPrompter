#!/usr/bin/env bash
#
# Release packaging for BroPrompter (BROP-49).
# Run via `make release`, which regenerates the Xcode project first.
#
# Output: build/release/BroPrompter-<version>.dmg
#
# Modes (auto-detected):
#   unsigned (default) - ad-hoc signed, no Apple Developer membership needed.
#       This is the bridge build shipped while Apple enrollment is pending. On
#       download, users must clear Gatekeeper once (see README).
#   signed - Developer ID signed + notarized + stapled. Enabled when
#       SIGN_IDENTITY, TEAM_ID, and NOTARY_PROFILE are all set. Produces a
#       cleanly double-clickable DMG.
#       UNVERIFIED end-to-end until the Apple membership is active (BROP-49).
#       Verify the full sign -> notarize -> staple chain before trusting it.
#
# Environment variables (signed mode only):
#   SIGN_IDENTITY   "Developer ID Application: Your Name (TEAMID)"
#   TEAM_ID         10-character Apple Team ID
#   NOTARY_PROFILE  notarytool keychain profile
#                   (see: xcrun notarytool store-credentials)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="BroPrompter"
APP_NAME="BroPrompter"
CONFIG="Release"
PROJECT="BroPrompter.xcodeproj"

RELEASE_DIR="build/release"
ARCHIVE="$RELEASE_DIR/$APP_NAME.xcarchive"
STAGING="$RELEASE_DIR/dmg"

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [ ! -d "$PROJECT" ]; then
  echo "error: $PROJECT not found. Run 'make generate' first (or use 'make release')." >&2
  exit 1
fi

VERSION="$(sed -n -E 's/.*MARKETING_VERSION:[[:space:]]*"([^"]+)".*/\1/p' project.yml | head -1)"
VERSION="${VERSION:-0.0.0}"
DMG="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"

if [ -n "$SIGN_IDENTITY" ] && [ -n "$TEAM_ID" ] && [ -n "$NOTARY_PROFILE" ]; then
  MODE="signed"
else
  MODE="unsigned"
fi

echo "==> BroPrompter $VERSION release ($MODE mode)"
echo "==> Cleaning $RELEASE_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$STAGING"

echo "==> Archiving ($CONFIG)"
if [ "$MODE" = "signed" ]; then
  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY"
else
  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM=""
fi

APP_SRC="$ARCHIVE/Products/Applications/$APP_NAME.app"
if [ ! -d "$APP_SRC" ]; then
  echo "error: archived app not found at $APP_SRC" >&2
  exit 1
fi

echo "==> Staging app for DMG"
cp -R "$APP_SRC" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
APP_IN_STAGING="$STAGING/$APP_NAME.app"

if [ "$MODE" = "signed" ]; then
  # UNVERIFIED until the Apple membership is active (BROP-49).
  echo "==> Notarizing app"
  ZIP="$RELEASE_DIR/$APP_NAME.zip"
  ditto -c -k --keepParent "$APP_IN_STAGING" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  rm -f "$ZIP"
  echo "==> Stapling app"
  xcrun stapler staple "$APP_IN_STAGING"
fi

echo "==> Building DMG"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING" \
  -fs HFS+ \
  -ov -format UDZO \
  "$DMG"

if [ "$MODE" = "signed" ]; then
  echo "==> Stapling DMG"
  xcrun stapler staple "$DMG"
fi

echo ""
echo "Done: $DMG"
if [ "$MODE" = "unsigned" ]; then
  cat <<EOF

This is an UNSIGNED bridge build. After download, users clear Gatekeeper once:

  xattr -dr com.apple.quarantine "/Applications/$APP_NAME.app"

or via System Settings > Privacy & Security > Open Anyway. See README.
EOF
fi

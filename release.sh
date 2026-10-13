#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/ClipBook.xcodeproj"
SCHEME="ClipBook"
CONFIGURATION="Release"
APP_NAME="ClipBook"
APP_ARCHS="${APP_ARCHS:-arm64 x86_64}"
TEAM_ID="${TEAM_ID:-96B3X7S47C}"
BASE_URL="${BASE_URL:-https://f005.backblazeb2.com/file/clipbook/}"
NOTARIZATION_PROFILE="${NOTARIZATION_PROFILE:-ClipBookNotaryProfile}"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-ed25519}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData/Release}"
RELEASE_ROOT="$ROOT_DIR/Releases"
APPCAST_DIR="${APPCAST_DIR:-$RELEASE_ROOT/appcast}"
LICENSING_PACKAGE_PATH="${LICENSING_PACKAGE_PATH:-$ROOT_DIR/../ClipBook-Licensing}"
GENERATED_COMMERCIAL_LICENSING_DIR="$ROOT_DIR/ClipBook/GeneratedCommercialLicensing"
SKIP_NOTARIZATION=0
COMMERCIAL_BUILD=0
COMMERCIAL_LICENSING_STAGED=0
VERSION=""
BUILD=""

usage() {
  printf '%s\n' "Usage: ./release.sh --version 2.3.0 [options]"
  printf '%s\n' ""
  printf '%s\n' "Options:"
  printf '%s\n' "  --version VERSION              Marketing version for the release."
  printf '%s\n' "  --build BUILD                  Bundle version for Sparkle comparisons. Default: VERSION without dots (2.3.0 -> 230)."
  printf '%s\n' "  --base-url URL                 Public server root. Default: $BASE_URL."
  printf '%s\n' "  --notarization-profile NAME    notarytool keychain profile. Default: $NOTARIZATION_PROFILE."
  printf '%s\n' "  --team-id TEAM_ID              Apple Developer team ID. Default: $TEAM_ID."
  printf '%s\n' "  --commercial                   Build with commercial licensing enabled."
  printf '%s\n' "  --licensing-package PATH       Path to ClipBook-Licensing. Default: $LICENSING_PACKAGE_PATH."
  printf '%s\n' "  APP_ARCHS=\"arm64 x86_64\"       Architectures to archive. Default: $APP_ARCHS."
  printf '%s\n' "  --skip-notarization            Build local artifacts without notarizing."
  printf '%s\n' "  -h, --help                     Show this help."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --build)
      BUILD="$2"
      shift 2
      ;;
    --base-url)
      BASE_URL="$2"
      shift 2
      ;;
    --notarization-profile)
      NOTARIZATION_PROFILE="$2"
      shift 2
      ;;
    --team-id)
      TEAM_ID="$2"
      shift 2
      ;;
    --commercial)
      COMMERCIAL_BUILD=1
      shift
      ;;
    --licensing-package)
      LICENSING_PACKAGE_PATH="$2"
      shift 2
      ;;
    --skip-notarization)
      SKIP_NOTARIZATION=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  usage >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  printf 'Version must contain only numbers separated by dots, for example 2.3.0.\n' >&2
  exit 1
fi

if [[ -z "$BUILD" ]]; then
  BUILD="$((10#${VERSION//./}))"
fi

if [[ ! "$BUILD" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Build must be a positive integer greater than 0. Sparkle uses it as CFBundleVersion for update comparisons.\n' >&2
  exit 1
fi

read -r -a REQUIRED_APP_ARCHS <<< "$APP_ARCHS"
if [[ "${#REQUIRED_APP_ARCHS[@]}" -eq 0 ]]; then
  printf 'APP_ARCHS must contain at least one architecture.\n' >&2
  exit 1
fi

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required tool is missing: %s\n' "$1" >&2
    exit 1
  fi
}

resolve_sparkle_tool() {
  local tool="$1"
  local candidates=()

  if [[ -n "${SPARKLE_BIN:-}" ]]; then
    candidates+=("$SPARKLE_BIN/$tool")
  fi

  candidates+=("$DERIVED_DATA_PATH/SourcePackages/artifacts/sparkle/Sparkle/bin/$tool")

  shopt -s nullglob
  candidates+=("$DERIVED_DATA_PATH"/SourcePackages/artifacts/*/Sparkle/bin/"$tool")
  candidates+=("$HOME"/Library/Developer/Xcode/DerivedData/*/SourcePackages/artifacts/*/Sparkle/bin/"$tool")
  shopt -u nullglob

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf 'Could not find Sparkle tool: %s\n' "$tool" >&2
  printf 'Set SPARKLE_BIN to the Sparkle bin directory and try again.\n' >&2
  exit 1
}

require_tool xcodebuild
require_tool xcrun
require_tool hdiutil
require_tool ditto

cleanup_dmg_mount() {
  if [[ -d "$MOUNT_PATH" ]]; then
    hdiutil detach "$MOUNT_PATH" >/dev/null 2>&1 || true
    rmdir "$MOUNT_PATH" >/dev/null 2>&1 || true
  fi
}

cleanup_release() {
  cleanup_dmg_mount
  if [[ "$COMMERCIAL_LICENSING_STAGED" -eq 1 ]]; then
    rm -rf "$GENERATED_COMMERCIAL_LICENSING_DIR"
  fi
}

stage_commercial_licensing() {
  local source_dir="$LICENSING_PACKAGE_PATH/Sources/ClipBookCommercialLicensing"

  if [[ ! -d "$source_dir" ]]; then
    printf 'Commercial licensing source not found: %s\n' "$source_dir" >&2
    printf 'Pass --licensing-package PATH or set LICENSING_PACKAGE_PATH.\n' >&2
    exit 1
  fi

  printf 'Staging commercial licensing source from %s.\n' "$source_dir"
  rm -rf "$GENERATED_COMMERCIAL_LICENSING_DIR"
  mkdir -p "$GENERATED_COMMERCIAL_LICENSING_DIR"
  ditto "$source_dir" "$GENERATED_COMMERCIAL_LICENSING_DIR"
  COMMERCIAL_LICENSING_STAGED=1
  trap cleanup_release EXIT
}

BASE_URL="${BASE_URL%/}"
RELEASE_ID="$VERSION-$BUILD"
WORK_DIR="$RELEASE_ROOT/$RELEASE_ID"
ARCHIVE_PATH="$WORK_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$WORK_DIR/export"
STAGING_PATH="$WORK_DIR/dmg-staging"
MOUNT_PATH="$WORK_DIR/dmg-mount"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$WORK_DIR/$DMG_NAME"
RW_DMG_PATH="$WORK_DIR/$APP_NAME-$VERSION-rw.dmg"
EXPORT_OPTIONS_PATH="$WORK_DIR/ExportOptions.plist"

printf 'Preparing release %s build %s.\n' "$VERSION" "$BUILD"
if [[ "$COMMERCIAL_BUILD" -eq 1 ]]; then
  printf 'Commercial licensing is enabled for this release.\n'
  stage_commercial_licensing
else
  printf 'Commercial licensing is disabled for this release.\n'
fi
printf 'Cleaning %s.\n' "$RELEASE_ROOT"
rm -rf "$RELEASE_ROOT"
mkdir -p "$WORK_DIR" "$EXPORT_PATH" "$STAGING_PATH" "$APPCAST_DIR"

cat > "$EXPORT_OPTIONS_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>$TEAM_ID</string>
</dict>
</plist>
PLIST

printf 'Resolving package dependencies.\n'
xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -derivedDataPath "$DERIVED_DATA_PATH"

GENERATE_APPCAST="$(resolve_sparkle_tool generate_appcast)"

printf 'Archiving app.\n'
ARCHIVE_BUILD_SETTINGS=(
  ARCHS="$APP_ARCHS"
  ONLY_ACTIVE_ARCH=NO
  MARKETING_VERSION="$VERSION"
  CURRENT_PROJECT_VERSION="$BUILD"
)
if [[ "$COMMERCIAL_BUILD" -eq 1 ]]; then
  ARCHIVE_BUILD_SETTINGS+=(
    SWIFT_ACTIVE_COMPILATION_CONDITIONS="CLIPBOOK_COMMERCIAL CLIPBOOK_COMMERCIAL_IN_TREE \$(inherited)"
  )
fi

xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  "${ARCHIVE_BUILD_SETTINGS[@]}"

printf 'Exporting Developer ID app.\n'
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PATH"

APP_PATH="$EXPORT_PATH/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  printf 'Expected exported app not found: %s\n' "$APP_PATH" >&2
  exit 1
fi

APP_BINARY_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
if [[ ! -x "$APP_BINARY_PATH" ]]; then
  printf 'Expected app executable not found: %s\n' "$APP_BINARY_PATH" >&2
  exit 1
fi

printf 'Verifying universal executable.\n'
# lipo in Xcode 27 accepts a single architecture per -verify_arch invocation.
for required_arch in "${REQUIRED_APP_ARCHS[@]}"; do
  xcrun lipo "$APP_BINARY_PATH" -verify_arch "$required_arch"
done

printf 'Creating disk image layout.\n'
ditto "$APP_PATH" "$STAGING_PATH/$APP_NAME.app"
ln -s /Applications "$STAGING_PATH/Applications"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING_PATH" \
  -fs HFS+ \
  -ov \
  -format UDRW \
  "$RW_DMG_PATH"

mkdir -p "$MOUNT_PATH"
hdiutil attach "$RW_DMG_PATH" \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$MOUNT_PATH"
trap cleanup_release EXIT

rm -rf "$MOUNT_PATH/.fseventsd" "$MOUNT_PATH/.Spotlight-V100" "$MOUNT_PATH/.Trashes"

osascript <<APPLESCRIPT
set dmgFolder to POSIX file "$MOUNT_PATH" as alias

tell application "Finder"
  open dmgFolder
  delay 1
  set dmgWindow to container window of dmgFolder
  set current view of dmgWindow to icon view
  set toolbar visible of dmgWindow to false
  set statusbar visible of dmgWindow to false
  set the bounds of dmgWindow to {100, 100, 720, 500}
  set arrangement of icon view options of dmgWindow to not arranged
  set icon size of icon view options of dmgWindow to 128
  set text size of icon view options of dmgWindow to 16
  set position of item "$APP_NAME.app" of dmgFolder to {170, 160}
  set position of item "Applications" of dmgFolder to {450, 160}
  update dmgFolder without registering applications
  delay 1
  close dmgWindow
  end tell
APPLESCRIPT

rm -rf "$MOUNT_PATH/.fseventsd" "$MOUNT_PATH/.Spotlight-V100" "$MOUNT_PATH/.Trashes"
sync
hdiutil detach "$MOUNT_PATH"
rmdir "$MOUNT_PATH"

printf 'Compressing disk image.\n'
hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"
rm -f "$RW_DMG_PATH"

if [[ "$SKIP_NOTARIZATION" -eq 0 ]]; then
  printf 'Submitting disk image for notarization.\n'
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARIZATION_PROFILE" \
    --wait

  printf 'Stapling notarization ticket.\n'
  xcrun stapler staple "$DMG_PATH"
else
  printf 'Skipping notarization. Do not publish this artifact as an official release.\n'
fi

printf 'Updating Sparkle appcast source.\n'
cp "$DMG_PATH" "$APPCAST_DIR/$DMG_NAME"

"$GENERATE_APPCAST" \
  --account "$SPARKLE_ACCOUNT" \
  --download-url-prefix "$BASE_URL/" \
  --maximum-versions 1 \
  "$APPCAST_DIR"

printf '\nRelease artifacts are ready.\n'
printf 'Upload the contents of this directory to %s/:\n' "$BASE_URL"
printf '  %s\n' "$APPCAST_DIR"
printf '\nImportant files:\n'
printf '  %s\n' "$APPCAST_DIR/appcast.xml"
printf '  %s\n' "$APPCAST_DIR/$DMG_NAME"

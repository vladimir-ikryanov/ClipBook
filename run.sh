#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/ClipBook.xcodeproj"
SCHEME="ClipBook"
APP_NAME="ClipBook"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-}"
CLEAN=0
BUILD_ONLY=0
FOREGROUND=0

usage() {
  printf '%s\n' "Usage: ./run.sh [options]"
  printf '%s\n' ""
  printf '%s\n' "Builds ClipBook and relaunches it, so a change can be tested right away."
  printf '%s\n' ""
  printf '%s\n' "Options:"
  printf '%s\n' "  --configuration NAME   Build configuration. Default: $CONFIGURATION."
  printf '%s\n' "  --clean                Clean the build before rebuilding."
  printf '%s\n' "  --build-only           Build without launching the app."
  printf '%s\n' "  --foreground           Run the binary in this terminal so its output"
  printf '%s\n' "                         streams here and Ctrl+C quits it."
  printf '%s\n' "  DERIVED_DATA_PATH=DIR  Build location. Default: DerivedData/<configuration>."
  printf '%s\n' "  -h, --help             Show this help."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --clean)
      CLEAN=1
      shift
      ;;
    --build-only)
      BUILD_ONLY=1
      shift
      ;;
    --foreground)
      FOREGROUND=1
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

if [[ -z "$DERIVED_DATA_PATH" ]]; then
  DERIVED_DATA_PATH="$ROOT_DIR/DerivedData/$CONFIGURATION"
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_PATH/Contents/MacOS/$APP_NAME"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required tool is missing: %s\n' "$1" >&2
    exit 1
  fi
}

require_tool xcodebuild

# Only development builds are stopped. A copy installed in /Applications is left
# alone, so a rebuild never quits the ClipBook the user actually runs day to day.
quit_development_instances() {
  local pids=()
  local pid
  local path

  while read -r pid path; do
    case "$path" in
      /Applications/*)
        continue
        ;;
    esac
    pids+=("$pid")
  done < <(ps -axo pid=,comm= | grep -F "/$APP_NAME.app/Contents/MacOS/$APP_NAME" || true)

  if [[ "${#pids[@]}" -eq 0 ]]; then
    return 0
  fi

  printf 'Quitting running development instance(s): %s\n' "${pids[*]}"
  kill "${pids[@]}" 2>/dev/null || true

  # The app writes its history on the way out, so it is given a moment to
  # finish before anything harsher.
  local waited=0
  local alive
  while [[ "$waited" -lt 50 ]]; do
    alive=0
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        alive=1
        break
      fi
    done
    if [[ "$alive" -eq 0 ]]; then
      return 0
    fi
    sleep 0.1
    waited=$((waited + 1))
  done

  kill -9 "${pids[@]}" 2>/dev/null || true
}

run_xcodebuild() {
  # xcbeautify and xcpretty are only ever nice-to-have here: without one of
  # them the raw xcodebuild log is still perfectly usable.
  if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild "$@" | xcbeautify
  elif command -v xcpretty >/dev/null 2>&1; then
    xcodebuild "$@" | xcpretty
  else
    xcodebuild "$@"
  fi
}

BUILD_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination 'platform=macOS'
  -derivedDataPath "$DERIVED_DATA_PATH"
)

if [[ "$CLEAN" -eq 1 ]]; then
  printf 'Cleaning %s build.\n' "$CONFIGURATION"
  run_xcodebuild "${BUILD_ARGS[@]}" clean
fi

printf 'Building %s (%s).\n' "$APP_NAME" "$CONFIGURATION"
run_xcodebuild "${BUILD_ARGS[@]}" build

if [[ ! -d "$APP_PATH" ]]; then
  printf 'Build finished but the app is missing: %s\n' "$APP_PATH" >&2
  exit 1
fi

printf 'Built %s\n' "$APP_PATH"

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  exit 0
fi

quit_development_instances

if [[ "$FOREGROUND" -eq 1 ]]; then
  printf 'Running %s in this terminal. Press Ctrl+C to quit.\n' "$APP_NAME"
  exec "$APP_BINARY"
fi

# -n forces a fresh instance rather than activating whichever ClipBook macOS
# already knows about.
open -n "$APP_PATH"
printf 'Launched %s.\n' "$APP_NAME"

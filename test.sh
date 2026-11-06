#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/ClipBook.xcodeproj"
SCHEME="ClipBook"
# The tests use `@testable import`, which needs the Debug configuration.
CONFIGURATION="Debug"
CLEAN=0
NO_PARALLEL=0
FILTER_PATTERNS=()

usage() {
  printf '%s\n' "Usage: ./test.sh [options]"
  printf '%s\n' ""
  printf '%s\n' "Builds ClipBook and runs the ClipBookTests Swift Testing suite with xcodebuild."
  printf '%s\n' ""
  printf '%s\n' "Options:"
  printf '%s\n' "  --filter IDENTIFIER      Run only the given test suite or test, for example"
  printf '%s\n' "                           DomainAndSensitiveContentTests. Repeat to run several."
  printf '%s\n' "                           A suite inside another type is named by its path, as in"
  printf '%s\n' "                           DomainAndSensitiveContentTests/SensitiveContentTests. A"
  printf '%s\n' "                           single test needs its parentheses, as in Suite/test()."
  printf '%s\n' "  --no-parallel            Disable parallel test execution."
  printf '%s\n' "  --record-snapshots       Re-record the reference images in ClipBookTests/Snapshots."
  printf '%s\n' "                           The run reports failures; review the image diff, then re-run."
  printf '%s\n' "  --clean                  Clean the build before testing."
  printf '%s\n' "  RESULT_BUNDLE_PATH=PATH  Write the .xcresult bundle, including test"
  printf '%s\n' "                           attachments such as view snapshots, to PATH, which"
  printf '%s\n' "                           must not exist yet."
  printf '%s\n' "  -h, --help               Show this help."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      CLEAN=1
      shift
      ;;
    --filter)
      if [[ $# -lt 2 ]]; then
        printf -- '--filter needs an identifier.\n\n' >&2
        usage >&2
        exit 1
      fi
      FILTER_PATTERNS+=("$2")
      shift 2
      ;;
    --no-parallel)
      NO_PARALLEL=1
      shift
      ;;
    --record-snapshots)
      # xcodebuild passes TEST_RUNNER_* variables to the tests without the prefix.
      export TEST_RUNNER_RECORD_SNAPSHOTS=1
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

if ! xcodebuild -version >/dev/null 2>&1; then
  printf 'xcodebuild needs a full Xcode installation. Install Xcode and select it with xcode-select.\n' >&2
  exit 1
fi

XCODEBUILD_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination 'platform=macOS'
  "CODE_SIGN_STYLE=Manual"
  "DEVELOPMENT_TEAM="
  "CODE_SIGN_IDENTITY=-"
)

if [[ "$NO_PARALLEL" -eq 1 ]]; then
  XCODEBUILD_ARGS+=(-parallel-testing-enabled NO)
fi

if [[ -n "${RESULT_BUNDLE_PATH:-}" ]]; then
  XCODEBUILD_ARGS+=(-resultBundlePath "$RESULT_BUNDLE_PATH")
fi

for pattern in ${FILTER_PATTERNS[@]+"${FILTER_PATTERNS[@]}"}; do
  XCODEBUILD_ARGS+=("-only-testing:ClipBookTests/$pattern")
done

# Each throwaway defaults suite of the tests leaves an empty preferences file behind.
remove_test_preferences() {
  rm -f "$HOME"/Library/Preferences/com.ikryanov.clipbook.{coordinator.tests,tests,apptests}.*.plist
}
OUTPUT_FILE=""
trap 'rm -f "$OUTPUT_FILE"; remove_test_preferences' EXIT

ACTIONS=(test)
if [[ "$CLEAN" -eq 1 ]]; then
  ACTIONS=(clean test)
fi

if [[ ${#FILTER_PATTERNS[@]} -eq 0 ]]; then
  xcodebuild "${XCODEBUILD_ARGS[@]}" "${ACTIONS[@]}"
  exit 0
fi

# xcodebuild succeeds when a --filter identifier matches no test, so check that something ran.
OUTPUT_FILE="$(mktemp)"
xcodebuild "${XCODEBUILD_ARGS[@]}" "${ACTIONS[@]}" | tee "$OUTPUT_FILE"
UNMATCHED=0
for pattern in "${FILTER_PATTERNS[@]}"; do
  if ! grep -qF "Test case '$pattern" "$OUTPUT_FILE"; then
    printf '\nNo test ran for --filter %s.\n' "$pattern" >&2
    UNMATCHED=1
  fi
done
if [[ "$UNMATCHED" -eq 1 ]]; then
  printf 'Name a suite or test by its path from the top-level type, for example\n' >&2
  printf 'DomainAndSensitiveContentTests/SensitiveContentTests.\n' >&2
  exit 1
fi

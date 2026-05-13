#!/usr/bin/env bash
# LINT-IOS-RELEASE-02 — no_debug_endpoint_in_release
#
# Verify that a release-mode `Runner.app` binary contains zero symbols
# from the Tier 2 debug-state HTTP endpoint. Belt-and-suspenders gate
# behind the three compile-time guards (kDebugMode + dart-define +
# conditional-import facade).
#
# Why this lint exists
# ====================
# `lib/debug/debug_server.dart` is triple-gated in source, but the
# `debug_facade.dart` conditional export pulls the file into the
# dependency graph on any target with `dart.library.io`. Flutter's
# tree-shaker normally removes unreferenced code, but a subtle
# refactor (e.g. an unconditional reference from main.dart) could
# silently restore the symbols in release. App Store review treats an
# embedded HTTP server as a red flag even when dormant.
#
# This check runs `strings(1)` on the release binary and fails if any
# of the debug-endpoint markers appear.
#
# Usage
# =====
#   tools/checks/no_debug_endpoint_in_release.sh [<path-to-Runner.app>]
#
# Default path: apps/mobile/build/ios/iphoneos/Runner.app
# CI hook: testflight.yml runs this immediately after
# `flutter build ios --release`, before fastlane sign+upload.
#
# Exit codes
# ==========
#   0 — clean (no debug-endpoint symbols found)
#   1 — debug-endpoint symbols detected (CI-blocking)
#   2 — binary not found / cannot read (configuration error)
set -euo pipefail

DEFAULT_APP="apps/mobile/build/ios/iphoneos/Runner.app"
APP_PATH="${1:-$DEFAULT_APP}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "::error::Runner.app not found at $APP_PATH" >&2
  echo "Pass an explicit path or run 'flutter build ios --release' first." >&2
  exit 2
fi

BIN="$APP_PATH/Runner"
if [[ ! -f "$BIN" ]]; then
  echo "::error::Runner binary not found at $BIN" >&2
  exit 2
fi

# Symbols that MUST NOT appear in a release binary. Each entry must be
# distinctive enough that a false positive is implausible. Keep this
# list narrow — we want true positives only.
#
# Why each entry:
#   DebugServer            — the Dart class name (mangled but recoverable in strings)
#   /debug/state           — HTTP route literal, copy-pasted into the binary by const eval
#   /debug/health          — same; auth-free port handshake
#   mint_debug.token       — token file name literal
#   ch.mint.debug          — logging tag literal printed on bind
FORBIDDEN_PATTERNS=(
  "DebugServer listening"
  "/debug/state"
  "/debug/health"
  "mint_debug.token"
  "ch.mint.debug"
)

echo "[no_debug_endpoint_in_release] scanning $BIN"
echo "[no_debug_endpoint_in_release] forbidden patterns: ${FORBIDDEN_PATTERNS[*]}"

FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Single strings pass piped through one grep -E for performance — large
# Flutter binaries can be ~50 MB and we don't want N reads.
PATTERN_RE="$(IFS='|'; echo "${FORBIDDEN_PATTERNS[*]}")"
strings "$BIN" | grep -E "$PATTERN_RE" > "$TMP" || true

if [[ -s "$TMP" ]]; then
  echo ""
  echo "::error::Debug-endpoint symbols detected in release binary."
  echo "Matches:"
  sed 's/^/  /' < "$TMP"
  echo ""
  echo "Remediation:"
  echo "  1. Confirm release build did NOT receive --dart-define=MINT_DEBUG_ENDPOINT=true."
  echo "  2. Verify lib/main.dart still gates DebugServer.start() behind 'if (kDebugMode && _debugEndpointEnabled)'."
  echo "  3. Check that nothing outside lib/debug/ references DebugServer or state_surfaces directly."
  echo "  4. If a legitimate reference was added, justify in a follow-up commit and update the FORBIDDEN_PATTERNS allowlist."
  FAIL=1
fi

if [[ $FAIL -eq 0 ]]; then
  echo "[no_debug_endpoint_in_release] clean — release binary contains no debug-endpoint symbols."
fi

exit $FAIL

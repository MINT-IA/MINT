#!/usr/bin/env bash
# =============================================================================
# build_a14.sh — Galaxy A14 release APK build + optional install + launch
# =============================================================================
# Phase 10.5 Friction Pass 1 — MINT v2.2 "La Beauté de Mint"
# Per D-01 (.planning/phases/10.5-friction-pass-1/10.5-CONTEXT.md):
#   Build profile MUST be `release` (not debug, not profile). A release APK
#   is what a real user installs from Play Store. Honest measurement only.
#
# Usage (run from repo root):
#   tools/scripts/build_a14.sh                       # build only
#   tools/scripts/build_a14.sh --install             # build + adb install -r
#   tools/scripts/build_a14.sh --install --launch    # build + install + launch
#   tools/scripts/build_a14.sh --skip-clean          # skip flutter clean
#
# Exit codes: 0 success, non-zero on build/install failure.
#
# After first use, ensure executable:
#   chmod +x tools/scripts/build_a14.sh
# =============================================================================

set -euo pipefail

SKIP_CLEAN=0
DO_INSTALL=0
DO_LAUNCH=0
PACKAGE_ID="ch.mint.coach"

for arg in "$@"; do
  case "$arg" in
    --skip-clean) SKIP_CLEAN=1 ;;
    --install)    DO_INSTALL=1 ;;
    --launch)     DO_LAUNCH=1 ;;
    -h|--help)
      grep '^# ' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# --- Branch warning (dev rules, CLAUDE.md) -----------------------------------
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo unknown)"
EXPECTED_BRANCH="feature/v2.2-p0a-code-unblockers"
if [[ "$CURRENT_BRANCH" != "$EXPECTED_BRANCH" ]]; then
  echo "WARN: on branch '$CURRENT_BRANCH', expected '$EXPECTED_BRANCH'. Continuing anyway."
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT/apps/mobile"

# --- Build steps -------------------------------------------------------------
if [[ "$SKIP_CLEAN" -eq 0 ]]; then
  echo "==> flutter clean"
  flutter clean
else
  echo "==> skipping flutter clean (--skip-clean)"
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter gen-l10n"
flutter gen-l10n

echo "==> flutter build apk --release --split-per-abi  (D-01: release profile)"
flutter build apk --release --split-per-abi

APK_REL="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
APK_ABS="$REPO_ROOT/apps/mobile/$APK_REL"

if [[ ! -f "$APK_ABS" ]]; then
  echo "ERROR: expected APK not found at $APK_ABS" >&2
  exit 3
fi

APK_SIZE="$(du -h "$APK_ABS" | awk '{print $1}')"
echo ""
echo "==> BUILD OK"
echo "    APK:  $APK_ABS"
echo "    Size: $APK_SIZE"
echo "    Commit: $(git rev-parse --short HEAD)"
echo ""

# --- Optional install --------------------------------------------------------
if [[ "$DO_INSTALL" -eq 1 ]]; then
  if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: adb not found in PATH — install Android platform tools." >&2
    exit 4
  fi
  DEVICE_COUNT="$(adb devices | awk 'NR>1 && $2=="device"' | wc -l | tr -d ' ')"
  if [[ "$DEVICE_COUNT" != "1" ]]; then
    echo "ERROR: expected exactly 1 adb device in state 'device', got $DEVICE_COUNT." >&2
    echo "Run 'adb devices' to debug." >&2
    exit 5
  fi
  echo "==> adb install -r $APK_REL"
  adb install -r "$APK_ABS"
  echo "==> INSTALL OK"
fi

# --- Optional launch ---------------------------------------------------------
if [[ "$DO_LAUNCH" -eq 1 ]]; then
  if [[ "$DO_INSTALL" -eq 0 ]]; then
    echo "WARN: --launch without --install — app may be stale."
  fi
  echo "==> launching $PACKAGE_ID"
  adb shell monkey -p "$PACKAGE_ID" -c android.intent.category.LAUNCHER 1 >/dev/null
  echo "==> LAUNCHED (if this failed, confirm package with: grep applicationId apps/mobile/android/app/build.gradle.kts)"
fi

echo ""
echo "Next steps (per docs/FRICTION_PASS_1/README.md):"
echo "  1. Force-stop the app in Android settings (cold-start discipline)."
echo "  2. Enable Developer Options → Show taps."
echo "  3. Start screen recorder (swipe-down tile) and begin the golden path."
echo "  4. Log frottements in docs/FRICTION_PASS_1.md."

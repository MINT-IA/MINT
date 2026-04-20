#!/usr/bin/env bash
# tools/simulator/walker.sh — Phase 31 J0 simulator driver.
#
# Subset of Phase 35 mint-dogfood.sh — 4 ops on iPhone 17 Pro:
#   boot → install staging build → screenshot → Sentry pull.
#
# Every simctl call is wrapped in `timeout 30s` (Pitfall 8 macOS Tahoe
# simctl flakiness mitigation). macOS Tahoe build doctrine is enforced:
# no destructive cocoapods/flutter reset, no removal of the ios lock
# file. See tools/simulator/README.md for the full discipline.
#
# Usage:
#   bash tools/simulator/walker.sh [mode]
#
# Modes:
#   --quick-screenshot         Boot + install + launch + 1 screenshot (default)
#   --smoke-test-inject-error  Above + inject known error + pull Sentry event
#   --gate-phase-31            Wave 3: smoke-test-inject-error + PII audit
#                              screens (delegates to pii_audit_screens.sh)
#   --admin-routes             Phase 32 MAP-02b / J0 Task 6: rebuild with
#                              ENABLE_ADMIN=1, launch, navigate to
#                              /admin/routes, capture 5 screenshots under
#                              .planning/phases/32-cartographier/screenshots/walker-YYYY-MM-DD/.
#                              Alias: --scenario=admin-routes
#   --scenario=admin-routes    Plan 32-05 canonical form; normalizes to --admin-routes
#
# Required env:
#   SENTRY_DSN_STAGING   (Railway staging env var)
#   SENTRY_AUTH_TOKEN    (Sentry user token, read-only scopes)
#   MINT_WALKER_DEVICE   (optional, defaults to 'iPhone 17 Pro')
#   MINT_WALKER_DRY_RUN  (optional, skip destructive simctl + build;
#                        used by Wave 0 smoke test in CI-hostile envs)
#
set -euo pipefail

DEVICE="${MINT_WALKER_DEVICE:-iPhone 17 Pro}"
# Bundle ID matches Xcode project CFBundleIdentifier (ch.mint.app).
# Previously hardcoded "com.mint.mintMobile" which did not match — simctl
# launch failed with FBSOpenApplicationServiceErrorDomain code=4.
BUNDLE="${MINT_WALKER_BUNDLE:-ch.mint.app}"
MODE="${1:---quick-screenshot}"
DRY_RUN="${MINT_WALKER_DRY_RUN:-0}"

# Phase 32 MAP-02b — admin-routes scenario: accept both the existing
# positional `--admin-routes` flag AND the plan's `--scenario=admin-routes`
# form. Normalize to --admin-routes before dispatch.
if [[ "$MODE" == "--scenario=admin-routes" || "$MODE" == "--scenario" && "${2:-}" == "admin-routes" ]]; then
  MODE="--admin-routes"
fi

TS="$(date +%Y-%m-%d-%H%M%S)"
OUTDIR=".planning/walker/${TS}"
mkdir -p "$OUTDIR"
LOG="$OUTDIR/walker.log"

log() {
  echo "[walker $(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG"
}

log "mode=${MODE} device='${DEVICE}' outdir=${OUTDIR} dry_run=${DRY_RUN}"

# ---------------------------------------------------------------------------
# Portable `timeout` — macOS has no `timeout` out of the box. Prefer GNU
# coreutils `gtimeout`, then `timeout`. Degrade with a WARN if neither is
# available (Pitfall 8 mitigation becomes best-effort, not fatal).
# ---------------------------------------------------------------------------
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
else
  TIMEOUT_BIN=""
  log "WARN: neither gtimeout nor timeout found — simctl calls unbounded."
  log "WARN: install via: brew install coreutils"
fi
to() {
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "$@"
  else
    # Drop the first arg (duration like 30s) and run the rest bare.
    shift
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# 0. Auth token — accept env var OR Keychain fallback (per README).
# ---------------------------------------------------------------------------
if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
  if command -v security >/dev/null 2>&1; then
    KEYCHAIN_TOKEN="$(security find-generic-password -s SENTRY_AUTH_TOKEN -w 2>/dev/null || true)"
    if [ -n "$KEYCHAIN_TOKEN" ]; then
      export SENTRY_AUTH_TOKEN="$KEYCHAIN_TOKEN"
      log "SENTRY_AUTH_TOKEN loaded from Keychain"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 1. Boot iPhone 17 Pro (idempotent). Each simctl call timeout-wrapped.
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
  log "DRY_RUN=1 — skipping simctl boot/erase/build/install/launch"
else
  log "boot: shutdown all + erase + boot '${DEVICE}'"
  to 30s xcrun simctl shutdown all || true
  to 30s xcrun simctl erase "$DEVICE" || true
  to 30s xcrun simctl boot "$DEVICE"
  open -a Simulator || true

  # -------------------------------------------------------------------------
  # 2. Build + install staging. Respect macOS Tahoe doctrine: no destructive
  #    flutter reset, no removal of the ios cocoapods lock file — see
  #    tools/simulator/README.md (feedback_ios_build_macos_tahoe.md).
  #    Staging always — feedback_app_targets_staging_always.md.
  # -------------------------------------------------------------------------
  : "${SENTRY_DSN_STAGING:?SENTRY_DSN_STAGING required for simulator build}"

  log "build: flutter build ios --simulator --no-codesign (staging dart-defines, macOS Tahoe)"
  (cd apps/mobile && flutter build ios --simulator --no-codesign \
    --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
    --dart-define=SENTRY_DSN="${SENTRY_DSN_STAGING}") 2>&1 | tee -a "$LOG"

  APP_PATH="apps/mobile/build/ios/iphonesimulator/Runner.app"
  if [ ! -d "$APP_PATH" ]; then
    log "FAIL: Runner.app not found at $APP_PATH"
    exit 1
  fi

  log "install: simctl install ${DEVICE} ${APP_PATH}"
  to 60s xcrun simctl install "$DEVICE" "$APP_PATH"

  log "launch: simctl launch ${DEVICE} ${BUNDLE}"
  to 30s xcrun simctl launch "$DEVICE" "$BUNDLE"

  sleep 5
  log "screenshot: ${OUTDIR}/launch.png"
  to 10s xcrun simctl io "$DEVICE" screenshot "${OUTDIR}/launch.png"
fi

# ---------------------------------------------------------------------------
# 3. Mode dispatch.
# ---------------------------------------------------------------------------
case "$MODE" in
  --quick-screenshot)
    log "--quick-screenshot done → ${OUTDIR}"
    ;;

  --gate-phase-31)
    # Wave 3: OBS-06 PII audit gate — smoke-test-inject-error + navigate
    # through the 5 sensitive screens capturing one screenshot each.
    # Visual mask verification (the actual audit) happens in Sentry UI
    # Replay afterwards; this script only captures proof-of-reach state.
    log "gate-phase-31: delegating to --smoke-test-inject-error"
    bash "$0" --smoke-test-inject-error
    log "gate-phase-31: delegating to pii_audit_screens.sh"
    bash tools/simulator/pii_audit_screens.sh
    log "gate-phase-31: smoke + pii-audit complete"
    log "gate-phase-31: BLOCKING next step — manual Sentry UI replay review"
    log "gate-phase-31: commit findings to .planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md"
    ;;

  --admin-routes)
    # Phase 32 MAP-02b / D-11 J0 Task 6 — admin-routes smoke scenario.
    # Rebuild the booted simulator with --dart-define=ENABLE_ADMIN=1 on
    # top of the staging API URL, reinstall Runner.app, launch the bundle,
    # navigate to /admin/routes, and capture 5 screenshots.
    #
    # The prior stage (boot/erase/build/install/launch at top of this
    # script) already produced a staging Runner.app WITHOUT ENABLE_ADMIN.
    # This mode rebuilds with both defines so the admin shell compiles in.
    if [ "$DRY_RUN" = "1" ]; then
      log "admin-routes: DRY_RUN=1 — skipping admin rebuild + navigate"
      log "admin-routes: (dry-run) would have built with --dart-define=ENABLE_ADMIN=1"
    else
      : "${SENTRY_DSN_STAGING:?SENTRY_DSN_STAGING required for admin-routes build}"

      ADMIN_OUT=".planning/phases/32-cartographier/screenshots/walker-$(date +%Y-%m-%d)"
      mkdir -p "$ADMIN_OUT"
      log "admin-routes: output dir ${ADMIN_OUT}"

      log "admin-routes: flutter build ios --simulator --no-codesign with ENABLE_ADMIN=1 (macOS Tahoe)"
      (cd apps/mobile && flutter build ios --simulator --no-codesign \
        --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
        --dart-define=SENTRY_DSN="${SENTRY_DSN_STAGING}" \
        --dart-define=ENABLE_ADMIN=1) 2>&1 | tee -a "$LOG"

      ADMIN_APP="apps/mobile/build/ios/iphonesimulator/Runner.app"
      if [ ! -d "$ADMIN_APP" ]; then
        log "FAIL: admin Runner.app not found at $ADMIN_APP"
        exit 1
      fi

      log "admin-routes: simctl install (re-install with ENABLE_ADMIN=1)"
      to 60s xcrun simctl install "$DEVICE" "$ADMIN_APP"

      log "admin-routes: simctl launch ${BUNDLE}"
      to 30s xcrun simctl launch "$DEVICE" "$BUNDLE"
      sleep 6

      # Attempt deep link first. The app may not yet declare a mint://
      # URL scheme — a soft failure here is acceptable; the operator can
      # navigate manually between screenshots.
      log "admin-routes: simctl openurl mint://admin/routes"
      if to 10s xcrun simctl openurl "$DEVICE" "mint://admin/routes" 2>>"$LOG"; then
        log "admin-routes: deep link accepted"
      else
        log "WARN: deep link failed — operator may need to navigate manually between shots"
      fi

      # Capture 5 screenshots at 2 s intervals. The operator can scroll
      # through owner buckets between shots if the screen is live.
      for i in 1 2 3 4 5; do
        sleep 2
        SHOT="${ADMIN_OUT}/admin-routes-${i}.png"
        if to 10s xcrun simctl io "$DEVICE" screenshot "$SHOT" 2>>"$LOG"; then
          log "admin-routes: captured ${SHOT}"
        else
          log "WARN: screenshot ${i} failed"
        fi
      done

      log "admin-routes: screenshots at ${ADMIN_OUT}"
      ls -la "$ADMIN_OUT" | tee -a "$LOG"
      log "admin-routes: remaining gate — review screenshots + verify mint.admin.routes.viewed breadcrumb in Sentry UI"
    fi
    ;;

  --smoke-test-inject-error)
    # Generate a known 32-hex trace_id we can grep for in Sentry events.
    TRACE_ID="$(openssl rand -hex 16)"
    SPAN_ID="$(openssl rand -hex 8)"
    SENTRY_TRACE="${TRACE_ID}-${SPAN_ID}-1"
    echo "$TRACE_ID" > "${OUTDIR}/trace_id.txt"
    log "smoke: inject error with sentry-trace=${SENTRY_TRACE}"

    # Primary: hit the dedicated test endpoint (may not exist yet — Plan
    # 31-02 adds it). Fallback: POST malformed JSON to /auth/login to
    # exercise the existing global exception handler.
    PRIMARY_STATUS="$(curl -s -o "${OUTDIR}/inject_primary.body" -w '%{http_code}' \
      -X POST https://mint-staging.up.railway.app/api/v1/_test/inject_error \
      -H "sentry-trace: ${SENTRY_TRACE}" \
      -H 'content-type: application/json' \
      --max-time 15 || echo '000')"
    log "smoke: primary /_test/inject_error HTTP=${PRIMARY_STATUS}"

    if [ "$PRIMARY_STATUS" != "200" ] && [ "$PRIMARY_STATUS" != "500" ]; then
      log "smoke: primary endpoint absent (Open Question #4) — fallback to malformed /auth/login"
      FALLBACK_STATUS="$(curl -s -o "${OUTDIR}/inject_fallback.body" -w '%{http_code}' \
        -X POST https://mint-staging.up.railway.app/api/v1/auth/login \
        -H "sentry-trace: ${SENTRY_TRACE}" \
        -H 'content-type: application/json' \
        --data-raw '{"email": "not-an-email", "password":' \
        --max-time 15 || echo '000')"
      log "smoke: fallback /auth/login HTTP=${FALLBACK_STATUS}"
    fi

    # Let Sentry ingest.
    log "smoke: sleep 60s for Sentry ingestion"
    sleep 60

    # Pull events (auth token optional — script tolerates missing token
    # so Wave 0 can exercise the happy path on this dev host).
    if [ -n "${SENTRY_AUTH_TOKEN:-}" ]; then
      log "smoke: pull events via sentry-cli api"
      sentry-cli api "/projects/mint/mint-backend/events/?statsPeriod=15m" \
        --auth-token "${SENTRY_AUTH_TOKEN}" \
        > "${OUTDIR}/sentry-events.json" 2>>"$LOG" || {
          log "WARN: sentry-cli api failed — events.json will be empty"
          echo '[]' > "${OUTDIR}/sentry-events.json"
        }
      # Assert the trace_id round-tripped.
      python3 tools/simulator/assert_event_round_trip.py \
        "${OUTDIR}/sentry-events.json" "${TRACE_ID}" \
        && log "smoke: round-trip PASS" \
        || log "smoke: round-trip FAIL (trace_id ${TRACE_ID} not in events)"
    else
      log "WARN: SENTRY_AUTH_TOKEN not set — skipping event pull"
      echo '[]' > "${OUTDIR}/sentry-events.json"
    fi
    ;;

  *)
    log "FAIL: unknown mode '${MODE}' (expect --quick-screenshot | --smoke-test-inject-error | --gate-phase-31 | --admin-routes | --scenario=admin-routes)"
    exit 2
    ;;
esac

log "walker.sh: done → ${OUTDIR}"

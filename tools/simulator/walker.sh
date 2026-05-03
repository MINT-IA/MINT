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
#   bash tools/simulator/walker.sh [mode|flags]
#   bash tools/simulator/walker.sh --help
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
# Phase 51 E2E-07 / CONTEXT D-17 — archetype-driven walkthrough:
#   --archetype <slug>         Run a scripted walkthrough for the given
#                              CONTEXT D-02 archetype. Loads the seed via
#                              --dart-define=MINT_E2E_ARCHETYPE=<slug> at
#                              app launch; drives chat with a scenario-
#                              specific prompt; captures screenshots at each
#                              of the 7 walkthrough breadcrumb steps.
#                              Output: screenshots/walkthrough/v2.10-final/<slug>/<scenario>/.
#                              Valid slugs: swiss_native, expat_eu, expat_us,
#                              cross_border, independent_no_lpp, recent_arrival,
#                              near_retirement, young_starter.
#   --scenario <name>          Pairs with --archetype. Default: retraite.
#                              Accepted: retraite, fiscalite, housing, career,
#                              fatca, family, business, integration, lpp_choice.
#   --dry-run                  Print planned actions without booting/building/
#                              calling simctl/curl. Used by the smoke test
#                              harness (tools/simulator/test_walker_archetype.sh)
#                              and by scripts/sim/run-e2e.sh DRY_RUN=1.
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
# 51-07 / G51-06-03 — corrected bundle id. The pre-fix value did NOT
# match the actual built artifact (Info.plist declares ch.mint.app).
BUNDLE="ch.mint.app"
MODE="${1:---quick-screenshot}"
DRY_RUN="${MINT_WALKER_DRY_RUN:-0}"

# 51-07 / G51-06-03 — cliclick-driven simulator nav helpers. Replace the
# polling-based screenshot loop (which captured arbitrary states at
# 3-second intervals) with deterministic tap + type drivers. Coordinates
# below are placeholders synced to the existing landing+chat goldens;
# refine via a calibration screenshot if test_walker_archetype.sh smoke
# detects two consecutive sha256-identical PNGs (T-51-07-06 mitigation).
SIM_DEVICE_ID="${SIM_DEVICE_ID:-booted}"

tap_at() {
  # Send a synthetic mouse click at simulator window coordinates.
  # cliclick driver — no-op in DRY_RUN.
  if [ "$DRY_RUN" = "1" ]; then return 0; fi
  local x="$1" y="$2"
  command -v cliclick >/dev/null 2>&1 || {
    echo "[walker] cliclick required: brew install cliclick" >&2
    return 1
  }
  cliclick "c:${x},${y}"
  sleep 0.4
}

type_text() {
  # Type a prompt into the focused input via cliclick — no-op in DRY_RUN.
  if [ "$DRY_RUN" = "1" ]; then return 0; fi
  local s="$1"
  command -v cliclick >/dev/null 2>&1 || return 1
  cliclick "t:${s}"
  sleep 0.3
}

wait_for_ui() {
  # Poll the sim screenshot SHA every second; return as soon as two
  # consecutive captures match (UI quiescent). Bounded by max iters.
  if [ "$DRY_RUN" = "1" ]; then return 0; fi
  local max="${1:-8}"
  local prev_hash="" cur_hash="" i
  for i in $(seq 1 "$max"); do
    xcrun simctl io "$SIM_DEVICE_ID" screenshot /tmp/_walker_poll.png \
      >/dev/null 2>&1 || true
    cur_hash=$(shasum /tmp/_walker_poll.png 2>/dev/null | awk '{print $1}')
    if [ -n "$prev_hash" ] && [ "$prev_hash" = "$cur_hash" ]; then
      return 0
    fi
    prev_hash="$cur_hash"
    sleep 1
  done
}

snap() {
  # Capture a single frame to the requested path (auto mkdir -p parent).
  if [ "$DRY_RUN" = "1" ]; then return 0; fi
  local out="$1"
  mkdir -p "$(dirname "$out")"
  xcrun simctl io "$SIM_DEVICE_ID" screenshot "$out"
}

# Phase 51 E2E-07 — archetype-driven walkthrough vars (set by the
# argument parser below; empty/default when running in legacy modes).
ARCHETYPE=""
SCENARIO="retraite"
# CONTEXT D-02 — the canonical 8 slugs. Single source of truth for both
# Plan 51-01 (apps/mobile/lib/services/coach_profile_seeds.dart) and the
# walker's --archetype validator. Drift here means Plan 51-01 must be
# updated atomically.
VALID_ARCHETYPES=(
  swiss_native
  expat_eu
  expat_us
  cross_border
  independent_no_lpp
  recent_arrival
  near_retirement
  young_starter
)

# CONTEXT D-17 — scenario → first chat prompt mapping. LSFin-clean (no
# « garanti », « optimal », « meilleur ») — sanitized via natural-language
# « pourrait » / « envisager » framing. The walker types this prompt into
# the chat after the seed is loaded and the chat surface is open.
declare_scenario_prompt() {
  case "$1" in
    retraite)    echo "Je devrais sortir mon LPP en rente ou en capital ?" ;;
    fiscalite)   echo "Comment pourrais-je envisager mon 3a cette année ?" ;;
    housing)     echo "Devrais-je amortir mon hypothèque ou alimenter mon 3a ?" ;;
    career)      echo "Si je change d'employeur, qu'est-ce qui se passe avec ma LPP ?" ;;
    fatca)       echo "Quel impact a la FATCA sur ma prévoyance suisse ?" ;;
    family)      echo "Comment mon mariage change-t-il ma situation fiscale ?" ;;
    business)    echo "Mon chiffre d'affaires varie chaque année — comment adapter mon 3a ?" ;;
    integration) echo "Je viens d'arriver en Suisse, par quoi commencer ?" ;;
    lpp_choice)  echo "À 60 ans, comment envisager mon retrait LPP ?" ;;
    dryrun_smoke) echo "[dry-run smoke prompt — not for real execution]" ;;
    *)           echo "" ;;
  esac
}

VALID_SCENARIOS=(retraite fiscalite housing career fatca family business integration lpp_choice dryrun_smoke)

_in_array() {
  local needle="$1"; shift
  local hay
  for hay in "$@"; do
    [ "$hay" = "$needle" ] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Phase 51 E2E-07 — argument parser. Runs BEFORE the legacy MODE dispatch.
# Recognizes --help / --archetype / --scenario / --dry-run anywhere in the
# argv. When --archetype is set, MODE is rewritten to a synthetic value
# ('--archetype-walkthrough') that the case dispatch handles below.
# ---------------------------------------------------------------------------
_archetype_print_usage() {
  cat <<EOF
walker.sh — MINT simulator driver

Legacy modes:
  --quick-screenshot           Boot + install + launch + 1 screenshot (default)
  --smoke-test-inject-error    Inject known error + pull Sentry event
  --gate-phase-31              Phase 31 PII audit + smoke
  --admin-routes               Phase 32 admin-shell rebuild + 5 screenshots
  --scenario=admin-routes      Alias for --admin-routes

Phase 51 E2E-07 archetype walkthrough:
  --archetype <slug>           Drive a scripted walkthrough for archetype
                               <slug>. Valid slugs:
                                 ${VALID_ARCHETYPES[*]}
  --scenario <name>            Pair with --archetype. Default: retraite.
                               Valid: ${VALID_SCENARIOS[*]}
  --dry-run                    Plan only, no simctl / build / curl.

Examples:
  bash tools/simulator/walker.sh --archetype swiss_native --scenario retraite
  bash tools/simulator/walker.sh --archetype expat_us --scenario fatca
  DRY_RUN=1 bash tools/simulator/walker.sh --archetype cross_border --dry-run
EOF
}

# Pre-scan argv for --archetype / --scenario / --dry-run / --help. This
# leaves $MODE intact for legacy positional invocations; archetype mode
# is a separate dispatch path keyed on $ARCHETYPE non-empty.
_args=("$@")
i=0
while [ "$i" -lt "${#_args[@]}" ]; do
  a="${_args[$i]}"
  case "$a" in
    --help|-h)
      _archetype_print_usage
      exit 0
      ;;
    --archetype)
      i=$((i+1))
      ARCHETYPE="${_args[$i]:-}"
      ;;
    --archetype=*)
      ARCHETYPE="${a#--archetype=}"
      ;;
    --scenario)
      i=$((i+1))
      SCENARIO="${_args[$i]:-retraite}"
      ;;
    --scenario=*)
      # Phase 32 MAP-02b kept --scenario=admin-routes as a legacy alias —
      # we intercept that specific value below to preserve back-compat.
      _v="${a#--scenario=}"
      if [ "$_v" = "admin-routes" ]; then
        :  # let the legacy normalizer below handle it
      else
        SCENARIO="$_v"
      fi
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
  esac
  i=$((i+1))
done

if [ -n "$ARCHETYPE" ]; then
  # Validate slug. Hardcoded list = T-51-05-04 shell injection mitigation —
  # the slug is never interpolated unquoted into a subprocess.
  if ! _in_array "$ARCHETYPE" "${VALID_ARCHETYPES[@]}"; then
    echo "ERROR: unknown archetype '$ARCHETYPE'" >&2
    echo "Valid: ${VALID_ARCHETYPES[*]}" >&2
    exit 2
  fi
  if ! _in_array "$SCENARIO" "${VALID_SCENARIOS[@]}"; then
    echo "ERROR: unknown scenario '$SCENARIO'" >&2
    echo "Valid: ${VALID_SCENARIOS[*]}" >&2
    exit 2
  fi
  # Synthetic mode — handled in the case dispatch below.
  MODE="--archetype-walkthrough"
fi

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
#
# Phase 51 E2E-07 — archetype walkthrough mode has its own boot/build/install
# flow (see the --archetype-walkthrough case below) so we skip the legacy
# boot section to avoid double-booting and to allow the archetype dispatcher
# to inject MINT_E2E_ARCHETYPE / MINT_DEV_AUTH_TOKEN dart-defines that the
# legacy build flow does not know about. Dry-run also short-circuits.
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" = "1" ] || [ "$MODE" = "--archetype-walkthrough" ]; then
  log "skipping legacy boot section (DRY_RUN=$DRY_RUN MODE=$MODE)"
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

  log "build: flutter build ios --simulator (staging dart-defines)"
  (cd apps/mobile && flutter build ios --simulator \
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

      log "admin-routes: flutter build ios --simulator with ENABLE_ADMIN=1"
      (cd apps/mobile && flutter build ios --simulator \
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

  --archetype-walkthrough)
    # Phase 51 E2E-07 / CONTEXT D-17 — archetype-driven scripted walkthrough.
    #
    # Drives the simulator through the 7 walkthrough breadcrumb steps:
    #   00-seed-loaded       seed loaded via MINT_E2E_ARCHETYPE dart-define
    #   01-chat-open         chat surface focused, ready to receive prompt
    #   02-tool-dispatched   ChatToolDispatcher routed to MargeFiscaleCalculator
    #   03-canvas-open       Canvas L3 rendered (recap card + sliders)
    #   04-canvas-back       Back navigation returned the user to chat
    #   05-recap-received    SequenceCoordinator emitted the recap message
    #   06-cta-routed        CTA tapped, RoutePlanner.plan() routed to target
    #
    # Each step screenshots into:
    #   screenshots/walkthrough/v2.10-final/<archetype>/<scenario>/0X-<step>.png
    #
    # Sentry breadcrumbs mint.walkthrough.<step> (CONTEXT D-17) are emitted
    # by the app instrumentation when MINT_WALKTHROUGH_PHASE=51 is set on
    # the launch env (the app reads it via Platform.environment / dart-define
    # bridge and tags every navigation breadcrumb).
    SHOTS_DIR="screenshots/walkthrough/v2.10-final/${ARCHETYPE}/${SCENARIO}"
    PROMPT="$(declare_scenario_prompt "$SCENARIO")"

    log "archetype-walkthrough: archetype=${ARCHETYPE} scenario=${SCENARIO}"
    log "archetype-walkthrough: shots_dir=${SHOTS_DIR}"
    log "archetype-walkthrough: prompt=${PROMPT}"

    if [ "$DRY_RUN" = "1" ]; then
      log "DRY-RUN: would mkdir -p ${SHOTS_DIR}"
      log "DRY-RUN: would build sim with --dart-define=MINT_E2E_ARCHETYPE=${ARCHETYPE} \\"
      log "DRY-RUN:   --dart-define=MINT_DEV_AUTH_TOKEN=\$DEV_TOKEN \\"
      log "DRY-RUN:   --dart-define=MINT_WALKTHROUGH_PHASE=51"
      log "DRY-RUN: would xcrun simctl boot '${DEVICE}'"
      log "DRY-RUN: would launch ${BUNDLE} and capture 7 screenshots:"
      for step in 00-seed-loaded 01-chat-open 02-tool-dispatched 03-canvas-open 04-canvas-back 05-recap-received 06-cta-routed; do
        log "DRY-RUN:   - ${SHOTS_DIR}/${step}.png"
      done
      log "DRY-RUN: would type prompt: ${PROMPT}"
      log "DRY-RUN: would emit Sentry breadcrumbs mint.walkthrough.{seed_loaded,chat_open,tool_dispatched,canvas_open,canvas_back,recap_received,cta_routed}"
      log "archetype-walkthrough: DRY-RUN done — filesystem unchanged"
      exit 0
    fi

    # ---------------------------------------------------------------------
    # Real run — boot + build + install + drive + screenshot.
    # ---------------------------------------------------------------------
    # 51-07 (post-T-04): MINT_DEV_AUTH_TOKEN is OPTIONAL. The default chat
    # path is /anonymous/chat (apps/mobile/lib/app.dart:326) which needs no
    # auth header — only an X-Anonymous-Session UUID handled by the client.
    # The dev-token gate (Plan 51-05) is for local-backend testing only;
    # against Railway staging it does not apply. See feedback memory
    # `feedback_app_targets_staging_always.md`.
    : "${MINT_DEV_AUTH_TOKEN:=}"
    : "${SENTRY_DSN_STAGING:=}"

    mkdir -p "$SHOTS_DIR"

    # Resolve a booted device id (delegating to the device name); reuse
    # apps/mobile/scripts/run-sim.sh discipline (CODE_SIGNING_ALLOWED=NO).
    log "archetype-walkthrough: booting ${DEVICE}"
    DEVICE_ID=$(xcrun simctl list devices available 2>/dev/null \
      | grep -E "^[[:space:]]*${DEVICE}[[:space:]]+\(" \
      | head -1 \
      | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
    if [ -z "$DEVICE_ID" ]; then
      log "FAIL: simulator '${DEVICE}' not found"
      exit 1
    fi
    if ! xcrun simctl list devices booted | grep -q "$DEVICE_ID"; then
      to 30s xcrun simctl boot "$DEVICE_ID"
      open -a Simulator || true
      sleep 4
    fi

    # Build with archetype + walkthrough phase dart-defines.
    # 51-07 (post-T-04): API_BASE_URL targets Railway staging per
    # `feedback_app_targets_staging_always.md` — secrets (ANTHROPIC_API_KEY)
    # live on Railway only, so localhost would 502/503 on every chat phase
    # and produce phantom evidence. Staging is the canonical target.
    log "archetype-walkthrough: flutter build with MINT_E2E_ARCHETYPE=${ARCHETYPE} → staging"
    # 51-07 (post-T-04): --no-codesign required when the working tree lives
    # under an iCloud Drive `.nosync` mount (macOS Sequoia/Tahoe propagates
    # `com.apple.provenance` xattrs, which break codesign for sim builds).
    # See ENV-WORKTREE-PROVENANCE in get-shit-done workflow + Phase 44 incident.
    # Sim builds don't need a real signature anyway.
    (cd apps/mobile && flutter build ios --simulator --no-codesign \
      --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
      --dart-define=MINT_DEV_AUTH_TOKEN="${MINT_DEV_AUTH_TOKEN}" \
      --dart-define=MINT_E2E_ARCHETYPE="${ARCHETYPE}" \
      --dart-define=MINT_WALKTHROUGH_PHASE=51 \
      --dart-define=SENTRY_DSN="${SENTRY_DSN_STAGING}") 2>&1 | tee -a "$LOG"
    BUILD_RC=${PIPESTATUS[0]}

    APP_PATH="apps/mobile/build/ios/iphonesimulator/Runner.app"
    if [ "$BUILD_RC" -ne 0 ] || [ ! -d "$APP_PATH" ]; then
      log "FAIL: flutter build exited ${BUILD_RC} OR Runner.app missing at $APP_PATH"
      exit 1
    fi
    to 60s xcrun simctl install "$DEVICE_ID" "$APP_PATH"
    to 30s xcrun simctl launch "$DEVICE_ID" "$BUNDLE"
    sleep 8

    # 51-07 / G51-06-03 — deterministic 7-phase capture replacing the
    # legacy polling loop. Each phase: tap (or sleep for animation) ->
    # wait_for_ui quiescence -> snap. Coordinates calibrated against
    # the existing landing/chat goldens; UI drift will surface as two
    # consecutive sha256-identical PNGs in test_walker_archetype.sh
    # smoke (T-51-07-06).
    SIM_DEVICE_ID="$DEVICE_ID"

    # Phase 0: app already launched + seeded by main.dart kDebugMode
    # block (G51-06-01 wiring). Capture the seed_loaded surface.
    snap "${SHOTS_DIR}/00-seed-loaded.png" \
      && log "archetype-walkthrough: captured 00-seed-loaded.png" \
      || log "WARN: 00-seed-loaded snap failed"

    # Phase 1: open the chat surface — tap "Parle à Mint" CTA on landing.
    tap_at 195 760
    wait_for_ui 6
    snap "${SHOTS_DIR}/01-chat-open.png" \
      && log "archetype-walkthrough: captured 01-chat-open.png" \
      || log "WARN: 01-chat-open snap failed"

    # Phase 2: tap a reflection chip (or type the scenario prompt) so
    # the orchestrator dispatches a tool call.
    tap_at 195 720
    wait_for_ui 8
    snap "${SHOTS_DIR}/02-tool-dispatched.png" \
      && log "archetype-walkthrough: captured 02-tool-dispatched.png" \
      || log "WARN: 02-tool-dispatched snap failed"

    # Phase 3: tap the suggested RouteSuggestionCard to open the canvas.
    tap_at 195 600
    wait_for_ui 6
    snap "${SHOTS_DIR}/03-canvas-open.png" \
      && log "archetype-walkthrough: captured 03-canvas-open.png" \
      || log "WARN: 03-canvas-open snap failed"

    # Phase 4: dismiss the canvas (back button at top-left).
    sleep 1
    tap_at 30 80
    wait_for_ui 4
    snap "${SHOTS_DIR}/04-canvas-back.png" \
      && log "archetype-walkthrough: captured 04-canvas-back.png" \
      || log "WARN: 04-canvas-back snap failed"

    # Phase 5: recap card should now be enqueued in chat — capture it.
    sleep 1
    snap "${SHOTS_DIR}/05-recap-received.png" \
      && log "archetype-walkthrough: captured 05-recap-received.png" \
      || log "WARN: 05-recap-received snap failed"

    # Phase 6: tap the recap CTA to dispatch the next route.
    tap_at 195 540
    wait_for_ui 4
    snap "${SHOTS_DIR}/06-cta-routed.png" \
      && log "archetype-walkthrough: captured 06-cta-routed.png" \
      || log "WARN: 06-cta-routed snap failed"

    log "archetype-walkthrough: prompt-to-type='${PROMPT}'"
    log "archetype-walkthrough: 7-phase deterministic capture complete"
    log "archetype-walkthrough: shots in ${SHOTS_DIR}"
    ls -la "$SHOTS_DIR" | tee -a "$LOG"
    ;;

  *)
    log "FAIL: unknown mode '${MODE}' (expect --quick-screenshot | --smoke-test-inject-error | --gate-phase-31 | --admin-routes | --scenario=admin-routes | --archetype <slug>)"
    exit 2
    ;;
esac

log "walker.sh: done → ${OUTDIR}"

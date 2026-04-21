#!/usr/bin/env bash
# tools/simulator/pii_audit_screens.sh — Phase 31 OBS-06 PII audit driver.
#
# Navigates the iPhone 17 Pro simulator through the 5 sensitive screens
# flagged by CONTEXT.md D-06 / RESEARCH Pitfall 1 and captures one
# screenshot per screen. Visual mask verification (the actual audit)
# happens in Sentry UI Replay; this script only captures the
# "did I reach the screen" proof state that the audit artefact cites
# alongside the Sentry replay frames.
#
# Prereq: walker.sh --quick-screenshot has already booted the device,
# built staging, and installed + launched the app. Re-running walker
# before this script is safe (idempotent); running this script against
# a cold device will fail the openurl steps.
#
# Staging-only per feedback_app_targets_staging_always.md. Production
# sessionSampleRate stays 0.0 per D-01; this script does NOT flip it.
#
# Usage:
#   bash tools/simulator/pii_audit_screens.sh
#
# Optional env:
#   MINT_WALKER_DEVICE   (defaults to 'iPhone 17 Pro')
#   MINT_WALKER_DRY_RUN  (skip simctl side effects — smoke test this file)

set -euo pipefail

DEVICE="${MINT_WALKER_DEVICE:-iPhone 17 Pro}"
BUNDLE="com.mint.mintMobile"
DRY_RUN="${MINT_WALKER_DRY_RUN:-0}"
TS="$(date +%Y-%m-%d-%H%M%S)"
OUTDIR=".planning/research/pii-audit-screenshots/${TS}"
mkdir -p "$OUTDIR"
LOG="$OUTDIR/pii-audit.log"

log() {
  echo "[pii-audit $(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$LOG"
}

log "device='${DEVICE}' outdir=${OUTDIR} dry_run=${DRY_RUN}"

# Portable `timeout` — macOS has no `timeout` out of the box. See walker.sh.
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
else
  TIMEOUT_BIN=""
  log "WARN: neither gtimeout nor timeout found — simctl calls unbounded."
fi
to() {
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "$@"
  else
    shift
    "$@"
  fi
}

# 5 sensitive screens — GoRouter deep links (resolved from apps/mobile/lib/app.dart):
#   CoachChat             → /coach/chat        (app.dart L384)
#   DocumentScan          → /scan              (app.dart L792; legacy /document-scan redirects)
#   ExtractionReviewSheet → triggered by scan flow (bottom sheet, not a direct route — captured via scan flow)
#   Onboarding            → /landing then anonymous flow (onboarding proper is orchestrated through coach; landing is the public entrypoint captured here)
#   Budget                → /budget            (app.dart L657)
#
# The ExtractionReviewSheet is a modal bottom sheet triggered by the scan
# flow and has no deep-link — the audit artefact notes this, and the
# operator captures it manually after triggering a scan.
SCREENS=(
  "coach-chat:/coach/chat"
  "document-scan:/scan"
  "landing:/landing"
  "budget:/budget"
)

capture_screen() {
  local name="$1"
  local path="$2"
  local out="${OUTDIR}/${name}.png"
  log "navigating to ${name} (${path})"

  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN=1 — skipping openurl + screenshot for ${name}"
    : > "$out"
    return 0
  fi

  # Attempt several deep-link schemes. The build may not yet register a
  # custom URL scheme (`mint://`) — Universal Links on `mint.app` is the
  # spec. We try both plus a fallback that does nothing, and always
  # snap the screenshot so the operator can eyeball whether navigation
  # succeeded.
  to 15s xcrun simctl openurl "$DEVICE" "mint:/${path}" 2>/dev/null \
    || to 15s xcrun simctl openurl "$DEVICE" "https://mint.app${path}" 2>/dev/null \
    || log "WARN: deep-link failed for ${name} — manual nav in Sentry UI audit"
  sleep 3
  to 10s xcrun simctl io "$DEVICE" screenshot "$out"
  log "captured ${name} → ${out}"
}

for entry in "${SCREENS[@]}"; do
  NAME="${entry%%:*}"
  PATH_="${entry#*:}"
  capture_screen "$NAME" "$PATH_"
done

# ExtractionReviewSheet requires a document flow and cannot be deep-linked.
log "NOTE: ExtractionReviewSheet requires manual scan-triggered capture"
log "      (pick a test document on /scan, advance to the review sheet,"
log "      then: xcrun simctl io '${DEVICE}' screenshot ${OUTDIR}/extraction-review.png)"

log "pii-audit: screenshots saved to ${OUTDIR}"
log "pii-audit: next step — open staging Sentry UI, filter replays env:staging"
log "pii-audit: pause on CHF/IBAN/AVS frames, verify black-box overlay visible"
log "pii-audit: commit findings to .planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md"

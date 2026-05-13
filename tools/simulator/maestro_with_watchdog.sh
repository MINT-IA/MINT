#!/usr/bin/env bash
# tools/simulator/maestro_with_watchdog.sh — S98 Phase 3
#
# Wraps a Maestro flow run with a stall-detector watchdog. Maestro on
# iOS sim is known-flaky: documented silent hangs (mobile-dev-inc
# issues #1252 #2628 #3254) sit with no output for 10-30 minutes and
# never auto-kill. Session 2026-05-13 lost 30 min on task `bo1o442ww`
# which stalled and never returned.
#
# This wrapper:
#   1. Tees maestro stdout/stderr to a log file with a per-line mtime.
#   2. A background watchdog probes the log's mtime every
#      MAESTRO_STALL_PROBE_INTERVAL seconds (default 30s). If the log
#      hasn't been touched in MAESTRO_STALL_THRESHOLD seconds (default
#      90s), maestro is considered stalled.
#   3. On stall: dump artifacts (last screenshot, /debug/state snapshot
#      if endpoint reachable, OSLog tail) and SIGTERM maestro.
#   4. Hard ceiling at MAESTRO_HARD_LIMIT seconds (default 900s = 15
#      min). Past that, SIGKILL.
#
# Usage:
#   bash tools/simulator/maestro_with_watchdog.sh test <flow.yaml> [...args]
#
# Forwards all args to `tools/simulator/maestro_env.sh`. The first arg
# must be the maestro subcommand (`test`, `studio`, etc.) — same shape
# as direct `maestro` invocation.
#
# Env:
#   MAESTRO_STALL_PROBE_INTERVAL   default 30
#   MAESTRO_STALL_THRESHOLD        default 90
#   MAESTRO_HARD_LIMIT             default 900
#   MINT_WALKER_ARTIFACTS          default $REPO/.planning/_walker/<ts>
#   MINT_DEBUG_PORT                default 8181
#   MINT_DEBUG_TOKEN_PATH          default <auto-resolved from simctl>
#
# Exit codes:
#   0    — maestro succeeded
#   124  — stall detected, maestro killed
#   137  — hard limit hit (SIGKILL)
#   other — maestro's own non-zero exit
set -euo pipefail

# ── Resolve paths + defaults ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAESTRO_ENV="$SCRIPT_DIR/maestro_env.sh"
[ -x "$MAESTRO_ENV" ] || {
  echo "ERROR: $MAESTRO_ENV not found / not executable" >&2
  exit 2
}

STALL_PROBE_INTERVAL="${MAESTRO_STALL_PROBE_INTERVAL:-30}"
STALL_THRESHOLD="${MAESTRO_STALL_THRESHOLD:-90}"
HARD_LIMIT="${MAESTRO_HARD_LIMIT:-900}"

TS="$(date +%Y%m%dT%H%M%S)"
ARTIFACT_DIR="${MINT_WALKER_ARTIFACTS:-$REPO_ROOT/.planning/_walker/$TS}"
mkdir -p "$ARTIFACT_DIR"

LOG_FILE="$ARTIFACT_DIR/maestro.log"
STALL_MARKER="$ARTIFACT_DIR/STALLED"

DEBUG_PORT="${MINT_DEBUG_PORT:-8181}"
BUNDLE="${MINT_BUNDLE_ID:-ch.mint.app}"

echo "[watchdog] artifacts → $ARTIFACT_DIR"
echo "[watchdog] hard limit ${HARD_LIMIT}s ; stall threshold ${STALL_THRESHOLD}s ; probe ${STALL_PROBE_INTERVAL}s"

# ── Dump function (called on stall OR caller-side trap) ────────────────
dump_state() {
  local reason="$1"
  echo "[watchdog] DUMPING STATE — reason: $reason"
  {
    echo "reason: $reason"
    echo "timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "maestro_log: $LOG_FILE ($(wc -l < "$LOG_FILE" 2>/dev/null || echo 0) lines)"
    echo "last_log_lines:"
    tail -n 30 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
  } > "$ARTIFACT_DIR/stall-summary.txt"

  # 1. Last sim screenshot (best-effort, doesn't matter if booted-state
  # is gone).
  xcrun simctl io booted screenshot "$ARTIFACT_DIR/last-screen.png" 2>/dev/null \
    || echo "[watchdog] simctl screenshot failed (sim may not be booted)"

  # 2. OSLog tail filtered to ch.mint.* (the same tag MintHttpClient
  # uses) — 5-minute window pre-stall.
  xcrun simctl spawn booted log show --last 5m \
    --predicate 'subsystem CONTAINS "mint" OR category CONTAINS "mint"' \
    --style compact > "$ARTIFACT_DIR/oslog-mint.txt" 2>/dev/null \
    || echo "[watchdog] simctl log show failed"

  # 3. /debug/state snapshot if reachable. Token discovery via
  # `simctl get_app_container booted <bundle> data` then tmp/mint_debug.token
  # (matches Tier 2 spec — see lib/debug/debug_server.dart file-header).
  if app_data=$(xcrun simctl get_app_container booted "$BUNDLE" data 2>/dev/null); then
    token_file="$app_data/tmp/mint_debug.token"
    if [ -f "$token_file" ]; then
      token=$(cat "$token_file")
      curl -fsS --max-time 5 \
        -H "Authorization: Bearer $token" \
        "http://127.0.0.1:${DEBUG_PORT}/debug/state" \
        -o "$ARTIFACT_DIR/debug-state.json" \
        || echo "[watchdog] /debug/state fetch failed (endpoint not running?)"
    else
      echo "[watchdog] token file not found at $token_file — Tier 2 endpoint not enabled?"
    fi
  fi

  # 4. Maestro driver logs ~/.maestro/tests/<latest>/ (Maestro internal
  # trace).
  if [ -d "$HOME/.maestro/tests" ]; then
    latest_trace=$(ls -t "$HOME/.maestro/tests" 2>/dev/null | head -1)
    if [ -n "$latest_trace" ]; then
      cp -R "$HOME/.maestro/tests/$latest_trace" "$ARTIFACT_DIR/maestro-trace/" 2>/dev/null \
        || true
    fi
  fi

  echo "[watchdog] dump complete → $ARTIFACT_DIR/"
}

# ── Spawn Maestro in the background, tee'd to log ──────────────────────
# `script -q` would give us a real tty for color output, but is non-
# portable. Use tee + line-buffered cat. macOS bash 3.x doesn't have
# `stdbuf`, so we accept slight buffering (acceptable — watchdog probes
# mtime, not byte count).
#
# The pipeline `( cmd ) | tee &` returns the PID of `tee` via `$!`.
# Killing `tee` closes the pipe ; the upstream subshell then receives
# SIGPIPE on its next write and dies. We don't need a separate maestro
# PID — the pipe-close cascade is sufficient. (Earlier `pgrep`-based
# detection was fragile under `set -e` + `pipefail` and added no value.)
( "$MAESTRO_ENV" "$@" 2>&1 ) | tee "$LOG_FILE" &
TEE_PID=$!
echo "[watchdog] tee pid=$TEE_PID — killing this cascades SIGPIPE to maestro"

# ── Spawn the watchdog ─────────────────────────────────────────────────
START_TS=$(date +%s)
(
  while true; do
    sleep "$STALL_PROBE_INTERVAL"
    # Has the parent tee exited? (maestro completed or crashed)
    if ! kill -0 "$TEE_PID" 2>/dev/null; then
      exit 0
    fi
    # Hard limit check.
    now=$(date +%s)
    elapsed=$(( now - START_TS ))
    if [ "$elapsed" -gt "$HARD_LIMIT" ]; then
      echo "[watchdog] HARD LIMIT ${HARD_LIMIT}s exceeded — killing"
      echo "hard_limit" > "$STALL_MARKER"
      dump_state "hard_limit_${elapsed}s"
      kill -TERM "$TEE_PID" 2>/dev/null || true
      sleep 5
      kill -KILL "$TEE_PID" 2>/dev/null || true
      pkill -KILL -P "$TEE_PID" 2>/dev/null || true
      exit 137
    fi
    # Stall check via log mtime.
    if [ -f "$LOG_FILE" ]; then
      log_mtime=$(stat -f %m "$LOG_FILE" 2>/dev/null || echo 0)
      idle=$(( now - log_mtime ))
      if [ "$idle" -gt "$STALL_THRESHOLD" ]; then
        echo "[watchdog] STALL — no log output for ${idle}s (> ${STALL_THRESHOLD}s)"
        echo "stall_${idle}s" > "$STALL_MARKER"
        dump_state "stall_${idle}s"
        kill -TERM "$TEE_PID" 2>/dev/null || true
        pkill -TERM -P "$TEE_PID" 2>/dev/null || true
        sleep 3
        kill -KILL "$TEE_PID" 2>/dev/null || true
        pkill -KILL -P "$TEE_PID" 2>/dev/null || true
        exit 124
      fi
    fi
  done
) &
WATCHDOG_PID=$!

# ── Wait for maestro to finish ─────────────────────────────────────────
# `wait` returns the child's exit status (or 128+signal if killed). Under
# `set -e`, a non-zero return would abort BEFORE we can capture $?.
# Disable `errexit` just around this call so the watchdog's SIGTERM /
# SIGKILL of TEE_PID is observable as a normal exit code.
set +e
wait "$TEE_PID" 2>/dev/null
MAESTRO_EXIT=$?
set -e

# Stop the watchdog (whether by stall or normal completion).
kill "$WATCHDOG_PID" 2>/dev/null || true
wait "$WATCHDOG_PID" 2>/dev/null || true

if [ -f "$STALL_MARKER" ]; then
  reason=$(cat "$STALL_MARKER")
  echo "[watchdog] EXIT — STALLED ($reason). Artifacts: $ARTIFACT_DIR"
  if [ "$reason" = "hard_limit" ] || [[ "$reason" == "hard_limit_"* ]]; then
    exit 137
  fi
  exit 124
fi

echo "[watchdog] EXIT — maestro returned $MAESTRO_EXIT"
exit "$MAESTRO_EXIT"

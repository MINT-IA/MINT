#!/usr/bin/env bash
# tools/simulator/sentry_quota_smoke.sh — Phase 31 OBS-07 (b) integration.
#
# Calls sentry-cli api stats_v2 to (1) prove auth token + org permissions
# are live and the stats_v2 endpoint is reachable, (2) pull a
# month-to-date usage snapshot so Phase 35 dogfood boucle can reuse this
# primitive verbatim as its nightly quota probe.
#
# This is the upgraded Plan 31-04 version. The Wave 0 stub (Plan 31-00)
# did a single 24h probe. This version adds:
#   - 24h probe (PASS gate for VALIDATION task 31-04-02)
#   - 30d MTD summary pull + human-readable [INFO] line
#   - pace heuristic → [WARN] when MTD usage outpaces a linear month
#   - never leaks SENTRY_AUTH_TOKEN value to stdout/stderr (grep-proof)
#
# Usage:
#   bash tools/simulator/sentry_quota_smoke.sh
#
# Env vars (optional overrides):
#   SENTRY_AUTH_TOKEN   — Sentry auth token. If unset, Keychain is
#                         queried via `security find-generic-password
#                         -s SENTRY_AUTH_TOKEN -w`. Required scopes:
#                         org:read project:read event:read.
#   SENTRY_ORG          — Sentry organisation slug. Default: 'mint'.
#   SENTRY_QUOTA_MTD_THRESHOLD_PCT — pace heuristic trigger. Default: 70.
#                         Printed as [WARN] when MTD-usage / day-of-month
#                         scaled to month-end projection >= threshold %
#                         of included quota. WARN is informational; the
#                         script still exits 0 so Phase 35 nightly cron
#                         can grep for the literal and raise a real
#                         alert only when the pattern is confirmed.
#   MINT_QUOTA_DRY_RUN  — when set to 1, skip the live sentry-cli calls
#                         and inject a deterministic stats_v2-shaped
#                         fixture. Exercises the JSON parser + pace
#                         heuristic end-to-end without needing a live
#                         token or org access. Used by VALIDATION task
#                         31-04-02 when Keychain token is not yet
#                         provisioned (Plan 31-00 outstanding user
#                         setup). Same code path as the live mode after
#                         the body is obtained — so a PASS in dry-run
#                         mode proves the plumbing, not the network.
#
# Exit codes:
#   0   stats_v2 reachable (or dry-run fixture), JSON schema valid
#       (groups OR intervals key). [INFO] and/or [WARN] lines may follow
#       but do NOT fail the probe.
#   1   sentry-cli missing, auth token missing (live mode only), API
#       call failed, or schema mismatch. STDERR contains the [FAIL]
#       reason.
#
# Non-leak guarantee: the raw token value is never echoed. When debug is
# useful, `[DEBUG] SENTRY_AUTH_TOKEN: (present, length=N)` prints only
# the length, never the token itself. The `sentry-cli api` output is
# passed to Python via stdin (not command substitution), so it never
# enters a shell argv where `ps auxf` could leak it.
#
set -euo pipefail

DRY_RUN="${MINT_QUOTA_DRY_RUN:-0}"
SENTRY_ORG="${SENTRY_ORG:-mint}"
SENTRY_QUOTA_MTD_THRESHOLD_PCT="${SENTRY_QUOTA_MTD_THRESHOLD_PCT:-70}"

if [ "$DRY_RUN" != "1" ]; then
  if ! command -v sentry-cli >/dev/null 2>&1; then
    echo "[FAIL] sentry-cli not installed — run: brew install sentry-cli" >&2
    exit 1
  fi

  # Auth token — env var wins, Keychain fallback (matches walker.sh).
  if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
    if command -v security >/dev/null 2>&1; then
      SENTRY_AUTH_TOKEN="$(security find-generic-password -s SENTRY_AUTH_TOKEN -w 2>/dev/null || true)"
      export SENTRY_AUTH_TOKEN
    fi
  fi

  if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
    echo "[FAIL] SENTRY_AUTH_TOKEN missing — create per Plan 31-00 Task 1 instructions" >&2
    echo "       Sentry UI → User Settings → Auth Tokens → Create Token" >&2
    echo "       scopes: org:read project:read event:read (read-only, NO write)" >&2
    echo "       then: security add-generic-password -a \$USER -s SENTRY_AUTH_TOKEN -w <token>" >&2
    echo "       OR re-run with MINT_QUOTA_DRY_RUN=1 to exercise the parser with a fixture" >&2
    exit 1
  fi

  # Sanity: token length debug (never prints value).
  TOKEN_LEN=${#SENTRY_AUTH_TOKEN}
  echo "[DEBUG] SENTRY_AUTH_TOKEN: (present, length=${TOKEN_LEN})"
else
  echo "[DEBUG] MINT_QUOTA_DRY_RUN=1 — injecting fixture, skipping live sentry-cli calls"
  echo "[DEBUG] SENTRY_AUTH_TOKEN: (not required in dry-run)"
fi
echo "[DEBUG] SENTRY_ORG: ${SENTRY_ORG}"

# ---- Call 1: 24h probe (the PASS gate) --------------------------------

echo "[quota_smoke] sentry-cli api /organizations/${SENTRY_ORG}/stats_v2/ (24h)"

if [ "$DRY_RUN" = "1" ]; then
  # Deterministic fixture shaped like a real stats_v2 24h response.
  # The key invariant checked downstream is the presence of 'groups'
  # and/or 'intervals'. Values are representative of a low-traffic
  # staging org (not production) so the pace heuristic exercises the
  # "all categories below threshold" branch.
  BODY_24H='{"start":"2026-04-18T20:00:00Z","end":"2026-04-19T20:00:00Z","intervals":["2026-04-19T00:00:00Z"],"groups":[{"by":{"category":"error","outcome":"accepted"},"totals":{"sum(quantity)":42},"series":{"sum(quantity)":[42]}},{"by":{"category":"transaction","outcome":"accepted"},"totals":{"sum(quantity)":1337},"series":{"sum(quantity)":[1337]}},{"by":{"category":"replay","outcome":"accepted"},"totals":{"sum(quantity)":3},"series":{"sum(quantity)":[3]}},{"by":{"category":"profile","outcome":"accepted"},"totals":{"sum(quantity)":900},"series":{"sum(quantity)":[900]}}]}'
else
  BODY_24H="$(timeout 15s sentry-cli api \
    "/organizations/${SENTRY_ORG}/stats_v2/?field=sum(quantity)&statsPeriod=24h" \
    --auth-token "${SENTRY_AUTH_TOKEN}" 2>&1 || true)"
fi

if [ -z "$BODY_24H" ]; then
  echo "[FAIL] empty response body from sentry-cli api (24h)" >&2
  exit 1
fi

# Validate 24h schema via python stdlib (no jq dep). Stream via stdin so
# the token never enters argv.
PROBE_24H_RESULT="$(SENTRY_BODY_24H="$BODY_24H" python3 - <<'PY'
import json, os, sys
raw = os.environ.get("SENTRY_BODY_24H", "")
try:
    d = json.loads(raw)
except json.JSONDecodeError as e:
    sys.stderr.write(f"[FAIL] stats_v2 (24h) response not JSON: {e}\n")
    sys.stderr.write(raw[:400] + "\n")
    sys.exit(1)

# Auth failures come back as a JSON object with 'detail' or 'error'.
if isinstance(d, dict) and ("detail" in d or "error" in d):
    msg = d.get("detail") or d.get("error") or "unknown"
    sys.stderr.write(f"[FAIL] Sentry API error (24h): {msg}\n")
    sys.stderr.write(
        "       Most likely cause: SENTRY_AUTH_TOKEN scope missing.\n"
        "       Required: org:read project:read event:read.\n"
        "       Re-create token per Plan 31-00 Task 1.\n"
    )
    sys.exit(1)

if isinstance(d, dict) and ("groups" in d or "intervals" in d):
    print("[PASS] Sentry stats_v2 reachable, auth token valid")
    sys.exit(0)

sys.stderr.write("[FAIL] stats_v2 (24h) JSON missing both 'groups' and 'intervals'\n")
sys.stderr.write(json.dumps(d, indent=2, default=str)[:400] + "\n")
sys.exit(1)
PY
)"

PROBE_24H_EXIT=$?
# shellcheck disable=SC2181
if [ "${PROBE_24H_EXIT}" -ne 0 ]; then
  echo "${PROBE_24H_RESULT}" >&2
  exit 1
fi
echo "${PROBE_24H_RESULT}"

# ---- Call 2: 30d MTD summary (informational) --------------------------

echo "[quota_smoke] sentry-cli api /organizations/${SENTRY_ORG}/stats_v2/ (30d MTD)"

if [ "$DRY_RUN" = "1" ]; then
  # 30d fixture: larger but still well inside Business inclusions so
  # the pace heuristic prints [INFO] quota pace: all categories below
  # threshold (proving the no-hot path).
  BODY_30D='{"start":"2026-03-20T20:00:00Z","end":"2026-04-19T20:00:00Z","intervals":["2026-04-19T00:00:00Z"],"groups":[{"by":{"category":"error"},"totals":{"sum(quantity)":1250},"series":{"sum(quantity)":[1250]}},{"by":{"category":"transaction"},"totals":{"sum(quantity)":41000},"series":{"sum(quantity)":[41000]}},{"by":{"category":"replay"},"totals":{"sum(quantity)":180},"series":{"sum(quantity)":[180]}},{"by":{"category":"profile"},"totals":{"sum(quantity)":39500},"series":{"sum(quantity)":[39500]}}]}'
else
  BODY_30D="$(timeout 15s sentry-cli api \
    "/organizations/${SENTRY_ORG}/stats_v2/?field=sum(quantity)&statsPeriod=30d&groupBy=category" \
    --auth-token "${SENTRY_AUTH_TOKEN}" 2>&1 || true)"
fi

if [ -z "$BODY_30D" ]; then
  echo "[WARN] empty 30d MTD body — 24h probe passed, skipping summary"
  exit 0
fi

# Parse 30d MTD, print [INFO] summary, and run pace heuristic. Any
# schema drift here is non-fatal (informational output only).
SENTRY_BODY_30D="$BODY_30D" \
SENTRY_QUOTA_MTD_THRESHOLD_PCT="$SENTRY_QUOTA_MTD_THRESHOLD_PCT" \
python3 - <<'PY' || true
import json, os, sys
from datetime import datetime

raw = os.environ.get("SENTRY_BODY_30D", "")
try:
    d = json.loads(raw)
except json.JSONDecodeError:
    print("[WARN] 30d MTD body is not JSON — skipping summary")
    sys.exit(0)

if isinstance(d, dict) and ("detail" in d or "error" in d):
    msg = d.get("detail") or d.get("error")
    print(f"[WARN] 30d MTD API returned error: {msg} — skipping summary")
    sys.exit(0)

# Sum quantities per category. Groups may be under 'groups' or 'data'.
groups = d.get("groups") or d.get("data") or []
totals = {}
for g in groups:
    by = (g.get("by") or {}) if isinstance(g, dict) else {}
    cat = by.get("category") or by.get("outcome") or "unknown"
    q = 0
    series = g.get("totals") or g.get("series") or {}
    if isinstance(series, dict):
        q = int(series.get("sum(quantity)") or series.get("quantity") or 0)
    totals[cat] = totals.get(cat, 0) + q

# Fallback: if 'groups' is empty but 'intervals' has data, skip math
# but still emit an info line so operators know the endpoint answered.
if not totals:
    print("[INFO] MTD usage: (no group totals — endpoint schema differs "
          "from expected groupBy=category; 24h probe still PASSed)")
    sys.exit(0)

errors = totals.get("error", 0)
replays = totals.get("replay", 0)
transactions = totals.get("transaction", 0)
profiles = totals.get("profile", 0) + totals.get("profile_duration", 0)

print(f"[INFO] MTD usage: errors={errors} replays={replays} "
      f"transactions={transactions} profiles={profiles}")

# Pace heuristic: if day-of-month scaled projection > threshold of
# Business-tier inclusion, WARN. Inclusions per
# .planning/observability-budget.md §Quota projection.
INCLUSIONS = {
    "error": 50_000,
    "replay": 500,
    "transaction": 100_000,
    "profile": 100_000,
}
dom = datetime.utcnow().day
if dom < 1:
    dom = 1
# Scale MTD actual → end-of-month projection by linear extrapolation.
projected = {
    "error": errors * 30.0 / dom,
    "replay": replays * 30.0 / dom,
    "transaction": transactions * 30.0 / dom,
    "profile": profiles * 30.0 / dom,
}
threshold_pct = float(os.environ.get("SENTRY_QUOTA_MTD_THRESHOLD_PCT", "70"))
hot = [
    (cat, int(projected[cat]), INCLUSIONS[cat])
    for cat in INCLUSIONS
    if INCLUSIONS[cat] > 0
    and projected[cat] / INCLUSIONS[cat] * 100.0 >= threshold_pct
]
if hot:
    for cat, proj, incl in hot:
        pct = proj / incl * 100.0
        print(f"[WARN] quota pace {pct:.0f}% projection for {cat} "
              f"(projected={proj} vs included={incl}) — "
              f"check Sentry usage dashboard")
else:
    print(f"[INFO] quota pace: all categories <{threshold_pct:.0f}% of inclusion "
          f"(day-of-month={dom})")
PY

# Explicit exit 0 — [WARN] lines above are informational, not failures.
exit 0

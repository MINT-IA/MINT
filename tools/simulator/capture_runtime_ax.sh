#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${1:-$ROOT_DIR/.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/runtime-ax-$(date +%Y%m%dT%H%M%S)}"
APP_SCHEME="${APP_SCHEME:-mintapp}"
IDB_UDID="${IDB_UDID:-}"
REQUIRE_ROW23_PROOF="${MINT_AX_REQUIRE_ROW23_PROOF:-false}"

mkdir -p "$OUT_DIR"

if ! command -v idb >/dev/null 2>&1; then
  echo "idb is required for runtime AX capture" >&2
  exit 2
fi

capture_idb_tree() {
  local json_path="$1"
  if [[ -n "$IDB_UDID" ]]; then
    idb ui describe-all --udid "$IDB_UDID" --json > "$json_path"
  else
    idb ui describe-all --json > "$json_path"
  fi
}

capture_surface() {
  local slug="$1"
  local route="$2"
  shift 2
  local json_path="$OUT_DIR/${slug}-describe-all.json"

  xcrun simctl openurl booted "${APP_SCHEME}:///${route}"
  sleep "${AX_CAPTURE_SETTLE_SECONDS:-3}"
  capture_idb_tree "$json_path"

  python3 - "$json_path" "$slug" "$@" <<'PY'
import json
import sys

path = sys.argv[1]
slug = sys.argv[2]
expected = sys.argv[3:]

with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

def walk(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if isinstance(item, str):
                yield item
            else:
                yield from walk(item)
    elif isinstance(value, list):
        for item in value:
            yield from walk(item)

strings = list(walk(data))
joined = "\n".join(strings)
normalized_joined = joined.replace(" ", "")
empty_sentinel = (
    isinstance(data, list)
    and len(data) == 1
    and "{{0,0},{0,0}}" in normalized_joined
)
if empty_sentinel or len(strings) <= 1:
    raise SystemExit(
        f"{slug}: platform AX tree is empty or unpublished; got {path}"
    )

cursor = 0
for text in strings:
    if cursor < len(expected) and expected[cursor] in text:
        cursor += 1

if cursor != len(expected):
    raise SystemExit(
        f"{slug}: expected ordered markers {expected}, only matched "
        f"{expected[:cursor]} in {path}"
    )
PY
}

capture_surface coach-chat "coach/chat" "Coach" "Dis-moi"
if [[ "$REQUIRE_ROW23_PROOF" == "true" ]]; then
  capture_surface budget "budget" \
    "budget_income_basis" \
    "q_self_employed_net_income_annual_chf=96000" \
    "monthly_net=CHF 8"
  capture_surface rapport "rapport" \
    "report_3a_income_basis" \
    "annual=96000" \
    "remaining=13200"
else
  capture_surface budget "budget" "budget_screen" "budget_hero_summary"
  capture_surface rapport "rapport" "Ton Bilan Flash" "Transparence"
fi

cat > "$OUT_DIR/README.md" <<EOF
# Runtime iOS accessibility tree capture

Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

This captures the ordered iOS platform accessibility tree with \`idb ui
describe-all --json\`. It is not a VoiceOver speech-order proof. It fails on
the known empty \`{{0, 0}, {0, 0}}\` sentinel and requires ordered markers for the
Coach, Budget, and Rapport surfaces.

Build flags for Row 23 value-continuity proof:

\`\`\`bash
flutter build ios --simulator --debug \\
  --dart-define=MINT_DISABLE_BETA_MODAL=true \\
  --dart-define=MINT_E2E_PROOF_ANCHORS=true
\`\`\`

Run this script with \`MINT_AX_REQUIRE_ROW23_PROOF=true\` when the AX capture
must also contain Row 23 machine proof anchors and values. Without that env
var this script only proves that an ordered platform AX tree was published for
the surfaces, not that the Row 23 machine proof anchors or values are present.
EOF

echo "$OUT_DIR"

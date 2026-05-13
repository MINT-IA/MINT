#!/usr/bin/env bash
# cassure4-probe.sh — discriminate H4a / H4b / H4c / H4d for the
# auth-gate-modal-not-triggered bug observed on the new-user E2E flow
# (see .planning/phases/97.5-product-completeness-for-ship/
#    evidence-2026-05-13/cassure4-backend-works-curl-evidence.md).
#
# Hypotheses to discriminate:
#   H4a — `messagesRemaining` field absent from response payload
#   H4b — present but coerced as String "0" instead of int 0 (cast → null)
#   H4c — race: setState fires before the gate check
#   H4d — staging response shape differs vs curl baseline
#
# How the probe answers each:
#   - H4a / H4b / H4d are answered by reading the BODY logs that
#     MintHttpClient emits (cf. tools/debug/mint-trace.sh + the
#     `ch.mint.http` OSLog category).
#   - H4c needs Dart-side code inspection; if H4a/b/d are ruled out,
#     the verdict points there.
#
# Dependencies (in dev or staging):
#   - PR #592 (obs spine) deployed — supplies MintHttpClient BODY logs
#   - PR #591 (E2E flow) merged — supplies tools/simulator/flows/e2e/
#       flow_e2e_new_user_full_journey.yaml
#   - Maestro installed (JAVA_HOME below points to OpenJDK 21)
#   - Sim UDID locked to iPhone 17 Pro / iOS 26.2
#
# Usage: tools/debug/cassure4-probe.sh
set -euo pipefail

SIM_UDID="B03E429D-0422-4357-B754-536637D979F9"
STAGING_API="https://mint-staging.up.railway.app/api/v1"
FLOW="tools/simulator/flows/e2e/flow_e2e_new_user_full_journey.yaml"
JAVA_HOME_OPENJDK21="/opt/homebrew/Cellar/openjdk@21/21.0.11/libexec/openjdk.jdk/Contents/Home"
STAMP="$(date +%Y%m%dT%H%M%S)"
RUN_DIR="/tmp/cassure4-probe-${STAMP}"
mkdir -p "${RUN_DIR}"

log() { printf '\n[probe %s] %s\n' "$(date +%H:%M:%S)" "$*"; }

log "0/5  Pre-flight"
[[ -f "${FLOW}" ]] || { echo "ERR: missing ${FLOW} — wait for PR #591 to merge" >&2; exit 2; }
curl -fsS --max-time 5 "${STAGING_API}/health" >/dev/null \
  || { echo "ERR: staging unreachable: ${STAGING_API}/health" >&2; exit 3; }

log "1/5  Boot sim ${SIM_UDID}"
xcrun simctl boot "${SIM_UDID}" 2>/dev/null || true

if ! xcrun simctl get_app_container "${SIM_UDID}" ch.mint.app >/dev/null 2>&1; then
  cat >&2 <<EOM
ERR: ch.mint.app is not installed on the sim.
Build + install first (must include the MintHttpClient bits) :

  cd apps/mobile
  flutter build ios --simulator --no-codesign \\
    --dart-define=API_BASE_URL=${STAGING_API}
  xcrun simctl install ${SIM_UDID} \\
    build/ios/iphonesimulator/Runner.app
EOM
  exit 5
fi

log "2/5  Mark OSLog window start"
WINDOW_START="$(date -u '+%Y-%m-%d %H:%M:%S')"

log "3/5  Run Maestro flow (this can take 5-11 min)"
JAVA_HOME="${JAVA_HOME_OPENJDK21}" \
  maestro --device "${SIM_UDID}" test "${FLOW}" \
  > "${RUN_DIR}/maestro.log" 2>&1 \
  || log "    (maestro exited non-zero — expected, cassure #4 still fails)"

log "4/5  Dump OSLog (category=ch.mint.http) since ${WINDOW_START}"
xcrun simctl spawn "${SIM_UDID}" log show \
  --start "${WINDOW_START}" \
  --predicate 'category == "ch.mint.http"' \
  --style compact \
  > "${RUN_DIR}/http.oslog" 2>/dev/null || true

bodies_file="${RUN_DIR}/anonymous-chat-bodies.txt"
grep -E "BODY req_id=" "${RUN_DIR}/http.oslog" \
  | grep -E "anonymous/chat" \
  > "${bodies_file}" || true

n="$(wc -l < "${bodies_file}" | tr -d ' ')"
log "5/5  Classify (${n} BODY entries captured for anonymous/chat)"

if [[ "${n}" -eq 0 ]]; then
  cat >&2 <<'EOM'
VERDICT: NO BODY CAPTURE.
Likely cause: staging is not running the obs spine yet (PR #592 not deployed).
Action: confirm staging has the MintHttpClient changes, then re-run.
EOM
  exit 4
fi

third_body="$(tail -1 "${bodies_file}")"
echo "Last BODY line:"
echo "${third_body}"

verdict_file="${RUN_DIR}/VERDICT.txt"

if grep -qE '"messagesRemaining"\s*:\s*0[,}]' <<<"${third_body}"; then
  cat <<'EOM' | tee "${verdict_file}"
VERDICT: H4b — parser sees int 0 correctly OR client-state gate not firing.
Bytes received: messagesRemaining: 0 (int).
Action: inspect anonymous_chat_screen.dart:269 — the if-condition or the
        order of setState vs _showAuthGate(). May actually be H4c (race).
EOM
elif grep -qE '"messagesRemaining"\s*:\s*"0"' <<<"${third_body}"; then
  cat <<'EOM' | tee "${verdict_file}"
VERDICT: H4b CONFIRMED — backend serialized messagesRemaining as String "0".
The client cast (`as int?`) returns null, so the gate never fires.
Action: coerce String→int in syncAnonymousRemainingFromResponse, or
        fix the backend Pydantic model to emit int.
EOM
elif ! grep -q '"messagesRemaining"' <<<"${third_body}"; then
  cat <<'EOM' | tee "${verdict_file}"
VERDICT: H4a — messagesRemaining field ABSENT from the response.
Action: inspect backend AnonymousChatResponse Pydantic model AND the
        request path: curl baseline used direct /api/v1/anonymous/chat,
        but the sim may hit a different routing (gateway, version prefix).
EOM
else
  cat <<EOM | tee "${verdict_file}"
VERDICT: H4?? — body has messagesRemaining in an unexpected shape.
        Hand-inspect ${bodies_file}.
EOM
fi

log "Done. Artifacts in ${RUN_DIR}/"
echo "  - maestro.log               (full Maestro stdout)"
echo "  - http.oslog                (full ch.mint.http OSLog dump)"
echo "  - anonymous-chat-bodies.txt (filtered BODY lines for anonymous/chat)"
echo "  - VERDICT.txt               (classification)"

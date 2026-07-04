#!/usr/bin/env bash
set -euo pipefail

mode="${1:-bootstrap}"

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: missing required file: $file" >&2
    exit 1
  fi
}

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $name" >&2
    exit 127
  fi
}

check_maestro_version() {
  local min_version="${MINT_MIN_MAESTRO_VERSION:-2.5.1}"
  local version
  version="$(maestro --version | tr -d '[:space:]')"
  python3 - "$version" "$min_version" <<'PY'
import sys

actual = tuple(int(part) for part in sys.argv[1].split("."))
minimum = tuple(int(part) for part in sys.argv[2].split("."))
width = max(len(actual), len(minimum))
actual = actual + (0,) * (width - len(actual))
minimum = minimum + (0,) * (width - len(minimum))
if actual < minimum:
    raise SystemExit(
        f"ERROR: Maestro {sys.argv[1]} is below required {sys.argv[2]}"
    )
PY
}

normalize_generated_l10n_line_endings() {
  require_command perl
  perl -0pi -e 's/\r\n/\n/g' apps/mobile/lib/l10n/app_localizations*.dart
}

export_mint_ios_codesign_path() {
  local codesign_dir="$PWD/apps/mobile/ios/mint_xcode_tools"
  local codesign_wrapper="$codesign_dir/codesign"

  if [[ ! -x "$codesign_wrapper" ]]; then
    echo "ERROR: missing executable MINT iOS codesign wrapper: $codesign_wrapper" >&2
    exit 1
  fi

  export PATH="$codesign_dir:$PATH"
}

maestro_check_syntax() {
  local flow="$1"
  local timeout_seconds="${MINT_MAESTRO_CHECK_TIMEOUT_SECONDS:-360}"
  local started_at
  local finished_at
  local rc
  require_file "$flow"
  started_at="$(date +%s)"
  printf '[mint-gate] maestro check-syntax start %s\n' "$flow" >&2
  set +e
  python3 - "$timeout_seconds" "$flow" <<'PY'
import os
import signal
import subprocess
import sys
import tempfile

timeout_seconds = int(sys.argv[1])
flow = sys.argv[2]
stderr_file = None
stderr_path = None
try:
    stderr_file = tempfile.NamedTemporaryFile(
        mode="w+",
        encoding="utf-8",
        prefix="mint-maestro-check.",
        suffix=".stderr",
        delete=False,
    )
    stderr_path = stderr_file.name
    proc = subprocess.Popen(
        ["maestro", "check-syntax", flow],
        stdout=subprocess.DEVNULL,
        stderr=stderr_file,
        text=True,
        preexec_fn=os.setsid,
    )
    proc.wait(timeout=timeout_seconds)
except subprocess.TimeoutExpired:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
        proc.wait(timeout=5)
    except Exception:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except Exception:
            pass
    print(
        f"ERROR: maestro check-syntax timed out after {timeout_seconds}s: {flow}",
        file=sys.stderr,
    )
    sys.exit(124)
finally:
    try:
        stderr_file.close()
    except Exception:
        pass

if proc.returncode != 0:
    stderr = ""
    if stderr_path:
        try:
            with open(stderr_path, encoding="utf-8") as handle:
                stderr = handle.read()
        except OSError:
            stderr = ""
    if stderr:
        print(stderr, file=sys.stderr, end="" if stderr.endswith("\n") else "\n")
    sys.exit(proc.returncode)

if stderr_path:
    try:
        os.unlink(stderr_path)
    except OSError:
        pass
PY
  rc=$?
  set -e
  finished_at="$(date +%s)"
  if [[ "$rc" -eq 0 ]]; then
    printf '[mint-gate] maestro check-syntax ok %s (%ss)\n' "$flow" "$((finished_at - started_at))" >&2
  else
    printf '[mint-gate] maestro check-syntax failed %s (%ss, rc=%s)\n' "$flow" "$((finished_at - started_at))" "$rc" >&2
  fi
  return "$rc"
}

kill_process_tree() {
  local pid="$1"
  local child

  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    kill_process_tree "$child"
  done

  kill "$pid" 2>/dev/null || true
}

check_agents() {
  local agents=(
    mint-lead
    mint-quality-gate
    mint-swiss-brain
    mint-data-ledger-architect
    mint-data-quest-architect
    mint-backend
    mint-mobile
    mint-lucidity-pdf
    mint-external-auditor
  )

  for agent in "${agents[@]}"; do
    local file=".claude/agents/${agent}.md"
    require_file "$file"
    grep -q '^name:' "$file"
    grep -q '^description:' "$file"
  done
}

compile_mermaid() {
  local evidence_dir
  if [[ -n "${MINT_EVIDENCE_DIR:-}" ]]; then
    evidence_dir="$MINT_EVIDENCE_DIR"
    mkdir -p "$evidence_dir"
  else
    evidence_dir="$(mktemp -d "${TMPDIR:-/tmp}/mint-lucidity-mermaid.XXXXXX")"
  fi
  npx -y @mermaid-js/mermaid-cli \
    -i docs/codex/WIRING_GRAPH.mmd \
    -o "$evidence_dir/WIRING_GRAPH.svg" \
    >/dev/null
  test -s "$evidence_dir/WIRING_GRAPH.svg"
  echo "Mermaid evidence: $evidence_dir/WIRING_GRAPH.svg"
}

validate_evidence_dir() {
  local evidence_dir="${MINT_EVIDENCE_DIR:-}"
  if [[ -z "$evidence_dir" ]]; then
    return 0
  fi

  local base
  base="$(basename "$evidence_dir")"
  if [[ ! "$base" =~ ^mint-lucidity-[a-z0-9-]+-[0-9]{8}T[0-9]{6}$ ]]; then
    echo "ERROR: evidence folder must match mint-lucidity-<phase>-YYYYMMDDTHHMMSS: $base" >&2
    exit 1
  fi
}

check_cli_exception_ledger() {
  python3 - <<'PY'
import json
from pathlib import Path

path = Path(".planning/runtime-evidence/cli_exception_ledger.json")
if path.exists():
    data = json.loads(path.read_text())
else:
    data = {"consumed": False, "entries": []}
assert isinstance(data.get("consumed"), bool), "consumed must be boolean"
assert isinstance(data.get("entries"), list), "entries must be list"
for entry in data["entries"]:
    for key in ("phase", "command", "failure_mode", "retry_plan", "consumed_at"):
        assert key in entry, f"entry missing {key}"
PY
}

check_final_bootstrap_audit() {
  local evidence_dir="${MINT_EVIDENCE_DIR:-}"
  if [[ -z "$evidence_dir" || ! -f "$evidence_dir/SCORECARD.md" ]]; then
    return 0
  fi

  local final_audit="$evidence_dir/claude-bootstrap-audit-final.md"
  require_file "$final_audit"
  if ! grep -q 'NO_UNRESOLVED_CRITICAL_HIGH' "$final_audit"; then
    echo "ERROR: final bootstrap audit lacks NO_UNRESOLVED_CRITICAL_HIGH marker" >&2
    exit 1
  fi
}

check_phase_acceptance_artifacts() {
  local phase="$1"
  local evidence_dir="${MINT_EVIDENCE_DIR:-}"
  if [[ -z "$evidence_dir" ]]; then
    echo "ERROR: MINT_EVIDENCE_DIR is required for $phase acceptance" >&2
    exit 1
  fi

  require_file "$evidence_dir/SCORECARD.md"
  require_file "$evidence_dir/claude-${phase}-audit.md"
  grep -q 'NO_UNRESOLVED_CRITICAL_HIGH' "$evidence_dir/claude-${phase}-audit.md"
  grep -q 'cli_exception_consumed: false' "$evidence_dir/SCORECARD.md"
  grep -Eq 'mint-quality-gate score: 9\.[0-9]+/10|mint-quality-gate score: 10(\.0)?/10' "$evidence_dir/SCORECARD.md"
  grep -q 'mint-quality-gate co-signature:' "$evidence_dir/SCORECARD.md"
  grep -q 'mint-lead countersignature:' "$evidence_dir/SCORECARD.md"
}

run_phase2_runtime_gate() {
  validate_evidence_dir
  check_cli_exception_ledger
  check_phase2_data_quest_contract
  compile_mermaid
  bash "$0" ledger
  bash "$0" mobile-data-quest

  if [[ -z "${MINT_PHASE2_MAESTRO_FLOW:-}" ]]; then
    echo "ERROR: set MINT_PHASE2_MAESTRO_FLOW to an executable Phase 2 Maestro YAML" >&2
    exit 1
  fi
  local local_phase2_reconfirm_flow
  local_phase2_reconfirm_flow="${MINT_PHASE2_RECONFIRM_MAESTRO_FLOW:-apps/mobile/.maestro/phase2_data_quest_reconfirm.yaml}"
  check_phase2_maestro_contract "$MINT_PHASE2_MAESTRO_FLOW"
  check_phase2_reconfirm_maestro_contract "$local_phase2_reconfirm_flow"
  if [[ "${MINT_PHASE2_SKIP_MAESTRO:-}" == "1" ]]; then
    echo "ERROR: Phase 2 acceptance requires executed Maestro runtime proof; do not set MINT_PHASE2_SKIP_MAESTRO=1" >&2
    exit 1
  fi
  install_phase2_flutter_app_if_requested
  run_phase2_maestro "$MINT_PHASE2_MAESTRO_FLOW"
  run_phase2_reconfirm_maestro "$local_phase2_reconfirm_flow"
}

check_no_open_baseline_highs() {
  local evidence_dir="${MINT_EVIDENCE_DIR:-}"
  local audit="$evidence_dir/DATA_LEDGER_BASELINE_AUDIT.md"
  require_file "$audit"
  if grep -q '^status: baseline-audit-open' "$audit"; then
    echo "ERROR: baseline audit is still open" >&2
    exit 1
  fi
  if grep -Eq '^### (CRITICAL|HIGH) ' "$audit"; then
    echo "ERROR: baseline audit still contains unresolved CRITICAL/HIGH headings" >&2
    exit 1
  fi
}

check_phase1_maestro_contract() {
  local flow="$1"
  local active_flow
  active_flow="$(sed '/^[[:space:]]*#/d' "$flow")"
  grep -q 'MINT_ENABLE_RUNTIME_PROOF_SEMANTICS: "true"' <<<"$active_flow"
  grep -q 'MINT_TEST_TRANSMIT_PROPERTY_FIXTURE: "raiffeisen_status"' <<<"$active_flow"
  grep -Eq 'assertVisible:|assertVisible:' "$flow"
  grep -q 'id: "succession_ledger_property_value"' "$flow"
  grep -Fq "text: \"Base ledger: CHF 1'200'000\"" "$flow"
  grep -q 'id: "succession_ledger_data_key"' "$flow"
  grep -q 'id: "succession_ledger_profile_owner_id"' "$flow"
  grep -q 'id: "succession_ledger_scenario_id"' "$flow"
  grep -q 'id: "succession_ledger_source"' "$flow"
  grep -Fq 'text: "source: estimated"' "$flow"
  grep -q 'id: "succession_ledger_confidence"' "$flow"
  grep -Fq 'text: "confidence: medium"' "$flow"
  grep -q 'id: "succession_runtime_scenario_statuses"' "$flow"
  grep -Fq "text: \"scenario_statuses: needs_review | CHF -8'000 | at_risk | CHF 195'000\"" "$flow"
  grep -q 'id: "succession_runtime_scenario_confidence"' "$flow"
  grep -Fq 'text: "scenario_confidence: medium"' "$flow"
  grep -q 'id: "succession_runtime_scenario_model_scope"' "$flow"
  grep -Fq 'text: "classification=educational_triage;not_legal_partition=true;requires_specialist_review=true"' "$flow"
  grep -q 'id: "succession_runtime_scenario_cantonal_tax"' "$flow"
  grep -Fq 'text: "canton=VD;requires_cantonal_review=true"' "$flow"
  grep -q 'id: "succession_runtime_scenario_assumption"' "$flow"
  grep -Fq "text: \"Hypothèse locale : versement, reprise hypothécaire et droit d'habitation saisis.\"" "$flow"
}

check_phase2_data_quest_contract() {
  require_file docs/codex/P0_CASE_VARIABLE_REGISTRY.json
  require_file docs/codex/ANDROID_RUNTIME_BLOCKERS.md
  require_file apps/mobile/lib/services/data_quest/case_registry.dart
  require_file apps/mobile/lib/services/data_quest/data_quest_service.dart
  require_file apps/mobile/lib/services/dossier/dossier_payload_service.dart
  require_file apps/mobile/lib/services/startup_route_override.dart
  require_file apps/mobile/test/services/data_quest/data_quest_service_test.dart
  require_file apps/mobile/test/services/dossier/dossier_payload_service_test.dart
  require_file apps/mobile/test/services/startup_route_override_parser_test.dart
  require_file apps/mobile/.maestro/phase2_data_quest_transmit_property.yaml
  require_file apps/mobile/.maestro/phase2_data_quest_reconfirm.yaml
  require_file docs/codex/dossier_stubs/dossier_first_salary_tax.schema.json
  require_file docs/codex/dossier_stubs/dossier_buy_property.schema.json
  require_file docs/codex/dossier_stubs/dossier_transmit_property.schema.json
  grep -q '"minimum_variables"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
  grep -q '"useful_variables"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
  grep -q '"blocking_guard_questions"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
  grep -q '"required_questions"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
  grep -q '"enrichment_questions"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
  grep -q '"pdf_section_id"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
  grep -q '"dossier_contract"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
  grep -q '"maestro_flow_id"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
  grep -q 'ANDROID-PHASE1-PHASE2-RUNTIME-PROOF' docs/codex/ANDROID_RUNTIME_BLOCKERS.md
  grep -q 'MINT_TEST_PROPERTY_VALUE' apps/mobile/lib/services/startup_route_override_parser.dart
  grep -q 'MINT_TEST_PROPERTY_STALE' apps/mobile/lib/services/startup_route_override_parser.dart
  grep -q 'readMintDebugPropertyValueStaleSeed' apps/mobile/lib/app.dart
  grep -q 'dataQuestFactsFromProfile' apps/mobile/lib/services/dossier/dossier_payload_service.dart
  grep -q 'fresh transmit_property profile metadata feeds Data Quest facts' apps/mobile/test/services/dossier/dossier_payload_service_test.dart
  grep -q 'mintRuntimeProofStalePropertyValueDate' apps/mobile/lib/services/startup_route_override.dart
  grep -q 'mintRuntimeProofStalePropertyValueDate' apps/mobile/lib/app.dart
  grep -q 'FreshnessDecayService.needsRefresh' apps/mobile/test/services/startup_route_override_parser_test.dart
  python3 - <<'PY'
import json
from pathlib import Path

root = Path(".")
registry = json.loads(Path("docs/codex/P0_CASE_VARIABLE_REGISTRY.json").read_text())
for case_id, case in registry["cases"].items():
    path = root / case["dossier_contract"]
    assert path.exists(), f"{case_id} dossier contract missing: {path}"
    contract = json.loads(path.read_text())
    assert contract["x-mint-owner"] == "mint-lucidity-pdf"
    assert contract["x-mint-case-id"] == case_id
    assert contract["x-mint-pdf-section-id"] == case["pdf_section_id"]
    assert contract["properties"]["case_id"]["const"] == case_id
    assert contract["properties"]["pdf_section_id"]["const"] == case["pdf_section_id"]
PY
  grep -q 'DataQuestService.planCase' apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  grep -q 'DataQuestProofStrip' apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  grep -q 'answersSnapshot' apps/mobile/lib/providers/coach_profile_provider.dart
  grep -q "\${semanticsPrefix}_data_quest_next_ask" apps/mobile/lib/widgets/data_quest/data_quest_proof_strip.dart
  grep -q '_runtimeProofDebugLabelsEnabled' apps/mobile/lib/widgets/data_quest/data_quest_proof_strip.dart
  grep -q "bool.fromEnvironment('MINT_ENABLE_RUNTIME_PROOF_SEMANTICS')" apps/mobile/lib/widgets/data_quest/data_quest_proof_strip.dart
  grep -q 'next_ask_value: $nextAsk' apps/mobile/lib/widgets/data_quest/data_quest_proof_strip.dart
  # The next_ask_value text is an explicit debug/runtime-proof label. Maestro
  # flows that assert it must run on debug builds or with the runtime-proof
  # dart-define enabled, never as a normal release product proof.
  grep -q 'text: "Prochaine donnée à confirmer"' apps/mobile/.maestro/phase2_data_quest_transmit_property.yaml
  grep -q 'text: "next_ask_value: propertyMarketValue"' apps/mobile/.maestro/phase2_data_quest_transmit_property.yaml
  grep -q 'text: "next_ask_value: targetRetirementAge"' apps/mobile/.maestro/phase2_data_quest_transmit_property.yaml
  grep -q 'text: "Donnée manquante à collecter"' apps/mobile/.maestro/phase2_data_quest_transmit_property.yaml
  grep -q 'text: "Indispensable avant le calcul"' apps/mobile/.maestro/phase2_data_quest_transmit_property.yaml
  grep -q 'text: "next_ask_value: propertyMarketValue"' apps/mobile/.maestro/phase2_data_quest_reconfirm.yaml
}

check_phase2_maestro_contract() {
  local flow="$1"
  require_file "$flow"
  grep -q 'MINT_ENABLE_RUNTIME_PROOF_SEMANTICS: "true"' "$flow"
  grep -q 'id: "succession_data_quest_contract"' "$flow"
  grep -q 'id: "succession_data_quest_next_ask"' "$flow"
  grep -q 'text: "Prochaine donnée à confirmer"' "$flow"
  grep -q 'text: "Donnée manquante à collecter"' "$flow"
  grep -q 'text: "Indispensable avant le calcul"' "$flow"
  grep -q 'text: "next_ask_value: propertyMarketValue"' "$flow"
  grep -q 'text: "next_ask_value: targetRetirementAge"' "$flow"
  grep -q 'MINT_TEST_PROPERTY_VALUE: "1200000"' "$flow"
  maestro_check_syntax "$flow"
}

check_phase2_reconfirm_maestro_contract() {
  local flow="$1"
  require_file "$flow"
  grep -q 'MINT_ENABLE_RUNTIME_PROOF_SEMANTICS: "true"' "$flow"
  grep -q 'MINT_TEST_PROPERTY_VALUE: "1200000"' "$flow"
  grep -q 'MINT_TEST_PROPERTY_STALE: "true"' "$flow"
  grep -q 'id: "succession_data_quest_contract"' "$flow"
  grep -q 'text: "Prochaine donnée à confirmer"' "$flow"
  grep -q 'text: "next_ask_value: propertyMarketValue"' "$flow"
  grep -q 'text: "Valeur existante à confirmer"' "$flow"
  grep -q 'text: "Indispensable avant le calcul"' "$flow"
  maestro_check_syntax "$flow"
}

check_phase1_maestro_output_complete() {
  local log="$1"

  require_file "$log"
  grep -q 'Launch app "ch.mint.app".*COMPLETED' "$log"
  grep -q 'Assert that id: succession_ledger_property_value is visible... COMPLETED' "$log"
  grep -Fq "Assert that \"Base ledger: CHF 1'200'000\" is visible... COMPLETED" "$log"
  grep -q 'Assert that id: succession_ledger_data_key is visible... COMPLETED' "$log"
  grep -q 'Assert that id: succession_ledger_profile_owner_id is visible... COMPLETED' "$log"
  grep -q 'Assert that id: succession_ledger_scenario_id is visible... COMPLETED' "$log"
  grep -q 'Assert that id: succession_ledger_source is visible... COMPLETED' "$log"
  grep -q 'Assert that "source: estimated" is visible... COMPLETED' "$log"
  grep -q 'Assert that id: succession_ledger_confidence is visible... COMPLETED' "$log"
  grep -q 'Assert that "confidence: medium" is visible... COMPLETED' "$log"
  grep -q 'Assert that id: succession_runtime_scenario_statuses is visible... COMPLETED' "$log"
  grep -Fq "Assert that \"scenario_statuses: needs_review | CHF -8'000 | at_risk | CHF 195'000\" is visible... COMPLETED" "$log"
  grep -q 'Assert that id: succession_runtime_scenario_confidence is visible... COMPLETED' "$log"
  grep -q 'Assert that "scenario_confidence: medium" is visible... COMPLETED' "$log"
  grep -q 'Assert that id: succession_runtime_scenario_model_scope is visible... COMPLETED' "$log"
  grep -q 'Assert that "classification=educational_triage;not_legal_partition=true;requires_specialist_review=true" is visible... COMPLETED' "$log"
  grep -q 'Assert that id: succession_runtime_scenario_cantonal_tax is visible... COMPLETED' "$log"
  grep -q 'Assert that "canton=VD;requires_cantonal_review=true" is visible... COMPLETED' "$log"
  grep -q 'Assert that id: succession_runtime_scenario_assumption is visible... COMPLETED' "$log"
  grep -Fq "Assert that \"Hypothèse locale : versement, reprise hypothécaire et droit d'habitation saisis.\" is visible... COMPLETED" "$log"
}

run_phase1_maestro() {
  local flow="$1"
  local log
  local timeout_seconds="${MINT_PHASE1_MAESTRO_TIMEOUT_SECONDS:-300}"
  local elapsed=0
  local status

  if [[ -n "${MINT_EVIDENCE_DIR:-}" ]]; then
    log="$MINT_EVIDENCE_DIR/phase1-maestro.txt"
  else
    log="$(mktemp "${TMPDIR:-/tmp}/mint-phase1-maestro.XXXXXX.log")"
  fi

  rm -f "$log"
  (
    set -o pipefail
    maestro test "$flow" 2>&1 | tee "$log"
  ) &
  local pid="$!"

  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= timeout_seconds )); then
      if check_phase1_maestro_output_complete "$log"; then
        echo "ERROR: Maestro timed out after completed assertions; timeout remains fatal to catch post-assertion crashes." >&2
      else
        echo "ERROR: Maestro did not complete required assertions within ${timeout_seconds}s" >&2
      fi
      kill_process_tree "$pid"
      wait "$pid" 2>/dev/null || true
      return 124
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  set +e
  wait "$pid"
  status="$?"
  set -e
  if [[ "$status" -ne 0 ]]; then
    return "$status"
  fi

  check_phase1_maestro_output_complete "$log"
}

run_phase2_maestro() {
  local flow="$1"
  local log
  local timeout_seconds="${MINT_PHASE2_MAESTRO_TIMEOUT_SECONDS:-300}"
  local elapsed=0
  local status

  if [[ -n "${MINT_EVIDENCE_DIR:-}" ]]; then
    log="$MINT_EVIDENCE_DIR/phase2-maestro.txt"
  else
    log="$(mktemp "${TMPDIR:-/tmp}/mint-phase2-maestro.XXXXXX.log")"
  fi

  rm -f "$log"
  (
    set -o pipefail
    maestro test "$flow" 2>&1 | tee "$log"
  ) &
  local pid="$!"

	  while kill -0 "$pid" 2>/dev/null; do
	    if (( elapsed >= timeout_seconds )); then
	      echo "ERROR: Maestro Phase 2 did not complete within ${timeout_seconds}s" >&2
	      kill_process_tree "$pid"
	      wait "$pid" 2>/dev/null || true
      return 124
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  set +e
  wait "$pid"
  status="$?"
  set -e
  if [[ "$status" -ne 0 ]]; then
    return "$status"
  fi

  check_phase2_maestro_output_complete "$log"
}

run_phase2_reconfirm_maestro() {
  local flow="$1"
  local log
  local timeout_seconds="${MINT_PHASE2_MAESTRO_TIMEOUT_SECONDS:-300}"
  local elapsed=0
  local status

  if [[ -n "${MINT_EVIDENCE_DIR:-}" ]]; then
    log="$MINT_EVIDENCE_DIR/phase2-reconfirm-maestro.txt"
  else
    log="$(mktemp "${TMPDIR:-/tmp}/mint-phase2-reconfirm-maestro.XXXXXX.log")"
  fi

  rm -f "$log"
  (
    set -o pipefail
    maestro test "$flow" 2>&1 | tee "$log"
  ) &
  local pid="$!"

  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= timeout_seconds )); then
      echo "ERROR: Maestro Phase 2 reconfirm did not complete within ${timeout_seconds}s" >&2
      kill_process_tree "$pid"
      wait "$pid" 2>/dev/null || true
      return 124
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  set +e
  wait "$pid"
  status="$?"
  set -e
  if [[ "$status" -ne 0 ]]; then
    return "$status"
  fi

  check_phase2_reconfirm_maestro_output_complete "$log"
}

check_phase2_maestro_output_complete() {
  local log="$1"

  require_file "$log"
  grep -q 'Assert that id: succession_data_quest_next_ask is visible... COMPLETED' "$log"
  grep -q 'Assert that "Prochaine donnée à confirmer" is visible... COMPLETED' "$log"
  grep -q 'Assert that "next_ask_value: propertyMarketValue" is visible... COMPLETED' "$log"
  grep -q 'Assert that "next_ask_value: targetRetirementAge" is visible... COMPLETED' "$log"
  grep -q 'Assert that "Donnée manquante à collecter" is visible... COMPLETED' "$log"
  grep -q 'Assert that "Indispensable avant le calcul" is visible... COMPLETED' "$log"
  grep -q 'MINT_TEST_PROPERTY_VALUE=1200000' "$log"
}

check_phase2_reconfirm_maestro_output_complete() {
  local log="$1"

  require_file "$log"
  grep -q 'MINT_TEST_PROPERTY_STALE=true' "$log"
  grep -q 'Assert that id: succession_data_quest_next_ask is visible... COMPLETED' "$log"
  grep -q 'Assert that "Prochaine donnée à confirmer" is visible... COMPLETED' "$log"
  grep -q 'Assert that "next_ask_value: propertyMarketValue" is visible... COMPLETED' "$log"
  grep -q 'Assert that "Valeur existante à confirmer" is visible... COMPLETED' "$log"
  grep -q 'Assert that "Indispensable avant le calcul" is visible... COMPLETED' "$log"
}

run_mobile_patrol_test() {
  local mobile_test_path="$1"
  local device_id="${MINT_PATROL_DEVICE_ID:-${2:-}}"
  local patrol_bin="${MINT_PATROL_BIN:-}"
  local build_dir="${MINT_PATROL_BUILD_DIR:-/tmp/mint-mobile-build}"
  local rc

  if [[ -z "$device_id" ]]; then
    echo "ERROR: Patrol gate requires MINT_PATROL_DEVICE_ID or a device id argument" >&2
    exit 2
  fi

  if [[ -z "$patrol_bin" ]]; then
    if command -v patrol >/dev/null 2>&1; then
      patrol_bin="$(command -v patrol)"
    else
      patrol_bin="$HOME/.pub-cache/bin/patrol"
    fi
  fi
  if [[ ! -x "$patrol_bin" ]]; then
    echo "ERROR: patrol CLI not found or not executable: $patrol_bin" >&2
    exit 127
  fi

  require_file "apps/mobile/$mobile_test_path"
  require_file apps/mobile/pubspec.yaml
  grep -q '^patrol:' apps/mobile/pubspec.yaml
  grep -q 'test_directory: test/patrol' apps/mobile/pubspec.yaml
  grep -q 'package_name: ch.mint.coach' apps/mobile/pubspec.yaml
  grep -q 'bundle_id: ch.mint.app' apps/mobile/pubspec.yaml
  bash apps/mobile/scripts/patch_patrol_xcode26_2.sh
  export_mint_ios_codesign_path

  mkdir -p "$build_dir"
  if [[ -e apps/mobile/build && ! -L apps/mobile/build ]]; then
    mv apps/mobile/build "$build_dir-prev-$(date +%Y%m%d%H%M%S)"
  fi
  if [[ ! -L apps/mobile/build ]]; then
    ln -s "$build_dir" apps/mobile/build
  fi

  if [[ "${MINT_PATROL_CLEAN_BUILD:-1}" == "1" ]]; then
    rm -rf "$build_dir/ios_integ"
    find "$build_dir" -maxdepth 1 -name 'ios_results_*.xcresult' -exec rm -rf {} +
  fi

  if xcrun simctl list devices 2>/dev/null | grep -Fq "$device_id"; then
    xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$device_id" -b >/dev/null
  else
    printf '[mint-gate] Patrol device %s is not an iOS simulator; skipping simctl boot\n' "$device_id" >&2
  fi

  set +e
  (
    cd apps/mobile
    trap 'rm -f test/patrol/test_bundle.dart patrol_test/test_bundle.dart' EXIT
    "$patrol_bin" test \
      -t "$mobile_test_path" \
      -d "$device_id" \
      --no-check-compatibility \
      --no-uninstall
  )
  rc=$?
  set -e
  normalize_generated_l10n_line_endings
  return "$rc"
}

run_f2_patrol() {
  run_mobile_patrol_test test/patrol/f2_datablock_to_mortgage_patrol_test.dart "${1:-}"
}

run_first_salary_tax_patrol() {
  run_mobile_patrol_test test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart "${1:-}"
}

run_first_salary_tax_fatca_patrol() {
  run_mobile_patrol_test test/patrol/first_salary_tax_fatca_3a_patrol_test.dart "${1:-}"
}

run_transmit_property_patrol() {
  run_mobile_patrol_test test/patrol/transmit_property_patrol_test.dart "${1:-}"
}

run_budget_housing_frequency_patrol() {
  run_mobile_patrol_test test/patrol/budget_housing_frequency_patrol_test.dart "${1:-}"
}

run_p0_patrol_suite() {
  local device_id="${1:-}"

  run_first_salary_tax_patrol "$device_id"
  run_first_salary_tax_fatca_patrol "$device_id"
  run_f2_patrol "$device_id"
  run_transmit_property_patrol "$device_id"
}

check_phase1_runtime_args_guard() {
  grep -q 'proc.wait(timeout=timeout_seconds)' tools/checks/mint_lucidity_gate.sh
  grep -q 'preexec_fn=os.setsid' tools/checks/mint_lucidity_gate.sh
  grep -q 'os.killpg(proc.pid, signal.SIGTERM)' tools/checks/mint_lucidity_gate.sh
  grep -q 'sys.exit(124)' tools/checks/mint_lucidity_gate.sh
  grep -q '#if DEBUG || targetEnvironment(simulator)' apps/mobile/ios/Runner/AppDelegate.swift
  grep -q 'allowsRuntimeArgsChannel' apps/mobile/android/app/src/main/kotlin/ch/mint/coach/MainActivity.kt
  grep -q 'ENABLE_RUNTIME_ARGS_CHANNEL' apps/mobile/android/app/build.gradle
  grep -q 'BuildConfig.ENABLE_RUNTIME_ARGS_CHANNEL' apps/mobile/android/app/src/main/kotlin/ch/mint/coach/MainActivity.kt
  grep -q 'MINT_ENABLE_RUNTIME_PROOF_SEMANTICS' apps/mobile/lib/services/startup_route_override_parser.dart
  grep -q 'MINT_TEST_PROPERTY_VALUE' apps/mobile/lib/services/startup_route_override_parser.dart
  grep -q 'MINT_TEST_TRANSMIT_PROPERTY_FIXTURE' apps/mobile/lib/services/startup_route_override_parser.dart
  grep -q 'MINT_TEST_REPORT_FIXTURE' apps/mobile/lib/services/startup_route_override_parser.dart
  grep -q 'readMintRuntimeProofSemanticsFlag' apps/mobile/lib/services/startup_route_override_platform_io.dart
  grep -q 'readMintTestReportFixture' apps/mobile/lib/services/startup_route_override_platform_io.dart
  grep -q 'readMintRuntimeProofSemanticsEnabled' apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  grep -q '_mintRuntimeProofInputsEnabled' apps/mobile/lib/services/startup_route_override.dart
  if grep -q 'if (!kDebugMode) return null' apps/mobile/lib/services/startup_route_override.dart; then
    echo "ERROR: runtime proof seeds must not be debug-only" >&2
    exit 1
  fi
  python3 - <<'PY'
from pathlib import Path

text = Path("apps/mobile/lib/services/startup_route_override.dart").read_text()
body = text.split("Future<bool> _mintRuntimeProofInputsEnabled() async {", 1)[1]
body = body.split("@visibleForTesting", 1)[0]
if "kDebugMode" in body:
    raise SystemExit(
        "ERROR: runtime proof input seeds must not auto-enable in debug mode"
    )
for token in (
    "_mintRuntimeProofInputsCompileTimeEnabled",
    "platform.readMintRuntimeProofSemanticsFlag()",
):
    if token not in body:
        raise SystemExit(f"ERROR: runtime proof input gate missing {token}")
for function, fallback in (
    ("readMintDebugInitialRoute", "return null"),
    ("readMintDebugPropertyValueSeed", "return null"),
    ("readMintDebugRevenueAnnualSeed", "return null"),
    ("readMintDebugCantonSeed", "return null"),
    ("readMintDebugPropertyValueStaleSeed", "return false"),
    ("readMintDebugTransmitPropertyFixtureSeed", "return null"),
    ("readMintDebugReportFixtureSeed", "return null"),
):
    segment = text.split(f"Future", 1)[1]
    start = text.index(f"{function}() async")
    end = text.find("\n}\n", start)
    if end == -1:
        raise SystemExit(f"ERROR: cannot parse {function}")
    segment = text[start:end]
    guard = f"if (!await _mintRuntimeProofInputsEnabled()) {fallback};"
    if guard not in segment:
        raise SystemExit(f"ERROR: {function} is missing input gate guard")
PY
}

check_report_maestro_contract() {
  local flow="apps/mobile/.maestro/r3_report_pillar3a_action.yaml"
  local dossier_flow="apps/mobile/.maestro/r3c_report_dossier_export.yaml"
  require_file "$flow"
  require_file "$dossier_flow"
  grep -q 'MINT_ENABLE_RUNTIME_PROOF_SEMANTICS: "true"' "$flow"
  grep -q 'MINT_TEST_INITIAL_ROUTE: "/rapport"' "$flow"
  grep -q 'MINT_TEST_REPORT_FIXTURE: "first_salary_tax_vd"' "$flow"
  grep -q 'id: "report_action_pillar3a_card"' "$flow"
  grep -q 'id: "report_action_pillar3a_cta"' "$flow"
  grep -q 'openLink: "mint:///pilier-3a"' "$flow"
  grep -q 'text: "Ton 3e pilier"' "$flow"
  maestro_check_syntax "$flow"
  grep -q 'MINT_ENABLE_RUNTIME_PROOF_SEMANTICS: "true"' "$dossier_flow"
  grep -q 'MINT_TEST_INITIAL_ROUTE: "/rapport"' "$dossier_flow"
  grep -q 'MINT_TEST_REPORT_FIXTURE: "first_salary_tax_vd"' "$dossier_flow"
  grep -q 'id: "report_dossier_transmit_property_card"' "$dossier_flow"
  grep -q 'id: "report_dossier_transmit_property_export_cta"' "$dossier_flow"
  grep -A8 'id: "report_dossier_transmit_property_export_cta"' "$dossier_flow" | grep -q 'centerElement: false'
  grep -Fq 'Keep `centerElement: false`' docs/codex/MAESTRO_FLOWS.md
  maestro_check_syntax "$dossier_flow"
  grep -Fq 'report_action_${category.name}_cta' apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart
  grep -Fq "identifier: 'report_export_pdf_cta'" apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart
  grep -Fq 'report_dossier_${dossier.caseId}_export_cta' apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart
  grep -q 'buildFinancialReportPdfBytes' apps/mobile/lib/services/pdf_service.dart
  grep -q 'buildFinancialReportPdfAuditManifest' apps/mobile/lib/services/pdf_service.dart
  if grep -REq 'Statement of Advice|Plan annuel recommandé' \
    apps/mobile/lib/services/pdf_service.dart \
    apps/mobile/test/services/pdf_service_test.dart; then
    echo "ERROR: /rapport PDF must stay educational; advice-coded labels are forbidden" >&2
    exit 1
  fi
  grep -q 'buildDossierPayloadPdfBytes' apps/mobile/lib/services/pdf_service.dart
  grep -q 'buildDossierPayloadPdfAuditManifest' apps/mobile/lib/services/pdf_service.dart
  grep -q 'generateDossierPayloadPdf' apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart
  grep -Fq "const ['first_salary_tax', 'buy_property', 'transmit_property']" apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart
  grep -q 'DossierPayloadService.buildP0Case' apps/mobile/test/services/pdf_service_test.dart
  grep -q 'DossierPayloadSchemaValidator.validateJsonAgainstSchema' apps/mobile/test/services/dossier/dossier_payload_service_test.dart
  grep -q 'report_dossier_first_salary_tax_card' apps/mobile/test/screens/report_route_screen_test.dart
  grep -q 'report_dossier_first_salary_tax_export_cta' apps/mobile/test/screens/report_route_screen_test.dart
  grep -q 'report_dossier_buy_property_card' apps/mobile/test/screens/report_route_screen_test.dart
  grep -q 'report_dossier_buy_property_export_cta' apps/mobile/test/screens/report_route_screen_test.dart
  grep -q 'report_dossier_transmit_property_card' apps/mobile/test/screens/report_route_screen_test.dart
  grep -q 'report_dossier_transmit_property_export_cta' apps/mobile/test/screens/report_route_screen_test.dart
  grep -q 'PdfService.buildDossierPayloadPdfBytes' apps/mobile/test/screens/report_route_screen_test.dart
  grep -q "String.fromCharCodes(bytes.take(5)), '%PDF-'" apps/mobile/test/screens/report_route_screen_test.dart
  grep -q 'DossierPayloadSchemaValidator.validateJsonAgainstSchema' apps/mobile/test/screens/report_route_screen_test.dart
  grep -q '_loadPdfTheme' apps/mobile/lib/services/pdf_service.dart
  grep -q 'assets/fonts/Lato-Regular.ttf' apps/mobile/pubspec.yaml
  grep -q 'first_salary_tax_vd' apps/mobile/lib/app.dart
}

check_confidence_maestro_contract() {
  local flow="apps/mobile/.maestro/r3b_confidence_dashboard.yaml"
  require_file "$flow"
  grep -q 'MINT_ENABLE_RUNTIME_PROOF_SEMANTICS: "true"' "$flow"
  grep -q 'MINT_TEST_INITIAL_ROUTE: "/confidence"' "$flow"
  grep -q 'MINT_TEST_REPORT_FIXTURE: "first_salary_tax_vd"' "$flow"
  grep -Fq 'Précision de ton profil' "$flow"
  grep -q 'id: "confidence_score_gauge"' "$flow"
  grep -q 'ConfidenceRouteScreen' apps/mobile/lib/app.dart
  grep -q 'loadResult: _confidenceResultFromContext' apps/mobile/lib/app.dart
  grep -q 'profileProvider.answersSnapshot' apps/mobile/lib/app.dart
  grep -q "identifier: 'confidence_score_gauge'" apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart
  grep -q '_openEnrichmentPrompt(prompt)' apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart
  grep -Fq "/scan?type=" apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart
  grep -Fq "/data-block/" apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart
  grep -Fq "/open-banking" apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart
  grep -q "path: '/open-banking'" apps/mobile/lib/app.dart
}

check_maestro_route_coverage_manifest() {
  local entries=(
    "/succession|ios-only|apps/mobile/.maestro/f5_transmitting_property.yaml"
    "/scan/review|ios-only|apps/mobile/.maestro/r1_scan_review.yaml"
    "/scan/impact|ios-only|apps/mobile/.maestro/r2_scan_impact.yaml"
    "/rapport|ios-only|apps/mobile/.maestro/r3c_report_dossier_export.yaml"
    "/confidence|ios-only|apps/mobile/.maestro/r3b_confidence_dashboard.yaml"
    "/pilier-3a|ios-only|apps/mobile/.maestro/r3_report_pillar3a_action.yaml"
    "/divorce|blocked|apps/mobile/.maestro/f6_divorce.yaml"
    "/data-block/:type|ios-only|apps/mobile/.maestro/f2_datablock_to_mortgage.yaml"
    "/hypotheque|ios-only|apps/mobile/.maestro/f2_datablock_to_mortgage.yaml"
    "/retraite|blocked|apps/mobile/.maestro/f1_first_job.yaml"
  )
  local entry route status flow
  for entry in "${entries[@]}"; do
    IFS='|' read -r route status flow <<<"$entry"
    grep -Fq "path: '$route'" apps/mobile/lib/app.dart
    case "$status" in
      ios-only)
        require_file "$flow"
        maestro_check_syntax "$flow"
        ;;
      cross-platform)
        echo "ERROR: cross-platform Maestro runtime coverage is not available while docs/codex/ANDROID_RUNTIME_BLOCKERS.md is OPEN" >&2
        exit 1
        ;;
      blocked)
        grep -Fq "$flow" docs/codex/MAESTRO_FLOWS.md
        ;;
      *)
        echo "ERROR: unknown route coverage status '$status' for $route" >&2
        exit 1
        ;;
    esac
  done

  python3 - <<'PY'
import json
from pathlib import Path

coverage_routes = {
    "/succession",
    "/pilier-3a",
    "/hypotheque",
}
registry = json.loads(Path("docs/codex/P0_CASE_VARIABLE_REGISTRY.json").read_text())
maestro_dir = Path("apps/mobile/.maestro")
patrol_dir = Path("apps/mobile/test/patrol")
missing = sorted(
    case["target_screen"]
    for case in registry["cases"].values()
    if case["target_screen"] not in coverage_routes
)
if missing:
    raise SystemExit(
        "P0 target screen lacks explicit Maestro route coverage status: "
        + ", ".join(missing)
    )
bad_flows = []
for case_id, case in registry["cases"].items():
    flow_id = case.get("maestro_flow_id")
    patrol_flow_id = case.get("patrol_flow_id")
    status = case.get("acceptance_status")
    has_patrol = bool(patrol_flow_id) and (patrol_dir / f"{patrol_flow_id}.dart").exists()
    if patrol_flow_id and not has_patrol:
        bad_flows.append(
            f"{case_id}: patrol_flow_id '{patrol_flow_id}' does not resolve to "
            f"apps/mobile/test/patrol/{patrol_flow_id}.dart"
        )
    if status == "phase1_runtime_accepted":
        if flow_id == "pending" and not has_patrol:
            bad_flows.append(
                f"{case_id}: runtime accepted case requires a resolved "
                "patrol_flow_id when maestro_flow_id is pending"
            )
        if not case.get("runtime_input_gate"):
            bad_flows.append(f"{case_id}: runtime accepted case lacks runtime_input_gate")
        if not case.get("runtime_proof_kind"):
            bad_flows.append(f"{case_id}: runtime accepted case lacks runtime_proof_kind")
    if flow_id == "pending":
        stale_candidates = [
            maestro_dir / f"{case_id}.yaml",
            maestro_dir / f"phase2_{case_id}.yaml",
            maestro_dir / f"phase2_data_quest_{case_id}.yaml",
        ]
        stale_files = [str(path) for path in stale_candidates if path.exists()]
        if stale_files:
            bad_flows.append(
                f"{case_id}: pending maestro_flow_id but flow files exist: "
                + ", ".join(stale_files)
            )
        continue
    if not flow_id:
        bad_flows.append(f"{case_id}: missing maestro_flow_id")
        continue
    if not (maestro_dir / f"{flow_id}.yaml").exists():
        bad_flows.append(
            f"{case_id}: maestro_flow_id '{flow_id}' does not resolve to "
            f"apps/mobile/.maestro/{flow_id}.yaml"
        )
if bad_flows:
    raise SystemExit("P0 maestro_flow_id drift: " + "; ".join(bad_flows))
PY
}

check_p0_mint_design_tokens() {
  local files=(
    apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
    apps/mobile/lib/screens/mortgage/affordability_screen.dart
    apps/mobile/lib/screens/simulator_3a_screen.dart
    apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  )

  for file in "${files[@]}"; do
    require_file "$file"
  done

  if rg -n '(^|[^[:alnum:]_])Colors\.|Color\(0x[0-9A-Fa-f]+' "${files[@]}" >/tmp/mint-p0-design-token-violations.txt; then
    echo "ERROR: P0 mobile screens must use MintColors/MintTextStyles instead of raw Material colors or hex colors" >&2
    cat /tmp/mint-p0-design-token-violations.txt >&2
    exit 1
  fi

  grep -q "MintColors" "${files[@]}"
  grep -q "MintTextStyles" "${files[@]}"
}

check_p0_french_compliance() {
  require_file tools/checks/accent_lint_fr.py
  require_file tools/checks/no_hardcoded_fr.py
  require_file apps/mobile/lib/l10n/app_fr.arb
  require_file apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  require_file apps/mobile/test/i18n/succession_arb_compliance_test.dart

  python3 tools/checks/accent_lint_fr.py --file apps/mobile/lib/l10n/app_fr.arb
  python3 tools/checks/no_hardcoded_fr.py --file apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  (
    cd apps/mobile
    flutter test test/i18n/succession_arb_compliance_test.dart --reporter expanded
  )
}

check_future_maestro_contracts() {
  check_p0_mint_design_tokens
  check_p0_french_compliance

  if rg -n 'openLink:.*mint://[^/]' apps/mobile/.maestro >/dev/null; then
    echo "ERROR: Maestro deep links must use mint:///absolute-path, not mint://host-form" >&2
    rg -n 'openLink:.*mint://[^/]' apps/mobile/.maestro >&2
    exit 1
  fi
  check_maestro_route_coverage_manifest
  grep -q '"documentsEmpty": "Aucun document"' apps/mobile/lib/l10n/app_fr.arb
  require_file apps/mobile/.maestro/r1b_scan_review_orphan_session.yaml
  require_file apps/mobile/.maestro/r2b_scan_impact_orphan_session.yaml
  maestro_check_syntax apps/mobile/.maestro/r1b_scan_review_orphan_session.yaml
  maestro_check_syntax apps/mobile/.maestro/r2b_scan_impact_orphan_session.yaml
  grep -q 'text: "Aucun document"' apps/mobile/.maestro/r1_scan_review.yaml
  grep -q 'text: "Aucun document"' apps/mobile/.maestro/r2_scan_impact.yaml
  grep -q 'text: "Aucun document"' apps/mobile/.maestro/r1b_scan_review_orphan_session.yaml
  grep -q 'text: "Aucun document"' apps/mobile/.maestro/r2b_scan_impact_orphan_session.yaml
  grep -q 'point: "50%,90%"' apps/mobile/.maestro/r1_scan_review.yaml
  grep -q 'point: "50%,90%"' apps/mobile/.maestro/r2_scan_impact.yaml
  grep -q 'point: "50%,90%"' apps/mobile/.maestro/r1b_scan_review_orphan_session.yaml
  grep -q 'point: "50%,90%"' apps/mobile/.maestro/r2b_scan_impact_orphan_session.yaml
  grep -Fq 'openLink: "mint:///scan/review?scanSessionId=orphan-session-r1b"' apps/mobile/.maestro/r1b_scan_review_orphan_session.yaml
  grep -Fq 'openLink: "mint:///scan/impact?scanSessionId=orphan-session-r2b"' apps/mobile/.maestro/r2b_scan_impact_orphan_session.yaml
  grep -q 'id: "document_scan_header"' apps/mobile/.maestro/r1_scan_review.yaml
  grep -q 'id: "document_scan_header"' apps/mobile/.maestro/r2_scan_impact.yaml
  grep -q 'id: "document_scan_header"' apps/mobile/.maestro/r1b_scan_review_orphan_session.yaml
  grep -q 'id: "document_scan_header"' apps/mobile/.maestro/r2b_scan_impact_orphan_session.yaml
  if [[ "${MINT_ENABLE_LEGACY_STATIC_PATROL_CONTRACTS:-false}" != "true" ]]; then
    return 0
  fi
  if [[ -f "apps/mobile/.maestro/f1_first_job.yaml" ]]; then
    require_file "apps/mobile/.maestro/goto_retirement.yaml"
    require_file "apps/mobile/test/fixtures/coach_ledger_first_job_golden.json"
    grep -q 'runFlow: goto_retirement.yaml' apps/mobile/.maestro/f1_first_job.yaml
    grep -q 'id: "coach_response_fixture_first_job"' apps/mobile/.maestro/f1_first_job.yaml
    grep -q 'id: "retirement_salary_basis_value"' apps/mobile/.maestro/f1_first_job.yaml
    if rg -n 'assertVisible:.*text:.*(3e pilier|pilier|LPP)' apps/mobile/.maestro/f1_first_job.yaml >/dev/null; then
      echo "ERROR: f1_first_job.yaml must not assert open coach LLM prose; use a fixture-pinned Semantics id" >&2
      exit 1
    fi
    if rg -n "assertVisible:.*text:.*4'?500|text: \"4'?500\"" apps/mobile/.maestro/f1_first_job.yaml >/dev/null; then
      echo "ERROR: f1_first_job.yaml must not assert salary echo as raw text; use retirement_salary_basis_value" >&2
      exit 1
    fi
  fi
  grep -q "identifier: 'retirement_gap_value'" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart
  grep -q "identifier: 'retirement_salary_basis_value'" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart
  grep -q "_firstJobSalary" apps/mobile/lib/services/chat/fact_extraction_fallback.dart
  grep -q "premier job à 4500 net" apps/mobile/test/services/chat/fact_extraction_fallback_test.dart
  grep -q "retirement_salary_basis_value" apps/mobile/test/screens/coach/retirement_dashboard_test.dart
  if [[ -f "apps/mobile/.maestro/f3_retirement.yaml" ]]; then
    require_file "apps/mobile/test/fixtures/coach_ledger_retirement_lpp_golden.json"
    grep -q 'id: "coach_input"' apps/mobile/.maestro/f3_retirement.yaml
    grep -q 'id: "coach_response_fixture_lpp"' apps/mobile/.maestro/f3_retirement.yaml
    grep -q 'id: "rente_capital_uses_lpp"' apps/mobile/.maestro/f3_retirement.yaml
    if rg -n 'assertVisible:.*text:.*(LPP|pilier)' apps/mobile/.maestro/f3_retirement.yaml >/dev/null; then
      echo "ERROR: f3_retirement.yaml must not assert open coach LLM prose; use a fixture-pinned Semantics id" >&2
      exit 1
    fi
  fi
  require_file "apps/mobile/.maestro/f2_datablock_to_mortgage.yaml"
  maestro_check_syntax apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
  grep -q 'MINT_TEST_REVENUE_ANNUAL: "96000"' apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
  grep -q 'MINT_TEST_CANTON: "GE"' apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
  if rg -n 'inputText:|eraseText' apps/mobile/.maestro/f2_datablock_to_mortgage.yaml >/dev/null; then
    echo "ERROR: f2_datablock_to_mortgage.yaml must not use Maestro text entry; Patrol owns the user-input proof" >&2
    exit 1
  fi
  grep -q 'text: "12 / 12 pts"' apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
  grep -q 'text: "Complet"' apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
  grep -q 'id: "mortgage_afford_result"' apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
  grep -Fq "text: \"Revenu brut annuel: CHF.*96'000; Canton: GE\"" apps/mobile/.maestro/f2_datablock_to_mortgage.yaml
  grep -q 'MINT_TEST_REVENUE_ANNUAL' apps/mobile/lib/services/startup_route_override_parser.dart
  grep -q 'MINT_TEST_CANTON' apps/mobile/lib/services/startup_route_override_parser.dart
  grep -q 'mintRuntimeProofInputsEnabledForTest' apps/mobile/test/services/startup_route_override_parser_test.dart
  grep -q 'readMintDebugRevenueAnnualSeed' apps/mobile/lib/app.dart
  grep -q 'readMintDebugCantonSeed' apps/mobile/lib/app.dart
  grep -q 'DateTime.now().toUtc()' apps/mobile/lib/app.dart
  grep -q "'q_gross_salary_annual': revenueAnnual" apps/mobile/lib/app.dart
  grep -q "'q_canton': canton" apps/mobile/lib/app.dart
  require_file "apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart"
  grep -q "patrolTest" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "GoRouter" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "/data-block/:type" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "/hypotheque" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "#salary_input" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "#canton_input" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "#salary_save_cta" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "#savings_input" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "#target_property_input" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "#patrimoine_save_cta" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "q_gross_salary_annual" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "q_canton" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "q_cash_total" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "q_target_property_value" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "q_property_market_value" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "startsWith('q_')" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "q_net_income_period_chf" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "q_monthly_gross_salary_chf" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "#mortgage_data_quest_contract" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "mortgage_data_quest_runtime_proof" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "mobile-f2-patrol" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "mortgage_data_quest_next_ask" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "'householdType'" apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart
  grep -q "DataQuestProofStrip" apps/mobile/lib/screens/mortgage/affordability_screen.dart
  grep -q "caseId: 'buy_property'" apps/mobile/lib/screens/mortgage/affordability_screen.dart
  require_file "apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart"
  grep -q "patrolTest" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "GoRouter" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "/data-block/:type" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "/pilier-3a" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "#sim3a_profile_basis" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "Simulator3aScreen" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "q_gross_salary_annual" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "q_canton" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "q_birth_year" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "q_has_pension_fund" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "startsWith('q_')" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "q_net_income_period_chf" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "q_monthly_gross_salary_chf" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "#sim3a_data_quest_contract" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "sim3a_data_quest_runtime_proof" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "mobile-first-salary-patrol" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "sim3a_data_quest_next_ask" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "'pillar3aAnnual'" apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart
  grep -q "DataQuestProofStrip" apps/mobile/lib/screens/simulator_3a_screen.dart
  grep -q "caseId: 'first_salary_tax'" apps/mobile/lib/screens/simulator_3a_screen.dart
  require_file "apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart"
  grep -q "patrolTest" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "applySaveFact('nationality', 'US')" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "q_nationality" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "q_is_fatca_resident" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "isFatcaResident" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "sim3a_data_quest_runtime_proof" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "mobile-first-salary-patrol" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "#sim3a_non_contributable_state" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "can_contribute_3a=false" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "plafond_3a=CHF" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "startsWith('q_')" apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart
  grep -q "case 'nationality'" apps/mobile/lib/providers/coach_profile_provider.dart
  grep -q "'q_nationality'" apps/mobile/lib/providers/coach_profile_provider.dart
  grep -q "_canContribute3a = coachProfile.canContribute3a" apps/mobile/lib/screens/simulator_3a_screen.dart
  grep -q "sim3aNonContributableTitle" apps/mobile/lib/screens/simulator_3a_screen.dart
  grep -q "startsWith('q_')" apps/mobile/test/screens/data_block_enrichment_screen_test.dart
  grep -q "patrimoine save accepts liquid assets before target property" apps/mobile/test/screens/data_block_enrichment_screen_test.dart
  grep -q "answers.containsKey('q_target_property_value'), isFalse" apps/mobile/test/screens/data_block_enrichment_screen_test.dart
  grep -q "writes edited mortgage assumptions back to canonical ledger" apps/mobile/test/screens/calculator_prefill_writeback_test.dart
  grep -q "_coach_mortgage_capacity" apps/mobile/test/screens/calculator_prefill_writeback_test.dart
  grep -q "_coach_estimated_monthly_payment" apps/mobile/test/screens/calculator_prefill_writeback_test.dart
  grep -q "mergeAnswers persists mortgage computed field paths as estimates" apps/mobile/test/providers/coach_profile_provider_save_fact_mapping_test.dart
  grep -q "patrimoine.mortgageCapacity" apps/mobile/lib/providers/coach_profile_provider.dart
  grep -q "patrimoine.estimatedMonthlyPayment" apps/mobile/lib/providers/coach_profile_provider.dart
  grep -q "rawTargetProperty.isEmpty" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "answers.isEmpty" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "identifier: 'salary_input'" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "identifier: 'canton_input'" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "identifier: 'birth_year_input'" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "identifier: 'has_pension_fund_switch'" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "identifier: 'salary_save_cta'" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "identifier: 'savings_input'" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "identifier: 'target_property_input'" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "identifier: 'patrimoine_save_cta'" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "Key('salary_input')" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "Key('canton_input')" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "Key('birth_year_input')" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "Key('has_pension_fund_switch')" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "Key('salary_save_cta')" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "Key('savings_input')" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "Key('target_property_input')" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "Key('patrimoine_save_cta')" apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart
  grep -q "identifier: 'mortgage_afford_result'" apps/mobile/lib/screens/mortgage/affordability_screen.dart
  grep -q "identifier: 'mortgage_salary_basis_value'" apps/mobile/lib/screens/mortgage/affordability_screen.dart
  grep -q "identifier: 'mortgage_canton_basis_value'" apps/mobile/lib/screens/mortgage/affordability_screen.dart
  grep -q "identifier: 'sim3a_profile_basis'" apps/mobile/lib/screens/simulator_3a_screen.dart
  grep -q "ValueKey('sim3a_profile_basis')" apps/mobile/lib/screens/simulator_3a_screen.dart
  grep -q "coachProfile.revenuBrutAnnuel" apps/mobile/lib/screens/simulator_3a_screen.dart
  require_file "apps/mobile/.maestro/f5_transmitting_property.yaml"
  maestro_check_syntax apps/mobile/.maestro/f5_transmitting_property.yaml
  grep -q 'MINT_TEST_PROPERTY_VALUE: "1200000"' apps/mobile/.maestro/f5_transmitting_property.yaml
  grep -q 'id: "succession_data_quest_next_ask"' apps/mobile/.maestro/f5_transmitting_property.yaml
  grep -q 'text: "Prochaine donnée à confirmer"' apps/mobile/.maestro/f5_transmitting_property.yaml
  grep -q 'id: "succession_parents_note"' apps/mobile/.maestro/f5_transmitting_property.yaml
  grep -q 'id: "succession_scenario_preview"' apps/mobile/.maestro/f5_transmitting_property.yaml
  grep -q 'id: "succession_scenario_retirement_status"' apps/mobile/.maestro/f5_transmitting_property.yaml
  grep -q 'id: "succession_scenario_equalization_status"' apps/mobile/.maestro/f5_transmitting_property.yaml
  grep -q 'id: "succession_scenario_confidence"' apps/mobile/.maestro/f5_transmitting_property.yaml
  grep -q "identifier: 'property_value_input'" apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  grep -q "identifier: 'succession_parents_note'" apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  grep -q "identifier: 'succession_scenario_preview'" apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  grep -q "identifier: 'succession_scenario_retirement_status'" apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  grep -q "identifier: 'succession_scenario_equalization_status'" apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  grep -q "identifier: 'succession_scenario_confidence'" apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart
  require_file "apps/mobile/test/patrol/transmit_property_patrol_test.dart"
  grep -q "patrolTest" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "SuccessionPatrimoineScreen" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "property_value_input" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "succession_parents_note" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "succession_data_quest_runtime_proof" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "mobile-transmit-property-patrol" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "succession_data_quest_next_ask" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "'propertyMarketValue'" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "'targetRetirementAge'" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "find.textContaining('next_ask:')" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "q_property_market_value" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "q_target_property_value" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "patrimoine.propertyMarketValue" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "patrimoine.targetPropertyValue" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  grep -q "ProfileDataSource.userInput" apps/mobile/test/patrol/transmit_property_patrol_test.dart
  if [[ -f "apps/mobile/.maestro/f6_divorce.yaml" ]]; then
    grep -q "identifier: 'divorce_regime_picker'" apps/mobile/lib/screens/divorce_simulator_screen.dart
    grep -q "identifier: 'divorce_lpp_split_result'" apps/mobile/lib/screens/divorce_simulator_screen.dart
  fi
  if [[ -f "apps/mobile/.maestro/r4_persistence.yaml" ]]; then
    maestro_check_syntax apps/mobile/.maestro/r4_persistence.yaml
    grep -q 'id: "salary_input"' apps/mobile/.maestro/r4_persistence.yaml
    grep -q 'id: "mortgage_afford_result"' apps/mobile/.maestro/r4_persistence.yaml
  fi
  if [[ -f "apps/mobile/.maestro/r5_portfolio_param.yaml" ]]; then
    maestro_check_syntax apps/mobile/.maestro/r5_portfolio_param.yaml
    grep -Fq 'mint:///portfolio?tab=1' apps/mobile/.maestro/r5_portfolio_param.yaml
  fi
}

install_phase1_flutter_app_if_requested() {
  if [[ -z "${MINT_PHASE1_FLUTTER_DEVICE_ID:-}" ]]; then
    return 0
  fi
  export_mint_ios_codesign_path
  (
    cd apps/mobile
    flutter run \
      -d "$MINT_PHASE1_FLUTTER_DEVICE_ID" \
      --debug \
      --dart-define=MINT_ENABLE_RUNTIME_PROOF_SEMANTICS=true \
      --no-resident
  )
}

install_phase2_flutter_app_if_requested() {
  if [[ -z "${MINT_PHASE2_FLUTTER_DEVICE_ID:-}" ]]; then
    return 0
  fi
  export_mint_ios_codesign_path
  (
    cd apps/mobile
    flutter run \
      -d "$MINT_PHASE2_FLUTTER_DEVICE_ID" \
      --debug \
      --dart-define=MINT_ENABLE_RUNTIME_PROOF_SEMANTICS=true \
      --no-resident
  )
}

case "$mode" in
  bootstrap)
    validate_evidence_dir
    check_cli_exception_ledger
    require_file AGENTS.md
    require_file CLAUDE.md
    require_file docs/superpowers/plans/2026-07-01-mint-lucidity-spine.md
    require_file docs/codex/DATA_LEDGER_GATE_SPEC.md
    require_file docs/codex/P0_CASE_VARIABLE_REGISTRY.json
    require_file tools/checks/tests/test_codex_ledger_parity.py
    require_file tools/checks/tests/test_cross_stack_fixture_schema.py
    require_file tools/checks/tests/test_p0_case_variable_registry.py
    require_file tools/checks/arb_parity.py
    grep -q '"mobile_runtime_calculator": "apps/mobile/lib/services/financial_core/property_transmission_calculator.dart"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
    grep -q '"backend_fixture_authority": "services/backend/tests/fixtures/scenarios/property_transmission_raiffeisen.json"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
    require_file tools/checks/claude_external_audit.sh
    require_file docs/codex/WIRING_GRAPH.mmd

    require_command bash
    require_command claude
    require_command maestro
    require_command npx

    bash -n tools/checks/claude_external_audit.sh
    check_agents
    check_report_maestro_contract
    check_confidence_maestro_contract

    claude --help >/dev/null
    claude ultrareview --help >/dev/null
    check_maestro_version
    compile_mermaid

    if [[ -f tools/checks/active_context_guard.py ]]; then
      python3 tools/checks/active_context_guard.py
    fi
    if [[ -f tools/checks/phase_contract_guard.py ]]; then
      python3 tools/checks/phase_contract_guard.py
    fi
    if [[ -f tools/checks/mint_rules_guard.py ]]; then
      python3 tools/checks/mint_rules_guard.py
    fi
    check_final_bootstrap_audit
    ;;
  external-bootstrap)
    bash "$0" bootstrap
    tools/checks/claude_external_audit.sh bootstrap
    ;;
  phase1)
    validate_evidence_dir
    check_cli_exception_ledger
    require_file docs/codex/DATA_LEDGER_GATE_SPEC.md
    require_file docs/codex/P0_CASE_VARIABLE_REGISTRY.json
    require_file tools/checks/tests/test_codex_ledger_parity.py
    require_file tools/checks/tests/test_cross_stack_fixture_schema.py
    require_file tools/checks/tests/test_p0_case_variable_registry.py
    require_file tools/checks/arb_parity.py
    grep -q '"mobile_runtime_calculator": "apps/mobile/lib/services/financial_core/property_transmission_calculator.dart"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
    grep -q '"backend_fixture_authority": "services/backend/tests/fixtures/scenarios/property_transmission_raiffeisen.json"' docs/codex/P0_CASE_VARIABLE_REGISTRY.json
    grep -q '^## Gate 1: Backend Allowlist' docs/codex/DATA_LEDGER_GATE_SPEC.md
    grep -q '^## Gate 2: Mobile Answer Switch' docs/codex/DATA_LEDGER_GATE_SPEC.md
    grep -q '^## Gate 3: Model Reads' docs/codex/DATA_LEDGER_GATE_SPEC.md
    grep -q '^## Gate 4: Screen Consumers' docs/codex/DATA_LEDGER_GATE_SPEC.md
	    grep -q '^## Cross-Stack Fixture Schema' docs/codex/DATA_LEDGER_GATE_SPEC.md
	    compile_mermaid
	    check_phase1_runtime_args_guard
	    bash "$0" ledger
	    bash "$0" backend-scenarios
	    bash "$0" mobile-scenarios
	    bash "$0" live-http-scenario
	    bash "$0" mobile-live-http-scenario

    if [[ -z "${MINT_PHASE1_MAESTRO_FLOW:-}" ]]; then
      echo "ERROR: set MINT_PHASE1_MAESTRO_FLOW to an executable Phase 1 Maestro YAML" >&2
      exit 1
    fi
    require_file "$MINT_PHASE1_MAESTRO_FLOW"
    check_phase1_maestro_contract "$MINT_PHASE1_MAESTRO_FLOW"
    install_phase1_flutter_app_if_requested
    run_phase1_maestro "$MINT_PHASE1_MAESTRO_FLOW"
    check_no_open_baseline_highs
    check_phase_acceptance_artifacts phase1
    ;;
  phase2)
    run_phase2_runtime_gate
    check_phase_acceptance_artifacts phase2
    ;;
  phase2-runtime)
    run_phase2_runtime_gate
    ;;
  phase2-artifacts)
    validate_evidence_dir
    check_cli_exception_ledger
    check_phase_acceptance_artifacts phase2
    ;;
  ledger)
    python3 -m pytest \
      tools/checks/tests/test_codex_ledger_parity.py \
      tools/checks/tests/test_source_crosswalk.py \
      tools/checks/tests/test_cross_stack_fixture_schema.py \
      tools/checks/tests/test_no_bypass_persistence.py \
      tools/checks/tests/test_p0_case_variable_registry.py \
      -q
    ;;
  backend-scenarios)
    (
      cd services/backend
      python3 -m pytest \
        tests/test_property_transmission_scenario.py \
        tests/test_scenarios.py \
        tests/test_donation.py \
        -q
    )
    ;;
  live-http-scenario)
    python3 tools/checks/property_transmission_live_http_probe.py
    ;;
  mobile-live-http-scenario)
    python3 tools/checks/property_transmission_mobile_live_probe.py
    ;;
  mobile-scenarios)
    check_phase1_runtime_args_guard
    (
      cd apps/mobile
      flutter gen-l10n
    )
    normalize_generated_l10n_line_endings
    (
	      cd apps/mobile
	      flutter test \
	        test/services/startup_route_override_parser_test.dart \
	        test/services/financial_core/property_transmission_calculator_test.dart \
	        test/architecture/raw_reference_stores_contract_test.dart \
	        test/providers/coach_profile_provider_save_fact_mapping_test.dart \
	        test/services/chat/fact_extraction_fallback_test.dart \
	        test/i18n/succession_arb_compliance_test.dart \
	        test/navigation/goroute_health_test.dart \
	        test/services/dossier/dossier_payload_service_test.dart \
        test/services/pdf_service_test.dart \
        test/screens/confidence_route_screen_test.dart \
	        test/screens/report_route_screen_test.dart \
	        test/screens/data_block_enrichment_screen_test.dart \
	        test/screens/calculator_prefill_writeback_test.dart \
	        test/screens/document_scan/document_scan_screen_test.dart \
	        test/screens/coach/retirement_dashboard_test.dart \
	        test/screens/s44_phase2_smoke_test.dart \
	        --reporter expanded
	    )
    check_report_maestro_contract
    check_confidence_maestro_contract
    check_future_maestro_contracts
    python3 tools/checks/arb_parity.py
    python3 -m pytest \
      tools/checks/tests/test_no_bypass_persistence.py \
      tools/checks/tests/test_data_quest_i18n_preconditions.py \
      tools/checks/tests/test_codex_ledger_parity.py \
      tools/checks/tests/test_p0_dart_case_registry_parity.py \
      tools/checks/tests/test_p0_case_variable_registry.py \
      tools/checks/tests/test_patrol_p0_gate_contract.py \
	      tools/checks/tests/test_ios_codesign_reproducibility_contract.py \
	      tools/checks/tests/test_claude_audit_corpus_contract.py \
	      tools/checks/tests/test_cross_stack_fixture_schema.py \
	      -q
    ;;
  mobile-f2-patrol)
    run_f2_patrol "${2:-}"
    ;;
  mobile-first-salary-patrol)
    run_first_salary_tax_patrol "${2:-}"
    ;;
  mobile-first-salary-fatca-patrol)
    run_first_salary_tax_fatca_patrol "${2:-}"
    ;;
  mobile-transmit-property-patrol)
    run_transmit_property_patrol "${2:-}"
    ;;
  mobile-budget-housing-frequency-patrol)
    run_budget_housing_frequency_patrol "${2:-}"
    ;;
  mobile-p0-patrol)
    run_p0_patrol_suite "${2:-}"
    ;;
  mobile-data-quest)
    check_phase2_data_quest_contract
    (
      cd apps/mobile
      flutter analyze \
        lib/services/data_quest/data_quest_service.dart \
        lib/services/dossier/dossier_payload_service.dart \
        lib/services/startup_route_override.dart \
        lib/widgets/data_quest/data_quest_proof_strip.dart \
        lib/screens/coach/succession_patrimoine_screen.dart \
        lib/providers/coach_profile_provider.dart \
        test/services/data_quest/data_quest_service_test.dart \
        test/services/dossier/dossier_payload_service_test.dart \
        test/services/startup_route_override_parser_test.dart \
        test/screens/s44_phase2_smoke_test.dart
      flutter test \
        test/services/startup_route_override_parser_test.dart \
        test/services/data_quest/data_quest_service_test.dart \
        test/services/dossier/dossier_payload_service_test.dart \
        test/providers/coach_profile_provider_save_fact_mapping_test.dart \
        test/screens/s44_phase2_smoke_test.dart \
        --reporter expanded
    )
    ;;
  *)
    echo "Usage: $0 {bootstrap|external-bootstrap|phase1|phase2|phase2-runtime|phase2-artifacts|ledger|backend-scenarios|live-http-scenario|mobile-live-http-scenario|mobile-scenarios|mobile-f2-patrol|mobile-first-salary-patrol|mobile-first-salary-fatca-patrol|mobile-transmit-property-patrol|mobile-budget-housing-frequency-patrol|mobile-p0-patrol|mobile-data-quest}" >&2
    exit 2
    ;;
esac

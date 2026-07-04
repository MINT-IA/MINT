#!/usr/bin/env bash
set -euo pipefail

mode="${1:-code}"
target="${2:-dev}"
timeout_minutes="${CLAUDE_ULTRAREVIEW_TIMEOUT_MINUTES:-30}"
audit_model="${CLAUDE_AUDIT_MODEL:-sonnet}"
audit_budget_usd="${CLAUDE_AUDIT_MAX_BUDGET_USD:-1.00}"
doc_lines="${CLAUDE_AUDIT_DOC_LINES:-90}"
spec_lines="${CLAUDE_AUDIT_SPEC_LINES:-180}"

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude CLI not found in PATH" >&2
  exit 127
fi

emit_file() {
  local file="$1"
  local lines="${2:-$doc_lines}"
  echo
  echo "===== FILE: $file ====="
  if [[ -f "$file" ]]; then
    sed -n "1,${lines}p" "$file"
  else
    echo "MISSING: $file"
  fi
}

emit_range() {
  local file="$1"
  local start_pattern="$2"
  local end_pattern="$3"
  echo
  echo "===== FILE RANGE: $file ($start_pattern -> $end_pattern) ====="
  if [[ -f "$file" ]]; then
    sed -n "/$start_pattern/,/$end_pattern/p" "$file"
  else
    echo "MISSING: $file"
  fi
}

run_claude_prompt() {
  local bundle="$1"
  claude -p \
    --model "$audit_model" \
    --max-budget-usd "$audit_budget_usd" \
    "$(cat "$bundle")"
}

case "$mode" in
  bootstrap)
    bundle="$(mktemp)"
    trap 'rm -f "$bundle"' EXIT
    {
      echo "You are an external bootstrap auditor for MINT."
      echo
      echo "Audit whether the permanent agent roster and lucidity plan can safely gate Phase 1."
      echo "Return at most 900 words: CRITICAL/HIGH/MEDIUM/LOW findings, required fixes, and an overall score /10."
      echo "Reject circular gates, missing phase acceptance, unclear data ownership, and unverifiable QA."
      echo "If there are no unresolved CRITICAL or HIGH findings, start the response with exactly: NO_UNRESOLVED_CRITICAL_HIGH"
      echo "If this run is being written as the final audit artifact, do not fail solely because this run's output file is not visible yet."
      emit_range AGENTS.md "Permanent MINT Lucidity Roster" "If a step was skipped"
      emit_file docs/superpowers/plans/2026-07-01-mint-lucidity-spine.md 220
      emit_file docs/codex/DATA_LEDGER_GATE_SPEC.md 180
      emit_file tools/checks/mint_lucidity_gate.sh 220
      emit_file .planning/runtime-evidence/cli_exception_ledger.json 80
      if [[ -n "${MINT_EVIDENCE_DIR:-}" && -f "${MINT_EVIDENCE_DIR}/SCORECARD.md" ]]; then
        emit_file "${MINT_EVIDENCE_DIR}/SCORECARD.md" 180
      fi
    } > "$bundle"
    run_claude_prompt "$bundle"
    ;;
  architecture)
    bundle="$(mktemp)"
    trap 'rm -f "$bundle"' EXIT
    {
      echo "You are an external architecture auditor for MINT."
      echo
      echo "Audit whether this plan can make MINT usable as a Swiss financial lucidity product."
      echo "Focus on data architecture, life-event progression, Swiss compliance, runtime evidence, and facade risk."
      echo "Return CRITICAL/HIGH/MEDIUM/LOW findings and an overall score /10."
      emit_file CLAUDE.md 120
      emit_file AGENTS.md 170
      emit_file docs/superpowers/plans/2026-07-01-mint-lucidity-spine.md 260
      emit_file docs/codex/DATA_LEDGER_GATE_SPEC.md 220
      emit_file docs/codex/ANDROID_RUNTIME_BLOCKERS.md 120
      emit_file .github/workflows/android-runtime-patrol.yml 140
      emit_file docs/codex/P0_CASE_VARIABLE_REGISTRY.json 700
      emit_file tools/checks/mint_lucidity_gate.sh 1300
      emit_file apps/mobile/ios/mint_xcode_tools/codesign 120
      emit_file tools/checks/ios_simulator_build_with_mint_codesign.sh 120
      emit_file services/backend/app/services/confidence/source_crosswalk.py 120
      emit_file tools/checks/tests/test_source_crosswalk.py 160
      emit_file tools/checks/tests/test_codex_ledger_parity.py 260
      emit_file tools/checks/tests/test_patrol_p0_gate_contract.py 160
      emit_file services/backend/app/api/v1/endpoints/coach_chat.py 1220
      emit_file services/backend/tests/test_save_fact_tool.py 230
      emit_file apps/mobile/lib/services/financial_core/property_transmission_calculator.dart 760
      emit_file apps/mobile/lib/services/dossier/dossier_payload_service.dart 760
      emit_file apps/mobile/test/services/dossier/dossier_payload_service_test.dart 260
      emit_file apps/mobile/lib/screens/simulator_3a_screen.dart 700
      emit_file apps/mobile/lib/services/local_profile_owner_service.dart 120
      emit_file apps/mobile/lib/widgets/data_quest/data_quest_proof_strip.dart 140
      emit_file apps/mobile/lib/providers/coach_profile_provider.dart 1050
      emit_file apps/mobile/test/screens/simulator_3a_fatca_screen_test.dart 180
      emit_file apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart 220
      emit_file apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart 220
      emit_file apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart 240
      emit_file apps/mobile/test/patrol/transmit_property_patrol_test.dart 220
      emit_file apps/mobile/lib/providers/scan_session_provider.dart 220
      emit_file apps/mobile/test/routing/no_domain_data_in_extra_test.dart 220
      for file in \
        docs/codex/DATA_LEDGER.md \
        docs/codex/DATA_QUEST.md \
        docs/codex/SCREEN_CONTRACTS.md \
        docs/codex/WIRING_GRAPH.mmd \
        docs/codex/MAESTRO_FLOWS.md
      do
        emit_file "$file" "$doc_lines"
      done
    } > "$bundle"
    run_claude_prompt "$bundle"
    ;;
  specs)
    bundle="$(mktemp)"
    trap 'rm -f "$bundle"' EXIT
    {
      echo "You are an external spec-drift auditor for MINT."
      echo
      echo "Challenge these five docs/codex specs. Report stale, false, or unverifiable claims; missing gates; and any path that cannot produce product value."
      echo "Severity: CRITICAL/HIGH/MEDIUM/LOW. Do not propose cosmetic changes."
      for file in \
        docs/codex/DATA_LEDGER.md \
        docs/codex/DATA_QUEST.md \
        docs/codex/SCREEN_CONTRACTS.md \
        docs/codex/WIRING_GRAPH.mmd \
        docs/codex/MAESTRO_FLOWS.md
      do
        emit_file "$file" "$spec_lines"
      done
    } > "$bundle"
    run_claude_prompt "$bundle"
    ;;
  phase1)
    bundle="$(mktemp)"
    trap 'rm -f "$bundle"' EXIT
    {
      echo "You are an external Phase 1 acceptance auditor for MINT."
      echo
      echo "Audit whether Phase 1 makes the DATA_LEDGER / transmit_property path executable enough to continue."
      echo "Focus on runtime proof, source provenance, P0 CASE variable discipline, Swiss educational-scope safety, and facade risk."
      echo "Return at most 1200 words: CRITICAL/HIGH/MEDIUM/LOW findings, required fixes, residual risks, and an overall score /10."
      echo "If there are no unresolved CRITICAL or HIGH findings, start the response with exactly: NO_UNRESOLVED_CRITICAL_HIGH"
      echo "Do not fail solely because future phases are not implemented; fail only if Phase 1 acceptance is unsafe or unverifiable."
      emit_file tools/checks/mint_lucidity_gate.sh 290
      emit_file tools/checks/arb_parity.py 120
      emit_file lefthook.yml 120
      emit_file docs/superpowers/plans/2026-07-01-mint-lucidity-spine.md 260
      emit_file apps/mobile/.maestro/phase1_data_ledger_succession.yaml 120
      emit_file docs/codex/DATA_LEDGER_GATE_SPEC.md 220
      emit_file docs/codex/P0_CASE_VARIABLE_REGISTRY.json 420
      emit_file services/backend/app/services/succession_property_transmission.py 420
      emit_file services/backend/app/api/v1/endpoints/scenarios.py 240
      emit_file services/backend/app/schemas/scenario.py 90
      emit_file services/backend/tests/fixtures/scenarios/README.md 80
      emit_file services/backend/tests/fixtures/scenarios/property_transmission_raiffeisen.json 220
      emit_file services/backend/tests/fixtures/scenarios/property_transmission_raiffeisen_source_dates.json 240
      emit_file services/backend/tests/test_property_transmission_scenario.py 260
      emit_file tools/checks/property_transmission_live_http_probe.py 180
      emit_file tools/checks/property_transmission_mobile_live_probe.py 180
      emit_file apps/mobile/ios/Runner/AppDelegate.swift 120
      emit_file apps/mobile/ios/Runner/Info.plist 140
      emit_file apps/mobile/android/app/src/main/AndroidManifest.xml 140
      emit_file apps/mobile/android/app/build.gradle 120
      emit_file apps/mobile/android/app/src/main/kotlin/ch/mint/coach/MainActivity.kt 140
      emit_file apps/mobile/lib/app.dart 1720
      emit_range apps/mobile/lib/app.dart "final provider = CoachProfileProvider" "return provider;"
      emit_file apps/mobile/lib/services/startup_route_override.dart 80
      emit_file apps/mobile/lib/services/startup_route_override_parser.dart 140
      emit_file apps/mobile/lib/services/startup_route_override_platform_io.dart 120
      emit_file apps/mobile/lib/services/startup_route_override_platform_stub.dart 40
      emit_range apps/mobile/lib/services/api_service.dart "createScenario" "put("
      emit_file apps/mobile/lib/services/financial_core/property_transmission_calculator.dart 780
      emit_file apps/mobile/lib/providers/coach_profile_provider.dart 180
      emit_file apps/mobile/lib/models/coach_profile.dart 140
      emit_file apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart 1020
      for locale in fr en de es it pt; do
        emit_range "apps/mobile/lib/l10n/app_${locale}.arb" "successionGuardMissingState" "successionSources"
      done
      emit_range apps/mobile/lib/l10n/app_fr.arb "donationIntroText" "donationImpotTitle"
      emit_file apps/mobile/test/providers/coach_profile_provider_save_fact_mapping_test.dart 220
      emit_file apps/mobile/test/i18n/succession_arb_compliance_test.dart 180
      emit_file apps/mobile/test/services/startup_route_override_parser_test.dart 180
      emit_file apps/mobile/test/services/financial_core/property_transmission_calculator_test.dart 220
      emit_file apps/mobile/test/services/api_service_property_transmission_live_test.dart 220
      emit_file apps/mobile/test/navigation/goroute_health_test.dart 220
      emit_file apps/mobile/test/screens/s44_phase2_smoke_test.dart 390
      emit_file tools/checks/tests/test_codex_ledger_parity.py 220
      emit_file tools/checks/tests/test_cross_stack_fixture_schema.py 220
      emit_file tools/checks/tests/test_p0_case_variable_registry.py 220
      if [[ -n "${MINT_EVIDENCE_DIR:-}" ]]; then
        emit_file "${MINT_EVIDENCE_DIR}/DATA_LEDGER_BASELINE_AUDIT.md" 220
        emit_file "${MINT_EVIDENCE_DIR}/SCORECARD.md" 180
        emit_file "${MINT_EVIDENCE_DIR}/gate-phase1-run.txt" 220
        emit_file "${MINT_EVIDENCE_DIR}/phase1-maestro.txt" 120
        emit_file "${MINT_EVIDENCE_DIR}/platform-diff.txt" 220
      fi
    } > "$bundle"
    run_claude_prompt "$bundle"
    ;;
  phase2)
    bundle="$(mktemp)"
    trap 'rm -f "$bundle"' EXIT
    {
      echo "You are an external Phase 2 acceptance auditor for MINT."
      echo
      echo "Audit whether Phase 2 makes the Data Quest case registry executable enough to continue."
      echo "Focus on delta-only data acquisition, case registry completeness, write-path discipline, runtime proof, dossier/PDF hooks, and facade risk."
      echo "Return at most 1200 words: CRITICAL/HIGH/MEDIUM/LOW findings, required fixes, residual risks, and an overall score /10."
      echo "If there are no unresolved CRITICAL or HIGH findings, start the response with exactly: NO_UNRESOLVED_CRITICAL_HIGH"
      echo "Do not fail solely because all P0 scenarios are not implemented; fail only if Phase 2 acceptance is unsafe or unverifiable."
      emit_file tools/checks/mint_lucidity_gate.sh 1320
      emit_file docs/superpowers/plans/2026-07-01-mint-lucidity-spine.md 260
      emit_file docs/codex/DATA_QUEST.md 220
      emit_file docs/codex/P0_CASE_VARIABLE_REGISTRY.json 700
      emit_file docs/codex/dossier_stubs/dossier_first_salary_tax.schema.json 120
      emit_file docs/codex/dossier_stubs/dossier_buy_property.schema.json 120
      emit_file docs/codex/dossier_stubs/dossier_transmit_property.schema.json 120
      emit_file apps/mobile/lib/services/data_quest/case_registry.dart 80
      emit_file apps/mobile/lib/services/data_quest/data_quest_service.dart 520
      emit_file apps/mobile/lib/services/dossier/dossier_payload_service.dart 860
      emit_file apps/mobile/lib/services/startup_route_override.dart 140
      emit_file apps/mobile/lib/services/startup_route_override_parser.dart 180
      emit_file apps/mobile/lib/services/biography/freshness_decay_service.dart 320
      emit_file apps/mobile/lib/providers/coach_profile_provider.dart 760
      emit_file apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart 860
      emit_file apps/mobile/lib/screens/advisor/report_route_screen.dart 220
      emit_file apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart 1040
      emit_file apps/mobile/lib/widgets/data_quest/data_quest_proof_strip.dart 260
      emit_file apps/mobile/test/services/biography/freshness_decay_test.dart 220
      emit_file apps/mobile/test/services/data_quest/data_quest_service_test.dart 260
      emit_file apps/mobile/test/services/dossier/dossier_payload_service_test.dart 760
      emit_file apps/mobile/test/services/startup_route_override_parser_test.dart 240
      emit_file apps/mobile/test/screens/report_route_screen_test.dart 460
      emit_file apps/mobile/test/providers/coach_profile_provider_save_fact_mapping_test.dart 260
      emit_file apps/mobile/test/screens/s44_phase2_smoke_test.dart 360
      emit_file apps/mobile/.maestro/phase2_data_quest_transmit_property.yaml 120
      emit_file apps/mobile/.maestro/phase2_data_quest_reconfirm.yaml 120
      emit_file tools/checks/tests/test_p0_case_variable_registry.py 260
      if [[ -n "${MINT_EVIDENCE_DIR:-}" ]]; then
        emit_file "${MINT_EVIDENCE_DIR}/SCORECARD.md" 180
        emit_file "${MINT_EVIDENCE_DIR}/phase2-maestro.txt" 160
        emit_file "${MINT_EVIDENCE_DIR}/phase2-reconfirm-maestro.txt" 160
        emit_file "${MINT_EVIDENCE_DIR}/gate-phase2-run.txt" 520
      fi
    } > "$bundle"
    run_claude_prompt "$bundle"
    ;;
  code)
    claude ultrareview "$target" --timeout "$timeout_minutes"
    ;;
  *)
    echo "Usage: $0 {bootstrap|architecture|specs|phase1|phase2|code} [base-branch-or-pr]" >&2
    exit 2
    ;;
esac

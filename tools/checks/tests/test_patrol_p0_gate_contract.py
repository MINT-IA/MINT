import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def test_mobile_p0_patrol_gate_runs_all_runtime_flows() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()

    assert "run_p0_patrol_suite()" in gate
    assert "check_p0_mint_design_tokens()" in gate
    assert "check_p0_french_compliance()" in gate
    assert "mobile-p0-patrol)" in gate
    assert "mobile-p0-patrol" in gate.split("Usage: $0", maxsplit=1)[1]
    assert "check_p0_mint_design_tokens" in gate.split(
        "check_future_maestro_contracts()",
        maxsplit=1,
    )[1]
    assert "check_p0_french_compliance" in gate.split(
        "check_future_maestro_contracts()",
        maxsplit=1,
    )[1]

    suite = gate.split("run_p0_patrol_suite()", maxsplit=1)[1].split(
        "check_phase1_runtime_args_guard",
        maxsplit=1,
    )[0]
    assert "run_first_salary_tax_patrol" in suite
    assert "run_first_salary_tax_fatca_patrol" in suite
    assert "run_f2_patrol" in suite
    assert "run_transmit_property_patrol" in suite


def test_phase1_maestro_timeout_is_fatal_after_completed_assertions() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()

    phase1_runner = gate.split("run_phase1_maestro()", maxsplit=1)[1].split(
        "run_phase2_maestro()",
        maxsplit=1,
    )[0]
    timeout_block = phase1_runner.split(
        "if (( elapsed >= timeout_seconds )); then",
        maxsplit=1,
    )[1].split("sleep 1", maxsplit=1)[0]

    assert "MAESTRO_TIMEOUT_AFTER_COMPLETED_ASSERTIONS" not in timeout_block
    assert "return 0" not in timeout_block
    assert "return 124" in timeout_block
    assert "timeout remains fatal" in timeout_block


def test_first_salary_tax_fatca_patrol_locks_single_source_of_truth() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()
    patrol = (
        ROOT / "apps/mobile/test/patrol/first_salary_tax_fatca_3a_patrol_test.dart"
    ).read_text()

    assert "mobile-first-salary-fatca-patrol)" in gate
    assert "run_first_salary_tax_fatca_patrol" in gate
    assert "applySaveFact('nationality', 'US')" in patrol
    assert "q_nationality" in patrol
    assert "q_is_fatca_resident" in patrol
    assert "containsKey('q_is_fatca_resident'), isFalse" in patrol
    assert "containsKey('isFatcaResident'), isFalse" in patrol
    assert "sim3a_non_contributable_state" in patrol
    assert "can_contribute_3a=false" in patrol
    assert "plafond_3a=CHF" in patrol


def test_first_salary_and_mortgage_patrol_prove_data_quest_next_asks() -> None:
    first_salary = (
        ROOT / "apps/mobile/test/patrol/first_salary_tax_datablock_to_3a_patrol_test.dart"
    ).read_text()
    mortgage = (
        ROOT / "apps/mobile/test/patrol/f2_datablock_to_mortgage_patrol_test.dart"
    ).read_text()

    assert "sim3a_data_quest_next_ask" in first_salary
    assert "'pillar3aAnnual'" in first_salary
    assert "'useful'" in first_salary

    assert "mortgage_data_quest_next_ask" in mortgage
    assert "'householdType'" in mortgage
    assert "'guard'" in mortgage


def test_mobile_scenarios_normalizes_generated_l10n_after_gen_l10n() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()

    assert "normalize_generated_l10n_line_endings()" in gate

    mobile_scenarios = gate.split("mobile-scenarios)", maxsplit=1)[1].split(
        "mobile-f2-patrol)",
        maxsplit=1,
    )[0]
    assert mobile_scenarios.index("flutter gen-l10n") < mobile_scenarios.index(
        "normalize_generated_l10n_line_endings"
    )
    assert mobile_scenarios.index(
        "normalize_generated_l10n_line_endings"
    ) < mobile_scenarios.index("flutter test")


def test_patrol_gate_normalizes_generated_l10n_after_runtime_builds() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()

    patrol_runner = gate.split("run_mobile_patrol_test()", maxsplit=1)[1].split(
        "run_f2_patrol()",
        maxsplit=1,
    )[0]
    assert '"$patrol_bin" test' in patrol_runner
    assert patrol_runner.index('"$patrol_bin" test') < patrol_runner.index(
        "normalize_generated_l10n_line_endings"
    )
    assert 'return "$rc"' in patrol_runner


def test_patrol_gate_applies_xcode26_patch_before_runtime_builds() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()
    patch_script = (
        ROOT / "apps/mobile/scripts/patch_patrol_xcode26_2.sh"
    ).read_text()

    patrol_runner = gate.split("run_mobile_patrol_test()", maxsplit=1)[1].split(
        "run_f2_patrol()",
        maxsplit=1,
    )[0]
    assert "apps/mobile/scripts/patch_patrol_xcode26_2.sh" in patrol_runner
    assert patrol_runner.index(
        "apps/mobile/scripts/patch_patrol_xcode26_2.sh"
    ) < patrol_runner.index('"$patrol_bin" test')
    assert "TLSPolicy.swift" in patch_script
    assert "Localization.swift" in patch_script
    assert "NSRegularExpression+Ext.swift" in patch_script
    assert "HTTPRoute.swift" in patch_script
    assert "IOSAutomator.swift" in patch_script
    assert "PatrolAppServiceClient.swift" in patch_script
    assert "URL+Ext.swift" in patch_script
    assert "URLCredential()" in patch_script
    assert "Foundation.PropertyListSerialization.propertyList" in patch_script
    assert "public final class Regex" in patch_script
    assert "String.CompareOptions = [.regularExpression]" in patch_script
    assert "import Foundation" in patch_script
    assert "import CoreFoundation" in patch_script
    assert "CFStreamCreatePairWithSocketToHost" in patch_script
    assert "failed to remove URLSession" in patch_script
    assert "timeoutIntervalForRequest" in patch_script
    assert "failed to remove unavailable URLSessionConfiguration timeouts" in patch_script
    assert "failed to replace URLSession completion handler" in patch_script
    assert "ProcessInfo.processInfo.operatingSystemVersion" in patch_script
    assert 'return "application\\/octet-stream"' in patch_script


def test_patrol_runner_does_not_force_simctl_for_android_devices() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()

    patrol_runner = gate.split("run_mobile_patrol_test()", maxsplit=1)[1].split(
        "run_f2_patrol()",
        maxsplit=1,
    )[0]
    assert 'xcrun simctl list devices' in patrol_runner
    assert 'grep -Fq "$device_id"' in patrol_runner
    assert "skipping simctl boot" in patrol_runner


def test_route_coverage_manifest_accepts_patrol_runtime_proof() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()

    manifest = gate.split("check_maestro_route_coverage_manifest()", maxsplit=1)[
        1
    ].split("check_p0_mint_design_tokens()", maxsplit=1)[0]
    assert 'patrol_dir = Path("apps/mobile/test/patrol")' in manifest
    assert "patrol_flow_id" in manifest
    assert "runtime_input_gate" in manifest
    assert "runtime_proof_kind" in manifest
    assert "runtime accepted case cannot have pending maestro_flow_id" not in manifest
    assert "runtime accepted case requires a resolved " in manifest
    assert "patrol_flow_id when maestro_flow_id is pending" in manifest


def test_permanent_agents_enforce_patrol_design_and_data_chronology() -> None:
    mobile_agent = (ROOT / ".claude/agents/mint-mobile.md").read_text()
    quality_agent = (ROOT / ".claude/agents/mint-quality-gate.md").read_text()
    data_quest_agent = (
        ROOT / ".claude/agents/mint-data-quest-architect.md"
    ).read_text()

    assert "Patrol" in mobile_agent
    assert "MintColors" in mobile_agent
    assert "MintTextStyles" in mobile_agent

    assert "mobile-p0-patrol" in quality_agent
    assert "Patrol" in quality_agent

    assert "chronological" in data_quest_agent
    assert "do not ask it again" in data_quest_agent


def test_android_runtime_blocker_has_executable_patrol_remediation_path() -> None:
    workflow = (ROOT / ".github/workflows/android-runtime-patrol.yml").read_text()
    blocker = (ROOT / "docs/codex/ANDROID_RUNTIME_BLOCKERS.md").read_text()

    assert "reactivecircus/android-emulator-runner@v2" in workflow
    assert "pull_request:" in workflow
    assert "push:" in workflow
    assert '"apps/mobile/**"' in workflow
    assert "flutter build apk --debug" in workflow
    assert "mobile-p0-patrol emulator-5554" in workflow
    assert ".github/workflows/android-runtime-patrol.yml" in blocker
    assert "automatic triggers" in blocker
    assert "mobile-p0-patrol emulator-5554" in blocker
    assert "before any Phase 3" in blocker


def test_lucidity_gate_self_recursion_works_when_invoked_with_bash() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()

    assert not re.search(r'^\s*"\$0"\s+\S+', gate, re.MULTILINE)
    assert 'bash "$0" ledger' in gate
    assert 'bash "$0" mobile-data-quest' in gate


def test_phase2_gate_splits_runtime_from_external_audit_artifacts() -> None:
    gate = (ROOT / "tools/checks/mint_lucidity_gate.sh").read_text()

    assert "run_phase2_runtime_gate()" in gate
    assert "phase2-runtime)" in gate
    assert "phase2-artifacts)" in gate
    assert "phase2-runtime" in gate.split("Usage: $0", maxsplit=1)[1]
    assert "phase2-artifacts" in gate.split("Usage: $0", maxsplit=1)[1]

    phase2_case = gate.split("phase2)", maxsplit=1)[1].split(
        "phase2-runtime)",
        maxsplit=1,
    )[0]
    assert "run_phase2_runtime_gate" in phase2_case
    assert "check_phase_acceptance_artifacts phase2" in phase2_case

    runtime_case = gate.split("phase2-runtime)", maxsplit=1)[1].split(
        "phase2-artifacts)",
        maxsplit=1,
    )[0]
    assert "run_phase2_runtime_gate" in runtime_case
    assert "check_phase_acceptance_artifacts" not in runtime_case

    artifacts_case = gate.split("phase2-artifacts)", maxsplit=1)[1].split(
        "ledger)",
        maxsplit=1,
    )[0]
    assert "check_phase_acceptance_artifacts phase2" in artifacts_case
    assert "run_phase2_runtime_gate" not in artifacts_case

from __future__ import annotations

import ast
import base64
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest
import yaml


ROOT = Path(__file__).resolve().parents[3]
MOBILE = ROOT / "apps/mobile"
ORCHESTRATOR = ROOT / "tools/simulator/patrol_pillar3a_beneficiary_process_death.sh"
WRITER = MOBILE / "integration_test/g1_ret_ref_pillar3a_beneficiary_write_patrol_test.dart"
READER = MOBILE / "integration_test/g1_ret_ref_pillar3a_beneficiary_read_patrol_test.dart"
RETIREMENT_SCREEN = MOBILE / "lib/screens/coach/retirement_dashboard_screen.dart"
SUPPORT = MOBILE / "integration_test/support/g1_ret_ref_pillar3a_beneficiary_runtime_contract.dart"
WRITE_WRAPPER = MOBILE / "test/patrol/g1_ret_ref_pillar3a_beneficiary_write_runtime_test.dart"
READ_WRAPPER = MOBILE / "test/patrol/g1_ret_ref_pillar3a_beneficiary_read_runtime_test.dart"
FLOW_BEFORE = MOBILE / ".maestro/g1_ret_ref_pillar3a_beneficiary_flag_off_before.yaml"
FLOW_AFTER = MOBILE / ".maestro/g1_ret_ref_pillar3a_beneficiary_flag_off_after.yaml"
RUNTIME_ASSETS = (
    ORCHESTRATOR,
    WRITER,
    READER,
    SUPPORT,
    WRITE_WRAPPER,
    READ_WRAPPER,
    FLOW_BEFORE,
    FLOW_AFTER,
)


def _missing_assets() -> list[str]:
    return [
        path.relative_to(ROOT).as_posix()
        for path in RUNTIME_ASSETS
        if not path.is_file()
    ]


@pytest.fixture(autouse=True)
def _require_complete_runtime_atom(request: pytest.FixtureRequest) -> None:
    if request.node.name == "test_runtime_assets_are_checked_in":
        return
    missing = _missing_assets()
    if missing:
        pytest.skip("TDD RED: missing exact 3a runtime assets: " + ", ".join(missing))


def _collect_yaml_ids(value: Any) -> set[str]:
    if isinstance(value, dict):
        result = {value["id"]} if isinstance(value.get("id"), str) else set()
        for nested in value.values():
            result.update(_collect_yaml_ids(nested))
        return result
    if isinstance(value, list):
        result: set[str] = set()
        for nested in value:
            result.update(_collect_yaml_ids(nested))
        return result
    return set()


def _ids_for_action(steps: list[Any], action: str) -> set[str]:
    identifiers: set[str] = set()
    for step in steps:
        if isinstance(step, dict) and action in step:
            identifiers.update(_collect_yaml_ids(step[action]))
    return identifiers


def _embedded_python(source: str, function_name: str) -> str:
    marker = f"{function_name}() {{"
    assert marker in source, f"missing executable {function_name} contract"
    function_start = source.index(marker)
    heredoc_start = source.index("<<'PY'\n", function_start) + len("<<'PY'\n")
    heredoc_end = source.index("\nPY\n", heredoc_start)
    return source[heredoc_start:heredoc_end]


def _literal_assignment(source: str, name: str) -> Any:
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if isinstance(target, ast.Name) and target.id == name:
            return ast.literal_eval(node.value)
    raise AssertionError(f"missing literal assignment {name}")


def test_runtime_assets_are_checked_in() -> None:
    assert _missing_assets() == []


def test_writer_uses_real_screens_and_transient_synthetic_pdf() -> None:
    source = WRITER.read_text(encoding="utf-8")
    assert source.count("patrolTest(") == 1
    for anchor in (
        "MINT_PATROL_CLI",
        "FeatureFlags.typedLppEvidence = true;",
        "FeatureFlags.documentLppEvidenceEnabled = true;",
        "FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = true;",
        "FeatureFlags.pillar3aBeneficiaryClauseReferenceEnabled = false;",
        "ReportPersistenceService.setMiniOnboardingCompleted(true)",
        "RetirementDashboardScreen(",
        "DocumentScanScreen(",
        "ExtractionReviewScreen(",
        "package:pdf/widgets.dart",
        "DOCUMENT SYNTHÉTIQUE — AUCUNE DONNÉE RÉELLE",
        "Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle",
        "DocumentType.pillar3aBeneficiaryClause",
        "pillar_3a_beneficiary_clause",
        "ConsentPurpose.visionExtraction",
        "ConsentPurpose.transferUsAnthropic",
        "visionExtractor:",
        "uploadDocument:",
        "Unexpected vault upload",
        "document_scan_pillar3a_beneficiary_clause_type_selector",
        "document_scan_gallery_cta",
        "pillar3a_beneficiary_relation_current_active_unpaid",
        "pillar3a_beneficiary_confirm_cta",
        "acceptPillar3aBeneficiaryReview",
        "recordPillar3aBeneficiaryEvidence",
        "expect(events, const <String>['accept', 'record'])",
        "Pillar3aBeneficiaryEvidenceRoot.answerKey",
        "DocumentReferenceStore.storageKey",
        "'__secure__'",
        "currentActiveUnpaid",
        "g1Pillar3aBeneficiaryWriterPidKey",
        "preferences.setInt(g1Pillar3aBeneficiaryWriterPidKey, pid)",
        "expect(ledger.profile, isNotNull)",
        "Pillar3aBeneficiaryLedgerState.missing",
        "Pillar3aBeneficiaryConsumerState.empty",
    ):
        assert anchor in source, anchor

    for forbidden in (
        "sanity_avoir_lpp_7M.pdf",
        "MINT_LPP_PRIVATE_MANIFEST",
        "uploadCalls.add",
        "$(#retirement_pillar3a_beneficiary_reference_insert_cta)",
        "find.bySemanticsIdentifier(\n"
        "        'retirement_pillar3a_beneficiary_reference_insert_cta'",
    ):
        assert forbidden not in source, forbidden

    assert "$(#retirement_pillar3a_beneficiary_insert_cta)" in source

    dashboard = source.index("retirement_pillar3a_beneficiary_insert_cta")
    scan = source.index("document_scan_gallery_cta")
    relation = source.index("pillar3a_beneficiary_relation_current_active_unpaid")
    confirm = source.index("pillar3a_beneficiary_confirm_cta")
    pid_witness = source.index(
        "preferences.setInt(g1Pillar3aBeneficiaryWriterPidKey, pid)"
    )
    assert dashboard < scan < relation < confirm < pid_witness

    retirement = RETIREMENT_SCREEN.read_text(encoding="utf-8")
    for production_anchor in (
        "retirement_pillar3a_beneficiary_reference_insert_cta",
        "retainPillar3aBeneficiaryScanIntent",
        "Pillar3aBeneficiaryScanIntentKind.insertion",
        "returnUri: '/retraite'",
    ):
        assert production_anchor in retirement, production_anchor


def test_reader_is_real_mint_app_and_covers_fail_closed_recovery() -> None:
    source = READER.read_text(encoding="utf-8")
    assert source.count("patrolTest(") == 1
    for anchor in (
        "const MintApp()",
        "AccountSessionBootstrap",
        "preferences.getInt(g1Pillar3aBeneficiaryWriterPidKey)",
        "writerPid == null",
        "writerPid <= 0",
        "writerPid == pid",
        "Reader reused the writer app process",
        "testOnlyRootRouter.go('/rapport')",
        "financial_report_screen",
        "financial_report_pillar3a_beneficiary_handoff",
        "Pillar3aBeneficiarySpecialistHandoff.tryFromConsumerResolution",
        "FinancialReportService().generateReport",
        "PdfService.buildFinancialReportPdfBytes",
        "pdfBytes.length, greaterThan(1000)",
        "utf8.decode(pdfBytes.take(5).toList())",
        "'%PDF-'",
        "Pillar3aBeneficiaryConsumerState.missingDocumentReference",
        "Pillar3aBeneficiaryConsumerState.mismatchedDocumentReference",
        "Pillar3aBeneficiaryConsumerState.invalidPresenceProvenance",
        "resetInvalidPillar3aBeneficiaryPresenceProvenance",
        "Pillar3aBeneficiaryLedgerState.invalid",
        "resetInvalidPillar3aBeneficiaryEvidence",
        "originalAnswers",
        "originalRootJson",
        "originalDocumentReferences",
        "finally",
        "handoff reappears after exact restoration",
    ):
        assert anchor in source, anchor

    missing = source.index("missingDocumentReference")
    mismatch = source.index("mismatchedDocumentReference")
    presence = source.index("invalidPresenceProvenance")
    invalid_root = source.index("Pillar3aBeneficiaryLedgerState.invalid")
    restoration = source.index("handoff reappears after exact restoration")
    assert missing < mismatch < presence < invalid_root < restoration


def test_writer_and_reader_use_shared_pid_contract() -> None:
    support = SUPPORT.read_text(encoding="utf-8")
    assert "const g1Pillar3aBeneficiaryWriterPidKey" in support
    assert "_g1_ret_ref_pillar3a_beneficiary_writer_pid_v1" in support
    for path in (WRITER, READER):
        source = path.read_text(encoding="utf-8")
        assert "g1_ret_ref_pillar3a_beneficiary_runtime_contract.dart" in source
        assert "dart:io" in source


def test_wrappers_delegate_to_exact_integration_entrypoints() -> None:
    assert "g1_ret_ref_pillar3a_beneficiary_write_patrol_test.dart" in (
        WRITE_WRAPPER.read_text(encoding="utf-8")
    )
    assert "g1_ret_ref_pillar3a_beneficiary_read_patrol_test.dart" in (
        READ_WRAPPER.read_text(encoding="utf-8")
    )


def test_maestro_proves_production_default_off_before_and_after() -> None:
    for path, clear_state in ((FLOW_BEFORE, True), (FLOW_AFTER, False)):
        documents = list(yaml.safe_load_all(path.read_text(encoding="utf-8")))
        assert len(documents) == 2
        header, steps = documents
        assert header["appId"] == "ch.mint.app"
        launches = [step["launchApp"] for step in steps if "launchApp" in step]
        assert launches == [{"clearState": clear_state}]
        visible = _ids_for_action(steps, "assertVisible")
        absent = _ids_for_action(steps, "assertNotVisible")
        assert {
            "landing_route",
            "scan_review_recovery_cta",
            "financial_report_screen",
        } <= visible
        assert {
            "document_scan_pillar3a_beneficiary_clause_type_selector",
            "retirement_pillar3a_beneficiary_reference_consumer",
            "financial_report_pillar3a_beneficiary_handoff",
        } <= absent


def test_orchestrator_is_valid_exact_pushed_sha_and_two_process_bounded() -> None:
    assert ORCHESTRATOR.stat().st_mode & stat.S_IXUSR
    subprocess.run(["bash", "-n", str(ORCHESTRATOR)], check=True)
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        "set -euo pipefail",
        "$HOME/.pub-cache/bin/patrol",
        'python3 "$repo_root/tools/checks/mint_os_doctor.py"',
        'python3 "$repo_root/tools/checks/patrol_tooling_guard.py"',
        "pillar3a_beneficiary_handoff_pdf_test.dart",
        "pdftotext",
        '[[ "$sha" == "$head_sha" ]]',
        "rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'",
        'git -C "$repo_root" merge-base --is-ancestor "$sha" "$upstream_ref"',
        "pushed_sha_verified=true",
        '[[ -d "$artifacts" && ! -L "$artifacts" ]]',
        'find "$artifacts" -mindepth 1 -print -quit',
        "artifact directory must be initially empty",
        'git -C "$repo_root" diff --quiet "$sha" --',
        "ls-files --others --exclude-standard -- apps/mobile tools/simulator tools/checks",
        "runtime contract is not tracked by HEAD",
        "g1_ret_ref_pillar3a_beneficiary_write_runtime_test.dart",
        "g1_ret_ref_pillar3a_beneficiary_read_runtime_test.dart",
        "g1_ret_ref_pillar3a_beneficiary_flag_off_before.yaml",
        "g1_ret_ref_pillar3a_beneficiary_flag_off_after.yaml",
        'git -C "$repo_root" archive --format=tar',
        "production_source_exported_exact=true",
        "production_source_physical=true",
        '"production_source_exported_exact"',
        '"production_source_physical"',
        "writer_reader_build_isolation_verified=false",
        "writer_reader_build_isolation_verified=true",
        '"writer_reader_build_isolation_verified"',
        'xcrun simctl boot "$device"',
        'xcrun simctl bootstatus "$device" -b',
        'boot_simulator',
        "run_xcode_test \"write\"",
        'xcrun simctl launch "$device" "$bundle_id"',
        'xcrun simctl terminate "$device" "$bundle_id"',
        "run_xcode_test \"read\"",
        "verify_xcresult_one_of_one \"write\"",
        "verify_xcresult_one_of_one \"read\"",
        "state_preserved_across_process_death=true",
        'run_maestro "before" "$flow_before"',
        'run_maestro "after" "$flow_after"',
        "production_default_off_before_passed=true",
        "production_default_off_after_passed=true",
        "runtime_completed=true",
    ):
        assert anchor in source, anchor

    stages = (
        "boot_simulator",
        'install_production_app "before"',
        'run_maestro "before" "$flow_before"',
        'run_xcode_test "write"',
        'xcrun simctl launch "$device" "$bundle_id"',
        'xcrun simctl terminate "$device" "$bundle_id"',
        'run_xcode_test "read"',
        'run_maestro "after" "$flow_after"',
    )
    execution = source[source.index("export_production_source\n") :]
    assert [execution.index(stage) for stage in stages] == sorted(
        execution.index(stage) for stage in stages
    )
    assert source.count('"$patrol_bin" --verbose build ios') == 1
    assert 'run_patrol_build "write" "$write_target"' in source
    assert 'run_patrol_build "read" "$read_target"' in source
    assert source.count('run_xcode_test "write"') == 1
    assert source.count('run_xcode_test "read"') == 1
    assert "simctl uninstall" not in source
    isolation_verified = source.rindex(
        "writer_reader_build_isolation_verified=true"
    )
    for prerequisite in (
        'run_patrol_build "write" "$write_target"',
        'run_xcode_test "write"',
        'verify_xcresult_one_of_one "write"',
        'rm -rf -- "$external_build"',
        'run_patrol_build "read" "$read_target"',
        'run_xcode_test "read"',
        'verify_xcresult_one_of_one "read"',
    ):
        assert source.rindex(prerequisite) < isolation_verified, prerequisite


def test_orchestrator_retains_only_sanitized_synthetic_metadata(
    tmp_path: Path,
) -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        "metadata.json",
        "REDACTED_REPO",
        "REDACTED_HOME",
        "REDACTED_SIMULATOR_UDID",
        "sanitize_log()",
        "verify_retained_artifacts()",
        'verify_retained_artifacts "partial"',
        'verify_retained_artifacts "final"',
        '"contract": "g1_ret_ref_pillar3a_beneficiary"',
        '"synthetic_data_only": True',
        '"private_fixture_used": False',
        '"distinct_process_pid_verified"',
        "distinct_process_pid_verified=true",
        '"write_passed_tests": 1',
        '"read_passed_tests": 1',
    ):
        assert anchor in source, anchor
    for forbidden in (
        "sanity_avoir_lpp_7M.pdf",
        "MINT_LPP_PRIVATE_MANIFEST",
        "source-manifest.sha256",
        "device.sha256",
    ):
        assert forbidden not in source, forbidden

    metadata_python = _embedded_python(source, "write_metadata")
    verifier_python = _embedded_python(source, "verify_retained_artifacts")
    expected_logs = _literal_assignment(metadata_python, "expected_logs")
    verifier_expected_logs = _literal_assignment(verifier_python, "expected_logs")
    assert verifier_expected_logs == expected_logs

    artifacts = tmp_path / "artifacts"
    artifacts.mkdir()
    verifier_args = (
        str(artifacts),
        str(ROOT),
        "/synthetic/home",
        "00000000-0000-0000-0000-000000000000",
        "/synthetic/external",
    )

    def verify(mode: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, "-c", verifier_python, *verifier_args, mode],
            text=True,
            capture_output=True,
            check=False,
        )

    assert verify("partial").returncode == 0
    (artifacts / expected_logs[0]).write_text("safe diagnostic\n", encoding="utf-8")
    assert verify("partial").returncode == 0

    for unexpected in ("unexpected.txt", "unexpected.log", "unexpected.json"):
        path = artifacts / unexpected
        path.write_text("benign but not allowlisted\n", encoding="utf-8")
        assert verify("partial").returncode != 0, unexpected
        path.unlink()

    allowed_log = artifacts / expected_logs[0]
    encoded_pdf = base64.b64encode(b"%PDF-1.7 raw OCR beneficiary").decode()
    for unsafe in (
        "rawOcr: Jean Dupont",
        "sourceText: Beneficiaire Jean Dupont",
        "raw OCR: AVS 756.1234.5678.97",
        encoded_pdf,
    ):
        allowed_log.write_text(unsafe, encoding="utf-8")
        assert verify("partial").returncode != 0, unsafe
    allowed_log.write_text("safe diagnostic\n", encoding="utf-8")

    for expected in expected_logs[1:]:
        (artifacts / expected).write_text("safe diagnostic\n", encoding="utf-8")
    (artifacts / "metadata.json").write_text("{}\n", encoding="utf-8")
    assert verify("final").returncode == 0

    (artifacts / expected_logs[-1]).unlink()
    assert verify("final").returncode != 0

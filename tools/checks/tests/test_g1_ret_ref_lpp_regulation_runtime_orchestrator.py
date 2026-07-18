from __future__ import annotations

import re
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest
import yaml


ROOT = Path(__file__).resolve().parents[3]
ORCHESTRATOR = ROOT / "tools/simulator/patrol_lpp_regulation_process_death.sh"
WRITER = (
    ROOT / "apps/mobile/integration_test/"
    "g1_ret_ref_lpp_regulation_write_patrol_test.dart"
)
READER = (
    ROOT / "apps/mobile/integration_test/"
    "g1_ret_ref_lpp_regulation_read_patrol_test.dart"
)
WRITE_WRAPPER = (
    ROOT / "apps/mobile/test/patrol/g1_ret_ref_lpp_regulation_write_runtime_test.dart"
)
READ_WRAPPER = (
    ROOT / "apps/mobile/test/patrol/g1_ret_ref_lpp_regulation_read_runtime_test.dart"
)
FLOW_BEFORE = (
    ROOT / "apps/mobile/.maestro/g1_ret_ref_lpp_regulation_flag_off_before.yaml"
)
FLOW_AFTER = ROOT / "apps/mobile/.maestro/g1_ret_ref_lpp_regulation_flag_off_after.yaml"
FEATURE_FLAGS = ROOT / "apps/mobile/lib/services/feature_flags.dart"
RUNTIME_ASSETS = (
    ORCHESTRATOR,
    WRITER,
    READER,
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
        pytest.skip(
            "TDD RED: missing LPP regulation runtime assets: " + ", ".join(missing)
        )


def _embedded_python(source: str, function_name: str) -> str:
    marker = f"{function_name}() {{"
    assert marker in source, f"missing executable {function_name} contract"
    function_start = source.index(marker)
    heredoc_start = source.index("<<'PY'\n", function_start) + len("<<'PY'\n")
    heredoc_end = source.index("\nPY\n", heredoc_start)
    return source[heredoc_start:heredoc_end]


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


def test_runtime_assets_are_checked_in() -> None:
    assert _missing_assets() == []


def test_orchestrator_is_valid_bash_exact_head_and_pushed_sha_bounded() -> None:
    assert ORCHESTRATOR.stat().st_mode & stat.S_IXUSR
    subprocess.run(["bash", "-n", str(ORCHESTRATOR)], check=True)
    source = ORCHESTRATOR.read_text(encoding="utf-8")

    for anchor in (
        "set -euo pipefail",
        "$HOME/.pub-cache/bin/patrol",
        'python3 "$repo_root/tools/checks/mint_os_doctor.py"',
        'python3 "$repo_root/tools/checks/patrol_tooling_guard.py"',
        '[[ "$sha" == "$head_sha" ]]',
        "rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'",
        'git -C "$repo_root" merge-base --is-ancestor "$sha" "$upstream_ref"',
        "pushed_sha_verified=true",
        'git -C "$repo_root" diff --quiet "$sha" --',
        "ls-files --others --exclude-standard -- apps/mobile tools/simulator",
        "runtime contract is not tracked by HEAD",
        "g1_ret_ref_lpp_regulation_write_patrol_test.dart",
        "g1_ret_ref_lpp_regulation_read_patrol_test.dart",
        "g1_ret_ref_lpp_regulation_write_runtime_test.dart",
        "g1_ret_ref_lpp_regulation_read_runtime_test.dart",
        "g1_ret_ref_lpp_regulation_flag_off_before.yaml",
        "g1_ret_ref_lpp_regulation_flag_off_after.yaml",
        "apps/mobile/lib/app.dart",
        "apps/mobile/lib/models/lpp_evidence.dart",
        "apps/mobile/lib/providers/scan_session_provider.dart",
        "apps/mobile/lib/providers/coach_profile_provider.dart",
        "apps/mobile/lib/providers/document_provider.dart",
        "apps/mobile/lib/screens/document_scan/document_scan_screen.dart",
        "apps/mobile/lib/screens/document_scan/extraction_review_screen.dart",
        "apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart",
        "apps/mobile/lib/services/consent/consent_service.dart",
        "apps/mobile/lib/services/document_service.dart",
        "apps/mobile/lib/services/feature_flags.dart",
        "apps/mobile/lib/services/report_persistence_service.dart",
        'git -C "$repo_root" archive --format=tar',
        "production_source_exported_exact=true",
        "production_source_physical=true",
        "stat.S_ISLNK",
        "entry_status.st_nlink > 1",
        '"pushed_sha_verified": True',
        '"sha": os.environ["MINT_META_SHA"]',
    ):
        assert anchor in source, anchor

    # The exact commit is the authority. Do not create a second retained hash
    # inventory or a pseudonymous device fingerprint for this privacy atom.
    for forbidden in (
        "source-manifest.sha256",
        "device.sha256",
        '"device_sha256"',
    ):
        assert forbidden not in source, forbidden


def test_orchestrator_orders_default_off_and_process_death() -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    stages = (
        'build_production_app "before"',
        'install_production_app "before"',
        'run_maestro "before" "$flow_before"',
        'run_patrol_build "write"',
        'run_xcode_test "write"',
        'xcrun simctl launch "$device" "$bundle_id"',
        'xcrun simctl terminate "$device" "$bundle_id"',
        'install_production_app "after"',
        'run_maestro "after" "$flow_after"',
        'run_patrol_build "read"',
        'run_xcode_test "read"',
    )
    for anchor in (
        '"$patrol_bin" --verbose build ios',
        "--dart-define=MINT_PATROL_CLI=true",
        "xcodebuild test-without-building",
        '-only-testing "RunnerUITests/RunnerUITests"',
        *stages,
        'verify_xcresult_one_of_one "write"',
        'verify_xcresult_one_of_one "read"',
        "state_preserved_across_process_death=true",
        "production_default_off_before_passed=true",
        "production_default_off_after_passed=true",
        "flutter build ios --simulator --debug --target lib/main.dart",
        'xcrun simctl install "$device" "$production_app"',
        '"${maestro_command[@]}" test --udid "$device"',
        "maestro-before-report.sanitized.xml",
        "maestro-after-report.sanitized.xml",
        "runtime_completed=true",
    ):
        assert anchor in source, anchor

    assert [source.index(stage) for stage in stages] == sorted(
        source.index(stage) for stage in stages
    )
    assert source.count('"$patrol_bin" --verbose build ios') == 2
    assert source.count('run_xcode_test "write"') == 1
    assert source.count('run_xcode_test "read"') == 1
    assert "simctl uninstall" not in source

    production_build = source[
        source.index("build_production_app() {") : source.index(
            "install_production_app() {"
        )
    ]
    assert "--dart-define" not in production_build


def test_orchestrator_retains_only_sanitized_synthetic_metadata(
    tmp_path: Path,
) -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        "metadata.json",
        "REDACTED_REPO",
        "REDACTED_HOME",
        "REDACTED_SIMULATOR_UDID",
        "REDACTED_EXTERNAL_BUILD",
        "REDACTED_PRIVATE_TEMP",
        "sanitize_log()",
        "verify_retained_artifacts()",
        'rm -f -- "$raw"',
        'rm -rf -- "$write_xcresult" "$read_xcresult"',
        "raw Maestro report removal failed",
        "external build removal failed",
        '"contract": "g1_ret_ref_lpp_regulation"',
        '"synthetic_data_only": True',
        '"private_fixture_used": False',
        '"document_hash_retained": False',
        '"raw_document_bytes_retained": False',
        '"simulator_identifier_retained": False',
        '"xcresult_retained": False',
        '"feature_activation": "test_process_static_flags_only"',
        '"state_preservation": "writer_process_death_cold_reader"',
        '"write_passed_tests": 1',
        '"write_failed_tests": 0',
        '"read_passed_tests": 1',
        '"read_failed_tests": 0',
        '"maestro_before_exit_code"',
        '"maestro_after_exit_code"',
    ):
        assert anchor in source, anchor

    for forbidden in (
        "MINT_LPP_PRIVATE_MANIFEST",
        "test/golden",
        "Télécharger le certificat de prévoyance.pdf",
        "Certificat_Lauren.jpeg",
    ):
        assert forbidden not in source, forbidden

    guard = _embedded_python(source, "verify_retained_artifacts")

    def run_guard(artifacts: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                "-",
                str(artifacts),
                "/Users/synthetic/repo",
                "/Users/synthetic",
                "123E4567-E89B-42D3-A456-426614174000",
                "/private/tmp/mint-patrol-synthetic",
            ],
            input=guard,
            text=True,
            capture_output=True,
            check=False,
        )

    safe = tmp_path / "safe"
    safe.mkdir()
    (safe / "metadata.json").write_text(
        '{"private_fixture_used":false,"cleanup_status":"passed"}\n',
        encoding="utf-8",
    )
    (safe / "maestro-after-report.sanitized.xml").write_text(
        '<testsuite device="REDACTED_SIMULATOR_UDID"/>\n',
        encoding="utf-8",
    )
    assert run_guard(safe).returncode == 0

    unsafe_cases = {
        "repo-path.log": "/Users/synthetic/repo",
        "fixture-path.log": "test/golden/private-certificate.pdf",
        "fixture-key.log": "MINT_LPP_PRIVATE_MANIFEST",
        "document-hash.log": "a" * 64,
        "raw-bytes.log": "%PDF-1.7 private bytes",
        "raw-udid.log": "123E4567-E89B-42D3-A456-426614174000",
        "write.xcresult": "raw Xcode result bundle",
        "device.sha256": "pseudonymous simulator hash",
        "private-document.pdf": "fixture payload",
        "stage.raw.log": "must not survive cleanup",
        "maestro-report.xml": "unsanitized report",
        "maestro-debug.png": "unsanitized debug media",
    }
    for name, content in unsafe_cases.items():
        case = tmp_path / re.sub(r"[^A-Za-z0-9]+", "-", name)
        case.mkdir()
        (case / name).write_text(content, encoding="utf-8")
        assert run_guard(case).returncode != 0, name

    cleanup = source[source.index("cleanup() {") : source.index("trap cleanup EXIT")]
    guard_call = "if ! verify_retained_artifacts; then"
    assert guard_call in cleanup
    assert cleanup.index(guard_call) < cleanup.index('cleanup_status="failed"')
    assert cleanup.index(guard_call) < cleanup.index("write_metadata")


def test_writer_uses_plan_picker_upload_and_volatile_review() -> None:
    writer = WRITER.read_text(encoding="utf-8")
    assert writer.count("patrolTest(") == 1
    for anchor in (
        "MINT_PATROL_CLI",
        "FeatureFlags.typedLppEvidence = true;",
        "FeatureFlags.documentLppEvidenceEnabled = true;",
        "FeatureFlags.lppRegulationReferenceEnabled = true;",
        "FeatureFlags.typedLppEvidence = false;",
        "FeatureFlags.documentLppEvidenceEnabled = false;",
        "FeatureFlags.lppRegulationReferenceEnabled = false;",
        "ReportPersistenceService.clearDiagnostic()",
        "await ledger.acceptLppReview(_initialNumericReview(",
        "DocumentScanScreen(",
        "initialType: DocumentType.lppPlan",
        "pickFile:",
        "requireConsent:",
        "ConsentPurpose.visionExtraction",
        "uploadDocument:",
        "VaultDocumentType.lppPlan",
        "expect(type, VaultDocumentType.lppPlan);",
        "DocumentUploadResult.fromJson",
        "expect(upload.isExactLppPlanAuthority, isTrue);",
        "'document_type': 'lpp_plan'",
        "'extracted_fields': <String, dynamic>{}",
        "'confidence': 0",
        "'fields_found': 0",
        "'fields_total': 0",
        "'warnings': <String>[]",
        "'rag_indexed': false",
        "%PDF-1.7 MINT synthetic LPP regulation runtime bytes only",
        "document_scan_lpp_plan_type_selector",
        "document_scan_gallery_cta",
        "expect(purposes, const <ConsentPurpose>[ConsentPurpose.visionExtraction]);",
        "routeUri.queryParameters.keys",
        "const <String>{'scanSessionId'}",
        "expect(scanSessionId, isNot(contains(_backendDocumentId)));",
        "scanSessions.byId(scanSessionId)",
        "retained.lppRegulationCandidate",
        "retained.extraction.documentType",
        "DocumentType.lppPlan",
        "lppRegulationCandidate: payload.lppRegulationCandidate",
        "lpp_regulation_review_source_date",
        "lpp_regulation_review_legal_year",
        "lpp_regulation_review_confirm_cta",
        "super.acceptLppRegulationReference(confirmation)",
        "super.recordLppRegulation(receipt)",
        "expect(events, const <String>['accept', 'record'])",
        "DocumentReferenceStore.storageKey",
        "isNot(contains(_rawMarker))",
        "isNot(contains(_backendDocumentId))",
        "expect(scanSessions.byId(scanSessionId), isNull)",
        "retirement_lpp_regulation_reference_education",
    ):
        assert anchor in writer, anchor

    assert writer.index("#document_scan_gallery_cta") < writer.index(
        "#lpp_regulation_review_source_date"
    )
    assert writer.index("#lpp_regulation_review_source_date") < writer.index(
        "#lpp_regulation_review_confirm_cta"
    )
    assert writer.index("#lpp_regulation_review_confirm_cta") < writer.index(
        "expect(events, const <String>['accept', 'record'])"
    )

    # Runtime observes the production UI's writer seam through thin super
    # spies; it must not manually invoke the two regulation writers.
    for forbidden in (
        "ledger.acceptLppRegulationReference(",
        "documents.recordLppRegulation(",
        "DocumentProvider.uploadDocument",
        "MINT_LPP_PRIVATE_MANIFEST",
        "/Users/",
        "test/golden",
    ):
        assert forbidden not in writer, forbidden

    seed_start = writer.index("ReportPersistenceService.saveAnswers(")
    seed_end = writer.index(");", seed_start)
    assert "_coach_lpp_evidence_v1" not in writer[seed_start:seed_end]


def test_cold_reader_handoff_then_numeric_replacement_hides_reference() -> None:
    reader = READER.read_text(encoding="utf-8")
    assert reader.count("patrolTest(") == 1
    for anchor in (
        "FeatureFlags.typedLppEvidence = true;",
        "FeatureFlags.documentLppEvidenceEnabled = true;",
        "FeatureFlags.lppRegulationReferenceEnabled = true;",
        "FeatureFlags.typedLppEvidence = false;",
        "FeatureFlags.documentLppEvidenceEnabled = false;",
        "FeatureFlags.lppRegulationReferenceEnabled = false;",
        "await provider.loadFromWizard();",
        "documents.bindLedger(provider);",
        "await documents.hydrateReferences();",
        "final candidate = provider.profile!.lppRegulationReference;",
        "final resolved = documents.resolveLppRegulation(candidate);",
        "expect(resolved, isNotNull);",
        "documents.byId(candidate!.referenceId)",
        "expect(reference.snapshotId, currentSnapshot.snapshotId);",
        "RetirementDashboardScreen()",
        "retirement_lpp_regulation_reference_education",
        "retirement_lpp_regulation_handoff_cta",
        "retirement_lpp_regulation_handoff_sheet",
        "retirement_lpp_regulation_handoff_title",
        "retirement_lpp_regulation_handoff_privacy",
        "retirement_lpp_regulation_handoff_close",
        "await provider.acceptLppReview(_replacementNumericReview(",
        "isNot(currentSnapshot.snapshotId)",
        "expect(replacementSnapshot.lppRegulationReference, isNull);",
        "expect(provider.profile!.lppRegulationReference, isNull);",
        "expect(documents.resolveLppRegulation(candidate), isNull);",
        "findsNothing",
    ):
        assert anchor in reader, anchor

    assert (
        reader.index("await documents.hydrateReferences();")
        < reader.index("retirement_lpp_regulation_reference_education")
        < reader.index("retirement_lpp_regulation_handoff_cta")
        < reader.index("retirement_lpp_regulation_handoff_sheet")
        < reader.index("await provider.acceptLppReview(_replacementNumericReview(")
    )
    assert "acceptLppRegulationReference(" not in reader
    assert "recordLppRegulation(" not in reader
    assert reader.count("acceptLppReview(") == 1
    for forbidden in (
        "MINT_LPP_PRIVATE_MANIFEST",
        "/Users/",
        "test/golden",
    ):
        assert forbidden not in reader, forbidden


def test_wrappers_local_flags_and_dual_maestro_keep_production_default_off() -> None:
    flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    for declaration in (
        "static bool typedLppEvidence = false;",
        "static bool documentLppEvidenceEnabled = false;",
        "static bool lppRegulationReferenceEnabled = false;",
    ):
        assert declaration in flags, declaration
    apply_from_map = flags[flags.index("static void applyFromMap") :]
    for remote_forbidden in (
        "documentLppEvidenceEnabled",
        "lppRegulationReferenceEnabled",
    ):
        assert remote_forbidden not in apply_from_map, remote_forbidden

    write_wrapper = WRITE_WRAPPER.read_text(encoding="utf-8")
    read_wrapper = READ_WRAPPER.read_text(encoding="utf-8")
    assert "g1_ret_ref_lpp_regulation_write_patrol_test.dart" in write_wrapper
    assert "lpp_regulation_write.main();" in write_wrapper
    assert "g1_ret_ref_lpp_regulation_read_patrol_test.dart" in read_wrapper
    assert "lpp_regulation_read.main();" in read_wrapper

    before_contents = FLOW_BEFORE.read_text(encoding="utf-8")
    after_contents = FLOW_AFTER.read_text(encoding="utf-8")
    before_header, before_body = before_contents.split("---", 1)
    after_header, after_body = after_contents.split("---", 1)
    assert yaml.safe_load(before_header) == {
        "appId": "ch.mint.app",
        "name": "G1 RET-REF LPP regulation production-default before",
    }
    assert yaml.safe_load(after_header) == {
        "appId": "ch.mint.app",
        "name": "G1 RET-REF LPP regulation production-default after",
    }
    before_steps = yaml.safe_load(before_body)
    after_steps = yaml.safe_load(after_body)
    assert isinstance(before_steps, list)
    assert isinstance(after_steps, list)
    assert "clearState: true" in before_contents
    assert "clearState: true" not in after_contents
    assert "clearState: false" in after_contents

    required_ids = {
        "landing_route",
        "document_scan_capture_cta",
        "document_scan_lpp_plan_type_selector",
        "lpp_regulation_review_source_date",
        "lpp_regulation_review_confirm_cta",
        "retirement_lpp_regulation_reference_education",
        "retirement_lpp_regulation_handoff_sheet",
    }
    for contents, steps in (
        (before_contents, before_steps),
        (after_contents, after_steps),
    ):
        assert 'openLink: "mint:///scan?type=lppPlan"' in contents
        assert 'openLink: "mint:///retraite"' in contents
        assert required_ids <= _collect_yaml_ids(steps)
        assert {
            "landing_route",
            "document_scan_capture_cta",
        } <= _ids_for_action(steps, "assertVisible")
        assert required_ids - {
            "landing_route",
            "document_scan_capture_cta",
        } <= _ids_for_action(steps, "assertNotVisible")
        for forbidden in (
            "tapOn:",
            "inputText:",
            "point:",
            "text:",
            "MINT_LPP_PRIVATE_MANIFEST",
            "/Users/",
            "test/golden",
        ):
            assert forbidden not in contents, forbidden

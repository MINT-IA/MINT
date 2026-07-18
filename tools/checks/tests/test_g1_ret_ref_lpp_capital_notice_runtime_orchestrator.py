from __future__ import annotations

import subprocess
from pathlib import Path

import pytest
import yaml


ROOT = Path(__file__).resolve().parents[3]
ORCHESTRATOR = ROOT / "tools/simulator/patrol_lpp_capital_notice_process_death.sh"
WRITER = (
    ROOT / "apps/mobile/integration_test/"
    "g1_ret_ref_lpp_capital_notice_write_patrol_test.dart"
)
READER = (
    ROOT / "apps/mobile/integration_test/"
    "g1_ret_ref_lpp_capital_notice_read_patrol_test.dart"
)
WRITE_WRAPPER = (
    ROOT / "apps/mobile/test/patrol/"
    "g1_ret_ref_lpp_capital_notice_write_runtime_test.dart"
)
READ_WRAPPER = (
    ROOT / "apps/mobile/test/patrol/"
    "g1_ret_ref_lpp_capital_notice_read_runtime_test.dart"
)
FLOW = ROOT / "apps/mobile/.maestro/g1_ret_ref_lpp_capital_notice_flag_off.yaml"
FEATURE_FLAGS = ROOT / "apps/mobile/lib/services/feature_flags.dart"
RUNTIME_ASSETS = (ORCHESTRATOR, WRITER, READER, WRITE_WRAPPER, READ_WRAPPER, FLOW)


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
        pytest.skip("TDD RED: missing runtime assets: " + ", ".join(missing))


def test_runtime_assets_are_checked_in() -> None:
    assert _missing_assets() == []


def test_orchestrator_is_valid_bash_and_exact_sha_bounded() -> None:
    assert ORCHESTRATOR.stat().st_mode & 0o111
    subprocess.run(["bash", "-n", str(ORCHESTRATOR)], check=True)
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        "set -euo pipefail",
        "$HOME/.pub-cache/bin/patrol",
        'python3 "$repo_root/tools/checks/mint_os_doctor.py"',
        'python3 "$repo_root/tools/checks/patrol_tooling_guard.py"',
        '[[ "$sha" == "$head_sha" ]]',
        'git -C "$repo_root" diff --quiet "$sha" --',
        "ls-files --others --exclude-standard -- apps/mobile tools/simulator",
        "runtime contract is not tracked by HEAD",
        "source-manifest.sha256",
        "g1_ret_ref_lpp_capital_notice_write_patrol_test.dart",
        "g1_ret_ref_lpp_capital_notice_read_patrol_test.dart",
        "g1_ret_ref_lpp_capital_notice_write_runtime_test.dart",
        "g1_ret_ref_lpp_capital_notice_read_runtime_test.dart",
        "g1_ret_ref_lpp_capital_notice_runtime_contract.dart",
        "g1_ret_ref_lpp_capital_notice_flag_off.yaml",
        "apps/mobile/lib/app.dart",
        "apps/mobile/lib/models/lpp_evidence.dart",
        "apps/mobile/lib/providers/coach_profile_provider.dart",
        "apps/mobile/lib/providers/document_provider.dart",
        "apps/mobile/lib/providers/scan_session_provider.dart",
        "apps/mobile/lib/screens/document_scan/document_scan_screen.dart",
        "apps/mobile/lib/screens/document_scan/extraction_review_screen.dart",
        "apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart",
    ):
        assert anchor in source, anchor


def test_orchestrator_proves_process_death_state_and_normal_app_restore() -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    stages = (
        'run_xcode_test "write"',
        'xcrun simctl bootstatus "$device" -b',
        'xcrun simctl launch "$device" "$bundle_id"',
        'xcrun simctl terminate "$device" "$bundle_id"',
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
        "write.xcresult",
        "read.xcresult",
        "state_preserved_across_process_death=true",
        "normal_build_manifest_before_sha256",
        "normal_build_manifest_after_sha256",
        "normal_build_core_hashes_verified=true",
        'git -C "$repo_root" archive --format=tar',
        "production_source_exported_exact=true",
        "production_source_physical=true",
        "stat.S_ISLNK",
        "entry_status.st_nlink > 1",
        "flutter build ios --simulator --debug --target lib/main.dart",
        'xcrun simctl install "$device" "$production_app"',
        '"${maestro_command[@]}" test --udid "$device"',
        "maestro-report.sanitized.xml",
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


def test_orchestrator_retains_only_sanitized_synthetic_metadata() -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        "metadata.json",
        "device.sha256",
        "REDACTED_REPO",
        "REDACTED_HOME",
        "REDACTED_SIMULATOR_UDID",
        "REDACTED_EXTERNAL_BUILD",
        "REDACTED_PRIVATE_TEMP",
        "sanitize_log()",
        "verify_retained_artifacts()",
        'rm -f -- "$raw"',
        "raw Maestro report removal failed",
        "external build removal failed",
        '"contract": "g1_ret_ref_lpp_capital_notice"',
        '"synthetic_data_only": True',
        '"private_fixture_used": False',
        '"production_capital_notice_acquisition_seam_used": True',
        '"feature_activation": "test_process_static_flags_only"',
        '"state_preservation": "writer_process_death_cold_reader"',
        '"write_passed_tests": 1',
        '"write_failed_tests": 0',
        '"read_passed_tests": 1',
        '"read_failed_tests": 0',
        '"boot_status_exit_code"',
        '"terminate_exit_code"',
        '"production_build_exit_code"',
        '"maestro_exit_code"',
    ):
        assert anchor in source, anchor
    assert '"production_capital_notice_acquisition_seam_used": False' not in source
    for forbidden in (
        "MINT_LPP_PRIVATE_MANIFEST",
        "Télécharger le certificat de prévoyance.pdf",
        "Certificat_Lauren.jpeg",
    ):
        assert forbidden not in source, forbidden


def test_writer_uses_native_lpp_plan_acquisition_and_review_seam() -> None:
    writer = WRITER.read_text(encoding="utf-8")
    assert writer.count("patrolTest(") == 1
    for anchor in (
        "MINT_PATROL_CLI",
        "FeatureFlags.typedLppEvidence = true;",
        "FeatureFlags.documentLppEvidenceEnabled = true;",
        "FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;",
        "FeatureFlags.lppCapitalNoticeDeadlineEnabled = false;",
        "FeatureFlags.lppRegulationReferenceEnabled = true;",
        "FeatureFlags.lppRegulationReferenceEnabled = false;",
        "ReportPersistenceService.clearDiagnostic()",
        "Directory.systemTemp.createTemp(",
        "%PDF-1.7 MINT synthetic",
        "delete(recursive: true)",
        "path: '/scan'",
        "DocumentType.values",
        "state.uri.queryParameters['type']",
        "initialType: initialType",
        "DocumentScanScreen(",
        "ExtractionReviewScreen(",
        "DocumentImpactScreen(",
        "router.go('/scan?type=lppPlan')",
        "DocumentType.lppPlan",
        "VaultDocumentType.lppPlan",
        "ConsentPurpose.visionExtraction",
        "const <ConsentPurpose>[ConsentPurpose.visionExtraction]",
        "pickFile:",
        "PlatformFile(",
        "path: syntheticPlan.path",
        "uploadDocument:",
        "DocumentUploadResult.fromJson(",
        "'document_type': 'lpp_plan'",
        "'extracted_fields': <String, dynamic>{}",
        "'fields_found': 0",
        "'fields_total': 0",
        "'rag_indexed': false",
        "upload.isExactLppPlanAuthority",
        "visionExtractor:",
        "document_scan_lpp_type_selector",
        "document_scan_lpp_example_cta",
        "lpp_review_confirm_cta",
        "await $(#lpp_impact_retirement_cta).scrollTo().tap();",
        "expect(router.routeInformationProvider.value.uri.path, '/retraite');",
        "LppEvidenceSelector.selectSelf",
        "document_scan_lpp_plan_type_selector",
        "lppRegulationCandidate: payload.lppRegulationCandidate",
        "lppCapitalNoticeCandidate: payload.lppCapitalNoticeCandidate",
        "retained.lppCapitalNoticeCandidate",
        "expectedSnapshotId",
        "lpp_regulation_review_source_date",
        "lpp_regulation_review_legal_year",
        "lpp_regulation_fund_relation_current",
        "lpp_capital_notice_deadline_question",
        "lpp_capital_notice_deadline_field",
        "lpp_regulation_review_confirm_cta",
        "accept_regulation",
        "record_regulation",
        "accept_capital",
        "record_capital",
        "expect(events, const <String>[",
        "expect(scanSessions.byId(scanSessionId), isNull)",
        "final retirementScrollable = find.byWidgetPredicate(",
        "widget is Scrollable && widget.axisDirection == AxisDirection.down",
        "await $.tester.scrollUntilVisible(",
        "scrollable: retirementScrollable",
        "g1LppCapitalNoticeWriterPidKey",
        "setInt(g1LppCapitalNoticeWriterPidKey, pid)",
        "DocumentReferenceStore.storageKey",
    ):
        assert anchor in writer, anchor
    impact_exit_index = writer.index(
        "await $(#lpp_impact_retirement_cta).scrollTo().tap();"
    )
    retirement_index = writer.index(
        "expect(router.routeInformationProvider.value.uri.path, '/retraite');"
    )
    route_index = writer.index("router.go('/scan?type=lppPlan')")
    plan_selector_index = writer.index("#document_scan_lpp_plan_type_selector")
    source_date_index = writer.index("#lpp_regulation_review_source_date")
    legal_year_index = writer.index("#lpp_regulation_review_legal_year")
    current_fund_index = writer.index("#lpp_regulation_fund_relation_current")
    deadline_index = writer.index("#lpp_capital_notice_deadline_field")
    confirm_index = writer.index("#lpp_regulation_review_confirm_cta")
    assert (
        impact_exit_index
        < retirement_index
        < route_index
        < plan_selector_index
        < source_date_index
        < legal_year_index
        < current_fund_index
        < deadline_index
        < confirm_index
    )
    # Spies may override these methods above main(), but the test body must
    # reach them only through DocumentScanScreen -> ExtractionReviewScreen.
    main_body = writer[writer.index("void main()") :]
    event_order = (
        main_body.index("'accept_regulation'"),
        main_body.index("'record_regulation'"),
        main_body.index("'accept_capital'"),
        main_body.index("'record_capital'"),
    )
    assert list(event_order) == sorted(event_order)
    for forbidden_direct_bridge in (
        "await provider.acceptLppRegulationReference(",
        "await ledger.acceptLppRegulationReference(",
        "await documents.recordLppRegulation(",
        "await provider.acceptLppCapitalNotice(",
        "await ledger.acceptLppCapitalNotice(",
        "await documents.recordLppCapitalNotice(",
        "LppCapitalNoticeReviewConfirmation(",
    ):
        assert forbidden_direct_bridge not in main_body, forbidden_direct_bridge
    assert "provider.acceptLppReview(" not in writer
    for forbidden in ("MINT_LPP_PRIVATE_MANIFEST", "/Users/", "test/golden"):
        assert forbidden not in writer, forbidden


def test_cold_reader_distinct_pid_then_authority_and_snapshot_fail_closed() -> None:
    reader = READER.read_text(encoding="utf-8")
    assert reader.count("patrolTest(") == 1
    for anchor in (
        "FeatureFlags.typedLppEvidence = true;",
        "FeatureFlags.lppCapitalNoticeDeadlineEnabled = true;",
        "FeatureFlags.lppRegulationReferenceEnabled = true;",
        "g1LppCapitalNoticeWriterPidKey",
        "SharedPreferences.getInstance()",
        "getInt(g1LppCapitalNoticeWriterPidKey)",
        "expect(writerPid, isNotNull)",
        "expect(pid, isNot(writerPid))",
        "await provider.loadFromWizard();",
        "documents.bindLedger(provider);",
        "await documents.hydrateReferences();",
        "final candidate = provider.profile!.lppCapitalNoticeDeadline;",
        "final resolved = documents.resolveLppCapitalNotice(candidate);",
        "expect(resolved, isNotNull);",
        "documents.byId(candidate!.referenceId)",
        "expect(reference.snapshotId, currentSnapshot.snapshotId);",
        "RetirementDashboardScreen()",
        "retirement_lpp_capital_notice_deadline_education",
        "final authorityBeforeReplacement =",
        "provider.profile!.lppRegulationReference",
        "final replacementAuthorityReceipt =",
        "await provider.acceptLppRegulationReference(",
        "expectedPreviousReferenceId: authorityBeforeReplacement.referenceId",
        "await documents.recordLppRegulation(replacementAuthorityReceipt)",
        "expect(documents.resolveLppCapitalNotice(candidate), isNull)",
        "await provider.acceptLppReview(",
        "LppEvidenceAuthorizationMode.self",
        "replacementSnapshot.snapshotId",
        "isNot(currentSnapshot.snapshotId)",
        "expect(replacementSnapshot.lppCapitalNoticeDeadline, isNull);",
        "expect(provider.profile!.lppCapitalNoticeDeadline, isNull);",
        "expect(documents.resolveLppCapitalNotice(candidate), isNull);",
        "findsNothing",
    ):
        assert anchor in reader, anchor
    assert (
        reader.index("await documents.hydrateReferences();")
        < reader.index("retirement_lpp_capital_notice_deadline_education")
        < reader.index("await provider.acceptLppRegulationReference(")
        < reader.index("await provider.acceptLppReview(")
    )
    assert "acceptLppCapitalNotice(" not in reader
    assert "recordLppCapitalNotice(" not in reader
    assert reader.count("acceptLppReview(") == 1
    for forbidden in ("MINT_LPP_PRIVATE_MANIFEST", "/Users/", "test/golden"):
        assert forbidden not in reader, forbidden


def test_wrappers_flags_and_maestro_keep_production_seam_invisible() -> None:
    flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    assert "static bool lppCapitalNoticeDeadlineEnabled = false;" in flags
    apply_from_map = flags[flags.index("static void applyFromMap") :]
    assert "lppCapitalNoticeDeadlineEnabled" not in apply_from_map

    write_wrapper = WRITE_WRAPPER.read_text(encoding="utf-8")
    read_wrapper = READ_WRAPPER.read_text(encoding="utf-8")
    assert "g1_ret_ref_lpp_capital_notice_write_patrol_test.dart" in write_wrapper
    assert "capital_notice_write.main();" in write_wrapper
    assert "g1_ret_ref_lpp_capital_notice_read_patrol_test.dart" in read_wrapper
    assert "capital_notice_read.main();" in read_wrapper

    contents = FLOW.read_text(encoding="utf-8")
    header, body = contents.split("---", 1)
    assert yaml.safe_load(header) == {
        "appId": "ch.mint.app",
        "name": "G1 RET-REF LPP capital notice production-default flag-off",
    }
    steps = yaml.safe_load(body)
    assert isinstance(steps, list)
    for anchor in (
        "clearState: true",
        "landing_route",
        "mint:///scan?type=lppPlan",
        "document_scan_capture_cta",
        "document_scan_lpp_plan_type_selector",
        "lpp_regulation_review_source_date",
        "lpp_regulation_review_legal_year",
        "lpp_capital_notice_deadline_field",
        "lpp_regulation_review_confirm_cta",
        "mint:///retraite",
        "retirement_lpp_capital_notice_deadline_education",
        "assertNotVisible:",
    ):
        assert anchor in contents, anchor
    for forbidden in (
        "tapOn:",
        "inputText:",
        "point:",
        "text:",
        "capital_notice_type_selector",
        "capital_notice_upload",
        "capital_notice_review",
        "MINT_LPP_PRIVATE_MANIFEST",
        "/Users/",
    ):
        assert forbidden not in contents, forbidden

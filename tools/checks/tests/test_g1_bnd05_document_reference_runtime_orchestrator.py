from __future__ import annotations

import subprocess
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[3]
ORCHESTRATOR = (
    ROOT / "tools/simulator/patrol_bnd05_document_reference_process_death.sh"
)
WRITER = (
    ROOT
    / "apps/mobile/integration_test/g1_bnd05_document_reference_write_patrol_test.dart"
)
READER = (
    ROOT
    / "apps/mobile/integration_test/g1_bnd05_document_reference_read_patrol_test.dart"
)
WRITE_WRAPPER = (
    ROOT
    / "apps/mobile/test/patrol/g1_bnd05_document_reference_write_runtime_test.dart"
)
READ_WRAPPER = (
    ROOT
    / "apps/mobile/test/patrol/g1_bnd05_document_reference_read_runtime_test.dart"
)
FLOW = ROOT / "apps/mobile/.maestro/g1_bnd05_document_reference_flag_off.yaml"


def test_orchestrator_is_valid_bash() -> None:
    assert ORCHESTRATOR.is_file()
    assert ORCHESTRATOR.stat().st_mode & 0o111
    subprocess.run(["bash", "-n", str(ORCHESTRATOR)], check=True)


def test_orchestrator_is_bnd05_exact_sha_and_source_bounded() -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        "g1_bnd05_document_reference_write_patrol_test.dart",
        "g1_bnd05_document_reference_read_patrol_test.dart",
        "g1_bnd05_document_reference_write_runtime_test.dart",
        "g1_bnd05_document_reference_read_runtime_test.dart",
        "g1_bnd05_document_reference_flag_off.yaml",
        "apps/mobile/lib/app.dart",
        "apps/mobile/lib/models/lpp_evidence.dart",
        "apps/mobile/lib/providers/coach_profile_provider.dart",
        "apps/mobile/lib/providers/document_provider.dart",
        "apps/mobile/lib/providers/timeline_provider.dart",
        "apps/mobile/lib/screens/document_detail_screen.dart",
        "apps/mobile/lib/services/feature_flags.dart",
        "apps/mobile/lib/services/report_persistence_service.dart",
        "tools/simulator/maestro_env.sh",
        '[[ "$sha" == "$head_sha" ]]',
        "git -C \"$repo_root\" diff --quiet \"$sha\" --",
        "ls-files --others --exclude-standard -- apps/mobile",
        "runtime contract is not tracked by HEAD",
        "source-manifest.sha256",
    ):
        assert anchor in source, anchor
    for forbidden in (
        "g1_bnd03",
        "budget_",
        "g1_prov02",
        "g1_prov03",
    ):
        assert forbidden not in source, forbidden


def test_orchestrator_proves_real_process_death_and_production_restore() -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        '"$patrol_bin" --verbose build ios',
        "--dart-define=MINT_PATROL_CLI=true",
        "xcodebuild test-without-building",
        'xcrun simctl launch "$device" "$bundle_id"',
        'xcrun simctl terminate "$device" "$bundle_id"',
        "reset_between_patrol_stages=true",
        "git -C \"$repo_root\" archive --format=tar",
        "production_source_exported_exact=true",
        "production_source_physical=true",
        "stat.S_ISLNK",
        "entry_status.st_nlink > 1",
        "flutter build ios --simulator --debug --target lib/main.dart",
        "codesign --verify --strict --deep",
        'xattr -r "$production_app"',
        "com.apple.FinderInfo",
        "com.apple.ResourceFork",
        'xcrun simctl install "$device" "$production_app"',
        '"${maestro_command[@]}" test --udid "$device"',
        "maestro-report.sanitized.xml",
        "runtime_completed=true",
    ):
        assert anchor in source, anchor


def test_orchestrator_sanitizes_every_retained_artifact() -> None:
    source = ORCHESTRATOR.read_text(encoding="utf-8")
    for anchor in (
        "device.sha256",
        "REDACTED_REPO",
        "REDACTED_HOME",
        "REDACTED_SIMULATOR_UDID",
        "REDACTED_EXTERNAL_BUILD",
        "REDACTED_PRIVATE_TEMP",
        'rm -f -- "$raw"',
        "raw Maestro report removal failed",
        "external build removal failed",
        "Patrol bundle cleanup failed",
        '"contract": "g1_bnd05_document_reference"',
        '"synthetic_data_only": True',
        '"private_fixture_used": False',
        '"write_build_exit_code"',
        '"write_exit_code"',
        '"launch_exit_code"',
        '"terminate_exit_code"',
        '"read_build_exit_code"',
        '"read_exit_code"',
        '"production_export_exit_code"',
        '"production_extract_exit_code"',
        '"production_build_exit_code"',
        '"production_codesign_verify_exit_code"',
        '"production_xattr_inspect_exit_code"',
        '"production_install_exit_code"',
        '"maestro_exit_code"',
    ):
        assert anchor in source, anchor


def test_runtime_contracts_are_synthetic_and_use_production_wiring() -> None:
    writer = WRITER.read_text(encoding="utf-8")
    reader = READER.read_text(encoding="utf-8")
    assert "const MintApp()" in writer
    assert "const MintApp()" in reader
    for source in (writer, reader):
        for anchor in (
            "CoachProfileProvider",
            "DocumentProvider",
            "TimelineProvider",
            "document_reference_remove",
            "DocumentReferenceStore.storageKey",
        ):
            assert anchor in source, anchor
        for forbidden in (
            "MINT_LPP_PRIVATE_MANIFEST",
            "/Users/",
        ):
            assert forbidden not in source, forbidden
    assert "acceptLppReview(" in writer
    assert "recordConfirmedLppReview(receipt)" in writer
    assert "acceptLppReview(" not in reader
    assert "recordConfirmedLppReview(" not in reader
    assert "deleteConfirmedReference" not in writer
    assert "strictRootBeforeDelete" in reader
    assert "ledger.reportAnswersSnapshot['_coach_lpp_evidence_v1']" in reader
    assert "_rawMarker" in writer
    assert "synthetic runtime bytes only" in writer
    assert WRITE_WRAPPER.read_text(encoding="utf-8").count("write_patrol_test.dart") == 1
    assert READ_WRAPPER.read_text(encoding="utf-8").count("read_patrol_test.dart") == 1


def test_maestro_flow_is_fail_closed_and_synthetic() -> None:
    contents = FLOW.read_text(encoding="utf-8")
    header, body = contents.split("---", 1)
    assert yaml.safe_load(header) == {
        "appId": "ch.mint.app",
        "name": "G1 BND-05 production-default document reference fail-closed",
    }
    steps = yaml.safe_load(body)
    assert isinstance(steps, list)
    for anchor in (
        "clearState: true",
        "mint:///scan?type=lppCertificate",
        "document_scan_lpp_type_selector",
        "mint:///documents/45454545-4545-4545-8545-454545454545",
        "document_reference_missing_state",
        "document_reference_back_to_documents",
        "document_reference_remove",
        "CHF 143'287",
    ):
        assert anchor in contents, anchor
    assert "/Users/" not in contents
    assert "MINT_LPP_PRIVATE_MANIFEST" not in contents

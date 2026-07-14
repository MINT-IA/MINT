from __future__ import annotations

import json
import os
import re
import stat
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
MAESTRO_FLOW = ROOT / "apps/mobile/.maestro/g1_prov03_tax_flag_off.yaml"
WRITE_CONTRACT = (
    ROOT
    / "apps/mobile/integration_test/g1_prov03_tax_persistence_write_patrol_test.dart"
)
READ_CONTRACT = (
    ROOT
    / "apps/mobile/integration_test/g1_prov03_tax_persistence_read_patrol_test.dart"
)
WRITE_RUNNER = (
    ROOT / "apps/mobile/test/patrol/g1_prov03_tax_persistence_write_runtime_test.dart"
)
READ_RUNNER = (
    ROOT / "apps/mobile/test/patrol/g1_prov03_tax_persistence_read_runtime_test.dart"
)
ORCHESTRATOR = ROOT / "tools/simulator/patrol_tax_provenance_process_death.sh"
FEATURE_FLAGS = ROOT / "apps/mobile/lib/services/feature_flags.dart"
SCAN_SCREEN = ROOT / "apps/mobile/lib/screens/document_scan/document_scan_screen.dart"
EXTRACTION_REVIEW_SCREEN = (
    ROOT / "apps/mobile/lib/screens/document_scan/extraction_review_screen.dart"
)

SYNTHETIC_UDID = "B03E429D-0422-4357-B754-536637D979F9"
SYNTHETIC_SHA = "1" * 40
BUNDLE_ID = "ch.mint.app"


def _maestro_ids_for_action(source: str, action: str) -> set[str]:
    lines = source.splitlines()
    identifiers: set[str] = set()
    marker = f"- {action}:"
    for index, line in enumerate(lines):
        if line.strip() != marker:
            continue
        for child in lines[index + 1 :]:
            if child.startswith("- "):
                break
            stripped = child.strip()
            if stripped.startswith("id:"):
                identifiers.add(stripped.removeprefix("id:").strip().strip('"'))
                break
    return identifiers


def _semantic_scroll_tap_identifiers(source: str) -> list[str]:
    return re.findall(
        r"\$\(\s*find\.bySemanticsIdentifier\(\s*'([^']+)'\s*,?\s*\)"
        r"\s*\)\.scrollTo\(\)\.tap\(\);",
        source,
    )


def _write_executable(path: Path, source: str) -> None:
    path.write_text(source, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _fake_runtime(
    tmp_path: Path,
    *,
    write_exit: int = 0,
    launch_exit: int = 0,
    terminate_exit: int = 0,
    read_exit: int = 0,
) -> dict[str, str]:
    tmp_path.mkdir(parents=True, exist_ok=True)
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    calls = tmp_path / "calls.log"
    fake_git = fake_bin / "git"
    fake_patrol = fake_bin / "patrol"
    fake_xcrun = fake_bin / "xcrun"

    _write_executable(
        fake_git,
        "#!/usr/bin/env bash\n"
        'printf \'git %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "$*" == *"--show-toplevel"* ]]; then\n'
        "  printf '%s\\n' \"$MINT_TEST_REPO_ROOT\"\n"
        "  exit 0\n"
        "fi\n"
        'if [[ "$*" == *"rev-parse HEAD"* ]]; then\n'
        "  printf '%s\\n' \"$MINT_TEST_HEAD_SHA\"\n"
        "  exit 0\n"
        "fi\n"
        'if [[ "$*" == *"ls-files --error-unmatch"* ]]; then exit 0; fi\n'
        'if [[ "$*" == *"ls-files --others"* ]]; then exit 0; fi\n'
        'if [[ "$*" == *"diff --quiet HEAD"* ]]; then exit 0; fi\n'
        "exit 91\n",
    )
    _write_executable(
        fake_patrol,
        "#!/usr/bin/env bash\n"
        'printf \'patrol %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "$*" == *"g1_prov03_tax_persistence_write"* ]]; then\n'
        f"  exit {write_exit}\n"
        "fi\n"
        f"exit {read_exit}\n",
    )
    _write_executable(
        fake_xcrun,
        "#!/usr/bin/env bash\n"
        'printf \'xcrun %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        f'if [[ "${{2:-}}" == "launch" ]]; then exit {launch_exit}; fi\n'
        f'if [[ "${{2:-}}" == "terminate" ]]; then exit {terminate_exit}; fi\n'
        "exit 92\n",
    )
    return {
        **os.environ,
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "PATROL_BIN": str(fake_patrol),
        "MINT_TEST_CALLS": str(calls),
        "MINT_TEST_REPO_ROOT": str(ROOT),
        "MINT_TEST_HEAD_SHA": SYNTHETIC_SHA,
    }


def _run_orchestrator(
    tmp_path: Path,
    env: dict[str, str],
    *,
    sha: str = SYNTHETIC_SHA,
    include_device: bool = True,
) -> subprocess.CompletedProcess[str]:
    command = ["bash", str(ORCHESTRATOR)]
    if include_device:
        command.extend(["--device", SYNTHETIC_UDID])
    command.extend(
        [
            "--bundle-id",
            BUNDLE_ID,
            "--sha",
            sha,
            "--artifacts",
            str(tmp_path / "artifacts"),
        ]
    )
    return subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_tax_runtime_contracts_use_real_specific_seams() -> None:
    maestro = MAESTRO_FLOW.read_text(encoding="utf-8")
    writer = WRITE_CONTRACT.read_text(encoding="utf-8")
    reader = READ_CONTRACT.read_text(encoding="utf-8")
    write_runner = WRITE_RUNNER.read_text(encoding="utf-8")
    read_runner = READ_RUNNER.read_text(encoding="utf-8")
    orchestrator = ORCHESTRATOR.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    scan_screen = SCAN_SCREEN.read_text(encoding="utf-8")
    extraction_review_screen = EXTRACTION_REVIEW_SCREEN.read_text(encoding="utf-8")

    assert "static bool typedTaxProfile = false;" in feature_flags
    assert "static bool documentTaxAssessmentEnabled = false;" in feature_flags
    assert "documentTaxAssessmentEnabled && typedTaxProfile" in feature_flags
    assert "document_scan_tax_type_selector" in scan_screen

    assert "appId: ch.mint.app" in maestro
    assert "clearState: true" in maestro
    assert 'openLink: "mint:///scan?type=taxDeclaration"' in maestro
    visible_ids = _maestro_ids_for_action(maestro, "assertVisible")
    hidden_ids = _maestro_ids_for_action(maestro, "assertNotVisible")
    tapped_ids = _maestro_ids_for_action(maestro, "tapOn")
    tax_acquisition_ids = {
        "document_scan_tax_type_selector",
        "document_scan_tax_example_cta",
        "document_scan_tax_local_text_cta",
    }
    assert "document_scan_capture_cta" in visible_ids
    assert tax_acquisition_ids <= hidden_ids
    assert "tax_review_confirm_cta" in hidden_ids
    assert tax_acquisition_ids.isdisjoint(visible_ids)
    assert tax_acquisition_ids.isdisjoint(tapped_ids)
    assert "tax_review_confirm_cta" not in tapped_ids
    assert "text:" not in maestro
    assert "point:" not in maestro

    assert "patrolTest(" in writer
    assert "MINT_PATROL_CLI" in writer
    assert "FeatureFlags.typedTaxProfile = true;" in writer
    assert "FeatureFlags.documentTaxAssessmentEnabled = true;" in writer
    assert "FeatureFlags.typedTaxProfile = false;" in writer
    assert "FeatureFlags.documentTaxAssessmentEnabled = false;" in writer
    assert "ReportPersistenceService.clearDiagnostic()" in writer
    assert "ReportPersistenceService.setMiniOnboardingCompleted(true)" in writer
    assert "pumpWidgetAndSettle(const MintApp())" in writer
    assert "mobile.openUrl('mint:///scan')" in writer
    keyed_controls = (
        "document_scan_tax_type_selector",
        "document_scan_tax_example_cta",
        "tax_review_subject_scope",
        "tax_review_source_date",
        "tax_review_canton_code",
        "tax_review_cantonal_communal_taxable_income_chf",
        "tax_review_federal_taxable_income_chf",
        "tax_review_cantonal_communal_taxable_wealth_chf",
        "tax_review_cantonal_base_scope",
        "tax_review_federal_base_scope",
        "tax_review_confirm_cta",
    )
    for identifier in keyed_controls:
        assert f"#{identifier}" in writer

    runtime_option_identifiers = [
        "tax_review_subject_scope_individual",
        "tax_review_cantonal_base_scope_income_and_wealth",
        "tax_review_federal_base_scope_income_only",
    ]
    assert _semantic_scroll_tap_identifiers(writer) == runtime_option_identifiers
    for identifier in runtime_option_identifiers:
        assert f"$(#{identifier})" not in writer

    assert "final optionKey = '${controlKey}_${_enumSnakeCase(option.name)}';" in (
        extraction_review_screen
    )
    assert re.search(
        r"DropdownMenuItem<T>\(\s*"
        r"key: Key\(optionKey\),\s*"
        r"value: option,\s*"
        r"child: Semantics\(\s*"
        r"identifier: optionKey,\s*"
        r"child: Text\(optionLabel\),",
        extraction_review_screen,
    )
    assert "tax_review_back_cta).waitUntilVisible" in writer
    assert "tax_review_confirm_cta).waitUntilVisible" not in writer
    assert "tax_review_confirm_cta).scrollTo().tap()" in writer
    assert "find.bySemanticsIdentifier('document_impact_return_cta')" in writer
    for bypass in (
        "acceptTaxReview(",
        "saveAnswers(",
        "FiscalSnapshotSelector.selectAssessedBaseline(",
    ):
        assert bypass not in writer
    assert "PII-NEVER" not in writer

    assert "patrolTest(" in reader
    assert "MINT_PATROL_CLI" in reader
    assert "FeatureFlags.typedTaxProfile = true;" in reader
    assert "FeatureFlags.documentTaxAssessmentEnabled = true;" in reader
    assert "FeatureFlags.typedTaxProfile = false;" in reader
    assert "FeatureFlags.documentTaxAssessmentEnabled = false;" in reader
    assert "pumpWidgetAndSettle(const MintApp())" in reader
    assert "waitForReportAnswers()" in reader
    assert "FiscalSnapshotSelector.selectAssessedBaseline(" in reader
    assert "FiscalSnapshotQuery.precise(" in reader
    assert "TaxSnapshotField.cantonalCommunalTaxableIncomeChf" in reader
    assert "TaxSnapshotField.cantonalCommunalAssessedTax" in reader
    assert "TaxSnapshotField.federalDirectAssessedTax" in reader
    assert "TaxAuthorityScope.cantonalCommunalCombined" in reader
    assert "TaxAuthorityScope.federalDirect" in reader
    assert "TaxBaseScope.incomeAndWealth" in reader
    assert "TaxBaseScope.incomeOnly" in reader
    assert "ProfileDataSource.certificate" in reader
    assert "ConfidenceScorer.score(profile)" in reader
    assert "fiscal.assessedBaseline" in reader
    for bypass in (
        "ReportPersistenceService",
        "acceptTaxReview(",
        "saveAnswers(",
        "enterText(",
    ):
        assert bypass not in reader
    assert "PII-NEVER" not in reader

    assert (
        "../../integration_test/"
        "g1_prov03_tax_persistence_write_patrol_test.dart" in write_runner
    )
    assert "tax_persistence_write.main();" in write_runner
    assert (
        "../../integration_test/"
        "g1_prov03_tax_persistence_read_patrol_test.dart" in read_runner
    )
    assert "tax_persistence_read.main();" in read_runner

    assert "set -euo pipefail" in orchestrator
    assert "$HOME/.pub-cache/bin/patrol" in orchestrator
    assert "g1_prov03_tax_persistence_write_patrol_test.dart" in orchestrator
    assert "g1_prov03_tax_persistence_read_patrol_test.dart" in orchestrator
    assert "g1_prov03_tax_persistence_write_runtime_test.dart" in orchestrator
    assert "g1_prov03_tax_persistence_read_runtime_test.dart" in orchestrator
    assert orchestrator.count("--no-uninstall") == 2
    assert orchestrator.count('xcrun simctl launch "$device" "$bundle_id"') == 1
    assert orchestrator.count('xcrun simctl terminate "$device" "$bundle_id"') == 1
    assert "rev-parse HEAD" in orchestrator
    assert "ls-files --error-unmatch" in orchestrator
    assert "ls-files --others --exclude-standard" in orchestrator
    assert "diff --quiet HEAD" in orchestrator
    assert "metadata.json" in orchestrator
    assert '"contract": "g1_prov03_tax"' in orchestrator
    assert '"synthetic_data_only": True' in orchestrator


def test_tax_orchestrator_runs_write_process_death_read_and_metadata(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path)

    result = _run_orchestrator(tmp_path, env)

    assert result.returncode == 0, result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8").splitlines()
    runtime_calls = [line for line in calls if not line.startswith("git ")]
    assert len(runtime_calls) == 4
    assert "g1_prov03_tax_persistence_write_runtime_test.dart" in runtime_calls[0]
    assert "--no-uninstall" in runtime_calls[0]
    assert f"--device {SYNTHETIC_UDID}" in runtime_calls[0]
    assert runtime_calls[1] == (f"xcrun simctl launch {SYNTHETIC_UDID} {BUNDLE_ID}")
    assert runtime_calls[2] == (f"xcrun simctl terminate {SYNTHETIC_UDID} {BUNDLE_ID}")
    assert "g1_prov03_tax_persistence_read_runtime_test.dart" in runtime_calls[3]
    assert "--no-uninstall" in runtime_calls[3]

    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["contract"] == "g1_prov03_tax"
    assert metadata["device"] == SYNTHETIC_UDID
    assert metadata["bundle_id"] == BUNDLE_ID
    assert metadata["sha"] == SYNTHETIC_SHA
    assert metadata["write_exit_code"] == 0
    assert metadata["launch_exit_code"] == 0
    assert metadata["terminate_exit_code"] == 0
    assert metadata["read_exit_code"] == 0
    assert metadata["synthetic_data_only"] is True
    assert metadata["feature_activation"] == "test_process_static_flags_only"


@pytest.mark.parametrize(
    ("runtime", "expected", "forbidden_call"),
    [
        ({"write_exit": 7}, "write stage failed", "xcrun simctl launch"),
        ({"launch_exit": 8}, "launch stage failed", "xcrun simctl terminate"),
        (
            {"terminate_exit": 9},
            "terminate stage failed",
            "g1_prov03_tax_persistence_read",
        ),
        ({"read_exit": 10}, "read stage failed", "PASS device="),
    ],
)
def test_tax_orchestrator_fails_closed(
    tmp_path: Path,
    runtime: dict[str, int],
    expected: str,
    forbidden_call: str,
) -> None:
    env = _fake_runtime(tmp_path, **runtime)

    result = _run_orchestrator(tmp_path, env)

    assert result.returncode != 0
    assert expected in result.stderr
    runtime_calls = [
        line
        for line in (tmp_path / "calls.log").read_text(encoding="utf-8").splitlines()
        if not line.startswith("git ")
    ]
    combined = "\n".join(runtime_calls) + result.stdout + result.stderr
    assert forbidden_call not in combined


def test_tax_orchestrator_rejects_missing_device_and_sha_drift(
    tmp_path: Path,
) -> None:
    missing_env = _fake_runtime(tmp_path / "missing")
    missing_device = _run_orchestrator(
        tmp_path / "missing",
        missing_env,
        include_device=False,
    )

    drift_env = _fake_runtime(tmp_path / "drift")
    wrong_sha = _run_orchestrator(
        tmp_path / "drift",
        drift_env,
        sha="a" * 40,
    )

    assert missing_device.returncode != 0
    assert "--device is required" in missing_device.stderr
    assert wrong_sha.returncode != 0
    assert "must equal current HEAD" in wrong_sha.stderr

from __future__ import annotations

import json
import os
import re
import shutil
import signal
import stat
import subprocess
import time
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
        r"\s*\)\s*\.scrollTo\(\)\s*\.tap\(\);",
        source,
    )


def _write_executable(path: Path, source: str) -> None:
    path.write_text(source, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _fake_runtime(
    tmp_path: Path,
    *,
    write_build_exit: int = 0,
    read_build_exit: int = 0,
    write_exit: int = 0,
    bootstatus_exit: int = 0,
    launch_exit: int = 0,
    terminate_exit: int = 0,
    read_exit: int = 0,
    codesign_exit: int = 0,
    entitlement_app_id: str = "7F5UDGYS5H.ch.mint.app",
    entitlement_group: str = "7F5UDGYS5H.ch.mint.app",
    xattr_output: str = "",
    xattr_exit: int = 0,
    omit_der_section: bool = False,
    omit_asset_stage: str = "",
    skip_xcresult_stage: str = "",
    patrol_sleep: int = 0,
) -> dict[str, str]:
    tmp_path.mkdir(parents=True, exist_ok=True)
    repo_root = tmp_path / "repo"
    mobile_root = repo_root / "apps/mobile"
    for relative in (
        "integration_test/g1_prov03_tax_persistence_write_patrol_test.dart",
        "integration_test/g1_prov03_tax_persistence_read_patrol_test.dart",
        "test/patrol/g1_prov03_tax_persistence_write_runtime_test.dart",
        "test/patrol/g1_prov03_tax_persistence_read_runtime_test.dart",
    ):
        contract = mobile_root / relative
        contract.parent.mkdir(parents=True, exist_ok=True)
        contract.write_text("// tracked fake runtime contract\n", encoding="utf-8")
    original_build = mobile_root / "build"
    original_build.mkdir(parents=True)
    (original_build / "original-build-marker.txt").write_text(
        "must survive every exit path\n",
        encoding="utf-8",
    )
    (mobile_root / ".dart_tool").mkdir()

    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    calls = tmp_path / "calls.log"
    fake_git = fake_bin / "git"
    fake_patrol = fake_bin / "patrol"
    fake_xcrun = fake_bin / "xcrun"
    fake_xcodebuild = fake_bin / "xcodebuild"
    fake_codesign = fake_bin / "codesign"
    fake_xattr = fake_bin / "xattr"

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
        "set -euo pipefail\n"
        'printf \'patrol cwd=%s build=%s args=%s\\n\' "$PWD" "$(readlink build 2>/dev/null || true)" "$*" >> "$MINT_TEST_CALLS"\n'
        '[[ "${1:-}" == "build" && "${2:-}" == "ios" ]] || exit 93\n'
        '[[ -L build ]] || exit 94\n'
        'if [[ "${MINT_TEST_PATROL_SLEEP:-0}" -gt 0 ]]; then sleep "$MINT_TEST_PATROL_SLEEP"; fi\n'
        'stage="read"\n'
        'if [[ "$*" == *"g1_prov03_tax_persistence_write"* ]]; then\n'
        '  stage="write"\n'
        "fi\n"
        'mkdir -p build/ios_integ/Build/Products/Debug-iphonesimulator/Runner.app\n'
        'python3 - build/ios_integ/Build/Products/Debug-iphonesimulator/Runner.app/Runner <<\'PY\'\n'
        'import os\n'
        'import plistlib\n'
        'import sys\n'
        'from pathlib import Path\n'
        'payload = {\n'
        '    "application-identifier": os.environ["MINT_TEST_ENTITLEMENT_APP_ID"],\n'
        '    "keychain-access-groups": [os.environ["MINT_TEST_ENTITLEMENT_GROUP"]],\n'
        '}\n'
        'xml = plistlib.dumps(payload, fmt=plistlib.FMT_XML, sort_keys=True)\n'
        'der = b"DER-SIMULATED-ENTITLEMENTS"\n'
        'content = bytearray(b"MACHO-FAKE".ljust(128, b"\\0"))\n'
        'content.extend(xml)\n'
        'content.extend(b"\\0" * (2048 - len(content)))\n'
        'if os.environ["MINT_TEST_OMIT_DER"] != "1":\n'
        '    content.extend(der)\n'
        'Path(sys.argv[1]).write_bytes(content)\n'
        'PY\n'
        'asset_dir="build/ios_integ/Build/Products/Debug-iphonesimulator/Runner.app/Frameworks/App.framework/flutter_assets"\n'
        'if [[ "$MINT_TEST_OMIT_ASSET_STAGE" != "$stage" ]]; then\n'
        '  mkdir -p "$asset_dir"\n'
        '  printf "fake asset manifest %s\\n" "$stage" > "$asset_dir/AssetManifest.bin"\n'
        'fi\n'
        'printf \'fake xctestrun %s\\n\' "$stage" > build/ios_integ/Build/Products/Runner_iphonesimulator26.2-arm64-x86_64.xctestrun\n'
        'if [[ "$stage" == "write" ]]; then exit "$MINT_TEST_WRITE_BUILD_EXIT"; fi\n'
        'exit "$MINT_TEST_READ_BUILD_EXIT"\n',
    )
    _write_executable(
        fake_codesign,
        "#!/usr/bin/env bash\n"
        'printf \'codesign %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'exit "$MINT_TEST_CODESIGN_EXIT"\n',
    )
    _write_executable(
        fake_xattr,
        "#!/usr/bin/env bash\n"
        'printf \'xattr %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'printf \'%s\' "${MINT_TEST_XATTR_OUTPUT:-}"\n'
        'exit "$MINT_TEST_XATTR_EXIT"\n',
    )
    _write_executable(
        fake_xcodebuild,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'xcodebuild %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'result=""\n'
        'previous=""\n'
        'for argument in "$@"; do\n'
        '  if [[ "$previous" == "-resultBundlePath" ]]; then result="$argument"; break; fi\n'
        '  previous="$argument"\n'
        'done\n'
        '[[ -n "$result" ]] || exit 96\n'
        'stage="read"\n'
        '[[ "$result" == *"write"* ]] && stage="write"\n'
        'if [[ "$MINT_TEST_SKIP_XCRESULT_STAGE" != "$stage" ]]; then\n'
        '  mkdir -p "$result/Data"\n'
        '  printf \'fake xcresult %s\\n\' "$stage" > "$result/Data/result.txt"\n'
        'fi\n'
        'if [[ "$stage" == "write" ]]; then exit "$MINT_TEST_WRITE_EXIT"; fi\n'
        'exit "$MINT_TEST_READ_EXIT"\n',
    )
    _write_executable(
        fake_xcrun,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'xcrun %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "${1:-}" == "lipo" ]]; then\n'
        '  input="${4:-}"\n'
        '  output="${6:-}"\n'
        '  cp "$input" "$output"\n'
        '  exit 0\n'
        'fi\n'
        'if [[ "${1:-}" == "otool" ]]; then\n'
        '  python3 - "${3:-}" <<\'PY\'\n'
        'import sys\n'
        'from pathlib import Path\n'
        'data = Path(sys.argv[1]).read_bytes()\n'
        'xml_offset = data.index(b"<?xml")\n'
        'xml_size = data.index(b"</plist>", xml_offset) + len(b"</plist>") - xml_offset\n'
        'print("Section")\n'
        'print("  sectname __entitlements")\n'
        'print("   segname __TEXT")\n'
        'print(f"      size 0x{xml_size:x}")\n'
        'print(f"    offset {xml_offset}")\n'
        'marker = b"DER-SIMULATED-ENTITLEMENTS"\n'
        'if marker in data:\n'
        '    der_offset = data.index(marker)\n'
        '    print("Section")\n'
        '    print("  sectname __ents_der")\n'
        '    print("   segname __TEXT")\n'
        '    print(f"      size 0x{len(marker):x}")\n'
        '    print(f"    offset {der_offset}")\n'
        'PY\n'
        '  exit 0\n'
        'fi\n'
        f'if [[ "${{2:-}}" == "bootstatus" ]]; then exit {bootstatus_exit}; fi\n'
        f'if [[ "${{2:-}}" == "launch" ]]; then exit {launch_exit}; fi\n'
        f'if [[ "${{2:-}}" == "terminate" ]]; then exit {terminate_exit}; fi\n'
        "exit 92\n",
    )
    return {
        **os.environ,
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "PATROL_BIN": str(fake_patrol),
        "MINT_TEST_CALLS": str(calls),
        "MINT_TEST_REPO_ROOT": str(repo_root),
        "MINT_TEST_HEAD_SHA": SYNTHETIC_SHA,
        "MINT_TEST_WRITE_BUILD_EXIT": str(write_build_exit),
        "MINT_TEST_READ_BUILD_EXIT": str(read_build_exit),
        "MINT_TEST_WRITE_EXIT": str(write_exit),
        "MINT_TEST_READ_EXIT": str(read_exit),
        "MINT_TEST_CODESIGN_EXIT": str(codesign_exit),
        "MINT_TEST_ENTITLEMENT_APP_ID": entitlement_app_id,
        "MINT_TEST_ENTITLEMENT_GROUP": entitlement_group,
        "MINT_TEST_XATTR_OUTPUT": xattr_output,
        "MINT_TEST_XATTR_EXIT": str(xattr_exit),
        "MINT_TEST_OMIT_DER": "1" if omit_der_section else "0",
        "MINT_TEST_OMIT_ASSET_STAGE": omit_asset_stage,
        "MINT_TEST_SKIP_XCRESULT_STAGE": skip_xcresult_stage,
        "MINT_TEST_PATROL_SLEEP": str(patrol_sleep),
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
        "tax_review_assessment_status",
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
        "tax_review_assessment_status_in_force",
        "tax_review_in_force_attested",
        "tax_review_cantonal_base_scope_income_and_wealth",
        "tax_review_federal_base_scope_income_only",
    ]
    assert _semantic_scroll_tap_identifiers(writer) == runtime_option_identifiers
    for identifier in runtime_option_identifiers:
        assert f"$(#{identifier})" not in writer

    assert "final optionKey = '${controlKey}_${_enumSnakeCase(option.name)}';" in (
        extraction_review_screen
    )
    assert "controlKey: 'tax_review_assessment_status'" in extraction_review_screen
    assert "value != TaxAssessmentStatus.inForce" in extraction_review_screen
    assert "key: const Key('tax_review_in_force_attested')" in (
        extraction_review_screen
    )
    assert "identifier: 'tax_review_in_force_attested'" in (
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
    assert re.search(
        r"document_impact_return_cta'\)\)\s*\.waitUntilExists\(\)",
        writer,
    )
    assert not re.search(
        r"document_impact_return_cta'\)\)\s*\.waitUntilVisible\(\)",
        writer,
    )
    for bypass in (
        "acceptTaxReview(",
        "saveAnswers(",
        "FiscalSnapshotSelector.selectAssessedBaseline(",
    ):
        assert bypass not in writer
    assert "PII-NEVER" not in writer
    assert "expect(snapshot.assessmentStatus, TaxAssessmentStatus.inForce);" in writer
    assert "expect(snapshot.inForceAttested, isTrue);" in writer

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
    assert "closeTo(0.325, 1e-12)" in reader
    assert "closeTo(0.1915, 1e-12)" in reader
    assert "expect(snapshot.explicitAverageIncomeTaxRate, 0.1915)" not in reader
    assert "ProfileDataSource.certificate" in reader
    assert "expect(snapshot.assessmentStatus, TaxAssessmentStatus.inForce);" in reader
    assert "expect(snapshot.inForceAttested, isTrue);" in reader
    assert "for (final leaf in const ['assessmentStatus', 'inForceAttested'])" in (
        reader
    )
    assert "ProfileDataSource.userInput" in reader
    exact_reference_assertions = (
        "final reference = profile.latestTaxDecisionReference;",
        "expect(reference, isNotNull);",
        "expect(reference!.referenceId, snapshot.snapshotId);",
        "expect(reference.kind, SpecialistReferenceKind.taxAssessmentDecision);",
        "expect(reference.taxYear, snapshot.taxYear);",
        "expect(reference.legalYear, snapshot.taxYear);",
        "expect(reference.sourceDate, snapshot.sourceDate);",
        "expect(reference.confirmedAt, snapshot.updatedAt.toUtc());",
    )
    for contract in (writer, reader):
        for assertion in exact_reference_assertions:
            assert assertion in contract
        assert re.search(
            r"expect\(\s*reference\.precisionReadyAt\(\s*"
            r"snapshot\.updatedAt,\s*taxSnapshot:\s*snapshot,\s*\),\s*"
            r"isTrue,\s*\);",
            contract,
        )
    assert re.search(
        r"final confidence = ConfidenceScorer\.score\(profile\);\s*"
        r"expect\(\s*confidence\.prompts\.where\(\s*"
        r"\(prompt\) => prompt\.fieldPath == 'fiscal\.assessedBaseline',\s*"
        r"\),\s*isEmpty,\s*\);",
        reader,
    )
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
    assert orchestrator.count('"$patrol_bin" build ios') == 2
    assert orchestrator.count("xcodebuild test-without-building") == 1
    assert orchestrator.count('-only-testing "RunnerUITests/RunnerUITests"') == 1
    assert orchestrator.count('run_xcode_test "write"') == 1
    assert orchestrator.count('run_xcode_test "read"') == 1
    assert orchestrator.count('xcrun simctl bootstatus "$device" -b') == 1
    assert orchestrator.count('xcrun simctl launch "$device" "$bundle_id"') == 1
    assert orchestrator.count('xcrun simctl terminate "$device" "$bundle_id"') == 1
    assert "rev-parse HEAD" in orchestrator
    assert "ls-files --error-unmatch" in orchestrator
    assert "ls-files --others --exclude-standard" in orchestrator
    assert "diff --quiet HEAD" in orchestrator
    assert 'mktemp -d "/tmp/mint-patrol-g1-prov03-' in orchestrator
    assert 'rm -rf -- "$external_build"' in orchestrator
    assert 'mv "$mobile_build" "$build_backup"' in orchestrator
    assert 'ln -s "$external_build" "$mobile_build"' in orchestrator
    assert "cp -R" not in orchestrator
    assert "trap 'exit 129' HUP" in orchestrator
    assert "trap 'exit 130' INT" in orchestrator
    assert "trap 'exit 143' TERM" in orchestrator
    assert "codesign --verify --strict --deep" in orchestrator
    assert "codesign --display --entitlements" not in orchestrator
    assert "xcrun lipo -thin" in orchestrator
    assert "xcrun otool -l" in orchestrator
    assert "__TEXT" in orchestrator
    assert "__entitlements" in orchestrator
    assert "__ents_der" in orchestrator
    assert "AssetManifest.bin" in orchestrator
    assert "application-identifier" in orchestrator
    assert "keychain-access-groups" in orchestrator
    assert "com.apple.FinderInfo" in orchestrator
    assert "com.apple.ResourceFork" in orchestrator
    assert "metadata.json" in orchestrator
    assert '"boot_status_command"' in orchestrator
    assert '"boot_status_exit_code"' in orchestrator
    assert '"boot_status_log"' in orchestrator
    assert '"contract": "g1_prov03_tax"' in orchestrator
    assert '"synthetic_data_only": True' in orchestrator


def test_tax_orchestrator_runs_write_process_death_read_and_metadata(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path)
    repo_root = Path(env["MINT_TEST_REPO_ROOT"])
    mobile_build = repo_root / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run_orchestrator(tmp_path, env)

    assert result.returncode == 0, result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8").splitlines()
    runtime_calls = [line for line in calls if not line.startswith("git ")]
    patrol_calls = [line for line in runtime_calls if line.startswith("patrol ")]
    codesign_calls = [line for line in runtime_calls if line.startswith("codesign ")]
    xattr_calls = [line for line in runtime_calls if line.startswith("xattr ")]
    xcodebuild_calls = [line for line in runtime_calls if line.startswith("xcodebuild ")]
    xcrun_calls = [line for line in runtime_calls if line.startswith("xcrun ")]
    assert len(patrol_calls) == 2
    assert "build ios" in patrol_calls[0]
    assert "g1_prov03_tax_persistence_write_runtime_test.dart" in patrol_calls[0]
    assert "build ios" in patrol_calls[1]
    assert "g1_prov03_tax_persistence_read_runtime_test.dart" in patrol_calls[1]
    external_targets = {call.split(" build=", 1)[1].split(" args=", 1)[0] for call in patrol_calls}
    assert len(external_targets) == 1
    external_target = Path(external_targets.pop())
    assert external_target.as_posix().startswith("/private/tmp/") or external_target.as_posix().startswith("/tmp/")
    assert len(codesign_calls) == 2
    assert all("--verify --strict --deep" in call for call in codesign_calls)
    assert len(xattr_calls) == 2
    assert len(xcodebuild_calls) == 2
    assert all("test-without-building" in call for call in xcodebuild_calls)
    assert all(
        "-only-testing RunnerUITests/RunnerUITests" in call
        for call in xcodebuild_calls
    )
    assert all(f"platform=iOS Simulator,id={SYNTHETIC_UDID}" in call for call in xcodebuild_calls)
    simctl_calls = [line for line in xcrun_calls if " simctl " in line]
    assert sum("lipo -thin" in line for line in xcrun_calls) == 2
    assert sum("otool -l" in line for line in xcrun_calls) == 2
    assert simctl_calls == [
        f"xcrun simctl bootstatus {SYNTHETIC_UDID} -b",
        f"xcrun simctl launch {SYNTHETIC_UDID} {BUNDLE_ID}",
        f"xcrun simctl terminate {SYNTHETIC_UDID} {BUNDLE_ID}",
    ]

    assert mobile_build.is_dir()
    assert not mobile_build.is_symlink()
    assert mobile_build.stat().st_ino == original_inode
    assert (mobile_build / "original-build-marker.txt").read_text(encoding="utf-8") == (
        "must survive every exit path\n"
    )
    assert not external_target.exists()

    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["contract"] == "g1_prov03_tax"
    assert metadata["device"] == SYNTHETIC_UDID
    assert metadata["bundle_id"] == BUNDLE_ID
    assert metadata["sha"] == SYNTHETIC_SHA
    assert metadata["write_exit_code"] == 0
    assert metadata["boot_status_exit_code"] == 0
    assert metadata["boot_status_command"] == (
        f"xcrun simctl bootstatus {SYNTHETIC_UDID} -b"
    )
    assert Path(metadata["boot_status_log"]) == tmp_path / "artifacts/bootstatus.log"
    assert Path(metadata["boot_status_log"]).is_file()
    assert metadata["launch_exit_code"] == 0
    assert metadata["terminate_exit_code"] == 0
    assert metadata["read_exit_code"] == 0
    assert metadata["synthetic_data_only"] is True
    assert metadata["feature_activation"] == "test_process_static_flags_only"
    assert metadata["external_build"]["enabled"] is True
    assert metadata["external_build"]["original_build_present"] is True
    assert metadata["external_build"]["restoration_status"] == "restored"
    assert metadata["external_build"]["path"] == str(external_target)
    assert not Path(metadata["external_build"]["backup_path"]).exists()
    for stage in ("write", "read"):
        evidence = metadata["xcresults"][stage]
        result_path = Path(evidence["path"])
        assert result_path.is_dir()
        assert result_path.parent == tmp_path / "artifacts"
        assert re.fullmatch(r"[0-9a-f]{64}", evidence["sha256"])
        assert Path(evidence["manifest_path"]).is_file()
        sections = metadata["mach_o_sections"][stage]
        assert re.fullmatch(r"[0-9a-f]{64}", sections["entitlements_sha256"])
        assert re.fullmatch(r"[0-9a-f]{64}", sections["der_sha256"])
        assert Path(sections["entitlements_path"]).is_file()
        assert Path(sections["der_path"]).is_file()
        assert (
            tmp_path / "artifacts" / f"{stage}-Runner-MachO-entitlements.plist"
        ).is_file()
        assert (tmp_path / "artifacts" / f"{stage}-Runner-MachO-ents.der").is_file()
        assert (tmp_path / "artifacts" / f"{stage}-AssetManifest.bin").is_file()
        assert (tmp_path / "artifacts" / f"{stage}-AssetManifest.sha256").is_file()
        assert (tmp_path / "artifacts" / f"{stage}-Runner.xctestrun").is_file()


@pytest.mark.parametrize(
    ("runtime", "expected", "forbidden_call"),
    [
        ({"write_build_exit": 6}, "write build stage failed", "codesign --verify"),
        ({"write_exit": 7}, "write test stage failed", "xcrun simctl launch"),
        ({"bootstatus_exit": 12}, "bootstatus stage failed", "xcrun simctl launch"),
        ({"launch_exit": 8}, "launch stage failed", "xcrun simctl terminate"),
        (
            {"terminate_exit": 9},
            "terminate stage failed",
            "g1_prov03_tax_persistence_read_runtime_test.dart",
        ),
        ({"read_exit": 10}, "read test stage failed", "PASS device="),
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
    mobile_build = Path(env["MINT_TEST_REPO_ROOT"]) / "apps/mobile/build"
    assert mobile_build.is_dir()
    assert not mobile_build.is_symlink()
    assert (mobile_build / "original-build-marker.txt").is_file()


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


@pytest.mark.parametrize(
    ("runtime", "expected"),
    [
        ({"codesign_exit": 11}, "codesign verification failed"),
        (
            {"entitlement_app_id": "WRONG.ch.mint.app"},
            "application-identifier mismatch",
        ),
        (
            {"entitlement_group": "WRONG.ch.mint.app"},
            "keychain-access-groups mismatch",
        ),
        (
            {
                "xattr_output": (
                    "Runner.app: com.apple.FinderInfo:\\n"
                    "Runner.app/file: com.apple.ResourceFork:\\n"
                )
            },
            "forbidden extended attribute",
        ),
        ({"xattr_exit": 12}, "xattr inspection failed"),
        ({"omit_der_section": True}, "missing __TEXT,__ents_der section"),
    ],
)
def test_tax_orchestrator_rejects_unsigned_or_tainted_runner_before_install(
    tmp_path: Path,
    runtime: dict[str, object],
    expected: str,
) -> None:
    env = _fake_runtime(tmp_path, **runtime)

    result = _run_orchestrator(tmp_path, env)

    assert result.returncode != 0
    assert expected in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert "xcodebuild test-without-building" not in calls
    mobile_build = Path(env["MINT_TEST_REPO_ROOT"]) / "apps/mobile/build"
    assert mobile_build.is_dir()
    assert not mobile_build.is_symlink()
    assert (mobile_build / "original-build-marker.txt").is_file()


def test_tax_orchestrator_rejects_missing_read_assets_before_read_install(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, omit_asset_stage="read")

    result = _run_orchestrator(tmp_path, env)

    assert result.returncode != 0
    assert "read AssetManifest.bin is missing or empty" in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert calls.count("xcodebuild test-without-building") == 1
    mobile_build = Path(env["MINT_TEST_REPO_ROOT"]) / "apps/mobile/build"
    assert mobile_build.is_dir()
    assert not mobile_build.is_symlink()
    assert (mobile_build / "original-build-marker.txt").is_file()


def test_tax_orchestrator_rejects_preexisting_build_symlink_and_backup_collision(
    tmp_path: Path,
) -> None:
    symlink_env = _fake_runtime(tmp_path / "symlink")
    symlink_repo = Path(symlink_env["MINT_TEST_REPO_ROOT"])
    symlink_build = symlink_repo / "apps/mobile/build"
    shutil.rmtree(symlink_build)
    external = tmp_path / "foreign-build"
    external.mkdir()
    symlink_build.symlink_to(external, target_is_directory=True)

    symlink_result = _run_orchestrator(tmp_path / "symlink", symlink_env)

    assert symlink_result.returncode != 0
    assert "pre-existing build symlink" in symlink_result.stderr
    assert symlink_build.is_symlink()
    assert symlink_build.resolve() == external.resolve()

    collision_env = _fake_runtime(tmp_path / "collision")
    collision_repo = Path(collision_env["MINT_TEST_REPO_ROOT"])
    collision_build = collision_repo / "apps/mobile/build"
    backup = (
        collision_repo
        / "apps/mobile/.dart_tool"
        / f"mint-patrol-g1-prov03-build-backup-{SYNTHETIC_SHA}"
    )
    backup.mkdir()
    (backup / "stale-backup-marker.txt").write_text("preserve\n", encoding="utf-8")

    collision_result = _run_orchestrator(tmp_path / "collision", collision_env)

    assert collision_result.returncode != 0
    assert "backup collision" in collision_result.stderr
    assert collision_build.is_dir()
    assert (collision_build / "original-build-marker.txt").is_file()
    assert (backup / "stale-backup-marker.txt").is_file()
    assert "patrol " not in (tmp_path / "collision/calls.log").read_text(
        encoding="utf-8"
    )


def test_tax_orchestrator_requires_each_xcresult_and_restores_original_build(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, skip_xcresult_stage="write")

    result = _run_orchestrator(tmp_path, env)

    assert result.returncode != 0
    assert "write xcresult is missing" in result.stderr
    mobile_build = Path(env["MINT_TEST_REPO_ROOT"]) / "apps/mobile/build"
    assert mobile_build.is_dir()
    assert not mobile_build.is_symlink()
    assert (mobile_build / "original-build-marker.txt").is_file()


def test_tax_orchestrator_restores_original_build_on_term_signal(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, patrol_sleep=30)
    repo_root = Path(env["MINT_TEST_REPO_ROOT"])
    mobile_build = repo_root / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    command = [
        "bash",
        str(ORCHESTRATOR),
        "--device",
        SYNTHETIC_UDID,
        "--bundle-id",
        BUNDLE_ID,
        "--sha",
        SYNTHETIC_SHA,
        "--artifacts",
        str(tmp_path / "artifacts"),
    ]
    process = subprocess.Popen(
        command,
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline and not mobile_build.is_symlink():
        if process.poll() is not None:
            break
        time.sleep(0.05)
    assert mobile_build.is_symlink(), process.communicate(timeout=2)

    os.killpg(process.pid, signal.SIGTERM)
    stdout, stderr = process.communicate(timeout=10)

    assert process.returncode != 0, stdout + stderr
    assert mobile_build.is_dir()
    assert not mobile_build.is_symlink()
    assert mobile_build.stat().st_ino == original_inode
    assert (mobile_build / "original-build-marker.txt").is_file()
    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["external_build"]["restoration_status"] == "restored"

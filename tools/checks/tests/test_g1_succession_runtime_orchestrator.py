from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "tools/simulator/patrol_succession_evidence_process_death.sh"
MOBILE = ROOT / "apps/mobile"


def source() -> str:
    return RUNNER.read_text(encoding="utf-8")


def test_runner_is_valid_strict_bash() -> None:
    result = subprocess.run(
        ["bash", "-n", str(RUNNER)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    assert source().startswith("#!/usr/bin/env bash\nset -euo pipefail\n")


def test_runner_binds_every_tracked_runtime_contract_to_exact_pushed_head() -> None:
    text = source()
    for path in (
        "apps/mobile/integration_test/g1_succession_native_present_patrol_test.dart",
        "apps/mobile/integration_test/g1_succession_absent_write_patrol_test.dart",
        "apps/mobile/integration_test/g1_succession_cold_read_patrol_test.dart",
        "apps/mobile/test/patrol/g1_succession_native_present_runtime_test.dart",
        "apps/mobile/test/patrol/g1_succession_absent_write_runtime_test.dart",
        "apps/mobile/test/patrol/g1_succession_cold_read_runtime_test.dart",
        "apps/mobile/integration_test/support/g1_succession_runtime_contract.dart",
        "apps/mobile/.maestro/g1_succession_flag_off.yaml",
        "apps/mobile/.maestro/g1_succession_progressive.yaml",
        "tools/simulator/patrol_succession_evidence_process_death.sh",
    ):
        assert f'"{path}"' in text
    assert "git -C \"$repo_root\" ls-files --error-unmatch" in text
    assert '[[ "$sha" == "$head_sha" ]]' in text
    assert "merge-base --is-ancestor \"$sha\" \"$upstream_ref\"" in text
    assert "git -C \"$repo_root\" diff --quiet \"$sha\" --" in text
    assert "ls-files --others --exclude-standard -- apps/mobile tools/simulator" in text
    assert "source-manifest.sha256" in text


def test_runner_uses_three_isolated_patrol_stages_and_real_process_death() -> None:
    text = source()
    assert "verify_patrol_contracts" in text
    assert "absent writer must stop at the durable acknowledgement before process death" in text
    for stage in ("native_present", "absent_write", "cold_read"):
        assert f'run_patrol_stage "{stage}"' in text
        assert f"{stage}-build.log" in text
        assert f"{stage}-test.log" in text
        assert f"{stage}-xcresult-summary.sanitized.json" in text
    assert text.count("--dart-define=MINT_PATROL_CLI=true") >= 1
    assert text.count("--dart-define=MINT_TEST_SUCCESSION_EVIDENCE_COLLECTION=true") >= 2
    assert "xcrun simctl terminate \"$device\" \"$bundle_id\"" in text
    assert "reset_external_build" in text
    assert "writer_reader_distinct_pid_verified=true" in text
    assert "state_preserved_across_process_death=true" in text
    assert "no_data_erase_between_writer_reader=true" in text
    death = text.index('xcrun simctl terminate "$device" "$bundle_id"')
    writer = text.index('run_patrol_stage "absent_write"')
    reader = text.index('run_patrol_stage "cold_read"')
    assert writer < death < reader
    forbidden_between = text[writer:reader]
    assert "uninstall" not in forbidden_between
    assert "clearDiagnostic" not in forbidden_between


def test_runner_builds_physical_exact_archive_default_off_and_flag_on_apps() -> None:
    text = source()
    archive = 'git -C "$repo_root" archive --format=tar "$sha" -- apps/mobile'
    assert text.count(archive) == 1
    assert 'run_logged "production-$stage-export" git' not in text
    assert '>"$archive" 2>"$raw"' in text
    assert 'sanitize_log "$raw" "$artifacts/production-$stage-export.log"' in text
    assert "archive_sha256=" in text
    assert "production_source_exported_exact=true" in text
    assert "production_source_physical=true" in text
    assert "reject_source_aliases" in text
    assert 'reject_source_aliases "$root/apps/mobile" || exit 1' in text
    assert 'build_production_app "flag_off" false' in text
    assert 'build_production_app "flag_on" true' in text
    assert "flutter build ios --simulator --debug --target lib/main.dart" in text
    off = re.search(
        r'build_production_app\(\).*?if \[\[ "\$enable_succession" == true \]\]; then(.*?)else(.*?)fi',
        text,
        re.S,
    )
    assert off is not None
    assert "MINT_TEST_SUCCESSION_EVIDENCE_COLLECTION=true" in off.group(1)
    assert "MINT_TEST_SUCCESSION_EVIDENCE_COLLECTION" not in off.group(2)
    assert 'run_maestro "flag_off" "$flag_off_flow"' in text
    assert 'run_maestro "flag_on" "$flag_on_flow"' in text
    assert "flag_off_route_anchor_verified=true" in text
    assert "flag_off_quest_absence_verified=true" in text
    assert "flag_on_civil_return_verified=true" in text
    build_function = text.split("build_production_app() {", 1)[1].split(
        "install_production_app() {", 1
    )[0]
    returned = build_function.index('source_root="$(export_production_source "$stage")"')
    assert build_function.index("production_source_exported_exact=true") > returned
    assert build_function.index("production_source_physical=true") > returned


def test_flag_off_is_not_a_vacuous_absence_only_check() -> None:
    text = source()
    assert "succession_parents_note" in text
    assert "succession_reference_quest" in text
    assert "verify_maestro_contract" in text
    assert "assertVisible" in text
    assert "assertNotVisible" in text


def test_runner_retains_only_sanitized_private_safe_evidence() -> None:
    text = source()
    assert "private_root=\"$(mktemp -d" in text
    assert "sanitize_log" in text
    assert "REDACTED_REPO" in text
    assert "REDACTED_HOME" in text
    assert "REDACTED_SIMULATOR_UDID" in text
    assert "REDACTED_PRIVATE_TEMP" in text
    assert "device.sha256" in text
    assert "synthetic_data_only=true" in text
    assert "raw_runtime_outputs_retained=false" in text
    assert "cleanup_status=passed" in text
    assert "SHA256SUMS" in text
    assert "trap cleanup EXIT HUP INT TERM" in text
    assert 'python3 - "$artifacts" "$repo_root" "$HOME" "$device" "$private_root"' in text


def test_metadata_python_executes_with_strict_real_booleans(tmp_path: Path) -> None:
    text = source()
    match = re.search(
        r"# METADATA_PYTHON_BEGIN\n.*?<<'PY'\n(.*?)\nPY\n# METADATA_PYTHON_END",
        text,
        re.S,
    )
    assert match is not None
    program = match.group(1)
    metadata = tmp_path / "metadata.json"
    device_sha = tmp_path / "device.sha256"
    device_sha.write_text("a" * 64 + "\n", encoding="utf-8")
    args = [
        str(metadata),
        "1" * 40,
        "ch.mint.app",
        str(device_sha),
        "true",
        "true",
        "true",
        "true",
        "true",
        "true",
        "true",
        "true",
        "true",
        "true",
        "false",
        "true",
    ]
    result = subprocess.run(
        ["python3", "-", *args],
        input=program,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    payload = json.loads(metadata.read_text(encoding="utf-8"))
    for key in (
        "pushedShaVerified",
        "productionSourceExportedExact",
        "productionSourcePhysical",
        "flagOffRouteAnchorVerified",
        "flagOffQuestAbsenceVerified",
        "flagOnCivilReturnVerified",
        "writerReaderDistinctPidVerified",
        "statePreservedAcrossProcessDeath",
        "noDataEraseBetweenWriterReader",
        "syntheticDataOnly",
        "runtimeCompleted",
    ):
        assert payload[key] is True
    assert payload["rawRuntimeOutputsRetained"] is False

    invalid = subprocess.run(
        ["python3", "-", *args[:-1], "not-a-bool"],
        input=program,
        text=True,
        capture_output=True,
        check=False,
    )
    assert invalid.returncode != 0
    assert "invalid boolean" in invalid.stderr


def test_runner_isolates_and_restores_build_state_and_captures_visuals() -> None:
    text = source()
    assert "build_backup=" in text
    assert "restore_build_isolation" in text
    assert "restoration_status=restored" in text
    assert "xcrun simctl io \"$device\" screenshot" in text
    for name in (
        "flag-off.png",
        "civil-return.png",
        "native-present.png",
        "cold-continuation.png",
    ):
        assert name in text
    assert "screenshot-sha256.json" in text
    assert text.index("trap cleanup EXIT HUP INT TERM") < text.index(
        'mv "$mobile_build" "$build_backup"'
    )
    assert 'install_production_app "flag_on-present" "$flag_on_app"' in text
    assert 'run_logged "flag-on-present-openurl"' in text
    assert 'install_production_app "flag_on-cold" "$flag_on_app"' in text
    assert 'run_logged "flag-on-cold-openurl"' in text
    assert "PNG signature or dimensions are invalid" in text
    assert "sleep 2" not in text
    assert "wait_for_succession_quest" in text
    assert 'bash "$maestro_runner" --udid "$device" hierarchy --compact' in text
    assert "deadline=$((SECONDS + 30))" in text
    assert "succession_reference_quest" in text
    assert 'sanitize_log "$raw" "$artifacts/hierarchy-$stage.log"' in text


def test_patrol_bundle_is_removed_before_each_exact_sha_stage_guard() -> None:
    text = source()
    assert "generated_bundle_armed=false" in text
    assert "pre-existing generated Patrol bundle is ambiguous" in text
    reset = text.split("reset_external_build() {", 1)[1].split(
        "patrol_app=", 1
    )[0]
    assert "remove_generated_bundle" not in reset
    assert "generated Patrol bundle exists before stage build" in reset
    assert "generated_bundle_armed=true" in reset
    function = text.split("run_patrol_stage() {", 1)[1].split(
        "capture_screenshot() {", 1
    )[0]
    assert function.index("reset_external_build") < function.index(
        '"$patrol_bin" --verbose build ios'
    )
    summary = function.index('summarize_xcresult "$stage" "$result_bundle"')
    cleanup = function.index("remove_generated_bundle", summary)
    guard = function.index("exact_sha_guard", cleanup)
    assert summary < cleanup < guard


def test_artifacts_path_is_case_scoped_and_exact_sha_timestamped() -> None:
    text = source()
    assert 'evidence_root="$repo_root/.planning/runtime-evidence/phase-37/succession-01"' in text
    assert "runtime-${sha:0:12}-YYYYMMDDTHHMMSSZ" in text
    assert "artifacts path must be under the G1 SUCCESSION evidence root" in text
    assert "artifacts basename must bind short SHA and UTC timestamp" in text


def test_bound_mobile_targets_make_cold_reader_the_first_post_death_advance() -> None:
    writer = (
        MOBILE / "integration_test/g1_succession_absent_write_patrol_test.dart"
    ).read_text(encoding="utf-8")
    reader = (
        MOBILE / "integration_test/g1_succession_cold_read_patrol_test.dart"
    ).read_text(encoding="utf-8")
    support = (
        MOBILE / "integration_test/support/g1_succession_runtime_contract.dart"
    ).read_text(encoding="utf-8")
    assert "succession_answer_saved" in writer
    last_saved = writer.rindex("succession_answer_saved")
    next_positions = [
        match.start() for match in re.finditer("succession_next_question", writer)
    ]
    assert next_positions
    assert all(position < last_saved for position in next_positions)
    assert "succession_instrument_inheritancePact_question" not in writer
    assert "successionWriterPid" in support
    assert "successionWriterStateWitness" in support
    assert "expect(pid, isNot(writerPid))" in reader
    assert "succession_instrument_inheritancePact_question" in reader

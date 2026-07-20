from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "tools/simulator/patrol_return01_six_origin.sh"


def source() -> str:
    return RUNNER.read_text(encoding="utf-8")


def test_runner_exists_and_has_a_strict_shell_contract() -> None:
    assert RUNNER.is_file()
    text = source()
    assert text.startswith("#!/usr/bin/env bash\nset -euo pipefail\n")
    assert "umask 077" in text
    assert "trap cleanup EXIT" in text
    assert "trap 'exit 129' HUP" in text
    assert "trap 'exit 130' INT" in text
    assert "trap 'exit 143' TERM" in text


def test_runner_requires_exact_clean_pushed_sha_device_bundle_and_fresh_root() -> None:
    text = source()
    for token in (
        "device must be an iOS Simulator UDID",
        "unexpected iOS bundle id",
        "sha must be 40 lowercase hex characters",
        "requested sha is not current HEAD",
        "HEAD must equal its configured upstream",
        "HEAD must be clean before runtime evidence",
        "runtime-<shortsha>-<UTC>",
        "artifacts directory already exists",
        "requested iOS Simulator is not booted",
    ):
        assert token in text
    assert "rev-parse '@{upstream}'" in text


def test_runner_requires_all_versioned_mobile_contracts_at_the_exact_sha() -> None:
    text = source()
    for token in (
        "apps/mobile/integration_test/g1_return01_six_origin_patrol_test.dart",
        "apps/mobile/test/patrol/g1_return01_six_origin_runtime_test.dart",
        "apps/mobile/test/runtime/g1_return01_six_origin_runtime_test.dart",
        "apps/mobile/.maestro/g1_return01_work_return.yaml",
        "apps/mobile/.maestro/g1_return01_housing_cancel_return.yaml",
        "apps/mobile/.maestro/g1_return01_disability_return.yaml",
        "apps/mobile/.maestro/g1_return01_succession_return.yaml",
        "apps/mobile/.maestro/g1_return01_frontalier_inline.yaml",
        "tools/simulator/patrol_return01_rvc_lpp_scan_return.sh",
        "runtime contract files must be tracked at HEAD",
        "runtime contract files differ from the requested SHA",
    ):
        assert token in text


def test_stage_mappings_are_bash_32_compatible_and_executable(tmp_path: Path) -> None:
    text = source()
    assert "declare -A" not in text
    assert re.search(r"\$\{(?:maestro_flows|witness_names|final_anchors)\[", text) is None

    functions: list[str] = []
    for name in (
        "maestro_flow_for_stage",
        "witness_name_for_stage",
        "final_anchor_for_stage",
    ):
        match = re.search(rf"{name}\(\) \{{\n.*?\n\}}", text, flags=re.S)
        assert match is not None, f"missing Bash-3 mapping function {name}"
        functions.append(match.group(0))

    expected = {
        "work_save": (
            "apps/mobile/.maestro/g1_return01_work_return.yaml",
            "mint-g1-return01-work_save-witness-v1.json",
            "first_job_result_cards",
        ),
        "housing_cancel": (
            "apps/mobile/.maestro/g1_return01_housing_cancel_return.yaml",
            "mint-g1-return01-housing_cancel-witness-v1.json",
            "mortgage_enrich_profile_cta",
        ),
        "disability_validation_cancel": (
            "apps/mobile/.maestro/g1_return01_disability_return.yaml",
            "mint-g1-return01-disability_validation_cancel-witness-v1.json",
            "disability_gap_ledger_facts",
        ),
        "succession_save": (
            "apps/mobile/.maestro/g1_return01_succession_return.yaml",
            "mint-g1-return01-succession_save-witness-v1.json",
            "succession_mortgage_missing",
        ),
        "frontalier_inline": (
            "apps/mobile/.maestro/g1_return01_frontalier_inline.yaml",
            "mint-g1-return01-frontalier_inline-witness-v1.json",
            "frontier_jurisdiction_known_state",
        ),
    }
    script = tmp_path / "mapping-contract.sh"
    body = ["#!/bin/bash", "set -eu", *functions]
    for stage, values in expected.items():
        body.extend(
            [
                f'test "$(maestro_flow_for_stage {stage})" = "{values[0]}"',
                f'test "$(witness_name_for_stage {stage})" = "{values[1]}"',
                f'test "$(final_anchor_for_stage {stage})" = "{values[2]}"',
            ]
        )
    body.extend(
        [
            "if maestro_flow_for_stage unknown >/dev/null 2>&1; then exit 41; fi",
            "if witness_name_for_stage unknown >/dev/null 2>&1; then exit 42; fi",
            "if final_anchor_for_stage unknown >/dev/null 2>&1; then exit 43; fi",
        ]
    )
    script.write_text("\n".join(body) + "\n", encoding="utf-8")
    result = subprocess.run(
        ["/bin/bash", str(script)], text=True, capture_output=True, check=False
    )
    assert result.returncode == 0, result.stderr


def test_runner_runs_doctor_and_patrol_guard_before_any_mobile_stage() -> None:
    text = source()
    doctor = text.index("python3 tools/checks/mint_os_doctor.py")
    patrol_guard = text.index("python3 tools/checks/patrol_tooling_guard.py")
    first_stage = text.index("run_patrol_stage work_save")
    assert doctor < patrol_guard < first_stage
    assert 'sanitize_log "$private_root/doctor.raw.log" "$artifacts/doctor.log"' in text
    assert (
        'sanitize_log "$private_root/patrol-tooling.raw.log" '
        '"$artifacts/patrol-tooling.log"'
    ) in text


def test_runner_exports_and_builds_physical_exact_source() -> None:
    text = source()
    for token in (
        "git archive --format=tar",
        "source-manifest.sha256",
        "productionSourceExportedExact",
        "productionSourcePhysical",
        "productionOverlayVerified",
        "flutter build ios --simulator --debug",
        "xcrun simctl install",
        "codesign --verify",
        "xattr",
    ):
        assert token in text
    assert text.index("git archive --format=tar") < text.index(
        "run_patrol_stage work_save"
    )


def test_runner_executes_the_five_non_rvc_stages_in_order() -> None:
    text = source()
    calls = re.findall(
        r"run_patrol_stage (work_save|housing_cancel|disability_validation_cancel|succession_save|frontalier_inline)",
        text,
    )
    assert calls == [
        "work_save",
        "housing_cancel",
        "disability_validation_cancel",
        "succession_save",
        "frontalier_inline",
    ]
    assert "MINT_G1_RETURN01_STAGE" in text
    assert "--dart-define=MINT_PATROL_CLI=true" in text
    assert "--no-uninstall" in text
    for stage in calls:
        assert text.index(f"run_patrol_stage {stage}") < text.index(
            f"run_maestro_stage {stage}"
        )
    assert "production overlay changed persistent app data" in text


def test_production_overlay_uses_immutable_app_and_preserves_seeded_data() -> None:
    text = source()
    build_match = re.search(r"build_physical_source\(\) \{\n(.*?)\n\}", text, flags=re.S)
    assert build_match is not None
    build = build_match.group(1)
    built_app = build.index(
        'local built_app="$source_root/apps/mobile/build/ios/iphonesimulator/Runner.app"'
    )
    immutable_app = build.index(
        'normal_app="$private_root/normal-production-app/Runner.app"', built_app
    )
    snapshot = build.index('/usr/bin/ditto "$built_app" "$normal_app"', immutable_app)
    verify = build.index('codesign --verify --deep --strict "$normal_app"', snapshot)
    assert built_app < immutable_app < snapshot < verify

    function_match = re.search(r"run_maestro_stage\(\) \{\n(.*?)\n\}", text, flags=re.S)
    assert function_match is not None
    function = function_match.group(1)
    pre_container = function.index("container_before=$(resolve_app_container)")
    pre_fingerprint = function.index(
        "data_before=$(fingerprint_persistent_app_data \"$container_before\")",
        pre_container,
    )
    install = function.index(
        'xcrun simctl install "$device" "$normal_app"', pre_fingerprint
    )
    post_container = function.index("container_after=$(resolve_app_container)", install)
    post_fingerprint = function.index(
        "data_after=$(fingerprint_persistent_app_data \"$container_after\")",
        post_container,
    )
    relocated = function.index("container_identity='relocated'", post_fingerprint)
    same_data = function.index('[[ "$data_before" == "$data_after" ]]', post_fingerprint)
    assert "production overlay changed persistent app data" in function[same_data:]
    assert pre_container < pre_fingerprint < install < post_container
    assert post_container < post_fingerprint < relocated < same_data
    assert "production overlay changed app data container" not in function
    assert "containerIdentityPreserved" not in text

    fingerprint_match = re.search(
        r"fingerprint_persistent_app_data\(\) \{\n(.*?)\n\}", text, flags=re.S
    )
    assert fingerprint_match is not None
    fingerprint = fingerprint_match.group(1)
    assert "file_count" in fingerprint
    assert "byte_count" in fingerprint
    assert 'if file_count < 1 or byte_count < 1:' in fingerprint
    assert 'print(f"{file_count}:{byte_count}:{digest.hexdigest()}")' in fingerprint

    overlay_log = function.index(">\"$artifacts/production-overlay-$stage.log\"")
    assert "container_identity=%s" in function[:overlay_log]
    assert "persistent_data=%s" in function[:overlay_log]
    assert '"$container_identity" "$persistent_data"' in function[:overlay_log]

    seeded_label = "housing_cancel | disability_validation_cancel | frontalier_inline)"
    seeded_start = function.index(seeded_label)
    seeded_case = function[seeded_start : function.index(";;", seeded_start)]
    assert "simctl uninstall" not in seeded_case


def test_each_stage_has_exact_maestro_flow_and_strict_witness_contract() -> None:
    text = source()
    expected = {
        "work_save": "g1_return01_work_return.yaml",
        "housing_cancel": "g1_return01_housing_cancel_return.yaml",
        "disability_validation_cancel": "g1_return01_disability_return.yaml",
        "succession_save": "g1_return01_succession_return.yaml",
        "frontalier_inline": "g1_return01_frontalier_inline.yaml",
    }
    for stage, flow in expected.items():
        assert f"apps/mobile/.maestro/{flow}" in text
        assert f"mint-g1-return01-{stage}-witness-v1.json" in text
    for token in (
        "validate_stage_witness",
        '"schemaVersion"',
        "routeBefore",
        "collectorRouteVerified",
        "routeAfterVerified",
        "storeWriteVerified",
        "storeUnchangedVerified",
        "validationRetainedVerified",
        "noDataBlockVerified",
        "frontalierCanonicalWritesVerified",
        "capture_hierarchy",
        "first_job_result_cards",
        "mortgage_enrich_profile_cta",
        "disability_gap_ledger_facts",
        "succession_mortgage_missing",
        "frontier_jurisdiction_known_state",
        "Maestro JUnit is not a clean pass",
    ):
        assert token in text


def test_maestro_failure_is_sanitized_and_named_before_fail_closed_exit() -> None:
    text = source()
    match = re.search(r"run_maestro_stage\(\) \{\n(.*?)\n\}", text, flags=re.S)
    assert match is not None
    function = match.group(1)

    command = function.index("bash tools/simulator/maestro_with_watchdog.sh test")
    capture = function.index("maestro_status=$?", command)
    restore_errexit = function.index("set -e", capture)
    sanitize_log = function.index(
        'sanitize_log "$private_stage/maestro.raw.log" '
        '"$artifacts/maestro-$stage.log"',
        restore_errexit,
    )
    junit_exists = function.index(
        '[[ -f "$private_stage/report.xml"', sanitize_log
    )
    sanitize_junit = function.index(
        'sanitize_log "$private_stage/report.xml"', junit_exists
    )
    assert (
        '"$artifacts/maestro-$stage-report.sanitized.xml"'
        in function[sanitize_junit:]
    )
    named_failure = function.index(
        'die "Maestro stage $stage failed with exit $maestro_status',
        sanitize_junit,
    )
    assert command < capture < restore_errexit < sanitize_log
    assert sanitize_log < junit_exists < sanitize_junit < named_failure
    assert "set +e" in function[:command]
    assert "sanitized log retained" in function[named_failure:]
    assert "maestro.raw.log" not in function[named_failure:]


def test_maestro_outputs_are_private_and_failure_diagnostics_are_best_effort() -> None:
    text = source()
    match = re.search(r"run_maestro_stage\(\) \{\n(.*?)\n\}", text, flags=re.S)
    assert match is not None
    function = match.group(1)

    command = function.index("bash tools/simulator/maestro_with_watchdog.sh test")
    test_output = function.index(
        '--test-output-dir "$private_stage/test-output"', command
    )
    debug_output = function.index(
        '--debug-output "$private_stage/debug-output"', command
    )
    flatten = function.index("--flatten-debug-output", command)
    flow = function.index('"$flow"', command)
    capture_status = function.index("maestro_status=$?", flow)
    failure_branch = function.index("if ((maestro_status != 0)); then")
    failure_diagnostics = function.index(
        'capture_failed_maestro_diagnostics "$stage" "$private_stage" || true',
        failure_branch,
    )
    named_failure = function.index(
        'die "Maestro stage $stage failed with exit $maestro_status',
        failure_diagnostics,
    )

    assert command < test_output < flow < capture_status
    assert command < debug_output < flow
    assert command < flatten < flow
    assert failure_branch < failure_diagnostics < named_failure
    assert "$HOME/.maestro" not in function

    helper_match = re.search(
        r"capture_failed_maestro_diagnostics\(\) \{\n(.*?)\n\}", text, flags=re.S
    )
    assert helper_match is not None
    helper = helper_match.group(1)
    assert 'xcrun simctl io "$device" screenshot "$artifacts/maestro-$stage.png"' in helper
    assert "hierarchy --compact" not in helper
    assert 'python3 - "$private_stage/debug-output" "$hierarchy_raw"' in helper
    assert 'glob("commands-*.json")' in helper
    assert '["metadata"]["error"]["hierarchyRoot"]' in helper
    assert "path.is_symlink()" in helper
    assert (
        'sanitize_log "$hierarchy_raw" '
        '"$artifacts/hierarchy-maestro-$stage.log"'
        in helper.replace("\\\n", "")
    )
    assert 'rm -f -- "$artifacts/maestro-$stage.png"' in helper
    assert 'rm -f -- "$artifacts/hierarchy-maestro-$stage.log"' in helper
    assert helper.rstrip().endswith("return 0")

    semantic_check = function.index(
        'python3 - "$artifacts/maestro-$stage-report.sanitized.xml"'
    )
    strict_hierarchy = function.index(
        'capture_hierarchy "maestro-$stage" "$anchor"', semantic_check
    )
    strict_screenshot = function.index(
        'capture_screenshot "maestro-$stage"', strict_hierarchy
    )
    assert named_failure < semantic_check < strict_hierarchy < strict_screenshot


def test_hierarchy_patrol_and_rvc_failures_are_isolated_and_observable() -> None:
    text = source()

    hierarchy_match = re.search(r"capture_hierarchy\(\) \{\n(.*?)\n\}", text, flags=re.S)
    assert hierarchy_match is not None
    hierarchy = hierarchy_match.group(1)
    command = hierarchy.index('bash "$maestro_runner" --udid "$device" hierarchy --compact')
    assert 'local private_home="$private_root/maestro-hierarchy-$label-java-home"' in hierarchy
    assert 'local walker="$private_root/maestro-hierarchy-$label-walker"' in hierarchy
    assert hierarchy.index('MAESTRO_OPTS="-Duser.home=$private_home"') < command
    assert hierarchy.index('MINT_WALKER_ARTIFACTS="$walker"') < command
    assert 'grep -Fq -- "$anchor"' in hierarchy[command:]

    patrol_match = re.search(r"run_patrol_stage\(\) \{\n(.*?)\n\}", text, flags=re.S)
    assert patrol_match is not None
    patrol = patrol_match.group(1)
    patrol_command = patrol.index('"$patrol" test')
    patrol_capture = patrol.index("patrol_status=$?", patrol_command)
    patrol_restore = patrol.index("set -e", patrol_capture)
    patrol_sanitize = patrol.index(
        'sanitize_log "$raw" "$artifacts/patrol-$stage.log"', patrol_restore
    )
    patrol_failure = patrol.index("if ((patrol_status != 0)); then", patrol_sanitize)
    patrol_archive = patrol.index('archive_xcresult_summary "$stage"', patrol_failure)
    patrol_die = patrol.index(
        'die "Patrol stage $stage failed with exit $patrol_status; sanitized log retained"',
        patrol_archive,
    )
    patrol_pass_archive = patrol.index('archive_xcresult_summary "$stage"', patrol_die)
    assert "set +e" in patrol[:patrol_command]
    assert patrol_command < patrol_capture < patrol_restore < patrol_sanitize
    assert patrol_sanitize < patrol_failure < patrol_archive < patrol_die
    assert "if ! (" in patrol[patrol_failure:patrol_archive]
    assert patrol_die < patrol_pass_archive

    rvc_match = re.search(r"run_rvc_stage\(\) \{\n(.*?)\n\}", text, flags=re.S)
    assert rvc_match is not None
    rvc = rvc_match.group(1)
    rvc_command = rvc.index('bash "$rvc_runner"')
    rvc_capture = rvc.index("rvc_status=$?", rvc_command)
    rvc_restore = rvc.index("set -e", rvc_capture)
    rvc_sanitize = rvc.index(
        'sanitize_log "$private_root/rvc-runner.raw.log" "$artifacts/rvc-runner.log"',
        rvc_restore,
    )
    rvc_die = rvc.index(
        'die "RVC stage failed with exit $rvc_status; sanitized log retained"',
        rvc_sanitize,
    )
    metadata = rvc.index('validate_rvc_metadata "$rvc_artifacts/metadata.json"', rvc_die)
    assert "set +e" in rvc[:rvc_command]
    assert rvc_command < rvc_capture < rvc_restore < rvc_sanitize < rvc_die < metadata


def test_rvc_is_a_separate_required_exact_sha_stage() -> None:
    text = source()
    rvc_call = text.index("patrol_return01_rvc_lpp_scan_return.sh")
    assert "return-01-rvc/runtime-${expected_sha:0:10}-$timestamp" in text
    assert "validate_rvc_metadata" in text
    assert '"sourceSha"' in text or '"commitSha"' in text
    assert "rvcExactShaVerified" in text
    assert rvc_call < text.index("write_metadata passed")


def test_runner_never_injects_a_production_persistence_failure() -> None:
    text = source().lower()
    forbidden = (
        "mint_inject_persistence_failure",
        "failure_query",
        "debug_failure_route",
        "throwingcoachprofileprovider",
        "failuresremaining",
    )
    for token in forbidden:
        assert token not in text
    assert "productionFailureInjectionUsed" in source()


def test_runner_sanitizes_an_allowlist_and_rejects_private_or_raw_outputs() -> None:
    text = source()
    for token in (
        "REDACTED_REPO",
        "REDACTED_HOME",
        "REDACTED_SIMULATOR_UDID",
        "REDACTED_PRIVATE_TEMP",
        "rawRuntimeOutputsRetained",
        "syntheticDataOnly",
        "verify_artifact_allowlist",
        "verify_privacy_inventory",
        "SHA256SUMS",
    ):
        assert token in text
    assert "find \"$artifacts\" -type f -print0" in text


def test_runner_records_restoration_cleanup_and_rechecks_exact_sha() -> None:
    text = source()
    for token in (
        "restore_normal_build",
        "verify_runtime_sources_clean",
        "restorationStatus",
        "cleanupStatus",
        "pushedShaVerified",
        "sourceTreeCleanAfterRuntime",
        "HEAD/upstream changed during runtime evidence",
    ):
        assert token in text
    assert text.rindex("verify_runtime_sources_clean") < text.index(
        "write_metadata passed"
    )


def test_metadata_is_fail_closed_for_all_six_origins_and_artifacts() -> None:
    text = source()
    for token in (
        '"caseId": "G1-RETURN-01"',
        '"workSaveVerified"',
        '"housingCancelNoWriteVerified"',
        '"disabilityValidationCancelNoWriteVerified"',
        '"successionSaveVerified"',
        '"frontalierInlineNoDataBlockVerified"',
        '"rvcExactShaVerified"',
        '"maestroStagesVerified"',
        '"patrolStagesVerified"',
        '"hierarchyWitnessesVerified"',
        '"storeWitnessesVerified"',
        '"screenshotsVerified"',
        '"checksumsVerified"',
    ):
        assert token in text


def _witness_validator_program() -> str:
    match = re.search(
        r"validate_stage_witness\(\) \{.*?<<'PY'\n(.*?)\nPY",
        source(),
        flags=re.S,
    )
    assert match is not None
    return match.group(1)


def _witness(stage: str) -> dict[str, object]:
    origins = {
        "work_save": "/first-job",
        "housing_cancel": "/hypotheque",
        "disability_validation_cancel": "/invalidite",
        "succession_save": "/succession",
        "frontalier_inline": "/segments/frontalier",
    }
    return {
        "schemaVersion": 1,
        "caseId": "G1-RETURN-01",
        "stage": stage,
        "sourceSha": "a" * 40,
        "syntheticDataOnly": True,
        "routeBefore": origins[stage],
        "routeAfter": origins[stage],
        "collectorRouteVerified": stage != "frontalier_inline",
        "routeAfterVerified": True,
        "storeWriteVerified": stage in {"work_save", "succession_save"},
        "storeUnchangedVerified": stage
        in {"housing_cancel", "disability_validation_cancel"},
        "validationRetainedVerified": stage
        == "disability_validation_cancel",
        "noDataBlockVerified": stage == "frontalier_inline",
        "frontalierCanonicalWritesVerified": stage == "frontalier_inline",
    }


def _run_witness_validator(
    tmp_path: Path, stage: str, payload: dict[str, object]
) -> subprocess.CompletedProcess[str]:
    tmp_path.mkdir(parents=True, exist_ok=True)
    source_path = tmp_path / f"{stage}.source.json"
    retained_path = tmp_path / f"{stage}.retained.json"
    source_path.write_text(json.dumps(payload), encoding="utf-8")
    return subprocess.run(
        ["python3", "-", str(source_path), str(retained_path), stage, "a" * 40],
        input=_witness_validator_program(),
        text=True,
        capture_output=True,
        check=False,
    )


def test_embedded_witness_validator_accepts_all_five_exact_schemas(
    tmp_path: Path,
) -> None:
    for stage in (
        "work_save",
        "housing_cancel",
        "disability_validation_cancel",
        "succession_save",
        "frontalier_inline",
    ):
        result = _run_witness_validator(tmp_path, stage, _witness(stage))
        assert result.returncode == 0, result.stderr
        retained = json.loads(
            (tmp_path / f"{stage}.retained.json").read_text(encoding="utf-8")
        )
        assert retained == _witness(stage)


def test_embedded_witness_validator_rejects_drift_and_fake_booleans(
    tmp_path: Path,
) -> None:
    mutations: list[tuple[str, object]] = [
        ("schemaVersion", 2),
        ("sourceSha", "b" * 40),
        ("routeAfter", "/home"),
        ("routeAfterVerified", 1),
        ("storeWriteVerified", True),
    ]
    for index, (key, value) in enumerate(mutations):
        payload = _witness("housing_cancel")
        payload[key] = value
        result = _run_witness_validator(
            tmp_path / f"mutation-{index}", "housing_cancel", payload
        )
        assert result.returncode != 0, (key, result.stdout, result.stderr)

    payload = _witness("work_save")
    payload["rawFinancialValue"] = 96000
    result = _run_witness_validator(tmp_path / "extra", "work_save", payload)
    assert result.returncode != 0

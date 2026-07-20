from __future__ import annotations

import hashlib
import json
import plistlib
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
        "apps/mobile/integration_test/g1_succession_civil_guard_seed_patrol_test.dart",
        "apps/mobile/integration_test/g1_succession_native_present_patrol_test.dart",
        "apps/mobile/integration_test/g1_succession_absent_write_patrol_test.dart",
        "apps/mobile/integration_test/g1_succession_cold_read_patrol_test.dart",
        "apps/mobile/test/patrol/g1_succession_civil_guard_seed_runtime_test.dart",
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
    writer = text.index('run_patrol_stage "absent_write"')
    death = text.index('xcrun simctl terminate "$device" "$bundle_id"', writer)
    reader = text.index('run_patrol_stage "cold_read"')
    assert writer < death < reader
    forbidden_between = text[writer:reader]
    assert "uninstall" not in forbidden_between
    assert "clearDiagnostic" not in forbidden_between


def test_runner_seeds_civil_guard_without_erasing_before_flag_on_maestro() -> None:
    text = source()
    for needle in (
        "clearDiagnostic()",
        "saveAnswers",
        "'q_civil_status': 'partenariat'",
        "isMiniOnboardingCompleted()",
        "persisted['q_civil_status']",
        "CoachProfile.fromWizardAnswers(persisted)",
        "civilStatusNeedsConfirmation",
    ):
        assert needle in text
    assert "CoachProfileProvider()" not in text
    assert "loadFromWizard()" not in text
    seed_contract = (
        MOBILE / "integration_test/g1_succession_civil_guard_seed_patrol_test.dart"
    ).read_text(encoding="utf-8")
    assert "setMiniOnboardingCompleted" not in seed_contract
    assert 'run_patrol_stage "civil_guard_seed" "$civil_guard_seed_target"' in text
    for suffix in ("build.log", "test.log", "xcresult-summary.sanitized.json"):
        assert f"civil_guard_seed-{suffix}" in text

    build = text.index('build_production_app "flag_on" true')
    seed = text.index(
        'run_patrol_stage "civil_guard_seed" "$civil_guard_seed_target"', build
    )
    seed_verified = text.index("civil_guard_seed_verified=true", seed)
    terminate = text.index(
        'terminate_seed_app_idempotently "civil-guard-seed-terminate"',
        seed_verified,
    )
    post_terminate = text.index(
        'wait_for_seed_witness "post-terminate"', terminate
    )
    post_terminate_verified = text.index(
        "seed_post_terminate_witness_verified=true", post_terminate
    )
    identity_captured = text.index(
        'seed_post_terminate_container_identity="$seed_witness_container_identity"',
        post_terminate_verified,
    )
    install = text.index(
        'install_production_app "flag_on-seeded" "$flag_on_app"',
        identity_captured,
    )
    post_overlay = text.index('wait_for_seed_witness "post-overlay"', install)
    post_overlay_verified = text.index(
        "seed_post_overlay_witness_verified=true", post_overlay
    )
    identity_verified = text.index(
        "seed_overlay_container_identity_verified=true", post_overlay_verified
    )
    witnesses_equal = text.index(
        "seed_witnesses_equal_verified=true", identity_verified
    )
    launch = text.index(
        'xcrun simctl launch "$device" "$bundle_id"', witnesses_equal
    )
    landing = text.index('wait_for_landing "flag_on-seeded"', launch)
    openurl = text.index('xcrun simctl openurl "$device"', landing)
    property_anchor = text.index('wait_for_property_input "flag_on-seeded"', openurl)
    maestro = text.index('run_maestro "flag_on" "$flag_on_flow"', property_anchor)
    preserved = text.index("seed_state_preserved_to_maestro=true", maestro)
    native_present = text.index(
        'run_patrol_stage "native_present" "$native_present_target"', preserved
    )
    native_contract = (
        MOBILE / "integration_test/g1_succession_native_present_patrol_test.dart"
    ).read_text(encoding="utf-8")
    assert "ReportPersistenceService.clearDiagnostic()" in native_contract
    assert (
        build
        < seed
        < seed_verified
        < terminate
        < post_terminate
        < post_terminate_verified
        < identity_captured
        < install
        < post_overlay
        < post_overlay_verified
        < identity_verified
        < witnesses_equal
        < launch
        < landing
        < openurl
        < property_anchor
        < maestro
        < preserved
        < native_present
    )
    seed_to_maestro = text[post_terminate:maestro]
    for forbidden in ("uninstall", "clearDiagnostic", "clearState"):
        assert forbidden not in seed_to_maestro
    for artifact in (
        "seed-witness-post-terminate.json",
        "seed-witness-post-overlay.json",
    ):
        assert artifact in text
    witness_function = text.split("wait_for_seed_witness() {", 1)[1].split(
        "wait_for_landing() {", 1
    )[0]
    assert (
        'xcrun simctl get_app_container "$device" "$bundle_id" data'
        in witness_function
    )
    assert "stat -f '%d:%i'" in witness_function
    assert 'printf \'%s\\n\' "$candidate"' not in witness_function
    assert (
        '[[ "$seed_witness_container_identity" == '
        '"$seed_post_terminate_container_identity" ]]' in text
    )
    compare = text.index("cmp -s", post_overlay_verified)
    first_witness = text.index(
        '"$artifacts/seed-witness-post-terminate.json"', compare
    )
    second_witness = text.index(
        '"$artifacts/seed-witness-post-overlay.json"', first_witness
    )
    assert compare < first_witness < second_witness < witnesses_equal


def test_seed_terminate_classifier_accepts_only_exact_already_dead_error(
    tmp_path: Path,
) -> None:
    text = source()
    match = re.search(
        r"# SEED_TERMINATE_CLASSIFIER_BEGIN\n(.*?)\n# SEED_TERMINATE_CLASSIFIER_END",
        text,
        re.S,
    )
    assert match is not None
    classifier = match.group(1)

    def classify(status: int, diagnostic: str) -> subprocess.CompletedProcess[str]:
        log = tmp_path / "terminate.log"
        log.write_text(diagnostic, encoding="utf-8")
        return subprocess.run(
            [
                "bash",
                "-c",
                f"{classifier}\nseed_terminate_is_already_dead \"$1\" \"$2\"",
                "classifier",
                str(status),
                str(log),
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    exact = """An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=3):
Simulator device failed to terminate ch.mint.app.
found nothing to terminate
"""
    assert classify(3, exact).returncode == 0
    assert classify(1, exact).returncode != 0
    assert classify(3, "found nothing to terminate\n").returncode != 0
    assert (
        classify(
            3,
            "An error was encountered (domain=NSPOSIXErrorDomain, code=3): permission denied\n",
        ).returncode
        != 0
    )
    assert classify(3, exact.replace("code=3", "code=4")).returncode != 0

    assert 'terminate_seed_app_idempotently "civil-guard-seed-terminate"' in text
    boundary = text.split("terminate_seed_app_idempotently() {", 1)[1].split(
        "reset_external_build() {", 1
    )[0]
    assert 'sanitize_log "$raw" "$artifacts/$name.log"' in boundary
    assert 'seed_terminate_is_already_dead "$status" "$raw"' in boundary
    assert 'exit "$status"' in boundary
    classify_before_sanitize = boundary.index(
        'seed_terminate_is_already_dead "$status" "$raw"'
    )
    sanitize = boundary.index('sanitize_log "$raw" "$artifacts/$name.log"')
    assert classify_before_sanitize < sanitize


def test_seed_witness_python_is_exact_and_retains_no_raw_values(
    tmp_path: Path,
) -> None:
    text = source()
    match = re.search(
        r"# SEED_WITNESS_PYTHON_BEGIN\n.*?<<'PY'\n(.*?)\nPY\n.*?# SEED_WITNESS_PYTHON_END",
        text,
        re.S,
    )
    assert match is not None
    program = match.group(1)
    seed_contract = (
        MOBILE / "integration_test/g1_succession_civil_guard_seed_patrol_test.dart"
    ).read_text(encoding="utf-8")
    seed_birth_year = int(
        re.search(r"'q_birth_year': (\d+)", seed_contract).group(1)  # type: ignore[union-attr]
    )
    seed_canton = re.search(
        r"'q_canton': '([^']+)'", seed_contract
    ).group(1)  # type: ignore[union-attr]
    seed_civil_status = re.search(
        r"'q_civil_status': '([^']+)'", seed_contract
    ).group(1)  # type: ignore[union-attr]
    assert f"birth_year != {seed_birth_year}" in program
    assert f'canton != "{seed_canton}"' in program
    assert f'civil_status != "{seed_civil_status}"' in program
    preferences = tmp_path / "ch.mint.app.plist"

    def run(values: dict[str, object]) -> subprocess.CompletedProcess[str]:
        with preferences.open("wb") as handle:
            plistlib.dump(values, handle)
        return subprocess.run(
            ["python3", "-", str(preferences)],
            input=program,
            text=True,
            capture_output=True,
            check=False,
        )

    valid = run(
        {
            "flutter.wizard_answers_v2": json.dumps(
                {
                    "q_birth_year": seed_birth_year,
                    "q_canton": seed_canton,
                    "q_civil_status": seed_civil_status,
                }
            ),
            "flutter.mini_onboarding_completed": False,
        }
    )
    assert valid.returncode == 0, valid.stderr
    witness = json.loads(valid.stdout)
    assert set(witness) == {
        "birthYearExpected",
        "cantonExpected",
        "civilStatusAmbiguous",
        "miniOnboardingIncomplete",
        "propertyMarketValueAbsent",
        "schemaVersion",
        "selectedValuesSha256",
    }
    assert witness["birthYearExpected"] is True
    assert witness["cantonExpected"] is True
    assert witness["civilStatusAmbiguous"] is True
    assert witness["miniOnboardingIncomplete"] is True
    assert witness["propertyMarketValueAbsent"] is True
    assert len(witness["selectedValuesSha256"]) == 64
    selected = json.dumps(
        {
            "miniOnboardingCompleted": False,
            "propertyMarketValuePresent": False,
            "q_birth_year": seed_birth_year,
            "q_canton": seed_canton,
            "q_civil_status": seed_civil_status,
        },
        separators=(",", ":"),
        sort_keys=True,
    )
    assert witness["selectedValuesSha256"] == hashlib.sha256(
        selected.encode()
    ).hexdigest()
    assert "partenariat" not in valid.stdout
    assert str(preferences) not in valid.stdout
    assert "900000" not in valid.stdout

    invalid_values = (
        {"q_civil_status": "celibataire"},
        {"q_civil_status": "partenariat", "q_property_market_value": 900000},
        {
            "q_birth_year": 1979,
            "q_canton": "VD",
            "q_civil_status": "partenariat",
        },
        {
            "q_birth_year": 1980,
            "q_canton": "GE",
            "q_civil_status": "partenariat",
        },
    )
    for answers in invalid_values:
        result = run(
            {
                "flutter.wizard_answers_v2": json.dumps(answers),
                "flutter.mini_onboarding_completed": False,
            }
        )
        assert result.returncode != 0
        assert result.stdout == ""
    completed = run(
        {
            "flutter.wizard_answers_v2": json.dumps(
                {"q_civil_status": "partenariat"}
            ),
            "flutter.mini_onboarding_completed": True,
        }
    )
    assert completed.returncode != 0
    assert completed.stdout == ""


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
    assert 'prepare_maestro_route "flag_off" "$flag_off_app"' in text
    assert 'prepare_maestro_route "flag_on" "$flag_on_app"' not in text
    assert "flag_off_route_anchor_verified=true" in text
    assert "flag_off_marker_verified=true" in text
    assert "flag_on_civil_return_verified=true" in text
    build_function = text.split("build_production_app() {", 1)[1].split(
        "install_production_app() {", 1
    )[0]
    returned = build_function.index('source_root="$(export_production_source "$stage")"')
    assert build_function.index("production_source_exported_exact=true") > returned
    assert build_function.index("production_source_physical=true") > returned


def test_flag_off_is_not_a_vacuous_absence_only_check() -> None:
    text = source()
    assert "succession_reference_quest_flag_off" in text
    assert "verify_maestro_contract" in text
    assert "assertVisible" in text
    assert "flag_off_marker_verified" in text
    assert "flagOffExplicitMarkerVerified" in text
    assert "flag_off_quest_absence_verified" not in text
    assert "flagOffQuestAbsenceVerified" not in text


def _assert_flow_starts_from_prepared_property_route(flow: str) -> None:
    for forbidden in ("- stopApp", "- launchApp:", "clearState:", "- openLink:"):
        assert forbidden not in flow

    lines = flow.split("---", 1)[1].splitlines()
    while lines and (not lines[0].strip() or lines[0].lstrip().startswith("#")):
        lines.pop(0)
    commands = "\n".join(lines)
    assert commands.startswith("- extendedWaitUntil:")
    route_wait = commands.index("- extendedWaitUntil:")
    route_wait_visible = commands.index("visible:", route_wait)
    route_wait_property = commands.index(
        'id: "property_market_value_input"', route_wait_visible
    )
    route_wait_timeout = commands.index("timeout: 20000", route_wait_property)
    property_assertion = commands.index("- assertVisible:", route_wait_timeout)
    property_assertion_id = commands.index(
        'id: "property_market_value_input"', property_assertion
    )

    assert (
        route_wait
        < route_wait_visible
        < route_wait_property
        < route_wait_timeout
        < property_assertion
        < property_assertion_id
    )


def test_runner_preflights_maestro_as_attached_prepared_route_proof() -> None:
    text = source()
    assert "require_prepared_route_flow" in text
    for forbidden in ("- stopApp", "- launchApp:", "clearState:", "- openLink:"):
        assert forbidden in text
    assert "forbidden in prepared Maestro flow" in text
    assert "- extendedWaitUntil:" in text
    assert "timeout: 20000" in text
    assert 'id: "property_market_value_input"' in text
    assert "must start from the prepared property route" in text


def test_runner_primes_clears_reinstalls_and_opens_flag_off_maestro_route() -> None:
    text = source()
    body = text.split("prepare_maestro_route() {", 1)[1].split("run_maestro() {", 1)[0]
    ordered = (
        'install_production_app "$stage-prime" "$app"',
        'xcrun simctl uninstall "$device" "$bundle_id"',
        'install_production_app "$stage-final" "$app"',
        'xcrun simctl launch "$device" "$bundle_id"',
        'wait_for_landing "$stage"',
        'xcrun simctl openurl "$device"',
        '"mint:///data-block/patrimoine?inputKey=q_property_market_value&returnUri=/succession"',
        'wait_for_property_input "$stage"',
    )
    cursor = 0
    for needle in ordered:
        position = body.index(needle, cursor)
        cursor = position + len(needle)

    for stage in ("flag_off",):
        build = text.index(f'build_production_app "{stage}"')
        prepare = text.index(f'prepare_maestro_route "{stage}"', build)
        maestro = text.index(f'run_maestro "{stage}"', prepare)
        assert build < prepare < maestro

    poll = text.split("wait_for_property_input() {", 1)[1].split(
        "wait_for_succession_quest() {", 1
    )[0]
    assert "local deadline=$((SECONDS + 30))" in poll
    assert 'bash "$maestro_runner" --udid "$device" hierarchy --compact' in poll
    assert "grep -Fq 'property_market_value_input'" in poll
    assert 'sanitize_log "$raw" "$artifacts/hierarchy-$stage-property.log"' in poll

    landing_poll = text.split("wait_for_landing() {", 1)[1].split(
        "wait_for_property_input() {", 1
    )[0]
    assert "local deadline=$((SECONDS + 30))" in landing_poll
    assert 'bash "$maestro_runner" --udid "$device" hierarchy --compact' in landing_poll
    assert "grep -Fq 'landing_route'" in landing_poll
    assert 'sanitize_log "$raw" "$artifacts/hierarchy-$stage-landing.log"' in landing_poll


def test_bound_maestro_flows_match_every_runner_preflight_needle() -> None:
    off = (MOBILE / ".maestro/g1_succession_flag_off.yaml").read_text(
        encoding="utf-8"
    )
    on = (MOBILE / ".maestro/g1_succession_progressive.yaml").read_text(
        encoding="utf-8"
    )
    for needle in (
        "assertVisible",
        "succession_reference_quest_flag_off",
    ):
        assert needle in off, f"flag-off flow lacks runner needle {needle}"
    for needle in (
        "succession_reference_quest",
        "succession_civil_status_guard",
        "succession_civil_status_confirm",
        "civil_status_single_choice",
        "household_save_cta",
        "succession_instrument_will_question",
    ):
        assert needle in on, f"flag-on flow lacks runner needle {needle}"
    _assert_flow_starts_from_prepared_property_route(off)
    _assert_flow_starts_from_prepared_property_route(on)

    assert "assertNotVisible" not in off
    save = off.index('id: "patrimoine_save_cta"')
    off_scroll = off.index("- scrollUntilVisible:", save)
    off_scroll_target = off.index(
        'id: "succession_reference_quest_flag_off"', off_scroll
    )
    off_direction = off.index("direction: DOWN", off_scroll_target)
    off_marker_assert = off.index("- assertVisible:", off_direction)
    off_marker = off.index(
        'id: "succession_reference_quest_flag_off"', off_marker_assert
    )
    assert (
        save
        < off_scroll
        < off_scroll_target
        < off_direction
        < off_marker_assert
        < off_marker
    )

    save = on.index('id: "patrimoine_save_cta"')
    scroll = on.index("- scrollUntilVisible:", save)
    scroll_target = on.index('id: "succession_civil_status_guard"', scroll)
    direction = on.index("direction: DOWN", scroll_target)
    guard_assert = on.index("- assertVisible:", direction)
    guard_id = on.index('id: "succession_civil_status_guard"', guard_assert)
    guard_tap = on.index('id: "succession_civil_status_confirm"', guard_id)
    assert (
        save
        < scroll
        < scroll_target
        < direction
        < guard_assert
        < guard_id
        < guard_tap
    )


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
        "flagOffExplicitMarkerVerified",
        "flagOnCivilReturnVerified",
        "civilGuardSeedVerified",
        "seedPostTerminateWitnessVerified",
        "seedPostOverlayWitnessVerified",
        "seedOverlayContainerIdentityVerified",
        "seedWitnessesEqualVerified",
        "seedStatePreservedToMaestro",
        "writerReaderDistinctPidVerified",
        "statePreservedAcrossProcessDeath",
        "noDataEraseBetweenWriterReader",
        "syntheticDataOnly",
        "runtimeCompleted",
    ):
        assert payload[key] is True
    assert payload["rawRuntimeOutputsRetained"] is False
    assert payload["setupPatrolStages"] == ["civil_guard_seed"]
    assert payload["patrolStages"] == ["native_present", "absent_write", "cold_read"]

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
    present = (
        MOBILE / "integration_test/g1_succession_native_present_patrol_test.dart"
    ).read_text(encoding="utf-8")
    writer = (
        MOBILE / "integration_test/g1_succession_absent_write_patrol_test.dart"
    ).read_text(encoding="utf-8")
    reader = (
        MOBILE / "integration_test/g1_succession_cold_read_patrol_test.dart"
    ).read_text(encoding="utf-8")
    support = (
        MOBILE / "integration_test/support/g1_succession_runtime_contract.dart"
    ).read_text(encoding="utf-8")
    for needle in (
        "succession_instrument_will_source_date",
        "succession_instrument_will_legal_year",
        ".enterText(",
        "EstateEvidenceRoot.fromJsonString",
        "EstateInstrumentSlotState.confirmedPresent",
    ):
        assert needle in present, f"native-present contract lacks {needle}"
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
    for needle in (
        "expect(pid, isNot(writerPid))",
        "successionWriterStateWitness",
        "EstateInstrumentSlotState.confirmedAbsent",
        "succession_instrument_inheritancePact_question",
    ):
        assert needle in reader, f"cold-reader contract lacks {needle}"

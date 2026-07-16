from __future__ import annotations

import json
import os
import re
import shutil
import signal
import stat
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
FLOW = ROOT / "apps/mobile/.maestro/g1_bnd03_budget_cold.yaml"
WRITE_CONTRACT = (
    ROOT / "apps/mobile/integration_test/g1_bnd03_budget_persistence_write_patrol_test.dart"
)
READ_CONTRACT = (
    ROOT / "apps/mobile/integration_test/g1_bnd03_budget_persistence_read_patrol_test.dart"
)
WRITE_RUNNER = (
    ROOT / "apps/mobile/test/patrol/g1_bnd03_budget_persistence_write_runtime_test.dart"
)
READ_RUNNER = (
    ROOT / "apps/mobile/test/patrol/g1_bnd03_budget_persistence_read_runtime_test.dart"
)
ORCHESTRATOR = ROOT / "tools/simulator/patrol_bnd03_budget_process_death.sh"
BUDGET_SCREEN = ROOT / "apps/mobile/lib/screens/budget/budget_screen.dart"
SYNTHETIC_UDID = "B03E429D-0422-4357-B754-536637D979F9"
SYNTHETIC_SHA = "3" * 40
BUNDLE_ID = "ch.mint.app"


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
    maestro_exit: int = 0,
    maestro_report: bool = True,
    maestro_invalid_xml: bool = False,
    maestro_override: bool = True,
    diff_exit: int = 0,
    untracked_mobile: bool = False,
    generate_bundle: bool = True,
    bundle_as_directory: bool = False,
    bundle_tracked: bool = False,
    patrol_sleep: int = 0,
) -> dict[str, str]:
    repo = tmp_path / "repo"
    mobile = repo / "apps/mobile"
    for relative in (
        "integration_test/g1_bnd03_budget_persistence_write_patrol_test.dart",
        "integration_test/g1_bnd03_budget_persistence_read_patrol_test.dart",
        "test/patrol/g1_bnd03_budget_persistence_write_runtime_test.dart",
        "test/patrol/g1_bnd03_budget_persistence_read_runtime_test.dart",
        ".maestro/g1_bnd03_budget_cold.yaml",
        "lib/screens/budget/budget_container_screen.dart",
        "lib/screens/budget/budget_setup_screen.dart",
        "lib/screens/budget/budget_screen.dart",
    ):
        target = mobile / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("tracked synthetic contract\n", encoding="utf-8")
    original_build = mobile / "build"
    original_build.mkdir(parents=True)
    (original_build / "original-build-marker.txt").write_text(
        "must survive every exit path\n",
        encoding="utf-8",
    )
    (mobile / ".dart_tool").mkdir()
    simulator = repo / "tools/simulator"
    simulator.mkdir(parents=True)
    (simulator / "patrol_bnd03_budget_process_death.sh").write_text(
        "tracked synthetic orchestrator\n", encoding="utf-8"
    )

    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    calls = tmp_path / "calls.log"
    fake_git = fake_bin / "git"
    fake_patrol = fake_bin / "patrol"
    fake_xcrun = fake_bin / "xcrun"
    fake_maestro = fake_bin / "maestro-runner"
    default_maestro = simulator / "maestro_env.sh"
    default_maestro.write_text(
        '#!/usr/bin/env bash\nexec "$MINT_TEST_DEFAULT_MAESTRO" "$@"\n',
        encoding="utf-8",
    )
    default_maestro.chmod(0o644)

    _write_executable(
        fake_git,
        "#!/usr/bin/env bash\n"
        'printf \'git %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "$*" == *"--show-toplevel"* ]]; then printf \'%s\\n\' "$MINT_TEST_REPO"; exit 0; fi\n'
        'if [[ "$*" == *"rev-parse HEAD"* ]]; then printf \'%s\\n\' "$MINT_TEST_SHA"; exit 0; fi\n'
        'if [[ "$*" == *"ls-files --others"* ]]; then\n'
        '  if [[ "$MINT_TEST_UNTRACKED_MOBILE" == "1" ]]; then printf \'apps/mobile/untracked.dart\\n\'; fi\n'
        '  exit 0\n'
        'fi\n'
        'if [[ "$*" == *"ls-files --error-unmatch"* && "$*" == *"test/patrol/test_bundle.dart"* ]]; then\n'
        '  exit "$MINT_TEST_BUNDLE_TRACKED"\n'
        'fi\n'
        'if [[ "$*" == *"ls-files --error-unmatch"* ]]; then exit 0; fi\n'
        'if [[ "$*" == *"diff --quiet"* ]]; then exit "$MINT_TEST_DIFF_EXIT"; fi\n'
        "exit 91\n",
    )
    _write_executable(
        fake_patrol,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'build_target="$(readlink build 2>/dev/null || true)"\n'
        'printf \'patrol cwd=%s build=%s args=%s\\n\' "$PWD" "$build_target" "$*" >> "$MINT_TEST_CALLS"\n'
        '[[ "${1:-}" == "--verbose" && "${2:-}" == "test" ]] || exit 93\n'
        '[[ -L build && -d "$build_target" ]] || exit 94\n'
        'case "$build_target" in "$MINT_TEST_REPO"/*) exit 95 ;; esac\n'
        'printf \'verbose repo=%s external=%s home=%s device=%s temp=%s\\n\' "$MINT_TEST_REPO" "$build_target" "$HOME" "$MINT_TEST_DEVICE" "$MINT_TEST_PRIVATE_TEMP"\n'
        'if [[ "$MINT_TEST_GENERATE_BUNDLE" == "1" ]]; then\n'
        '  if [[ "$MINT_TEST_BUNDLE_AS_DIRECTORY" == "1" ]]; then\n'
        '    mkdir -p test/patrol/test_bundle.dart\n'
        '  else\n'
        '    mkdir -p test/patrol\n'
        '    printf \'generated bundle\\n\' > test/patrol/test_bundle.dart\n'
        '  fi\n'
        'fi\n'
        'if [[ "$*" == *"write_runtime"* ]]; then\n'
        '  printf \'writer cache\\n\' > build/writer-cache-marker.txt\n'
        '  if [[ "$MINT_TEST_PATROL_SLEEP" -gt 0 ]]; then sleep "$MINT_TEST_PATROL_SLEEP"; fi\n'
        '  exit "$MINT_TEST_WRITE_EXIT"\n'
        'fi\n'
        '[[ ! -e build/writer-cache-marker.txt ]] || exit 96\n'
        'printf \'reader cache\\n\' > build/reader-cache-marker.txt\n'
        'exit "$MINT_TEST_READ_EXIT"\n',
    )
    _write_executable(
        fake_xcrun,
        "#!/usr/bin/env bash\n"
        'printf \'xcrun %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "${2:-}" == "launch" ]]; then exit "$MINT_TEST_LAUNCH_EXIT"; fi\n'
        'if [[ "${2:-}" == "terminate" ]]; then exit "$MINT_TEST_TERMINATE_EXIT"; fi\n'
        "exit 92\n",
    )
    _write_executable(
        fake_maestro,
        "#!/usr/bin/env bash\n"
        'printf \'maestro %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'output=""\n'
        'previous=""\n'
        'for argument in "$@"; do\n'
        '  if [[ "$previous" == "--output" ]]; then output="$argument"; break; fi\n'
        '  previous="$argument"\n'
        'done\n'
        'printf \'private udid=%s repo=%s home=%s temp=%s\\n\' "$MINT_TEST_DEVICE" "$MINT_TEST_REPO" "$HOME" "$MINT_TEST_PRIVATE_TEMP"\n'
        'if [[ "$MINT_TEST_MAESTRO_REPORT" == "1" && -n "$output" ]]; then\n'
        '  if [[ "$MINT_TEST_MAESTRO_INVALID_XML" == "1" ]]; then\n'
        '    printf \'<testsuite name="unterminated"\' > "$output"\n'
        '  else\n'
        '    printf \'<testsuite name="synthetic" device="%s" repo="%s" home="%s" temp="%s"/>\\n\' "$MINT_TEST_DEVICE" "$MINT_TEST_REPO" "$HOME" "$MINT_TEST_PRIVATE_TEMP" > "$output"\n'
        '  fi\n'
        'fi\n'
        'exit "$MINT_TEST_MAESTRO_EXIT"\n',
    )
    env = {
        **os.environ,
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "PATROL_BIN": str(fake_patrol),
        "MINT_TEST_CALLS": str(calls),
        "MINT_TEST_REPO": str(repo),
        "MINT_TEST_SHA": SYNTHETIC_SHA,
        "MINT_TEST_WRITE_EXIT": str(write_exit),
        "MINT_TEST_LAUNCH_EXIT": str(launch_exit),
        "MINT_TEST_TERMINATE_EXIT": str(terminate_exit),
        "MINT_TEST_READ_EXIT": str(read_exit),
        "MINT_TEST_MAESTRO_EXIT": str(maestro_exit),
        "MINT_TEST_MAESTRO_REPORT": "1" if maestro_report else "0",
        "MINT_TEST_MAESTRO_INVALID_XML": "1" if maestro_invalid_xml else "0",
        "MINT_TEST_DEVICE": SYNTHETIC_UDID,
        "MINT_TEST_DIFF_EXIT": str(diff_exit),
        "MINT_TEST_UNTRACKED_MOBILE": "1" if untracked_mobile else "0",
        "MINT_TEST_GENERATE_BUNDLE": "1" if generate_bundle else "0",
        "MINT_TEST_BUNDLE_AS_DIRECTORY": "1" if bundle_as_directory else "0",
        "MINT_TEST_BUNDLE_TRACKED": "0" if bundle_tracked else "1",
        "MINT_TEST_PATROL_SLEEP": str(patrol_sleep),
        "MINT_TEST_DEFAULT_MAESTRO": str(fake_maestro),
        "MINT_TEST_PRIVATE_TEMP": "/private/var/folders/aa/bb/T/mint-bnd03",
    }
    if maestro_override:
        env["MAESTRO_RUNNER"] = str(fake_maestro)
    else:
        env.pop("MAESTRO_RUNNER", None)
    return env


def _assert_original_build_restored(env: dict[str, str], inode: int) -> None:
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    assert mobile_build.is_dir()
    assert not mobile_build.is_symlink()
    assert mobile_build.stat().st_ino == inode
    assert (mobile_build / "original-build-marker.txt").read_text(
        encoding="utf-8"
    ) == "must survive every exit path\n"


def _run(
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


def test_budget_runtime_contracts_use_real_ui_and_cold_canonical_seams() -> None:
    writer = WRITE_CONTRACT.read_text(encoding="utf-8")
    reader = READ_CONTRACT.read_text(encoding="utf-8")
    write_runner = WRITE_RUNNER.read_text(encoding="utf-8")
    read_runner = READ_RUNNER.read_text(encoding="utf-8")
    flow = FLOW.read_text(encoding="utf-8")
    screen = BUDGET_SCREEN.read_text(encoding="utf-8")
    orchestrator = ORCHESTRATOR.read_text(encoding="utf-8")

    assert "ReportPersistenceService.clearDiagnostic()" in writer
    assert "ReportPersistenceService.saveAnswers(" not in writer
    for identifier in (
        "salary_input",
        "salary_save_cta",
        "budget_setup_housing_input",
        "budget_setup_lamal_input",
        "budget_setup_save_cta",
        "budget_future_input",
        "budget_variables_input",
        "budget_available_hero",
    ):
        assert f"#{identifier}" in writer
    assert writer.index("#budget_future_input") < writer.index("budget_inputs_v1")
    assert "SharedPreferences.getInstance()" in writer
    assert "999999" in writer
    assert "waitForOverridePersistence()" in writer
    assert "openUrl('mint:///budget/setup')" not in writer
    first_budget = writer.index("openUrl('mint:///budget')")
    setup_start = writer.index("#budget_setup_start_cta")
    setup_housing = writer.index("#budget_setup_housing_input")
    setup_save = writer.index("#budget_setup_save_cta")
    first_hero = writer.index("#budget_available_hero")
    revenue = writer.index("openUrl('mint:///data-block/revenu')")
    salary = writer.index("#salary_input")
    salary_save = writer.index("#salary_save_cta")
    final_budget = writer.index("openUrl('mint:///budget')", first_budget + 1)
    future = writer.index("#budget_future_input")
    assert (
        first_budget
        < setup_start
        < setup_housing
        < setup_save
        < first_hero
        < revenue
        < salary
        < salary_save
        < final_budget
        < future
    )

    assert "ReportPersistenceService.clearDiagnostic()" not in reader
    assert "CoachProfileProvider" in reader
    assert "BudgetProvider" in reader
    assert "MintStateProvider" in reader
    assert "BudgetInputs.fromCoachProfile(profile!)" in reader
    assert "budget_inputs_v1" in reader
    assert "budget_override_future" in reader
    assert "budget_override_variables" in reader
    assert "#budget_available_hero" in reader
    assert "monthlyFree" in reader
    assert "waitForOverridePersistence()" in reader

    assert "g1_bnd03_budget_persistence_write_patrol_test.dart" in write_runner
    assert "g1_bnd03_budget_persistence_read_patrol_test.dart" in read_runner
    assert "budget_available_hero" in screen
    assert "budget_future_input" in screen
    assert "budget_variables_input" in screen

    assert "clearState" not in flow
    assert "takeScreenshot" not in flow
    assert flow.index("- stopApp") < flow.index("- launchApp")
    assert "launchApp" in flow
    assert 'id: "budget_available_hero"' in flow
    assert 'id: "budget_future_input"' in flow
    assert 'id: "budget_variables_input"' in flow

    assert "set -euo pipefail" in orchestrator
    assert "ls-files --error-unmatch" in orchestrator
    assert "ls-files --others --exclude-standard -- apps/mobile" in orchestrator
    assert "diff --quiet" in orchestrator
    assert re.search(
        r'git -C "\$repo_root" diff --quiet "\$sha" --\s*\\$',
        orchestrator,
        re.MULTILINE,
    )
    assert orchestrator.count('xcrun simctl terminate "$device" "$bundle_id"') == 1
    assert "MAESTRO_RUNNER" in orchestrator
    assert '"tools/simulator/maestro_env.sh"' in orchestrator
    assert 'maestro_command=(bash "$default_maestro_runner")' in orchestrator
    assert 'maestro_command=("$MAESTRO_RUNNER")' in orchestrator
    assert "xml.etree.ElementTree" in orchestrator
    assert "test/patrol/test_bundle.dart" in orchestrator
    assert "budget_container_screen.dart" in orchestrator
    assert "budget_setup_screen.dart" in orchestrator
    assert 'mobile_build="$mobile_root/build"' in orchestrator
    assert 'rm -rf -- "$external_build"' in orchestrator
    assert 'mv "$mobile_build" "$build_backup"' in orchestrator
    assert 'ln -s "$external_build" "$mobile_build"' in orchestrator
    assert "pre-existing build symlink" in orchestrator
    assert "backup collision" in orchestrator
    assert "trap 'exit 143' TERM" in orchestrator
    assert orchestrator.count('"$patrol_bin" --verbose test') == 2
    assert "patrol build" not in orchestrator
    assert "xcodebuild" not in orchestrator
    assert "codesign" not in orchestrator
    assert "entitlements" not in orchestrator
    assert "synthetic_data_only" in orchestrator
    assert "device_sha256" in orchestrator
    assert '"device"' not in orchestrator


def test_budget_orchestrator_runs_writer_death_reader_then_maestro(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    result = _run(tmp_path, env)

    assert result.returncode == 0, result.stderr
    _assert_original_build_restored(env, original_inode)
    assert result.stdout.count("patrol_bnd03_budget_process_death: PASS") == 1
    assert not (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    ).exists()
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8").splitlines()
    runtime_calls = [line for line in calls if not line.startswith("git ")]
    assert len(runtime_calls) == 5
    assert "write_runtime" in runtime_calls[0]
    patrol_calls = [line for line in runtime_calls if line.startswith("patrol ")]
    assert len(patrol_calls) == 2
    assert all("args=--verbose test" in line for line in patrol_calls)
    assert all("--no-uninstall" in line for line in patrol_calls)
    external_targets = {
        re.search(r" build=([^ ]+) args=", line).group(1) for line in patrol_calls
    }
    assert len(external_targets) == 1
    external_target = Path(external_targets.pop())
    assert not external_target.is_relative_to(Path(env["MINT_TEST_REPO"]))
    assert not external_target.exists()
    assert runtime_calls[1] == f"xcrun simctl launch {SYNTHETIC_UDID} {BUNDLE_ID}"
    assert runtime_calls[2] == f"xcrun simctl terminate {SYNTHETIC_UDID} {BUNDLE_ID}"
    assert "read_runtime" in runtime_calls[3]
    assert "g1_bnd03_budget_cold.yaml" in runtime_calls[4]

    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["contract"] == "g1_bnd03_budget"
    assert metadata["sha"] == SYNTHETIC_SHA
    assert metadata["synthetic_data_only"] is True
    assert metadata["private_fixture_used"] is False
    assert metadata["write_exit_code"] == 0
    assert metadata["launch_exit_code"] == 0
    assert metadata["terminate_exit_code"] == 0
    assert metadata["read_exit_code"] == 0
    assert metadata["maestro_exit_code"] == 0
    assert metadata["cleanup_status"] == "passed"
    assert metadata["build_isolation"] == {
        "enabled": True,
        "original_build_present": True,
        "reset_between_patrol_stages": True,
        "restoration_status": "restored",
    }
    assert "maestro-report.sanitized.xml" in metadata["logs"]
    assert metadata["device_sha256"] != SYNTHETIC_UDID
    assert SYNTHETIC_UDID not in (tmp_path / "artifacts/metadata.json").read_text()
    artifacts = tmp_path / "artifacts"
    report = artifacts / "maestro-report.sanitized.xml"
    assert report.is_file()
    private_values = (
        SYNTHETIC_UDID,
        env["MINT_TEST_REPO"],
        env["HOME"],
        str(external_target.parent),
    )
    for sanitized in (report, *artifacts.glob("*.log")):
        sanitized_text = sanitized.read_text(encoding="utf-8")
        assert all(private not in sanitized_text for private in private_values)
    assert "REDACTED_SIMULATOR_UDID" in report.read_text(encoding="utf-8")
    assert "REDACTED_REPO" in report.read_text(encoding="utf-8")
    assert "REDACTED_HOME" in report.read_text(encoding="utf-8")
    assert "REDACTED_PRIVATE_TEMP" in report.read_text(encoding="utf-8")
    assert ET.parse(report).getroot().tag == "testsuite"
    assert "REDACTED_SIMULATOR_UDID" in (artifacts / "maestro.log").read_text(
        encoding="utf-8"
    )
    for patrol_log in (artifacts / "write.log", artifacts / "read.log"):
        text = patrol_log.read_text(encoding="utf-8")
        assert "REDACTED_REPO" in text
        assert "REDACTED_HOME" in text
        assert "REDACTED_SIMULATOR_UDID" in text
        assert "REDACTED_PRIVATE_TEMP" in text
        assert "REDACTED_EXTERNAL_BUILD" in text
    metadata_text = (artifacts / "metadata.json").read_text(encoding="utf-8")
    assert str(tmp_path) not in metadata_text
    assert not any("path" in key for key in metadata["build_isolation"])
    assert not (artifacts / "maestro-report.xml").exists()
    assert not list(artifacts.glob("*.raw.log"))


def test_budget_orchestrator_uses_default_non_executable_maestro_via_bash(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, maestro_override=False)
    default_runner = Path(env["MINT_TEST_REPO"]) / "tools/simulator/maestro_env.sh"
    assert not os.access(default_runner, os.X_OK)

    result = _run(tmp_path, env)

    assert result.returncode == 0, result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert "maestro " in calls
    assert (tmp_path / "artifacts/maestro-report.sanitized.xml").is_file()


def test_budget_orchestrator_rejects_maestro_success_without_junit(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, maestro_report=False)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode != 0
    _assert_original_build_restored(env, original_inode)
    assert "Maestro JUnit report is missing or empty" in result.stderr
    assert "PASS" not in result.stdout
    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["maestro_exit_code"] != 0
    assert not (tmp_path / "artifacts/maestro-report.sanitized.xml").exists()
    assert not (tmp_path / "artifacts/maestro-report.xml").exists()


def test_budget_orchestrator_rejects_invalid_sanitized_junit(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, maestro_invalid_xml=True)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode != 0
    _assert_original_build_restored(env, original_inode)
    assert "sanitized Maestro JUnit report is invalid XML" in result.stderr
    assert "PASS" not in result.stdout
    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["maestro_exit_code"] != 0


@pytest.mark.parametrize(
    ("runtime", "expected", "forbidden"),
    [
        ({"write_exit": 7}, "write stage failed", "xcrun simctl launch"),
        ({"launch_exit": 8}, "launch stage failed", "xcrun simctl terminate"),
        ({"terminate_exit": 9}, "terminate stage failed", "read_runtime"),
        ({"read_exit": 10}, "read stage failed", "maestro "),
        ({"maestro_exit": 11}, "Maestro stage failed", "PASS"),
    ],
)
def test_budget_orchestrator_fails_closed(
    tmp_path: Path,
    runtime: dict[str, int],
    expected: str,
    forbidden: str,
) -> None:
    env = _fake_runtime(tmp_path, **runtime)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    result = _run(tmp_path, env)

    assert result.returncode == next(iter(runtime.values()))
    _assert_original_build_restored(env, original_inode)
    assert expected in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8").splitlines()
    runtime_calls = "\n".join(line for line in calls if not line.startswith("git "))
    assert forbidden not in runtime_calls + result.stdout
    generated_bundle = (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    )
    assert not generated_bundle.exists()
    artifacts = tmp_path / "artifacts"
    assert (artifacts / "metadata.json").is_file()
    assert not list(artifacts.glob("*.raw.log"))
    assert not (artifacts / "maestro-report.xml").exists()


def test_budget_orchestrator_rejects_missing_device_and_sha_drift(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path)

    missing_device = _run(tmp_path, env, include_device=False)
    wrong_sha = _run(tmp_path, env, sha="a" * 40)

    assert missing_device.returncode != 0
    assert "--device is required" in missing_device.stderr
    assert wrong_sha.returncode != 0
    assert "must equal current HEAD" in wrong_sha.stderr


def test_budget_orchestrator_rejects_any_tracked_worktree_drift(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, diff_exit=12)

    result = _run(tmp_path, env)

    assert result.returncode != 0
    assert "runtime contract differs from --sha HEAD" in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert "patrol " not in calls


def test_budget_orchestrator_rejects_untracked_mobile_before_runtime(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, untracked_mobile=True)

    result = _run(tmp_path, env)

    assert result.returncode != 0
    assert "untracked mobile files make --sha evidence ambiguous" in result.stderr
    assert "patrol " not in (tmp_path / "calls.log").read_text(encoding="utf-8")


def test_budget_orchestrator_cleanup_preserves_tracked_patrol_bundle(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, bundle_tracked=True)

    result = _run(tmp_path, env)

    assert result.returncode == 0, result.stderr
    generated_bundle = (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    )
    assert generated_bundle.read_text(encoding="utf-8") == "generated bundle\n"


def test_budget_orchestrator_success_fails_closed_when_metadata_is_directory(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    metadata = tmp_path / "artifacts/metadata.json"
    metadata.mkdir(parents=True)

    result = _run(tmp_path, env)

    assert result.returncode == 2
    _assert_original_build_restored(env, original_inode)
    assert "PASS" not in result.stdout
    assert metadata.is_dir()
    generated_bundle = (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    )
    assert not generated_bundle.exists()


def test_budget_orchestrator_success_fails_closed_when_bundle_cleanup_fails(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, bundle_as_directory=True)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode == 2
    _assert_original_build_restored(env, original_inode)
    assert "PASS" not in result.stdout
    generated_bundle = (
        Path(env["MINT_TEST_REPO"]) / "apps/mobile/test/patrol/test_bundle.dart"
    )
    assert generated_bundle.is_dir()
    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["cleanup_status"] == "failed"


def test_budget_orchestrator_stage_failure_preserves_code_when_cleanup_fails(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, write_exit=7, bundle_as_directory=True)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino

    result = _run(tmp_path, env)

    assert result.returncode == 7
    _assert_original_build_restored(env, original_inode)
    assert "PASS" not in result.stdout
    assert (tmp_path / "artifacts/metadata.json").is_file()


def test_budget_orchestrator_stage_failure_preserves_code_when_sanitization_fails(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, write_exit=7)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
    original_inode = mobile_build.stat().st_ino
    artifacts = tmp_path / "artifacts"
    (artifacts / "write.log").mkdir(parents=True)

    result = _run(tmp_path, env)

    assert result.returncode == 7
    _assert_original_build_restored(env, original_inode)
    assert "PASS" not in result.stdout
    assert not list(artifacts.glob("*.raw.log"))
    metadata = json.loads((artifacts / "metadata.json").read_text(encoding="utf-8"))
    assert metadata["cleanup_status"] == "failed"


def test_budget_orchestrator_rejects_build_symlink_and_backup_collision(
    tmp_path: Path,
) -> None:
    symlink_env = _fake_runtime(tmp_path / "symlink")
    symlink_build = Path(symlink_env["MINT_TEST_REPO"]) / "apps/mobile/build"
    shutil.rmtree(symlink_build)
    foreign_build = tmp_path / "foreign-build"
    foreign_build.mkdir()
    symlink_build.symlink_to(foreign_build, target_is_directory=True)

    symlink_result = _run(tmp_path / "symlink", symlink_env)

    assert symlink_result.returncode != 0
    assert "pre-existing build symlink" in symlink_result.stderr
    assert symlink_build.is_symlink()
    assert symlink_build.resolve() == foreign_build.resolve()

    collision_env = _fake_runtime(tmp_path / "collision")
    collision_repo = Path(collision_env["MINT_TEST_REPO"])
    collision_build = collision_repo / "apps/mobile/build"
    original_inode = collision_build.stat().st_ino
    backup = (
        collision_repo
        / "apps/mobile/.dart_tool"
        / f"mint-patrol-g1-bnd03-build-backup-{SYNTHETIC_SHA}"
    )
    backup.mkdir()
    (backup / "stale-backup-marker.txt").write_text("preserve\n", encoding="utf-8")

    collision_result = _run(tmp_path / "collision", collision_env)

    assert collision_result.returncode != 0
    assert "backup collision" in collision_result.stderr
    _assert_original_build_restored(collision_env, original_inode)
    assert (backup / "stale-backup-marker.txt").read_text(encoding="utf-8") == (
        "preserve\n"
    )
    assert "patrol " not in (tmp_path / "collision/calls.log").read_text(
        encoding="utf-8"
    )


def test_budget_orchestrator_restores_original_build_on_term_signal(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path, patrol_sleep=30)
    mobile_build = Path(env["MINT_TEST_REPO"]) / "apps/mobile/build"
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
    artifacts = tmp_path / "artifacts"
    calls_path = tmp_path / "calls.log"
    write_raw = artifacts / "write.raw.log"
    deadline = time.monotonic() + 10
    patrol_write_call = ""
    while time.monotonic() < deadline:
        if process.poll() is not None:
            break
        if calls_path.exists():
            patrol_write_call = next(
                (
                    line
                    for line in calls_path.read_text(encoding="utf-8").splitlines()
                    if line.startswith("patrol ") and "write_runtime" in line
                ),
                "",
            )
        if patrol_write_call and write_raw.is_file() and write_raw.stat().st_size > 0:
            break
        time.sleep(0.05)
    assert patrol_write_call, process.communicate(timeout=2)
    assert write_raw.is_file() and write_raw.stat().st_size > 0
    assert mobile_build.is_symlink()
    external_target_match = re.search(r" build=([^ ]+) args=", patrol_write_call)
    assert external_target_match is not None
    external_root = str(Path(external_target_match.group(1)).parent)

    os.killpg(process.pid, signal.SIGTERM)
    stdout, stderr = process.communicate(timeout=10)

    assert process.returncode == 143, stdout + stderr
    _assert_original_build_restored(env, original_inode)
    metadata = json.loads(
        (artifacts / "metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["build_isolation"]["restoration_status"] == "restored"
    assert not list(artifacts.glob("*.raw.log"))
    write_log = artifacts / "write.log"
    assert write_log.is_file()
    sanitized = write_log.read_text(encoding="utf-8")
    for private in (
        env["MINT_TEST_REPO"],
        env["HOME"],
        SYNTHETIC_UDID,
        env["MINT_TEST_PRIVATE_TEMP"],
        external_root,
    ):
        assert private not in sanitized

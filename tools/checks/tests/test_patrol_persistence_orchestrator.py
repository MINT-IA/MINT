from __future__ import annotations

import json
import os
import stat
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
ORCHESTRATOR = ROOT / "tools/simulator/patrol_persistence_process_death.sh"
WRITE_TEST = (
    ROOT
    / "apps/mobile/integration_test/g1_p0_persistence_write_patrol_test.dart"
)
READ_TEST = (
    ROOT
    / "apps/mobile/integration_test/g1_p0_persistence_read_patrol_test.dart"
)
WRITE_RUNNER = ROOT / "apps/mobile/test/patrol/g1_p0_persistence_write_runtime_test.dart"
READ_RUNNER = ROOT / "apps/mobile/test/patrol/g1_p0_persistence_read_runtime_test.dart"
MAESTRO_FLOW = ROOT / "apps/mobile/.maestro/r4_persistence.yaml"
SYNTHETIC_UDID = "B03E429D-0422-4357-B754-536637D979F9"
BUNDLE_ID = "ch.mint.app"


def _head_sha() -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def _write_executable(path: Path, source: str) -> None:
    path.write_text(source, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _fake_runtime(
    tmp_path: Path,
    *,
    patrol_exit: int = 0,
    launch_exit: int = 0,
    terminate_exit: int = 0,
) -> dict[str, str]:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    calls = tmp_path / "calls.log"
    fake_patrol = fake_bin / "patrol"
    fake_xcrun = fake_bin / "xcrun"
    _write_executable(
        fake_patrol,
        "#!/usr/bin/env bash\n"
        "printf 'patrol %s\\n' \"$*\" >> \"$MINT_TEST_CALLS\"\n"
        f"exit {patrol_exit}\n",
    )
    _write_executable(
        fake_xcrun,
        "#!/usr/bin/env bash\n"
        "printf 'xcrun %s\\n' \"$*\" >> \"$MINT_TEST_CALLS\"\n"
        f"if [[ \"${{2:-}}\" == \"launch\" ]]; then exit {launch_exit}; fi\n"
        f"exit {terminate_exit}\n",
    )
    return {
        **os.environ,
        "PATH": f"{fake_bin}:{os.environ['PATH']}",
        "PATROL_BIN": str(fake_patrol),
        "MINT_TEST_CALLS": str(calls),
    }


def _run_orchestrator(
    tmp_path: Path,
    env: dict[str, str],
    *,
    sha: str | None = None,
    include_device: bool = True,
) -> subprocess.CompletedProcess[str]:
    artifacts = tmp_path / "artifacts"
    command = ["bash", str(ORCHESTRATOR)]
    if include_device:
        command.extend(["--device", SYNTHETIC_UDID])
    command.extend(
        [
            "--bundle-id",
            BUNDLE_ID,
            "--sha",
            sha or _head_sha(),
            "--artifacts",
            str(artifacts),
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


def test_runtime_contracts_are_distinct_and_prove_real_write_then_read() -> None:
    orchestrator = ORCHESTRATOR.read_text(encoding="utf-8")
    write_test = WRITE_TEST.read_text(encoding="utf-8")
    read_test = READ_TEST.read_text(encoding="utf-8")
    write_runner = WRITE_RUNNER.read_text(encoding="utf-8")
    read_runner = READ_RUNNER.read_text(encoding="utf-8")
    maestro = MAESTRO_FLOW.read_text(encoding="utf-8")

    assert "set -euo pipefail" in orchestrator
    assert "$HOME/.pub-cache/bin/patrol" in orchestrator
    assert "integration_test/g1_p0_persistence_write_patrol_test.dart" in orchestrator
    assert "integration_test/g1_p0_persistence_read_patrol_test.dart" in orchestrator
    assert orchestrator.count("--no-uninstall") == 2
    assert "test/patrol/g1_p0_persistence_write_runtime_test.dart" in orchestrator
    assert "test/patrol/g1_p0_persistence_read_runtime_test.dart" in orchestrator
    assert orchestrator.count('xcrun simctl terminate "$device" "$bundle_id"') == 1
    assert orchestrator.count('xcrun simctl launch "$device" "$bundle_id"') == 1
    assert "rev-parse HEAD" in orchestrator
    assert "metadata.json" in orchestrator

    assert "patrolTest(" in write_test
    assert "MINT_PATROL_CLI" in write_test
    assert "ReportPersistenceService.clearDiagnostic()" in write_test
    for identifier in (
        "salary_input",
        "canton_picker",
        "birth_year_input",
        "salary_save_cta",
        "data_block_save_success",
    ):
        assert f"#{identifier}" in write_test
    assert "saveAnswers(" not in write_test

    assert "patrolTest(" in read_test
    assert "MINT_PATROL_CLI" in read_test
    assert "ReportPersistenceService" not in read_test
    assert "enterText(" not in read_test
    for identifier in ("mortgage_afford_result", "mortgage_income_amount"):
        assert f"#{identifier}" in read_test

    assert "../../integration_test/g1_p0_persistence_write_patrol_test.dart" in write_runner
    assert "persistence_write.main();" in write_runner
    assert "../../integration_test/g1_p0_persistence_read_patrol_test.dart" in read_runner
    assert "persistence_read.main();" in read_runner

    write_position = maestro.index('clearState: true')
    save_position = maestro.index('id: "salary_save_cta"')
    stop_position = maestro.index("- stopApp", save_position)
    relaunch_position = maestro.index("clearState: false", stop_position)
    consumer_position = maestro.index('id: "mortgage_income_amount"', relaunch_position)
    assert write_position < save_position < stop_position < relaunch_position < consumer_position


def test_orchestrator_runs_write_terminate_read_and_archives_metadata(
    tmp_path: Path,
) -> None:
    env = _fake_runtime(tmp_path)

    result = _run_orchestrator(tmp_path, env)

    assert result.returncode == 0, result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8").splitlines()
    assert len(calls) == 4
    assert "g1_p0_persistence_write_runtime_test.dart" in calls[0]
    assert "--no-uninstall" in calls[0]
    assert f"--device {SYNTHETIC_UDID}" in calls[0]
    assert calls[1] == f"xcrun simctl launch {SYNTHETIC_UDID} {BUNDLE_ID}"
    assert calls[2] == f"xcrun simctl terminate {SYNTHETIC_UDID} {BUNDLE_ID}"
    assert "g1_p0_persistence_read_runtime_test.dart" in calls[3]
    assert "--no-uninstall" in calls[3]
    metadata = json.loads(
        (tmp_path / "artifacts/metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["device"] == SYNTHETIC_UDID
    assert metadata["bundle_id"] == BUNDLE_ID
    assert metadata["sha"] == _head_sha()
    assert metadata["write_exit_code"] == 0
    assert metadata["launch_exit_code"] == 0
    assert metadata["terminate_exit_code"] == 0
    assert metadata["read_exit_code"] == 0
    assert metadata["synthetic_data_only"] is True


@pytest.mark.parametrize(
    ("runtime", "expected", "forbidden_call"),
    [
        ({"patrol_exit": 7}, "write stage failed", "xcrun simctl terminate"),
        ({"launch_exit": 8}, "launch stage failed", "xcrun simctl terminate"),
        ({"terminate_exit": 9}, "terminate stage failed", "g1_p0_persistence_read"),
    ],
)
def test_orchestrator_fails_closed_before_the_next_stage(
    tmp_path: Path,
    runtime: dict[str, int],
    expected: str,
    forbidden_call: str,
) -> None:
    env = _fake_runtime(tmp_path, **runtime)

    result = _run_orchestrator(tmp_path, env)

    assert result.returncode != 0
    assert expected in result.stderr
    calls = (tmp_path / "calls.log").read_text(encoding="utf-8")
    assert forbidden_call not in calls


def test_orchestrator_rejects_missing_device_and_sha_drift(tmp_path: Path) -> None:
    env = _fake_runtime(tmp_path)

    missing_device = _run_orchestrator(tmp_path, env, include_device=False)
    wrong_sha = _run_orchestrator(tmp_path, env, sha="a" * 40)

    assert missing_device.returncode != 0
    assert "--device is required" in missing_device.stderr
    assert wrong_sha.returncode != 0
    assert "must equal current HEAD" in wrong_sha.stderr

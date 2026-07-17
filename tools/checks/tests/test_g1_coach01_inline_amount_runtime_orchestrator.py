from __future__ import annotations

import json
import os
import stat
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
INTEGRATION = (
    ROOT
    / "apps/mobile/integration_test/g1_coach01_inline_amount_patrol_test.dart"
)
WRAPPER = (
    ROOT
    / "apps/mobile/test/patrol/g1_coach01_inline_amount_runtime_test.dart"
)
RUNNER = ROOT / "tools/simulator/patrol_coach01_inline_amount.sh"
SHA = "c" * 40
BUNDLE_ID = "ch.mint.app"
DEVICE = "C01C0123-4567-489A-BCDE-F0123456789A"
UTC_STAMP = "20260717T143000Z"


def _write_executable(path: Path, source: str) -> None:
    path.write_text(source, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _fake_runtime(tmp_path: Path) -> dict[str, str]:
    repo = tmp_path / "repo"
    mobile = repo / "apps/mobile"
    for relative in (
        "integration_test/g1_coach01_inline_amount_patrol_test.dart",
        "test/patrol/g1_coach01_inline_amount_runtime_test.dart",
    ):
        target = mobile / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("tracked synthetic runtime contract\n", encoding="utf-8")
    simulator = repo / "tools/simulator"
    simulator.mkdir(parents=True)
    (simulator / RUNNER.name).write_text(
        "tracked synthetic runtime runner\n",
        encoding="utf-8",
    )

    fake_home = tmp_path / "private-home"
    fake_patrol = fake_home / ".pub-cache/bin/patrol"
    fake_patrol.parent.mkdir(parents=True)
    calls = tmp_path / "calls.log"
    _write_executable(
        fake_patrol,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'patrol cwd=%s args=%s\\n\' "$PWD" "$*" >> "$MINT_TEST_CALLS"\n'
        'printf \'private repo=%s home=%s device=%s tmp=%s\\n\' '
        '"$MINT_TEST_REPO" "$HOME" "$MINT_TEST_DEVICE" "${TMPDIR:-/tmp}"\n',
    )

    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    _write_executable(
        fake_bin / "git",
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'git %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "$*" == *"rev-parse --show-toplevel"* ]]; then\n'
        '  printf \'%s\\n\' "$MINT_TEST_REPO"\n'
        'elif [[ "$*" == *"rev-parse HEAD"* ]]; then\n'
        '  printf \'%s\\n\' "$MINT_TEST_SHA"\n'
        'elif [[ "$*" == *"status --porcelain"* ]]; then\n'
        '  if [[ "${MINT_TEST_DIRTY:-0}" == "1" ]]; then printf \' M tracked.dart\\n\'; fi\n'
        'elif [[ "$*" == *"ls-files --error-unmatch"* ]]; then\n'
        '  if [[ "${MINT_TEST_UNTRACKED:-0}" == "1" ]]; then exit 1; fi\n'
        'elif [[ "$*" == *"diff --quiet"* ]]; then\n'
        '  exit 0\n'
        'else\n'
        '  exit 91\n'
        'fi\n',
    )
    _write_executable(
        fake_bin / "xcrun",
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'xcrun %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "$*" == "simctl list devices booted" ]]; then\n'
        '  printf \'iPhone Synthetic (%s) (Booted)\\n\' "$MINT_TEST_DEVICE"\n'
        'elif [[ "${1:-}" == "simctl" && "${2:-}" == "io" '
        '&& "${3:-}" == "$MINT_TEST_DEVICE" && "${4:-}" == "screenshot" ]]; then\n'
        '  printf \'synthetic-png\\n\' > "${5:?missing screenshot path}"\n'
        'else\n'
        '  exit 92\n'
        'fi\n',
    )

    env = os.environ.copy()
    env.update(
        {
            "HOME": str(fake_home),
            "PATH": f"{fake_bin}:{env['PATH']}",
            "TMPDIR": str(tmp_path / "private-tmp"),
            "MINT_TEST_CALLS": str(calls),
            "MINT_TEST_REPO": str(repo),
            "MINT_TEST_SHA": SHA,
            "MINT_TEST_DEVICE": DEVICE,
        }
    )
    Path(env["TMPDIR"]).mkdir()
    return {
        "repo": str(repo),
        "home": str(fake_home),
        "calls": str(calls),
        "env": env,
    }


def _run(
    runtime: dict[str, str],
    *,
    sha: str = SHA,
    artifacts: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    repo = Path(runtime["repo"])
    output = artifacts or (
        repo
        / ".planning/runtime-evidence/phase-37/coach-01"
        / f"runtime-{sha[:10]}-{UTC_STAMP}"
    )
    return subprocess.run(
        [
            str(RUNNER),
            "--device",
            DEVICE,
            "--bundle-id",
            BUNDLE_ID,
            "--sha",
            sha,
            "--artifacts",
            str(output),
        ],
        cwd=repo,
        env=runtime["env"],
        text=True,
        capture_output=True,
        check=False,
        timeout=30,
    )


def test_runtime_contract_uses_real_coach_chain_and_cold_report_persistence() -> None:
    integration = INTEGRATION.read_text(encoding="utf-8")
    wrapper = WRAPPER.read_text(encoding="utf-8")

    for token in (
        "patrolTest(",
        "bool.fromEnvironment('MINT_PATROL_CLI')",
        "CoachChatScreen",
        "CoachLlmService.registerOrchestrator",
        "name: 'ask_user_input'",
        "field_key': 'salaireBrut'",
        "ChatAmountInput",
        "ReportPersistenceService.saveAnswers",
        "'q_nombre_mois': 12",
        "'120000'",
        "q_gross_salary_annual",
        "CoachProfileProvider()",
        "loadFromWizard()",
        "ProfileDataSource.userInput",
        "salaireBrutMensuel",
    ):
        assert token in integration
    assert integration.count("CoachProfileProvider()") >= 2
    assert "g1_coach01_inline_amount_patrol_test.dart" in wrapper


def test_runner_executes_exact_sha_and_publishes_only_sanitized_artifacts(
    tmp_path: Path,
) -> None:
    runtime = _fake_runtime(tmp_path)
    result = _run(runtime)

    assert result.returncode == 0, result.stderr
    repo = Path(runtime["repo"])
    artifacts = (
        repo
        / ".planning/runtime-evidence/phase-37/coach-01"
        / f"runtime-{SHA[:10]}-{UTC_STAMP}"
    )
    log = artifacts / "patrol.log"
    screenshot = artifacts / "final.png"
    metadata_path = artifacts / "metadata.json"
    assert log.is_file() and log.stat().st_size > 0
    assert screenshot.is_file() and screenshot.stat().st_size > 0
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    assert metadata["caseId"] == "G1-COACH-01"
    assert metadata["commitSha"] == SHA
    assert metadata["bundleId"] == BUNDLE_ID
    assert metadata["result"] == "passed"
    assert len(metadata["logSha256"]) == 64
    assert len(metadata["screenshotSha256"]) == 64

    text_artifacts = log.read_text(encoding="utf-8") + metadata_path.read_text(
        encoding="utf-8"
    )
    for secret in (runtime["repo"], runtime["home"], DEVICE, runtime["env"]["TMPDIR"]):
        assert secret not in text_artifacts
    assert "<REPO>" in text_artifacts
    assert "<HOME>" in text_artifacts
    assert "<DEVICE>" in text_artifacts

    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "$HOME/.pub-cache/bin/patrol" not in calls
    assert "test --target test/patrol/g1_coach01_inline_amount_runtime_test.dart" in calls
    assert "--no-generate-bundle" in calls
    assert "--dart-define=MINT_PATROL_CLI=true" in calls
    assert f"simctl io {DEVICE} screenshot" in calls


@pytest.mark.parametrize("failure", ["dirty", "untracked", "sha"])
def test_runner_rejects_non_exact_or_non_tracked_head(
    tmp_path: Path,
    failure: str,
) -> None:
    runtime = _fake_runtime(tmp_path)
    if failure == "dirty":
        runtime["env"]["MINT_TEST_DIRTY"] = "1"
    elif failure == "untracked":
        runtime["env"]["MINT_TEST_UNTRACKED"] = "1"

    result = _run(runtime, sha="d" * 40 if failure == "sha" else SHA)

    assert result.returncode != 0
    calls_path = Path(runtime["calls"])
    calls = calls_path.read_text(encoding="utf-8") if calls_path.exists() else ""
    assert "patrol cwd=" not in calls


def test_runner_rejects_artifacts_outside_the_case_sha_directory(
    tmp_path: Path,
) -> None:
    runtime = _fake_runtime(tmp_path)

    result = _run(runtime, artifacts=tmp_path / "unsafe-output")

    assert result.returncode != 0
    assert not (tmp_path / "unsafe-output").exists()


@pytest.mark.parametrize(
    "runtime_name",
    [
        f"runtime-{'d' * 10}-{UTC_STAMP}",
        f"runtime-{SHA[:10]}-2026-07-17T14:30:00Z",
    ],
)
def test_runner_rejects_wrong_short_sha_or_noncanonical_utc_directory(
    tmp_path: Path,
    runtime_name: str,
) -> None:
    runtime = _fake_runtime(tmp_path)
    artifacts = (
        Path(runtime["repo"])
        / ".planning/runtime-evidence/phase-37/coach-01"
        / runtime_name
    )

    result = _run(runtime, artifacts=artifacts)

    assert result.returncode != 0
    assert not artifacts.exists()

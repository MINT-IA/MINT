from __future__ import annotations

import json
import os
import re
import signal
import shutil
import stat
import subprocess
import time
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
INTEGRATION = (
    ROOT
    / "apps/mobile/integration_test/g1_scn01_scenario_isolation_patrol_test.dart"
)
WRAPPER = (
    ROOT
    / "apps/mobile/test/patrol/g1_scn01_scenario_isolation_runtime_test.dart"
)
RUNNER = ROOT / "tools/simulator/patrol_scn01_scenario_isolation.sh"
SHA = "c" * 40
BUNDLE_ID = "ch.mint.app"
DEVICE = "5C010123-4567-489A-BCDE-F0123456789A"
UTC_STAMP = "20260717T143000Z"
VISUAL_MARKER_NAME = "mint-g1-scn01-visual-ready-v1.marker"
VISUAL_MARKER_PAYLOAD = "MINT_G1_SCN01_VISUAL_READY_V1\n"


def _write_executable(path: Path, source: str) -> None:
    path.write_text(source, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _fake_runtime(tmp_path: Path) -> dict[str, str]:
    repo = tmp_path / "repo"
    mobile = repo / "apps/mobile"
    for relative in (
        "integration_test/g1_scn01_scenario_isolation_patrol_test.dart",
        "test/patrol/g1_scn01_scenario_isolation_runtime_test.dart",
    ):
        target = mobile / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("tracked synthetic runtime contract\n", encoding="utf-8")
    original_build = mobile / "build"
    original_build.mkdir()
    (original_build / "original-sentinel.txt").write_text(
        "original build must survive\n",
        encoding="utf-8",
    )
    simulator = repo / "tools/simulator"
    simulator.mkdir(parents=True)
    (simulator / RUNNER.name).write_text(
        "tracked synthetic runtime runner\n",
        encoding="utf-8",
    )

    fake_home = tmp_path / "private-home"
    app_container = (
        fake_home
        / "Library/Developer/CoreSimulator/Devices"
        / DEVICE
        / "data/Containers/Data/Application/AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE"
    )
    app_tmp = app_container / "tmp"
    app_tmp.mkdir(parents=True)
    visual_marker = app_tmp / VISUAL_MARKER_NAME
    visual_marker.write_text(VISUAL_MARKER_PAYLOAD, encoding="utf-8")
    fake_patrol = fake_home / ".pub-cache/bin/patrol"
    fake_patrol.parent.mkdir(parents=True)
    calls = tmp_path / "calls.log"
    _write_executable(
        fake_patrol,
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'patrol cwd=%s args=%s\\n\' "$PWD" "$*" >> "$MINT_TEST_CALLS"\n'
        'if [[ "${MINT_TEST_PATROL_SLEEP:-0}" -gt 0 ]]; then\n'
        '  sleep "$MINT_TEST_PATROL_SLEEP"\n'
        'fi\n'
        '[[ "${1:-}" == "--verbose" && "${2:-}" == "build" '
        '&& "${3:-}" == "ios" ]] || exit 60\n'
        '[[ "$*" == *"--target '
        'test/patrol/g1_scn01_scenario_isolation_runtime_test.dart"* ]] || exit 61\n'
        '[[ "$*" == *"--simulator"* ]] || exit 62\n'
        '[[ "$*" == *"--bundle-id ch.mint.app"* ]] || exit 63\n'
        '[[ "$*" == *"--dart-define=MINT_PATROL_CLI=true"* ]] || exit 64\n'
        'build_target="$(readlink build 2>/dev/null || true)"\n'
        '[[ -L build && -d "$build_target" ]] || exit 66\n'
        'case "$build_target" in "$MINT_TEST_REPO"/*) exit 67 ;; esac\n'
        'printf \'patrol external_build=%s\\n\' "$build_target" '
        '>> "$MINT_TEST_CALLS"\n'
        'printf \'private repo=%s home=%s device=%s tmp=%s\\n\' '
        '"$MINT_TEST_REPO" "$HOME" "$MINT_TEST_DEVICE" "${TMPDIR:-/tmp}"\n'
        'build_exit="${MINT_TEST_PATROL_EXIT:-0}"\n'
        'if [[ "$build_exit" -ne 0 ]]; then exit "$build_exit"; fi\n'
        'products="$build_target/ios_integ/Build/Products"\n'
        'runner="$products/Debug-iphonesimulator/Runner.app"\n'
        'product_mode="${MINT_TEST_BUILD_PRODUCT:-complete}"\n'
        'if [[ "$product_mode" != "runner" ]]; then\n'
        '  mkdir -p "$runner"\n'
        '  if [[ "$product_mode" != "asset" ]]; then\n'
        '    mkdir -p "$runner/Frameworks/App.framework/flutter_assets"\n'
        '    printf \'synthetic asset manifest\\n\' '
        '> "$runner/Frameworks/App.framework/flutter_assets/AssetManifest.bin"\n'
        '  fi\n'
        'fi\n'
        'if [[ "$product_mode" != "xctestrun" ]]; then\n'
        '  mkdir -p "$products"\n'
        '  printf \'synthetic xctestrun\\n\' > "$products/Runner.xctestrun"\n'
        '  if [[ "$product_mode" == "multiple_xctestrun" ]]; then\n'
        '    printf \'duplicate xctestrun\\n\' > "$products/Runner-2.xctestrun"\n'
        '  fi\n'
        'fi\n',
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
        'elif [[ "$*" == *"ls-files --others"* ]]; then\n'
        '  bundle="$MINT_TEST_REPO/apps/mobile/test/patrol/test_bundle.dart"\n'
        '  if [[ -e "$bundle" || -L "$bundle" ]]; then\n'
        '    printf \'apps/mobile/test/patrol/test_bundle.dart\\n\'\n'
        '  fi\n'
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
        'elif [[ "${1:-}" == "simctl" && "${2:-}" == "get_app_container" '
        '&& "${3:-}" == "$MINT_TEST_DEVICE" && "${4:-}" == "ch.mint.app" '
        '&& "${5:-}" == "data" ]]; then\n'
        '  printf \'%s\\n\' "$MINT_TEST_APP_CONTAINER"\n'
        'elif [[ "${1:-}" == "simctl" && "${2:-}" == "io" '
        '&& "${3:-}" == "$MINT_TEST_DEVICE" && "${4:-}" == "screenshot" ]]; then\n'
        '  [[ -f "$MINT_TEST_VISUAL_MARKER" ]] || exit 93\n'
        '  if [[ "${MINT_TEST_SCREENSHOT_EXIT:-0}" -ne 0 ]]; then\n'
        '    exit "$MINT_TEST_SCREENSHOT_EXIT"\n'
        '  fi\n'
        '  printf \'synthetic-png\\n\' > "${5:?missing screenshot path}"\n'
        'else\n'
        '  exit 92\n'
        'fi\n',
    )
    _write_executable(
        fake_bin / "xcodebuild",
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n"
        'printf \'xcodebuild %s\\n\' "$*" >> "$MINT_TEST_CALLS"\n'
        '[[ "${1:-}" == "test-without-building" ]] || exit 71\n'
        'shift\n'
        'xctestrun=\'\'\n'
        'only_testing=\'\'\n'
        'destination=\'\'\n'
        'result_bundle=\'\'\n'
        'while (($#)); do\n'
        '  case "$1" in\n'
        '    -xctestrun) xctestrun="${2:?}"; shift 2 ;;\n'
        '    -only-testing) only_testing="${2:?}"; shift 2 ;;\n'
        '    -destination) destination="${2:?}"; shift 2 ;;\n'
        '    -resultBundlePath) result_bundle="${2:?}"; shift 2 ;;\n'
        '    *) exit 72 ;;\n'
        '  esac\n'
        'done\n'
        '[[ -f "$xctestrun" ]] || exit 73\n'
        '[[ "$only_testing" == "RunnerUITests/RunnerUITests" ]] || exit 74\n'
        '[[ "$destination" == "platform=iOS Simulator,id=$MINT_TEST_DEVICE" ]] '
        '|| exit 75\n'
        'case "$xctestrun" in "$MINT_TEST_REPO"/*) exit 76 ;; esac\n'
        'case "$result_bundle" in "$MINT_TEST_REPO"/*) exit 77 ;; esac\n'
        '[[ ! -e "$MINT_TEST_VISUAL_MARKER" '
        '&& ! -L "$MINT_TEST_VISUAL_MARKER" ]] || exit 78\n'
        'printf \'private xctestrun=%s result=%s device=%s\\n\' '
        '"$xctestrun" "$result_bundle" "$MINT_TEST_DEVICE"\n'
        'if [[ "${MINT_TEST_XCODE_SLEEP:-0}" -gt 0 ]]; then\n'
        '  sleep "$MINT_TEST_XCODE_SLEEP"\n'
        'fi\n'
        'if [[ "${MINT_TEST_XCODE_NO_MARKER:-0}" != "1" ]]; then\n'
        '  if [[ "${MINT_TEST_XCODE_BAD_MARKER:-0}" == "1" ]]; then\n'
        '    printf \'INVALID_VISUAL_MARKER\\n\' > "$MINT_TEST_VISUAL_MARKER"\n'
        '  else\n'
        '    printf \'%s\' "$MINT_TEST_VISUAL_MARKER_PAYLOAD" '
        '> "$MINT_TEST_VISUAL_MARKER"\n'
        '  fi\n'
        '  printf \'xcodebuild marker-ready\\n\' >> "$MINT_TEST_CALLS"\n'
        '  for _ in $(seq 1 100); do\n'
        '    [[ ! -e "$MINT_TEST_VISUAL_MARKER" '
        '&& ! -L "$MINT_TEST_VISUAL_MARKER" ]] && break\n'
        '    sleep 0.02\n'
        '  done\n'
        '  [[ ! -e "$MINT_TEST_VISUAL_MARKER" '
        '&& ! -L "$MINT_TEST_VISUAL_MARKER" ]] || exit 79\n'
        '  printf \'xcodebuild marker-acked\\n\' >> "$MINT_TEST_CALLS"\n'
        'fi\n'
        'if [[ "${MINT_TEST_XCODE_NO_RESULT:-0}" != "1" ]]; then\n'
        '  mkdir -p "$result_bundle"\n'
        '  printf \'synthetic xcresult\\n\' > "$result_bundle/result.txt"\n'
        'fi\n'
        'printf \'xcodebuild finished\\n\' >> "$MINT_TEST_CALLS"\n'
        'exit "${MINT_TEST_XCODE_EXIT:-0}"\n',
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
            "MINT_TEST_APP_CONTAINER": str(app_container),
            "MINT_TEST_VISUAL_MARKER": str(visual_marker),
            "MINT_TEST_VISUAL_MARKER_PAYLOAD": VISUAL_MARKER_PAYLOAD,
        }
    )
    Path(env["TMPDIR"]).mkdir()
    return {
        "repo": str(repo),
        "home": str(fake_home),
        "calls": str(calls),
        "visual_marker": str(visual_marker),
        "env": env,
    }


def _artifacts(runtime: dict[str, str], sha: str = SHA) -> Path:
    return (
        Path(runtime["repo"])
        / ".planning/runtime-evidence/phase-37/scn-01"
        / f"runtime-{sha[:10]}-{UTC_STAMP}"
    )


def _build_backup(runtime: dict[str, str]) -> Path:
    return (
        Path(runtime["repo"])
        / "apps/mobile/.dart_tool"
        / f"mint-patrol-g1-scn01-build-backup-{SHA}"
    )


def _assert_build_restored(runtime: dict[str, str], *, originally_present: bool = True) -> None:
    build = Path(runtime["repo"]) / "apps/mobile/build"
    assert not build.is_symlink()
    if originally_present:
        assert build.is_dir()
        assert (build / "original-sentinel.txt").read_text(encoding="utf-8") == (
            "original build must survive\n"
        )
        assert not (build / "ios_integ").exists()
    else:
        assert not build.exists()
    assert not _build_backup(runtime).exists()
    assert not list(Path(runtime["env"]["TMPDIR"]).glob("mint-scn01-build.*"))


def _runner_command(
    runtime: dict[str, str],
    *,
    sha: str = SHA,
    artifacts: Path | None = None,
) -> list[str]:
    return [
        str(RUNNER),
        "--device",
        DEVICE,
        "--bundle-id",
        BUNDLE_ID,
        "--sha",
        sha,
        "--artifacts",
        str(artifacts or _artifacts(runtime, sha)),
    ]


def _run(
    runtime: dict[str, str],
    *,
    sha: str = SHA,
    artifacts: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        _runner_command(runtime, sha=sha, artifacts=artifacts),
        cwd=runtime["repo"],
        env=runtime["env"],
        text=True,
        capture_output=True,
        check=False,
        timeout=30,
    )


def test_versioned_runner_exists_before_runtime_execution() -> None:
    assert RUNNER.is_file(), "SCN-01 runtime runner must be checked in"
    assert os.access(RUNNER, os.X_OK), "SCN-01 runtime runner must be executable"


def test_runtime_contract_proves_stale_scenario_isolation_and_visual_handshake() -> None:
    integration = INTEGRATION.read_text(encoding="utf-8")
    wrapper = WRAPPER.read_text(encoding="utf-8")

    for token in (
        "import 'dart:io';",
        "patrolTest(",
        "bool.fromEnvironment('MINT_PATROL_CLI')",
        "RenteVsCapitalScreen",
        "_SyntheticStaleProfileProvider",
        "ScenarioSessionProvider(",
        "ScenarioSessionStore(",
        "rvc_scenario_unavailable",
        "cache.readCount, 0",
        "cache.writeCount, 0",
        "cache.clearCount, 0",
        "sessionFor(ScenarioKind.renteCapital)",
        "find.byType(TextField",
        "find.byType(Slider",
        "RegExp(r'CHF|\\d')",
        "_visualReadyMarkerName",
        "Directory.systemTemp",
        "MINT_G1_SCN01_VISUAL_READY_V1\\n",
        "flush: true",
        "visualReadyMarker.delete()",
        "Duration(seconds: 90)",
        "visual evidence acknowledgement",
    ):
        assert token in integration
    assert integration.index("_expectUnavailableWithoutFinancialData(") < integration.index(
        "visualReadyMarker.writeAsString"
    )
    assert "g1_scn01_scenario_isolation_patrol_test.dart" in wrapper


def test_runner_executes_exact_sha_and_publishes_only_sanitized_artifacts(
    tmp_path: Path,
) -> None:
    runtime = _fake_runtime(tmp_path)
    result = _run(runtime)

    assert result.returncode == 0, result.stderr
    repo = Path(runtime["repo"])
    artifacts = _artifacts(runtime)
    generated_bundle = repo / "apps/mobile/test/patrol/test_bundle.dart"
    assert not generated_bundle.exists()
    _assert_build_restored(runtime)
    log = artifacts / "patrol.log"
    screenshot = artifacts / "final.png"
    metadata_path = artifacts / "metadata.json"
    assert log.is_file() and log.stat().st_size > 0
    assert screenshot.is_file() and screenshot.stat().st_size > 0
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    assert metadata["caseId"] == "G1-SCN-01"
    assert metadata["commitSha"] == SHA
    assert metadata["bundleId"] == BUNDLE_ID
    assert metadata["patrolTarget"] == (
        "test/patrol/g1_scn01_scenario_isolation_runtime_test.dart"
    )
    assert metadata["result"] == "passed"
    assert metadata["device"] == "<redacted>"
    assert len(metadata["logSha256"]) == 64
    assert len(metadata["screenshotSha256"]) == 64

    text_artifacts = log.read_text(encoding="utf-8") + metadata_path.read_text(
        encoding="utf-8"
    )
    for secret in (runtime["repo"], runtime["home"], DEVICE, runtime["env"]["TMPDIR"]):
        assert secret not in text_artifacts
    assert re.search(
        r"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b",
        text_artifacts,
    ) is None
    assert "<REPO>" in text_artifacts
    assert "<HOME>" in text_artifacts
    assert "<DEVICE>" in text_artifacts

    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "$HOME/.pub-cache/bin/patrol" not in calls
    assert (
        "build ios --target test/patrol/g1_scn01_scenario_isolation_runtime_test.dart"
        in calls
    )
    assert "--simulator" in calls
    assert "patrol cwd=" in calls
    assert "patrol cwd=" in calls and " args=test " not in calls
    assert "--dart-define=MINT_PATROL_CLI=true" in calls
    assert "xcodebuild test-without-building -xctestrun " in calls
    assert "-only-testing RunnerUITests/RunnerUITests" in calls
    assert f"-destination platform=iOS Simulator,id={DEVICE}" in calls
    assert "-resultBundlePath " in calls
    assert f"simctl io {DEVICE} screenshot" in calls
    assert f"simctl get_app_container {DEVICE} {BUNDLE_ID} data" in calls
    assert "patrol external_build=" in calls
    assert calls.count("rev-parse HEAD") >= 3
    assert "ls-files --others --exclude-standard -- apps/mobile" in calls
    marker_ready = calls.index("xcodebuild marker-ready")
    screenshot = calls.index(f"simctl io {DEVICE} screenshot")
    marker_acked = calls.index("xcodebuild marker-acked")
    xcode_finished = calls.index("xcodebuild finished")
    assert marker_ready < screenshot < marker_acked < xcode_finished
    assert not Path(runtime["visual_marker"]).exists()


def test_runner_writes_sanitized_build_failure_metadata(
    tmp_path: Path,
) -> None:
    runtime = _fake_runtime(tmp_path)
    runtime["env"]["MINT_TEST_PATROL_EXIT"] = "9"

    result = _run(runtime)

    assert result.returncode == 9
    bundle = Path(runtime["repo"]) / "apps/mobile/test/patrol/test_bundle.dart"
    assert not bundle.exists()
    _assert_build_restored(runtime)
    artifacts = _artifacts(runtime)
    assert not (artifacts / "final.png").exists()
    metadata_path = artifacts / "metadata.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    assert metadata["result"] == "failed"
    assert metadata["screenshotSha256"] is None
    log = (artifacts / "patrol.log").read_text(encoding="utf-8")
    for secret in (
        runtime["repo"],
        runtime["home"],
        DEVICE,
        runtime["env"]["TMPDIR"],
    ):
        assert secret not in log
    assert "<DEVICE>" in log
    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "args=--verbose build ios" in calls
    assert "xcodebuild " not in calls


def test_runner_preserves_xcode_test_failure_and_restores_build(tmp_path: Path) -> None:
    runtime = _fake_runtime(tmp_path)
    runtime["env"]["MINT_TEST_XCODE_EXIT"] = "8"

    result = _run(runtime)

    assert result.returncode == 8
    _assert_build_restored(runtime)
    metadata = json.loads(
        (_artifacts(runtime) / "metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["result"] == "failed"
    assert metadata["screenshotSha256"] is None
    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "xcodebuild test-without-building" in calls
    assert f"-destination platform=iOS Simulator,id={DEVICE}" in calls
    assert not Path(runtime["visual_marker"]).exists()


@pytest.mark.parametrize(
    "product_mode",
    ["runner", "asset", "xctestrun", "multiple_xctestrun"],
)
def test_runner_fails_closed_on_missing_or_ambiguous_build_product(
    tmp_path: Path,
    product_mode: str,
) -> None:
    runtime = _fake_runtime(tmp_path)
    runtime["env"]["MINT_TEST_BUILD_PRODUCT"] = product_mode

    result = _run(runtime)

    assert result.returncode != 0
    _assert_build_restored(runtime)
    metadata = json.loads(
        (_artifacts(runtime) / "metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["result"] == "failed"
    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "args=--verbose build ios" in calls
    assert "xcodebuild " not in calls


def test_runner_fails_when_xcodebuild_omits_the_result_bundle(tmp_path: Path) -> None:
    runtime = _fake_runtime(tmp_path)
    runtime["env"]["MINT_TEST_XCODE_NO_RESULT"] = "1"

    result = _run(runtime)

    assert result.returncode == 2
    _assert_build_restored(runtime)
    metadata = json.loads(
        (_artifacts(runtime) / "metadata.json").read_text(encoding="utf-8")
    )
    assert metadata["result"] == "failed"
    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "xcodebuild test-without-building" in calls
    assert not Path(runtime["visual_marker"]).exists()


def test_runner_fails_closed_when_visual_marker_never_appears(tmp_path: Path) -> None:
    runtime = _fake_runtime(tmp_path)
    runtime["env"]["MINT_TEST_XCODE_NO_MARKER"] = "1"

    result = _run(runtime)

    assert result.returncode == 2
    _assert_build_restored(runtime)
    artifacts = _artifacts(runtime)
    assert not (artifacts / "final.png").exists()
    metadata = json.loads((artifacts / "metadata.json").read_text(encoding="utf-8"))
    assert metadata["result"] == "failed"
    assert metadata["screenshotSha256"] is None
    assert len(metadata["logSha256"]) == 64
    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert f"simctl io {DEVICE} screenshot" not in calls
    assert not Path(runtime["visual_marker"]).exists()


def test_runner_acks_marker_but_fails_closed_when_screenshot_fails(
    tmp_path: Path,
) -> None:
    runtime = _fake_runtime(tmp_path)
    runtime["env"]["MINT_TEST_SCREENSHOT_EXIT"] = "7"

    result = _run(runtime)

    assert result.returncode == 2
    _assert_build_restored(runtime)
    artifacts = _artifacts(runtime)
    assert not (artifacts / "final.png").exists()
    metadata = json.loads((artifacts / "metadata.json").read_text(encoding="utf-8"))
    assert metadata["result"] == "failed"
    assert metadata["screenshotSha256"] is None
    assert len(metadata["logSha256"]) == 64
    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "xcodebuild marker-ready" in calls
    assert f"simctl io {DEVICE} screenshot" in calls
    assert "xcodebuild marker-acked" in calls
    assert not Path(runtime["visual_marker"]).exists()
    log = (artifacts / "patrol.log").read_text(encoding="utf-8")
    for secret in (
        runtime["repo"],
        runtime["home"],
        DEVICE,
        runtime["env"]["TMPDIR"],
    ):
        assert secret not in log


def test_runner_rejects_and_cleans_a_marker_with_invalid_payload(
    tmp_path: Path,
) -> None:
    runtime = _fake_runtime(tmp_path)
    runtime["env"]["MINT_TEST_XCODE_BAD_MARKER"] = "1"

    result = _run(runtime)

    assert result.returncode == 2
    _assert_build_restored(runtime)
    artifacts = _artifacts(runtime)
    assert not (artifacts / "final.png").exists()
    metadata = json.loads((artifacts / "metadata.json").read_text(encoding="utf-8"))
    assert metadata["result"] == "failed"
    assert metadata["screenshotSha256"] is None
    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "xcodebuild marker-ready" in calls
    assert f"simctl io {DEVICE} screenshot" not in calls
    assert not Path(runtime["visual_marker"]).exists()


def test_runner_refuses_and_preserves_a_preexisting_bundle(tmp_path: Path) -> None:
    runtime = _fake_runtime(tmp_path)
    bundle = Path(runtime["repo"]) / "apps/mobile/test/patrol/test_bundle.dart"
    bundle.write_text("preexisting bundle must survive\n", encoding="utf-8")

    result = _run(runtime)

    assert result.returncode != 0
    assert bundle.read_text(encoding="utf-8") == "preexisting bundle must survive\n"
    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "patrol cwd=" not in calls


def test_runner_supports_an_initially_absent_build_directory(tmp_path: Path) -> None:
    runtime = _fake_runtime(tmp_path)
    shutil.rmtree(Path(runtime["repo"]) / "apps/mobile/build")

    result = _run(runtime)

    assert result.returncode == 0, result.stderr
    _assert_build_restored(runtime, originally_present=False)


@pytest.mark.parametrize("state", ["symlink", "file", "backup"])
def test_runner_refuses_ambiguous_build_or_backup_state(
    tmp_path: Path,
    state: str,
) -> None:
    runtime = _fake_runtime(tmp_path)
    build = Path(runtime["repo"]) / "apps/mobile/build"
    backup = _build_backup(runtime)
    if state == "symlink":
        shutil.rmtree(build)
        outside = tmp_path / "preexisting-build-target"
        outside.mkdir()
        build.symlink_to(outside)
    elif state == "file":
        shutil.rmtree(build)
        build.write_text("ambiguous build file\n", encoding="utf-8")
    else:
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.mkdir()
        (backup / "preexisting.txt").write_text("keep\n", encoding="utf-8")

    result = _run(runtime)

    assert result.returncode != 0
    if state == "symlink":
        assert build.is_symlink()
    elif state == "file":
        assert build.read_text(encoding="utf-8") == "ambiguous build file\n"
    else:
        assert (backup / "preexisting.txt").read_text(encoding="utf-8") == "keep\n"
    calls = Path(runtime["calls"]).read_text(encoding="utf-8")
    assert "patrol cwd=" not in calls


def test_runner_restores_build_when_signalled_during_patrol_build(
    tmp_path: Path,
) -> None:
    runtime = _fake_runtime(tmp_path)
    runtime["env"]["MINT_TEST_PATROL_SLEEP"] = "30"
    process = subprocess.Popen(
        _runner_command(runtime),
        cwd=runtime["repo"],
        env=runtime["env"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    deadline = time.monotonic() + 5
    calls_path = Path(runtime["calls"])
    while time.monotonic() < deadline and process.poll() is None:
        calls = calls_path.read_text(encoding="utf-8") if calls_path.exists() else ""
        if "patrol cwd=" in calls:
            break
        time.sleep(0.05)
    else:
        pytest.fail(f"Patrol build did not start: {process.communicate(timeout=2)}")
    assert process.poll() is None

    process.send_signal(signal.SIGTERM)
    process.communicate(timeout=5)

    assert process.returncode != 0
    bundle = Path(runtime["repo"]) / "apps/mobile/test/patrol/test_bundle.dart"
    assert not bundle.exists()
    _assert_build_restored(runtime)


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
        / ".planning/runtime-evidence/phase-37/scn-01"
        / runtime_name
    )

    result = _run(runtime, artifacts=artifacts)

    assert result.returncode != 0
    assert not artifacts.exists()

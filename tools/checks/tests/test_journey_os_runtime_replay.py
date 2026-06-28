from __future__ import annotations

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools/simulator/journey_os_runtime_replay.sh"


def _run(*args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(SCRIPT), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        env=env,
    )


def test_core_dry_run_lists_core_flows() -> None:
    proc = _run("--dry-run")

    assert proc.returncode == 0
    assert "dry-run set=core" in proc.stdout
    assert "money_truth_spine" in proc.stdout
    assert "profile_privacy_control" in proc.stdout
    assert "onboarding_first_value" in proc.stdout


def test_top_dry_run_lists_current_top_actionable_flow() -> None:
    proc = _run("--dry-run", "--set", "top")

    assert proc.returncode == 0
    assert "dry-run set=top" in proc.stdout
    assert "coach_advice_turn" in proc.stdout
    assert "flow_jos004_coach_advice_turn_runtime.yaml" in proc.stdout
    assert "MINT_E2E_ARCHETYPE=cadre_salarie_lpp_suisse_ready" in proc.stdout


def test_authenticated_dry_run_lists_authenticated_flows_without_secrets() -> None:
    env = {key: value for key, value in os.environ.items() if key not in {"MINT_E2E_EMAIL", "MINT_E2E_PASSWORD"}}

    proc = _run("--dry-run", "--set", "authenticated", env=env)

    assert proc.returncode == 0
    assert "coach_advice_turn" in proc.stdout
    assert "account_lifecycle_delete" not in proc.stdout


def test_account_lifecycle_dry_run_is_separate_from_authenticated_set() -> None:
    env = {key: value for key, value in os.environ.items() if key not in {"MINT_E2E_EMAIL", "MINT_E2E_PASSWORD"}}

    proc = _run("--dry-run", "--set", "account_lifecycle", env=env)

    assert proc.returncode == 0
    assert "account_lifecycle_delete" in proc.stdout
    assert "coach_advice_turn" not in proc.stdout


def test_requires_auth_classifier_reports_runtime_set_auth_need() -> None:
    assert _run("--requires-auth", "--set", "core").stdout.strip() == "false"
    assert _run("--requires-auth", "--set", "top").stdout.strip() == "true"
    assert _run("--requires-auth", "--set", "authenticated").stdout.strip() == "true"
    assert _run("--requires-auth", "--set", "account_lifecycle").stdout.strip() == "true"


def test_authenticated_real_run_requires_credentials_before_build() -> None:
    env = {key: value for key, value in os.environ.items() if key not in {"MINT_E2E_EMAIL", "MINT_E2E_PASSWORD"}}

    proc = _run("--set", "authenticated", env=env)

    assert proc.returncode == 1
    assert "authenticated replay requires MINT_E2E_EMAIL" in proc.stderr


def test_top_real_run_requires_credentials_when_top_is_authenticated() -> None:
    env = {key: value for key, value in os.environ.items() if key not in {"MINT_E2E_EMAIL", "MINT_E2E_PASSWORD"}}

    proc = _run("--set", "top", env=env)

    assert proc.returncode == 1
    assert "authenticated replay requires MINT_E2E_EMAIL" in proc.stderr


def test_unknown_runtime_set_fails_before_build() -> None:
    proc = _run("--dry-run", "--set", "unknown")

    assert proc.returncode == 2
    assert "unknown Journey OS runtime set" in proc.stderr


def test_top_runtime_set_can_be_empty_after_all_actionable_issues_close() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    assert 'if runtime_set == "top":' in text
    assert "raise SystemExit(0)" in text


def test_real_replay_rejects_dirty_worktree_before_build() -> None:
    marker = ROOT / ".journey-os-runtime-dirty-test"
    marker.write_text("dirty\n", encoding="utf-8")
    try:
        proc = _run("--set", "core")
    finally:
        marker.unlink(missing_ok=True)

    assert proc.returncode == 1
    assert "requires a clean git worktree" in proc.stderr
    assert "flutter is required" not in proc.stderr


def test_replay_script_boots_installs_and_launches_before_maestro() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    assert "xcrun simctl boot" in text
    assert "xcrun simctl bootstatus" in text
    assert "xcrun simctl install" in text
    assert "xcrun simctl launch" in text
    maestro = text.index('bash "$ROOT/tools/simulator/maestro_with_watchdog.sh"')
    assert text.index("xcrun simctl boot") < text.index("xcrun simctl bootstatus")
    assert text.index("xcrun simctl bootstatus") < text.index("xcrun simctl install")
    assert text.index("xcrun simctl install") < text.index("xcrun simctl launch")
    assert text.index("xcrun simctl launch") < maestro


def test_replay_script_can_create_missing_named_simulator() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    assert "ensure_device_udid" in text
    assert "xcrun simctl create" in text
    assert "com.apple.CoreSimulator.SimDeviceType.iPhone-13-mini" in text
    assert "resolve_status\" -ne 3" in text


def test_replay_script_is_record_driven() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    assert ".planning/journeys/records" in text
    assert "runtime_replay" in text
    assert "declare -a FLOWS" not in text


def test_replay_script_writes_runtime_manifest() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    assert "manifest.json" in text
    assert '"runtime_set": runtime_set' in text
    assert '"journeys": items' in text
    assert '"git_dirty": bool(git_status)' in text
    assert '"git_status_porcelain": git_status' in text
    assert '"git_diff_sha256": git_diff_sha256' in text
    assert '"replay_script_sha256": sha256_file' in text
    assert '"flow_sha256": sha256_file' in text
    assert 'entry["result"] = results[journey]' in text


def test_replay_script_does_not_expand_empty_auth_env_array() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    assert 'maestro_cmd+=("${maestro_env[@]}")' in text
    assert '"${maestro_env[@]}" \\' not in text


def test_replay_script_requires_clean_worktree_for_real_evidence() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    assert "capture_clean_git_state" in text
    assert "status --porcelain=v1 --untracked-files=all" in text
    assert "requires a clean git worktree" in text
    assert text.index("capture_clean_git_state") < text.index("write_manifest")


def test_replay_script_keeps_raw_debug_outside_journey_evidence() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    assert 'DEBUG_ROOT="${JOURNEY_OS_DEBUG_ROOT:-${TMPDIR:-/tmp}/mint-journey-os-runtime-debug/$STAMP}"' in text
    assert 'MINT_WALKER_ARTIFACTS="$debug_dir/watchdog"' in text
    assert '--debug-output "$debug_dir/maestro-debug"' in text
    assert 'MINT_WALKER_ARTIFACTS="$out_dir"' not in text
    assert '--debug-output "$out_dir/debug"' not in text


def test_replay_script_aggregates_multi_journey_failures() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    assert "RESULTS_FILE" in text
    assert "EXIT_STATUS=0" in text
    assert 'printf \'%s\\t%s\\t%s\\n\' "$journey" "failed" "$journey_status" >> "$RESULTS_FILE"' in text
    assert 'exit "$EXIT_STATUS"' in text

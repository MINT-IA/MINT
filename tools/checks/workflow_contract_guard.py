#!/usr/bin/env python3
"""Validate that Mint's human workflow and automated guards stay wired."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - exercised only on incomplete local envs.
    yaml = None

AGENTS = Path("AGENTS.md")
RULES = Path("rules.md")
BOOTSTRAP = Path(".claude/AGENT_BOOTSTRAP.md")
LEFTHOOK = Path("lefthook.yml")
WORKFLOW = Path(".github/workflows/ai-workflow-guards.yml")
RUNTIME_REPLAY_WORKFLOW = Path(".github/workflows/journey-os-runtime-replay.yml")
RUNTIME_REPLAY_DRY_RUN = "bash tools/simulator/journey_os_runtime_replay.sh --dry-run"
RUNTIME_REPLAY_TOP_DRY_RUN = "bash tools/simulator/journey_os_runtime_replay.sh --dry-run --set top"
RUNTIME_REPLAY_RUN = "bash tools/simulator/journey_os_runtime_replay.sh"

SESSION_COMMANDS = (
    "python3 tools/checks/active_context_guard.py",
    "python3 tools/checks/phase_contract_guard.py",
    "python3 tools/checks/mint_rules_guard.py",
    "python3 tools/checks/journey_os_check.py",
    "python3 tools/checks/workflow_contract_guard.py",
)

CI_COMMANDS = SESSION_COMMANDS + (
    "python3 tools/checks/agent_reference_guard.py",
    "python3 tools/checks/claude_hooks_guard.py",
    "python3 tools/checks/mermaid_render_guard.py",
    "python3 tools/checks/maestro_locator_audit.py",
    RUNTIME_REPLAY_DRY_RUN,
    RUNTIME_REPLAY_TOP_DRY_RUN,
    "python3 tools/checks/verify_phase_acceptance.py",
)

CI_TESTS = (
    "tools/checks/tests/test_active_context_guard.py",
    "tools/checks/tests/test_phase_contract_guard.py",
    "tools/checks/tests/test_mint_rules_guard.py",
    "tools/checks/tests/test_agent_reference_guard.py",
    "tools/checks/tests/test_claude_hooks_guard.py",
    "tools/checks/tests/test_journey_os_check.py",
    "tools/checks/tests/test_journey_os_runtime_replay.py",
    "tools/checks/tests/test_maestro_locator_audit.py",
    "tools/checks/tests/test_mermaid_render_guard.py",
    "tools/checks/tests/test_workflow_contract_guard.py",
    "tools/checks/tests/test_verify_phase_acceptance.py",
)


def _read(root: Path, rel: Path) -> str:
    return (root / rel).read_text(encoding="utf-8", errors="ignore")


def _require_all(errors: list[str], root: Path, rel: Path, needles: tuple[str, ...]) -> None:
    try:
        text = _read(root, rel)
    except OSError as exc:
        errors.append(f"unable to read {rel}: {exc}")
        return
    missing = [needle for needle in needles if needle not in text]
    if missing:
        errors.append(f"{rel} missing required workflow command(s): {', '.join(missing)}")


def _yaml_doc(errors: list[str], root: Path, rel: Path) -> object:
    if yaml is None:
        errors.append("python package pyyaml is required for workflow contract validation")
        return None
    try:
        return yaml.safe_load(_read(root, rel))
    except OSError as exc:
        errors.append(f"unable to read {rel}: {exc}")
    except yaml.YAMLError as exc:
        errors.append(f"{rel} is not valid YAML: {exc}")
    return None


def _executable_lines(text: str) -> list[str]:
    lines = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        if stripped:
            lines.append(line)
    return lines


def _run_texts(runs: list[str]) -> str:
    executable_lines = []
    for text in runs:
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            executable_lines.append(line)
    return "\n".join(executable_lines)


def _invokes_command(executable: str, command: str) -> bool:
    pattern = re.compile(
        r"^\s*"
        r"(?:[A-Za-z_][A-Za-z0-9_]*=\S+\s+)*"
        r"(?:timeout\s+\d+\s+)?"
        + re.escape(command)
        + r"(?:\s|$)",
        re.MULTILINE,
    )
    return bool(pattern.search(executable))


def _invokes_pytest_target(executable: str, target: str) -> bool:
    pattern = re.compile(
        r"^\s*"
        r"(?:[A-Za-z_][A-Za-z0-9_]*=\S+\s+)*"
        r"python3\s+-m\s+pytest\b[^\n;&|]*"
        + re.escape(target)
        + r"(?:\s|$)",
        re.MULTILINE,
    )
    return bool(pattern.search(executable))


def _require_executed_commands(errors: list[str], rel: Path, runs: list[str], needles: tuple[str, ...]) -> None:
    first_lines = [
        lines[0]
        for run in runs
        if (lines := _executable_lines(run))
    ]
    missing = [
        needle
        for needle in needles
        if not any(_invokes_command(line, needle) for line in first_lines)
    ]
    if missing:
        errors.append(f"{rel} missing required executable workflow command(s): {', '.join(missing)}")


def _require_pytest_targets(errors: list[str], rel: Path, runs: list[str], targets: tuple[str, ...]) -> None:
    executable = _run_texts(runs)
    missing = [target for target in targets if not _invokes_pytest_target(executable, target)]
    if missing:
        errors.append(f"{rel} missing required pytest target(s): {', '.join(missing)}")


def _lefthook_runs(errors: list[str], root: Path) -> list[str]:
    data = _yaml_doc(errors, root, LEFTHOOK)
    if not isinstance(data, dict):
        errors.append(f"{LEFTHOOK} must be a YAML mapping")
        return []
    pre_commit = data.get("pre-commit")
    commands = pre_commit.get("commands") if isinstance(pre_commit, dict) else None
    if not isinstance(commands, dict):
        errors.append(f"{LEFTHOOK} must define pre-commit.commands")
        return []
    runs = [
        command.get("run")
        for command in commands.values()
        if isinstance(command, dict) and isinstance(command.get("run"), str)
    ]
    if not runs:
        errors.append(f"{LEFTHOOK} must define executable pre-commit command run fields")
    return runs


def _workflow_runs(errors: list[str], root: Path) -> list[str]:
    data = _yaml_doc(errors, root, WORKFLOW)
    if not isinstance(data, dict):
        errors.append(f"{WORKFLOW} must be a YAML mapping")
        return []
    jobs = data.get("jobs")
    if not isinstance(jobs, dict):
        errors.append(f"{WORKFLOW} must define jobs")
        return []
    runs: list[str] = []
    for job in jobs.values():
        if not isinstance(job, dict):
            continue
        steps = job.get("steps")
        if not isinstance(steps, list):
            continue
        for step in steps:
            if isinstance(step, dict) and isinstance(step.get("run"), str):
                runs.append(step["run"])
    if not runs:
        errors.append(f"{WORKFLOW} must define executable step run fields")
    return runs


def _runtime_replay_errors(root: Path) -> list[str]:
    errors: list[str] = []
    try:
        text = _read(root, RUNTIME_REPLAY_WORKFLOW)
    except OSError as exc:
        return [f"unable to read {RUNTIME_REPLAY_WORKFLOW}: {exc}"]
    if re.search(r"continue-on-error\s*:\s*true", text):
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must not use continue-on-error for Journey OS replay")
    if "contents: read" not in text:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must set permissions.contents: read")
    if "get.maestro.mobile.dev" in text or re.search(r"curl[^\n|]*\|\s*bash\b", text):
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must not install Maestro through curl-to-bash")
    if "flutter-action@v2" in text:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must pin subosito/flutter-action by SHA")
    if "actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02" not in text:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must pin actions/upload-artifact and retain runtime replay evidence")
    if ".planning/journeys/evidence/runtime_replay/**" not in text:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must upload Journey OS runtime replay evidence artifacts")
    if "MAESTRO_ZIP_SHA256" not in text or "shasum -a 256 -c -" not in text:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must checksum the pinned Maestro zip")
    data = _yaml_doc(errors, root, RUNTIME_REPLAY_WORKFLOW)
    if not isinstance(data, dict):
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must be a YAML mapping")
        return errors
    trigger = data.get("on", data.get(True))
    if not (
        trigger == "workflow_dispatch"
        or (isinstance(trigger, dict) and "workflow_dispatch" in trigger)
    ):
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must expose workflow_dispatch")
    if "top" not in text:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must expose the top Journey OS runtime set")
    if "account_lifecycle" not in text:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must expose account_lifecycle separately from authenticated replay")
    if "--requires-auth" not in text:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must classify runtime sets before secret routing")
    if "requires_auth == 'false'" not in text or "requires_auth == 'true'" not in text:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must route public and authenticated runtime sets by classification")
    jobs = data.get("jobs")
    if not isinstance(jobs, dict) or not jobs:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must define jobs")
        return errors
    runs: list[str] = []
    macos_job = False
    for job in jobs.values():
        if not isinstance(job, dict):
            continue
        runner = str(job.get("runs-on", ""))
        if "macos" in runner:
            macos_job = True
        steps = job.get("steps")
        if not isinstance(steps, list):
            continue
        for step in steps:
            if isinstance(step, dict) and isinstance(step.get("run"), str):
                runs.append(step["run"])
            if isinstance(step, dict) and isinstance(step.get("env"), dict):
                env_text = "\n".join(str(value) for value in step["env"].values())
                if "secrets." in env_text and not job.get("environment"):
                    errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must protect secret-bearing replay jobs with a GitHub Environment")
    if not macos_job:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must run on macOS for iOS simulator replay")
    executable_lines = [
        line
        for run in runs
        for line in _executable_lines(run)
    ]
    has_real_replay = any(
        _invokes_command(line, RUNTIME_REPLAY_RUN) and "--dry-run" not in line and "--requires-auth" not in line
        for line in executable_lines
    )
    if not has_real_replay:
        errors.append(f"{RUNTIME_REPLAY_WORKFLOW} must execute {RUNTIME_REPLAY_RUN}")
    return errors


def check(root: Path) -> list[str]:
    errors: list[str] = []
    for rel in (AGENTS, RULES, BOOTSTRAP):
        _require_all(errors, root, rel, SESSION_COMMANDS)
    lefthook_runs = _lefthook_runs(errors, root)
    workflow_runs = _workflow_runs(errors, root)
    _require_executed_commands(errors, LEFTHOOK, lefthook_runs, SESSION_COMMANDS)
    _require_executed_commands(errors, WORKFLOW, workflow_runs, CI_COMMANDS)
    _require_pytest_targets(errors, WORKFLOW, workflow_runs, CI_TESTS)
    errors += _runtime_replay_errors(root)

    try:
        workflow = _read(root, WORKFLOW)
    except OSError:
        workflow = ""
    if "Skipping generic phase acceptance" in workflow:
        errors.append(f"{WORKFLOW} must run verify_phase_acceptance.py for the active SPEC, not skip by milestone name")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    errors = check(args.root.resolve())
    if not errors:
        print("OK workflow_contract_guard: workflow guard wiring is coherent.", file=sys.stderr)
        return 0
    print("FAIL workflow_contract_guard: workflow guard wiring drift detected.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

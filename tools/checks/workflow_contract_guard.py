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
    "python3 tools/checks/verify_phase_acceptance.py",
)

CI_TESTS = (
    "tools/checks/tests/test_active_context_guard.py",
    "tools/checks/tests/test_phase_contract_guard.py",
    "tools/checks/tests/test_mint_rules_guard.py",
    "tools/checks/tests/test_agent_reference_guard.py",
    "tools/checks/tests/test_claude_hooks_guard.py",
    "tools/checks/tests/test_journey_os_check.py",
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


def check(root: Path) -> list[str]:
    errors: list[str] = []
    for rel in (AGENTS, RULES, BOOTSTRAP):
        _require_all(errors, root, rel, SESSION_COMMANDS)
    lefthook_runs = _lefthook_runs(errors, root)
    workflow_runs = _workflow_runs(errors, root)
    _require_executed_commands(errors, LEFTHOOK, lefthook_runs, SESSION_COMMANDS)
    _require_executed_commands(errors, WORKFLOW, workflow_runs, CI_COMMANDS)
    _require_pytest_targets(errors, WORKFLOW, workflow_runs, CI_TESTS)

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

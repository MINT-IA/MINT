#!/usr/bin/env python3
"""Validate repo-local Claude hook configuration."""
from __future__ import annotations

import argparse
import json
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

SETTINGS = Path(".claude/settings.json")
REQUIRED_DENY_SIGNALS = (
    "git reset --hard",
    "git checkout --",
    "git clean",
    "git push --force",
    "rm -rf",
    "claude --bare",
    "claude --dangerously-skip-permissions",
)
FORBIDDEN_COMMAND_SNIPPETS = (
    "/Users/julienbattaglia/.nvm/",
    "/Users/julienbattaglia/Desktop/MINT.nosync",
)


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _hook_commands(settings: dict[str, Any]) -> list[str]:
    commands: list[str] = []
    for entries in settings.get("hooks", {}).values():
        if not isinstance(entries, list):
            continue
        for entry in entries:
            for hook in entry.get("hooks", []):
                command = hook.get("command")
                if isinstance(command, str):
                    commands.append(command)
    status_line = settings.get("statusLine", {})
    if isinstance(status_line, dict) and isinstance(status_line.get("command"), str):
        commands.append(status_line["command"])
    return commands


def _script_tokens(command: str, root: Path) -> list[Path]:
    try:
        tokens = shlex.split(command)
    except ValueError:
        return []
    paths: list[Path] = []
    for token in tokens:
        expanded = token.replace("$CLAUDE_PROJECT_DIR", str(root))
        if expanded.startswith("${CLAUDE_PROJECT_DIR}"):
            expanded = expanded.replace("${CLAUDE_PROJECT_DIR}", str(root), 1)
        if not (
            expanded.endswith(".js")
            or expanded.endswith(".cjs")
            or expanded.endswith(".mjs")
            or expanded.endswith(".sh")
        ):
            continue
        path = Path(expanded)
        if not path.is_absolute():
            path = root / path
        paths.append(path)
    return paths


def _syntax_check(path: Path) -> str | None:
    if path.suffix in {".js", ".cjs", ".mjs"}:
        node = shutil.which("node")
        if not node:
            return None
        proc = subprocess.run(
            [node, "--check", str(path)],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            return f"{path} failed node --check: {proc.stderr.strip()}"
    if path.suffix == ".sh":
        bash = shutil.which("bash")
        if not bash:
            return None
        proc = subprocess.run(
            [bash, "-n", str(path)],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            return f"{path} failed bash -n: {proc.stderr.strip()}"
    return None


def check(root: Path) -> list[str]:
    errors: list[str] = []
    settings_path = root / SETTINGS
    if not settings_path.exists():
        return [f"missing Claude settings: {SETTINGS}"]
    try:
        settings = _load(settings_path)
    except json.JSONDecodeError as exc:
        return [f"{SETTINGS} is not valid JSON: {exc}"]

    commands = _hook_commands(settings)
    for command in commands:
        for forbidden in FORBIDDEN_COMMAND_SNIPPETS:
            if forbidden in command:
                label = (
                    "absolute Node runtime"
                    if ".nvm" in forbidden
                    else "quarantined worktree path"
                )
                errors.append(f"{SETTINGS} hook uses {label}: {command}")
        for script in _script_tokens(command, root):
            if not script.exists():
                errors.append(f"{SETTINGS} hook references missing script: {script}")
            else:
                syntax_error = _syntax_check(script)
                if syntax_error:
                    errors.append(syntax_error)

    deny = settings.get("permissions", {}).get("deny", [])
    deny_text = "\n".join(str(item) for item in deny)
    for signal in REQUIRED_DENY_SIGNALS:
        if signal not in deny_text:
            errors.append(f"{SETTINGS} deny list missing signal: {signal}")

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    errors = check(args.root.resolve())
    if not errors:
        print("OK claude_hooks_guard: Claude hooks are coherent.", file=sys.stderr)
        return 0
    print("FAIL claude_hooks_guard: Claude hook drift detected.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())


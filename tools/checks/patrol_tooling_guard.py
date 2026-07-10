#!/usr/bin/env python3
"""Verify that MINT's Patrol gate is wired and discoverable."""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def _section(text: str, name: str) -> str:
    match = re.search(rf"^{re.escape(name)}:\s*$", text, re.MULTILINE)
    if not match:
        return ""
    start = match.end()
    next_top = re.search(r"^\S[^:\n]*:\s*$", text[start:], re.MULTILINE)
    end = start + next_top.start() if next_top else len(text)
    return text[start:end]


def _has_dev_dependency(pubspec: str, dependency: str) -> bool:
    section = _section(pubspec, "dev_dependencies")
    return re.search(rf"^\s{{2}}{re.escape(dependency)}:\s*\S+", section, re.MULTILINE) is not None


def _has_patrol_config(pubspec: str) -> bool:
    section = _section(pubspec, "patrol")
    required = (
        r"^\s{2}app_name:\s*Mint\s*$",
        r"^\s{2}test_directory:\s*test/patrol\s*$",
        r"^\s{4}bundle_id:\s*ch\.mint\.app\s*$",
    )
    return bool(section) and all(re.search(pattern, section, re.MULTILINE) for pattern in required)


def _patrol_cli_paths() -> list[Path]:
    candidates: list[Path] = []
    if path := shutil.which("patrol"):
        candidates.append(Path(path))
    candidates.append(Path.home() / ".pub-cache" / "bin" / "patrol")
    return [path for path in candidates if path.exists() and os.access(path, os.X_OK)]


def _dart_global_has_patrol_cli() -> bool:
    dart = shutil.which("dart")
    if dart is None:
        return False
    try:
        proc = subprocess.run(
            [dart, "pub", "global", "list"],
            text=True,
            capture_output=True,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return proc.returncode == 0 and "patrol_cli" in proc.stdout


def check(root: Path, *, require_cli: bool = True) -> list[str]:
    root = root.resolve()
    errors: list[str] = []
    mobile = root / "apps" / "mobile"
    pubspec = _read(mobile / "pubspec.yaml")

    if not pubspec:
        errors.append("apps/mobile/pubspec.yaml is missing or unreadable")
        return errors
    if not _has_dev_dependency(pubspec, "patrol"):
        errors.append("apps/mobile/pubspec.yaml must declare dev_dependencies.patrol")
    if not _has_patrol_config(pubspec):
        errors.append("apps/mobile/pubspec.yaml must define patrol app_name, test_directory, and iOS bundle_id")

    patrol_tests = mobile / "test" / "patrol"
    if not patrol_tests.is_dir() or not any(patrol_tests.glob("*_test.dart")):
        errors.append("apps/mobile/test/patrol must contain at least one *_test.dart")
    else:
        test_text = "\n".join(_read(path) for path in patrol_tests.glob("*_test.dart"))
        if "bool.fromEnvironment('MINT_PATROL_CLI')" not in test_text:
            errors.append("Patrol smoke tests must gate native-only patrolTest with MINT_PATROL_CLI")

    patrol_doc = _read(root / ".github" / "workflows" / "patrol.md")
    if "--dart-define=MINT_PATROL_CLI=true" not in patrol_doc:
        errors.append("Patrol runbook must pass --dart-define=MINT_PATROL_CLI=true")

    if require_cli and not _patrol_cli_paths() and not _dart_global_has_patrol_cli():
        errors.append(
            "patrol CLI not found; add $HOME/.pub-cache/bin to PATH or run "
            "`dart pub global activate patrol_cli`"
        )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--no-cli", action="store_true", help="Skip host CLI availability checks.")
    args = parser.parse_args(argv)

    errors = check(args.root, require_cli=not args.no_cli)
    if not errors:
        print("OK patrol_tooling_guard: Patrol config, tests, and CLI discovery are wired.")
        for path in _patrol_cli_paths():
            print(f"  patrol_cli: {path}")
        return 0
    print("FAIL patrol_tooling_guard: Patrol gate is not wired.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

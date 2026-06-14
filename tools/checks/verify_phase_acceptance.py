#!/usr/bin/env python3
"""Run the active phase SPEC.md acceptance commands.

The verifier is deliberately a dispatcher. It does not invent checks; it binds
the active phase spec to existing deterministic commands and reports their exit
codes.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ACTIVE_CONTEXT = Path(".planning/ACTIVE_CONTEXT.json")
VERIFY_BLOCK = re.compile(r"```verify\s*\n(?P<body>.*?)\n```", re.DOTALL)


@dataclass(frozen=True)
class Criterion:
    criterion_id: str
    command: str
    tier: str


@dataclass(frozen=True)
class Result:
    criterion: Criterion
    exit_code: int
    status: str


def _load_spec_path(root: Path) -> Path:
    manifest_path = root / ACTIVE_CONTEXT
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    spec_value = manifest.get("active_spec")
    if not spec_value:
        raise ValueError(f"{ACTIVE_CONTEXT} missing active_spec")
    spec_path = root / str(spec_value)
    if not spec_path.exists():
        raise ValueError(f"active spec does not exist: {spec_value}")
    return spec_path


def _parse_verify_block(spec_text: str) -> list[Criterion]:
    match = VERIFY_BLOCK.search(spec_text)
    if not match:
        raise ValueError("SPEC.md missing ```verify fenced block")

    tier = "deterministic"
    criteria: list[Criterion] = []
    for raw_line in match.group("body").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            tier_match = re.match(r"#\s*tier:\s*([a-zA-Z0-9_-]+)\s*$", line)
            if tier_match:
                tier = tier_match.group(1).casefold()
            continue
        if ":" not in line:
            raise ValueError(f"invalid verify line, expected id: command: {line}")
        criterion_id, command = line.split(":", maxsplit=1)
        criterion_id = criterion_id.strip()
        command = command.strip()
        if not criterion_id or not command:
            raise ValueError(f"invalid verify line, expected id: command: {line}")
        if tier not in {"deterministic", "device"}:
            raise ValueError(f"unknown verify tier {tier!r} for {criterion_id}")
        criteria.append(Criterion(criterion_id, command, tier))

    if not criteria:
        raise ValueError("SPEC.md verify block has no criteria")
    return criteria


def _run_criterion(root: Path, criterion: Criterion) -> Result:
    proc = subprocess.run(
        criterion.command,
        cwd=root,
        shell=True,
        capture_output=True,
        text=True,
    )
    if criterion.tier == "device":
        status = "DEVICE-PASS" if proc.returncode == 0 else "DEVICE-FAIL"
    else:
        status = "PASS" if proc.returncode == 0 else "FAIL"
    return Result(criterion, proc.returncode, status)


def _print_results(results: list[Result]) -> None:
    print("| criterion | tier | exit | status | command |")
    print("|---|---:|---:|---|---|")
    for result in results:
        command = result.criterion.command.replace("|", "\\|")
        print(
            f"| {result.criterion.criterion_id} | {result.criterion.tier} | "
            f"{result.exit_code} | {result.status} | `{command}` |"
        )


def run(root: Path, include_device: bool) -> int:
    spec_path = _load_spec_path(root)
    criteria = _parse_verify_block(spec_path.read_text(encoding="utf-8"))
    selected = [
        criterion
        for criterion in criteria
        if include_device or criterion.tier == "deterministic"
    ]
    results = [_run_criterion(root, criterion) for criterion in selected]
    _print_results(results)
    deterministic_failed = any(
        result.criterion.tier == "deterministic" and result.exit_code != 0
        for result in results
    )
    return 1 if deterministic_failed else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--device",
        action="store_true",
        help="Also run device-tier criteria. Device results are reported but do not set the exit code.",
    )
    args = parser.parse_args(argv)
    try:
        return run(args.root.resolve(), args.device)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL verify_phase_acceptance: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())


#!/usr/bin/env python3
"""Helpers for pre-commit checks that lint staged additions."""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class AddedLine:
    path: str
    line_no: int | None
    text: str


def staged_added_lines(pathspec: str) -> list[AddedLine]:
    """Return added lines from the staged diff for a pathspec."""
    cmd = [
        "git",
        "diff",
        "--cached",
        "--unified=0",
        "--",
        pathspec,
    ]
    proc = subprocess.run(cmd, check=False, capture_output=True, text=True)
    if proc.returncode not in (0, 1):
        return []

    current_path: str | None = None
    next_new_line: int | None = None
    out: list[AddedLine] = []

    for raw in proc.stdout.splitlines():
        if raw.startswith("+++ b/"):
            current_path = raw.removeprefix("+++ b/")
            next_new_line = None
            continue
        if raw.startswith("@@"):
            # Example: @@ -12,0 +13,2 @@
            marker = raw.split(" +", 1)
            if len(marker) == 2:
                new_part = marker[1].split(" ", 1)[0]
                start = new_part.split(",", 1)[0]
                try:
                    next_new_line = int(start)
                except ValueError:
                    next_new_line = None
            continue
        if raw.startswith("+") and not raw.startswith("+++"):
            out.append(
                AddedLine(
                    path=current_path or "<unknown>",
                    line_no=next_new_line,
                    text=raw[1:],
                )
            )
            if next_new_line is not None:
                next_new_line += 1
            continue
        if raw and not raw.startswith("-") and next_new_line is not None:
            next_new_line += 1

    return out


def existing_files(paths: list[str]) -> list[Path]:
    return [Path(path) for path in paths if path and Path(path).is_file()]

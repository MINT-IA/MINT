#!/usr/bin/env python3
"""Render generated Journey OS Mermaid diagrams to catch syntax drift."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

DIAGRAMS = Path(".planning/journeys/diagrams")
MERMAID_CLI = "@mermaid-js/mermaid-cli@11.4.2"


def _render(root: Path, diagram: Path, out_dir: Path) -> str | None:
    output = out_dir / f"{diagram.stem}.svg"
    proc = subprocess.run(
        ["npx", "-y", MERMAID_CLI, "-i", str(diagram), "-o", str(output)],
        cwd=root,
        text=True,
        capture_output=True,
        timeout=120,
    )
    if proc.returncode:
        return f"{diagram.relative_to(root)} failed to render: {proc.stderr.strip() or proc.stdout.strip()}"
    try:
        svg = output.read_text(encoding="utf-8", errors="ignore")
    except OSError as exc:
        return f"{diagram.relative_to(root)} did not produce an SVG: {exc}"
    if "<svg" not in svg or len(svg.strip()) < 100:
        return f"{diagram.relative_to(root)} produced an empty or invalid SVG"
    return None


def check(root: Path) -> list[str]:
    root = root.resolve()
    if shutil.which("npx") is None:
        return ["npx is required to render Journey OS Mermaid diagrams"]
    diagrams = sorted((root / DIAGRAMS).glob("*.mmd"))
    if not diagrams:
        return [f"missing Journey OS Mermaid diagrams under {DIAGRAMS}"]
    errors: list[str] = []
    with tempfile.TemporaryDirectory(prefix="mint-mermaid-render-") as tmp:
        out_dir = Path(tmp)
        for diagram in diagrams:
            error = _render(root, diagram, out_dir)
            if error:
                errors.append(error)
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    errors = check(args.root)
    if not errors:
        print("OK mermaid_render_guard: generated Journey OS Mermaid diagrams render.")
        return 0
    print("FAIL mermaid_render_guard: generated Journey OS Mermaid diagrams do not render.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Render checked-in MINT Mermaid diagrams to catch syntax drift."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REQUIRED_DIAGRAMS = (Path("docs/codex/WIRING_GRAPH.mmd"),)
OPTIONAL_DIAGRAM_DIRS = (Path(".planning/journeys/diagrams"),)
MERMAID_CLI = "@mermaid-js/mermaid-cli@11.4.2"


def _render(root: Path, diagram: Path, out_dir: Path, puppeteer_config: Path) -> str | None:
    output = out_dir / f"{diagram.stem}.svg"
    proc = subprocess.run(
        ["npx", "-y", MERMAID_CLI, "-p", str(puppeteer_config), "-i", str(diagram), "-o", str(output)],
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
        return ["npx is required to render MINT Mermaid diagrams"]
    missing = [path for path in REQUIRED_DIAGRAMS if not (root / path).is_file()]
    if missing:
        return [f"missing required MINT Mermaid diagram: {path}" for path in missing]
    diagrams = [root / path for path in REQUIRED_DIAGRAMS]
    for diagram_dir in OPTIONAL_DIAGRAM_DIRS:
        diagrams.extend(sorted((root / diagram_dir).glob("*.mmd")))
    errors: list[str] = []
    with tempfile.TemporaryDirectory(prefix="mint-mermaid-render-") as tmp:
        out_dir = Path(tmp)
        puppeteer_config = out_dir / "puppeteer-config.json"
        puppeteer_config.write_text(
            json.dumps({"args": ["--no-sandbox", "--disable-setuid-sandbox"]}),
            encoding="utf-8",
        )
        for diagram in diagrams:
            error = _render(root, diagram, out_dir, puppeteer_config)
            if error:
                errors.append(error)
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    errors = check(args.root)
    if not errors:
        print("OK mermaid_render_guard: MINT Mermaid diagrams render.")
        return 0
    print("FAIL mermaid_render_guard: MINT Mermaid diagrams do not render.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Validate the active Mint phase has an executable contract.

This guard turns the "spec before implementation" rule into a mechanical
check. It intentionally validates only the active phase from
`.planning/ACTIVE_CONTEXT.json`; historical phases can keep their old shape.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ACTIVE_CONTEXT = Path(".planning/ACTIVE_CONTEXT.json")
DEFAULT_REQUIRED_FILES = ("CONTEXT.md", "SPEC.md", "PLAN.md", "VERIFICATION.md")


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def check(root: Path) -> list[str]:
    errors: list[str] = []
    manifest_path = root / ACTIVE_CONTEXT
    if not manifest_path.exists():
        return [f"missing active context manifest: {ACTIVE_CONTEXT}"]

    try:
        manifest = _load_json(manifest_path)
    except json.JSONDecodeError as exc:
        return [f"{ACTIVE_CONTEXT} is not valid JSON: {exc}"]

    context_value = str(manifest.get("active_phase_context", ""))
    if not context_value:
        return [f"{ACTIVE_CONTEXT} missing active_phase_context"]

    required_files = [
        str(item)
        for item in manifest.get("required_phase_files", DEFAULT_REQUIRED_FILES)
    ]
    context_path = root / context_value
    if not context_path.exists():
        errors.append(f"active_phase_context path does not exist: {context_value}")
        phase_dir = context_path.parent
    else:
        phase_dir = context_path.parent

    for filename in required_files:
        required_path = phase_dir / filename
        if not required_path.exists():
            errors.append(
                "active phase contract missing "
                f"{filename}: {required_path.relative_to(root)}"
            )

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Repository root to check. Defaults to current working directory.",
    )
    args = parser.parse_args(argv)

    errors = check(args.root.resolve())
    if not errors:
        print("OK phase_contract_guard: active phase contract is coherent.", file=sys.stderr)
        return 0

    print("FAIL phase_contract_guard: active phase contract drift detected.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

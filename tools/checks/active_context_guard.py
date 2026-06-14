#!/usr/bin/env python3
"""Validate Mint's single active planning context.

This guard prevents old phase directories from silently becoming the active
router for future agent sessions. It does not delete history; it verifies that
history is not being treated as current authority.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

MANIFEST = Path(".planning/ACTIVE_CONTEXT.json")
HUMAN_ROUTER = Path(".planning/ACTIVE_CONTEXT.md")
STATE = Path(".planning/STATE.md")
ROADMAP = Path(".planning/ROADMAP.md")
INDEX = Path(".planning/INDEX.md")
AGENTS = Path("AGENTS.md")
WORKFLOW = Path("docs/MINT_AGENT_WORKFLOW.md")

REQUIRED_MANIFEST_KEYS = {
    "schema_version",
    "active_milestone",
    "active_phase_context",
    "next_product_phase_context",
    "historical_not_active",
    "quarantine_paths",
}


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def _load_manifest(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _frontmatter_value(text: str, key: str) -> str | None:
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith(f"{key}:"):
            continue
        return stripped.split(":", maxsplit=1)[1].strip().strip("\"'")
    return None


def _active_section(text: str, *end_markers: str) -> str:
    section = text
    for marker in end_markers:
        if marker in section:
            section = section.split(marker, maxsplit=1)[0]
    return section


def _contains_all(text: str, needles: list[str]) -> list[str]:
    return [needle for needle in needles if needle not in text]


def check(root: Path) -> list[str]:
    errors: list[str] = []

    manifest_path = root / MANIFEST
    human_router_path = root / HUMAN_ROUTER
    state_path = root / STATE
    roadmap_path = root / ROADMAP
    index_path = root / INDEX
    agents_path = root / AGENTS
    workflow_path = root / WORKFLOW

    for path in (
        manifest_path,
        human_router_path,
        state_path,
        roadmap_path,
        index_path,
        agents_path,
        workflow_path,
    ):
        if not path.exists():
            errors.append(f"missing active context file: {path.relative_to(root)}")

    if errors:
        return errors

    try:
        manifest = _load_manifest(manifest_path)
    except json.JSONDecodeError as exc:
        return [f"{MANIFEST} is not valid JSON: {exc}"]

    missing_keys = sorted(REQUIRED_MANIFEST_KEYS - set(manifest))
    if missing_keys:
        errors.append(f"{MANIFEST} missing required keys: {', '.join(missing_keys)}")

    active_milestone = str(manifest.get("active_milestone", ""))
    active_phase_context = str(manifest.get("active_phase_context", ""))
    next_product_phase_context = str(manifest.get("next_product_phase_context", ""))
    historical_not_active = [
        str(item) for item in manifest.get("historical_not_active", [])
    ]

    if active_milestone in historical_not_active:
        errors.append(
            f"{MANIFEST} active_milestone is listed in historical_not_active: "
            f"{active_milestone}"
        )

    for key, path_value in (
        ("active_phase_context", active_phase_context),
        ("next_product_phase_context", next_product_phase_context),
    ):
        if path_value and not (root / path_value).exists():
            errors.append(f"{MANIFEST} {key} path does not exist: {path_value}")

    state_text = _read(state_path)
    state_milestone = _frontmatter_value(state_text, "milestone")
    if state_milestone != active_milestone:
        errors.append(
            f"{STATE} STATE milestone {state_milestone!r} does not match "
            f"{MANIFEST} active_milestone {active_milestone!r}"
        )

    state_active = _active_section(state_text, "## Historical Receipts")
    state_missing = _contains_all(
        state_active,
        [active_phase_context, next_product_phase_context],
    )
    if state_missing:
        errors.append(
            f"{STATE} active section does not reference: "
            + ", ".join(state_missing)
        )

    roadmap_text = _read(roadmap_path)
    roadmap_active = _active_section(roadmap_text, "## Milestones")
    roadmap_missing = _contains_all(
        roadmap_active,
        [active_phase_context, next_product_phase_context],
    )
    if roadmap_missing:
        errors.append(
            f"{ROADMAP} Active Pointer does not reference: "
            + ", ".join(roadmap_missing)
        )

    for stale_slug in historical_not_active:
        if stale_slug and stale_slug in state_active:
            errors.append(
                f"{STATE} active section mentions historical_not_active slug: "
                f"{stale_slug}"
            )
        if stale_slug and stale_slug in roadmap_active:
            errors.append(
                f"{ROADMAP} Active Pointer mentions historical_not_active slug: "
                f"{stale_slug}"
            )

    index_text = _read(index_path)
    index_missing = _contains_all(
        index_text,
        [
            "ACTIVE_CONTEXT.md",
            active_phase_context.removeprefix(".planning/"),
            next_product_phase_context.removeprefix(".planning/"),
        ],
    )
    if index_missing:
        errors.append(
            f"{INDEX} does not surface active context: " + ", ".join(index_missing)
        )

    agents_text = _read(agents_path)
    workflow_text = _read(workflow_path)
    for path, text in (
        (AGENTS, agents_text),
        (WORKFLOW, workflow_text),
    ):
        missing = _contains_all(
            text,
            [str(HUMAN_ROUTER), str(MANIFEST)],
        )
        if missing:
            errors.append(
                f"{path} does not require the active context router: "
                + ", ".join(missing)
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
        print("OK active_context_guard: active context is coherent.", file=sys.stderr)
        return 0

    print("FAIL active_context_guard: active context drift detected.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

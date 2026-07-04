#!/usr/bin/env python3
"""Validate Mint's non-negotiable rules registry and agent bootstrap.

Prompted rules are useful, but high-risk rules need a mechanical boundary.
This guard verifies that `rules.md` keeps the Always / Ask first / Never
registry and that Claude's bootstrap cannot bypass the active context router.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

RULES = Path("rules.md")
BOOTSTRAP = Path(".claude/AGENT_BOOTSTRAP.md")
VARIABLE_DICTIONARY_LINT = Path("tools/checks/mint_variable_dictionary_lint.py")
P0_CASE_VARIABLE_REGISTRY = Path("docs/codex/P0_CASE_VARIABLE_REGISTRY.json")
LEGACY_VARIABLE_LINT_INPUT = Path(
    "services/backend/app/services/coach/extractor_schema.py"
)

REQUIRED_SECTIONS = ("ALWAYS DO", "ASK FIRST", "NEVER DO")

SECTION_PATTERNS = {
    "ALWAYS DO": [
        (".planning/ACTIVE_CONTEXT.md", ".planning/ACTIVE_CONTEXT.json"),
        ("active_context_guard.py",),
        ("journey_os_check.py",),
        ("workflow_contract_guard.py",),
        ("SPEC.md",),
        ("Engram", "mem_save"),
    ],
    "ASK FIRST": [
        ("dev", "staging", "main"),
        ("financial formula", "formule financière"),
        ("regulatory constant", "constante réglementaire"),
        ("archive", "historical planning", "dossiers historiques"),
    ],
    "NEVER DO": [
        ("financial number", "chiffre financier"),
        ("provenance",),
        ("UI code", "code UI", "l'UI"),
        ("AI/LLM path", "chemin IA", "chemin LLM"),
        ("silent fallback", "fallback silencieux"),
    ],
}

BOOTSTRAP_NEEDLES = (
    "AGENTS.md",
    "CLAUDE.md",
    "docs/MINT_AGENT_WORKFLOW.md",
    ".planning/ACTIVE_CONTEXT.md",
    ".planning/ACTIVE_CONTEXT.json",
    "active_context_guard.py",
    "journey_os_check.py",
    "workflow_contract_guard.py",
)


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def _section(text: str, heading: str) -> str:
    pattern = re.compile(
        rf"^##\s+{re.escape(heading)}\s*$",
        flags=re.IGNORECASE | re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        return ""
    rest = text[match.end() :]
    next_heading = re.search(r"^##\s+", rest, flags=re.MULTILINE)
    if next_heading:
        return rest[: next_heading.start()]
    return rest


def _contains_any(text: str, options: tuple[str, ...]) -> bool:
    folded = text.casefold()
    return any(option.casefold() in folded for option in options)


def check(root: Path) -> list[str]:
    errors: list[str] = []
    rules_path = root / RULES
    bootstrap_path = root / BOOTSTRAP
    variable_dictionary_lint = root / VARIABLE_DICTIONARY_LINT

    if not rules_path.exists():
        errors.append(f"missing rules registry: {RULES}")
    if not bootstrap_path.exists():
        errors.append(f"missing Claude bootstrap: {BOOTSTRAP}")
    if not variable_dictionary_lint.exists():
        errors.append(f"missing variable dictionary lint: {VARIABLE_DICTIONARY_LINT}")
    if errors:
        return errors

    rules = _read(rules_path)
    sections: dict[str, str] = {}
    for heading in REQUIRED_SECTIONS:
        body = _section(rules, heading)
        if not body:
            errors.append(f"{RULES} missing required section: {heading}")
        sections[heading] = body

    for heading, groups in SECTION_PATTERNS.items():
        body = sections.get(heading, "")
        if not body:
            continue
        for group in groups:
            if not _contains_any(body, group):
                errors.append(
                    f"{RULES} section {heading} missing required rule signal: "
                    + " / ".join(group)
                )

    bootstrap = _read(bootstrap_path)
    missing_bootstrap = [
        needle for needle in BOOTSTRAP_NEEDLES if needle not in bootstrap
    ]
    if missing_bootstrap:
        errors.append(
            f"{BOOTSTRAP} does not require active bootstrap items: "
            + ", ".join(missing_bootstrap)
        )

    has_legacy_input = (root / LEGACY_VARIABLE_LINT_INPUT).exists()
    has_current_registry = (root / P0_CASE_VARIABLE_REGISTRY).exists()
    should_run_legacy_lint = has_legacy_input or not has_current_registry
    if should_run_legacy_lint:
        proc = subprocess.run(
            [
                sys.executable,
                str(variable_dictionary_lint),
                "--root",
                str(root),
                "--check",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip()
            errors.append(
                f"{VARIABLE_DICTIONARY_LINT} failed"
                + (f": {detail}" if detail else "")
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
        print("OK mint_rules_guard: rules registry is coherent.", file=sys.stderr)
        return 0

    print("FAIL mint_rules_guard: rules registry drift detected.", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Phase mint-calc-engine-v1 Plan 09 Concern A — tool description FR rubric lint.

Scans Python source files for ``"description": "..."`` entries inside dict
literals (the Anthropic tools-array convention used in
``services/backend/app/services/coach/coach_tools.py`` and the long-tail map in
``anthropic_defer_loading_adapter.py``).

For each description string, the rubric enforces :

- **R1** : ≥1 French verb in
  ``{simule, calcule, compare, estime, projette, évalue, analyse}``.
- **R2** : ≥1 French accented vowel anywhere in the description (proxy for
  French text, NOT English).
- **R3** : ≥1 legal article ref (``art. <N>`` or ``CC art``/``LAVS art``/
  ``LPP art``/``LIFD art``/``LCC art``) OR ≥1 financial-domain keyword
  (``CHF``, ``canton``, ``retraite``, ``impôt``, ``hypothèque``, ``3a``,
  ``LPP``, ``AVS``, ``LIFD``, ``LCC``, ``LAVS``, ``rachat``, ``rente``,
  ``prévoyance``, ``fortune``, ``divorce``, ``succession``, ``salaire``).
- **R4** : length ≥80 chars (Plan 07 templated stubs are exactly the kind of
  thing this catches — ``<name> — life_events_served : <events>.`` style).

The lint is invoked with file paths :

::

    python3 tools/checks/tool_description_rubric.py \\
        services/backend/app/services/coach/coach_tools.py \\
        services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py

Exit codes :

- ``0`` — every scanned description passes all 4 rules.
- ``1`` — at least one description violates ≥1 rule (one violation per rule,
  per description, is reported to stderr).

Plan 09 acceptance criterion : exit 1 on coach_tools.py BEFORE the Task 2
rewrite (baseline), exit 0 AFTER the rewrite. The lint is wired by Plan 09
Task 1 RED→GREEN and consumed by Plan 09 Task 2 acceptance.
"""
from __future__ import annotations

import argparse
import ast
import re
import sys
from pathlib import Path


R1_VERBS = re.compile(
    r"\b(simule|calcule|compare|estime|projette|évalue|analyse)\w*\b",
    re.IGNORECASE,
)
R2_FR_ACCENT = re.compile(r"[éèàùîôûâçëïü]", re.IGNORECASE)
R3_LEGAL_OR_DOMAIN = re.compile(
    r"("
    r"art\.\s*\d+"  # generic "art. 14", "art. 122-124"
    r"|CC\s+art|LAVS\s+art|LPP\s+art|LIFD\s+art|LCC\s+art|OPP\s*\d+\s+art|CO\s+art"
    r"|\bCHF\b|\bcanton|\bretraite|\bimpôt|\bhypothèque|\bhypothécaire"
    r"|\b3a\b|\bLPP\b|\bAVS\b|\bLIFD\b|\bLCC\b|\bLAVS\b|\bLAMal\b|\bLAA\b|\bLAI\b"
    r"|\brachat|\brente|\bprévoyance|\bfortune|\bdivorce|\bsuccession"
    r"|\bsalaire|\bcotisation|\bfiscal|\bfrontalier|\bindépendant"
    r")",
    re.IGNORECASE,
)
R4_MIN_LEN = 80


def _extract_description_strings(
    source: str,
) -> list[tuple[int, str, str | None]]:
    """Return ``[(line_no, description_text, name_or_None), ...]`` for every
    ``"description":`` key/value pair found in dict literals.

    ``name`` is the sibling ``"name":`` string constant from the same dict,
    when present — used to scope the lint to an allowlist via ``--names``.

    Concatenated string literals (``"foo " "bar"``) and parenthesised
    multi-string literals (``("foo " "bar")``) are handled because Python's
    AST folds them into a single ``ast.Constant`` at compile time.

    Dict literals whose ``"description"`` is preceded by a same-dict
    ``"rubric_exempt": True`` or ``"rubric_exempt": "<reason>"`` key are
    skipped (allows in-source carve-outs without an external allowlist).
    """
    tree = ast.parse(source)
    found: list[tuple[int, str, str | None]] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Dict):
            continue
        # Pre-scan the dict for sibling "name" + "rubric_exempt".
        sibling_name: str | None = None
        is_exempt = False
        desc_value: tuple[int, str] | None = None
        for key, value in zip(node.keys, node.values):
            if not isinstance(key, ast.Constant):
                continue
            if key.value == "name" and isinstance(value, ast.Constant) and isinstance(value.value, str):
                sibling_name = value.value
            elif key.value == "rubric_exempt" and isinstance(value, ast.Constant):
                if value.value:
                    is_exempt = True
            elif key.value == "description" and isinstance(value, ast.Constant) and isinstance(value.value, str):
                desc_value = (value.lineno, value.value)
        if desc_value is None or is_exempt:
            continue
        lineno, desc_text = desc_value
        found.append((lineno, desc_text, sibling_name))
    return found


def _extract_dict_var_values(
    source: str, var_name: str
) -> list[tuple[int, str, str]]:
    """Scan ``source`` for a top-level assignment ``<var_name>: ... = {...}``
    where the dict has string-literal keys and string-literal values. Returns
    ``[(line_no, value_text, key_name), ...]`` for every such entry.

    Used to lint maps like ``_TOOL_DESCRIPTIONS_FR = {"tool_x": "...", ...}``
    where the KEY is the tool name and the VALUE is the description string.
    """
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return []
    found: list[tuple[int, str, str]] = []
    for node in tree.body:
        target_dict: ast.Dict | None = None
        if isinstance(node, ast.Assign):
            for tgt in node.targets:
                if isinstance(tgt, ast.Name) and tgt.id == var_name and isinstance(node.value, ast.Dict):
                    target_dict = node.value
                    break
        elif isinstance(node, ast.AnnAssign):
            if (
                isinstance(node.target, ast.Name)
                and node.target.id == var_name
                and node.value is not None
                and isinstance(node.value, ast.Dict)
            ):
                target_dict = node.value
        if target_dict is None:
            continue
        for key, value in zip(target_dict.keys, target_dict.values):
            if (
                isinstance(key, ast.Constant)
                and isinstance(key.value, str)
                and isinstance(value, ast.Constant)
                and isinstance(value.value, str)
            ):
                found.append((value.lineno, value.value, key.value))
    return found


def lint_file(
    path: Path,
    allowlist: set[str] | None = None,
    dict_var: str | None = None,
) -> list[tuple[int, str, str]]:
    """Return ``[(line_no, rule_id, snippet), ...]`` of failures in ``path``.

    When ``allowlist`` is provided (non-empty set), only descriptions whose
    sibling ``"name"`` is in the set are linted. When ``allowlist`` is
    ``None``, every description is linted (legacy mode for unit tests).

    When ``dict_var`` is provided, additionally lint each string-value of a
    top-level ``<dict_var> = {"<tool_name>": "<description>"}`` map. The
    ``allowlist`` (if any) still gates which keys are checked.
    """
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    try:
        descriptions = _extract_description_strings(source)
    except SyntaxError:
        return []
    if dict_var:
        for lineno, desc, key_name in _extract_dict_var_values(source, dict_var):
            descriptions.append((lineno, desc, key_name))
    failures: list[tuple[int, str, str]] = []
    for lineno, desc, name in descriptions:
        if allowlist is not None and name is not None and name not in allowlist:
            continue
        if allowlist is not None and name is None:
            # Skip entries without a sibling "name" when allowlist is active.
            continue
        snippet = desc.replace("\n", " ").strip()[:80]
        if not R1_VERBS.search(desc):
            failures.append((lineno, "R1 FR verb", snippet))
        if not R2_FR_ACCENT.search(desc):
            failures.append((lineno, "R2 FR text (accent)", snippet))
        if not R3_LEGAL_OR_DOMAIN.search(desc):
            failures.append((lineno, "R3 legal/domain keyword", snippet))
        if len(desc) < R4_MIN_LEN:
            failures.append(
                (lineno, f"R4 min length ({len(desc)} < {R4_MIN_LEN})", snippet)
            )
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Concern A tool description FR rubric lint."
    )
    parser.add_argument("paths", nargs="+", type=Path, help="Python files to lint")
    parser.add_argument(
        "--names",
        type=str,
        default=None,
        help=(
            "Comma-separated allowlist of tool names to enforce. When set, "
            "only dict entries whose sibling 'name' is in the allowlist are "
            "checked. When omitted, every description in the file is checked "
            "(legacy mode)."
        ),
    )
    parser.add_argument(
        "--names-file",
        type=Path,
        default=None,
        help="Path to a newline-delimited file of tool names (allowlist).",
    )
    parser.add_argument(
        "--dict-var",
        type=str,
        default=None,
        help=(
            "Additionally lint string-values of a top-level "
            "``<NAME> = {'<tool_name>': '<description>'}`` map (used for "
            "Plan 09's ``_TOOL_DESCRIPTIONS_FR`` in the Anthropic adapter)."
        ),
    )
    args = parser.parse_args(argv)

    allowlist: set[str] | None = None
    if args.names:
        allowlist = {n.strip() for n in args.names.split(",") if n.strip()}
    if args.names_file and args.names_file.is_file():
        if allowlist is None:
            allowlist = set()
        for line in args.names_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                allowlist.add(line)

    total = 0
    for path in args.paths:
        if not path.is_file():
            continue
        failures = lint_file(path, allowlist=allowlist, dict_var=args.dict_var)
        for lineno, rule, snippet in failures:
            print(f"{path}:{lineno}: {rule} — {snippet}...", file=sys.stderr)
            total += 1
    return 1 if total > 0 else 0


if __name__ == "__main__":
    sys.exit(main())

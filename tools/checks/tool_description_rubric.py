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


def _extract_description_strings(source: str) -> list[tuple[int, str]]:
    """Return ``[(line_no, description_text), ...]`` for every ``"description":``
    key/value pair found in dict literals.

    Concatenated string literals (``"foo " "bar"``) and parenthesised
    multi-string literals (``("foo " "bar")``) are handled because Python's
    AST folds them into a single ``ast.Constant`` at compile time.
    """
    tree = ast.parse(source)
    found: list[tuple[int, str]] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Dict):
            continue
        for key, value in zip(node.keys, node.values):
            if not isinstance(key, ast.Constant) or key.value != "description":
                continue
            # Resolve the value : either a direct string constant or a
            # constant after folding (``ast.parse`` already folds adjacent
            # string literals into a single Constant).
            if isinstance(value, ast.Constant) and isinstance(value.value, str):
                found.append((value.lineno, value.value))
    return found


def lint_file(path: Path) -> list[tuple[int, str, str]]:
    """Return ``[(line_no, rule_id, snippet), ...]`` of failures in ``path``."""
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    try:
        descriptions = _extract_description_strings(source)
    except SyntaxError:
        return []
    failures: list[tuple[int, str, str]] = []
    for lineno, desc in descriptions:
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
    args = list(argv if argv is not None else sys.argv[1:])
    if not args:
        print(
            "Usage: tool_description_rubric.py <python-file> [<python-file> ...]",
            file=sys.stderr,
        )
        return 2

    total = 0
    for arg in args:
        path = Path(arg)
        if not path.is_file():
            continue
        failures = lint_file(path)
        for lineno, rule, snippet in failures:
            print(f"{path}:{lineno}: {rule} — {snippet}...", file=sys.stderr)
            total += 1
    return 1 if total > 0 else 0


if __name__ == "__main__":
    sys.exit(main())

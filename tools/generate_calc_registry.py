#!/usr/bin/env python3
"""Phase mint-calc-engine-v1 Plan 05 — D-CE-11 calc registry generator.

AST scanner that walks ``services/backend/app/services/`` and emits a
per-calculator metadata index to ``services/backend/app/calculators/_registry.py``.

D-CE-09 Strangler-fig : the registry is an INDEX (« where does each calc
live? »); physical consolidation is deferred to a post-v1 phase. The generated
``_registry.py`` only DESCRIBES the existing services tree — it does NOT move
any code.

D-CE-14 reverse-dependency map : the same AST walk that produces ``REGISTRY``
also produces ``REVERSE_DEP_MAP`` (« kills two birds » per Override #5). The
map keys are profile field names ; values are sets of calc names that depend
on the field.

Output module shape
-------------------
The generated ``_registry.py`` exposes :

  * ``CalculatorMetadata`` TypedDict — `name`/`file`/`profile_fields_needed`/
    `life_events_served`/`output_type` per D-CE-11.
  * ``REGISTRY: dict[str, CalculatorMetadata]`` — keyed on canonical
    `<file_stem>__<func_qualname>` to avoid cross-domain name collisions.
  * ``REVERSE_DEP_MAP: dict[str, set[str]]`` — profile field → set[calc_name].
  * ``get_calculator(name)`` lookup. Raises ``KeyError`` on miss.
  * ``get_reverse_deps(field)`` scaffold (full impl ships in Plan 14).

Heuristic
---------
A function counts as a calculator if :

  1. Its name matches one of the prefix patterns
     ``compute_`` / ``simulate_`` / ``compare_`` / ``estimate_`` / ``calculate_``
     OR is one of the bare verbs (``compute`` / ``simulate`` / ``compare`` /
     ``estimate`` / ``calculate``).
  2. It lives under a CALC-SERVICE directory (``arbitrage`` / ``mortgage`` /
     ``fiscal`` / ``lpp_deep`` / ``family`` / ``expat`` / ``independants`` /
     ``retirement`` / ``debt_prevention`` / ``unemployment`` / ``fri`` /
     ``pillar_3a_deep``) OR is a root-level calc service file
     (``divorce_simulator.py`` / ``succession_simulator.py`` /
     ``lamal_franchise_service.py`` / ``donation_service.py`` /
     ``gender_gap_service.py`` / ``housing_sale_service.py`` /
     ``job_comparator.py`` / ``disability_gap_service.py`` /
     ``next_steps_service.py`` / ``household_service.py``).
  3. Class methods : we walk inside ``ClassDef`` bodies for the same prefixes.

D-CE-09 Phase A : the heuristic is best-effort. If W0 audit (57 calcs)
differs from the count emitted, the gap is documented in this plan's SUMMARY,
and Wave 2's ToolRegistryAdapter is the first downstream consumer that will
surface drift.

CLI
---
  * ``python3 tools/generate_calc_registry.py`` (no args) → WRITE registry.
  * ``python3 tools/generate_calc_registry.py --print`` → STDOUT registry.
  * ``python3 tools/generate_calc_registry.py --check`` → diff vs current ;
    exit 1 on drift.

Lucidity marker
---------------
Each FunctionDef may carry a ``# @lucidity: L<N>`` magic-comment on one of
the 5 lines above its ``def`` ; the scanner extracts the level. Default is
``L1`` when no marker is present (per D-CE-15 + Plan 04 lucidity payloads).

References
----------
- CONTEXT.md §D-CE-09 / §D-CE-11 / §D-CE-14.
- RESEARCH.md §Q-G (lines 975-1095).
- Plan 04 ``app/models/lucidity/_payload.py`` (LucidityLevel L1-L4).
- W0-AUDIT-MATRIX.md (57 calculators expected across 11 domains).
"""
from __future__ import annotations

import argparse
import ast
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


# ---------------------------------------------------------------------------
# Path discovery — must work from any CWD.
# ---------------------------------------------------------------------------

THIS_FILE = Path(__file__).resolve()
PROJECT_ROOT = THIS_FILE.parent.parent  # tools/ → project root
SERVICES_ROOT = PROJECT_ROOT / "services" / "backend" / "app" / "services"
BACKEND_ROOT = PROJECT_ROOT / "services" / "backend"
REGISTRY_OUT = (
    PROJECT_ROOT / "services" / "backend" / "app" / "calculators" / "_registry.py"
)


# ---------------------------------------------------------------------------
# Heuristic scope — which directories / files count as calculator services.
# ---------------------------------------------------------------------------

CALCULATOR_FUNC_PREFIXES: Tuple[str, ...] = (
    "compute_",
    "simulate_",
    "compare_",
    "estimate_",
    "calculate_",
)

CALCULATOR_BARE_VERBS: Tuple[str, ...] = (
    "compute",
    "simulate",
    "compare",
    "estimate",
    "calculate",
)

# Service sub-directories that hold canonical Swiss financial calculators
# (W0-AUDIT-MATRIX.md categories 1-13 + fri/ + pillar_3a_deep/).
CALC_SUB_DIRS: Tuple[str, ...] = (
    "arbitrage",
    "mortgage",
    "fiscal",
    "lpp_deep",
    "family",
    "expat",
    "independants",
    "retirement",
    "debt_prevention",
    "unemployment",
    "fri",
    "pillar_3a_deep",
)

# Root-level service files (no sub-directory) that ARE calculators per W0 audit.
ROOT_CALC_FILES: Tuple[str, ...] = (
    "divorce_simulator.py",
    "succession_simulator.py",
    "lamal_franchise_service.py",
    "donation_service.py",
    "gender_gap_service.py",
    "housing_sale_service.py",
    "job_comparator.py",
    "disability_gap_service.py",
    "next_steps_service.py",
    "household_service.py",
    "frontalier_service.py",  # deprecated shim — kept for D-CE-10 visibility
    "independant_service.py",  # deprecated shim — kept for D-CE-10 visibility
)

# Function names to ALWAYS exclude (utility helpers that match prefix but are
# not user-facing Swiss financial calculators).
EXCLUDED_FUNC_NAMES: Set[str] = {
    "compute_terminal_spread",  # arbitrage_models internal aggregator
    "compute_fingerprint",      # document_memory_service hash helper
    "compute_inputs_hash",      # coach helper
    "compute_policy_hash",      # consent receipt helper
    "compute_pareto_points",    # coach pareto helper (engine, not Swiss calc)
    "compute_what_ifs",         # coach sensitivity helper
    "compute_category_summary", # docling categorizer (UI helper)
    "compute_budget_preview",   # docling categorizer (UI helper)
    "compute_smart_defaults",   # precision service (engine helper)
    "compute_minimal_profile",  # onboarding (engine helper)
    "compute_disability_gap",   # rules_engine duplicate (canonical lives in disability_gap_service)
    "compute_rente_vs_capital", # rules_engine duplicate
    "compute_confidence",       # confidence engine (not a Swiss calc)
    "calculate_precision_score",
    "calculate_compound_interest",
    "calculate_pillar3a_tax_benefit",
    "calculate_leasing_opportunity_cost",
    "calculate_marginal_tax_rate",
    "calculate_tax_potential",
    "calculate_consumer_credit",
    "calculate_debt_risk_score",
    "estimate_confidence_delta",
    "estimate_tax_confidence_delta",
    "estimate_avs_confidence_delta",
}


# ---------------------------------------------------------------------------
# Life-event mapping (RESEARCH §Q-G lines 1051-1063 + W0-AUDIT-MATRIX).
# ---------------------------------------------------------------------------

LIFE_EVENT_MAPPING: Dict[str, List[str]] = {
    "lpp_deep": ["retirement", "buyback"],
    "family": ["family", "marriage"],
    "mortgage": ["housing"],
    "fiscal": ["taxes"],
    "expat": ["cross_border"],
    "independants": ["independent"],
    "retirement": ["retirement"],
    "debt_prevention": ["debt"],
    "arbitrage": ["cross_cutting"],
    "unemployment": ["career"],
    "fri": ["cross_cutting"],
    "pillar_3a_deep": ["retirement"],
}

# Root-file life-event mapping (W0-AUDIT-MATRIX categories 6, 7, 11, 14, etc.).
ROOT_FILE_LIFE_EVENTS: Dict[str, List[str]] = {
    "divorce_simulator.py": ["family", "divorce"],
    "succession_simulator.py": ["family", "succession"],
    "lamal_franchise_service.py": ["health"],
    "donation_service.py": ["family", "succession"],
    "gender_gap_service.py": ["career"],
    "housing_sale_service.py": ["housing"],
    "job_comparator.py": ["career"],
    "disability_gap_service.py": ["career"],
    "next_steps_service.py": ["cross_cutting"],
    "household_service.py": ["family"],
    "frontalier_service.py": ["cross_border"],
    "independant_service.py": ["independent"],
}


# ---------------------------------------------------------------------------
# AST utilities.
# ---------------------------------------------------------------------------


def _is_calc_func_name(name: str) -> bool:
    """Return True if ``name`` matches the calculator-prefix heuristic."""
    if name in EXCLUDED_FUNC_NAMES:
        return False
    if name.startswith("_"):
        return False  # private helper
    for prefix in CALCULATOR_FUNC_PREFIXES:
        if name.startswith(prefix):
            return True
    if name in CALCULATOR_BARE_VERBS:
        return True
    return False


def _file_in_scope(path: Path) -> bool:
    """Return True if ``path`` is under a CALC sub-dir OR is a ROOT_CALC_FILES."""
    try:
        rel = path.relative_to(SERVICES_ROOT)
    except ValueError:
        return False
    parts = rel.parts
    if len(parts) == 1 and parts[0] in ROOT_CALC_FILES:
        return True
    if len(parts) >= 2 and parts[0] in CALC_SUB_DIRS:
        return True
    return False


def _extract_arg_names(args: ast.arguments) -> List[str]:
    """Return the list of positional / keyword arg names (excluding ``self``/``cls``)."""
    out: List[str] = []
    for a in args.args:
        if a.arg in ("self", "cls"):
            continue
        out.append(a.arg)
    for a in args.kwonlyargs:
        out.append(a.arg)
    return out


def _scan_for_lucidity_marker(
    node: ast.FunctionDef, source_lines: List[str]
) -> str:
    """Look at the 5 lines preceding ``def`` for ``# @lucidity: L<N>``.

    Returns one of ``"L1" | "L2" | "L3" | "L4"`` ; defaults to ``"L1"``.
    """
    if not node.lineno:
        return "L1"
    start = max(0, node.lineno - 6)
    end = node.lineno - 1
    for line in source_lines[start:end]:
        stripped = line.strip()
        if stripped.startswith("#") and "@lucidity" in stripped:
            for token in ("L1", "L2", "L3", "L4"):
                if token in stripped:
                    return token
    return "L1"


def _life_events_for(path: Path) -> List[str]:
    """Heuristic life-event tagging based on parent sub-dir or root-file name."""
    try:
        rel = path.relative_to(SERVICES_ROOT)
    except ValueError:
        return ["cross_cutting"]
    parts = rel.parts
    if len(parts) == 1 and parts[0] in ROOT_FILE_LIFE_EVENTS:
        return list(ROOT_FILE_LIFE_EVENTS[parts[0]])
    if len(parts) >= 2 and parts[0] in LIFE_EVENT_MAPPING:
        return list(LIFE_EVENT_MAPPING[parts[0]])
    return ["cross_cutting"]


def _canonical_calc_name(path: Path, func_qualname: str) -> str:
    """Build ``<file_stem>__<func_qualname>`` ; collision-resistant across 11 domains."""
    stem = path.stem
    safe_qual = func_qualname.replace(".", "_")
    return f"{stem}__{safe_qual}"


def _relative_file(path: Path) -> str:
    """Return path relative to ``services/backend/`` for the ``file`` registry field."""
    return str(path.relative_to(BACKEND_ROOT))


# ---------------------------------------------------------------------------
# Per-module scan.
# ---------------------------------------------------------------------------


def find_calculators_in_module(path: Path) -> List[Dict[str, object]]:
    """Walk ``path``'s AST and emit one dict per calculator function found.

    Each dict has keys :
      - ``name`` : canonical calc id (``<file_stem>__<func_qualname>``).
      - ``file`` : relative path under ``services/backend/``.
      - ``profile_fields_needed`` : list[str] of arg names.
      - ``life_events_served`` : list[str] from heuristic mapping.
      - ``output_type`` : ``"L1" | "L2" | "L3" | "L4"``.
    """
    if not _file_in_scope(path):
        return []
    try:
        source = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return []
    try:
        tree = ast.parse(source, filename=str(path))
    except SyntaxError:
        return []
    source_lines = source.splitlines()
    out: List[Dict[str, object]] = []

    for top_node in tree.body:
        # Top-level function.
        if isinstance(top_node, ast.FunctionDef) and _is_calc_func_name(top_node.name):
            out.append(
                {
                    "name": _canonical_calc_name(path, top_node.name),
                    "file": _relative_file(path),
                    "profile_fields_needed": _extract_arg_names(top_node.args),
                    "life_events_served": _life_events_for(path),
                    "output_type": _scan_for_lucidity_marker(top_node, source_lines),
                }
            )
        # Class methods.
        elif isinstance(top_node, ast.ClassDef):
            for cls_node in top_node.body:
                if isinstance(cls_node, ast.FunctionDef) and _is_calc_func_name(
                    cls_node.name
                ):
                    qual = f"{top_node.name}.{cls_node.name}"
                    out.append(
                        {
                            "name": _canonical_calc_name(path, qual),
                            "file": _relative_file(path),
                            "profile_fields_needed": _extract_arg_names(cls_node.args),
                            "life_events_served": _life_events_for(path),
                            "output_type": _scan_for_lucidity_marker(
                                cls_node, source_lines
                            ),
                        }
                    )
    return out


# ---------------------------------------------------------------------------
# Full-tree scan + registry / reverse-dep build.
# ---------------------------------------------------------------------------


def generate_registry() -> Dict[str, Dict[str, object]]:
    """Walk all ``*.py`` files under ``SERVICES_ROOT`` and return the REGISTRY dict.

    Stable ordering : keys are sorted alphabetically, ensuring idempotent
    regeneration (Plan 05 hard constraint).
    """
    found: Dict[str, Dict[str, object]] = {}
    for path in sorted(SERVICES_ROOT.rglob("*.py")):
        if path.name == "__init__.py" or path.name.startswith("_"):
            continue
        for entry in find_calculators_in_module(path):
            name = entry["name"]
            # Collision guard : if the same name appears twice, keep the first
            # (alphabetical file order makes this deterministic).
            if name in found:
                continue
            found[name] = entry
    return dict(sorted(found.items()))


def generate_reverse_dep_map(
    registry: Dict[str, Dict[str, object]],
) -> Dict[str, Set[str]]:
    """Build {profile_field: {calc_names}} from a REGISTRY.

    Plan 14 (D-CE-14) is the canonical reverse-dep map implementer ; this
    scaffold is a seed produced as a side product of the AST walk per Override
    #5 (« kills two birds »).
    """
    reverse: Dict[str, Set[str]] = {}
    for calc_name, meta in registry.items():
        for field in meta.get("profile_fields_needed", []):  # type: ignore[union-attr]
            reverse.setdefault(field, set()).add(calc_name)
    return reverse


# ---------------------------------------------------------------------------
# Module rendering — produces the text of ``_registry.py``.
# ---------------------------------------------------------------------------


_HEADER = '''"""AUTO-GENERATED by ``tools/generate_calc_registry.py`` — DO NOT EDIT MANUALLY.

Regenerate :
    python3 tools/generate_calc_registry.py

Freshness check (exit 1 on drift) :
    python3 tools/generate_calc_registry.py --check

Phase mint-calc-engine-v1 Plan 05 — D-CE-09 / D-CE-11 / D-CE-14.
"""
from __future__ import annotations

from typing import Dict, List, Literal, Set, TypedDict


class CalculatorMetadata(TypedDict):
    """Per-calculator metadata per D-CE-11.

    ``output_type`` aligns with ``app/models/lucidity/_payload.py``
    ``LucidityLevel`` (Plan 04).
    """

    name: str
    file: str
    profile_fields_needed: List[str]
    life_events_served: List[str]
    output_type: Literal["L1", "L2", "L3", "L4"]


'''


def _render_registry(registry: Dict[str, Dict[str, object]]) -> str:
    """Render the ``REGISTRY: dict[str, CalculatorMetadata] = {...}`` block."""
    lines: List[str] = ["REGISTRY: Dict[str, CalculatorMetadata] = {"]
    for name in sorted(registry):
        entry = registry[name]
        # Serialize each field deterministically via json.dumps for stability.
        fields = json.dumps(
            entry["profile_fields_needed"], ensure_ascii=False, sort_keys=False
        )
        events = json.dumps(
            entry["life_events_served"], ensure_ascii=False, sort_keys=False
        )
        lines.append(f"    {json.dumps(name)}: {{")
        lines.append(f"        \"name\": {json.dumps(entry['name'])},")
        lines.append(f"        \"file\": {json.dumps(entry['file'])},")
        lines.append(f"        \"profile_fields_needed\": {fields},")
        lines.append(f"        \"life_events_served\": {events},")
        lines.append(f"        \"output_type\": {json.dumps(entry['output_type'])},")
        lines.append("    },")
    lines.append("}")
    return "\n".join(lines)


def _render_reverse_dep_map(reverse: Dict[str, Set[str]]) -> str:
    """Render the ``REVERSE_DEP_MAP: dict[str, set[str]] = {...}`` block."""
    lines: List[str] = ["REVERSE_DEP_MAP: Dict[str, Set[str]] = {"]
    for field in sorted(reverse):
        calcs = sorted(reverse[field])
        if not calcs:
            lines.append(f"    {json.dumps(field)}: set(),")
            continue
        lines.append(f"    {json.dumps(field)}: {{")
        for c in calcs:
            lines.append(f"        {json.dumps(c)},")
        lines.append("    },")
    lines.append("}")
    return "\n".join(lines)


_FOOTER = '''

def get_calculator(name: str) -> CalculatorMetadata:
    """Lookup helper — raises ``KeyError`` if ``name`` is not in REGISTRY.

    Plan 05 (D-CE-11) primary read API. Wave 2 ``ToolRegistryAdapter`` and
    Wave 3 reverse-dep cache consume this.
    """
    if name not in REGISTRY:
        raise KeyError(
            f"Calculator {name!r} not in REGISTRY. "
            "Re-run tools/generate_calc_registry.py."
        )
    return REGISTRY[name]


def get_reverse_deps(field_name: str) -> Set[str]:
    """Return the set of calc names that depend on ``field_name``.

    Plan 14 (D-CE-14) ships the full implementation (« static reverse-dep map
    for pre-compute selection ») ; this scaffold returns the AST-derived seed
    so Wave 2 / Wave 3 can wire against the API today.
    """
    return REVERSE_DEP_MAP.get(field_name, set())
'''


def render_module(registry: Dict[str, Dict[str, object]]) -> str:
    """Return the full text of the generated ``_registry.py`` module."""
    reverse = generate_reverse_dep_map(registry)
    return (
        _HEADER
        + _render_registry(registry)
        + "\n\n\n"
        + _render_reverse_dep_map(reverse)
        + _FOOTER
    )


# ---------------------------------------------------------------------------
# CLI.
# ---------------------------------------------------------------------------


def _cli(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate services/backend/app/calculators/_registry.py from AST scan."
    )
    parser.add_argument(
        "--print",
        action="store_true",
        help="Print the generated module to stdout instead of writing.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Diff against current _registry.py ; exit 1 on drift.",
    )
    args = parser.parse_args(argv)

    registry = generate_registry()
    rendered = render_module(registry)

    if args.print:
        sys.stdout.write(rendered)
        return 0
    if args.check:
        if not REGISTRY_OUT.exists():
            sys.stderr.write(
                f"FAIL : {REGISTRY_OUT} does not exist. Run without --check first.\n"
            )
            return 1
        current = REGISTRY_OUT.read_text(encoding="utf-8")
        if current != rendered:
            sys.stderr.write(
                "FAIL : tools/generate_calc_registry.py output differs from current "
                f"{REGISTRY_OUT.relative_to(PROJECT_ROOT)}. "
                "Re-run tools/generate_calc_registry.py to regenerate.\n"
            )
            return 1
        sys.stdout.write("OK : registry is fresh.\n")
        return 0

    REGISTRY_OUT.parent.mkdir(parents=True, exist_ok=True)
    REGISTRY_OUT.write_text(rendered, encoding="utf-8")
    sys.stdout.write(
        f"WROTE : {REGISTRY_OUT.relative_to(PROJECT_ROOT)} "
        f"({len(registry)} calculators)\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(_cli())

"""Phase mint-calc-engine-v1 Plan 05 — calc registry contract tests.

Verifies the AST-generated ``services/backend/app/calculators/_registry.py``
satisfies D-CE-11 metadata shape and D-CE-14 reverse-dep map seed shape.

Test budget : 8 tests per PLAN.md Task 2 <behavior> spec + 5 tests for the
generator itself per PLAN.md Task 1 <behavior> spec.

References
----------
- mint-calc-engine-v1-05-w1-calc-registry-PLAN.md
- mint-calc-engine-v1-CONTEXT.md §D-CE-09 / §D-CE-11 / §D-CE-14
- W0-AUDIT-MATRIX.md (57 calculators expected ; Plan 05 target ≥40)
"""
from __future__ import annotations

import ast
import subprocess
import sys
from pathlib import Path

import pytest


# ---------------------------------------------------------------------------
# Paths.
# ---------------------------------------------------------------------------

# tests/ → services/backend/ → MINT.nosync/
PROJECT_ROOT = Path(__file__).resolve().parents[3]
GENERATOR_PATH = PROJECT_ROOT / "tools" / "generate_calc_registry.py"
SERVICES_ROOT = PROJECT_ROOT / "services" / "backend" / "app" / "services"
REGISTRY_PATH = (
    PROJECT_ROOT / "services" / "backend" / "app" / "calculators" / "_registry.py"
)
BACKEND_ROOT = PROJECT_ROOT / "services" / "backend"


# Make the tools/ directory importable for direct generator unit tests.
if str(PROJECT_ROOT / "tools") not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT / "tools"))


# ---------------------------------------------------------------------------
# Task 2 tests — registry artifact contract (D-CE-11).
# ---------------------------------------------------------------------------


def test_registry_has_min_forty_entries():
    """Test 1 : ``len(REGISTRY) >= 40`` (D-CE-11 + W0 audit baseline)."""
    from app.calculators import REGISTRY

    assert len(REGISTRY) >= 40, (
        f"REGISTRY has {len(REGISTRY)} entries, expected ≥40 per Plan 05 "
        "(W0-AUDIT-MATRIX.md baseline 57). "
        "Re-run tools/generate_calc_registry.py and check heuristic scope."
    )


def test_registry_entry_shape_complete():
    """Test 2 : every entry has all 5 D-CE-11 keys."""
    from app.calculators import REGISTRY

    required = {
        "name",
        "file",
        "profile_fields_needed",
        "life_events_served",
        "output_type",
    }
    for name, entry in REGISTRY.items():
        missing = required - set(entry.keys())
        assert not missing, (
            f"calc {name!r} missing required D-CE-11 keys: {sorted(missing)}"
        )


def test_registry_file_field_points_to_existing_file():
    """Test 3 : every ``file`` field resolves to an actual file on disk."""
    from app.calculators import REGISTRY

    for name, entry in REGISTRY.items():
        abs_path = BACKEND_ROOT / entry["file"]
        assert abs_path.is_file(), (
            f"calc {name!r} declares file={entry['file']!r} but "
            f"{abs_path} does not exist on disk. "
            "Re-run tools/generate_calc_registry.py."
        )


def test_registry_output_type_is_valid_lucidity_level():
    """Test 4 : ``output_type`` is one of L1/L2/L3/L4 (Plan 04 LucidityLevel)."""
    from app.calculators import REGISTRY

    valid = {"L1", "L2", "L3", "L4"}
    for name, entry in REGISTRY.items():
        assert entry["output_type"] in valid, (
            f"calc {name!r} has output_type={entry['output_type']!r}, "
            f"must be one of {sorted(valid)} per LucidityLevel enum (Plan 04)."
        )


def test_reverse_dep_map_has_min_five_fields():
    """Test 5 : ``len(REVERSE_DEP_MAP) >= 5`` (D-CE-14 seed)."""
    from app.calculators import REVERSE_DEP_MAP

    assert len(REVERSE_DEP_MAP) >= 5, (
        f"REVERSE_DEP_MAP has {len(REVERSE_DEP_MAP)} fields, expected ≥5. "
        "Common profile fields (canton, age, salary, is_property_owner, "
        "marital_status) should all appear in calculator signatures."
    )


def test_reverse_dep_map_canton_non_empty():
    """Test 6 : ``REVERSE_DEP_MAP['canton']`` is a non-empty set.

    Per W0 audit, ~half of MINT's 57 calculators are canton-dependent.
    """
    from app.calculators import REVERSE_DEP_MAP

    assert "canton" in REVERSE_DEP_MAP, (
        "REVERSE_DEP_MAP must contain 'canton' (W0 audit : ~half of calcs "
        "are canton-dependent)."
    )
    canton_calcs = REVERSE_DEP_MAP["canton"]
    assert isinstance(canton_calcs, set)
    assert len(canton_calcs) > 0, "REVERSE_DEP_MAP['canton'] is empty."


def test_get_calculator_unknown_name_raises_keyerror():
    """Test 7 : ``get_calculator('nonexistent')`` raises ``KeyError``."""
    from app.calculators import get_calculator

    with pytest.raises(KeyError):
        get_calculator("nonexistent_calc_that_will_never_be_registered_xyz")


def test_registry_idempotent_regeneration():
    """Test 8 : two in-memory generations are byte-identical (determinism).

    Beads MINT_nosync-5u4 : l'ancienne version ÉCRIVAIT ``_registry.py`` sur
    le disque à chaque run pytest — le side effect régénérait le fichier et
    MASQUAIT tout drift du registre committé (la suite restait verte avec un
    registre stale ; frais_annuels_par_compte de PR #957 manquait depuis des
    semaines). L'idempotence se prouve en mémoire, sans toucher au worktree.
    """
    from generate_calc_registry import generate_registry, render_module

    first = render_module(generate_registry())
    second = render_module(generate_registry())
    assert first == second, (
        "Regeneration is not idempotent — check sort ordering / json.dumps usage."
    )


def test_registry_committed_file_is_fresh():
    """Test 9 : le fichier COMMITTÉ == la sortie du générateur (gate fraîcheur).

    Beads MINT_nosync-5u4 : ``--check`` n'était câblé ni en CI ni en
    lefthook — un calculateur ajouté sans régénération driftait en silence.
    Ce test vit dans la suite pytest (exécutée en CI backend) : tout drift
    casse le build avec l'instruction de régénération.
    """
    from generate_calc_registry import generate_registry, render_module

    expected = render_module(generate_registry())
    actual = REGISTRY_PATH.read_text(encoding="utf-8")
    assert actual == expected, (
        "services/backend/app/calculators/_registry.py est STALE vs le scan "
        "AST des services. Re-run : python3 tools/generate_calc_registry.py "
        "puis committer le fichier régénéré."
    )


# ---------------------------------------------------------------------------
# Task 1 tests — generator AST behavior (D-CE-11).
# ---------------------------------------------------------------------------


def test_generator_finds_calc_in_arbitrage_allocation_annuelle():
    """Generator T1 : ``find_calculators_in_module`` returns ≥1 entry for the sample."""
    from generate_calc_registry import find_calculators_in_module  # type: ignore

    sample = SERVICES_ROOT / "arbitrage" / "allocation_annuelle.py"
    assert sample.is_file(), f"sample file {sample} missing"
    entries = find_calculators_in_module(sample)
    assert len(entries) >= 1, (
        f"Generator missed the sample calc at {sample}. "
        "Heuristic must catch compare_allocation_annuelle (compare_ prefix)."
    )
    names = [e["name"] for e in entries]
    assert any("allocation_annuelle" in n for n in names), (
        f"None of {names} contains 'allocation_annuelle'."
    )
    files = {e["file"] for e in entries}
    assert "app/services/arbitrage/allocation_annuelle.py" in files


def test_generator_generate_registry_returns_min_forty():
    """Generator T2 : ``generate_registry()`` returns ≥40 entries."""
    from generate_calc_registry import generate_registry  # type: ignore

    registry = generate_registry()
    assert len(registry) >= 40, (
        f"generate_registry returned {len(registry)} entries, expected ≥40. "
        "Heuristic too narrow ; widen prefixes or add directories to CALC_SUB_DIRS."
    )


def test_generator_reverse_dep_map_canton_has_min_twenty_calcs():
    """Generator T3 : reverse-dep map for ``canton`` contains ≥20 calcs.

    Per W0-AUDIT-MATRIX.md, canton is a profile field used by ~half of the
    57 calculators (succession tax, allocations, AVS supplements,
    LAMal franchise, ...).
    """
    from generate_calc_registry import (  # type: ignore
        generate_registry,
        generate_reverse_dep_map,
    )

    registry = generate_registry()
    reverse = generate_reverse_dep_map(registry)
    canton_calcs = reverse.get("canton", set())
    assert len(canton_calcs) >= 20, (
        f"REVERSE_DEP_MAP['canton'] has {len(canton_calcs)} calcs, "
        "expected ≥20 per W0 audit (~half of 57 calcs are canton-dependent)."
    )


def test_generator_life_events_mapping_for_lpp_deep():
    """Generator T4 : ``_life_events_for`` maps ``lpp_deep`` → retirement+buyback."""
    from generate_calc_registry import _life_events_for  # type: ignore

    events = _life_events_for(
        SERVICES_ROOT / "lpp_deep" / "rachat_echelonne_service.py"
    )
    assert set(events) == {"retirement", "buyback"}, (
        f"_life_events_for(lpp_deep/...) returned {events}, "
        "expected ['retirement', 'buyback'] per CONTEXT.md mapping."
    )


def test_generator_print_output_is_parseable_python():
    """Generator T5 : ``--print`` produces valid Python module syntax."""
    result = subprocess.run(
        [sys.executable, str(GENERATOR_PATH), "--print"],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"--print failed : stderr={result.stderr!r}"
    )
    try:
        ast.parse(result.stdout)
    except SyntaxError as e:
        pytest.fail(f"Generated module is not parseable Python : {e}")

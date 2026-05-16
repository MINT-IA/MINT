"""Wave 1c-A3 (D-A3-05 #3) — drift guard.

Every chip-emitter `description` MUST contain the canonical
MISSING_FIELDS_INSTRUCTION_FR substring. Hard-fail if drift.

Path note: lives at tests/test_coach_tools_missing_fields_instruction.py
under the FLAT tests/test_*.py convention (matching
test_coach_tools_budget_snapshot.py, test_coach_tools_retirement_projection.py,
etc.). There is NO tests/test_coach_tools/ subdirectory in this repo.
"""
import pytest

from app.services.coach.coach_tools import COACH_TOOLS, MISSING_FIELDS_INSTRUCTION_FR


_CHIP_EMITTERS = {
    "get_budget_status",
    "get_retirement_projection",
    "get_cross_pillar_analysis",
    "get_cap_status",
    "get_couple_optimization",
}


@pytest.mark.parametrize("name", sorted(_CHIP_EMITTERS))
def test_chip_emitter_description_contains_missing_fields_instruction(name: str) -> None:
    tool = next((t for t in COACH_TOOLS if t["name"] == name), None)
    assert tool is not None, f"{name} not in COACH_TOOLS"
    # Canonical substring anchor (~28-char span, accent-stable):
    assert "Champs profil requis" in tool["description"], (
        f"{name} description missing « Champs profil requis » header"
    )
    assert "Exemple de séquence" in tool["description"], (
        f"{name} description missing Anthropic Tool-Use Example block"
    )


def test_instruction_template_has_required_fields_placeholder() -> None:
    assert "{required_fields_csv}" in MISSING_FIELDS_INSTRUCTION_FR


def test_instruction_template_format_smoke() -> None:
    """I-03 fix — `.format()` must not crash on embedded JSON braces."""
    out = MISSING_FIELDS_INSTRUCTION_FR.format(
        required_fields_csv="age, avsContributionYears"
    )
    assert "age" in out and "status" in out and "incomplete" in out

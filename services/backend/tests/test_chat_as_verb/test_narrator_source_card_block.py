"""Phase 96 D-13 — narrator <source_card> block injection tests.

Per 96-02-PLAN.md Task 3 <behavior> Tests 3, 4, 5. Validates :
- byte-identity when source_card is None (Phase 94 + 95 invariants
  preserved — pinned by the existing test_byte_identity_flag_off.py
  suite ; this file asserts the new kwarg path doesn't drift).
- <source_card> block format when source_card is non-None.
- Optional fields appear only when populated.
"""
from __future__ import annotations

from decimal import Decimal

from app.schemas.card_context import SerializedCardContext
from app.services.coach.claude_coach_service import build_narrator_system_prompt


def test_source_card_none_preserves_legacy_byte_identity():
    """build_narrator_system_prompt() with no source_card kwarg == base prompt.

    Phase 94 + 95 byte-identity tests pin the no-kwarg output ; here we
    just assert that passing source_card=None explicitly produces the
    identical string as omitting it (the new kwarg defaults to None).
    """
    base_no_kwarg = build_narrator_system_prompt(language="fr")
    base_with_none = build_narrator_system_prompt(language="fr", source_card=None)
    assert base_no_kwarg == base_with_none


def test_source_card_block_full_fields_rendered():
    """All 7 fields populated → all 7 appear in the block."""
    card = SerializedCardContext(
        card_id="mon_3a_2026",
        card_type="pillar_3a",
        computed_facts={
            "annual_contribution_chf": Decimal("7056.00"),
            "years_until_retirement": 22,
        },
        grounding_keys=["pillar_3a.max_contribution_2026", "lpp.coordination_2026"],
        life_event="retirement",
        canton="VD",
        archetype="swiss_native",
    )
    prompt = build_narrator_system_prompt(language="fr", source_card=card)
    assert "<source_card>" in prompt
    assert "</source_card>" in prompt
    assert "card_id: mon_3a_2026" in prompt
    assert "card_type: pillar_3a" in prompt
    assert "life_event: retirement" in prompt
    assert "canton: VD" in prompt
    assert "archetype: swiss_native" in prompt
    assert "computed_facts:" in prompt
    assert "annual_contribution_chf: 7056.00" in prompt
    assert "years_until_retirement: 22" in prompt
    assert "pillar_3a.max_contribution_2026" in prompt
    assert "lpp.coordination_2026" in prompt


def test_source_card_block_minimal_fields_only_show_required():
    """Optional fields (life_event/canton/archetype) ABSENT when None."""
    card = SerializedCardContext(card_id="x", card_type="y")
    prompt = build_narrator_system_prompt(language="fr", source_card=card)
    assert "<source_card>" in prompt
    assert "card_id: x" in prompt
    assert "card_type: y" in prompt
    # Optional fields must NOT render their label when None.
    assert "life_event:" not in prompt
    assert "canton:" not in prompt
    assert "archetype:" not in prompt
    # Empty computed_facts and grounding_keys must NOT render their label.
    assert "computed_facts:" not in prompt
    assert "grounding_keys:" not in prompt


def test_source_card_grounding_keys_comma_separated():
    """grounding_keys render as comma-separated when populated."""
    card = SerializedCardContext(
        card_id="x",
        card_type="y",
        grounding_keys=["key_a", "key_b", "key_c"],
    )
    prompt = build_narrator_system_prompt(language="fr", source_card=card)
    assert "grounding_keys: key_a, key_b, key_c" in prompt

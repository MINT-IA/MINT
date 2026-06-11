"""Phase mint-calc-engine-v1 Plan 04 — D-CE-15 typed lucidity payloads contract.

Tests prove schema-impossibility of L2/L3 ranking-creep at type level :
the FIELD `recommended_option` (and 5 paraphrase variants) cannot exist
on the payload — paraphrase cannot evade because there is no field name
to populate. This is the structural counterpart to D-CE-16(b) lint-time +
D-CE-16(c) runtime gate (lexical layers shipped in W4 plans).

Schema impossibility kills field names ; runtime gate D-CE-16(c) kills
banned verbs in free text (`narrative_fr`). Both layers required.

Reference : Q-C of mint-calc-engine-v1-RESEARCH.md ; Finding 6 of
mint-calc-engine-v1-CONTEXT.md ; threat T-mint-calc-04-01.
"""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.models.lucidity import (
    L1ChiffrePayload,
    L2ComparePayload,
    L4InvariantPayload,
    LucidityLevel,
    LucidityPayload,
)


# ---------------------------------------------------------------------------
# Helpers — valid scenario fixtures (LSFin clean)
# ---------------------------------------------------------------------------


def _valid_scenario(suffix: str, narrative_len: int = 60) -> dict:
    """Build a Pydantic-valid `_Scenario` dict with narrative_fr of fixed length.

    Uses LSFin-clean vocabulary (« pourrait », « envisager »). The banned
    verb list itself lives in `tools/checks/banned_terms_python.py` and is
    NOT duplicated here (lint discipline — no verbatim quoting of banned
    roots in non-exempted source).
    """
    base = "Tu pourrais envisager d'utiliser ces fonds pour ton 3a"
    # Pad to requested length using non-banned filler.
    filler = " avec un horizon long terme."
    text = base
    while len(text) < narrative_len:
        text += filler
    text = text[:narrative_len]
    return {
        "label_fr": f"Scénario {suffix}",
        "value": 7056.0,
        "narrative_fr": text,
        "citation_key": "tool_pillar3a",
    }


# ---------------------------------------------------------------------------
# Test 1 — D-CE-15 core : `recommended_option` is structurally impossible on L2
# ---------------------------------------------------------------------------


def test_l2_rejects_recommended_option_field_at_schema_level() -> None:
    """The FIELD `recommended_option` literally cannot exist on `L2ComparePayload`.

    Paraphrase cannot evade : there is no field name to populate.
    Pydantic v2 `extra="forbid"` returns ValidationError on `model_validate`
    when an unknown key is present.
    """
    with pytest.raises(ValidationError) as exc_info:
        L2ComparePayload.model_validate(
            {
                "level": "L2",
                "scenarios": [
                    _valid_scenario("A"),
                    _valid_scenario("B"),
                ],
                "recommended_option": "A",  # D-CE-15 forbidden field
            }
        )
    msg = str(exc_info.value).lower()
    assert "extra" in msg or "not permitted" in msg, (
        f"Expected « extra » or « not permitted » in ValidationError ; got: {msg!r}"
    )


# ---------------------------------------------------------------------------
# Test 2 — D-CE-15 paraphrase variants : 5 forbidden field names all rejected
# ---------------------------------------------------------------------------


_FORBIDDEN_RANKING_FIELDS: tuple[str, ...] = (
    "best_choice",
    "top_pick",
    "preferred",
    "optimal_choice",
    "winning_scenario",
)


@pytest.mark.parametrize("forbidden_field", _FORBIDDEN_RANKING_FIELDS)
def test_l2_rejects_paraphrase_ranking_fields(forbidden_field: str) -> None:
    """All 5 paraphrase variants of `recommended_option` are rejected by extra=forbid."""
    payload = {
        "level": "L2",
        "scenarios": [
            _valid_scenario("A"),
            _valid_scenario("B"),
        ],
        forbidden_field: "A",
    }
    with pytest.raises(ValidationError) as exc_info:
        L2ComparePayload.model_validate(payload)
    msg = str(exc_info.value).lower()
    assert "extra" in msg or "not permitted" in msg, (
        f"Expected ValidationError to mention extra/not permitted for "
        f"forbidden field {forbidden_field!r} ; got: {msg!r}"
    )


# ---------------------------------------------------------------------------
# Test 3 — D-CE-15 narrative parity : 200/50/50 chars rejected (>15% deviation)
# ---------------------------------------------------------------------------


def test_l2_narrative_parity_rejects_lopsided_scenarios() -> None:
    """A 200/50/50 char triple is de facto ranking (LSFin art. 8 risk).

    Avg = 100 ; max delta = 15. Scenarios at 200 chars deviate by +100 ; 50-char
    scenarios deviate by -50 ; both exceed the ±15% threshold.
    """
    payload = {
        "level": "L2",
        "scenarios": [
            _valid_scenario("A", narrative_len=200),
            _valid_scenario("B", narrative_len=50),
            _valid_scenario("C", narrative_len=50),
        ],
    }
    with pytest.raises(ValidationError) as exc_info:
        L2ComparePayload.model_validate(payload)
    msg = str(exc_info.value)
    assert "parity" in msg.lower() or "narrative" in msg.lower(), (
        f"Expected ValidationError to mention narrative parity ; got: {msg!r}"
    )


# ---------------------------------------------------------------------------
# Test 4 — D-CE-15 narrative parity : 100/105/95 chars accepted (within ±15%)
# ---------------------------------------------------------------------------


def test_l2_narrative_parity_accepts_balanced_scenarios() -> None:
    """100/105/95 char trio : avg=100, max delta=15. All within ±15% threshold."""
    payload = {
        "level": "L2",
        "scenarios": [
            _valid_scenario("A", narrative_len=100),
            _valid_scenario("B", narrative_len=105),
            _valid_scenario("C", narrative_len=95),
        ],
    }
    instance = L2ComparePayload.model_validate(payload)
    assert instance.level == LucidityLevel.L2
    assert len(instance.scenarios) == 3
    assert [len(s.narrative_fr) for s in instance.scenarios] == [100, 105, 95]


# ---------------------------------------------------------------------------
# Test 5 — L4 invariant happy path : « 33% Tragbarkeit plafond » constructs valid
# ---------------------------------------------------------------------------


def test_l4_invariant_constructs_with_valid_legal_ref_and_condition_text() -> None:
    """The L4 wedge payload (Finding 5) carries a legal article ref + FR text.

    NB : the 33% charge cap is a FINMA/ASB mortgage self-regulation rule. The
    LCC (consumer credit) explicitly excludes mortgage credit, so the citable
    source is « Directives ASB (FINMA) », not « LCC art. 28 » (Codex W4).
    """
    payload = L4InvariantPayload(
        legal_article_ref="Directives ASB (FINMA)",
        condition_text_fr=(
            "Quel que soit le scénario, ta capacité d'emprunt "
            "est plafonnée à 33% selon les Directives ASB."
        ),
    )
    assert payload.level == LucidityLevel.L4
    assert payload.legal_article_ref == "Directives ASB (FINMA)"
    assert "33%" in payload.condition_text_fr


# ---------------------------------------------------------------------------
# Test 6 — L4 rejects empty legal_article_ref (min_length=5)
# ---------------------------------------------------------------------------


def test_l4_invariant_rejects_empty_legal_article_ref() -> None:
    """`legal_article_ref` requires min_length=5 to ensure a citable source."""
    with pytest.raises(ValidationError):
        L4InvariantPayload(
            legal_article_ref="",
            condition_text_fr=(
                "Quel que soit le scénario, ta capacité d'emprunt "
                "est plafonnée à 33% selon les Directives ASB."
            ),
        )


# ---------------------------------------------------------------------------
# Test 7 — L4 rejects too-short condition_text_fr (min_length=20)
# ---------------------------------------------------------------------------


def test_l4_invariant_rejects_short_condition_text() -> None:
    """`condition_text_fr` requires min_length=20 to prevent trivial invariants."""
    with pytest.raises(ValidationError):
        L4InvariantPayload(
            legal_article_ref="Directives ASB (FINMA)",
            condition_text_fr="trop court",
        )


# ---------------------------------------------------------------------------
# Test 8 — Discriminator union routes level=L1 to L1, level=L4 to L4
# ---------------------------------------------------------------------------


def test_lucidity_payload_discriminator_routes_by_level() -> None:
    """`LucidityPayload` RootModel discriminates on `level` field.

    Verifies the union router picks the correct payload class per level.
    """
    l1 = LucidityPayload.model_validate(
        {
            "level": "L1",
            "value": 2300.0,
            "unit_fr": "CHF/mois",
            "citation_key": "tool_get_retirement_projection",
        }
    )
    assert isinstance(l1.root, L1ChiffrePayload)
    assert l1.root.value == 2300.0

    l4 = LucidityPayload.model_validate(
        {
            "level": "L4",
            "legal_article_ref": "Directives ASB (FINMA)",
            "condition_text_fr": (
                "Quel que soit le scénario d'investissement, "
                "ta capacité d'emprunt est plafonnée à 33% selon les "
                "Directives ASB."
            ),
        }
    )
    assert isinstance(l4.root, L4InvariantPayload)
    assert l4.root.legal_article_ref == "Directives ASB (FINMA)"

    # Unknown level → ValidationError from the discriminator
    with pytest.raises(ValidationError):
        LucidityPayload.model_validate(
            {"level": "L99", "value": 0.0, "unit_fr": "x", "citation_key": "k"}
        )


# ---------------------------------------------------------------------------
# Test 9 — frozen=True : mutation after construction raises
# ---------------------------------------------------------------------------


def test_l1_payload_is_frozen_immutable_after_construction() -> None:
    """`frozen=True` prevents post-construction mutation (no value-tampering)."""
    payload = L1ChiffrePayload(
        value=2300.0,
        unit_fr="CHF/mois",
        citation_key="tool_get_retirement_projection",
    )
    with pytest.raises(ValidationError):
        payload.value = 999.0  # frozen=True → Pydantic raises ValidationError


# ---------------------------------------------------------------------------
# Test 10 — Schema does NOT enforce banned-term scan on narrative_fr free text
# ---------------------------------------------------------------------------


def test_l2_schema_does_not_enforce_banned_term_scan_on_narrative_text() -> None:
    """Schema impossibility kills FIELD NAMES ; runtime gate D-CE-16(c) kills
    banned VERBS in free text. Both layers required ; documented per
    threat T-mint-calc-04-02 (« accept » disposition at schema level).

    This test fixture uses NEUTRAL non-banned text to prove the schema accepts
    L2 payloads with arbitrary narrative_fr — the banned-verb gate is enforced
    by W4 lint + runtime gate, NOT by the Pydantic schema.

    The test fixture itself is LSFin-clean (passes banned_terms_python.py) per
    test-file discipline ; the comment above documents the architectural split.
    """
    # Neutral, LSFin-clean L2 payload — proves the schema only structurally
    # forbids fields, it does not scan narrative_fr content.
    payload = L2ComparePayload.model_validate(
        {
            "level": "L2",
            "scenarios": [
                _valid_scenario("A", narrative_len=80),
                _valid_scenario("B", narrative_len=80),
            ],
        }
    )
    assert payload.level == LucidityLevel.L2
    # Architectural note (no assertion needed) :
    # If a future LSFin-violating narrative_fr were passed (e.g. containing
    # « meilleur option »), the schema would still accept it — that's W4's
    # D-CE-16(c) runtime banned-verb gate to catch. Both layers required.

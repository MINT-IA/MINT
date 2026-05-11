"""Phase 96 D-10 — terminal template invariants.

Per 96-02-PLAN.md Task 3 <behavior> Tests 2 + 12 + 13. The terminal
template is the verbatim FR string returned at turn 4 (cap hit) with
ZERO LLM call. CLAUDE.md rule 1 (LSFin banned terms) + rule 2 (accent
FR 100%) are enforced by this test file as snapshot guards.
"""
from __future__ import annotations

import re

from app.services.coach.turn_cap import TURN_CAP_TERMINAL_TEMPLATE


# Verbatim FR template per CONTEXT D-10 (snapshot guard — any drift
# from this exact string is a regression).
_EXPECTED = (
    "Tu as exploré 3 angles sur cette carte. "
    "Pour aller plus loin, ouvre le simulateur depuis "
    "[Explorer →](/explorer?id={card_id}) — "
    "tu pourras y modifier les hypothèses en direct."
)


def test_terminal_template_verbatim_snapshot():
    """The constant must match the CONTEXT D-10 verbatim FR string."""
    assert TURN_CAP_TERMINAL_TEMPLATE == _EXPECTED


def test_terminal_template_accent_fr_clean():
    """Required accents present : « exploré » + « hypothèses ».

    CLAUDE.md rule 2 — ASCII e in place of é is a bug. The snapshot
    above already enforces this byte-for-byte ; this test makes the
    intent explicit in its name.
    """
    assert "exploré" in TURN_CAP_TERMINAL_TEMPLATE
    assert "hypothèses" in TURN_CAP_TERMINAL_TEMPLATE
    # Negative : the ASCII e form must NOT be present.
    assert "explore " not in TURN_CAP_TERMINAL_TEMPLATE
    assert "hypotheses" not in TURN_CAP_TERMINAL_TEMPLATE


def test_terminal_template_no_lsfin_banned_terms():
    """CLAUDE.md rule 1 — zero « garanti / optimal / parfait » etc.

    The full banned-term list lives at CLAUDE.md §1 ; here we assert
    on the high-frequency offenders the planner could have slipped in.
    """
    banned = (
        "garanti",
        "optimal",
        "meilleur",
        "certain",
        "assuré",
        "sans risque",
        "parfait",
    )
    lowered = TURN_CAP_TERMINAL_TEMPLATE.lower()
    for term in banned:
        assert term not in lowered, (
            f"Terminal template contains LSFin banned term {term!r} : "
            f"{TURN_CAP_TERMINAL_TEMPLATE}"
        )


def test_terminal_template_substitutes_card_id():
    """{card_id} placeholder substitutes correctly via .format()."""
    rendered = TURN_CAP_TERMINAL_TEMPLATE.format(card_id="mon_3a_2026")
    assert "/explorer?id=mon_3a_2026" in rendered
    assert "{card_id}" not in rendered


def test_terminal_template_contains_explorer_deep_link():
    """The terminal template MUST surface the Explorer deep-link path."""
    assert re.search(r"\[Explorer →\]\(/explorer\?id=\{card_id\}\)", TURN_CAP_TERMINAL_TEMPLATE)

"""Phase 94 Wave 1 — D-10 templated fallback verbatim + no-template-vars.

Pins :
- `FALLBACK_TEMPLATED_TEXT` is byte-equal to D-10 spec.
- The source-line assignment block contains NO template variables
  (`{`, `f"`, `%s`, `.format(`) — guards against future contributors
  introducing user-content interpolation in the fallback path.
- Empty input → FALLBACK.
- `is_retry=True` + uncited → FALLBACK.
- `is_retry=True` + banned-claim → FALLBACK.
"""
from __future__ import annotations

import pathlib
import re

from app.services.coach.citation_parser import (
    FALLBACK_TEMPLATED_TEXT,
    GateVerdict,
    gate,
)


# ---------------------------------------------------------------------------
# D-10 verbatim — substring + no-template-vars
# ---------------------------------------------------------------------------


def test_fallback_verbatim():
    expected = (
        "Je n'ai pas cette donnée pour l'instant. Pour avancer ensemble, "
        "dis-moi un peu plus sur ta situation (canton, salaire, structure familiale) "
        "et je peux t'orienter vers ce qui s'applique chez toi."
    )
    assert FALLBACK_TEMPLATED_TEXT == expected


def test_fallback_substrings_present():
    """Defensive — life-event-router tone preserved."""
    assert "Je n'ai pas cette donnée" in FALLBACK_TEMPLATED_TEXT
    assert "canton" in FALLBACK_TEMPLATED_TEXT
    assert "salaire" in FALLBACK_TEMPLATED_TEXT
    assert "structure familiale" in FALLBACK_TEMPLATED_TEXT


def test_fallback_no_template_vars():
    """Source-line assignment must not contain any template-variable
    syntax. Reads `citation_parser.py` as text and isolates the
    `FALLBACK_TEMPLATED_TEXT = (...)` block.
    """
    source_path = (
        pathlib.Path(__file__).resolve().parent.parent.parent
        / "app" / "services" / "coach" / "citation_parser.py"
    )
    src = source_path.read_text(encoding="utf-8")
    # Match the full assignment block — multi-line tolerant.
    match = re.search(
        r"FALLBACK_TEMPLATED_TEXT\s*:\s*str\s*=\s*\(([\s\S]*?)\)\n",
        src,
    )
    assert match is not None, "FALLBACK_TEMPLATED_TEXT assignment not found"
    block = match.group(1)
    # Banned template-var syntaxes :
    assert "f\"" not in block, "f-string detected in fallback assignment"
    assert "f'" not in block, "f-string detected in fallback assignment"
    assert "%s" not in block, "%-format detected in fallback assignment"
    assert "%d" not in block, "%-format detected in fallback assignment"
    assert ".format(" not in block, ".format() detected in fallback assignment"
    # `{` is forbidden (would indicate `{var}` substitution). Citation
    # placeholders are EMITTED by the narrator, not interpolated by us.
    assert "{" not in block, "single-brace template detected in fallback"


# ---------------------------------------------------------------------------
# Empty / whitespace-only input → FALLBACK (defensive).
# ---------------------------------------------------------------------------


def test_empty_text_returns_fallback():
    result = gate("", ctx=None)
    assert result.verdict == GateVerdict.FALLBACK
    assert result.retry_needed is False


def test_whitespace_only_returns_fallback():
    result = gate("   \n\t  ", ctx=None)
    assert result.verdict == GateVerdict.FALLBACK
    assert result.retry_needed is False


# ---------------------------------------------------------------------------
# is_retry=True forces FALLBACK on any rejection (D-08 hard-cap).
# ---------------------------------------------------------------------------


def test_fallback_on_retry_uncited():
    result = gate(
        response_text="Tu peux mettre 6883 CHF par an.",
        ctx=None,
        citation_allowlist=[],
        is_retry=True,
    )
    assert result.verdict == GateVerdict.FALLBACK
    assert result.gated_text == FALLBACK_TEMPLATED_TEXT
    assert result.retry_needed is False


def test_fallback_on_retry_banned():
    result = gate(
        response_text="Vous ferez 4% {{cite:r3a_plafond_salarie_2026}}.",
        ctx=None,
        citation_allowlist=["r3a_plafond_salarie_2026"],
        is_retry=True,
    )
    assert result.verdict == GateVerdict.FALLBACK
    assert result.gated_text == FALLBACK_TEMPLATED_TEXT
    assert result.retry_needed is False

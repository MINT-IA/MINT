"""Wave 1a plan-08 Task 1 (WAVE1A-07).

Confirms `_handle_regulatory_constant` routes to
`RegulatoryRegistry.instance().get(key, jurisdiction)` and formats output
correctly. Wave 1a only ADDS confirmation tests — the handler itself is
unchanged (see plan-08 PLAN.md objective §1 and audit §1 line 39).

Five tests:
  1. Known key (pillar3a.max_with_lpp) returns value + source + effective_from.
  2. Unknown key returns the canonical "non trouvée" message.
  3. Canton override path (capital_tax.cantonal + canton=VD) resolves to VD value.
  4. Missing key returns the canonical FR error string.
  5. Unknown subkey within a known namespace returns prefix-match suggestions.
"""
from __future__ import annotations

from app.api.v1.endpoints.coach_chat import _handle_regulatory_constant


def test_pillar3a_max_with_lpp_returns_value_source_effective_from() -> None:
    result = _handle_regulatory_constant({"key": "pillar3a.max_with_lpp"})
    assert "pillar3a.max_with_lpp = 7258.0 CHF" in result
    assert "OPP3 art. 7 al. 1" in result
    assert "En vigueur depuis : 2025-01-01" in result


def test_unknown_key_returns_non_trouvee_message() -> None:
    result = _handle_regulatory_constant({"key": "unknown.key"})
    assert result.startswith("Constante 'unknown.key' non trouvée.")


def test_capital_tax_cantonal_with_vd_returns_vd_value() -> None:
    result = _handle_regulatory_constant(
        {"key": "capital_tax.cantonal", "canton": "VD"}
    )
    assert "capital_tax.cantonal.VD = 0.08 ratio" in result
    assert "Vaud" in result


def test_missing_key_returns_explicit_error() -> None:
    result = _handle_regulatory_constant({})
    assert result == (
        "Erreur : clé manquante. Fournis un key comme "
        "'pillar3a.max_with_lpp'."
    )


def test_unknown_pillar3a_subkey_returns_suggestions() -> None:
    result = _handle_regulatory_constant({"key": "pillar3a.unknown"})
    assert "Suggestions :" in result
    suffix = result.split("Suggestions :", 1)[1]
    assert "pillar3a." in suffix

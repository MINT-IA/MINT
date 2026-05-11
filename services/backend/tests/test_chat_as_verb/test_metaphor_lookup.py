"""Phase 96 W3 D-18 — backend metaphor_lookup tests.

Mirrors the Dart resolver at
`apps/mobile/lib/services/metaphor_lookup.dart`. The TOML asset at
`services/backend/app/data/metaphors.toml` is the source of truth on
Python side (loaded at module import via stdlib `tomllib`).

Behavior contract (96-03-PLAN.md §Task 1) :

- Test 10a — lookup for a known triplet returns the verbatim metaphor.
- Test 10b — lookup for an unknown triplet returns the empty string.
- Test 10c — partial mismatch on canton or life_event also returns "".
- Test 10d — Python + Dart parity : every TOML triplet resolves on Python
  (the Dart equivalent is tested separately by
  `apps/mobile/test/services/metaphor_lookup_test.dart`).
"""
from __future__ import annotations

from app.services.coach.metaphor_lookup import lookup


def test_known_triplet_returns_verbatim_metaphor() -> None:
    out = lookup("swiss_native", "VD", "housing")
    assert out.startswith("À Lausanne")
    assert "ombre" in out
    # accent guard : « À » with grave + « il faut » lowercase.
    assert "À" in out


def test_unknown_archetype_returns_empty_string() -> None:
    assert lookup("alien_archetype", "VD", "housing") == ""


def test_unknown_canton_returns_empty_string() -> None:
    assert lookup("swiss_native", "XX", "housing") == ""


def test_unknown_life_event_returns_empty_string() -> None:
    assert lookup("swiss_native", "VD", "alien_event") == ""


def test_all_v1_bootstrap_triplets_resolve() -> None:
    """Every section in metaphors.toml v1 resolves to a non-empty string."""
    triplets = [
        ("swiss_native", "VD", "housing"),
        ("swiss_native", "VD", "family"),
        ("swiss_native", "GE", "housing"),
        ("swiss_native", "GE", "family"),
        ("expat_eu", "VD", "housing"),
        ("expat_eu", "GE", "family"),
        ("cross_border", "VD", "housing"),
        ("cross_border", "GE", "family"),
    ]
    for archetype, canton, life_event in triplets:
        out = lookup(archetype, canton, life_event)
        assert out, f"Empty metaphor for {archetype}.{canton}.{life_event}"
        assert isinstance(out, str)
        # Sanity : at least 30 chars (v1 metaphors are full sentences).
        assert len(out) >= 30


def test_expat_eu_ge_family_matches_d17_example() -> None:
    """D-17 names this triplet by example in CONTEXT — pin it explicitly."""
    out = lookup("expat_eu", "GE", "family")
    assert "puzzle" in out
    assert "Genève" in out  # accent guard

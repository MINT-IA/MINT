"""Tests for the AVS reference-age domain fix (mint-grounded-coach-m1 Plan 06, Task 1).

Audit 01 DET-1 / CONTEXT WS-D: `avs.reference_age_women` was pinned at the
AVS21 endpoint value 65.0, but the 2026 transitional reference age for women
born 1962 is 64.5 (the AVS21 reform raises women's age progressively
64 → 65 over the 1961-1963 birth cohorts; it reaches 65 only in 2028).

This test pins the corrected 2026 transition value and guards the men value
(unchanged at 65.0). It is the deterministic regression that keeps the
constant from silently drifting back to the endpoint value.

Source: OFAS AVS 21 — relèvement de l'âge de référence des femmes.
"""

import pytest

from app.services.regulatory.registry import RegulatoryRegistry


@pytest.fixture(autouse=True)
def reset_registry():
    """Reset the registry singleton between tests for isolation."""
    RegulatoryRegistry._reset()
    yield
    RegulatoryRegistry._reset()


@pytest.fixture
def registry() -> RegulatoryRegistry:
    """Return a fresh registry instance."""
    return RegulatoryRegistry.instance()


class TestAvsReferenceAge2026:
    """AVS reference ages reflect the 2026 transitional values (AVS 21)."""

    def test_women_reference_age_is_64_5_for_2026(self, registry):
        """Women's 2026 transitional reference age is 64.5, not the 65 endpoint."""
        param = registry.get("avs.reference_age_women")
        assert param is not None
        assert param.value == 64.5

    def test_men_reference_age_unchanged_at_65(self, registry):
        """Men's reference age stays 65.0 (LAVS art. 21)."""
        param = registry.get("avs.reference_age_men")
        assert param is not None
        assert param.value == 65.0

    def test_women_and_men_differ_during_transition(self, registry):
        """During the 2026 transition the two reference ages are NOT equal."""
        men = registry.get("avs.reference_age_men")
        women = registry.get("avs.reference_age_women")
        assert men.value != women.value

    def test_women_description_notes_2026_transition(self, registry):
        """The description must signal the 2026 transitional state, not just AVS 21."""
        param = registry.get("avs.reference_age_women")
        assert param is not None
        assert "2026" in param.description
        # Source fields are preserved (still anchored to LAVS art. 21).
        assert "21" in (param.source_title or "")
        assert param.source_url

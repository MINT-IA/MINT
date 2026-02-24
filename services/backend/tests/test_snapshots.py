"""
Tests for Financial Snapshots — Sprint S33.

Covers:
    - Create snapshot returns valid snapshot
    - Get snapshots returns in reverse chronological order
    - Delete all snapshots returns correct count
    - Get evolution returns time series
    - Trigger types validation
    - Empty user has no snapshots

Sources:
    - LPD (Loi sur la protection des donnees) — right to erasure
"""

import time
import pytest

from app.services.snapshots.snapshot_service import (
    create_snapshot,
    get_snapshots,
    delete_all_snapshots,
    get_evolution,
    _clear_all,
)
from app.services.snapshots.snapshot_models import VALID_TRIGGERS


# ═══════════════════════════════════════════════════════════════════════════════
# Fixtures
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.fixture(autouse=True)
def clean_storage():
    """Clear in-memory storage before each test."""
    _clear_all()
    yield
    _clear_all()


SAMPLE_PROFILE = {
    "age": 35,
    "gross_income": 120_000.0,
    "canton": "VD",
    "archetype": "swiss_native",
    "household_type": "married",
    "replacement_ratio": 0.62,
    "months_liquidity": 4.5,
    "tax_saving_potential": 7_258.0,
    "confidence_score": 72.0,
    "enrichment_count": 3,
    "fri_total": 65.0,
    "fri_l": 70.0,
    "fri_f": 60.0,
    "fri_r": 55.0,
    "fri_s": 75.0,
}


# ═══════════════════════════════════════════════════════════════════════════════
# Create snapshot tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestCreateSnapshot:
    """Test snapshot creation."""

    def test_create_returns_valid_snapshot(self):
        """Created snapshot must have all required fields."""
        snapshot = create_snapshot(
            user_id="user-123",
            trigger="quarterly",
            profile_data=SAMPLE_PROFILE,
        )
        assert snapshot.id  # UUID must not be empty
        assert snapshot.user_id == "user-123"
        assert snapshot.trigger == "quarterly"
        assert snapshot.model_version == "1.0"
        assert snapshot.created_at  # Timestamp must not be empty

    def test_create_populates_profile_data(self):
        """Created snapshot must reflect all profile data."""
        snapshot = create_snapshot(
            user_id="user-123",
            trigger="profile_update",
            profile_data=SAMPLE_PROFILE,
        )
        assert snapshot.age == 35
        assert snapshot.gross_income == 120_000.0
        assert snapshot.canton == "VD"
        assert snapshot.archetype == "swiss_native"
        assert snapshot.household_type == "married"
        assert snapshot.replacement_ratio == 0.62
        assert snapshot.months_liquidity == 4.5
        assert snapshot.tax_saving_potential == 7_258.0
        assert snapshot.confidence_score == 72.0
        assert snapshot.enrichment_count == 3
        assert snapshot.fri_total == 65.0

    def test_create_with_empty_profile(self):
        """Must handle empty profile data (use defaults)."""
        snapshot = create_snapshot(
            user_id="user-123",
            trigger="check_in",
            profile_data={},
        )
        assert snapshot.age == 0
        assert snapshot.gross_income == 0.0
        assert snapshot.canton == "VD"

    def test_invalid_trigger_raises(self):
        """Invalid trigger type must raise ValueError."""
        with pytest.raises(ValueError, match="Invalid trigger"):
            create_snapshot(
                user_id="user-123",
                trigger="invalid_trigger",
                profile_data={},
            )

    def test_all_valid_triggers(self):
        """All valid trigger types must work."""
        for trigger in VALID_TRIGGERS:
            snapshot = create_snapshot(
                user_id=f"user-{trigger}",
                trigger=trigger,
                profile_data={},
            )
            assert snapshot.trigger == trigger


# ═══════════════════════════════════════════════════════════════════════════════
# Get snapshots tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestGetSnapshots:
    """Test snapshot retrieval."""

    def test_get_returns_reverse_chronological(self):
        """Snapshots must be returned most recent first."""
        create_snapshot("user-1", "quarterly", {"age": 30})
        time.sleep(0.01)  # Ensure different timestamps
        create_snapshot("user-1", "profile_update", {"age": 31})
        time.sleep(0.01)
        create_snapshot("user-1", "check_in", {"age": 32})

        snapshots = get_snapshots("user-1")
        assert len(snapshots) == 3
        assert snapshots[0].trigger == "check_in"  # Most recent
        assert snapshots[2].trigger == "quarterly"  # Oldest

    def test_get_respects_limit(self):
        """Limit parameter must cap the number of results."""
        for i in range(5):
            create_snapshot("user-1", "quarterly", {"age": 30 + i})

        snapshots = get_snapshots("user-1", limit=3)
        assert len(snapshots) == 3

    def test_empty_user_returns_empty(self):
        """Non-existent user must return empty list."""
        snapshots = get_snapshots("non-existent-user")
        assert snapshots == []


# ═══════════════════════════════════════════════════════════════════════════════
# Delete snapshots tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestDeleteSnapshots:
    """Test snapshot deletion (LPD compliance)."""

    def test_delete_returns_correct_count(self):
        """Must return the number of deleted snapshots."""
        create_snapshot("user-1", "quarterly", {})
        create_snapshot("user-1", "quarterly", {})
        create_snapshot("user-1", "quarterly", {})

        count = delete_all_snapshots("user-1")
        assert count == 3

    def test_delete_removes_all(self):
        """After deletion, get must return empty."""
        create_snapshot("user-1", "quarterly", {})
        create_snapshot("user-1", "quarterly", {})

        delete_all_snapshots("user-1")
        assert get_snapshots("user-1") == []

    def test_delete_non_existent_returns_zero(self):
        """Deleting non-existent user must return 0."""
        count = delete_all_snapshots("non-existent")
        assert count == 0

    def test_delete_does_not_affect_other_users(self):
        """Deletion must only affect the specified user."""
        create_snapshot("user-1", "quarterly", {})
        create_snapshot("user-2", "quarterly", {})

        delete_all_snapshots("user-1")
        assert len(get_snapshots("user-1")) == 0
        assert len(get_snapshots("user-2")) == 1


# ═══════════════════════════════════════════════════════════════════════════════
# Evolution tests
# ═══════════════════════════════════════════════════════════════════════════════

class TestGetEvolution:
    """Test evolution time series."""

    def test_evolution_returns_chronological(self):
        """Evolution data must be in chronological order (oldest first)."""
        create_snapshot("user-1", "quarterly", {"replacement_ratio": 0.50})
        time.sleep(0.01)
        create_snapshot("user-1", "quarterly", {"replacement_ratio": 0.55})
        time.sleep(0.01)
        create_snapshot("user-1", "quarterly", {"replacement_ratio": 0.60})

        evolution = get_evolution("user-1", "replacement_ratio")
        assert len(evolution) == 3
        assert evolution[0]["value"] == 0.50  # Oldest
        assert evolution[2]["value"] == 0.60  # Newest

    def test_evolution_tracks_field(self):
        """Must correctly track the requested field."""
        create_snapshot("user-1", "quarterly", {"months_liquidity": 3.0})
        create_snapshot("user-1", "quarterly", {"months_liquidity": 4.5})

        evolution = get_evolution("user-1", "months_liquidity")
        assert len(evolution) == 2
        assert evolution[0]["value"] == 3.0
        assert evolution[1]["value"] == 4.5

    def test_evolution_includes_trigger(self):
        """Each data point must include the trigger."""
        create_snapshot("user-1", "quarterly", {"replacement_ratio": 0.50})
        create_snapshot("user-1", "life_event", {"replacement_ratio": 0.55})

        evolution = get_evolution("user-1", "replacement_ratio")
        triggers = [dp["trigger"] for dp in evolution]
        assert "quarterly" in triggers
        assert "life_event" in triggers

    def test_invalid_field_raises(self):
        """Invalid field name must raise ValueError."""
        with pytest.raises(ValueError, match="Invalid field"):
            get_evolution("user-1", "invalid_field")

    def test_empty_user_returns_empty(self):
        """Non-existent user must return empty evolution."""
        evolution = get_evolution("non-existent", "replacement_ratio")
        assert evolution == []

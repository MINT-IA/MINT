"""D-17 snapshot cache invalidation tests (Plan 02-02 P1).

Asserts that `is_snapshot_stale()` returns True when the active regulatory
`constants_version_hash` differs from the hash stamped on a SnapshotModel
row, and False when they match.

Also asserts the cache-key format includes `constants_version_hash` so a
regulatory rotation naturally evicts the key.
"""
from __future__ import annotations

from datetime import date
from types import SimpleNamespace

from app.services.cache.snapshot_cache import (
    cache_key_for_snapshot,
    is_snapshot_stale,
)


def test_cache_key_includes_constants_version_hash() -> None:
    """D-17 — cache key separates entries by constants_version_hash."""
    k1 = cache_key_for_snapshot("user-1", "inputs-h", "constants-v1")
    k2 = cache_key_for_snapshot("user-1", "inputs-h", "constants-v2")
    assert k1 != k2
    assert "constants-v1" in k1
    assert "constants-v2" in k2


def test_cache_key_format_is_stable() -> None:
    """Format contract : `snapshot:{user_id}:{inputs_hash}:{constants_version_hash}`."""
    k = cache_key_for_snapshot("alice", "abc", "v1")
    assert k == "snapshot:alice:abc:v1"


def test_is_stale_returns_false_when_hashes_match(monkeypatch) -> None:
    """Snapshot stamp matches active registry → not stale."""
    from app.services.regulatory.registry import RegulatoryRegistry

    monkeypatch.setattr(
        RegulatoryRegistry, "instance",
        classmethod(lambda cls: SimpleNamespace(version_hash=lambda on_date: "STAMPED_HASH"))
    )
    row = SimpleNamespace(constants_version_hash="STAMPED_HASH")
    assert is_snapshot_stale(row) is False


def test_is_stale_returns_true_when_registry_rotated(monkeypatch) -> None:
    """Active registry hash differs from stamped → stale, recompute."""
    from app.services.regulatory.registry import RegulatoryRegistry

    monkeypatch.setattr(
        RegulatoryRegistry, "instance",
        classmethod(lambda cls: SimpleNamespace(version_hash=lambda on_date: "NEW_HASH"))
    )
    row = SimpleNamespace(constants_version_hash="OLD_HASH")
    assert is_snapshot_stale(row) is True


def test_is_stale_returns_false_for_legacy_unstamped_row(monkeypatch) -> None:
    """Pre-Hotfix-B legacy row without stamp is treated as fresh by convention."""
    from app.services.regulatory.registry import RegulatoryRegistry

    monkeypatch.setattr(
        RegulatoryRegistry, "instance",
        classmethod(lambda cls: SimpleNamespace(version_hash=lambda on_date: "ANY"))
    )
    row = SimpleNamespace(constants_version_hash=None)
    assert is_snapshot_stale(row) is False
    row2 = SimpleNamespace()  # no attribute at all
    assert is_snapshot_stale(row2) is False


def test_is_stale_accepts_explicit_on_date(monkeypatch) -> None:
    """`on_date` argument flows through to RegulatoryRegistry.version_hash."""
    seen_dates: list[date] = []

    def _version_hash(on_date: date) -> str:
        seen_dates.append(on_date)
        return "X"

    from app.services.regulatory.registry import RegulatoryRegistry

    monkeypatch.setattr(
        RegulatoryRegistry, "instance",
        classmethod(lambda cls: SimpleNamespace(version_hash=_version_hash))
    )
    row = SimpleNamespace(constants_version_hash="X")
    is_snapshot_stale(row, on_date=date(2026, 1, 1))
    assert seen_dates == [date(2026, 1, 1)]

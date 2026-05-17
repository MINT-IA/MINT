"""Tests for RegulatoryRegistry.version_hash (Hotfix B 2026-05-17).

The hash is the load-bearing primitive of the LSFin advice-audit trail:
every persisted projection stamps it on, and reconstructability depends
on it being deterministic + sensitive to the parameter set in scope at
the requested date.

These are pure (no DB) tests of the hash contract:
    - 64-char SHA-256 hex output shape.
    - Deterministic across calls for the same date.
    - Different across dates when the active parameter set differs
      (uses the AVS 13th-pension flip on 2026-01-01 as the anchor:
      keys `avs.13th_pension_active` / `_start_year` / `_factor` are
      `effective_from=date(2026, 1, 1)`, so 2025 ⇒ inactive,
      2026 ⇒ active).
"""

import re
from datetime import date

import pytest

from app.services.regulatory.registry import RegulatoryRegistry


@pytest.fixture
def registry() -> RegulatoryRegistry:
    return RegulatoryRegistry.instance()


def test_version_hash_returns_64char_hex(registry: RegulatoryRegistry) -> None:
    h = registry.version_hash(on_date=date(2026, 5, 17))
    assert re.fullmatch(r"[0-9a-f]{64}", h), f"expected 64-char sha256 hex, got {h!r}"


def test_version_hash_is_deterministic(registry: RegulatoryRegistry) -> None:
    target_date = date(2026, 3, 15)
    h1 = registry.version_hash(on_date=target_date)
    h2 = registry.version_hash(on_date=target_date)
    assert h1 == h2, "version_hash must be stable across calls for the same date"


def test_version_hash_changes_when_active_set_changes(
    registry: RegulatoryRegistry,
) -> None:
    # The AVS 13th-pension parameters become active 2026-01-01. So the
    # active set on 2025-12-31 must differ from the active set on
    # 2026-01-01, and the hashes must differ.
    h_2025 = registry.version_hash(on_date=date(2025, 12, 31))
    h_2026 = registry.version_hash(on_date=date(2026, 1, 1))
    assert h_2025 != h_2026, (
        "version_hash should differ across the 2026 AVS 13th-pension activation"
    )


def test_version_hash_today_is_64char_hex(registry: RegulatoryRegistry) -> None:
    h = registry.version_hash()  # on_date=None ⇒ today
    assert re.fullmatch(r"[0-9a-f]{64}", h)

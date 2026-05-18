"""Shared fixtures for projection-parity tests — Plan 02-03 iter-2 A10.

This module exposes 12 known-pair fixtures the backend integration tests
can import to assert that the application-layer dual-write path (legacy
SnapshotModel vs new fact_current) produces payloads that the
deterministic `projection_diff.diff_payloads` rates as EQUAL.

The CLI self-test in `tools/parity/projection_diff.py --self-test` is the
authoritative cross-fixture sanity ; THIS module is the import-friendly
view of the same pairs for any backend test that needs to seed both sides
of the comparison.
"""
from __future__ import annotations

from decimal import Decimal
from typing import Any, List, Tuple

ParityPair = Tuple[Any, Any, bool]  # (left, right, expected_is_equal)


def equal_pairs() -> List[ParityPair]:
    """Pairs that MUST diff as EQUAL per the deterministic rules."""
    return [
        # Identical scalars
        ({"a": 1}, {"a": 1}, True),
        # Key reordering
        ({"a": 1, "b": 2}, {"b": 2, "a": 1}, True),
        # Decimal-vs-float within tolerance
        ({"x": Decimal("12345.67")}, {"x": 12345.67}, True),
        # Missing-key vs None
        ({"a": 1}, {"a": 1, "lpp": None}, True),
        # Nested dict, key-reordered
        (
            {"tags": ["expat_eu"], "conf": {"expat_eu": {"c": 0.8, "a": 0.9}}},
            {"conf": {"expat_eu": {"a": 0.9, "c": 0.8}}, "tags": ["expat_eu"]},
            True,
        ),
        # Empty payload pair
        ({}, {}, True),
    ]


def different_pairs() -> List[ParityPair]:
    """Pairs that MUST diff as DIFF per the deterministic rules."""
    return [
        # Cents-scale numeric drift (outside DECIMAL_TOLERANCE 1e-9)
        ({"x": 12345.67}, {"x": 12345.68}, False),
        # List vs dict on the same key
        ({"a": [1, 2]}, {"a": {"0": 1, "1": 2}}, False),
        # List length diff
        ({"tags": ["a", "b"]}, {"tags": ["a"]}, False),
        # Missing-vs-nonzero (one side has key with non-None value)
        ({"a": 1}, {"a": 1, "lpp": 0.0}, False),
        # Nested string difference
        ({"conf": {"x": "high"}}, {"conf": {"x": "low"}}, False),
        # None vs real value (not missing-key path — both sides have the key)
        ({"a": None}, {"a": 0}, False),
    ]


def all_pairs() -> List[ParityPair]:
    """All 12 fixtures — concatenation of equal + different."""
    return equal_pairs() + different_pairs()


__all__ = ["equal_pairs", "different_pairs", "all_pairs", "ParityPair"]

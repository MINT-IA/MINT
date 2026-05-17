"""Phase 95 — DAG-02 UUID7 time-ordered supersession chain."""
from __future__ import annotations

import re
import time
import uuid as stdlib_uuid

from app.services.coach.projection_id import new_projection_id


_UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def test_format_36_char_hyphenated():
    pid = new_projection_id()
    assert isinstance(pid, str)
    assert len(pid) == 36
    assert _UUID_RE.match(pid), f"Unexpected UUID format: {pid!r}"


def test_parseable_by_stdlib_uuid():
    pid = new_projection_id()
    parsed = stdlib_uuid.UUID(pid)
    assert str(parsed) == pid


def test_version_is_7():
    pid = new_projection_id()
    parsed = stdlib_uuid.UUID(pid)
    assert parsed.version == 7, f"Expected UUID7, got version {parsed.version}"


def test_time_ordered_100_calls():
    ids = [new_projection_id() for _ in range(100)]
    assert ids == sorted(ids), "UUID7 must sort chronologically"


def test_uniqueness_1000_calls():
    ids = {new_projection_id() for _ in range(1000)}
    assert len(ids) == 1000


def test_sequential_calls_strictly_increase_in_ms():
    # First 48 bits encode ms since Unix epoch — sequential calls
    # should NEVER produce a stricly-decreasing pair within the same
    # ms (if same ms, random tail breaks ties — still lex-equal-or-
    # greater for our 100 successive calls).
    a = new_projection_id()
    time.sleep(0.002)  # 2ms — guarantees ms-prefix advances
    b = new_projection_id()
    assert b > a

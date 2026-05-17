"""Tests for Phase mint-data-architecture-v1-01 Plan 02 — Task 3 (ADR status flip).

Surgical flip of the upstream ADR
`.planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md`
from `status: Proposed` to `status: Decided (calc-engine portion)`,
preserving event-log + coach-extractor portions as Proposed per D-04.
"""

from __future__ import annotations

import re
from pathlib import Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


_ADR_REL = ".planning/decisions/2026-05-17-data-architecture-event-log-vs-bitemporal.md"


def _read() -> str:
    return (_repo_root() / _ADR_REL).read_text(encoding="utf-8")


def test_adr_status_flipped() -> None:
    src = _read()
    # Frontmatter `status:` line must start with « Decided (calc-engine portion) »
    # and explicitly call out the still-Proposed portions.
    match = re.search(
        r"^status:\s*Decided \(calc-engine portion\)",
        src,
        re.MULTILINE,
    )
    assert match is not None, (
        "Frontmatter must contain `status: Decided (calc-engine portion)` (line "
        "may continue with « ; Proposed (event-log + coach-extractor) »)."
    )
    # Same line must also mention event-log + coach-extractor as Proposed.
    line_match = re.search(r"^status:.*$", src, re.MULTILINE)
    assert line_match is not None
    line = line_match.group(0)
    assert "event-log" in line and "coach-extractor" in line and "Proposed" in line, (
        f"Frontmatter `status:` line must mention event-log + coach-extractor + "
        f"Proposed. Got : {line!r}"
    )


def test_adr_event_log_still_proposed() -> None:
    src = _read()
    pattern = re.compile(
        r"event-log.*Proposed|Proposed.*event-log|"
        r"event-log schema migration.*Proposed|event-log.*remain Proposed",
        re.IGNORECASE,
    )
    assert pattern.search(src) is not None, (
        "ADR must still flag event-log as Proposed somewhere after the flip."
    )


def test_adr_cites_phase_pointer() -> None:
    src = _read()
    pattern = re.compile(
        r"Phase mint-data-architecture-v1-01-calc-engine-canonical|"
        r"mint-data-architecture-v1-01-calc-engine-canonical"
    )
    assert pattern.search(src) is not None, (
        "ADR must cite the phase slug that resolved the calc-engine portion."
    )


def test_adr_status_followup_dated_entry() -> None:
    src = _read()
    # New dated entry under §Status & follow-up.
    pattern = re.compile(r"###\s*2026-05-17\s*—\s*Calc-engine portion Decided")
    assert pattern.search(src) is not None, (
        "§Status & follow-up must contain a new « ### 2026-05-17 — Calc-engine "
        "portion Decided » dated entry."
    )


def test_adr_carries_canonical_marker_block() -> None:
    src = _read()
    start = "<!-- mint-data-architecture-v1-01-canonical:start -->"
    end = "<!-- mint-data-architecture-v1-01-canonical:end -->"
    assert src.count(start) == 1, (
        f"ADR must contain exactly 1 marker:start, got {src.count(start)}."
    )
    assert src.count(end) == 1, (
        f"ADR must contain exactly 1 marker:end, got {src.count(end)}."
    )

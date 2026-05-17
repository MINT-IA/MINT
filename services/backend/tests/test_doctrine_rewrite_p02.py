"""Tests for Phase mint-data-architecture-v1-01 Plan 02 — Task 1 (doctrine rewrite).

Verifies the L1/L2 split doctrine landed in the 3 doctrine files :
- CLAUDE.md (TOP + BOTTOM triplet #4, §1 IDENTITY, §5 NEVER #3)
- docs/AGENTS/backend.md (line 39 rewrite)
- docs/AGENTS/flutter.md (new L1-canonical block appended)

Surgical marker-wrapped edits per Karpathy #3 + D-04 atomicity.
"""

from __future__ import annotations

import re
from pathlib import Path


def _repo_root() -> Path:
    # tests/ lives at services/backend/tests/, repo root is 3 parents up.
    return Path(__file__).resolve().parents[3]


def _read(rel: str) -> str:
    return (_repo_root() / rel).read_text(encoding="utf-8")


def test_claude_md_carries_l1_l2_split_doctrine() -> None:
    src = _read("CLAUDE.md")
    # TOP + BOTTOM = at least 2 occurrences of « L1 chiffrer ».
    assert src.count("L1 chiffrer") >= 2, (
        "Expected >= 2 occurrences of « L1 chiffrer » (TOP + BOTTOM triplets). "
        f"Got {src.count('L1 chiffrer')}."
    )
    # L2-L4 backend-canonical wording also TOP + BOTTOM.
    pattern = re.compile(
        r"L2-L4.*backend-canonical|backend-canonical.*L2-L4",
        re.IGNORECASE,
    )
    matches = pattern.findall(src)
    assert len(matches) >= 2, (
        "Expected >= 2 « L2-L4 ... backend-canonical » phrases in CLAUDE.md. "
        f"Got {len(matches)} :: {matches!r}"
    )


def test_claude_md_no_unilateral_canonical_claim() -> None:
    src = _read("CLAUDE.md")
    # The unqualified phrase « financial_core/` est SOURCE OF TRUTH. » (terminated by
    # period directly after « TRUTH ») must not appear. The new qualified form
    # « financial_core/` est SOURCE OF TRUTH **pour L1 chiffrer** » continues past
    # the word « TRUTH » without a sentence-terminating period.
    pattern = re.compile(
        r"financial_core/`? est SOURCE OF TRUTH\.( |$)",
        re.MULTILINE,
    )
    hits = pattern.findall(src)
    assert hits == [], (
        "Found unqualified « financial_core/ est SOURCE OF TRUTH. » — "
        "must be qualified with « pour L1 chiffrer »."
    )


def test_backend_md_line39_rewritten() -> None:
    src = _read("docs/AGENTS/backend.md")
    assert src.count("Backend = source of truth pour L2-L4") == 1, (
        "Expected exactly 1 « Backend = source of truth pour L2-L4 » in "
        f"docs/AGENTS/backend.md. Got {src.count('Backend = source of truth pour L2-L4')}."
    )
    # Legacy phrasing must be gone.
    legacy = re.compile(
        r"^- \*\*Backend = source of truth\*\* pour constants et formulas\. Flutter mirrors, jamais n'invente\.$",
        re.MULTILINE,
    )
    assert legacy.search(src) is None, (
        "Legacy backend.md:39 phrasing still present — should have been replaced."
    )


def test_flutter_md_carries_l1_canonical_doctrine() -> None:
    src = _read("docs/AGENTS/flutter.md")
    assert "L1 chiffrer" in src, "Expected « L1 chiffrer » in docs/AGENTS/flutter.md."
    # 4 migrates-backend file names per D-03.
    pattern = re.compile(
        r"monte_carlo_service|tornado_sensitivity_service|"
        r"withdrawal_sequencing_service|arbitrage_engine"
    )
    hits = pattern.findall(src)
    # Each name must appear at least once = >= 4 total hits.
    assert len(hits) >= 4, (
        "Expected >= 4 mentions of (monte_carlo_service / tornado_sensitivity_service / "
        "withdrawal_sequencing_service / arbitrage_engine) in flutter.md. "
        f"Got {len(hits)}."
    )


def test_doctrine_markers_present_and_idempotent() -> None:
    start = "<!-- mint-data-architecture-v1-01-canonical:start -->"
    end = "<!-- mint-data-architecture-v1-01-canonical:end -->"

    claude = _read("CLAUDE.md")
    # CLAUDE.md has 4 marker pairs (one per Zone A-D).
    assert claude.count(start) == 4, (
        f"Expected 4 start markers in CLAUDE.md, got {claude.count(start)}."
    )
    assert claude.count(end) == 4, (
        f"Expected 4 end markers in CLAUDE.md, got {claude.count(end)}."
    )

    backend = _read("docs/AGENTS/backend.md")
    assert backend.count(start) == 1, (
        f"Expected 1 start marker in backend.md, got {backend.count(start)}."
    )
    assert backend.count(end) == 1, (
        f"Expected 1 end marker in backend.md, got {backend.count(end)}."
    )

    flutter = _read("docs/AGENTS/flutter.md")
    assert flutter.count(start) == 1, (
        f"Expected 1 start marker in flutter.md, got {flutter.count(start)}."
    )
    assert flutter.count(end) == 1, (
        f"Expected 1 end marker in flutter.md, got {flutter.count(end)}."
    )


def test_bundle_size_report_cited_in_claude_md() -> None:
    src = _read("CLAUDE.md")
    pattern = re.compile(r"4509 gzip bytes|01-01-BUNDLE-SIZE-REPORT")
    hits = pattern.findall(src)
    assert len(hits) >= 1, (
        "Expected CLAUDE.md to cite « 4509 gzip bytes » or « 01-01-BUNDLE-SIZE-REPORT » "
        f"(Plan 01 empirical evidence). Got {len(hits)} hits."
    )

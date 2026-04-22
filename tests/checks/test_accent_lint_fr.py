"""GUARD-04 — pytest coverage for accent_lint_fr.py PATTERNS list reconciled
with CLAUDE.md §2 (Phase 34 D-11).

Invariants locked by this file:
- PATTERNS contains exactly 14 entries matching the canonical stems in
  CLAUDE.md §2 (Top 5 Rules Critiques #2).
- scan_text / scan_file signatures remain (int, str, str) so Phase 30.7
  TOOL-04 (`check_accent_patterns` MCP wrapper) continues to work.
- New D-11 patterns (prevoyance / reperer / cle) FIRE; old Phase 30.5 extras
  (specialistes / gerer / progres) DO NOT — they are outside the canonical
  set and were removed in Phase 34 Plan 01.

Technical English only — dev-facing per CLAUDE.md §2 self-compliance
(RESEARCH Pitfall 8).
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "checks"))

import accent_lint_fr as lint  # noqa: E402


# Canonical 14 stems per CLAUDE.md §2 (verbatim order).
CANONICAL_STEMS = {
    "creer", "decouvrir", "eclairage", "securite", "liberer", "preter",
    "realiser", "deja", "recu", "elaborer", "regler",
    "prevoyance", "reperer", "cle",
}


# ── Pattern-set invariants ─────────────────────────────────────────────────


def test_pattern_count_matches_canonical():
    """PATTERNS must contain exactly 14 entries per CLAUDE.md §2."""
    assert len(lint.PATTERNS) == 14, (
        f"Expected 14 canonical patterns per CLAUDE.md §2, got {len(lint.PATTERNS)}"
    )


def test_pattern_set_matches_canonical():
    """Each \\bstem\\b regex maps back to exactly the CLAUDE.md §2 stem set."""
    stems = set()
    for pat, _ in lint.PATTERNS:
        # Strip \b boundaries. PATTERNS use plain \bSTEM\b with no suffixes.
        core = pat.replace(r"\b", "").replace("\\b", "")
        stems.add(core)
    assert stems == CANONICAL_STEMS, (
        f"PATTERNS set drift. Missing: {CANONICAL_STEMS - stems}, "
        f"Extra: {stems - CANONICAL_STEMS}"
    )


# ── Canonical patterns: must FIRE ──────────────────────────────────────────


def test_scan_text_flags_creer():
    violations = lint.scan_text("creer un compte")
    assert len(violations) == 1
    assert "creer" in violations[0][2]


def test_scan_text_skips_accented_creer():
    violations = lint.scan_text("créer un compte")
    assert violations == []


def test_scan_text_flags_prevoyance_new_pattern():
    """D-11: prevoyance was MISSING pre-Phase-34 — must fire after reconcile."""
    violations = lint.scan_text("la prevoyance suisse")
    assert len(violations) == 1
    assert "prevoyance" in violations[0][2]


def test_scan_text_flags_reperer_new_pattern():
    """D-11: reperer was MISSING pre-Phase-34 — must fire after reconcile."""
    violations = lint.scan_text("reperer les details")
    assert len(violations) == 1
    assert "reperer" in violations[0][2]


def test_scan_text_flags_cle_new_pattern():
    """D-11: cle was MISSING pre-Phase-34 — must fire after reconcile."""
    violations = lint.scan_text("la cle du probleme")
    # probleme is not in canonical 14 — expect exactly 1 hit on cle.
    assert len(violations) == 1
    assert "cle" in violations[0][2]


# ── Removed extras: must NOT fire ──────────────────────────────────────────


def test_scan_text_ignores_removed_specialistes():
    """D-11 removed 'specialistes' from canonical set — no match expected."""
    violations = lint.scan_text("les specialistes")
    assert violations == []


def test_scan_text_ignores_removed_gerer():
    """D-11 removed 'gerer' from canonical set — no match expected."""
    violations = lint.scan_text("pour gerer le compte")
    assert violations == []


def test_scan_text_ignores_removed_progres():
    """D-11 removed 'progres' from canonical set — no match expected."""
    violations = lint.scan_text("beaucoup de progres")
    assert violations == []


# ── Fixture-based scan_file coverage ───────────────────────────────────────


def test_scan_file_bad_fixture_has_violations(fixtures_dir: Path):
    """Wave 0 accent_bad.dart contains creer, decouvrir, securite — expect ≥3."""
    violations = lint.scan_file(fixtures_dir / "accent_bad.dart")
    stems = set()
    for (_lineno, _snippet, pat) in violations:
        for s in CANONICAL_STEMS:
            if s in pat:
                stems.add(s)
    assert {"creer", "decouvrir", "securite"}.issubset(stems), (
        f"Expected creer+decouvrir+securite in bad fixture, got stems={stems}"
    )


def test_scan_file_good_fixture_clean(fixtures_dir: Path):
    violations = lint.scan_file(fixtures_dir / "accent_good.dart")
    assert violations == []


# ── MCP TOOL-04 signature guard ────────────────────────────────────────────


def test_scan_text_signature_returns_tuples_of_three():
    """Phase 30.7 TOOL-04 MCP wrapper (tools/mcp/mint-tools/tools/accent.py)
    imports scan_text and destructures (lineno, snippet, pattern). Do not
    change this shape without coordinating a Phase 30.7 test update.
    """
    violations = lint.scan_text("creer")
    assert all(isinstance(v, tuple) and len(v) == 3 for v in violations)
    lineno, snippet, pat = violations[0]
    assert isinstance(lineno, int)
    assert isinstance(snippet, str)
    assert isinstance(pat, str)

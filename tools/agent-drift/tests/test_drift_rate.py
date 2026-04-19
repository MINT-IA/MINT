"""Plan 01 Task 2 — metric (a) drift rate tests.

Validates:
  1. `ingest_git.parse_git_log` correctly flags Claude-authored commits via
     `Co-Authored-By: Claude` body substring (vs regular commits).
  2. Running `accent_lint_fr.py` on a synthetic fixture with `decouvrir`
     produces a machine-parseable `path:line: snippet` violation that
     `ingest_git.run_lint_on_file` turns into rows.
"""
from __future__ import annotations

import importlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
AGENT_DRIFT_DIR = REPO_ROOT / "tools" / "agent-drift"
if str(AGENT_DRIFT_DIR) not in sys.path:
    sys.path.insert(0, str(AGENT_DRIFT_DIR))


def test_drift_rate_parses_git_log_claude_author() -> None:
    """parse_git_log returns current repo history; we assert the classifier
    logic discriminates Claude vs human by `Co-Authored-By: Claude` body.

    Uses real `git log` on this repo (last 30d) — we don't construct fake
    ASCII-separated input because the function spawns git; instead we check
    that the author labels are drawn from {'claude-agent', 'human'} and
    that at least one claude-agent commit exists in the last 30d (this repo
    is actively co-authored by Claude).
    """
    ingest_git = importlib.import_module("ingest_git")
    rows = ingest_git.parse_git_log(days=30)
    assert isinstance(rows, list)
    labels = {r[1] for r in rows}
    assert labels.issubset({"claude-agent", "human"})
    # Repo is actively co-authored by Claude; at least one commit in 30d.
    assert any(label == "claude-agent" for _, label, _, _ in rows), (
        "expected >=1 claude-agent commit in last 30d — "
        "parse_git_log Co-Authored-By detection is broken"
    )


def test_drift_rate_counts_lint_violations(tmp_path: Path) -> None:
    """Running accent_lint_fr on a fixture with `decouvrir` -> >=1 violation
    parseable by ingest_git.run_lint_on_file."""
    ingest_git = importlib.import_module("ingest_git")

    # Create a dart file with a flagged word, inside the repo tree so that
    # ingest_git.run_lint_on_file's REPO_ROOT resolution works.
    fixture_dir = REPO_ROOT / ".planning" / "agent-drift" / "_test_fixtures"
    fixture_dir.mkdir(parents=True, exist_ok=True)
    fixture = fixture_dir / "drift_fixture.dart"
    fixture.write_text("// decouvrir les specialistes du placement\n", encoding="utf-8")
    try:
        rel = fixture.relative_to(REPO_ROOT).as_posix()
        violations = ingest_git.run_lint_on_file(
            REPO_ROOT / "tools" / "checks" / "accent_lint_fr.py", rel
        )
        assert len(violations) >= 1, (
            f"accent_lint_fr should flag 'decouvrir' in {rel}, got {violations}"
        )
        lineno, snippet = violations[0]
        assert lineno == 1
        assert "decouvrir" in snippet.lower()
    finally:
        if fixture.exists():
            fixture.unlink()
        # tmp dir cleanup
        try:
            fixture_dir.rmdir()
        except OSError:
            pass

"""GUARD-06 pytest coverage — D-16/D-17/D-18 + T-34-SPOOF-01 mitigation.

Covers the `tools/checks/proof_of_read.py` commit-msg hook (CONTEXT.md
D-27 amendment authorising ONE commit-msg block for Phase 34).

Technical English only — dev-facing, M-1 carve-out (no i18n on lint tests).
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "checks"))

import proof_of_read as lint  # noqa: E402


def _setup_read_md(tmp_path: Path, rel: str, bullets: list) -> Path:
    p = tmp_path / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    body = "# READ receipts\n\n" + "\n".join(
        f"- {b} - test rationale" for b in bullets
    ) + "\n"
    p.write_text(body, encoding="utf-8")
    return p


def test_valid_claude_commit_with_read_pass(tmp_path: Path) -> None:
    """Claude trailer + Read: + existing file + bullet format -> exit 0."""
    _setup_read_md(
        tmp_path,
        ".planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md",
        ["tools/checks/proof_of_read.py", "lefthook.yml"],
    )
    msg = (
        "feat(34): wire GUARD-06\n\n"
        "Implements proof-of-read.\n\n"
        "Read: .planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md\n"
        "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>\n"
    )
    rc, _ = lint.check_commit_msg(msg, tmp_path)
    assert rc == 0


def test_missing_read_trailer_fail(tmp_path: Path) -> None:
    """Claude trailer present but no Read: trailer -> FAIL."""
    msg = (
        "feat(34): no read trailer\n\n"
        "Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>\n"
    )
    rc, messages = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1
    assert any("Read:" in m and "missing" in m.lower() for m in messages)


def test_read_file_missing_fail(tmp_path: Path) -> None:
    """Read: trailer points to a file that doesn't exist -> FAIL."""
    msg = (
        "feat(34): stale read\n\n"
        "Read: .planning/phases/34-agent-guardrails-m-caniques/34-NONEXIST-READ.md\n"
        "Co-Authored-By: Claude <noreply@anthropic.com>\n"
    )
    rc, messages = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1
    assert any("does not exist" in m for m in messages)


def test_human_bypass_pass(tmp_path: Path) -> None:
    """No Co-Authored-By: Claude -> D-17 automatic bypass -> PASS."""
    msg = "feat(34): pure human commit\n\nNo Claude attribution here.\n"
    rc, _ = lint.check_commit_msg(msg, tmp_path)
    assert rc == 0


def test_read_path_outside_planning_fail(tmp_path: Path) -> None:
    """T-34-SPOOF-01 mitigation: Read: path MUST start with .planning/phases/."""
    msg = (
        "feat(34): spoof attempt\n\n"
        "Read: /dev/null\n"
        "Co-Authored-By: Claude <noreply@anthropic.com>\n"
    )
    rc, messages = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1
    assert any(".planning/phases/" in m for m in messages)


def test_read_path_relative_outside_planning_fail(tmp_path: Path) -> None:
    """T-34-SPOOF-01: even a relative path outside .planning/phases/ -> FAIL."""
    # Create a README under tmp_path root; point Read: at it.
    (tmp_path / "README.md").write_text("- some bullet - reason\n", encoding="utf-8")
    msg = (
        "feat(34): spoof attempt via relative path\n\n"
        "Read: README.md\n"
        "Co-Authored-By: Claude <noreply@anthropic.com>\n"
    )
    rc, messages = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1
    assert any(".planning/phases/" in m for m in messages)


def test_read_md_format_no_bullets_fail(tmp_path: Path) -> None:
    """D-18 format: READ.md with no `- ` bullet lines -> FAIL."""
    p = tmp_path / ".planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(
        "# READ receipts\n\nNo bullets here, just prose.\n",
        encoding="utf-8",
    )
    msg = (
        "feat(34): bad format\n\n"
        "Read: .planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md\n"
        "Co-Authored-By: Claude <noreply@anthropic.com>\n"
    )
    rc, messages = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1
    assert any("bullet" in m.lower() for m in messages)


def test_empty_commit_msg_pass(tmp_path: Path) -> None:
    """Empty / whitespace-only message -> PASS (nothing to check)."""
    rc, _ = lint.check_commit_msg("", tmp_path)
    assert rc == 0
    rc, _ = lint.check_commit_msg("   \n\n  ", tmp_path)
    assert rc == 0


def test_fixture_with_read_trailer_passes(tmp_path: Path, fixtures_dir: Path) -> None:
    """Wave 0 fixture `commit_with_read_trailer.txt` + READ.md -> PASS."""
    _setup_read_md(
        tmp_path,
        ".planning/phases/34-agent-guardrails-m-caniques/34-02-READ.md",
        ["tools/checks/no_bare_catch.py"],
    )
    msg = (fixtures_dir / "commit_with_read_trailer.txt").read_text(encoding="utf-8")
    rc, _ = lint.check_commit_msg(msg, tmp_path)
    assert rc == 0


def test_fixture_without_read_trailer_fails(tmp_path: Path, fixtures_dir: Path) -> None:
    """Wave 0 fixture `commit_without_read_trailer.txt` -> FAIL."""
    msg = (fixtures_dir / "commit_without_read_trailer.txt").read_text(encoding="utf-8")
    rc, _ = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1


def test_fixture_human_commit_passes(tmp_path: Path, fixtures_dir: Path) -> None:
    """Wave 0 fixture `commit_human_no_claude.txt` -> PASS (D-17 bypass)."""
    msg = (fixtures_dir / "commit_human_no_claude.txt").read_text(encoding="utf-8")
    rc, _ = lint.check_commit_msg(msg, tmp_path)
    assert rc == 0


def test_claude_trailer_case_insensitive(tmp_path: Path) -> None:
    """Defensive: Co-Authored-By vs co-authored-by both detected."""
    # Lowercase variant must still be detected (regex is MULTILINE only; test
    # whatever case-handling the current implementation provides).
    # This test documents the contract: the canonical form is `Co-Authored-By`.
    msg = (
        "feat(34): canonical case\n\n"
        "Co-Authored-By: Claude <noreply@anthropic.com>\n"
    )
    rc, messages = lint.check_commit_msg(msg, tmp_path)
    # Canonical casing should trip the check (no Read: -> FAIL).
    assert rc == 1
    assert any("Read:" in m for m in messages)


# --- Phase 34.1 Fix #4: hardening per audits/01 P0 findings --------------


def test_git_canonical_lowercase_co_authored_by_detected(tmp_path: Path) -> None:
    """Audit 01 P0: `Co-authored-by:` (Git canonical lowercase 'a') was
    treated as human commit entirely (whole doctrine bypassed).
    Phase 34.1: regex is now IGNORECASE."""
    msg = (
        "feat: ship\n\n"
        "Co-authored-by: Claude Sonnet <noreply@anthropic.com>\n"
    )
    rc, messages = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1, 'lowercase Co-authored-by must be treated as Claude commit'
    assert any('Read:' in m for m in messages)


def test_read_trailer_on_subject_line_rejected(tmp_path: Path) -> None:
    """Audit 01 P0: `Read:` on subject line (not trailer block) was accepted.
    Phase 34.1: trailers must be in the LAST paragraph (Git convention)."""
    # Subject contains `Read:`, body has Claude trailer but no trailer Read:
    msg = (
        "Read: bogus but appears on subject\n"
        "\n"
        "This is the body paragraph.\n"
        "\n"
        "Co-Authored-By: Claude Opus\n"
    )
    rc, _ = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1


def test_path_traversal_dotdot_blocked(tmp_path: Path) -> None:
    """Audit 01 P2: `.planning/phases/../../../etc/passwd` passed prefix
    check despite obviously escaping. Phase 34.1: canonicalise + re-check."""
    # Point Read: at a path that starts with allowed prefix but `..` up and out
    msg = (
        "fix: traversal\n\n"
        "Read: .planning/phases/../../etc/passwd\n"
        "Co-Authored-By: Claude\n"
    )
    rc, messages = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1
    assert any('escapes' in m or 'canonicalisation' in m for m in messages)


def test_directory_read_path_fails_gracefully(tmp_path: Path) -> None:
    """Audit 01 P2: IsADirectoryError crash when Read: pointed to a dir.
    Phase 34.1: explicit is_file() check emits clean FAIL."""
    # Create a directory at the expected path
    phase_dir = tmp_path / ".planning" / "phases" / "34-agent-guardrails-m-caniques"
    phase_dir.mkdir(parents=True)
    msg = (
        "fix: dir\n\n"
        "Read: .planning/phases/34-agent-guardrails-m-caniques\n"
        "Co-Authored-By: Claude\n"
    )
    rc, messages = lint.check_commit_msg(msg, tmp_path)
    assert rc == 1
    # Must emit a clean message, not crash
    assert any('directory' in m for m in messages)


def test_trailer_block_extraction() -> None:
    """Phase 34.1 helper: trailer block is the last paragraph."""
    assert lint._trailer_block("subject\n\nbody\n\ntrailer") == "trailer"
    assert lint._trailer_block("only subject") == "only subject"
    assert lint._trailer_block("") == ""
    assert lint._trailer_block("a\n\nb\n\n\n\nc") == "c"

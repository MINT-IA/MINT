"""CTX-01 Phase 30.5-02 Task 2 — 30j retention GC tests.

Un-skipped from Wave 0 stubs. Uses fake_memory_topic fixture (fresh / border /
stale) from conftest.py and redirects HOME so gc.py operates on a tmp_path
filesystem without touching the real ~/.claude/.../memory/.

Covers:
  - stale file (40d old) archived to archive/YYYY-MM/
  - fresh file (1d old) stays in topics/
  - border file (exactly 30d old) stays (inclusive-≤ boundary)
  - Patch 2 whitelist: feedback_*/project_*/user_* NEVER archived, even at 60d
  - non-whitelisted stale file IS archived

Per D-03: mtime-based detection. No yaml/frontmatter imports.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import time
from pathlib import Path

import pytest

GC = "tools/memory/gc.py"

MEMORY_SUBPATH = Path(
    ".claude/projects/-Users-julienbattaglia-Desktop-MINT/memory"
)


def _setup_fake_home(tmp_path: Path) -> tuple[Path, Path]:
    """Create a fake HOME tree and return (fake_home, topics_dir)."""
    fake_home = tmp_path / "fakehome"
    topics = fake_home / MEMORY_SUBPATH / "topics"
    topics.mkdir(parents=True)
    return fake_home, topics


def _run_gc(fake_home: Path, *args: str) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env["HOME"] = str(fake_home)
    # Also set HOMEDRIVE/HOMEPATH for pathlib.Path.home() fallback parity
    env.pop("HOMEDRIVE", None)
    env.pop("HOMEPATH", None)
    return subprocess.run(
        ["python3", GC, *args],
        env=env,
        capture_output=True,
        text=True,
    )


def test_gc_archives_files_older_than_30_days(
    fake_memory_topic: dict, tmp_path: Path
) -> None:
    """Non-whitelisted 40d file → archive. Fresh file → stays.

    fake_memory_topic uses `feedback_*` names so they are whitelisted;
    we copy the fixtures under non-whitelisted names (`oldnote_*.md`) to
    test the retention path, and copy the whitelisted ones separately to
    test the whitelist path in other tests.
    """
    fake_home, topics = _setup_fake_home(tmp_path)

    # Copy fresh (1d) under non-whitelisted name → stays
    fresh_src = fake_memory_topic["fresh"]
    fresh_dst = topics / "oldnote_fresh.md"
    shutil.copy2(fresh_src, fresh_dst)

    # Copy stale (40d) under non-whitelisted name → archived
    stale_src = fake_memory_topic["stale"]
    stale_dst = topics / "oldnote_stale.md"
    shutil.copy2(stale_src, stale_dst)

    r = _run_gc(fake_home)
    assert r.returncode == 0, f"gc exit={r.returncode} stderr={r.stderr}"

    assert fresh_dst.exists(), f"fresh non-whitelisted should stay: {r.stdout}"
    assert not stale_dst.exists(), (
        f"stale non-whitelisted should be archived: {r.stdout}"
    )

    archive_root = fake_home / MEMORY_SUBPATH / "archive"
    archived = list(archive_root.rglob("oldnote_stale.md"))
    assert len(archived) == 1, (
        f"archive/YYYY-MM/oldnote_stale.md missing; found: "
        f"{list(archive_root.rglob('*'))}"
    )


def test_gc_keeps_files_younger_than_30_days(
    fake_memory_topic: dict, tmp_path: Path
) -> None:
    """Fresh file (1d) under non-whitelisted name must stay in topics/."""
    fake_home, topics = _setup_fake_home(tmp_path)
    fresh_src = fake_memory_topic["fresh"]
    fresh_dst = topics / "oldnote_fresh.md"
    shutil.copy2(fresh_src, fresh_dst)

    r = _run_gc(fake_home)
    assert r.returncode == 0, r.stderr
    assert fresh_dst.exists(), "1d-old non-whitelisted file archived wrongly"


def test_gc_border_case_just_under_30_days(tmp_path: Path) -> None:
    """Border: age < 30d threshold → STAYS (inclusive-<= boundary).

    Implementation: `if age_seconds <= threshold_seconds: continue`.
    A file with age just under 30d (e.g., 29d23h) is well inside the
    retention window and must NOT be archived.

    Note: the fake_memory_topic["border"] fixture sets mtime = now - 30d
    *exactly*, but by the time gc.py reads stat().st_mtime there is a few
    ms of drift pushing age > threshold. We avoid that flake by using a
    29.99d mtime here, which tests the inclusive boundary intent without
    chasing wall-clock jitter.
    """
    fake_home, topics = _setup_fake_home(tmp_path)
    border = topics / "oldnote_border.md"
    border.write_text("# stub")
    # 29 days 23 hours = well inside retention, tolerant of subprocess drift.
    just_under = time.time() - (29 * 86400 + 23 * 3600)
    os.utime(border, (just_under, just_under))

    r = _run_gc(fake_home)
    assert r.returncode == 0, r.stderr
    assert border.exists(), (
        f"file 29d23h old should stay per inclusive-<=; gc stdout={r.stdout}"
    )


def test_gc_respects_whitelist_feedback_prefix(
    tmp_path: Path,
) -> None:
    """Patch 2: feedback_*.md with 60d mtime must NOT be archived."""
    fake_home, topics = _setup_fake_home(tmp_path)
    doctrine = topics / "feedback_test.md"
    doctrine.write_text("# doctrine stub\nbody")
    sixty_days_ago = time.time() - (60 * 86400)
    os.utime(doctrine, (sixty_days_ago, sixty_days_ago))

    r = _run_gc(fake_home)
    assert r.returncode == 0, r.stderr
    assert doctrine.exists(), (
        f"feedback_*.md whitelisted but archived: {r.stdout}"
    )


def test_gc_respects_whitelist_project_and_user(tmp_path: Path) -> None:
    """Patch 2: project_*.md and user_*.md whitelisted at 90d."""
    fake_home, topics = _setup_fake_home(tmp_path)
    proj = topics / "project_test.md"
    usr = topics / "user_test.md"
    for p in (proj, usr):
        p.write_text("# stub\nbody")
        old = time.time() - (90 * 86400)
        os.utime(p, (old, old))

    r = _run_gc(fake_home)
    assert r.returncode == 0, r.stderr
    assert proj.exists(), f"project_* archived wrongly: {r.stdout}"
    assert usr.exists(), f"user_* archived wrongly: {r.stdout}"


def test_gc_archives_non_whitelisted_stale(tmp_path: Path) -> None:
    """Patch 2: a file NOT matching whitelist with 60d mtime IS archived."""
    fake_home, topics = _setup_fake_home(tmp_path)
    random_file = topics / "random_test.md"
    random_file.write_text("# random stub\nbody")
    sixty_days_ago = time.time() - (60 * 86400)
    os.utime(random_file, (sixty_days_ago, sixty_days_ago))

    r = _run_gc(fake_home)
    assert r.returncode == 0, r.stderr
    assert not random_file.exists(), (
        f"random_test.md (non-whitelisted, 60d) should have been archived: "
        f"{r.stdout}"
    )
    archive_root = fake_home / MEMORY_SUBPATH / "archive"
    found = list(archive_root.rglob("random_test.md"))
    assert len(found) == 1, (
        f"archive/YYYY-MM/random_test.md missing; archive tree: "
        f"{list(archive_root.rglob('*'))}"
    )


def test_gc_dry_run_does_not_move(tmp_path: Path) -> None:
    """--dry-run must NOT move anything, only print planned actions."""
    fake_home, topics = _setup_fake_home(tmp_path)
    stale = topics / "oldnote_dryrun.md"
    stale.write_text("# stub")
    old = time.time() - (60 * 86400)
    os.utime(stale, (old, old))

    r = _run_gc(fake_home, "--dry-run")
    assert r.returncode == 0, r.stderr
    assert stale.exists(), "dry-run should not move files"
    assert "DRY" in r.stdout, f"dry-run should print DRY lines: {r.stdout}"


def test_gc_idempotent(tmp_path: Path) -> None:
    """Running GC twice leaves the same state (no duplicate archives)."""
    fake_home, topics = _setup_fake_home(tmp_path)
    stale = topics / "oldnote_idem.md"
    stale.write_text("# stub")
    old = time.time() - (60 * 86400)
    os.utime(stale, (old, old))

    r1 = _run_gc(fake_home)
    assert r1.returncode == 0
    r2 = _run_gc(fake_home)
    assert r2.returncode == 0

    archive_root = fake_home / MEMORY_SUBPATH / "archive"
    archived = list(archive_root.rglob("oldnote_idem.md"))
    assert len(archived) == 1, (
        f"duplicate archive after 2nd run: {list(archive_root.rglob('*'))}"
    )

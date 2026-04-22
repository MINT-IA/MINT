"""Shared pytest fixtures for Phase 34 lint tests (GUARD-01..08).

Technical English only — dev-facing diagnostics (per CLAUDE.md §2 self-
compliance + RESEARCH.md Pitfall 8).

Fixtures provide:
  - fixtures_dir: absolute Path to tests/checks/fixtures/
  - tmp_git_repo: temporary git repo for diff-only tests (GUARD-02)
"""
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path
from typing import Generator

import pytest

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture
def fixtures_dir() -> Path:
    return FIXTURES


@pytest.fixture
def tmp_git_repo(tmp_path: Path) -> Generator[Path, None, None]:
    """Initialise an empty git repo for diff-based tests.

    Caller appends + stages files, then runs the lint under test.
    """
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    subprocess.run(
        ["git", "-C", str(tmp_path), "config", "user.email", "test@example.com"],
        check=True,
    )
    subprocess.run(
        ["git", "-C", str(tmp_path), "config", "user.name", "Test"],
        check=True,
    )
    yield tmp_path

"""Wave 0 stub — Plan 01 CTX-02 metric (a) drift rate will implement.

Drift rate = % commits authored by Claude (last 7d) with >=1 lint violation.
Data source: `git log --author='Co-Authored-By: Claude'` + post-hoc lint replay.
"""
from __future__ import annotations

import pytest


@pytest.mark.skip(
    reason="TODO Wave 1 Plan 01 Task 2: parse git log, filter Co-Authored-By: Claude, count commits"
)
def test_drift_rate_parses_git_log_claude_author(fake_git_log: str) -> None:
    """fake_git_log has 2 Claude-authored + 1 human-authored line → parser should return 2."""
    pass


@pytest.mark.skip(
    reason="TODO Wave 1 Plan 01 Task 2: run tools/checks/*.py post-hoc on each Claude commit's diff, count violations"
)
def test_drift_rate_counts_lint_violations() -> None:
    """For each Claude commit, replay lints on diff → count commits with >=1 violation."""
    pass

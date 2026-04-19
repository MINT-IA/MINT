"""Shared fixtures for tools/agent-drift/ test suite.

Consumed by test_schema.py, test_drift_rate.py, test_token_cost.py, test_memory_gc.py.
Wave 0 scaffolding (Phase 30.5 Plan 00) — fixtures return minimal valid data so that
Wave 1-2 plans can un-skip tests by replacing their body, not re-plumbing fixtures.

Refs:
  - .planning/phases/30.5-context-sanity/30.5-CONTEXT.md D-11 (metric data sources)
  - .planning/phases/30.5-context-sanity/30.5-RESEARCH.md §Validation Architecture
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

import pytest


@pytest.fixture
def fake_git_log() -> str:
    """Mimics `git log --format='%H %ae %s' --author='Co-Authored-By: Claude' -n 5` output.

    Used by test_drift_rate.py to validate parsing of Claude-authored commits vs
    human-authored commits. Exactly 3 rows: 2 Claude + 1 human, to test filter logic.
    """
    return "\n".join(
        [
            "abc123 claude@anthropic.com feat(ctx): task 1",
            "def456 claude@anthropic.com fix(ctx): accent oublie",
            "789xyz human@example.com chore: no-op",
        ]
    )


@pytest.fixture
def fake_jsonl_transcript(tmp_path: Path) -> Path:
    """Returns path to a synthetic .claude/projects/.../*.jsonl transcript.

    Contains one session_start event + 2 assistant turns with `usage` blocks.
    Used by test_token_cost.py to validate token-sum parsing.
    """
    p = tmp_path / "session_abc.jsonl"
    events = [
        {
            "type": "session_start",
            "timestamp": "2026-04-19T08:00:00Z",
            "session_id": "abc",
        },
        {
            "type": "assistant",
            "message": {
                "usage": {
                    "input_tokens": 100,
                    "output_tokens": 50,
                    "cache_creation_input_tokens": 2000,
                    "cache_read_input_tokens": 500,
                }
            },
        },
        {
            "type": "assistant",
            "message": {
                "usage": {
                    "input_tokens": 80,
                    "output_tokens": 30,
                    "cache_creation_input_tokens": 0,
                    "cache_read_input_tokens": 2500,
                }
            },
        },
    ]
    p.write_text("\n".join(json.dumps(e) for e in events))
    return p


@pytest.fixture
def fake_memory_topic(tmp_path: Path) -> dict:
    """Creates 3 markdown files in tmp_path/topics/ with controllable mtime.

    Returns dict with 3 keys:
      - 'fresh': mtime = now - 1d (must NOT be archived by 30j GC)
      - 'stale': mtime = now - 40d (MUST be archived by 30j GC)
      - 'border': mtime = now - 30d exactly (behavior = archive, per D-02 rationale)

    Used by test_memory_gc.py to validate CTX-01 retention gate.
    """
    topics = tmp_path / "topics"
    topics.mkdir()
    now = time.time()
    result: dict[str, Path] = {}
    for name, age_days in [("fresh", 1), ("stale", 40), ("border", 30)]:
        p = topics / f"feedback_{name}.md"
        p.write_text(f"# feedback_{name}\nbody")
        mtime = now - (age_days * 86400)
        os.utime(p, (mtime, mtime))
        result[name] = p
    return result

"""Wave 0 stub — Plan 01 CTX-02 metric (c) token cost per session.

Data source: .claude/projects/-Users-julienbattaglia-Desktop-MINT/*.jsonl on disk.
Sum usage.input_tokens + usage.output_tokens across assistant turns per session_id.
Zero API call to Anthropic (transcripts already logged locally).
"""
from __future__ import annotations

from pathlib import Path

import pytest


@pytest.mark.skip(
    reason="TODO Wave 1 Plan 01 Task 2: parse jsonl transcript, sum input+output tokens per session"
)
def test_token_cost_sums_usage_from_jsonl(fake_jsonl_transcript: Path) -> None:
    """fake_jsonl_transcript has 2 assistant turns: (100+50) + (80+30) = 260 tokens total."""
    pass


@pytest.mark.skip(
    reason="TODO Wave 1 Plan 01 Task 2: skip lines that fail json.loads (graceful malformed handling)"
)
def test_token_cost_skips_malformed_lines() -> None:
    """Parser must tolerate partial/malformed jsonl rows without crashing."""
    pass

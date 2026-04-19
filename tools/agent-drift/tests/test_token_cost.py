"""Plan 01 Task 2 — metric (c) token cost tests.

Validates ingest_jsonl.aggregate_session correctly sums usage fields from a
synthetic transcript (fake_jsonl_transcript fixture) and tolerates malformed
JSON lines without crashing.
"""
from __future__ import annotations

import importlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
AGENT_DRIFT_DIR = REPO_ROOT / "tools" / "agent-drift"
if str(AGENT_DRIFT_DIR) not in sys.path:
    sys.path.insert(0, str(AGENT_DRIFT_DIR))


def test_token_cost_sums_usage_from_jsonl(fake_jsonl_transcript: Path) -> None:
    """fixture has 2 assistant turns: input 100+80, output 50+30, cache creates 2000+0, cache reads 500+2500."""
    ingest_jsonl = importlib.import_module("ingest_jsonl")
    sid, started_at, totals = ingest_jsonl.aggregate_session(fake_jsonl_transcript)

    assert sid == "session_abc"
    assert started_at is not None  # parsed from `2026-04-19T08:00:00Z`
    assert totals["input"] == 180, totals
    assert totals["output"] == 80, totals
    assert totals["cache_create"] == 2000, totals
    assert totals["cache_read"] == 3000, totals


def test_token_cost_skips_malformed_lines(tmp_path: Path) -> None:
    """Malformed JSONL rows must be silently skipped."""
    ingest_jsonl = importlib.import_module("ingest_jsonl")

    p = tmp_path / "malformed.jsonl"
    p.write_text(
        "\n".join(
            [
                '{"type":"session_start","timestamp":"2026-04-19T08:00:00Z"}',
                "{this is not valid json",  # malformed
                '{"message":{"usage":{"input_tokens":10,"output_tokens":5}}}',
                "",
                '{"message":{"usage":{"input_tokens":7,"output_tokens":3}}}',
            ]
        ),
        encoding="utf-8",
    )
    sid, started_at, totals = ingest_jsonl.aggregate_session(p)
    assert sid == "malformed"
    assert started_at is not None
    # Malformed row skipped; totals reflect the 2 valid usage rows only.
    assert totals["input"] == 17, totals
    assert totals["output"] == 8, totals

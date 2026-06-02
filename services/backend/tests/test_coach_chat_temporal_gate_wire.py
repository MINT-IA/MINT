"""CJT-021 runtime temporal gate wire-up tests."""
from __future__ import annotations

import pathlib
import re

import pytest

_COACH_CHAT_PATH = (
    pathlib.Path(__file__).resolve().parent.parent
    / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
)


@pytest.fixture(scope="module")
def coach_chat_source() -> str:
    return _COACH_CHAT_PATH.read_text(encoding="utf-8")


def test_runtime_temporal_gate_imported(coach_chat_source: str):
    assert "runtime_temporal_gate" in coach_chat_source


def test_temporal_gate_call_precedes_citation_gate_call(coach_chat_source: str):
    func_re = re.compile(
        r"async def _run_narrator_with_gate\b[\s\S]*?"
        r"(?=async def _run_narrator_with_gate_and_cap)",
        re.MULTILINE,
    )
    match = func_re.search(coach_chat_source)
    assert match, "_run_narrator_with_gate not found in expected position"
    body = match.group(0)

    temporal_match = re.search(r"_runtime_temporal_gate\s*\(", body)
    citation_match = re.search(r"_citation_gate\s*\(", body)

    assert temporal_match, "temporal-gate call missing in _run_narrator_with_gate"
    assert citation_match, "citation-gate call missing in _run_narrator_with_gate"
    assert temporal_match.start() < citation_match.start()


def test_temporal_gate_breadcrumb_category_present(coach_chat_source: str):
    assert "coach.temporal_gate.fired" in coach_chat_source

"""Wave 1a Plan 07 — parity-test fixture loader.

Loads ``services/backend/tests/fixtures/coach_tools_parity_v1.jsonl``
(18 fixtures, 3 archetypes x 6 tools) and exposes:

  * ``load_parity_fixtures()`` — pure function, returns all 18 dicts.
    Importable from any test file via
    ``from tests.test_coach_tools_pkg.conftest import load_parity_fixtures``.
  * ``parity_fixtures`` pytest fixture — session-scoped callable
    ``parity_fixtures(tool: str) -> list[dict]`` returning the 3 dicts
    for that tool.

Loader raises ``RuntimeError`` if the JSONL is malformed (one fixture
per line, no trailing comma, no comment lines).
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Callable, List

import pytest

# ``Path(__file__).parent`` resolves to ``services/backend/tests/test_coach_tools_pkg/``.
# ``.parent`` again is ``services/backend/tests/``. The JSONL lives under
# ``services/backend/tests/fixtures/coach_tools_parity_v1.jsonl``.
_FIXTURE_PATH: Path = (
    Path(__file__).parent.parent / "fixtures" / "coach_tools_parity_v1.jsonl"
)


def load_parity_fixtures() -> List[dict]:
    """Load and parse the 18 parity fixtures.

    Returns:
        ``list[dict]`` — one dict per line, JSON-decoded.

    Raises:
        RuntimeError: when the JSONL contains a malformed line. The
            error message cites the file path and 1-indexed line number.
        FileNotFoundError: when the fixture file is absent.
    """
    if not _FIXTURE_PATH.exists():
        raise FileNotFoundError(
            f"parity fixture file missing: {_FIXTURE_PATH}"
        )
    fixtures: List[dict] = []
    with _FIXTURE_PATH.open("r", encoding="utf-8") as fp:
        for lineno, raw in enumerate(fp, start=1):
            line = raw.strip()
            if not line:
                continue
            try:
                fixtures.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise RuntimeError(
                    f"malformed parity fixture at {_FIXTURE_PATH}:{lineno}: {exc}"
                ) from exc
    return fixtures


@pytest.fixture(scope="session")
def all_parity_fixtures() -> List[dict]:
    """Session-scoped — the full 18-fixture list, parsed once."""
    return load_parity_fixtures()


@pytest.fixture(scope="session")
def parity_fixtures(
    all_parity_fixtures: List[dict],
) -> Callable[[str], List[dict]]:
    """Return a callable: ``parity_fixtures('get_budget_status') -> list[dict]``.

    The plan-07 frontmatter ``<key_links>`` block contract is
    ``fixtures = parity_fixtures(tool='get_budget_status')`` — this
    fixture honors that exact call shape.
    """

    def _get(tool: str) -> List[dict]:
        return [f for f in all_parity_fixtures if f["tool"] == tool]

    return _get

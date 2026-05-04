"""Fail loud if pytest is run under Python <3.10 (mcp SDK minimum)."""
from __future__ import annotations

import sys


def test_python_at_least_310() -> None:
    assert sys.version_info >= (3, 10), (
        f"mcp SDK requires Python >=3.10, got {sys.version_info.major}.{sys.version_info.minor}. "
        "Create venv with python3.11 -m venv tools/mcp/mint-tools/.venv."
    )

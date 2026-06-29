"""Wave 1c payload instrumentation must stay torn down."""

from __future__ import annotations

from pathlib import Path


def test_wave1c_payload_logger_is_not_reintroduced():
    backend_root = Path(__file__).resolve().parents[3]
    checked_files = [
        backend_root / "app/services/rag/llm_client.py",
        backend_root / "app/services/llm/router.py",
    ]

    for path in checked_files:
        source = path.read_text(encoding="utf-8")
        assert "WAVE1C_PAYLOAD" not in source
        assert "WAVE1C_INSTRUMENT_ENABLED" not in source

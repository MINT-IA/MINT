"""Phase 94 Wave 0 — D-20 byte-identity vs captured snapshots (flag OFF).

Pins that introducing the citation gate primitives (parser, registry,
flag) does NOT alter the production narrator path when
`COACH_CITATION_GATE_ENABLED=False`. Asserts byte-equality with the 5
snapshots captured in Phase 93.5-02 Task 3.

Mirror of `tests/fixtures/narrator_legacy_snapshots/_load.py` capture
procedure ; this test re-runs `build_narrator_system_prompt` and
compares to the on-disk `.txt` baseline.

Wave 0 contract : Phase 94 only ships scaffolding ; coach_chat is NOT
wired yet. The flag exists, defaults False, and even when toggled True
during Wave 0 the production narrator is unaffected because Plan 94-02
owns the wrapper insertion. So byte-identity holds for BOTH flag values
in Wave 0 — but we only assert the OFF case (Wave 0 contract scope).
"""
from __future__ import annotations

import pytest

from app.core.config import Settings, settings
from app.services.coach.claude_coach_service import build_narrator_system_prompt
from tests.fixtures.narrator_legacy_snapshots._load import (
    FIXTURE_DIR,
    FIXTURES,
    load_fixture,
)


@pytest.mark.parametrize("name", FIXTURES)
def test_citation_gate_flag_off_does_not_alter_prompt(name: str):
    """Each captured snapshot is byte-identical to the live prompt build
    when `COACH_CITATION_GATE_ENABLED=False`.
    """
    # Confirm the flag is OFF on the module-level singleton (D-19 default).
    assert settings.COACH_CITATION_GATE_ENABLED is False, (
        "Wave 0 invariant — module-level settings.COACH_CITATION_GATE_ENABLED "
        "MUST default False"
    )

    ctx, language, cash_level = load_fixture(name)
    built = build_narrator_system_prompt(ctx, language, cash_level)
    expected_path = FIXTURE_DIR / f"{name}.txt"
    assert expected_path.exists(), f"missing snapshot file : {expected_path}"
    expected = expected_path.read_text(encoding="utf-8")

    assert built == expected, (
        f"Byte-identity DRIFT on fixture {name!r} — "
        f"built len={len(built)} chars, snapshot len={len(expected)} chars. "
        f"This means Wave 0 scaffolding (parser/registry/flag) altered the "
        f"narrator system prompt path — it MUST be a strict no-op when "
        f"flag is OFF."
    )


def test_byte_identity_holds_under_explicit_flag_off(monkeypatch: pytest.MonkeyPatch):
    """Even with `COACH_CITATION_GATE_ENABLED=false` set explicitly via env,
    the prompt remains byte-identical (defensive check on `Settings()` env
    binding plumbing — proves the flag does not leak side-effects on read).
    """
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "false")
    s = Settings()
    assert s.COACH_CITATION_GATE_ENABLED is False

    name = FIXTURES[0]
    ctx, language, cash_level = load_fixture(name)
    built = build_narrator_system_prompt(ctx, language, cash_level)
    expected = (FIXTURE_DIR / f"{name}.txt").read_text(encoding="utf-8")
    assert built == expected

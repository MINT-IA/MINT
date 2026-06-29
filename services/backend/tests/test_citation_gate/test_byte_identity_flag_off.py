"""D-20 byte-identity vs captured snapshots — the citation-gate ROLLBACK
contract (mint-grounded-coach-m1 Plan 07).

The citation gate was ACTIVATED by default in Plan 07
(`COACH_CITATION_GATE_ENABLED` defaults True). This test pins the
documented kill-switch: when the flag is explicitly set OFF (rollback),
the narrator prompt path is byte-identical to the 5 legacy snapshots
captured in Phase 93.5-02 Task 3 — i.e. activation is fully reversible
with zero residual side-effect on the prompt.

Mirror of `tests/fixtures/narrator_legacy_snapshots/_load.py` capture
procedure ; this test re-runs `build_narrator_system_prompt` (the legacy
narrator builder retained as the byte-identity reference) and compares to
the on-disk `.txt` baseline. The flag is forced OFF via monkeypatch on the
live `settings` singleton so the test exercises the rollback path
regardless of the now-ON default.
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
def test_citation_gate_flag_off_does_not_alter_prompt(
    name: str, monkeypatch: pytest.MonkeyPatch
):
    """Each captured snapshot is byte-identical to the live prompt build
    when `COACH_CITATION_GATE_ENABLED=False` (the rollback override).
    """
    # Force the rollback override OFF in both env and the module-level
    # singleton, then confirm it. Activation (Plan 07) flips the DEFAULT to
    # True, but the OFF path MUST remain byte-identical to the legacy snapshots.
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "false")
    monkeypatch.setattr(settings, "COACH_CITATION_GATE_ENABLED", False)
    assert settings.COACH_CITATION_GATE_ENABLED is False, (
        "rollback invariant — explicit OFF override MUST restore the "
        "byte-identical legacy narrator path"
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
    binding plumbing — proves the rollback override does not leak
    side-effects on read).
    """
    monkeypatch.setenv("COACH_CITATION_GATE_ENABLED", "false")
    s = Settings()
    assert s.COACH_CITATION_GATE_ENABLED is False
    # The builder reads both the env var AND the live `settings` singleton
    # (defensive in-process fallback at claude_coach_service.py). Force both
    # OFF so the rollback path is exercised regardless of the ON default.
    monkeypatch.setattr(settings, "COACH_CITATION_GATE_ENABLED", False)

    name = FIXTURES[0]
    ctx, language, cash_level = load_fixture(name)
    built = build_narrator_system_prompt(ctx, language, cash_level)
    expected = (FIXTURE_DIR / f"{name}.txt").read_text(encoding="utf-8")
    assert built == expected

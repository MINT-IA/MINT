"""Snapshot fixtures for Plan 93.5-02 Task 3 byte-identity regression test.

Each fixture builds a `CoachContext` + `(language, cash_level)` tuple ; the
corresponding `<name>.txt` file holds the byte-exact output of
`build_narrator_system_prompt(ctx, language, cash_level)` captured pre-Wave-1
on the current branch (commit time of Plan 93.5-01 Task 4).

Plan 93.5-02 Task 3 will add `test_flag_off_byte_identical_to_snapshot`
that re-runs `build_narrator_system_prompt` for each of the 5 fixtures
and asserts byte-equality with the captured `.txt`. If the flag-OFF
narrator path drifts even by one whitespace char, the test fails.

Capture procedure (one-shot, run once during Plan 93.5-01 Task 4) :

    cd services/backend
    COACH_CITATION_GATE_ENABLED=false python3 -c "
    from pathlib import Path
    from tests.fixtures.narrator_legacy_snapshots._load import FIXTURES, load_fixture, FIXTURE_DIR
    from app.core.config import settings
    from app.services.coach.claude_coach_service import build_narrator_system_prompt
    settings.COACH_CITATION_GATE_ENABLED = False
    for name in FIXTURES:
        ctx, language, cash_level = load_fixture(name)
        text = build_narrator_system_prompt(ctx, language, cash_level)
        (FIXTURE_DIR / f'{name}.txt').write_text(text, encoding='utf-8')
    "

NB on `CoachContext` : it is a `@dataclass` (not Pydantic). Default values
are baked into the class definition (coach_models.py:46-90) ; only fields
that materially affect the prompt output are passed below — defaults
cover the rest. `language` and `cash_level` are NOT CoachContext fields,
they are separate kwargs of `build_narrator_system_prompt`.
"""
from __future__ import annotations

from pathlib import Path
from typing import Tuple

from app.services.coach.coach_models import CoachContext

FIXTURE_DIR = Path(__file__).parent

FIXTURES = (
    "snapshot_default_ctx_fr_cash3",
    "snapshot_couple_dissymetrique_fr_cash5",
    "snapshot_safe_mode_has_debt_fr_cash2",
    "snapshot_canton_vs_de_cash3",
    "snapshot_minimal_ctx_en_cash1",
)


def load_fixture(name: str) -> Tuple[CoachContext, str, int]:
    """Build the (ctx, language, cash_level) tuple for one fixture name.

    The 5 fixtures cover :
    - default swiss_native VD/45 (baseline, fr, cash 3)
    - couple dissymetrique VD/42 (couple block, fr, cash 5)
    - swiss_native VD/38 has_debt=True (Safe Mode protocol, fr, cash 2)
    - swiss_native VS/50 in DE (canton + language switch)
    - expat_eu ZH/30 in EN (FATCA-adjacent archetype, language switch)
    """
    if name == "snapshot_default_ctx_fr_cash3":
        ctx = CoachContext(
            archetype="swiss_native",
            canton="VD",
            age=45,
            has_debt=False,
        )
        return ctx, "fr", 3
    if name == "snapshot_couple_dissymetrique_fr_cash5":
        ctx = CoachContext(
            archetype="couple_dissymetrique",
            canton="VD",
            age=42,
            has_debt=False,
        )
        return ctx, "fr", 5
    if name == "snapshot_safe_mode_has_debt_fr_cash2":
        ctx = CoachContext(
            archetype="swiss_native",
            canton="VD",
            age=38,
            has_debt=True,
        )
        return ctx, "fr", 2
    if name == "snapshot_canton_vs_de_cash3":
        ctx = CoachContext(
            archetype="swiss_native",
            canton="VS",
            age=50,
            has_debt=False,
        )
        return ctx, "de", 3
    if name == "snapshot_minimal_ctx_en_cash1":
        ctx = CoachContext(
            archetype="expat_eu",
            canton="ZH",
            age=30,
            has_debt=False,
        )
        return ctx, "en", 1
    raise ValueError(f"Unknown fixture: {name!r}")


__all__ = ["FIXTURES", "FIXTURE_DIR", "load_fixture"]

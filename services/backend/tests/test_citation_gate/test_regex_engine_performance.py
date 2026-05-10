"""Phase 94 Wave 0 — D-17 raw regex engine smoke perf (H3 fix iter 1).

This test guards the 5 D-02 patterns against ReDoS / catastrophic
backtracking by running `finditer` over a 4kB worst-case synthetic
narrative (≈ 800 tokens of mixed CHF + % + legal articles + durations)
and asserting `<50ms` per single iteration over 100 iterations.

Documented 16× safety margin to typical narrator output (cf. RESEARCH
§Performance — typical 200-token output is ~3ms ; 4kB is the hostile
ceiling). The end-to-end gate-level performance test (`test_gate_performance.py`)
lands in Plan 94-02 Task 1 step 4 once `gate()` is fattened — Wave 0's
gate body is empty and would not exercise the real code path.
"""
from __future__ import annotations

import time

from app.services.coach.citation_parser import (
    _RE_CURRENCY,
    _RE_DURATION,
    _RE_LEGAL_ARTICLE,
    _RE_PERCENT,
    _RE_REGULATORY,
)


def _build_4kb_input() -> str:
    """Synthesize ≈ 4096 chars of mixed-pattern French narrator output."""
    block = (
        "Le plafond 3a 2026 est de 7'258 CHF (art. 38 LIFD) sur 5 ans, "
        "avec un taux de conversion de 6.0% et un barème LIFD progressif "
        "(coefficient cantonal). LPP art. 19 al. 2 LPP fixe la rente "
        "survivant à 60% pour 30 jours. Il faut investir 80'000 EUR sur "
        "12 mois selon art. 33 LIFD avec 4,5% de marge. "
    )
    # Block ≈ 296 chars ; 14 repeats ~= 4144 chars ≥ 4kB target.
    text = block * 14
    assert len(text) >= 4000, f"buffer too small : {len(text)} chars"
    return text


def test_regex_engine_under_50ms_on_4kb_input():
    """All 5 regex finditer over 4kB FR mixed-pattern input under 50ms p100."""
    text = _build_4kb_input()
    regexes = (
        _RE_CURRENCY,
        _RE_PERCENT,
        _RE_LEGAL_ARTICLE,
        _RE_DURATION,
        _RE_REGULATORY,
    )

    timings: list[float] = []
    for _ in range(100):
        start = time.perf_counter()
        for r in regexes:
            list(r.finditer(text))
        timings.append(time.perf_counter() - start)

    p100 = max(timings)
    p95 = sorted(timings)[int(len(timings) * 0.95)]
    assert p100 < 0.050, (
        f"5-regex finditer p100 = {p100*1000:.2f}ms over 4kB input "
        f"(>50ms budget). p95 = {p95*1000:.2f}ms"
    )

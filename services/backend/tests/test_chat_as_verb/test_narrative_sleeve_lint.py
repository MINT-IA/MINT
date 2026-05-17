"""Phase 96 W3 D-16 — NarrativeSleeve hook digit-free linter tests.

Behavior contract (96-03-PLAN.md §Task 1) :

- Test 1 — clean hook passes through unchanged.
- Test 2 — digit in hook → swap to HOOK_FALLBACK.
- Test 3 — HOOK_FALLBACK is the verbatim D-16 FR string.
- Test 4 — linter NEVER raises (chaos cases : unicode, max-length hook).
- Test 5 — sentry breadcrumb fires on swap with category
  `coach.narrative_sleeve.hook_swap` + non-PII payload (length only).
- Test 6 — ReDoS regression : adversarial 10k-digit hook completes < 100ms.
- Test 7 — signal-alarm timeout : on regex hang, fall back to HOOK_FALLBACK
  without raising (defensive : on timeout, force the swap).
- Test 11 — wiring assertion : `lint_sleeve` is exported under the
  documented module path so `citation_parser` / endpoint can import it.
- Test 12 — None-pass-through is a no-op (the caller guards on
  `narrative_sleeve is not None` before invoking — this test pins the
  documented invariant that lint_sleeve only handles non-None sleeves).
"""
from __future__ import annotations

import time
from unittest.mock import patch

import pytest

from app.schemas.narrative_sleeve import NarrativeSleeve
from app.services.coach.narrative_sleeve_lint import (
    HOOK_FALLBACK,
    lint_sleeve,
)


# Test 1 — clean hook (no digits) passes through unchanged.
def test_clean_hook_unchanged() -> None:
    sleeve = NarrativeSleeve(
        hook="Voyons ce que ça change pour toi.",
        caption="Caption with cited numbers.",
        next_step="Ouvre le simulateur.",
        metaphor="",
    )
    result = lint_sleeve(sleeve)
    # Per spec : same instance returned on clean input.
    assert result is sleeve
    assert result.hook == "Voyons ce que ça change pour toi."


# Test 2 — digit in hook triggers swap to fallback.
def test_digit_hook_swaps_to_fallback() -> None:
    sleeve = NarrativeSleeve(
        hook="You earn 1500 CHF every month",
        caption="ok",
        next_step="ok",
    )
    result = lint_sleeve(sleeve)
    assert result.hook == HOOK_FALLBACK
    # Frozen ; lint_sleeve must produce a NEW instance via model_copy.
    assert result is not sleeve
    # caption / next_step / metaphor are preserved verbatim.
    assert result.caption == "ok"
    assert result.next_step == "ok"
    assert result.metaphor == ""


# Test 3 — HOOK_FALLBACK is the verbatim D-16 FR string.
def test_hook_fallback_verbatim_d16() -> None:
    assert HOOK_FALLBACK == "Voyons ensemble ce que ça change pour toi."
    # accent_lint guard : « ça » carries the cedilla.
    assert "ça" in HOOK_FALLBACK
    # LSFin guard : zero banned terms.
    lowered = HOOK_FALLBACK.lower()
    for banned in ("garanti", "optimal", "parfait", "meilleur", "sans risque"):
        assert banned not in lowered


# Test 4 — chaos cases : unicode edge cases + max-length hook never raise.
@pytest.mark.parametrize(
    "hook",
    [
        "é" * 200,                       # max-length unicode (200 chars)
        "Voyons « ça » — éclat",         # mixed punctuation + diacritics
        "🚀 emoji prelude",               # emoji-only prelude (no digit)
        "Voyons.\nDeux lignes.",         # newline-bearing hook
    ],
)
def test_lint_never_raises_on_chaos_inputs(hook: str) -> None:
    sleeve = NarrativeSleeve(hook=hook, caption="ok", next_step="ok")
    # The call MUST complete without raising — that's the contract.
    result = lint_sleeve(sleeve)
    # No digits in any of these → result must equal input (same instance).
    assert result is sleeve


# Test 5 — Sentry breadcrumb fires on swap with non-PII payload.
def test_sentry_breadcrumb_on_swap_non_pii() -> None:
    sleeve = NarrativeSleeve(
        hook="2026 marks a shift",
        caption="ok",
        next_step="ok",
    )
    with patch(
        "app.services.coach.narrative_sleeve_lint.sentry_sdk.add_breadcrumb"
    ) as mock_bc:
        result = lint_sleeve(sleeve)
        assert result.hook == HOOK_FALLBACK
        assert mock_bc.called
        kwargs = mock_bc.call_args.kwargs
        assert kwargs["category"] == "coach.narrative_sleeve.hook_swap"
        # PII guard : payload contains the LENGTH only, never the hook text.
        data = kwargs["data"]
        assert "original_hook_length" in data
        assert data["original_hook_length"] == len("2026 marks a shift")
        # The original text MUST NOT leak into any breadcrumb field.
        for v in data.values():
            assert "2026 marks a shift" != v


# Test 6 — ReDoS regression : 10k-digit hook completes well under 100ms.
def test_redos_regression_adversarial_input() -> None:
    # 10 000 digit chars is a stress workload for catastrophic backtracking
    # regexes ; the simple character class `\d` runs in O(n) so completes
    # under 10 ms even on a cold path. Allow 100 ms budget for CI noise.
    # NarrativeSleeve enforces max_length=200, so we build right at the cap.
    hook = "9" * 200
    sleeve = NarrativeSleeve(hook=hook, caption="ok", next_step="ok")
    start = time.perf_counter()
    result = lint_sleeve(sleeve)
    elapsed_ms = (time.perf_counter() - start) * 1000
    assert result.hook == HOOK_FALLBACK
    assert elapsed_ms < 100, f"ReDoS regression : took {elapsed_ms:.2f}ms"


# Test 7 — signal-alarm timeout : when the regex search itself hangs,
# the defensive `_LintTimeout` path forces a fallback.
def test_signal_timeout_falls_back_to_hook_fallback() -> None:
    from app.services.coach import narrative_sleeve_lint as lint_mod

    sleeve = NarrativeSleeve(
        hook="No digits in this hook at all",
        caption="ok",
        next_step="ok",
    )
    # Monkeypatch the digit-detection helper to simulate a regex hang :
    # raise the module-internal _LintTimeout exception. lint_sleeve MUST
    # catch any exception from the helper and force a fallback swap.
    def fake_has_digit(_hook: str, **_kw: object) -> bool:
        raise lint_mod._LintTimeout()  # type: ignore[attr-defined]

    with patch.object(lint_mod, "_has_digit_with_timeout", fake_has_digit):
        result = lint_sleeve(sleeve)
    assert result.hook == HOOK_FALLBACK


# Test 11 — wiring assertion : the public module path is stable
# (citation_parser.py + endpoint import this exact path).
def test_public_module_path_stable() -> None:
    import importlib

    mod = importlib.import_module(
        "app.services.coach.narrative_sleeve_lint"
    )
    assert hasattr(mod, "lint_sleeve")
    assert hasattr(mod, "HOOK_FALLBACK")
    assert callable(mod.lint_sleeve)
    assert isinstance(mod.HOOK_FALLBACK, str)


# Test 12 — None-pass-through is a caller contract.
# This pins the documented invariant : callers MUST guard on
# `sleeve is not None` before invoking lint_sleeve. The linter itself
# accepts only NarrativeSleeve instances ; passing None should raise
# AttributeError (defensive — calling code wouldn't hit this path).
def test_none_input_is_caller_contract_violation() -> None:
    with pytest.raises(AttributeError):
        lint_sleeve(None)  # type: ignore[arg-type]


# Test 11 (middleware wiring) — citation_parser.lint_response_sleeve is the
# documented call site. It is None-safe (returns None passthrough) and
# delegates to narrative_sleeve_lint.lint_sleeve when the sleeve is set.
# This pins the D-16 ordering contract : the helper lives next to
# `_substitute_placeholders` so the response build path is « citation
# gate first, sleeve linter second ».
def test_lint_response_sleeve_wires_through_citation_parser() -> None:
    from app.services.coach.citation_parser import lint_response_sleeve

    # None passthrough — endpoint legacy path with no narrative_sleeve.
    assert lint_response_sleeve(None) is None

    # Digit-bearing sleeve → fallback swap (delegates to lint_sleeve).
    sleeve = NarrativeSleeve(
        hook="3 angles changent ta marge",
        caption="ok",
        next_step="ok",
    )
    result = lint_response_sleeve(sleeve)
    assert result is not None
    assert result.hook == HOOK_FALLBACK
    assert result.caption == "ok"

    # Clean sleeve → same instance preserved (the helper is a pure
    # delegate, no defensive copy).
    clean = NarrativeSleeve(
        hook="Voyons ce que ça change",
        caption="ok",
        next_step="ok",
    )
    assert lint_response_sleeve(clean) is clean

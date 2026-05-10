"""Phase 91 Stage 3 narrator eval harness (D-01 + D-06).

Runs an N-fixture eval pack against a chosen Anthropic narrator model
and emits a JSON record per fixture + a summary line.

Mechanical scoring only (no LLM-as-judge per CLAUDE.md §9 « ground truth
must be deterministic »). Five automated criteria per response:

  (a) ComplianceGuard.validate(response).is_compliant
  (b) doctrine_checks.score_response(response).score >=
      fixture.expected_constraints.must_pass_doctrine_score_pct
  (c) banned-terms scan: response contains NONE of
      fixture.expected_constraints.must_avoid_banned_terms (case-insensitive,
      word-boundary).
  (d) anti-extractor leak: response contains NONE of
      fixture.expected_constraints.must_not_contain_substrings.
  (e) calculator_grounded: when fixture.must_contain_at_least_one_of is
      non-empty, response contains AT LEAST ONE of the substrings.

Aggregates per-category and overall pass rates. With --compare-to,
computes ratio against another model's output and emits STAGE_3_EVAL
PASS|FAIL line per D-01 ≥95% threshold.

Usage (run from `services/backend/`):

    python -m tools.eval_narrator --model haiku \
        --fixtures tests/fixtures/narrator_eval_50.jsonl \
        --out reports/eval_haiku.json
    python -m tools.eval_narrator --model sonnet \
        --fixtures tests/fixtures/narrator_eval_50.jsonl \
        --out reports/eval_sonnet.json
    python -m tools.eval_narrator --compare reports/eval_haiku.json \
        --baseline reports/eval_sonnet.json --threshold 0.95

The harness output (JSON --out files + stdout summary line) IS the
deterministic citation for the Stage 3 decision per CLAUDE.md §9.6.

Refs: D-01 (Haiku-first with Stage 3 gate), D-06 (50-fixture
single-variable test), ADR-20260419-v2.8-kill-policy.md (Stage 3 fail
=> keep Sonnet narrator, +54% per turn ceiling).
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import logging
import os
import re
import sys
import time
from collections import defaultdict
from pathlib import Path
from typing import Any, Optional

# ---------------------------------------------------------------------------
# Module-level logger configured in main() for deterministic stdout/stderr.
# ---------------------------------------------------------------------------
logger = logging.getLogger("tools.eval_narrator")


# ---------------------------------------------------------------------------
# Narrator model id resolver — single source of truth.
# Mirrors `_NARRATOR_MODEL_MAP` wired in `coach_chat.py` (Task 4.3).
# ---------------------------------------------------------------------------
_NARRATOR_MODEL_IDS: dict[str, str] = {
    "haiku": "claude-haiku-4-5-20251001",
    "sonnet": "claude-sonnet-4-5-20250929",
}


# ---------------------------------------------------------------------------
# Phase 93.5 Plan 04 — `count_tokens` cache (RESEARCH §Pitfall 8).
#
# Anthropic's `messages.count_tokens` API is rate-limited and adds latency
# to every fixture run. The eval pack runs deterministically (same fixtures,
# same prompt builder, same model) so token counts can be cached
# sha256(model::prompt) → input_tokens. Cache is committed to git (initial
# `{}`) so repeated CI runs accumulate hits.
#
# Fallback path: when the SDK call raises, return a 4-char-per-token
# heuristic. This keeps the eval running on offline / rate-limited boxes
# without polluting the cache with bogus numbers.
# ---------------------------------------------------------------------------
_TOKEN_CACHE_PATH: Path = (
    Path(__file__).parent.parent / "tests" / "fixtures" / ".token_count_cache.json"
)


def _load_token_cache() -> dict[str, int]:
    if _TOKEN_CACHE_PATH.exists():
        try:
            return json.loads(_TOKEN_CACHE_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            logger.warning("token cache corrupted at %s — resetting", _TOKEN_CACHE_PATH)
            return {}
    return {}


def _save_token_cache(cache: dict[str, int]) -> None:
    _TOKEN_CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    _TOKEN_CACHE_PATH.write_text(
        json.dumps(cache, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def count_tokens_cached(*, prompt: str, model: str, anthropic_client: Any) -> int:
    """Return input_tokens for `prompt` via cache → SDK → 4-char heuristic.

    The cache key includes the model id so a model swap doesn't reuse
    stale counts.
    """
    key = hashlib.sha256(f"{model}::{prompt}".encode("utf-8")).hexdigest()
    cache = _load_token_cache()
    if key in cache:
        return int(cache[key])
    try:
        result = anthropic_client.messages.count_tokens(
            model=model,
            system=prompt,
            messages=[{"role": "user", "content": "."}],
        )
        n = int(result.input_tokens)
        cache[key] = n
        _save_token_cache(cache)
        return n
    except Exception as exc:  # noqa: BLE001 — fallback is the contract
        logger.warning(
            "count_tokens API failed (%s) — falling back to 4-char heuristic",
            type(exc).__name__,
        )
        return len(prompt) // 4


# ---------------------------------------------------------------------------
# Phase 93.5 Plan 04 — `--prompt-builder` dispatch helper.
#
# Encapsulates the legacy-vs-bundle branch in ONE place so the smoke test
# can exercise the dispatch without spinning up the full Mode A flow.
# C3 contract — bundle path uses kwargs-only call. D-14 — fixtures
# without `intents` field default to `set()` (always-on only).
# ---------------------------------------------------------------------------


def _build_system_prompt_for_fixture(
    *, fixture: dict[str, Any], prompt_builder: str
) -> tuple[str, str]:
    """Compose the narrator system prompt for a single fixture.

    Returns `(system_prompt, builder_label)` where `builder_label` is
    one of {"bundle", "legacy"} for output-JSON traceability.
    """
    language = fixture.get("language", "fr")
    cash_level = int(fixture.get("cash_level", 3))

    if prompt_builder == "bundle":
        # Local import: keeps the legacy path import-light when the flag
        # is OFF, and dodges any future circular-import risk via
        # `app.services.coach.bundles`.
        from app.services.coach.claude_coach_service import (
            build_narrator_system_prompt_from_bundles,
        )

        intents = set(fixture.get("intents") or [])
        # C3 — kwargs-only call. Param is `ctx`, NOT `coach_ctx`.
        # No memory-block kwargs (eval fixtures don't carry them).
        system_prompt = build_narrator_system_prompt_from_bundles(
            intents=intents,
            ctx=None,
            language=language,
            cash_level=cash_level,
        )
        return system_prompt, "bundle"

    # Default / explicit "legacy" — Phase 91 Wave 2 narrator prompt.
    from app.services.coach.claude_coach_service import (
        build_narrator_system_prompt,
    )

    system_prompt = build_narrator_system_prompt(
        ctx=None,
        language=language,
        cash_level=cash_level,
    )
    return system_prompt, "legacy"


# ---------------------------------------------------------------------------
# Fixture loading
# ---------------------------------------------------------------------------


def _load_fixtures(path: Path) -> list[dict[str, Any]]:
    """Load a .jsonl fixture pack. One object per non-empty line."""
    if not path.exists():
        raise FileNotFoundError(f"fixtures file not found: {path}")
    out: list[dict[str, Any]] = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError as exc:
            raise ValueError(
                f"fixture parse error at {path}:{lineno}: {exc}"
            ) from exc
    return out


# ---------------------------------------------------------------------------
# Mechanical scoring
# ---------------------------------------------------------------------------


def _word_boundary_pattern(term: str) -> re.Pattern[str]:
    """Compile a case-insensitive word-boundary pattern matching `term`.

    Multi-word terms (e.g. « sans risque ») use plain re.escape with no word
    boundary because spaces already act as separators.
    """
    if " " in term:
        return re.compile(re.escape(term), re.IGNORECASE)
    fr_letter = r"a-zA-ZÀ-ÿ"
    return re.compile(
        rf"(?<![{fr_letter}]){re.escape(term)}(?![{fr_letter}])",
        re.IGNORECASE,
    )


# Wave 4 (Phase 93.5 H8 follow-up) — meta-quote / negation context aware scorer.
# Phase 94 Plan 94-01 Task 2 refactor (D-03) :
#   The legacy meta-helpers (`_is_meta_quoted` + `_is_meta_negation` + the
#   `_NEGATION_RE` lexicon, originally defined here at lines 243-296) have
#   moved to `app/services/coach/citation_parser.py` as PUBLIC API
#   (`is_meta_quoted` / `is_meta_negation` — no leading underscore) so they
#   can be consumed by both runtime gate and eval-time scorer.
#   The eval-local underscore aliases below preserve backward compat —
#   `_score_banned_terms` (further down) keeps calling `_is_meta_quoted` /
#   `_is_meta_negation` unchanged.
# Single source of truth — D-03.
from app.services.coach.citation_parser import (  # noqa: E402
    is_meta_negation as _is_meta_negation,
    is_meta_quoted as _is_meta_quoted,
)


def _score_banned_terms(
    response: str, banned: list[str]
) -> tuple[bool, list[str], list[dict]]:
    """Return (passed, [terms_found], [excused_meta_uses]).

    Pass when zero NON-META matches. Meta usage (negation refuting the term,
    or quoted meta-quote of the term) is recorded under `excused_meta_uses`
    for traceability but does NOT count as a failure.
    """
    found: list[str] = []
    excused: list[dict] = []
    for term in banned:
        if not term:
            continue
        term_failed = False
        for m in _word_boundary_pattern(term).finditer(response):
            if _is_meta_quoted(response, m.start(), m.end()) or _is_meta_negation(
                response, m.start(), m.end()
            ):
                excused.append(
                    {
                        "term": term,
                        "position": m.start(),
                        "context": response[
                            max(0, m.start() - 40) : m.end() + 40
                        ].replace("\n", " "),
                    }
                )
            else:
                term_failed = True
                break  # one non-meta match per term is enough to fail
        if term_failed:
            found.append(term)
    return (not found, found, excused)


def _score_anti_extractor_leak(
    response: str, forbidden: list[str]
) -> tuple[bool, list[str]]:
    """Pass if response (case-insensitive) contains NONE of `forbidden`."""
    lower = response.lower()
    leaked: list[str] = []
    for sub in forbidden:
        if not sub:
            continue
        if sub.lower() in lower:
            leaked.append(sub)
    return (not leaked, leaked)


def _score_calculator_grounded(
    response: str, must_contain_any: list[str]
) -> tuple[bool, Optional[str]]:
    """When the list is empty, returns (True, None). Otherwise (True, hit) on first match."""
    if not must_contain_any:
        return (True, None)
    lower = response.lower()
    for sub in must_contain_any:
        if not sub:
            continue
        if sub.lower() in lower:
            return (True, sub)
    return (False, None)


def _score_compliance(response: str) -> bool:
    """Use the production ComplianceGuard L1-L5 stack."""
    from app.services.coach.compliance_guard import ComplianceGuard, ComponentType

    guard = ComplianceGuard()
    result = guard.validate(
        response, context=None, component_type=ComponentType.general
    )
    return bool(result.is_compliant)


def _score_doctrine(response: str, threshold_pct: float) -> tuple[bool, float]:
    """Run doctrine_checks.score_response; pass if score >= threshold_pct."""
    from app.services.coach.doctrine_checks import score_response

    report = score_response(response)
    return (report.score >= threshold_pct, float(report.score))


# ---------------------------------------------------------------------------
# LLM call (Mode A real run) — defers import so --compare runs even when
# the optional anthropic package is not installed in the local venv.
# ---------------------------------------------------------------------------


async def _generate_narrator_response(
    *,
    model_id: str,
    api_key: str,
    fixture: dict[str, Any],
    prompt_builder: str = "legacy",
) -> tuple[str, int, int, float, str]:
    """Call the narrator LLM for a single fixture.

    Returns (response_text, input_tokens, output_tokens, latency_ms,
    builder_label). Token counts are best-effort from the Anthropic SDK;
    if unavailable, returns 0. The trailing `builder_label` (one of
    "bundle" / "legacy") is returned for output-JSON traceability.

    Phase 93.5 Plan 04 (BUNDLE-04) — when `prompt_builder == "bundle"`,
    the system prompt is composed via the skill-bundle compiler
    (kwargs-only `build_narrator_system_prompt_from_bundles`, C3 fix);
    otherwise the legacy `build_narrator_system_prompt` path is used
    (byte-identical to Phase 91 Wave 2 behavior, regression-anchored
    by `tests/test_coach_chat_bundles.py::test_flag_off_byte_identical_to_snapshot`).
    """
    from app.services.rag.llm_client import LLMClient

    system_prompt, builder_label = _build_system_prompt_for_fixture(
        fixture=fixture, prompt_builder=prompt_builder
    )
    user_message = fixture["user_message"]
    history = fixture.get("conversation_history", []) or []

    client = LLMClient(provider="claude", api_key=api_key, model=model_id)
    started = time.perf_counter()
    raw = await client.generate(
        system_prompt=system_prompt,
        user_message=user_message,
        context_chunks=[],
        conversation_history=history if history else None,
    )
    latency_ms = (time.perf_counter() - started) * 1000.0

    if isinstance(raw, dict):
        text = raw.get("text", "")
    else:
        text = str(raw or "")

    # Token counts are not surfaced by LLMClient.generate today (CoachUpstream
    # path); harness records 0 and the operator runs the eval against the
    # Anthropic console for billing-grade accounting if needed. Phase 93.5
    # Plan 04 adds an out-of-band prompt-token estimate via
    # `count_tokens_cached` at the call site (with sha256 cache + 4-char
    # heuristic fallback per RESEARCH §Pitfall 8).
    return text, 0, 0, latency_ms, builder_label


# ---------------------------------------------------------------------------
# Per-fixture eval
# ---------------------------------------------------------------------------


def _score_fixture(
    *, fixture: dict[str, Any], response_text: str, model_label: str,
    latency_ms: float, input_tokens: int, output_tokens: int,
    prompt_builder: str = "legacy", prompt_tokens: int = 0,
) -> dict[str, Any]:
    """Apply criteria (a)-(e) and return the per-fixture record.

    `prompt_builder` is one of {"bundle", "legacy"} (Phase 93.5 BUNDLE-04
    traceability). `prompt_tokens` is the system-prompt token count
    (out-of-band, via `count_tokens_cached`) — used in Plan 04
    EVAL-RESULTS to compute the bundle-vs-legacy cost regression.
    """
    expected = fixture.get("expected_constraints", {}) or {}
    threshold_pct = float(expected.get("must_pass_doctrine_score_pct", 80))
    banned = list(expected.get("must_avoid_banned_terms") or [])
    forbidden = list(expected.get("must_not_contain_substrings") or [])
    grounded = list(expected.get("must_contain_at_least_one_of") or [])

    compliance_pass = _score_compliance(response_text)
    doctrine_pass, doctrine_score = _score_doctrine(response_text, threshold_pct)
    banned_pass, banned_found, banned_excused = _score_banned_terms(
        response_text, banned
    )
    leak_pass, leaked = _score_anti_extractor_leak(response_text, forbidden)
    grounded_pass, grounded_hit = _score_calculator_grounded(response_text, grounded)

    all_three_pass = (
        compliance_pass
        and doctrine_pass
        and banned_pass
        and leak_pass
        and grounded_pass
    )

    excerpt = response_text.strip().replace("\n", " ")
    if len(excerpt) > 240:
        excerpt = excerpt[:237] + "..."

    return {
        "fixture_id": fixture.get("id"),
        "category": fixture.get("category"),
        "model": model_label,
        "prompt_builder": prompt_builder,
        "response_excerpt": excerpt,
        "compliance_pass": compliance_pass,
        "doctrine_score": doctrine_score,
        "doctrine_pass": doctrine_pass,
        "banned_terms_pass": banned_pass,
        "banned_terms_found": banned_found,
        "banned_terms_excused_meta": banned_excused,
        "anti_extractor_leak_pass": leak_pass,
        "anti_extractor_leak_found": leaked,
        "calculator_grounded_pass": grounded_pass,
        "calculator_grounded_hit": grounded_hit,
        "all_three_pass": all_three_pass,
        "latency_ms": round(latency_ms, 2),
        "input_tokens": int(input_tokens or 0),
        "output_tokens": int(output_tokens or 0),
        "prompt_tokens": int(prompt_tokens or 0),
    }


def _aggregate(records: list[dict[str, Any]]) -> dict[str, Any]:
    """Compute summary counters + per-category pass-rate."""
    total = len(records)

    def _count(key: str) -> int:
        return sum(1 for r in records if r.get(key))

    by_cat: dict[str, dict[str, int]] = defaultdict(lambda: {"all_three_pass": 0, "total": 0})
    for r in records:
        cat = r.get("category") or "unknown"
        by_cat[cat]["total"] += 1
        if r.get("all_three_pass"):
            by_cat[cat]["all_three_pass"] += 1

    return {
        "total": total,
        "compliance_pass": _count("compliance_pass"),
        "doctrine_pass": _count("doctrine_pass"),
        "banned_terms_pass": _count("banned_terms_pass"),
        "anti_extractor_leak_pass": _count("anti_extractor_leak_pass"),
        "calculator_grounded_pass": _count("calculator_grounded_pass"),
        "all_three_pass": _count("all_three_pass"),
        "by_category": dict(by_cat),
    }


# ---------------------------------------------------------------------------
# Mode A — eval-run
# ---------------------------------------------------------------------------


async def _run_eval(args: argparse.Namespace) -> int:
    fixtures_path = Path(args.fixtures)
    out_path = Path(args.out)
    fixtures = _load_fixtures(fixtures_path)
    # Phase 93.5 Plan 04 — `--limit N` allows smoke-testing the harness on
    # a small slice of the 50-fixture pack without rewriting the .jsonl.
    limit = getattr(args, "limit", None)
    if limit is not None and limit > 0:
        fixtures = fixtures[:limit]
    prompt_builder = getattr(args, "prompt_builder", "legacy")
    gate_mode = getattr(args, "gate", "off")
    logger.info(
        "loaded %d fixtures from %s (model=%s, dry_run=%s, prompt_builder=%s, gate=%s)",
        len(fixtures), fixtures_path, args.model, args.dry_run, prompt_builder, gate_mode,
    )
    model_id = _NARRATOR_MODEL_IDS[args.model]

    # Phase 94.1 Wave 4 instrumentation — when --gate=on, propagate
    # COACH_CITATION_GATE_ENABLED=True for the duration of the run so the
    # legacy-path narrator system prompt picks up the citation-grammar
    # fragment (`build_narrator_system_prompt` reads the env var per
    # `claude_coach_service.py` :976) AND the bundle-path compiler picks
    # up the CitationGrammarBundle (`bundle_compiler.compile_bundles`
    # reads `settings.COACH_CITATION_GATE_ENABLED`). This makes Stage 3
    # eval measure the FATTENED prompt instead of the unchanged Phase 94
    # baseline. The original env value is restored at function exit.
    _gate_env_original = os.environ.get("COACH_CITATION_GATE_ENABLED")
    _gate_settings_original: Optional[bool] = None
    if gate_mode == "on":
        os.environ["COACH_CITATION_GATE_ENABLED"] = "true"
        try:
            from app.core.config import settings as _live_settings
            _gate_settings_original = bool(
                getattr(_live_settings, "COACH_CITATION_GATE_ENABLED", False)
            )
            _live_settings.COACH_CITATION_GATE_ENABLED = True  # type: ignore[attr-defined]
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "failed to flip live settings.COACH_CITATION_GATE_ENABLED (%s) — "
                "env-var path still propagates, bundle-path may not pick up the fragment",
                type(exc).__name__,
            )
        logger.info(
            "94.1 — propagated COACH_CITATION_GATE_ENABLED=true (env + settings) for the run"
        )

    api_key = ""
    if not args.dry_run:
        api_key = os.environ.get("ANTHROPIC_API_KEY", "")
        if not api_key:
            logger.error(
                "ANTHROPIC_API_KEY env var is empty; either set it or pass --dry-run"
            )
            return 1

    # Out-of-band Anthropic client used purely for `count_tokens` cost
    # measurement (Plan 04 — bundle vs legacy cost-regression metric).
    # Best-effort : when the SDK / network is unavailable, the cache
    # helper falls back to a 4-char heuristic.
    anthropic_client = None
    if not args.dry_run:
        try:  # pragma: no cover — network-dependent branch
            import anthropic  # noqa: WPS433 — local import is intentional

            anthropic_client = anthropic.Anthropic(api_key=api_key)
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "anthropic SDK unavailable (%s) — prompt_tokens will use heuristic",
                type(exc).__name__,
            )

    records: list[dict[str, Any]] = []
    for idx, fixture in enumerate(fixtures, 1):
        # Compose the system prompt up-front so we can record its token
        # count regardless of the dry-run / live path.
        system_prompt, builder_label = _build_system_prompt_for_fixture(
            fixture=fixture, prompt_builder=prompt_builder
        )
        prompt_tokens = (
            count_tokens_cached(
                prompt=system_prompt,
                model=model_id,
                anthropic_client=anthropic_client,
            )
            if anthropic_client is not None
            else len(system_prompt) // 4
        )

        if args.dry_run:
            # Deterministic placeholder. Reverses the user message so the
            # scoring path runs end-to-end without a network call. Latency
            # 0, tokens 0 (no real call). Lets us self-test the harness.
            response_text = (fixture.get("user_message") or "")[::-1]
            latency_ms = 0.0
            in_tok = 0
            out_tok = 0
        else:
            try:
                response_text, in_tok, out_tok, latency_ms, _builder = (
                    await _generate_narrator_response(
                        model_id=model_id,
                        api_key=api_key,
                        fixture=fixture,
                        prompt_builder=prompt_builder,
                    )
                )
            except Exception as exc:  # noqa: BLE001 — eval harness is non-fatal
                logger.error(
                    "fixture %s LLM call failed (%s) — recorded as empty response",
                    fixture.get("id"), type(exc).__name__,
                )
                response_text = ""
                latency_ms = 0.0
                in_tok = 0
                out_tok = 0

        # ------------------------------------------------------------------
        # Phase 94 (GATE-04) — citation gate Stage-3 instrumentation.
        # When --gate=on, run citation_parser.gate() on the narrator output
        # and record the verdict. On retry_needed=True, call the narrator
        # a SECOND time with the reprompt addendum appended to the user
        # message (D-08 retry-once budget) and re-gate with is_retry=True
        # (collapses any rejection to FALLBACK, D-10 templated fallback).
        # When --gate=off, gate_verdict is recorded as "bypass" — legacy
        # behavior (byte-identical to today's eval).
        # ------------------------------------------------------------------
        gate_verdict_str: str = "bypass"
        gate_retries: int = 0
        gate_uncited_count: int = 0
        gate_banned_claims_count: int = 0
        tokens_total_with_retries: int = int(in_tok or 0)
        latency_total_with_retries: float = float(latency_ms or 0.0)
        if gate_mode == "on":
            try:
                from app.services.coach.citation_parser import gate as _citation_gate
            except Exception as exc:  # noqa: BLE001
                logger.error(
                    "fixture %s — citation_parser import failed (%s) ; "
                    "recording gate_verdict='import_error'",
                    fixture.get("id"), type(exc).__name__,
                )
                _citation_gate = None  # type: ignore

            if _citation_gate is not None and response_text:
                try:
                    gated = _citation_gate(
                        response_text=response_text,
                        ctx=None,
                        citation_allowlist=None,  # eval uses global registry fallback
                        is_retry=False,
                    )
                    gate_verdict_str = gated.verdict.value
                    gate_uncited_count = int(gated.uncited_numbers_count or 0)
                    gate_banned_claims_count = len(gated.banned_claims_found or ())

                    if gated.retry_needed and not args.dry_run:
                        # D-08 — retry once with reprompt addendum appended.
                        retry_fixture = dict(fixture)
                        retry_fixture["user_message"] = (
                            (fixture.get("user_message") or "")
                            + (gated.reprompt_addendum or "")
                        )
                        try:
                            (
                                retry_response, retry_in_tok,
                                retry_out_tok, retry_latency_ms, _b,
                            ) = await _generate_narrator_response(
                                model_id=model_id,
                                api_key=api_key,
                                fixture=retry_fixture,
                                prompt_builder=prompt_builder,
                            )
                            gate_retries = 1
                            tokens_total_with_retries += int(retry_in_tok or 0)
                            latency_total_with_retries += float(retry_latency_ms or 0.0)
                        except Exception as exc:  # noqa: BLE001
                            logger.error(
                                "fixture %s retry call failed (%s) — using empty",
                                fixture.get("id"), type(exc).__name__,
                            )
                            retry_response = ""

                        retry_gated = _citation_gate(
                            response_text=retry_response,
                            ctx=None,
                            citation_allowlist=None,
                            is_retry=True,
                        )
                        gate_verdict_str = retry_gated.verdict.value
                        gate_uncited_count = int(
                            retry_gated.uncited_numbers_count or 0
                        )
                        gate_banned_claims_count = len(
                            retry_gated.banned_claims_found or ()
                        )
                        # The gated_text is the surface a user would see —
                        # adopt it as the scoring substrate for retries.
                        response_text = retry_gated.gated_text
                    elif not gated.retry_needed:
                        # PASS / FALLBACK on first try — adopt gated_text
                        # as the surface a user would actually see.
                        response_text = gated.gated_text
                except Exception as exc:  # noqa: BLE001
                    logger.error(
                        "fixture %s gate() raised (%s) — recording gate_verdict='gate_error'",
                        fixture.get("id"), type(exc).__name__,
                    )
                    gate_verdict_str = "gate_error"

        expected_outcome = fixture.get("expected_gate_outcome")
        gate_correct: Optional[bool] = (
            (gate_verdict_str == expected_outcome)
            if (expected_outcome is not None and gate_mode == "on")
            else None
        )

        record = _score_fixture(
            fixture=fixture,
            response_text=response_text,
            model_label=args.model,
            latency_ms=latency_ms,
            input_tokens=in_tok,
            output_tokens=out_tok,
            prompt_builder=builder_label,
            prompt_tokens=prompt_tokens,
        )
        # Phase 94 — gate outcome fields, recorded in every record so the
        # JSON output is the deterministic citation for EVAL-RESULTS.
        record["gate_mode"] = gate_mode
        record["gate_verdict"] = gate_verdict_str
        record["expected_gate_outcome"] = expected_outcome
        record["gate_correct"] = gate_correct
        record["gate_retries"] = gate_retries
        record["gate_uncited_numbers_count"] = gate_uncited_count
        record["gate_banned_claims_count"] = gate_banned_claims_count
        record["tokens_total_with_retries"] = tokens_total_with_retries
        record["latency_total_with_retries_ms"] = round(
            latency_total_with_retries, 2
        )
        records.append(record)
        if idx % 10 == 0 or idx == len(fixtures):
            logger.info("scored %d/%d fixtures", idx, len(fixtures))

    aggregate = _aggregate(records)
    # Per Plan 04 — surface average prompt_tokens at aggregate level so the
    # operator can read cost regression directly off the JSON without
    # re-walking records.
    # Phase 94 Plan 03 — additionally surface gate-correct rate when --gate=on
    # so EVAL-RESULTS can read the Stage-3 thresholds directly off the JSON.
    if records:
        # Gate-correct aggregates (Phase 94, GATE-04 Stage 3 thresholds).
        gate_records = [r for r in records if r.get("gate_mode") == "on"]
        gate_correct_records = [r for r in gate_records if r.get("gate_correct") is True]
        retry_records = [r for r in gate_records if int(r.get("gate_retries") or 0) >= 1]
        fallback_records = [r for r in gate_records if r.get("gate_verdict") == "fallback"]
        aggregate["gate_mode"] = gate_mode
        aggregate["gate_count_runs"] = len(gate_records)
        aggregate["gate_correct"] = len(gate_correct_records)
        aggregate["gate_retry_rate"] = (
            round(len(retry_records) / len(gate_records), 4)
            if gate_records else 0.0
        )
        aggregate["gate_fallback_rate"] = (
            round(len(fallback_records) / len(gate_records), 4)
            if gate_records else 0.0
        )
        aggregate["avg_tokens_total_with_retries"] = round(
            sum(int(r.get("tokens_total_with_retries") or 0) for r in records)
            / len(records),
            2,
        )
        aggregate["avg_latency_total_with_retries_ms"] = round(
            sum(
                float(r.get("latency_total_with_retries_ms") or 0.0) for r in records
            )
            / len(records),
            2,
        )
        aggregate["avg_prompt_tokens"] = round(
            sum(int(r.get("prompt_tokens") or 0) for r in records) / len(records), 2
        )
        aggregate["avg_latency_ms"] = round(
            sum(float(r.get("latency_ms") or 0.0) for r in records) / len(records), 2
        )
    payload = {
        "model": args.model,
        "model_id": model_id,
        "prompt_builder": prompt_builder,
        "fixtures_count": len(fixtures),
        "fixtures_path": str(fixtures_path),
        "dry_run": bool(args.dry_run),
        "records": records,
        "aggregate": aggregate,
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    logger.info("wrote eval report to %s", out_path)

    summary = (
        f"MODEL_EVAL: model={args.model} prompt_builder={prompt_builder} "
        f"gate={gate_mode} "
        f"all_three_pass={aggregate['all_three_pass']}/{aggregate['total']}"
    )
    if gate_mode == "on":
        summary += (
            f" gate_correct={aggregate.get('gate_correct', 0)}/"
            f"{aggregate.get('gate_count_runs', 0)}"
            f" fallback_rate={aggregate.get('gate_fallback_rate', 0.0):.4f}"
            f" retry_rate={aggregate.get('gate_retry_rate', 0.0):.4f}"
        )
    print(summary)

    # Phase 94.1 Wave 4 — restore COACH_CITATION_GATE_ENABLED to its
    # original value (env var + live settings) so the eval harness is
    # reentrant and does not bleed state into a subsequent in-process call.
    if gate_mode == "on":
        if _gate_env_original is None:
            os.environ.pop("COACH_CITATION_GATE_ENABLED", None)
        else:
            os.environ["COACH_CITATION_GATE_ENABLED"] = _gate_env_original
        if _gate_settings_original is not None:
            try:
                from app.core.config import settings as _live_settings
                _live_settings.COACH_CITATION_GATE_ENABLED = (  # type: ignore[attr-defined]
                    _gate_settings_original
                )
            except Exception:  # noqa: BLE001 — best-effort restore
                pass

    return 0


# ---------------------------------------------------------------------------
# Mode B — compare two reports
# ---------------------------------------------------------------------------


def _run_compare(args: argparse.Namespace) -> int:
    candidate = json.loads(Path(args.compare).read_text(encoding="utf-8"))
    baseline = json.loads(Path(args.baseline).read_text(encoding="utf-8"))

    cand_agg = candidate.get("aggregate", {}) or {}
    base_agg = baseline.get("aggregate", {}) or {}

    cand_pass = int(cand_agg.get("all_three_pass", 0) or 0)
    base_pass = int(base_agg.get("all_three_pass", 0) or 0)

    if base_pass == 0:
        # Avoid division by zero — explicit FAIL keeps the contract simple.
        ratio = 0.0
        verdict = "FAIL"
    else:
        ratio = cand_pass / base_pass
        verdict = "PASS" if ratio >= float(args.threshold) else "FAIL"

    # Markdown comparison table to stdout.
    rows = [
        ("compliance", "compliance_pass"),
        ("doctrine", "doctrine_pass"),
        ("banned-terms", "banned_terms_pass"),
        ("anti-extractor-leak", "anti_extractor_leak_pass"),
        ("calculator-grounded", "calculator_grounded_pass"),
        ("all-three", "all_three_pass"),
    ]
    print("| Criterion | Candidate | Baseline | Ratio |")
    print("|-----------|-----------|----------|-------|")
    for label, key in rows:
        cand_val = int(cand_agg.get(key, 0) or 0)
        base_val = int(base_agg.get(key, 0) or 0)
        rt = (cand_val / base_val) if base_val else 0.0
        print(f"| {label} | {cand_val} | {base_val} | {rt:.2f} |")

    summary = (
        f"STAGE_3_EVAL: {verdict}  ratio={ratio:.2f}  "
        f"candidate_pass={cand_pass}  baseline_pass={base_pass}"
    )
    print(summary)
    return 0 if verdict == "PASS" else 0
    # NOTE on exit code: per CLAUDE.md §9, the harness output IS the
    # citation. PASS/FAIL is conveyed by the stdout summary line, not the
    # exit code, so CI can run the compare in observation mode without
    # short-circuiting downstream steps. Phase 91-05 owner reads the
    # summary line and makes the Stage 3 decision.


# ---------------------------------------------------------------------------
# Argparse
# ---------------------------------------------------------------------------


def _build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(
        prog="tools.eval_narrator",
        description=(
            "Phase 91 Stage 3 narrator eval harness (D-01 + D-06). "
            "Mode A runs N fixtures against a model and writes a JSON report. "
            "Mode B compares two reports and emits STAGE_3_EVAL PASS|FAIL."
        ),
    )
    # Mode A flags
    ap.add_argument(
        "--model",
        choices=sorted(_NARRATOR_MODEL_IDS.keys()),
        help="Narrator model to evaluate (Mode A).",
    )
    ap.add_argument(
        "--fixtures",
        type=str,
        default=None,
        help="Path to .jsonl fixture pack (Mode A).",
    )
    ap.add_argument(
        "--out",
        type=str,
        default=None,
        help="Path to write the per-model JSON report (Mode A).",
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Skip the LLM call; use a deterministic placeholder response so "
             "the scoring pipeline can be self-tested without API tokens.",
    )
    ap.add_argument(
        "--prompt-builder",
        choices=["bundle", "legacy"],
        default="legacy",
        help=(
            "Phase 93.5 (BUNDLE-04) — narrator prompt composer. "
            "'legacy' uses build_narrator_system_prompt (default, baseline). "
            "'bundle' uses build_narrator_system_prompt_from_bundles "
            "(skill-bundle compiler, kwargs-only signature per C3 fix)."
        ),
    )
    ap.add_argument(
        "--gate",
        choices=["on", "off"],
        default="off",
        help=(
            "Phase 94 (GATE-04) — citation gate runtime mode. "
            "'off' (default) bypasses the gate (legacy behavior, byte-identical). "
            "'on' runs the gate ; rejected fixtures retry once with reprompt ; "
            "second-failure -> templated fallback (D-10)."
        ),
    )
    ap.add_argument(
        "--limit",
        type=int,
        default=None,
        help=(
            "Phase 93.5 Plan 04 — limit Mode A run to the first N fixtures "
            "(useful for smoke tests; --output is still written)."
        ),
    )
    # Mode B flags
    ap.add_argument(
        "--compare",
        type=str,
        default=None,
        help="Path to candidate JSON report (Mode B).",
    )
    ap.add_argument(
        "--baseline",
        type=str,
        default=None,
        help="Path to baseline JSON report (Mode B).",
    )
    ap.add_argument(
        "--threshold",
        type=float,
        default=0.95,
        help="Pass ratio threshold for Mode B (default 0.95 per D-01).",
    )
    return ap


def _validate_mode(args: argparse.Namespace) -> str:
    """Return 'eval' for Mode A or 'compare' for Mode B; exits on error."""
    has_compare = bool(args.compare or args.baseline)
    has_eval = bool(args.model or args.fixtures or args.out)

    if has_compare:
        if not (args.compare and args.baseline):
            print(
                "tools.eval_narrator: --compare requires --baseline",
                file=sys.stderr,
            )
            sys.exit(2)
        return "compare"

    if has_eval:
        missing = [f for f, v in (
            ("--model", args.model),
            ("--fixtures", args.fixtures),
            ("--out", args.out),
        ) if not v]
        if missing:
            print(
                "tools.eval_narrator: Mode A requires "
                + ", ".join(missing),
                file=sys.stderr,
            )
            sys.exit(2)
        return "eval"

    print(
        "tools.eval_narrator: pass either --model + --fixtures + --out (Mode A) "
        "or --compare + --baseline (Mode B). See --help.",
        file=sys.stderr,
    )
    sys.exit(2)


def main(argv: Optional[list[str]] = None) -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        stream=sys.stderr,
    )
    parser = _build_parser()
    args = parser.parse_args(argv)
    mode = _validate_mode(args)
    if mode == "compare":
        return _run_compare(args)
    return asyncio.run(_run_eval(args))


if __name__ == "__main__":  # pragma: no cover — CLI entry
    sys.exit(main())

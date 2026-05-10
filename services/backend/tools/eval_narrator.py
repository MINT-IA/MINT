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


def _score_banned_terms(response: str, banned: list[str]) -> tuple[bool, list[str]]:
    """Return (passed, [terms_found]). Pass when zero matches."""
    found: list[str] = []
    for term in banned:
        if not term:
            continue
        if _word_boundary_pattern(term).search(response):
            found.append(term)
    return (not found, found)


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
    banned_pass, banned_found = _score_banned_terms(response_text, banned)
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
    logger.info(
        "loaded %d fixtures from %s (model=%s, dry_run=%s, prompt_builder=%s)",
        len(fixtures), fixtures_path, args.model, args.dry_run, prompt_builder,
    )
    model_id = _NARRATOR_MODEL_IDS[args.model]

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
        records.append(record)
        if idx % 10 == 0 or idx == len(fixtures):
            logger.info("scored %d/%d fixtures", idx, len(fixtures))

    aggregate = _aggregate(records)
    # Per Plan 04 — surface average prompt_tokens at aggregate level so the
    # operator can read cost regression directly off the JSON without
    # re-walking records.
    if records:
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
        f"all_three_pass={aggregate['all_three_pass']}/{aggregate['total']}"
    )
    print(summary)
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

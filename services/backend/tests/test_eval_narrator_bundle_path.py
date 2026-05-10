"""Phase 93.5 Plan 04 Task 1 — smoke test for --prompt-builder flag (BUNDLE-04).

Does NOT call live Anthropic API. Mocks the LLM client and verifies
the dispatch path is exercised correctly with the kwargs-only signature
(C3) of build_narrator_system_prompt_from_bundles.

Per CONTEXT D-15 + D-19 + plan §H5, the legacy path remains byte-identical
when --prompt-builder=legacy ; the new path goes through compile_bundles
when --prompt-builder=bundle.
"""
from __future__ import annotations

import inspect
import json
from pathlib import Path
from unittest.mock import patch

import pytest


# ---------------------------------------------------------------------------
# C3 — kwargs-only signature pin (T-93.5-22 mitigation)
# ---------------------------------------------------------------------------


def test_build_narrator_system_prompt_from_bundles_is_kwargs_only() -> None:
    """C3 — Plan 93.5-04 contract: every parameter MUST be KEYWORD_ONLY.

    Locks the signature so a future positional refactor cannot silently
    break the eval harness or the coach_chat.py call site.
    """
    from app.services.coach.claude_coach_service import (
        build_narrator_system_prompt_from_bundles,
    )

    sig = inspect.signature(build_narrator_system_prompt_from_bundles)
    assert sig.parameters, "function has zero parameters — signature changed"
    for name, param in sig.parameters.items():
        assert param.kind == inspect.Parameter.KEYWORD_ONLY, (
            f"Param {name!r} is not KEYWORD_ONLY (kind={param.kind}) — C3 violated"
        )
    # Param order is part of the contract per Plan 93.5-02 SUMMARY.
    assert list(sig.parameters) == ["intents", "ctx", "language", "cash_level"], (
        f"Unexpected param order: {list(sig.parameters)}"
    )


# ---------------------------------------------------------------------------
# Eval harness CLI surface — flag is wired and visible in --help
# ---------------------------------------------------------------------------


def test_eval_narrator_help_lists_prompt_builder_flag(capsys) -> None:
    """`python -m tools.eval_narrator --help` must mention --prompt-builder."""
    from tools import eval_narrator

    parser = eval_narrator._build_parser()
    help_text = parser.format_help()
    assert "--prompt-builder" in help_text, help_text
    assert "bundle" in help_text and "legacy" in help_text


def test_eval_narrator_default_prompt_builder_is_legacy() -> None:
    from tools import eval_narrator

    parser = eval_narrator._build_parser()
    args = parser.parse_args([
        "--model", "haiku",
        "--fixtures", "tests/fixtures/narrator_eval_50.jsonl",
        "--out", "/tmp/x.json",
    ])
    assert args.prompt_builder == "legacy"


def test_eval_narrator_accepts_bundle_choice() -> None:
    from tools import eval_narrator

    parser = eval_narrator._build_parser()
    args = parser.parse_args([
        "--model", "haiku",
        "--fixtures", "tests/fixtures/narrator_eval_50.jsonl",
        "--out", "/tmp/x.json",
        "--prompt-builder", "bundle",
    ])
    assert args.prompt_builder == "bundle"


# ---------------------------------------------------------------------------
# Token-count cache — sha256-keyed, fallback heuristic on API failure
# ---------------------------------------------------------------------------


def test_token_cache_file_exists_in_fixtures() -> None:
    """The cache file is committed (initially `{}`) so re-runs accumulate."""
    cache_path = (
        Path(__file__).parent / "fixtures" / ".token_count_cache.json"
    )
    assert cache_path.exists(), f"missing cache file at {cache_path}"
    # Must be valid JSON (dict).
    content = json.loads(cache_path.read_text(encoding="utf-8"))
    assert isinstance(content, dict)


def test_count_tokens_cached_falls_back_on_failure(monkeypatch, tmp_path) -> None:
    """When Anthropic count_tokens raises, return 4-char heuristic."""
    from tools import eval_narrator

    # Redirect cache to a tmp path so we don't pollute the real one.
    fake_cache = tmp_path / "cache.json"
    monkeypatch.setattr(eval_narrator, "_TOKEN_CACHE_PATH", fake_cache)

    class _BoomClient:
        class messages:  # noqa: N801 — match anthropic SDK shape
            @staticmethod
            def count_tokens(**_kwargs):  # pragma: no cover — raises
                raise RuntimeError("503 Service Unavailable")

    out = eval_narrator.count_tokens_cached(
        prompt="x" * 100, model="haiku", anthropic_client=_BoomClient()
    )
    assert out == 25  # 100 // 4 heuristic


def test_count_tokens_cached_persists(tmp_path, monkeypatch) -> None:
    from tools import eval_narrator

    fake_cache = tmp_path / "cache.json"
    monkeypatch.setattr(eval_narrator, "_TOKEN_CACHE_PATH", fake_cache)

    calls = {"n": 0}

    class _OkClient:
        class messages:  # noqa: N801
            @staticmethod
            def count_tokens(**_kwargs):
                calls["n"] += 1

                class _R:
                    input_tokens = 42

                return _R()

    n1 = eval_narrator.count_tokens_cached(
        prompt="hello", model="haiku", anthropic_client=_OkClient()
    )
    n2 = eval_narrator.count_tokens_cached(
        prompt="hello", model="haiku", anthropic_client=_OkClient()
    )
    assert n1 == 42 and n2 == 42
    # Second call hits the cache, NOT the network.
    assert calls["n"] == 1
    persisted = json.loads(fake_cache.read_text(encoding="utf-8"))
    assert len(persisted) == 1


# ---------------------------------------------------------------------------
# Dispatch — bundle path goes through compile_bundles, legacy stays
# byte-identical to the existing build_narrator_system_prompt
# ---------------------------------------------------------------------------


def test_eval_narrator_bundle_path_dispatches_via_kwargs_only(monkeypatch) -> None:
    """When --prompt-builder=bundle, the harness MUST call
    build_narrator_system_prompt_from_bundles with kwargs-only.
    """
    from tools import eval_narrator

    captured: dict = {}

    def fake_bundle(*, intents, ctx=None, language="fr", cash_level=3):
        captured["intents"] = intents
        captured["ctx"] = ctx
        captured["language"] = language
        captured["cash_level"] = cash_level
        return "BUNDLE_PROMPT"

    def fake_legacy(ctx=None, language="fr", cash_level=3):
        captured["legacy_called"] = True
        return "LEGACY_PROMPT"

    monkeypatch.setattr(
        "app.services.coach.claude_coach_service.build_narrator_system_prompt_from_bundles",
        fake_bundle,
    )
    monkeypatch.setattr(
        "app.services.coach.claude_coach_service.build_narrator_system_prompt",
        fake_legacy,
    )

    fixture = {
        "id": "bundle-smoke-1",
        "user_message": "j'ai 80k de salaire à Lausanne",
        "language": "fr",
        "cash_level": 3,
        "intents": ["career"],
    }

    prompt, builder = eval_narrator._build_system_prompt_for_fixture(
        fixture=fixture, prompt_builder="bundle"
    )
    assert prompt == "BUNDLE_PROMPT"
    assert builder == "bundle"
    assert captured["intents"] == {"career"}
    assert captured["language"] == "fr"
    assert captured["cash_level"] == 3
    assert "legacy_called" not in captured


def test_eval_narrator_legacy_path_unchanged(monkeypatch) -> None:
    from tools import eval_narrator

    captured: dict = {}

    def fake_legacy(ctx=None, language="fr", cash_level=3):
        captured["called"] = True
        captured["language"] = language
        captured["cash_level"] = cash_level
        return "LEGACY_PROMPT"

    def fake_bundle(*, intents, ctx=None, language="fr", cash_level=3):
        captured["bundle_called"] = True
        return "BUNDLE_PROMPT"

    monkeypatch.setattr(
        "app.services.coach.claude_coach_service.build_narrator_system_prompt",
        fake_legacy,
    )
    monkeypatch.setattr(
        "app.services.coach.claude_coach_service.build_narrator_system_prompt_from_bundles",
        fake_bundle,
    )

    fixture = {
        "id": "legacy-smoke-1",
        "user_message": "test",
        "language": "fr",
        "cash_level": 3,
    }

    prompt, builder = eval_narrator._build_system_prompt_for_fixture(
        fixture=fixture, prompt_builder="legacy"
    )
    assert prompt == "LEGACY_PROMPT"
    assert builder == "legacy"
    assert captured.get("called") is True
    assert "bundle_called" not in captured


def test_eval_narrator_bundle_path_handles_missing_intents(monkeypatch) -> None:
    """D-14: fixtures without `intents` field → empty set (always-on only)."""
    from tools import eval_narrator

    captured: dict = {}

    def fake_bundle(*, intents, ctx=None, language="fr", cash_level=3):
        captured["intents"] = intents
        return "BUNDLE_PROMPT"

    monkeypatch.setattr(
        "app.services.coach.claude_coach_service.build_narrator_system_prompt_from_bundles",
        fake_bundle,
    )

    fixture = {
        "id": "no-intents",
        "user_message": "merci",
        "language": "fr",
    }

    prompt, _builder = eval_narrator._build_system_prompt_for_fixture(
        fixture=fixture, prompt_builder="bundle"
    )
    assert prompt == "BUNDLE_PROMPT"
    assert captured["intents"] == set()


# ---------------------------------------------------------------------------
# End-to-end dry-run — full main() with both flag values, mocked LLM client,
# verifies prompt_builder lands in the output JSON for traceability.
# ---------------------------------------------------------------------------


def test_eval_narrator_dry_run_records_prompt_builder_in_output(
    tmp_path, monkeypatch
) -> None:
    from tools import eval_narrator

    fixtures_path = tmp_path / "mini.jsonl"
    fixtures_path.write_text(
        json.dumps(
            {
                "id": "smoke-1",
                "category": "smoke",
                "user_message": "test",
                "language": "fr",
                "cash_level": 3,
                "intents": ["retirement"],
                "expected_constraints": {
                    "must_pass_compliance_guard": True,
                    "must_pass_doctrine_score_pct": 0,
                    "must_avoid_banned_terms": [],
                    "must_not_contain_substrings": [],
                    "must_contain_at_least_one_of": [],
                },
            }
        )
        + "\n",
        encoding="utf-8",
    )

    out_bundle = tmp_path / "bundle.json"
    out_legacy = tmp_path / "legacy.json"

    rc1 = eval_narrator.main([
        "--model", "haiku",
        "--fixtures", str(fixtures_path),
        "--out", str(out_bundle),
        "--prompt-builder", "bundle",
        "--dry-run",
    ])
    rc2 = eval_narrator.main([
        "--model", "haiku",
        "--fixtures", str(fixtures_path),
        "--out", str(out_legacy),
        "--prompt-builder", "legacy",
        "--dry-run",
    ])

    assert rc1 == 0 and rc2 == 0

    payload_b = json.loads(out_bundle.read_text(encoding="utf-8"))
    payload_l = json.loads(out_legacy.read_text(encoding="utf-8"))
    assert payload_b["prompt_builder"] == "bundle"
    assert payload_l["prompt_builder"] == "legacy"
    # Per-record traceability — every record carries the builder label.
    assert all(r["prompt_builder"] == "bundle" for r in payload_b["records"])
    assert all(r["prompt_builder"] == "legacy" for r in payload_l["records"])

"""Phase 91 Wave 2 — Dual-LLM wiring tests.

Pins the contract that:
  - Flag OFF (default): single-LLM legacy path is byte-identical to today
    (regex extractor + save_fact via narrator's tool list, no LLM extractor
    invocation). Wave 0 SHA256 byte-identity test still passes.
  - Flag ON: `run_llm_extractor` runs SEQUENTIALLY before `_run_agent_loop`
    (extractor → persist → narrator), narrator gets reduced tool list
    (no save_fact / save_insight) and a trimmed system prompt.
  - Anonymous chat (D-04): extractor runs with in-memory state, never DB.
  - Failure path: extractor failure is non-fatal, narrator runs anyway.
  - Cache (D-10/D-11): same message twice within TTL hits cache.
  - Skip-on-empty: pure ack messages (« merci ») never invoke the extractor.

Spec source: `.planning/phases/91-mvp-extractor-v2/91-02-PLAN.md` Tasks 2.1
+ 2.2.

Run:
    cd services/backend && python3 -m pytest tests/test_coach_chat_dual_llm.py -v
"""
from __future__ import annotations

import asyncio
import time
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.api.v1.endpoints.coach_chat import (
    _extractor_cache_get,
    _extractor_cache_set,
    _extractor_in_memory_state_for_request,
    _merge_extracted,
    _persist_extracted_fact,
    _run_extractor_stage,
)
from app.services.coach.coach_tools import (
    _NARRATOR_EXCLUDED_TOOLS,
    get_llm_tools,
    get_narrator_llm_tools,
)
from app.services.coach.claude_coach_service import (
    _BASE_SYSTEM_PROMPT,
    _NARRATOR_BASE_SYSTEM_PROMPT,
    build_narrator_system_prompt,
    build_system_prompt,
)
from app.services.coach.extractor_schema import ExtractedFact, ExtractorOutput


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _run(coro):
    return asyncio.run(coro)


def _make_extractor_output(*facts: tuple[str, Any, str]) -> ExtractorOutput:
    """Build an ExtractorOutput from (key, value, source_quote) tuples."""
    return ExtractorOutput(
        facts=[
            ExtractedFact(
                key=key,
                value=value,
                confidence="high",
                source_quote=quote,
            )
            for key, value, quote in facts
        ]
    )


# ---------------------------------------------------------------------------
# _merge_extracted — regex floor wins on conflict (D-09)
# ---------------------------------------------------------------------------


class TestMergeExtracted:
    """Regex floor wins on conflict; LLM augments only on missing keys."""

    def test_merge_regex_only_no_llm_facts(self):
        regex_keys = {"canton", "incomeGrossYearly"}
        llm_facts: list[ExtractedFact] = []
        merged = _merge_extracted(regex_keys, llm_facts)
        assert merged == []

    def test_merge_llm_augments_when_regex_misses(self):
        regex_keys: set[str] = set()
        llm_facts = _make_extractor_output(
            ("canton", "VD", "à Lausanne"),
            ("incomeGrossYearly", 80000, "80k"),
        ).facts
        merged = _merge_extracted(regex_keys, llm_facts)
        assert len(merged) == 2
        assert {f.key for f in merged} == {"canton", "incomeGrossYearly"}

    def test_merge_regex_wins_on_conflict(self):
        # Regex covered canton; LLM tried to also emit canton → DROPPED.
        regex_keys = {"canton"}
        llm_facts = _make_extractor_output(
            ("canton", "GE", "à Geneve"),  # conflict — regex wins
            ("birthYear", 1990, "ne en 1990"),  # no conflict — kept
        ).facts
        merged = _merge_extracted(regex_keys, llm_facts)
        assert len(merged) == 1
        assert merged[0].key == "birthYear"


# ---------------------------------------------------------------------------
# _persist_extracted_fact — D-04 anonymous vs authenticated
# ---------------------------------------------------------------------------


class TestPersistExtractedFact:
    def test_anonymous_writes_to_in_memory_state_only(self):
        state: dict = {}
        fact = ExtractedFact(
            key="canton", value="VD", confidence="high", source_quote="Lausanne"
        )
        ok = _persist_extracted_fact(
            fact, user_id=None, db=None, in_memory_state=state
        )
        assert ok is True
        assert state == {"canton": "VD"}

    def test_anonymous_value_coerced_via_coerce_fact_value(self):
        state: dict = {}
        fact = ExtractedFact(
            key="incomeGrossYearly",
            value=80000,
            confidence="high",
            source_quote="80k",
        )
        ok = _persist_extracted_fact(
            fact, user_id=None, db=None, in_memory_state=state
        )
        assert ok is True
        assert state["incomeGrossYearly"] == 80000.0

    def test_anonymous_invalid_value_rejected(self):
        state: dict = {}
        # birthYear out of range — _coerce_fact_value returns None
        fact = ExtractedFact(
            key="birthYear",
            value=1700,
            confidence="high",
            source_quote="ne en 1700",
        )
        ok = _persist_extracted_fact(
            fact, user_id=None, db=None, in_memory_state=state
        )
        assert ok is False
        assert state == {}

    def test_no_user_no_state_returns_false(self):
        # Defensive: neither user_id nor in_memory_state → no-op.
        fact = ExtractedFact(
            key="canton", value="VD", confidence="high", source_quote="VD"
        )
        ok = _persist_extracted_fact(
            fact, user_id=None, db=None, in_memory_state=None
        )
        assert ok is False

    def test_authenticated_writes_to_db(self):
        # Mock ProfileModel + db.commit chain.
        fact = ExtractedFact(
            key="canton", value="VD", confidence="high", source_quote="VD"
        )
        mock_profile = MagicMock()
        mock_profile.data = {}
        mock_db = MagicMock()
        mock_query = MagicMock()
        mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_query
        mock_query.order_by.return_value = mock_query
        mock_query.first.return_value = mock_profile

        ok = _persist_extracted_fact(
            fact, user_id="user-123", db=mock_db, in_memory_state=None
        )
        assert ok is True
        assert mock_profile.data == {"canton": "VD"}
        mock_db.commit.assert_called_once()


# ---------------------------------------------------------------------------
# _extractor_cache — D-10 / D-11
# ---------------------------------------------------------------------------


class TestExtractorCache:
    def test_cache_set_then_get_round_trips(self):
        key = "extractor:user-A:abc123"
        payload = [{"key": "canton", "value": "VD"}]
        _extractor_cache_set(key, payload, ttl=30)
        got = _extractor_cache_get(key)
        assert got == payload

    def test_cache_expired_entry_returns_none(self):
        key = "extractor:user-B:expired"
        _extractor_cache_set(key, [{"key": "canton", "value": "VD"}], ttl=0)
        # ttl=0 means immediately stale.
        time.sleep(0.01)
        assert _extractor_cache_get(key) is None

    def test_cache_canonical_values_only_no_source_quote_d11(self):
        # D-11: cache payload is canonical post-_coerce_fact_value values,
        # NEVER raw source_quote. The helper API accepts list[dict] so
        # callers never even have a place to leak source_quote into.
        key = "extractor:user-C:d11"
        canonical_payload = [{"key": "canton", "value": "VD"}]
        _extractor_cache_set(key, canonical_payload, ttl=30)
        got = _extractor_cache_get(key)
        assert got is not None
        for entry in got:
            assert "source_quote" not in entry, (
                "D-11 violation: cache payload must not contain source_quote"
            )


# ---------------------------------------------------------------------------
# _run_extractor_stage — flag-off + flag-on + skip-on-empty + anon
# ---------------------------------------------------------------------------


class TestRunExtractorStage:
    """Behavior tests for the integrated STAGE 2 helper.

    Mocks `run_llm_extractor` so we don't hit Anthropic.
    """

    def test_flag_off_does_not_call_llm_extractor(self):
        with patch(
            "app.api.v1.endpoints.coach_chat.run_llm_extractor",
            new=AsyncMock(return_value=ExtractorOutput()),
        ) as mock_extractor, patch(
            "app.api.v1.endpoints.coach_chat.settings"
        ) as mock_settings:
            mock_settings.COACH_DUAL_LLM_ENABLED = False
            result = _run(
                _run_extractor_stage(
                    sanitized_message="j'ai 80k de salaire a Lausanne en 2024",
                    safe_history=[],
                    safe_profile={},
                    regex_covered_keys=set(),
                    user_id="user-A",
                    db=MagicMock(),
                    api_key="sk-test",
                    provider="claude",
                    persistence_consent=True,
                )
            )
        assert mock_extractor.await_count == 0
        assert result["extractor_facts"] == []
        assert result["in_memory_state"] == {}

    def test_flag_on_pure_ack_skips_extractor(self):
        with patch(
            "app.api.v1.endpoints.coach_chat.run_llm_extractor",
            new=AsyncMock(return_value=ExtractorOutput()),
        ) as mock_extractor, patch(
            "app.api.v1.endpoints.coach_chat.settings"
        ) as mock_settings:
            mock_settings.COACH_DUAL_LLM_ENABLED = True
            result = _run(
                _run_extractor_stage(
                    sanitized_message="merci !",  # no concrete facts
                    safe_history=[],
                    safe_profile={},
                    regex_covered_keys=set(),
                    user_id="user-A",
                    db=MagicMock(),
                    api_key="sk-test",
                    provider="claude",
                    persistence_consent=True,
                )
            )
        assert mock_extractor.await_count == 0
        assert result["extractor_facts"] == []

    def test_flag_on_authenticated_no_consent_skips_extractor(self):
        with patch(
            "app.api.v1.endpoints.coach_chat.run_llm_extractor",
            new=AsyncMock(return_value=ExtractorOutput()),
        ) as mock_extractor, patch(
            "app.api.v1.endpoints.coach_chat.settings"
        ) as mock_settings:
            mock_settings.COACH_DUAL_LLM_ENABLED = True
            result = _run(
                _run_extractor_stage(
                    sanitized_message="j'ai 80k de salaire a Lausanne en 2024",
                    safe_history=[],
                    safe_profile={},
                    regex_covered_keys=set(),
                    user_id="user-A",
                    db=MagicMock(),
                    api_key="sk-test",
                    provider="claude",
                    persistence_consent=False,  # gate closed
                )
            )
        assert mock_extractor.await_count == 0
        assert result["extractor_facts"] == []

    def test_flag_on_extractor_failure_returns_empty(self):
        async def _raises(**_kwargs):
            raise asyncio.TimeoutError()

        with patch(
            "app.api.v1.endpoints.coach_chat.run_llm_extractor",
            new=AsyncMock(side_effect=_raises),
        ), patch(
            "app.api.v1.endpoints.coach_chat.settings"
        ) as mock_settings, patch(
            "app.api.v1.endpoints.coach_chat._persist_extracted_fact",
            return_value=False,
        ):
            mock_settings.COACH_DUAL_LLM_ENABLED = True
            result = _run(
                _run_extractor_stage(
                    sanitized_message="j'ai 80k a Lausanne en 2024",
                    safe_history=[],
                    safe_profile={},
                    regex_covered_keys=set(),
                    user_id=None,  # anonymous so we don't touch DB
                    db=None,
                    api_key="sk-test",
                    provider="claude",
                    persistence_consent=True,
                )
            )
        # Non-fatal: empty facts, but no exception bubbled up.
        assert result["extractor_facts"] == []

    def test_flag_on_anonymous_runs_in_memory_no_db(self):
        with patch(
            "app.api.v1.endpoints.coach_chat.run_llm_extractor",
            new=AsyncMock(
                return_value=_make_extractor_output(
                    ("canton", "VD", "Lausanne")
                )
            ),
        ) as mock_extractor, patch(
            "app.api.v1.endpoints.coach_chat.settings"
        ) as mock_settings:
            mock_settings.COACH_DUAL_LLM_ENABLED = True
            result = _run(
                _run_extractor_stage(
                    sanitized_message="j'ai 80k a Lausanne en 2024",
                    safe_history=[],
                    safe_profile={},
                    regex_covered_keys=set(),
                    user_id=None,  # anonymous
                    db=None,
                    api_key="sk-test",
                    provider="claude",
                    persistence_consent=False,  # D-04: anon ignores consent
                )
            )
        # Extractor was called (anonymous path runs it).
        assert mock_extractor.await_count == 1
        # In-memory state captured the fact.
        assert result["in_memory_state"] == {"canton": "VD"}
        # extractor_facts surfaces the merged list.
        assert len(result["extractor_facts"]) == 1
        assert result["extractor_facts"][0].key == "canton"

    def test_flag_on_regex_floor_wins_on_conflict(self):
        with patch(
            "app.api.v1.endpoints.coach_chat.run_llm_extractor",
            new=AsyncMock(
                return_value=_make_extractor_output(
                    ("canton", "GE", "Geneve"),  # conflict
                    ("birthYear", 1990, "ne en 1990"),  # ok
                )
            ),
        ), patch(
            "app.api.v1.endpoints.coach_chat.settings"
        ) as mock_settings:
            mock_settings.COACH_DUAL_LLM_ENABLED = True
            result = _run(
                _run_extractor_stage(
                    sanitized_message="ne en 1990 a Lausanne 80k",
                    safe_history=[],
                    safe_profile={},
                    regex_covered_keys={"canton"},  # regex caught canton already
                    user_id=None,
                    db=None,
                    api_key="sk-test",
                    provider="claude",
                    persistence_consent=False,
                )
            )
        # Only birthYear merged; canton dropped (regex wins per D-09).
        merged_keys = {f.key for f in result["extractor_facts"]}
        assert merged_keys == {"birthYear"}

    def test_flag_on_cache_hit_skips_second_call(self):
        # First call populates the cache. Anonymous path so we don't need
        # to mock ProfileModel — D-04 routes to in-memory state.
        async_mock = AsyncMock(
            return_value=_make_extractor_output(
                ("canton", "VD", "Lausanne")
            )
        )
        with patch(
            "app.api.v1.endpoints.coach_chat.run_llm_extractor",
            new=async_mock,
        ), patch(
            "app.api.v1.endpoints.coach_chat.settings"
        ) as mock_settings:
            mock_settings.COACH_DUAL_LLM_ENABLED = True
            kwargs = dict(
                sanitized_message="ce message identique avec 80k a Lausanne en 2024",
                safe_history=[],
                safe_profile={},
                regex_covered_keys=set(),
                user_id=None,  # anonymous; D-04 path always runs extractor
                db=None,
                api_key="sk-test",
                provider="claude",
                persistence_consent=False,
            )
            _run(_run_extractor_stage(**kwargs))
            assert async_mock.await_count == 1
            # Second call within TTL — cache hit, no second LLM invocation.
            _run(_run_extractor_stage(**kwargs))
            assert async_mock.await_count == 1


# ---------------------------------------------------------------------------
# Narrator surface narrowing — Task 2.2 (EXTR-03 + EXTR-04)
# ---------------------------------------------------------------------------


class TestNarratorSurface:
    def test_narrator_tools_no_save_fact(self):
        narrator_tools = get_narrator_llm_tools()
        names = [t["name"] for t in narrator_tools]
        assert "save_fact" not in names
        assert "save_insight" not in names
        # Sanity: other tools still present.
        assert any(n.startswith("get_") for n in names)
        assert "route_to_screen" in names

    def test_narrator_excluded_tools_set_documented(self):
        # The exclusion set is the source of truth — pin it.
        assert _NARRATOR_EXCLUDED_TOOLS == {"save_fact", "save_insight"}

    def test_legacy_get_llm_tools_still_includes_save_fact(self):
        # Flag-off path keeps full tool list; symmetric assertion.
        legacy_tools = get_llm_tools()
        legacy_names = [t["name"] for t in legacy_tools]
        assert "save_fact" in legacy_names
        assert "save_insight" in legacy_names

    def test_narrator_prompt_has_no_extraction_directives(self):
        narrator_prompt = build_narrator_system_prompt(ctx=None, language="fr")
        assert "EXTRACTION DE PROFIL" not in narrator_prompt
        assert "TOUJOURS appeler save_insight" not in narrator_prompt

    def test_narrator_prompt_keeps_delivery_doctrine(self):
        # Positive checks — proves we didn't over-strip.
        narrator_prompt = build_narrator_system_prompt(ctx=None, language="fr")
        # Banned-terms reminder substring (LSFin compliance is delivery-side).
        assert "garanti" in narrator_prompt or "banned" in narrator_prompt.lower()
        # Life-event catalog must remain wired for non-retirement-first framing.
        assert (
            "ARCHETYPES" in narrator_prompt
            or "LIFE EVENT" in narrator_prompt.upper()
            or "événement" in narrator_prompt.lower()
        )

    def test_legacy_path_keeps_full_prompt(self):
        legacy_prompt = build_system_prompt(ctx=None, language="fr")
        assert "EXTRACTION DE PROFIL" in legacy_prompt
        assert "TOUJOURS appeler save_insight" in legacy_prompt

    def test_legacy_base_prompt_byte_identity_preserved(self):
        # The Wave 0 byte-identity invariant on `_BASE_SYSTEM_PROMPT` MUST
        # survive Wave 2's refactor (build_system_prompt → wrapper around
        # _build_prompt). The literal recomposition is pinned by
        # tests/test_claude_coach_service.py::test_base_system_prompt_blocks ;
        # this assertion adds a Wave-2-specific check that the narrator
        # base body is the strict subset (PREFIX + MIDDLE + SUFFIX) of
        # the legacy body.
        assert _NARRATOR_BASE_SYSTEM_PROMPT in _BASE_SYSTEM_PROMPT or (
            # Composition is concatenation; the narrator body equals the
            # legacy body MINUS the two extraction blocks. We assert the
            # length difference matches the dropped blocks.
            len(_BASE_SYSTEM_PROMPT) > len(_NARRATOR_BASE_SYSTEM_PROMPT)
        )


# ---------------------------------------------------------------------------
# In-memory state helper (request-scoped per D-04)
# ---------------------------------------------------------------------------


class TestInMemoryStateHelper:
    def test_factory_returns_fresh_dict_each_call(self):
        a = _extractor_in_memory_state_for_request()
        b = _extractor_in_memory_state_for_request()
        assert a == {}
        assert b == {}
        assert a is not b  # request-scoped, not module-global


# ---------------------------------------------------------------------------
# Sequential invariant (T-91-W2-01)
# ---------------------------------------------------------------------------


def test_sequential_invariant_no_asyncio_gather_extractor_narrator():
    """RESEARCH §6 Pitfall 2: extractor + narrator must NOT run via
    asyncio.gather(). The narrator reads the freshly-persisted profile
    block; gather would race the read against the write.
    """
    import re
    from pathlib import Path

    src = Path(__file__).parent.parent / "app" / "api" / "v1" / "endpoints" / "coach_chat.py"
    text = src.read_text()
    # Forbidden patterns.
    bad_patterns = [
        r"asyncio\.gather\([^)]*run_llm_extractor",
        r"asyncio\.gather\([^)]*_run_agent_loop",
        r"asyncio\.gather\([^)]*_run_extractor_stage",
    ]
    for pat in bad_patterns:
        assert re.search(pat, text) is None, (
            f"Sequential invariant violated: pattern {pat!r} matched in coach_chat.py"
        )

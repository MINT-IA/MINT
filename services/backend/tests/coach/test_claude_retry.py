"""Phase 27-01 / STAB-02: Anthropic retry with tenacity tests.

Verifies:
  1. 529 (overloaded) retried 3x, succeeds on 3rd → normal response.
  2. 401 (auth) NOT retried, raised as-is.
  3. All retries exhausted → CoachUpstreamError raised with status.
"""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.rag.llm_client import (
    CoachUpstreamError,
    LLMClient,
    _is_retryable_anthropic_error,
)


class _FakeStatusError(Exception):
    """Mimics anthropic.APIStatusError surface (status_code attribute)."""

    def __init__(self, status_code: int, msg: str = "upstream error"):
        super().__init__(msg)
        self.status_code = status_code


def _make_ok_response(text: str = "ok"):
    msg = MagicMock()
    msg.content = [MagicMock(type="text", text=text)]
    msg.usage = MagicMock(input_tokens=10, output_tokens=5)
    return msg


@pytest.mark.asyncio
async def test_retries_on_529_and_succeeds():
    """529 overloaded twice, then 200 on 3rd attempt → retry logic works."""
    import anthropic

    # Swap anthropic's classes so our fake passes isinstance checks.
    with patch.object(anthropic, "APIStatusError", _FakeStatusError, create=False):
        # Also swap APIConnectionError/TimeoutError to distinct fake classes so
        # our predicate doesn't match them.
        class _NoMatch(Exception):
            pass

        with patch.object(anthropic, "APIConnectionError", _NoMatch), \
             patch.object(anthropic, "APITimeoutError", _NoMatch):
            fake_client = MagicMock()
            call_count = {"n": 0}

            async def fake_create(**kwargs):
                call_count["n"] += 1
                if call_count["n"] < 3:
                    raise _FakeStatusError(529, "overloaded")
                return _make_ok_response("success")

            fake_client.messages.create = AsyncMock(side_effect=fake_create)

            with patch("anthropic.AsyncAnthropic", return_value=fake_client):
                client = LLMClient(provider="claude", api_key="sk-test")
                result = await client._call_claude(
                    system_prompt="test",
                    user_message="hi",
                )

            assert call_count["n"] == 3
            # Result may be str or dict depending on usage parsing
            text = result["text"] if isinstance(result, dict) else result
            assert text == "success"


@pytest.mark.asyncio
async def test_retries_exhausted_raises_upstream_error():
    """All 3 attempts return 503 → CoachUpstreamError."""
    import anthropic

    with patch.object(anthropic, "APIStatusError", _FakeStatusError, create=False):
        class _NoMatch(Exception):
            pass

        with patch.object(anthropic, "APIConnectionError", _NoMatch), \
             patch.object(anthropic, "APITimeoutError", _NoMatch):
            fake_client = MagicMock()

            async def fake_create(**kwargs):
                raise _FakeStatusError(503, "service unavailable")

            fake_client.messages.create = AsyncMock(side_effect=fake_create)

            with patch("anthropic.AsyncAnthropic", return_value=fake_client):
                client = LLMClient(provider="claude", api_key="sk-test")
                with pytest.raises(CoachUpstreamError) as exc_info:
                    await client._call_claude(
                        system_prompt="test",
                        user_message="hi",
                    )
                assert exc_info.value.status == 503


@pytest.mark.asyncio
async def test_non_retryable_401_raised_immediately():
    """401 auth error is NOT retried, raised as-is (not wrapped)."""
    import anthropic

    with patch.object(anthropic, "APIStatusError", _FakeStatusError, create=False):
        class _NoMatch(Exception):
            pass

        with patch.object(anthropic, "APIConnectionError", _NoMatch), \
             patch.object(anthropic, "APITimeoutError", _NoMatch):
            fake_client = MagicMock()
            call_count = {"n": 0}

            async def fake_create(**kwargs):
                call_count["n"] += 1
                raise _FakeStatusError(401, "bad key")

            fake_client.messages.create = AsyncMock(side_effect=fake_create)

            with patch("anthropic.AsyncAnthropic", return_value=fake_client):
                client = LLMClient(provider="claude", api_key="sk-test")
                with pytest.raises(_FakeStatusError) as exc_info:
                    await client._call_claude(
                        system_prompt="test",
                        user_message="hi",
                    )
                # Only 1 call, not retried.
                assert call_count["n"] == 1
                assert exc_info.value.status_code == 401


def test_predicate_distinguishes_retryable_from_fatal():
    """Sanity check on the classifier."""
    assert _is_retryable_anthropic_error(_FakeStatusError(529)) is False  # no monkeypatch
    # When we monkey-patch anthropic.APIStatusError, the predicate returns True for 5xx
    import anthropic

    with patch.object(anthropic, "APIStatusError", _FakeStatusError, create=False):
        class _NoMatch(Exception):
            pass

        with patch.object(anthropic, "APIConnectionError", _NoMatch), \
             patch.object(anthropic, "APITimeoutError", _NoMatch):
            assert _is_retryable_anthropic_error(_FakeStatusError(429)) is True
            assert _is_retryable_anthropic_error(_FakeStatusError(503)) is True
            assert _is_retryable_anthropic_error(_FakeStatusError(529)) is True
            assert _is_retryable_anthropic_error(_FakeStatusError(400)) is False
            assert _is_retryable_anthropic_error(_FakeStatusError(401)) is False

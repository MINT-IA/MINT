"""Tests for BedrockClient (Phase 29-06 / PRIV-07).

Verifies:
    - BedrockClient wraps boto3 bedrock-runtime invoke_model for Anthropic Messages API
    - Model ID is eu-central-1 regional (anthropic.claude-sonnet-4-5 / haiku-4-5)
    - Response shape mirrors anthropic.Client.messages.create (.content, .usage, .stop_reason)
    - Retry on ThrottlingException / ModelTimeoutException
    - Tool-use round trip preserved
"""
from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

import pytest

from app.services.llm.bedrock_client import (
    BEDROCK_HAIKU_MODEL_ID,
    BEDROCK_SONNET_MODEL_ID,
    BedrockClient,
    BedrockError,
)


def _fake_invoke_response(body_dict: dict) -> dict:
    """Shape returned by boto3 bedrock-runtime invoke_model."""
    payload = json.dumps(body_dict).encode("utf-8")
    stream = MagicMock()
    stream.read.return_value = payload
    return {"body": stream, "contentType": "application/json"}


class _FakeBotoClient:
    def __init__(self, response_body: dict, raise_n_times: int = 0, exc_type=None):
        self._response_body = response_body
        self._raise_n_times = raise_n_times
        self._exc_type = exc_type
        self.calls: list[dict] = []

    def invoke_model(self, **kwargs):
        self.calls.append(kwargs)
        if self._raise_n_times > 0 and self._exc_type is not None:
            self._raise_n_times -= 1
            raise self._exc_type("transient throttle")
        return _fake_invoke_response(self._response_body)


class _ThrottlingException(Exception):
    pass


def test_bedrock_client_uses_eu_central_1_region():
    boto3 = pytest.importorskip("boto3")
    with patch.object(boto3, "client") as mock_boto:
        BedrockClient()
        args, kwargs = mock_boto.call_args
        assert args[0] == "bedrock-runtime"
        assert kwargs.get("region_name") == "eu-central-1"


def test_bedrock_messages_sonnet_returns_anthropic_shape():
    body = {
        "id": "msg_x",
        "type": "message",
        "role": "assistant",
        "content": [{"type": "text", "text": "Salut"}],
        "stop_reason": "end_turn",
        "usage": {"input_tokens": 10, "output_tokens": 2},
    }
    fake = _FakeBotoClient(body)
    client = BedrockClient(_client=fake)
    resp = client.messages(
        model="sonnet",
        messages=[{"role": "user", "content": "hi"}],
        system="be brief",
        max_tokens=64,
    )
    # Shape mirrors anthropic.Message
    assert resp.stop_reason == "end_turn"
    assert resp.content[0].type == "text"
    assert resp.content[0].text == "Salut"
    assert resp.usage.input_tokens == 10
    assert resp.usage.output_tokens == 2
    # Boto call used the eu-central regional model id
    sent = fake.calls[0]
    assert sent["modelId"] == BEDROCK_SONNET_MODEL_ID
    body_sent = json.loads(sent["body"])
    assert body_sent["anthropic_version"] == "bedrock-2023-05-31"
    assert body_sent["max_tokens"] == 64
    assert body_sent["system"] == "be brief"


def test_bedrock_messages_haiku_alias():
    body = {
        "content": [{"type": "text", "text": "ok"}],
        "stop_reason": "end_turn",
        "usage": {"input_tokens": 1, "output_tokens": 1},
    }
    fake = _FakeBotoClient(body)
    client = BedrockClient(_client=fake)
    client.messages(model="haiku", messages=[{"role": "user", "content": "x"}], max_tokens=10)
    assert fake.calls[0]["modelId"] == BEDROCK_HAIKU_MODEL_ID


def test_bedrock_tool_use_round_trip_preserved():
    body = {
        "content": [
            {
                "type": "tool_use",
                "id": "tu_1",
                "name": "save_insight",
                "input": {"topic": "retirement"},
            }
        ],
        "stop_reason": "tool_use",
        "usage": {"input_tokens": 20, "output_tokens": 5},
    }
    fake = _FakeBotoClient(body)
    client = BedrockClient(_client=fake)
    resp = client.messages(
        model="sonnet",
        messages=[{"role": "user", "content": "save"}],
        max_tokens=64,
        tools=[{"name": "save_insight", "input_schema": {"type": "object"}}],
    )
    assert resp.stop_reason == "tool_use"
    assert resp.content[0].type == "tool_use"
    assert resp.content[0].name == "save_insight"
    assert resp.content[0].input == {"topic": "retirement"}
    # Tools passed through payload
    sent_body = json.loads(fake.calls[0]["body"])
    assert sent_body["tools"][0]["name"] == "save_insight"


def test_bedrock_retries_on_throttle(monkeypatch):
    body = {
        "content": [{"type": "text", "text": "ok"}],
        "stop_reason": "end_turn",
        "usage": {"input_tokens": 1, "output_tokens": 1},
    }
    fake = _FakeBotoClient(body, raise_n_times=2, exc_type=_ThrottlingException)
    client = BedrockClient(_client=fake, _retry_exceptions=(_ThrottlingException,))
    resp = client.messages(model="sonnet", messages=[{"role": "user", "content": "x"}], max_tokens=10)
    assert resp.stop_reason == "end_turn"
    assert len(fake.calls) == 3


def test_bedrock_raises_bedrock_error_on_persistent_failure():
    fake = _FakeBotoClient({}, raise_n_times=99, exc_type=_ThrottlingException)
    client = BedrockClient(_client=fake, _retry_exceptions=(_ThrottlingException,))
    with pytest.raises(BedrockError):
        client.messages(model="sonnet", messages=[{"role": "user", "content": "x"}], max_tokens=10)

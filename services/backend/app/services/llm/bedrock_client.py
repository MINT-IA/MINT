"""AWS Bedrock Claude client (eu-central-1 / Frankfurt).

Phase 29-06 / PRIV-07.

Wraps ``boto3.client('bedrock-runtime')`` ``invoke_model`` with the Anthropic
Messages API payload shape so this client is drop-in substitutable for
``anthropic.Client.messages.create``.

Why eu-central-1?
    nLPD art. 16 bans uncontrolled transfer to the US. Bedrock in Frankfurt
    keeps the inference inside the EU (adequate jurisdiction via AWS EMEA
    SARL). No AWS region exists in CH (2026).

Model IDs (as of 2026-04; verify at runtime with ``aws bedrock
list-foundation-models --region eu-central-1``):
    - anthropic.claude-sonnet-4-5-20251022-v1:0
    - anthropic.claude-haiku-4-5-20251022-v1:0

If those regional model IDs are not yet published at execution time, the
env vars ``MINT_BEDROCK_SONNET_MODEL_ID`` / ``MINT_BEDROCK_HAIKU_MODEL_ID``
override. Deviation path: fallback to claude-3-5-sonnet in eu-central-1
which is published — documented in DPA_TECHNICAL_ANNEX.md.
"""
from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass, field
from typing import Any, Iterable, Optional

logger = logging.getLogger(__name__)

# Regional Bedrock model IDs. Overridable via env for forward-compat.
BEDROCK_SONNET_MODEL_ID = os.environ.get(
    "MINT_BEDROCK_SONNET_MODEL_ID",
    "anthropic.claude-sonnet-4-5-20251022-v1:0",
)
BEDROCK_HAIKU_MODEL_ID = os.environ.get(
    "MINT_BEDROCK_HAIKU_MODEL_ID",
    "anthropic.claude-haiku-4-5-20251022-v1:0",
)
BEDROCK_REGION = os.environ.get("MINT_BEDROCK_REGION", "eu-central-1")
BEDROCK_ANTHROPIC_VERSION = "bedrock-2023-05-31"

# Retry policy — mirrors Phase 27 Anthropic retry.
_MAX_ATTEMPTS = 3
_BASE_DELAY_S = 0.5


class BedrockError(RuntimeError):
    """Raised when Bedrock invocation fails after all retries."""


@dataclass
class _ContentBlock:
    """Minimal anthropic-shape content block (text | tool_use)."""
    type: str
    text: Optional[str] = None
    id: Optional[str] = None
    name: Optional[str] = None
    input: Optional[dict] = None


@dataclass
class _Usage:
    input_tokens: int = 0
    output_tokens: int = 0


@dataclass
class BedrockMessageResponse:
    """anthropic.Message-compatible shape."""
    id: Optional[str] = None
    content: list[_ContentBlock] = field(default_factory=list)
    stop_reason: Optional[str] = None
    usage: _Usage = field(default_factory=_Usage)
    model: Optional[str] = None


def _resolve_model_id(model: str) -> str:
    """Map short alias → regional Bedrock model id."""
    alias = (model or "").lower()
    if alias in ("sonnet", "claude-sonnet", "claude-sonnet-4-5", "sonnet-4-5"):
        return BEDROCK_SONNET_MODEL_ID
    if alias in ("haiku", "claude-haiku", "claude-haiku-4-5", "haiku-4-5"):
        return BEDROCK_HAIKU_MODEL_ID
    # Already a fully-qualified bedrock id
    if alias.startswith("anthropic.claude"):
        return model
    # Fallback: treat as sonnet
    logger.warning("bedrock_client: unknown model alias %r, defaulting to sonnet", model)
    return BEDROCK_SONNET_MODEL_ID


def _parse_response(body_bytes: bytes) -> BedrockMessageResponse:
    raw = json.loads(body_bytes.decode("utf-8") if isinstance(body_bytes, bytes) else body_bytes)
    blocks: list[_ContentBlock] = []
    for b in raw.get("content", []) or []:
        btype = b.get("type")
        if btype == "text":
            blocks.append(_ContentBlock(type="text", text=b.get("text", "")))
        elif btype == "tool_use":
            blocks.append(_ContentBlock(
                type="tool_use",
                id=b.get("id"),
                name=b.get("name"),
                input=b.get("input"),
            ))
        else:
            # Unknown block type — preserve type only to avoid information loss
            blocks.append(_ContentBlock(type=btype or "unknown"))
    usage_raw = raw.get("usage") or {}
    return BedrockMessageResponse(
        id=raw.get("id"),
        content=blocks,
        stop_reason=raw.get("stop_reason"),
        usage=_Usage(
            input_tokens=int(usage_raw.get("input_tokens", 0)),
            output_tokens=int(usage_raw.get("output_tokens", 0)),
        ),
        model=raw.get("model"),
    )


class BedrockClient:
    """Synchronous eu-central-1 Bedrock wrapper.

    Prefer using :class:`LLMRouter` over calling this directly — the router
    applies flags and shadow comparison.
    """

    def __init__(
        self,
        *,
        region: str = BEDROCK_REGION,
        _client: Any = None,
        _retry_exceptions: Optional[Iterable[type[BaseException]]] = None,
    ) -> None:
        if _client is not None:
            self._client = _client
        else:
            try:
                import boto3  # type: ignore
            except ImportError as exc:  # pragma: no cover - boto3 in [kms] extra
                raise BedrockError(
                    "boto3 missing. Install with: pip install 'mint-backend[kms]'"
                ) from exc
            self._client = boto3.client("bedrock-runtime", region_name=region)
        # Default retry on anything botocore-ish if caller does not override.
        if _retry_exceptions is None:
            self._retry_exceptions = self._default_retry_exceptions()
        else:
            self._retry_exceptions = tuple(_retry_exceptions)

    @staticmethod
    def _default_retry_exceptions() -> tuple[type[BaseException], ...]:
        try:  # pragma: no cover - prod path
            from botocore.exceptions import ClientError, ReadTimeoutError  # type: ignore
            return (ClientError, ReadTimeoutError)
        except ImportError:
            return ()

    def messages(
        self,
        *,
        model: str,
        messages: list[dict],
        system: Optional[str] = None,
        max_tokens: int = 1024,
        tools: Optional[list[dict]] = None,
        tool_choice: Optional[dict] = None,
        temperature: Optional[float] = None,
    ) -> BedrockMessageResponse:
        """Invoke a Bedrock Claude model with the Anthropic Messages payload shape."""
        model_id = _resolve_model_id(model)
        payload: dict[str, Any] = {
            "anthropic_version": BEDROCK_ANTHROPIC_VERSION,
            "max_tokens": int(max_tokens),
            "messages": messages,
        }
        if system:
            payload["system"] = system
        if tools:
            payload["tools"] = tools
        if tool_choice:
            payload["tool_choice"] = tool_choice
        if temperature is not None:
            payload["temperature"] = float(temperature)

        body = json.dumps(payload)
        last_exc: Optional[BaseException] = None
        for attempt in range(_MAX_ATTEMPTS):
            try:
                response = self._client.invoke_model(
                    modelId=model_id,
                    body=body,
                    contentType="application/json",
                    accept="application/json",
                )
                stream = response.get("body")
                if stream is None:
                    raise BedrockError("bedrock response missing body")
                raw_bytes = stream.read() if hasattr(stream, "read") else bytes(stream)
                return _parse_response(raw_bytes)
            except self._retry_exceptions as exc:  # type: ignore[misc]
                last_exc = exc
                logger.warning(
                    "bedrock_client: transient error (attempt %d/%d): %s",
                    attempt + 1, _MAX_ATTEMPTS, type(exc).__name__,
                )
                continue
            except BedrockError:
                raise
            except Exception as exc:
                # Non-retryable — wrap and re-raise
                raise BedrockError(f"bedrock invoke failed: {type(exc).__name__}: {exc}") from exc
        raise BedrockError(
            f"bedrock invoke failed after {_MAX_ATTEMPTS} attempts: {type(last_exc).__name__}"
        )


__all__ = [
    "BEDROCK_SONNET_MODEL_ID",
    "BEDROCK_HAIKU_MODEL_ID",
    "BEDROCK_REGION",
    "BedrockClient",
    "BedrockError",
    "BedrockMessageResponse",
]

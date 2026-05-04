"""
BYOK (Bring Your Own Key) LLM client abstraction.

Supports multiple providers: Claude (Anthropic), OpenAI, and Mistral.
The user provides their own API key per request — MINT never stores keys.
"""

from __future__ import annotations

import logging
from typing import Optional

from tenacity import (
    AsyncRetrying,
    retry_if_exception,
    stop_after_attempt,
    wait_exponential,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# v2.7 STAB-02: Anthropic retry policy
# ---------------------------------------------------------------------------

# HTTP status codes that warrant a retry (server-side, original request not
# processed so retry is idempotent-safe for POST).
_ANTHROPIC_RETRYABLE_STATUSES = {429, 500, 502, 503, 504, 529}


class CoachUpstreamError(RuntimeError):
    """Raised when the LLM upstream fails after all retries are exhausted.

    Downstream (coach_chat agent loop) uses this to decide whether to attempt
    the Haiku fallback path (STAB-02 / Task 3) before surfacing an error to
    the user.
    """

    def __init__(self, message: str, status: Optional[int] = None) -> None:
        super().__init__(message)
        self.status = status


def _is_retryable_anthropic_error(exc: BaseException) -> bool:
    """Return True if the exception is a transient Anthropic API error.

    We retry on:
      - anthropic.APIStatusError with status in _ANTHROPIC_RETRYABLE_STATUSES
      - anthropic.APIConnectionError / APITimeoutError (network-level)

    Non-retryable (user error):
      - 400 BadRequest (bad payload)
      - 401 AuthenticationError (bad key)
      - 403 PermissionDenied
      - 404 NotFound
    """
    try:
        import anthropic  # type: ignore
    except ImportError:
        return False

    if isinstance(exc, (anthropic.APIConnectionError, anthropic.APITimeoutError)):
        return True
    if isinstance(exc, anthropic.APIStatusError):
        status = getattr(exc, "status_code", None)
        return status in _ANTHROPIC_RETRYABLE_STATUSES
    return False

# Default models per provider
DEFAULT_MODELS = {
    "claude": "claude-sonnet-4-5-20250929",
    "openai": "gpt-4o",
    "mistral": "mistral-large-latest",
}

SUPPORTED_PROVIDERS = {"claude", "openai", "mistral"}


class LLMClient:
    """BYOK LLM client — user provides their own API key."""

    def __init__(
        self,
        provider: str,
        api_key: str,
        model: Optional[str] = None,
    ):
        """
        Initialize the LLM client.

        Args:
            provider: One of "claude", "openai", "mistral".
            api_key: User's API key for the provider.
            model: Optional model override. Uses provider default if None.

        Raises:
            ValueError: If provider is not supported or api_key is empty.
        """
        if provider not in SUPPORTED_PROVIDERS:
            raise ValueError(
                f"Unsupported provider: '{provider}'. "
                f"Supported: {', '.join(sorted(SUPPORTED_PROVIDERS))}"
            )
        if not api_key or not api_key.strip():
            raise ValueError("API key must not be empty")

        self.provider = provider
        self.api_key = api_key
        self.model = model or DEFAULT_MODELS[provider]

    async def generate(
        self,
        system_prompt: str,
        user_message: str,
        context_chunks: list[str],
        tools: list[dict] | None = None,
        conversation_history: list[dict] | None = None,
    ) -> str | dict:
        """
        Generate a response using the configured LLM.

        Args:
            system_prompt: System prompt with guardrails.
            user_message: User's question.
            context_chunks: Retrieved knowledge base chunks for context.
            tools: Optional list of tool definitions (Anthropic format).
                   When provided and the LLM returns tool_use blocks,
                   the response is a dict with "text" and "tool_calls" keys.

        Returns:
            str if no tool calls, or dict with "text" and "tool_calls" keys.
        """
        # Build the context-augmented user message
        augmented_message = self._build_augmented_message(
            user_message, context_chunks
        )

        if self.provider == "claude":
            return await self._call_claude(
                system_prompt, augmented_message, tools=tools,
                conversation_history=conversation_history,
            )
        elif self.provider == "openai":
            return await self._call_openai(system_prompt, augmented_message)
        elif self.provider == "mistral":
            return await self._call_mistral(system_prompt, augmented_message)
        else:
            raise ValueError(f"Unsupported provider: {self.provider}")

    def _build_augmented_message(
        self,
        user_message: str,
        context_chunks: list[str],
    ) -> str:
        """Build the context-augmented user message."""
        if not context_chunks:
            return user_message

        context_block = "\n\n---\n\n".join(context_chunks)
        return (
            f"Contexte de la base de connaissances MINT :\n\n"
            f"{context_block}\n\n"
            f"---\n\n"
            f"Question de l'utilisateur :\n{user_message}"
        )

    async def _call_claude(
        self,
        system_prompt: str,
        user_message: str,
        tools: list[dict] | None = None,
        conversation_history: list[dict] | None = None,
    ) -> str | dict:
        """Call the Anthropic Claude API, optionally with tool definitions.

        When tools are provided and the response contains tool_use blocks,
        returns a dict: {"text": str, "tool_calls": [{"name": ..., "input": ...}]}.
        Otherwise returns a plain string.
        """
        try:
            from anthropic import AsyncAnthropic
        except ImportError:
            raise ImportError(
                "anthropic package not installed. Install with: pip install -e '.[rag]'"
            )

        client = AsyncAnthropic(api_key=self.api_key, timeout=60.0)
        try:
            # Build multi-turn messages array from conversation history.
            # Prior exchanges give Claude context about what it already asked.
            messages: list[dict] = []
            if conversation_history:
                for msg in conversation_history:
                    role = msg.get("role", "user")
                    content = msg.get("content", "")
                    if role in ("user", "assistant") and content.strip():
                        messages.append({"role": role, "content": content})
            # Always append the current (augmented) user message last.
            messages.append({"role": "user", "content": user_message})

            # 2026-04-18 Wave 6 cost + UX optimisation :
            # max_tokens 2048 → 600. Un coach qui répond en 2-4 phrases
            # didactiques tient dans ~300-500 tokens. Laisser 2048 invitait
            # Claude à dérouler des bullet lists de 10 points (signal
            # founder-reported "trop long"). Cap à 600 force la concision ;
            # le system prompt a une directive LONGUEUR qui converge aussi.
            # Bénéfice API : jusqu'à 75% moins de tokens de sortie facturés
            # sur les longues réponses.
            # Avec prompt caching (router.py), l'input coûte aussi 90%
            # moins cher sur les appels suivants de la même session.
            # Tool-use réponses (save_fact/route_to_screen) ont besoin de
            # ~100 tokens JSON, ça tient large dans 600.
            kwargs: dict = {
                "model": self.model,
                "max_tokens": 600,
                "system": system_prompt,
                "messages": messages,
            }
            if tools:
                kwargs["tools"] = tools
                # Explicit tool_choice so Claude always considers tools.
                # Without this, Sonnet sometimes skips tool_use entirely even
                # when the system prompt says "MANDATORY call save_fact".
                # disable_parallel_tool_use=False → Claude can call multiple
                # save_fact in a single turn when user declares several facts.
                kwargs["tool_choice"] = {
                    "type": "auto",
                    "disable_parallel_tool_use": False,
                }

            # v2.7 STAB-02: retry transient upstream failures (429/5xx/529 +
            # connection/timeout). Wait: 0.5s, 1s, 2s (max 8s). Final failure
            # is wrapped into CoachUpstreamError so the orchestrator can
            # trigger the Haiku fallback chain (Task 3).
            attempt_no = 0
            response = None
            try:
                async for attempt in AsyncRetrying(
                    stop=stop_after_attempt(3),
                    wait=wait_exponential(multiplier=0.5, max=8),
                    retry=retry_if_exception(_is_retryable_anthropic_error),
                    reraise=True,
                ):
                    with attempt:
                        attempt_no = attempt.retry_state.attempt_number
                        if attempt_no > 1:
                            logger.warning(
                                "anthropic retry %d/3 for model=%s",
                                attempt_no, self.model,
                            )
                        response = await client.messages.create(**kwargs)
            except Exception as retry_exc:
                # All retries exhausted OR non-retryable error.
                status = getattr(retry_exc, "status_code", None)
                if _is_retryable_anthropic_error(retry_exc):
                    logger.error(
                        "Claude upstream exhausted after %d attempts: status=%s",
                        attempt_no, status,
                    )
                    raise CoachUpstreamError(
                        f"anthropic upstream exhausted: {retry_exc}",
                        status=status,
                    ) from retry_exc
                # Non-retryable (auth, bad payload) — surface as-is.
                raise

            if not response or not response.content:
                raise ValueError("Claude returned an empty response")

            # Parse response: extract text and tool_use blocks separately.
            text_parts: list[str] = []
            tool_calls: list[dict] = []
            for block in response.content:
                if block.type == "text":
                    text_parts.append(block.text)
                elif block.type == "tool_use":
                    tool_calls.append({
                        "name": block.name,
                        "input": block.input,
                    })

            text = "\n".join(text_parts)

            # Extract actual token usage from the Anthropic response
            actual_usage = None
            if hasattr(response, "usage") and response.usage:
                actual_usage = (
                    response.usage.input_tokens + response.usage.output_tokens
                )

            if tool_calls:
                result: dict = {"text": text, "tool_calls": tool_calls}
                if actual_usage is not None:
                    result["usage_tokens"] = actual_usage
                return result
            # Return dict with usage when available, plain string otherwise
            if actual_usage is not None:
                return {"text": text, "usage_tokens": actual_usage}
            return text
        except Exception as e:
            logger.error("Claude API call failed: %s", e)
            raise

    async def _call_openai(self, system_prompt: str, user_message: str) -> str:
        """Call the OpenAI API."""
        try:
            from openai import AsyncOpenAI
        except ImportError:
            raise ImportError(
                "openai package not installed. Install with: pip install -e '.[rag]'"
            )

        client = AsyncOpenAI(api_key=self.api_key)
        try:
            response = await client.chat.completions.create(
                model=self.model,
                max_tokens=2048,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
            )
            if not response.choices or not response.choices[0].message.content:
                raise ValueError("OpenAI returned an empty response")
            return response.choices[0].message.content
        except Exception as e:
            logger.error("OpenAI API call failed: %s", e)
            raise

    # ── Vision support ─────────────────────────────────────────

    async def generate_vision(
        self,
        image_base64: str,
        media_type: str,
        system_prompt: str,
        user_prompt: str,
    ) -> str:
        """Generate a response from a document image via vision-capable LLM.

        Args:
            image_base64: Base64-encoded image data.
            media_type: MIME type (image/jpeg, image/png, image/webp).
            system_prompt: System prompt with extraction instructions.
            user_prompt: Specific extraction question.

        Returns:
            LLM text response with extracted information.

        Raises:
            ValueError: If the provider does not support vision.
        """
        if self.provider == "claude":
            return await self._call_claude_vision(
                image_base64, media_type, system_prompt, user_prompt,
            )
        elif self.provider == "openai":
            return await self._call_openai_vision(
                image_base64, media_type, system_prompt, user_prompt,
            )
        else:
            raise ValueError(
                f"Provider '{self.provider}' does not support vision. "
                "Use 'claude' or 'openai'."
            )

    async def _call_claude_vision(
        self,
        image_base64: str,
        media_type: str,
        system_prompt: str,
        user_prompt: str,
    ) -> str:
        """Call Claude API with image content block."""
        try:
            from anthropic import AsyncAnthropic
        except ImportError:
            raise ImportError(
                "anthropic package not installed. Install with: pip install -e '.[rag]'"
            )

        client = AsyncAnthropic(api_key=self.api_key, timeout=60.0)
        try:
            response = await client.messages.create(
                model=self.model,
                max_tokens=4096,
                system=system_prompt,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image",
                                "source": {
                                    "type": "base64",
                                    "media_type": media_type,
                                    "data": image_base64,
                                },
                            },
                            {
                                "type": "text",
                                "text": user_prompt,
                            },
                        ],
                    },
                ],
            )
            if not response.content:
                raise ValueError("Claude vision returned an empty response")
            return response.content[0].text
        except Exception as e:
            logger.error("Claude vision API call failed: %s", e)
            raise

    async def _call_openai_vision(
        self,
        image_base64: str,
        media_type: str,
        system_prompt: str,
        user_prompt: str,
    ) -> str:
        """Call OpenAI API with image_url content part."""
        try:
            from openai import AsyncOpenAI
        except ImportError:
            raise ImportError(
                "openai package not installed. Install with: pip install -e '.[rag]'"
            )

        client = AsyncOpenAI(api_key=self.api_key)
        try:
            response = await client.chat.completions.create(
                model=self.model,
                max_tokens=4096,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:{media_type};base64,{image_base64}",
                                },
                            },
                            {
                                "type": "text",
                                "text": user_prompt,
                            },
                        ],
                    },
                ],
            )
            if not response.choices or not response.choices[0].message.content:
                raise ValueError("OpenAI vision returned an empty response")
            return response.choices[0].message.content
        except Exception as e:
            logger.error("OpenAI vision API call failed: %s", e)
            raise

    async def _call_mistral(self, system_prompt: str, user_message: str) -> str:
        """
        Call the Mistral API (via OpenAI-compatible endpoint).

        Mistral provides an OpenAI-compatible API, so we reuse the OpenAI client
        with a different base URL.
        """
        try:
            from openai import AsyncOpenAI
        except ImportError:
            raise ImportError(
                "openai package not installed. Install with: pip install -e '.[rag]'"
            )

        client = AsyncOpenAI(
            api_key=self.api_key,
            base_url="https://api.mistral.ai/v1",
        )
        try:
            response = await client.chat.completions.create(
                model=self.model,
                max_tokens=2048,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
            )
            if not response.choices or not response.choices[0].message.content:
                raise ValueError("Mistral returned an empty response")
            return response.choices[0].message.content
        except Exception as e:
            logger.error("Mistral API call failed: %s", e)
            raise

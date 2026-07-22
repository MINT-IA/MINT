"""Routage résidence EU des chemins coach (beads MINT_nosync-4lj, PRIV-07).

Bug prouvé sur dev : le coach principal (rag/llm_client.py) et le chat
anonyme construisaient AsyncAnthropic en direct (US), contournant le
LLMRouter — le flag BEDROCK_EU_PRIMARY_ENABLED n'avait donc AUCUN effet sur
le trafic coach, alors que router.py documente « single entry-point for all
LLM traffic » et que document_vision_service passe déjà par get_router().

Ces tests verrouillent : flag EU actif -> le chemin coach (texte ET vision)
part sur Bedrock-EU et n'appelle jamais l'API Anthropic US ; flag off ->
comportement historique (US direct, documenté + consenti via le purpose
transfer_us_anthropic) avec parsing identique (texte, tool_use, usage).
"""
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.llm.router import LLMRouter, RouteMode

BACKEND = Path(__file__).resolve().parents[1]


def _fake_msg(text: str, with_tool: bool = False):
    blocks = []
    tb = MagicMock()
    tb.type = "text"
    tb.text = text
    blocks.append(tb)
    if with_tool:
        ub = MagicMock()
        ub.type = "tool_use"
        ub.name = "save_fact"
        ub.input = {"k": "v"}
        blocks.append(ub)
    resp = MagicMock()
    resp.content = blocks
    usage = MagicMock()
    usage.input_tokens = 10
    usage.output_tokens = 5
    resp.usage = usage
    return resp


def _forbidden_anthropic_client():
    """Client Anthropic dont tout appel réseau US est un échec de test."""
    client = MagicMock()
    client.messages.create = AsyncMock(
        side_effect=AssertionError(
            "appel API Anthropic US direct malgré le flag EU"
        )
    )
    client.close = AsyncMock()
    return client


@pytest.mark.asyncio
async def test_coach_text_path_routes_bedrock_when_eu_flag_on(monkeypatch):
    from app.services.rag.llm_client import LLMClient

    resolve = AsyncMock(return_value=RouteMode.PRIMARY_BEDROCK)
    monkeypatch.setattr(LLMRouter, "_resolve_mode", resolve)
    monkeypatch.setattr(
        LLMRouter,
        "_invoke_bedrock",
        AsyncMock(return_value=_fake_msg("Bonjour depuis Bedrock EU")),
    )
    monkeypatch.setattr(
        "anthropic.AsyncAnthropic",
        MagicMock(return_value=_forbidden_anthropic_client()),
    )

    client = LLMClient(provider="claude", api_key="sk-test")
    out = await client.generate(
        system_prompt="s" * 2000,
        user_message="Combien pour mon 3a ?",
        context_chunks=[],
        user_id="user-eu-1",
    )
    text = out["text"] if isinstance(out, dict) else out
    assert "Bedrock EU" in text
    # Le flag est résolu au scope de CET utilisateur (pas global-only).
    assert "user-eu-1" in [
        a for call in resolve.call_args_list for a in call.args
    ]


@pytest.mark.asyncio
async def test_coach_vision_path_routes_bedrock_when_eu_flag_on(monkeypatch):
    from app.services.rag.llm_client import LLMClient

    monkeypatch.setattr(
        LLMRouter,
        "_resolve_mode",
        AsyncMock(return_value=RouteMode.PRIMARY_BEDROCK),
    )
    monkeypatch.setattr(
        LLMRouter,
        "_invoke_bedrock",
        AsyncMock(return_value=_fake_msg("Extraction EU")),
    )
    monkeypatch.setattr(
        "anthropic.AsyncAnthropic",
        MagicMock(return_value=_forbidden_anthropic_client()),
    )

    client = LLMClient(provider="claude", api_key="sk-test")
    out = await client.generate_vision(
        image_base64="aGVsbG8=",
        media_type="image/png",
        system_prompt="extract",
        user_prompt="lis ce certificat",
        user_id="user-eu-2",
    )
    assert out == "Extraction EU"


@pytest.mark.asyncio
async def test_coach_text_path_default_off_preserves_us_behaviour(monkeypatch):
    """Flag off -> Anthropic direct via le routeur, parsing intact."""
    from app.services.rag.llm_client import LLMClient

    monkeypatch.setattr(
        LLMRouter, "_resolve_mode", AsyncMock(return_value=RouteMode.OFF)
    )
    fake_client = MagicMock()
    fake_client.messages.create = AsyncMock(
        return_value=_fake_msg("Réponse US", with_tool=True)
    )
    fake_client.close = AsyncMock()
    monkeypatch.setattr(
        "anthropic.AsyncAnthropic", MagicMock(return_value=fake_client)
    )

    client = LLMClient(provider="claude", api_key="sk-test")
    out = await client.generate(
        system_prompt="s",
        user_message="q",
        context_chunks=[],
        tools=[{"name": "save_fact"}],
        user_id="user-us",
    )
    assert isinstance(out, dict)
    assert out["text"] == "Réponse US"
    assert out["tool_calls"] == [{"name": "save_fact", "input": {"k": "v"}}]
    assert out["usage_tokens"] == 15
    fake_client.messages.create.assert_awaited()


def test_no_direct_messages_create_on_coach_surfaces():
    """Aucune surface coach n'appelle client.messages.create en direct.

    Le seul point d'entrée réseau autorisé est LLMRouter (PRIV-07). La
    branche compat de document_vision_service (tests mockés) est hors coach.
    """
    for rel in (
        "app/services/rag/llm_client.py",
        "app/api/v1/endpoints/anonymous_chat.py",
    ):
        source = (BACKEND / rel).read_text(encoding="utf-8")
        assert "client.messages.create" not in source, (
            f"{rel} : appel Anthropic direct — doit passer par LLMRouter"
        )
        assert "router.invoke" in source, (
            f"{rel} : le LLMRouter n'est pas câblé"
        )

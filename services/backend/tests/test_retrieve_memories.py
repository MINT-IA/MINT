"""
Tests for retrieve_memories — LLM-callable internal memory search tool.

Sprint S56+: Cleo-inspired dynamic memory retrieval.

Covers:
    - Tool definition has correct Anthropic schema
    - INTERNAL_TOOL_NAMES includes retrieve_memories
    - _handle_retrieve_memories finds matching lines
    - Empty memory_block returns "aucune mémoire" message
    - No match returns "pas de mémoire trouvée" message
    - max_results is respected (hard cap at 5)
    - Search is case-insensitive
    - Multiple matches appear in order of appearance (not sorted)
    - max_results defaults to 3 when not specified
    - max_results=1 returns exactly 1 line
    - Whitespace-only memory_block treated as empty
    - Topic with special characters still searched safely
    - retrieve_memories not present in flutter_tool_calls after intercept

Run: cd services/backend && python3 -m pytest tests/test_retrieve_memories.py -v
"""

from typing import Optional
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.endpoints.coach_chat import _handle_retrieve_memories
from app.main import app
from app.services.coach.coach_tools import COACH_TOOLS, INTERNAL_TOOL_NAMES


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _find_tool(name: str) -> Optional[dict]:
    """Return the tool definition with the given name, or None."""
    return next((t for t in COACH_TOOLS if t["name"] == name), None)


def _fake_user():
    """Mock authenticated user for dependency override."""

    user = MagicMock()
    user.id = "test-user-id"
    user.email = "test@mint.ch"
    return user


_MEMORY_BLOCK = """CONTEXTE CYCLE DE VIE : consolidation (45-55 ans)
SURFACES PERTINENTES : retraite, lpp_buyback, 3a
NUDGES ACTIFS : rachat_lpp (fenêtre fiscale ouverte)
PLAN EN COURS : Préparer retraite (3/10 étapes)
COULEUR RÉGIONALE : Romande — septante/nonante, understatement
SESSION PRÉCÉDENTE : Discussion sur la rente vs capital (2026-03-15)
OBJECTIF NOTÉ : Maximiser le rachat LPP avant 55 ans
"""

_VALID_BODY = {
    "message": "Je veux en savoir plus sur mon LPP.",
    "api_key": "sk-test-key-12345",
    "provider": "claude",
}

_ORCHESTRATOR_OK_RESULT = {
    "answer": "Voici ce que j'ai trouvé dans ta mémoire.",
    "sources": [],
    "disclaimers": ["Outil éducatif, ne constitue pas un conseil financier (LSFin)."],
    "tokens_used": 200,
}


# ===========================================================================
# TestRetrieveMemoriesToolDefinition — schema correctness
# ===========================================================================


class TestRetrieveMemoriesToolDefinition:
    """Validate the retrieve_memories tool definition in COACH_TOOLS."""

    def test_retrieve_memories_exists_in_coach_tools(self):
        """retrieve_memories must be present in COACH_TOOLS."""
        tool = _find_tool("retrieve_memories")
        assert tool is not None, "retrieve_memories not found in COACH_TOOLS"

    def test_retrieve_memories_has_description(self):
        """Tool description must be non-empty and mention memory/continuity."""
        tool = _find_tool("retrieve_memories")
        desc = tool["description"]
        assert len(desc) > 20
        assert any(
            kw in desc.lower()
            for kw in ["memory", "session", "past", "continuity", "mémoire"]
        )

    def test_retrieve_memories_input_schema_is_object(self):
        """input_schema.type must be 'object'."""
        tool = _find_tool("retrieve_memories")
        assert tool["input_schema"]["type"] == "object"

    def test_retrieve_memories_has_topic_property(self):
        """input_schema.properties must include 'topic' as a string."""
        tool = _find_tool("retrieve_memories")
        props = tool["input_schema"]["properties"]
        assert "topic" in props
        assert props["topic"]["type"] == "string"

    def test_retrieve_memories_has_max_results_property(self):
        """input_schema.properties must include 'max_results' as an integer."""
        tool = _find_tool("retrieve_memories")
        props = tool["input_schema"]["properties"]
        assert "max_results" in props
        assert props["max_results"]["type"] == "integer"

    def test_retrieve_memories_max_results_has_default(self):
        """max_results must declare a default value of 3."""
        tool = _find_tool("retrieve_memories")
        assert tool["input_schema"]["properties"]["max_results"]["default"] == 3

    def test_retrieve_memories_required_contains_topic(self):
        """'topic' must be in the required list."""
        tool = _find_tool("retrieve_memories")
        assert "topic" in tool["input_schema"]["required"]

    def test_retrieve_memories_max_results_not_required(self):
        """'max_results' must NOT be required (it has a default)."""
        tool = _find_tool("retrieve_memories")
        assert "max_results" not in tool["input_schema"]["required"]

    def test_retrieve_memories_in_internal_tool_names(self):
        """INTERNAL_TOOL_NAMES must include 'retrieve_memories'."""
        assert "retrieve_memories" in INTERNAL_TOOL_NAMES

    def test_internal_tool_names_is_list(self):
        """INTERNAL_TOOL_NAMES must be a list."""
        assert isinstance(INTERNAL_TOOL_NAMES, list)

    def test_retrieve_memories_description_mentions_internal(self):
        """Tool description must indicate it is handled internally/by backend."""
        tool = _find_tool("retrieve_memories")
        desc = tool["description"].lower()
        assert "internal" in desc or "backend" in desc


# ===========================================================================
# TestHandleRetrieveMemories — _handle_retrieve_memories pure function
# ===========================================================================


class TestHandleRetrieveMemories:
    """Unit tests for the _handle_retrieve_memories helper function."""

    def test_finds_matching_line(self):
        """A topic present in a memory line must be returned."""
        result = _handle_retrieve_memories(topic="lpp", memory_block=_MEMORY_BLOCK)
        assert "lpp" in result.lower()

    def test_empty_memory_block_returns_aucune_memoire(self):
        """Empty memory_block must return the 'aucune mémoire' message."""
        result = _handle_retrieve_memories(topic="retraite", memory_block="")
        assert "aucune" in result.lower() or "mémoire" in result.lower()

    def test_none_memory_block_returns_aucune_memoire(self):
        """None memory_block must return the 'aucune mémoire' message."""
        result = _handle_retrieve_memories(topic="retraite", memory_block=None)
        assert "aucune" in result.lower() or "mémoire" in result.lower()

    def test_whitespace_only_memory_block_treated_as_empty(self):
        """Whitespace-only memory_block must return the 'aucune mémoire' message."""
        result = _handle_retrieve_memories(topic="retraite", memory_block="   \n  ")
        assert "aucune" in result.lower() or "mémoire" in result.lower()

    def test_no_match_returns_pas_de_memoire(self):
        """When no line matches, must return the 'pas de mémoire trouvée' message."""
        result = _handle_retrieve_memories(topic="pilier_inexistant_xyz", memory_block=_MEMORY_BLOCK)
        assert "pas de mémoire" in result.lower() or "pas de" in result.lower()

    def test_no_match_mentions_topic_in_message(self):
        """The 'not found' message must include the searched topic."""
        topic = "sujet_absent_42"
        result = _handle_retrieve_memories(topic=topic, memory_block=_MEMORY_BLOCK)
        assert topic in result

    def test_max_results_respected(self):
        """Result must contain at most max_results lines."""
        # _MEMORY_BLOCK has multiple lines — request only 2
        result = _handle_retrieve_memories(
            topic="",  # empty matches every non-empty line
            memory_block=_MEMORY_BLOCK,
            max_results=2,
        )
        returned_lines = [line for line in result.split("\n") if line.strip()]
        assert len(returned_lines) <= 2

    def test_case_insensitive_search(self):
        """Search must be case-insensitive."""
        result_lower = _handle_retrieve_memories(topic="lpp", memory_block=_MEMORY_BLOCK)
        result_upper = _handle_retrieve_memories(topic="LPP", memory_block=_MEMORY_BLOCK)
        result_mixed = _handle_retrieve_memories(topic="Lpp", memory_block=_MEMORY_BLOCK)
        assert result_lower == result_upper == result_mixed

    def test_multiple_matches_in_order_of_appearance(self):
        """When multiple lines match, they appear in document order."""
        memory = "Ligne A: retraite\nLigne B: autre\nLigne C: retraite aussi"
        result = _handle_retrieve_memories(topic="retraite", memory_block=memory, max_results=5)
        lines = [line for line in result.split("\n") if line.strip()]
        assert lines[0].startswith("Ligne A")
        assert lines[1].startswith("Ligne C")

    def test_max_results_default_is_3(self):
        """When max_results is not provided, default is 3."""
        # Build a memory with 5 lines all matching "test"
        memory = "\n".join(f"test ligne {i}" for i in range(5))
        result = _handle_retrieve_memories(topic="test", memory_block=memory)
        returned_lines = [line for line in result.split("\n") if line.strip()]
        assert len(returned_lines) == 3

    def test_max_results_1_returns_exactly_one_line(self):
        """max_results=1 must return exactly one matching line."""
        result = _handle_retrieve_memories(
            topic="retraite", memory_block=_MEMORY_BLOCK, max_results=1
        )
        returned_lines = [line for line in result.split("\n") if line.strip()]
        assert len(returned_lines) == 1

    def test_max_results_capped_at_5(self):
        """max_results values above 5 must be capped at 5."""
        memory = "\n".join(f"item {i}" for i in range(10))
        result = _handle_retrieve_memories(topic="item", memory_block=memory, max_results=100)
        returned_lines = [line for line in result.split("\n") if line.strip()]
        assert len(returned_lines) <= 5


# ===========================================================================
# TestRetrieveMemoriesEndpointIntercept — endpoint strips internal tool
# ===========================================================================


class TestRetrieveMemoriesEndpointIntercept:
    """Verify the endpoint intercepts retrieve_memories and never forwards to Flutter."""

    @pytest.fixture(autouse=True)
    def _setup_auth(self):
        from app.core.auth import require_current_user, get_current_user
        from app.services.billing_service import ALL_FEATURES

        app.dependency_overrides[require_current_user] = _fake_user
        app.dependency_overrides[get_current_user] = _fake_user
        with patch(
            "app.api.v1.endpoints.coach_chat.recompute_entitlements",
            return_value=("premium", ALL_FEATURES),
        ):
            yield
        app.dependency_overrides.pop(require_current_user, None)
        app.dependency_overrides.pop(get_current_user, None)

    def test_retrieve_memories_not_in_flutter_tool_calls(self):
        """When LLM returns retrieve_memories, it must NOT appear in response tool_calls."""
        orchestrator_result_with_internal = {
            **_ORCHESTRATOR_OK_RESULT,
            "tool_calls": [
                {
                    "name": "retrieve_memories",
                    "input": {"topic": "lpp", "max_results": 3},
                }
            ],
        }
        mock_orch = MagicMock()
        mock_orch.query = AsyncMock(return_value=orchestrator_result_with_internal)

        body = {**_VALID_BODY, "memoryBlock": _MEMORY_BLOCK}

        with patch(
            "app.api.v1.endpoints.coach_chat._get_orchestrator",
            return_value=mock_orch,
        ), TestClient(app) as client:
            response = client.post("/api/v1/coach/chat", json=body)

        assert response.status_code == 200
        data = response.json()
        tool_calls = data.get("toolCalls") or data.get("tool_calls")
        # retrieve_memories is internal — it must not appear in the response
        if tool_calls:
            names = [tc["name"] for tc in tool_calls]
            assert "retrieve_memories" not in names

    def test_non_internal_tool_calls_still_forwarded(self):
        """Non-internal tools alongside retrieve_memories must still reach Flutter."""
        orchestrator_result_mixed = {
            **_ORCHESTRATOR_OK_RESULT,
            "tool_calls": [
                {
                    "name": "retrieve_memories",
                    "input": {"topic": "3a"},
                },
                {
                    "name": "route_to_screen",
                    "input": {
                        "intent": "tax_optimization_3a",
                        "confidence": 0.9,
                        "context_message": "Ce simulateur pourrait t'aider.",
                    },
                },
            ],
        }
        mock_orch = MagicMock()
        mock_orch.query = AsyncMock(return_value=orchestrator_result_mixed)

        body = {**_VALID_BODY, "memoryBlock": _MEMORY_BLOCK}

        with patch(
            "app.api.v1.endpoints.coach_chat._get_orchestrator",
            return_value=mock_orch,
        ), TestClient(app) as client:
            response = client.post("/api/v1/coach/chat", json=body)

        assert response.status_code == 200
        data = response.json()
        tool_calls = data.get("toolCalls") or data.get("tool_calls")
        assert tool_calls is not None
        names = [tc["name"] for tc in tool_calls]
        assert "route_to_screen" in names
        assert "retrieve_memories" not in names

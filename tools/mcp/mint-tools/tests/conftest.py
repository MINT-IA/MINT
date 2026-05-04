"""Shared pytest fixtures for Phase 30.7 MCP tools tests."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Ensure services/backend is on sys.path so `from app.services.regulatory.registry import ...`
# resolves in Wave 1 tests. Mirrors the .mcp.json PYTHONPATH injection.
# conftest.py lives at tools/mcp/mint-tools/tests/conftest.py, so parents[4] == repo root.
_REPO_ROOT = Path(__file__).resolve().parents[4]
_BACKEND = _REPO_ROOT / "services" / "backend"
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))


@pytest.fixture()
def sample_clean_fr_text() -> str:
    """Clean French text with correct accents. Used by accent tool tests."""
    return (
        "Créer un plan épargne, découvrir ses priorités, élaborer un budget réaliste."
    )


@pytest.fixture()
def sample_ascii_flat_fr_text() -> str:
    """French text with ASCII-flattened accents (14 pattern matches expected)."""
    return (
        "creer un plan, decouvrir les options, eclairage basique, securite financiere, "
        "liberer du budget, preter attention, realiser un scenario, deja fait, recu le mail, "
        "elaborer un plan, regler la facture, specialiste reconnu, gerer ses comptes, progres reguliers."
    )

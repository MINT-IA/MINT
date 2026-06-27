"""Tests for the shared regulatory tool handler (sub-phase 01.4 FLAG #1 + #2).

Verifies the lifted `app.services.regulatory.tool_handler.handle_regulatory_constant`
preserves the contract of the prior `coach_chat._handle_regulatory_constant`,
adds Sentry capture on miss, and stays importable WITHOUT pulling in
`coach_chat`'s auth stack (T-13-06 isolation).
"""

from __future__ import annotations

from unittest.mock import MagicMock, patch
from types import SimpleNamespace
from datetime import date



def test_shared_module_does_not_import_coach_chat_auth_stack():
    """Static assertion : the shared module's source MUST NOT import coach_chat.

    Sub-phase 01.4 panel FLAG #1 : T-13-06 isolation. The anonymous coach
    endpoint must be able to execute the regulatory tool without dragging
    in `require_current_user`, `billing_service`, `ConsentManager`, etc.

    NOTE — earlier iteration of this test popped `coach_chat` from
    sys.modules to verify isolation dynamically. That polluted test state
    for downstream tests in `test_retrieve_memories.py` (their auth
    `dependency_overrides` keyed on the original callable identity, which
    a re-import invalidates → 403 instead of 200). Static source check is
    safer and gives the same regression guard.
    """
    from pathlib import Path

    src_path = (
        Path(__file__).parent.parent  # tests -> services/backend
        / "app" / "services" / "regulatory" / "tool_handler.py"
    )
    src = src_path.read_text(encoding="utf-8")

    forbidden = [
        "from app.api.v1.endpoints.coach_chat",
        "import app.api.v1.endpoints.coach_chat",
        "from app.services.billing_service",
        "from app.core.auth import",
        "from app.services.consent",
    ]
    found = [needle for needle in forbidden if needle in src]
    assert not found, (
        "regulatory.tool_handler must stay isolated from the authenticated "
        f"coach stack (T-13-06). Forbidden imports detected : {found}"
    )


def test_handle_missing_key_returns_error_string():
    from app.services.regulatory.tool_handler import handle_regulatory_constant

    result = handle_regulatory_constant({})
    # CLAUDE.md TOP #2 — accents mandatory.
    assert "clé manquante" in result


def test_handle_returns_formatted_param_on_hit():
    from app.services.regulatory.tool_handler import handle_regulatory_constant

    fake_param = SimpleNamespace(
        key="pillar3a.max_with_lpp",
        value=7258.0,
        unit="CHF",
        source_title="OPP3 art. 7 al. 1",
        description="Plafond annuel 3a pour salaries.",
        effective_from=date(2025, 1, 1),
    )

    with patch(
        "app.services.regulatory.registry.RegulatoryRegistry"
    ) as MockRegistry:
        inst = MagicMock()
        inst.get.return_value = fake_param
        MockRegistry.instance.return_value = inst

        result = handle_regulatory_constant({"key": "pillar3a.max_with_lpp"})

    assert "pillar3a.max_with_lpp" in result
    assert "7258" in result
    assert "OPP3 art. 7 al. 1" in result
    assert "2025-01-01" in result


def test_handle_2026_3a_lpp_result_includes_closed_citation_hint():
    """JOS-004: tool result must tell the narrator which closed cite key to use."""
    from app.services.coach.citation_registry import CITATION_REGISTRY
    from app.services.regulatory.tool_handler import handle_regulatory_constant

    assert "r3a_plafond_salarie_2026" in CITATION_REGISTRY

    result = handle_regulatory_constant({"key": "pillar3a.historical_limits.2026"})

    assert "{{cite:r3a_plafond_salarie_2026}}" in result
    assert "Formulation citable" in result
    assert "pillar3a.historical_limits.2026 = 7258.0 CHF" in result
    assert "7'258 CHF" in result
    assert "OPP3 art. 7" in result


def test_handle_miss_emits_sentry_breadcrumb_with_suggestions():
    """Code-reviewer FLAG #2 — registry miss must not be silent."""
    from app.services.regulatory.tool_handler import handle_regulatory_constant

    with patch(
        "app.services.regulatory.registry.RegulatoryRegistry"
    ) as MockRegistry, patch(
        "app.services.regulatory.tool_handler.sentry_sdk"
    ) as mock_sentry:
        inst = MagicMock()
        inst.get.return_value = None
        inst.keys.return_value = [
            "pillar3a.max_with_lpp",
            "pillar3a.max_without_lpp",
            "pillar3a.early_withdrawal_min_age",
        ]
        MockRegistry.instance.return_value = inst

        result = handle_regulatory_constant({"key": "pillar3a.maxxxx"})

    # User-facing message includes suggestions. CLAUDE.md TOP #2 — accents mandatory.
    assert "non trouvée" in result
    assert "pillar3a.max_with_lpp" in result

    # Sentry breadcrumb fired with the miss data.
    assert mock_sentry.add_breadcrumb.called
    call_kwargs = mock_sentry.add_breadcrumb.call_args.kwargs
    assert call_kwargs.get("category") == "coach.tool.regulatory_constant.miss"
    assert call_kwargs.get("level") == "warning"
    data = call_kwargs.get("data", {})
    assert data.get("key") == "pillar3a.maxxxx"
    assert "pillar3a.max_with_lpp" in (data.get("suggestions") or [])


def test_handle_cantonal_capital_tax_auto_builds_key():
    """If canton is provided separately, the handler builds 'capital_tax.cantonal.<X>'."""
    from app.services.regulatory.tool_handler import handle_regulatory_constant

    fake_param = SimpleNamespace(
        key="capital_tax.cantonal.VS",
        value=0.0015,
        unit="rate",
        source_title="VS LIPC",
        description="Taux cantonal Valais",
        effective_from=date(2024, 1, 1),
    )

    with patch(
        "app.services.regulatory.registry.RegulatoryRegistry"
    ) as MockRegistry:
        inst = MagicMock()
        # First call (canton-prefixed) hits.
        inst.get.side_effect = lambda k, jurisdiction=None: (
            fake_param if k == "capital_tax.cantonal.VS" else None
        )
        MockRegistry.instance.return_value = inst

        result = handle_regulatory_constant(
            {"key": "capital_tax.cantonal", "canton": "VS"}
        )

    assert "capital_tax.cantonal.VS" in result
    assert "0.0015" in result

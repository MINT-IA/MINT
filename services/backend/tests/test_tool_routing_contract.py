"""
Wave E-PRIME regression test (2026-04-18) — tool routing contract.

Enforces that every tool declared in COACH_TOOLS is routed to exactly one
destination: either backend-internal (INTERNAL_TOOL_NAMES) or Flutter-rendered
(widget_renderer.dart switch/case).

Context: audit façade systémique Panel B identified that `save_fact` and
`suggest_actions` were declared with MANDATORY descriptions to the LLM, had
handlers in coach_chat.py, but were routed to external_calls because they
were missing from INTERNAL_TOOL_NAMES. Flutter widget_renderer.dart had no
case for them → `default: return null` → silent drop. Net effect: two shipped
features (Wave A PRIV-07 save_fact + Gate 0 #6 suggest_actions dynamic chips)
were dead code with green tests.

This test would have caught both regressions. It reads the dart file as
source of truth for Flutter handlers rather than duplicating the enumeration.

Run: cd services/backend && python3 -m pytest tests/test_tool_routing_contract.py -v
"""

from pathlib import Path
import re

from app.services.coach.coach_tools import COACH_TOOLS, INTERNAL_TOOL_NAMES


# Path to the Flutter widget_renderer.dart from repo root.
# Test file is at services/backend/tests/, widget_renderer.dart is at
# apps/mobile/lib/widgets/coach/widget_renderer.dart. Four parents up from
# the test file lands on the repo root.
_REPO_ROOT = Path(__file__).resolve().parents[3]
_WIDGET_RENDERER_PATH = (
    _REPO_ROOT / "apps" / "mobile" / "lib" / "widgets" / "coach" / "widget_renderer.dart"
)


def _extract_flutter_tool_cases() -> set[str]:
    """Parse widget_renderer.dart switch statement for case 'tool_name': entries."""
    assert _WIDGET_RENDERER_PATH.exists(), (
        f"widget_renderer.dart not found at {_WIDGET_RENDERER_PATH}. "
        f"If the file moved, update _WIDGET_RENDERER_PATH in this test."
    )
    source = _WIDGET_RENDERER_PATH.read_text(encoding="utf-8")
    # Match: case 'tool_name': or case "tool_name":
    pattern = re.compile(r"""case\s+['"]([a-z_]+)['"]\s*:""")
    return set(pattern.findall(source))


def test_every_coach_tool_is_routed_exactly_once() -> None:
    """Every tool in COACH_TOOLS must be routed via INTERNAL_TOOL_NAMES XOR widget_renderer."""
    tool_names = {t["name"] for t in COACH_TOOLS}
    internal = set(INTERNAL_TOOL_NAMES)
    flutter = _extract_flutter_tool_cases()

    unrouted = tool_names - internal - flutter
    double_routed = tool_names & internal & flutter

    assert not unrouted, (
        f"Tools declared in COACH_TOOLS but neither in INTERNAL_TOOL_NAMES nor "
        f"widget_renderer.dart: {sorted(unrouted)}. "
        f"The LLM will emit these tools → dispatcher will route them to "
        f"external_calls → Flutter widget_renderer default: null → silent drop. "
        f"Fix: add to INTERNAL_TOOL_NAMES (backend handler exists) OR add a "
        f"case to widget_renderer.dart (Flutter render). Never both, never neither."
    )
    assert not double_routed, (
        f"Tools routed to both INTERNAL_TOOL_NAMES and widget_renderer: "
        f"{sorted(double_routed)}. Double-routing is ambiguous — the backend "
        f"dispatcher prefers INTERNAL, the Flutter case is unreachable."
    )


def test_save_fact_is_internal() -> None:
    """Regression: save_fact MUST remain in INTERNAL_TOOL_NAMES (Wave E-PRIME fix)."""
    assert "save_fact" in INTERNAL_TOOL_NAMES, (
        "save_fact must be in INTERNAL_TOOL_NAMES. "
        "Missing = Wave A PRIV-07 redaction + 35-key whitelist persistence both "
        "dead code. See Panel B P0-1."
    )


def test_suggest_actions_is_internal() -> None:
    """Regression: suggest_actions MUST remain in INTERNAL_TOOL_NAMES (Wave E-PRIME fix)."""
    assert "suggest_actions" in INTERNAL_TOOL_NAMES, (
        "suggest_actions must be in INTERNAL_TOOL_NAMES. "
        "Missing = Gate 0 #6 dynamic chips dead. See Panel B P0-2."
    )


def test_partner_estimate_tools_are_flutter_only() -> None:
    """save_partner_estimate / update_partner_estimate are Flutter-handled (SecureStorage)."""
    flutter_cases = _extract_flutter_tool_cases()
    for name in ("save_partner_estimate", "update_partner_estimate"):
        assert name not in INTERNAL_TOOL_NAMES, (
            f"{name} must NOT be in INTERNAL_TOOL_NAMES — it is Flutter-intercepted "
            f"for SecureStorage (COUP-01/COUP-04)."
        )
        assert name in flutter_cases, (
            f"{name} must have a case in widget_renderer.dart."
        )


def test_save_insight_reads_type_param() -> None:
    """Regression Wave E-PRIME: coach_chat.py handler must read 'type' from tool_input.

    The schema at coach_tools.py:468 exposes the param name `type` (not `insight_type`).
    Anthropic SDK serializes tool_use params under the exact schema name. A handler
    that reads `insight_type` with a `"fact"` fallback silently downgrades every
    Wave A A0 event save to a "fact" classification.
    """
    coach_chat_path = (
        _REPO_ROOT
        / "services"
        / "backend"
        / "app"
        / "api"
        / "v1"
        / "endpoints"
        / "coach_chat.py"
    )
    source = coach_chat_path.read_text(encoding="utf-8")
    # Find the save_insight handler block
    save_insight_idx = source.find('if name == "save_insight":')
    assert save_insight_idx >= 0, "save_insight handler not found in coach_chat.py"
    # Examine the next 1500 chars (handler preamble + doc comments)
    preamble = source[save_insight_idx : save_insight_idx + 1500]
    # Must read `type` (from schema). Either as first lookup or via `or` chain.
    assert 'tool_input.get("type"' in preamble, (
        "save_insight handler must read tool_input.get(\"type\") — the schema "
        "exposes `type`, not `insight_type`. Reading only `insight_type` "
        "downgrades every Wave A A0 event to a 'fact'. See Panel B bug."
    )

"""Shared handler for the `get_regulatory_constant` coach tool.

Sub-phase 01.4 panel-review (code-reviewer FLAG #1) lifted this function
from `app/api/v1/endpoints/coach_chat.py` to a dedicated module so the
anonymous coach path can invoke it WITHOUT importing the authenticated
endpoint (which carries `require_current_user`, billing, ConsentManager,
claude_coach_service, etc. — violating T-13-06 anonymous isolation).

Single source of truth for both anonymous and authenticated paths.
"""

from __future__ import annotations

import logging
from typing import Any

try:
    import sentry_sdk  # type: ignore
except Exception:  # pragma: no cover — fail-open if SDK absent
    sentry_sdk = None  # type: ignore

logger = logging.getLogger(__name__)


def handle_regulatory_constant(tool_input: dict[str, Any]) -> str:
    """Look up a Swiss financial regulatory constant from the registry.

    Internal coach tool — results are injected into the LLM context so the
    coach can cite exact legal values in its responses.

    Returns a multi-line string with `key = value unit` plus source title,
    description, and effective_from date. On miss / error, returns a
    short error string AND emits a Sentry capture for observability
    (sub-phase 01.4 code-reviewer FLAG #2 — registry miss must not be
    silent ; the « 25 fois » regression class is precisely the « LLM
    falls back to training data when registry returns nothing » failure
    mode that memory `project_coach_forced_tool_invocation` flags).

    Parameters
    ----------
    tool_input : dict
        Must carry `key` (dotted registry path) and optionally `canton`
        (cantonal-tax fallback).
    """
    from app.services.regulatory.registry import RegulatoryRegistry

    key = (tool_input or {}).get("key", "")
    canton = (tool_input or {}).get("canton", "")

    if not key:
        # Sentry breadcrumb so we can detect LLM emitting tool_use with no
        # key (= an LLM bug, not a user / registry bug).
        if sentry_sdk is not None:
            try:  # pragma: no cover — telemetry-only
                sentry_sdk.add_breadcrumb(
                    category="coach.tool.regulatory_constant.bad_input",
                    message="missing key",
                    level="warning",
                    data={"canton": canton or ""},
                )
            except Exception:
                pass
        return "Erreur : clé manquante. Fournis un key comme 'pillar3a.max_with_lpp'."

    try:
        registry = RegulatoryRegistry.instance()
    except Exception as exc:  # pragma: no cover — registry init failure is infra-level
        logger.exception("regulatory_constant: registry init failed")
        if sentry_sdk is not None:
            try:
                sentry_sdk.capture_exception(exc)
            except Exception:
                pass
        return "Erreur : registre regulatory temporairement indisponible."

    # For cantonal capital tax, auto-build the key if canton is provided separately.
    jurisdiction = "CH"
    if canton:
        canton_upper = canton.upper()
        if not key.endswith(f".{canton_upper}"):
            cantonal_key = f"capital_tax.cantonal.{canton_upper}"
            try:
                param = registry.get(cantonal_key, jurisdiction=canton_upper)
            except Exception as exc:  # pragma: no cover — registry .get robustness
                logger.warning("regulatory_constant: cantonal lookup raised: %s", exc)
                param = None
            if param:
                return (
                    f"{param.key} = {param.value} {param.unit}\n"
                    f"Source : {param.source_title}\n"
                    f"Description : {param.description}\n"
                    f"En vigueur depuis : {param.effective_from.isoformat()}"
                )
        jurisdiction = canton_upper

    try:
        param = registry.get(key, jurisdiction=jurisdiction)
    except Exception as exc:  # pragma: no cover
        logger.warning("regulatory_constant: lookup raised for key=%s: %s", key, exc)
        param = None

    if param is None and jurisdiction != "CH":
        try:
            param = registry.get(key, jurisdiction="CH")
        except Exception:  # pragma: no cover
            param = None

    if param is None:
        # Code-reviewer FLAG #2 — capture miss to Sentry with suggestions so
        # ops can detect « LLM emits hallucinated key » vs « registry gap ».
        try:
            available = registry.keys()
        except Exception:  # pragma: no cover
            available = []
        suggestions = [k for k in available if key.split(".")[0] in k][:5]
        if sentry_sdk is not None:
            try:
                sentry_sdk.add_breadcrumb(
                    category="coach.tool.regulatory_constant.miss",
                    message=f"key not found: {key}",
                    level="warning",
                    data={
                        "key": key,
                        "jurisdiction": jurisdiction,
                        "suggestions": suggestions[:5],
                    },
                )
            except Exception:
                pass
        logger.info(
            "regulatory_constant miss: key=%s jurisdiction=%s suggestions=%s",
            key, jurisdiction, suggestions,
        )
        msg = f"Constante '{key}' non trouvée."
        if suggestions:
            msg += f" Suggestions : {', '.join(suggestions)}"
        return msg

    return (
        f"{param.key} = {param.value} {param.unit}\n"
        f"Source : {param.source_title}\n"
        f"Description : {param.description}\n"
        f"En vigueur depuis : {param.effective_from.isoformat()}"
    )

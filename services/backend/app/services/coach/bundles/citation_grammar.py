"""CitationGrammarBundle — flag-conditional grammar bundle (Phase 94.1).

Wraps `app.services.coach.citation_grammar.CITATION_GRAMMAR_FRAGMENT` as
a Pydantic v2 BundleBase so the bundle compiler can include it in the
narrator system prompt when `settings.COACH_CITATION_GATE_ENABLED=True`.

The bundle is conceptually always-on but registered per-call inside
`compile_bundles` rather than added to the `_ALWAYS_ON` constant. Two
reasons :

1. The existing `tests/bundles/test_bundle_compiler.py::
   test_empty_intent_emits_always_on_only` pins the always-on list to
   exactly `["compliance-narrator", "life-event-router"]`. Adding a
   third entry to the constant would break the assertion.

2. The grammar bundle is only useful when the citation gate is actually
   running (it teaches a syntax that only the gate enforces). If the
   gate flag is OFF, the bundle is dead weight ~1k tokens.

Per CONTEXT D-20 — `allowed_tools=[]` (the bundle is doctrine, no tools)
and `citation_allowlist=[]` (the bundle TEACHES the grammar ; it does
not enumerate citations for itself — the registry is the source of truth).

Per CLAUDE.md TOP rule #1 — fragment text scanned by
`tools/checks/banned_terms_python.py` (no LSFin banned terms in the
narrator-facing string).
"""
from __future__ import annotations

from typing import Literal

from app.services.coach.bundles._base import BundleBase
from app.services.coach.citation_grammar import CITATION_GRAMMAR_FRAGMENT


class CitationGrammarBundle(BundleBase):
    """Flag-conditional grammar bundle (Phase 94.1 Wave 4).

    Activated by `compile_bundles` when
    `settings.COACH_CITATION_GATE_ENABLED=True`. Inserted AFTER the two
    legacy always-on bundles (`compliance-narrator`, `life-event-router`)
    so the LSFin doctrine still leads the prompt.
    """

    name: Literal["citation-grammar"] = "citation-grammar"
    prompt_fragment: str = CITATION_GRAMMAR_FRAGMENT
    allowed_tools: list[str] = []
    citation_allowlist: list[str] = []


__all__ = ["CitationGrammarBundle"]

"""Compile-time skill-bundle composer.

Phase 93.5 Plan 02 (Wave 1). Reads detected intents (`set[str]` from
`_classify_user_intent` per CONTEXT D-01 supersession), composes a single
narrator prompt + tool allowlist + citation allowlist by unioning the
activated bundles' fragments per CONTEXT D-09 / D-10 / D-11 / D-12 / D-13
/ D-14.

Per CONTEXT D-04 — the static `_INTENT_BUNDLES` dict IS the resolver. No
ML, no LLM extra hop — Karpathy #2 Simplicity First.

Per RESEARCH §3.5 — single entrypoint `compile_bundles`.

Per H4 fix (revision iter1 2026-05-10) — post-assembly undeclared-slot
guard raises `ValueError` to prevent runtime `KeyError` in the narrator
call to `base_template.format(...)`.

Per T-93.5-06 — `_DROP_PRIORITY ∩ _ALWAYS_ON == set()` enforced at module
import via `assert` (defense-in-depth in addition to the test in
`tests/bundles/test_bundle_compiler.py`).
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable, Optional

from app.core.config import settings
from app.services.coach.bundles import (
    BundleBase,
    CitationGrammarBundle,
    ComplianceNarratorBundle,
    IndependentTaxBundle,
    LifeEventRouterBundle,
    LppProjectorBundle,
    MortgageStressorBundle,
    Pillar3aOptimizerBundle,
    SuccessionDivorceBundle,
    TaxExplainerBundle,
)
from app.services.coach.coach_models import CoachContext


# ---------------------------------------------------------------------------
# CONTEXT D-02 + D-CE-03 — static intent → bundle mapping (frozen at module load).
#
# Plan 08 (W2 bundles, D-CE-03 Override #2) extends the 7-bundle Wave 0/2
# state to 9 bundles by adding IndependentTaxBundle (wired in `taxes` +
# `career`) and SuccessionDivorceBundle (wired in `family`).
# ---------------------------------------------------------------------------
_INTENT_BUNDLES: dict[str, list[type[BundleBase]]] = {
    "retirement": [Pillar3aOptimizerBundle, LppProjectorBundle],
    "taxes":      [TaxExplainerBundle, Pillar3aOptimizerBundle, IndependentTaxBundle],
    "housing":    [MortgageStressorBundle, TaxExplainerBundle],
    "debt":       [MortgageStressorBundle, ComplianceNarratorBundle],
    "family":     [LifeEventRouterBundle, ComplianceNarratorBundle, SuccessionDivorceBundle],
    "career":     [LppProjectorBundle, LifeEventRouterBundle, IndependentTaxBundle],
}


# CONTEXT D-09 — always-on bundles (every request, regardless of intents).
# Order matters : `compliance-narrator` first so its LSFin doctrine is the
# top of the prompt.
_ALWAYS_ON: list[type[BundleBase]] = [
    ComplianceNarratorBundle,
    LifeEventRouterBundle,
]


# CONTEXT D-13 + D-CE-03 — drop priority right-to-left when over budget.
#
# Plan 08 (D-CE-03 Override #2) prepends the 2 new bundles so they drop
# FIRST under token-budget pressure. The 7 Wave 0/2 bundles keep their
# historical drop order to preserve regression-test signal on D-13
# behavior (test_drop_order_is_right_to_left).
_DROP_PRIORITY: list[type[BundleBase]] = [
    IndependentTaxBundle,        # Plan 08 — drop first
    SuccessionDivorceBundle,     # Plan 08 — drop second
    MortgageStressorBundle,
    TaxExplainerBundle,
    LppProjectorBundle,
    Pillar3aOptimizerBundle,
]


# T-93.5-06 — module-import-time defense-in-depth. If a future refactor
# accidentally lists `ComplianceNarratorBundle` or `LifeEventRouterBundle`
# in `_DROP_PRIORITY`, the import itself fails immediately.
assert set(_DROP_PRIORITY).isdisjoint(set(_ALWAYS_ON)), (
    "_DROP_PRIORITY must be disjoint from _ALWAYS_ON (CONTEXT D-09)"
)


# CONTEXT D-13 — final prompt size budget (in tokens, 4-char heuristic).
_TOKEN_BUDGET: int = 8_000


# CONTEXT D-11 — fragment join separator.
_FRAGMENT_SEPARATOR: str = "\n\n---\n\n"


# CONTEXT D-01 supersession — heuristic intent value space (same 6-enum as
# `ExtractorOutput.intents`). Matches `_INTENT_BUNDLES.keys()` ; declared
# explicitly so the constraint is testable and visible at the top.
_ALLOWED_INTENTS: frozenset[str] = frozenset(_INTENT_BUNDLES.keys())


# H4 — canonical 7-slot set provided by `_build_prompt` at
# `claude_coach_service.py:789`. Any 8th slot in a bundle fragment would
# raise `KeyError` at narrator call time — `compile_bundles` rejects it
# upfront with `ValueError`.
_DECLARED_SLOTS: frozenset[str] = frozenset({
    "banned_terms",
    "regional_identity",
    "lifecycle_awareness",
    "plan_awareness",
    "check_in_protocol",
    "safe_mode_protocol",
    "routing_rules",
})


# Single-brace `{slot}` pattern with negative lookbehind/lookahead so
# `{{cite:<key>}}` (Phase 94 placeholder, double-brace) is NOT matched.
_SINGLE_BRACE_SLOT = re.compile(r"(?<!\{)\{(\w+)\}(?!\})")


@dataclass(frozen=True)
class CompiledBundle:
    """Output of `compile_bundles` consumed by the narrator path.

    `prompt`              — concatenated bundle fragments (D-11).
    `allowed_tools`       — sorted union (D-12), used to filter the
                            narrator's tool registry (coach_chat.py:3136).
    `citation_allowlist`  — sorted union ; consumed by Phase 94's
                            citation-gate when the flag is on.
    `activated_bundles`   — kebab-case bundle names (telemetry).
    `estimated_tokens`    — 4-char heuristic ; `count_tokens` API only used
                            in Wave 3 with a `sha256` cache.
    `dropped_bundles`     — class names (`__name__`) of bundles dropped
                            for budget (diagnostics + drop-order test).
    """
    prompt: str
    allowed_tools: list[str]
    citation_allowlist: list[str]
    activated_bundles: list[str]
    estimated_tokens: int
    dropped_bundles: list[str]


def _estimate_tokens(s: str) -> int:
    """4-char-per-token heuristic per RESEARCH §Pitfall 2 + T-93.5-10.

    Cheap, deterministic, in-process. Wave 3 (Plan 93.5-04) replaces with
    Anthropic's `count_tokens` API behind a `sha256(prompt)` cache.
    """
    return len(s) // 4


def _assemble(bundles: list[BundleBase]) -> tuple[str, int]:
    """Join fragments by `_FRAGMENT_SEPARATOR` and estimate tokens."""
    fragments = [b.prompt_fragment for b in bundles]
    prompt_str = _FRAGMENT_SEPARATOR.join(fragments)
    return prompt_str, _estimate_tokens(prompt_str)


def compile_bundles(
    intents: Iterable[str],
    ctx: Optional[CoachContext] = None,
    language: str = "fr",
) -> CompiledBundle:
    """Compose the 6 skill bundles into a single narrator prompt.

    Args:
      intents: 6-enum heuristic intent set from `_classify_user_intent`
        (CONTEXT D-01 supersession). Unknown values silently dropped.
      ctx: optional `CoachContext` (currently unused by the compiler — the
        7 slots are interpolated by `_build_prompt` downstream — but
        accepted for forward-compat with per-canton bundle variants).
      language: ISO 639-1 code (currently unused — language switch is
        handled by `_build_prompt`'s appended block).

    Returns:
      `CompiledBundle` (frozen dataclass).

    Raises:
      ValueError: H4 — assembled prompt contains a single-brace `{slot}`
        not in the canonical 7-set. Defense-in-depth versus the per-bundle
        invariant test in Plan 93.5-01 Task 2.
    """
    # Step 1 — defensively normalize intents (silently drop unknowns ;
    # the heuristic path can't produce them but a future caller might).
    normalized = {i for i in intents if i in _ALLOWED_INTENTS}

    # Step 2 — collect bundle classes (always-on first, intent-driven
    # deduped, sorted intents for determinism).
    bundle_classes: list[type[BundleBase]] = list(_ALWAYS_ON)
    seen: set[type[BundleBase]] = set(_ALWAYS_ON)
    for intent in sorted(normalized):
        for cls in _INTENT_BUNDLES.get(intent, []):
            if cls not in seen:
                bundle_classes.append(cls)
                seen.add(cls)

    # Step 2b — Phase 94.1 Wave 4 : flag-conditional citation-grammar bundle.
    # When `settings.COACH_CITATION_GATE_ENABLED=True`, append
    # `CitationGrammarBundle` to the bundle list AFTER the legacy always-on
    # pair AND any intent-driven bundles. The grammar fragment teaches the
    # narrator the closed-world `{{cite:<key>}}` placeholder syntax + the
    # 18-key vocabulary from `citation_registry.CITATION_REGISTRY`. When
    # the flag is OFF, this branch is a no-op (preserves the activated_bundles
    # invariant pinned by `tests/bundles/test_bundle_compiler.py::
    # test_empty_intent_emits_always_on_only` and friends).
    #
    # The grammar bundle is conceptually always-on per Phase 94.1 architecture
    # but registered HERE (not in the `_ALWAYS_ON` constant) to keep the
    # legacy invariant intact.
    if settings.COACH_CITATION_GATE_ENABLED and CitationGrammarBundle not in seen:
        bundle_classes.append(CitationGrammarBundle)
        seen.add(CitationGrammarBundle)

    # Step 3 — instantiate. Bundles are frozen Pydantic v2 ; instantiation
    # is cheap and side-effect-free.
    activated: list[BundleBase] = [cls() for cls in bundle_classes]

    # Step 4 — assemble + drop right-to-left if over budget.
    # ALWAYS-ON NEVER DROPPED (T-93.5-06).
    prompt, est_tokens = _assemble(activated)
    dropped: list[str] = []
    while est_tokens > _TOKEN_BUDGET:
        droppable = [b for b in activated if type(b) in _DROP_PRIORITY]
        if not droppable:
            # Only always-on left ; accept overflow (D-09 supersedes D-13).
            break
        # Find the first instance whose class appears earliest in
        # `_DROP_PRIORITY` (right-to-left order).
        target: Optional[BundleBase] = None
        for drop_cls in _DROP_PRIORITY:
            target = next(
                (b for b in activated if isinstance(b, drop_cls)),
                None,
            )
            if target is not None:
                break
        if target is None:
            # Defensive : `droppable` was non-empty but no `_DROP_PRIORITY`
            # class matched — should not happen.
            break
        activated.remove(target)
        dropped.append(type(target).__name__)
        prompt, est_tokens = _assemble(activated)

    # Step 5 — H4 undeclared-slot guard. If a bundle ships an 8th slot,
    # raise ValueError BEFORE the narrator's `_build_prompt.format(...)`
    # would crash with `KeyError`.
    slots_found = set(_SINGLE_BRACE_SLOT.findall(prompt))
    undeclared = slots_found - _DECLARED_SLOTS
    if undeclared:
        raise ValueError(
            f"compile_bundles: undeclared slot(s) {sorted(undeclared)!r} "
            f"found in assembled prompt. "
            f"Allowed slots : {sorted(_DECLARED_SLOTS)!r}. "
            f"Activated bundles : {[b.name for b in activated]!r}."
        )

    # Step 6 — D-12 dedup tools + citations, sorted for deterministic output.
    allowed_tools = sorted({t for b in activated for t in b.allowed_tools})
    citation_allowlist = sorted(
        {c for b in activated for c in b.citation_allowlist}
    )

    return CompiledBundle(
        prompt=prompt,
        allowed_tools=allowed_tools,
        citation_allowlist=citation_allowlist,
        activated_bundles=[b.name for b in activated],
        estimated_tokens=est_tokens,
        dropped_bundles=dropped,
    )


__all__ = ["CompiledBundle", "compile_bundles"]

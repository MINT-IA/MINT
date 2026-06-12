"""Deterministic definitional-inversion claim-checker (WS-B/E).

Phase: mint-grounded-coach-m1 / Plan 04 (audit 04 §3.b.3 — « validateur
structurel post-génération, déterministe, pas LLM-as-judge »).

This is the semantic analogue of the numeric hallucination detector. The
numeric gates inspect CHF/%/durations against the constants store; this checker
inspects a definitional ASSERTION against the closed world of CONCEPT_REGISTRY.
It is the direct fix for the « un rachat, c'est retirer ton capital » blind spot:
a definitional inversion carries no number and no banned term, so it traverses
every numeric/lexical gate intact (audit 04 §P0).

How it works (closed-world, deterministic — CLAUDE.md §9):
    For each concept page in CONCEPT_REGISTRY:
      1. Definiendum gate — the concept must actually be the subject of the
         sentence: one of its definiendum surface forms (« rachat », « pilier
         3a », « taux de conversion »…) must appear in the text. This prevents
         a marker phrase from firing on an unrelated concept.
      2. Inversion marker — one of the page's multi-word `not_this_fr` markers
         (« sortir ton capital », « n'est pas imposée comme un revenu »…) must
         appear. These markers are the inverted-meaning signals; by construction
         (Plan 01 fixtures) they never appear in any canonical definition.
    Both conditions met → a ClaimViolation for that concept.

No regex NLP, no LLM call: pure case-insensitive substring containment over a
curated lexicon. Runs over all fixtures in well under 2s.
"""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass

from app.services.coach.concept_registry import CONCEPT_REGISTRY


@dataclass(frozen=True)
class ClaimViolation:
    """One detected definitional inversion.

    Args:
        concept_key: the registry concept whose definition was inverted.
        matched_inversion: the `not_this_fr` marker that fired.
        snippet: a short window of the text around the marker, for the log.
    """

    concept_key: str
    matched_inversion: str
    snippet: str


# Definiendum surface forms per concept — the lexical gate that confirms the
# concept is the SUBJECT of the assertion (closed-world over CONCEPT_REGISTRY).
# Curated so the canonical definition never trips and every Plan 01 inversion
# resolves to its own concept. Single short tokens (« 3a ») are intentionally
# avoided where a multi-word form (« pilier 3a ») disambiguates.
_DEFINIENDUM_LEXICON: dict[str, tuple[str, ...]] = {
    "rachat_lpp": ("rachat lpp", "rachat"),
    "epl": ("epl", "encouragement à la propriété"),
    "rente_imposition": ("rente",),
    "capital_imposition": ("capital de prévoyance", "capital du 2e pilier"),
    "pilier_3a": ("pilier 3a",),
    "pilier_3b": ("pilier 3b",),
    "taux_conversion": ("taux de conversion",),
    "lacunes_prevoyance": ("lacune de prévoyance", "lacune"),
    "coordination_lpp": ("déduction de coordination", "coordination"),
    "libre_passage": ("libre passage",),
    "splitting_avs": ("splitting",),
    "bonifications_vieillesse": ("bonifications de vieillesse", "bonifications"),
    "frontalier": ("frontalier",),
    "fatca": ("fatca",),
    "epl_blocage_3ans": ("blocage", "bloqué"),
    "avs_age_femmes": ("âge de référence avs", "rente avs", "femmes"),
    "rachat_deductibilite": ("rachat lpp", "rachat"),
    "pilier_3a_retrait": ("pilier 3a",),
}


def _normalize(text: str) -> str:
    """NFKC-normalize + lowercase (defends against homoglyph bypass, mirrors
    ComplianceGuard.validate pre-processing)."""
    return unicodedata.normalize("NFKC", text).lower()


def _snippet(text_low: str, marker_low: str, original: str) -> str:
    """Return a short window of the ORIGINAL text around the marker."""
    idx = text_low.find(marker_low)
    if idx < 0:
        return original[:80]
    start = max(0, idx - 20)
    end = min(len(original), idx + len(marker_low) + 20)
    return original[start:end].strip()


def _inversion_markers(page) -> list[str]:
    """The page's usable inversion markers: multi-word `not_this_fr` phrases.

    Bare single-word markers (« retirer », « sortir ») are too generic to be a
    safe inversion signal on their own — they appear in legitimate canonical
    prose (e.g. EPL's « retrait anticipé »). Only multi-word marker phrases are
    precise enough to fire as a closed-world inversion signal.
    """
    return [m for m in page.not_this_fr if len(m.split()) >= 2]


def check_claims(text: str) -> list[ClaimViolation]:
    """Detect definitional inversions of CONCEPT_REGISTRY concepts in ``text``.

    Args:
        text: candidate coach output (a definitional assertion or free prose).

    Returns:
        A list of ClaimViolation (empty if no inversion is detected). One entry
        per concept whose definiendum is the subject AND whose inverted-meaning
        marker is present.
    """
    if not text or not text.strip():
        return []

    low = _normalize(text)
    violations: list[ClaimViolation] = []

    for concept_key, page in CONCEPT_REGISTRY.items():
        lexicon = _DEFINIENDUM_LEXICON.get(concept_key, ())
        # Definiendum gate: the concept must be the subject of the assertion.
        if not any(form in low for form in lexicon):
            continue
        # Inversion marker: an inverted-meaning phrase must be present.
        for marker in _inversion_markers(page):
            marker_low = _normalize(marker)
            if marker_low in low:
                violations.append(
                    ClaimViolation(
                        concept_key=concept_key,
                        matched_inversion=marker,
                        snippet=_snippet(low, marker_low, text),
                    )
                )
                break  # one violation per concept is enough to block

    return violations


__all__ = ["ClaimViolation", "check_claims"]

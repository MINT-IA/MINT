"""Phase 94.1 Wave 4 — narrator citation-grammar fragment.

Phase 94.2 / Phase 97 W7 iter#11 (P001 H1) — intent-scoped variant
exposed as `build_intent_scoped_citation_grammar(intents)` that returns
only the registry keys relevant to the classified intent set, reducing
the 18-bullet noise floor that diluted narrator attention in Phase 94.1
(Sonnet 20% / Haiku 20% gate-correct vs 95% / 90% targets, root-cause H1
in `.planning/phases/94.1-.../94.1-EVAL-DELTA.md`).

Single source of truth for the FR-language doctrine that teaches the
narrator the closed-world `{{cite:<key>}}` placeholder grammar plus the
18-key vocabulary from `citation_registry.CITATION_REGISTRY`.

Why this module exists (per Phase 94 Wave 2 root-cause analysis at
`.planning/phases/94-mvp-citation-gate/94-03-EVAL-RESULTS.md` lines
90-106) : the narrator's system prompt did NOT teach the placeholder
syntax, so it emitted naked digits, the gate (correctly per closed-world
D-02..D-13) rejected, and the retry-once flow collapsed to fallback at
60-80% rate. This module's `CITATION_GRAMMAR_FRAGMENT` is the prompt-side
fix : it lists every active citation key + teaches the placement grammar.

Two consumers (Path C — Hybrid in `94.1-01-PLAN.md`) :

1. `app.services.coach.bundles.citation_grammar.CitationGrammarBundle` —
   wraps the fragment as a Pydantic v2 BundleBase ; conditionally added
   to the activated bundle list by `compile_bundles` when
   `settings.COACH_CITATION_GATE_ENABLED=True`.

2. `app.services.coach.claude_coach_service.build_narrator_system_prompt`
   — flag-conditional append at the end of the legacy narrator path so
   the eval harness (which calls the legacy builder) sees the fragment
   when `COACH_CITATION_GATE_ENABLED=True`. Default `False` preserves
   the byte-identity invariant pinned by `test_byte_identity_flag_off`
   and `test_flag_off_byte_identical_to_snapshot` (5 fixtures × 2 tests).

The fragment text is built from `CITATION_REGISTRY` at module-import
time via `_build_citation_grammar_fragment()`. Coupling : if a key is
added/removed from the registry, the fragment auto-updates ; the test
`test_grammar_fragment_lists_all_18_registry_keys` enforces the bond.

Compliance contract (CLAUDE.md §1) : the fragment text MUST NOT contain
LSFin banned terms (full list at `tools/checks/banned_terms_python.py`)
and MUST keep accents 100% FR (« créer », « éclairage », « sécurité »…).
Lint via `tools/checks/accent_lint_fr.py` and the pre-commit
banned-term gate.

The fragment's structure mirrors existing bundle fragment style (e.g.
`pillar3a_optimizer.py`) so the bundle compiler's `_FRAGMENT_SEPARATOR`
(`\\n\\n---\\n\\n`) joins it cleanly with adjacent fragments. The
fragment introduces NO new `{slot}` placeholders so the H4 undeclared-
slot guard at `bundle_compiler.py:97-105` stays green.
"""
from __future__ import annotations

from types import MappingProxyType
from typing import Iterable, Mapping

from app.services.coach.citation_registry import CITATION_REGISTRY


def _build_citation_grammar_fragment() -> str:
    """Compose the FR doctrine fragment from `CITATION_REGISTRY`.

    Pure function — invoked once at module import to set
    `CITATION_GRAMMAR_FRAGMENT` to a frozen `str` constant. No I/O, no
    LLM call, no side effects.

    Returns :
        The composed FR fragment as a single multi-line string. Length
        target ≤80 lines (~4 kB) per `94.1-01-PLAN.md` token budget.
    """
    # Header — explicit closed-world rule with the verbatim grammar that
    # the gate's `_RE_CITE_PLACEHOLDER = r"\{\{cite:[A-Za-z0-9_\-]+\}\}"`
    # accepts. Phrasing matches D-09 reprompt addendum style verbatim
    # (`citation_parser.REPROMPT_ADDENDUM_UNCITED`) so the system prompt
    # and the retry reprompt teach the same syntax.
    header = (
        "## DOCTRINE — GRAMMAIRE DE CITATION (closed-world, "
        "non-négociable)\n"
        "\n"
        "Pour CHAQUE chiffre émis (montant CHF/EUR/USD, pourcentage, "
        "durée en années/mois/jours, constante réglementaire), place "
        "un placeholder `{{cite:<clé>}}` directement après le chiffre. "
        "La liste des clés autorisées est ci-dessous — c'est un "
        "vocabulaire fermé. En l'absence de clé adaptée pour un "
        "chiffre, écris « je n'ai pas cette donnée pour l'instant » à "
        "la place du chiffre. N'INVENTE JAMAIS une clé qui n'apparaît "
        "pas dans la liste — la garde rejette toute clé inconnue et "
        "la réponse bascule alors sur un fallback templaté.\n"
    )

    # Vocabulary — every active key from CITATION_REGISTRY with its
    # FR description. Sorted alphabetically for determinism so the
    # fragment is byte-stable across reloads. Builds a markdown bullet
    # list ; each bullet is one key + its description_fr.
    keys_section_lines: list[str] = ["", "### Clés autorisées (vocabulaire fermé) :", ""]
    for key in sorted(CITATION_REGISTRY.keys()):
        src = CITATION_REGISTRY[key]
        keys_section_lines.append(
            f"- `{{{{cite:{key}}}}}` — {src.description_fr}"
        )
    keys_section_lines.append("")  # trailing blank line
    keys_section = "\n".join(keys_section_lines)

    # Examples — three verbatim FR examples covering VALID / VALID-no-key
    # / INVALID cases. Wording avoids LSFin banned terms (full list at
    # tools/checks/banned_terms_python.py) and respects the « pourrait »
    # / « envisager » vocabulary. Quotes use French guillemets « » and
    # accents are 100% FR (lint-clean).
    examples = (
        "\n"
        "### Exemples (verbatim, à imiter) :\n"
        "\n"
        "**ACCEPTÉ — chiffre cité** :\n"
        "« Pour 2026, le plafond 3a salarié·e est fixé par "
        "l'OPP3 art. 7 al. 1 let. a {{cite:r3a_plafond_salarie_2026}}. »\n"
        "\n"
        "**ACCEPTÉ — pas de clé adaptée** :\n"
        "« Je n'ai pas cette donnée pour l'instant. Pour avancer "
        "ensemble, dis-moi un peu plus sur ta situation. »\n"
        "\n"
        "**REJETÉ — chiffre nu, sans `{{cite:<clé>}}`** :\n"
        "« Le plafond 3a est de 7'056 CHF cette année. » → la garde "
        "détecte le chiffre non cité, demande une reformulation, et "
        "si la deuxième tentative reste non citée, ta réponse bascule "
        "sur le fallback templaté. Évite ce cas en plaçant la clé "
        "directement après le chiffre, ou en écrivant « je n'ai pas "
        "cette donnée pour l'instant » à la place du chiffre.\n"
    )

    # Adjacency rule — the gate uses a 80-char window per
    # `citation_parser._CITATION_ADJACENCY_CHARS`. We translate this
    # operationally for the narrator without surfacing the integer.
    rule_section = (
        "\n"
        "### Règle de placement :\n"
        "\n"
        "- Place `{{cite:<clé>}}` IMMÉDIATEMENT après le chiffre "
        "(même phrase, sans clause intermédiaire longue).\n"
        "- Une référence d'article de loi suisse (« art. 38 LIFD », "
        "« LPP art. 79b al. 3 ») est elle-même une citation — pas "
        "besoin d'ajouter `{{cite:}}` autour.\n"
        "- Une projection (« pourrait », « selon ce scénario », "
        "« si X reste constant ») reste au conditionnel ; n'utilise "
        "JAMAIS d'affirmation de promesse même avec une clé citée "
        "(« vous ferez 4% » est rejeté EVEN AVEC `{{cite:}}`).\n"
        "- Si le chiffre vient d'un calcul utilisateur (revenus, "
        "patrimoine saisi en chat), tu peux l'écrire sans clé — la "
        "garde reconnaît les négations et les méta-citations.\n"
    )

    return header + keys_section + examples + rule_section


# Frozen module-level constant — built at import. Pure str ; no
# mutable state. Re-exported by `__all__`.
CITATION_GRAMMAR_FRAGMENT: str = _build_citation_grammar_fragment()


# ---------------------------------------------------------------------------
# Phase 94.2 / Phase 97 W7 iter#11 — H1 intent-scoped key grouping.
#
# Hypothesis from `.planning/phases/94.1-.../94.1-EVAL-DELTA.md` §Root cause
# hypotheses for 94.2 (H1, high confidence) :
#
#   « The grammar fragment lists 18 keys with their FR descriptions. Total
#   bullet section is ~1.3 kB ; the narrator's attention may dilute over the
#   list. 94.2 candidate change : group keys by INTENT (3a / lpp / tax /
#   mortgage) so the bullet list is shorter per intent, surfaced ONLY when
#   that intent is active. »
#
# Intent → CITATION_REGISTRY keys mapping. Each intent label matches the
# 6-enum value space exposed by `coach_chat._classify_user_intent` (debt /
# housing / family / career / retirement / taxes) AND the fixture-level
# `intents` field in `citation_gate_eval_50.jsonl` (which also uses the
# convenience aliases `tax` / `mortgage` — both are accepted here, mapped
# to the same key buckets, so the eval harness can pass fixture intents
# verbatim without a translation step).
#
# Frozen at module load. Karpathy #2 simplicity-first : 1 mapping + 1
# function. No bundle refactor, no Pydantic schema, no I/O.
# ---------------------------------------------------------------------------

_INTENT_TO_CITATION_KEYS: Mapping[str, frozenset[str]] = MappingProxyType({
    # `retirement` — 3a / LPP / AVS / cross-pillar capital tax. The most
    # populated bucket (8 keys) because Phase 94.1's 50-fixture pack
    # over-indexes on retirement intents (26/50 fixtures).
    "retirement": frozenset({
        "r3a_plafond_salarie_2026",
        "r3a_plafond_independant_2026",
        "lpp_taux_conv_obligatoire_2026",
        "opp2_coordination_2026",
        "lpp_rente_survivant_pct",
        "lavs_age_reference_2026",
        "lifd_art_22_rentes",
        "lifd_art_38_capital_taux",
    }),
    # `taxes` (canonical) + `tax` (alias used by eval fixtures) — LIFD /
    # LHID deductions + capital tax at retrait.
    "taxes": frozenset({
        "lifd_art_33_deduction",
        "lifd_art_33_deduction_3a",
        "lifd_art_33_rachat_lpp",
        "lifd_art_22_rentes",
        "lifd_art_38_capital_taux",
        "lifd_art_38_taux_reduit",
        "lhid_harmonisation",
    }),
    "tax": frozenset({
        "lifd_art_33_deduction",
        "lifd_art_33_deduction_3a",
        "lifd_art_33_rachat_lpp",
        "lifd_art_22_rentes",
        "lifd_art_38_capital_taux",
        "lifd_art_38_taux_reduit",
        "lhid_harmonisation",
    }),
    # `housing` (canonical) + `mortgage` (alias used by eval fixtures) —
    # FINMA Tragbarkeit / LTV / amortissement rules.
    "housing": frozenset({
        "finma_taux_calculatoire",
        "amortissement_taux_2026",
        "finma_lcb_tragbarkeit",
        "ltv_max_residence_principale",
        "ratio_endettement_max_33pct",
    }),
    "mortgage": frozenset({
        "finma_taux_calculatoire",
        "amortissement_taux_2026",
        "finma_lcb_tragbarkeit",
        "ltv_max_residence_principale",
        "ratio_endettement_max_33pct",
    }),
    # `debt` — same Tragbarkeit / debt-service ratio surface as housing,
    # without the LTV/amortization specifics (debt-conso is not mortgage).
    "debt": frozenset({
        "finma_lcb_tragbarkeit",
        "ratio_endettement_max_33pct",
    }),
    # `career` — LPP at career transition + AVS reference age.
    "career": frozenset({
        "lpp_taux_conv_obligatoire_2026",
        "opp2_coordination_2026",
        "lavs_age_reference_2026",
    }),
    # `family` — LPP survivant + AVS (couple / orphelin).
    "family": frozenset({
        "lpp_rente_survivant_pct",
        "lavs_age_reference_2026",
    }),
})


def build_intent_scoped_citation_grammar(intents: Iterable[str]) -> str:
    """Compose an intent-scoped variant of `CITATION_GRAMMAR_FRAGMENT`.

    Returns a fragment listing ONLY the CITATION_REGISTRY keys relevant to
    the active intent set (per `_INTENT_TO_CITATION_KEYS` mapping above),
    instead of the full 18-bullet vocabulary. The header, examples, and
    placement rules are identical to the full fragment — only the
    « Clés autorisées » bullet list differs.

    Args:
        intents: classified intent set from
            `coach_chat._classify_user_intent` OR the fixture-level
            `intents` field. Empty / unrecognized intents fall back to
            the full 18-key fragment (defensive default, preserves
            cold-start behavior).

    Returns:
        FR fragment string. Byte-identical to `CITATION_GRAMMAR_FRAGMENT`
        when `intents` is empty or contains only unrecognized labels.

    Karpathy #3 surgical : pure function ; reuses `_build_citation_grammar_fragment`'s
    header/examples/rule structure ; only the keys-section bullet list is
    customized. No state, no I/O, no LLM call.
    """
    normalized = {i for i in intents if i in _INTENT_TO_CITATION_KEYS}
    if not normalized:
        # Defensive default : empty / unknown intents → full fragment.
        # Preserves the cold-start case (no classified intent yet) and
        # the « unknown intent » safety net.
        return CITATION_GRAMMAR_FRAGMENT

    # Union of intent-keyed buckets. Sorted alphabetically for determinism
    # (byte-stable fragment per same intent set, useful for snapshot tests
    # + token-count cache stability).
    scoped_keys: set[str] = set()
    for intent in normalized:
        scoped_keys.update(_INTENT_TO_CITATION_KEYS[intent])

    # If the union covers all 18 keys (e.g. {retirement, taxes, housing,
    # career, family}), defer to the full fragment to avoid a duplicate
    # build path that says the same thing.
    if scoped_keys == set(CITATION_REGISTRY.keys()):
        return CITATION_GRAMMAR_FRAGMENT

    # Re-use the full fragment's structure but replace ONLY the
    # « Clés autorisées » bullet list. Rebuild from scratch (it's cheap)
    # so the contract « bullet list reflects scoped keys only » is
    # mechanically true (no string-surgery on the full fragment).
    header = (
        "## DOCTRINE — GRAMMAIRE DE CITATION (closed-world, "
        "non-négociable)\n"
        "\n"
        "Pour CHAQUE chiffre émis (montant CHF/EUR/USD, pourcentage, "
        "durée en années/mois/jours, constante réglementaire), place "
        "un placeholder `{{cite:<clé>}}` directement après le chiffre. "
        "La liste des clés autorisées est ci-dessous — c'est un "
        "vocabulaire fermé adapté à ton contexte actuel. En l'absence "
        "de clé adaptée pour un chiffre, écris « je n'ai pas cette "
        "donnée pour l'instant » à la place du chiffre. N'INVENTE "
        "JAMAIS une clé qui n'apparaît pas dans la liste — la garde "
        "rejette toute clé inconnue et la réponse bascule alors sur "
        "un fallback templaté.\n"
    )

    keys_section_lines: list[str] = ["", "### Clés autorisées (vocabulaire fermé) :", ""]
    for key in sorted(scoped_keys):
        src = CITATION_REGISTRY[key]
        keys_section_lines.append(
            f"- `{{{{cite:{key}}}}}` — {src.description_fr}"
        )
    keys_section_lines.append("")
    keys_section = "\n".join(keys_section_lines)

    examples = (
        "\n"
        "### Exemples (verbatim, à imiter) :\n"
        "\n"
        "**ACCEPTÉ — chiffre cité** :\n"
        "« Pour 2026, le plafond 3a salarié·e est fixé par "
        "l'OPP3 art. 7 al. 1 let. a {{cite:r3a_plafond_salarie_2026}}. »\n"
        "\n"
        "**ACCEPTÉ — pas de clé adaptée** :\n"
        "« Je n'ai pas cette donnée pour l'instant. Pour avancer "
        "ensemble, dis-moi un peu plus sur ta situation. »\n"
        "\n"
        "**REJETÉ — chiffre nu, sans `{{cite:<clé>}}`** :\n"
        "« Le plafond 3a est de 7'056 CHF cette année. » → la garde "
        "détecte le chiffre non cité, demande une reformulation, et "
        "si la deuxième tentative reste non citée, ta réponse bascule "
        "sur le fallback templaté. Évite ce cas en plaçant la clé "
        "directement après le chiffre, ou en écrivant « je n'ai pas "
        "cette donnée pour l'instant » à la place du chiffre.\n"
    )

    rule_section = (
        "\n"
        "### Règle de placement :\n"
        "\n"
        "- Place `{{cite:<clé>}}` IMMÉDIATEMENT après le chiffre "
        "(même phrase, sans clause intermédiaire longue).\n"
        "- Une référence d'article de loi suisse (« art. 38 LIFD », "
        "« LPP art. 79b al. 3 ») est elle-même une citation — pas "
        "besoin d'ajouter `{{cite:}}` autour.\n"
        "- Une projection (« pourrait », « selon ce scénario », "
        "« si X reste constant ») reste au conditionnel ; n'utilise "
        "JAMAIS d'affirmation de promesse même avec une clé citée "
        "(« vous ferez 4% » est rejeté EVEN AVEC `{{cite:}}`).\n"
        "- Si le chiffre vient d'un calcul utilisateur (revenus, "
        "patrimoine saisi en chat), tu peux l'écrire sans clé — la "
        "garde reconnaît les négations et les méta-citations.\n"
    )

    return header + keys_section + examples + rule_section


__all__ = [
    "CITATION_GRAMMAR_FRAGMENT",
    "_build_citation_grammar_fragment",
    "build_intent_scoped_citation_grammar",
    "_INTENT_TO_CITATION_KEYS",
]

"""Phase 94.1 Wave 4 — narrator citation-grammar fragment.

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


__all__ = ["CITATION_GRAMMAR_FRAGMENT", "_build_citation_grammar_fragment"]

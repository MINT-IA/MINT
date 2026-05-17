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


# ---------------------------------------------------------------------------
# Wave 1c (D-03) — tool_use INVOCATION mandate.
#
# Shared constants prepended to BOTH the full fragment AND the intent-scoped
# variant. The mandate paragraph appears BEFORE any FORMAT example so the
# narrator reads "you MUST invoke first" before it reads "here is how to cite
# the result". The WRONG/RIGHT example pair is inserted at the TOP of the
# examples block (before the existing ACCEPTÉ entries) for the same reason.
#
# Doctrine: per `.planning/phases/wave-1c-coach-tool-dispatch-rca/HANDOFF.md`
# smoking-gun bisection, Sonnet 4.5 was emitting `{{cite:tool_<name>}}`
# placeholders AS PROSE without ever invoking the matching tool via
# `tool_use`. The Wave 1b grammar fragment taught the citation FORMAT but
# never MANDATED the prior `tool_use` invocation. This block adds that
# mandate at doctrine level, paired with a runtime gate at
# `app.api.v1.endpoints.coach_chat._enforce_tool_use_for_citations`.
#
# LSFin compliance: phrasing uses « il est OBLIGATOIRE de » (impersonal
# imperative) instead of the LSFin-imperative-voice second-person form
# (forbidden by CLAUDE.md §5 NEVER #5 in user-facing FR). The lint at
# `tools/checks/banned_terms_python.py` does NOT scan the second-person
# imperative form — this is a project-doctrine rule, enforced pre-push by
# grep + the security-auditor design panel.
# ---------------------------------------------------------------------------

_TOOL_USE_MANDATE: str = (
    "## DOCTRINE — INVOCATION OBLIGATOIRE D'OUTIL "
    "(préalable à toute citation `tool_*`)\n"
    "\n"
    "AVANT d'émettre tout placeholder `{{cite:tool_<name>}}` dans ta "
    "réponse, il est OBLIGATOIRE d'invoquer d'abord l'outil correspondant "
    "via le mécanisme `tool_use`. UNE citation = UN appel `tool_use` "
    "préalable. Aucune exception.\n"
    "\n"
    "Concrètement : si la réponse écrit "
    "`{{cite:tool_retirement_projection}}` après un chiffre, un bloc "
    "`tool_use(get_retirement_projection)` doit avoir été émis plus tôt "
    "dans ce même tour et son `tool_result` retourné. Sans cet appel "
    "préalable, le placeholder est rejeté par la garde et la réponse "
    "bascule sur un fallback templaté.\n"
    "\n"
    "Le `{{cite:tool_<name>}}` n'est PAS une formule magique — c'est une "
    "référence à un calcul serveur qui doit avoir été déclenché via "
    "`tool_use` plus tôt dans ce même tour.\n"
    "\n"
    "## DOCTRINE — VALEURS RÉGLEMENTAIRES DATÉES "
    "(plafond 3a, coordination LPP, rente AVS, barèmes IFD/IS, taux LAMal)\n"
    "\n"
    "Pour TOUTE valeur réglementaire datée (CHF, %, durée) que tu cites "
    "avec une clé non-`tool_*` (par exemple `r3a_plafond_salarie_2026`, "
    "`lpp_coordination_2026`, `avs_rente_max_2026`, `ifd_bracket_*`), il "
    "est OBLIGATOIRE d'invoquer d'abord l'outil `get_regulatory_constant` "
    "via `tool_use(get_regulatory_constant, key=\"<registry-key>\")`, ET "
    "d'écrire EXACTEMENT la valeur retournée par `tool_result` — JAMAIS "
    "de mémoire, d'estimation, ni de valeur tirée d'un exemple "
    "(les exemples REJETÉS plus bas ne sont pas des sources de "
    "valeurs).\n"
    "\n"
    "Le registre officiel (OFAS, OPP3, LAVS, LIFD) est la SEULE source "
    "fiable. Toute valeur reproduite « de tête » est par définition "
    "obsolète — les plafonds OFAS sont révisés chaque année. Ne donne "
    "JAMAIS un chiffre régulatoire sans `tool_use(get_regulatory_constant)` "
    "préalable dans ce même tour. À défaut, écris « je n'ai pas cette "
    "donnée pour l'instant » plutôt que d'émettre une valeur non "
    "sourcée.\n"
    "\n"
    "## DOCTRINE — USAGE MESURÉ DU MARKDOWN (obs #158)\n"
    "\n"
    "Tu peux utiliser le markdown `**gras**` et `*italique*` UNIQUEMENT "
    "pour de l'emphase ponctuelle (un mot-clé important, un verdict). "
    "PAS de titres (`#`, `##`, `###`), PAS de blocs de code (`` ``` ``), "
    "PAS de listes numérotées, PAS de tableaux, PAS de liens "
    "(`[texte](url)`). Le rendu mobile du chat n'est pas un éditeur "
    "Markdown : c'est une conversation. Écris en prose française "
    "naturelle, fluide, en phrases courtes, avec emphase TYPOGRAPHIQUE "
    "(gras / italique) seulement quand c'est vraiment justifié — pas "
    "plus d'UNE emphase par bulle de coach en moyenne. Un texte "
    "saturé de `**` est aussi mauvais qu'un texte sans aucune emphase.\n"
)

_TOOL_USE_WRONG_RIGHT_EXAMPLE: str = (
    "**REJETÉ — placeholder sans tool_use préalable** :\n"
    "« Ta projection de rente AVS sera de "
    "{{cite:tool_retirement_projection}} » écrit sans avoir d'abord émis "
    "`tool_use(get_retirement_projection)` dans ce tour. La garde détecte "
    "l'absence d'invocation et rejette. Pour corriger : appelle "
    "`get_retirement_projection` AVANT d'émettre la phrase.\n"
    "\n"
    "**ACCEPTÉ — tool_use puis citation du résultat** :\n"
    "Émets d'abord le bloc `tool_use(get_retirement_projection)` ; attends "
    "le `tool_result` ; écris ensuite « Ta projection de rente AVS "
    "pourrait être autour de 24'960 CHF/an "
    "{{cite:tool_retirement_projection}} ». La garde reconnaît l'appel "
    "préalable et accepte la citation.\n"
    "\n"
)


# ---------------------------------------------------------------------------
# Wave 1c-A1 (2026-05-15) — MANDATE repeated at BOTTOM of fragment to
# mitigate Liu 2024 lost-in-the-middle. The TOP occurrence (above the
# legacy GRAMMAIRE DE CITATION header) sits at ~51% of the staging
# system prompt; this repeat sits at ~64% (after rule_section). Plus a
# 3rd injection lives at ~99% (system prompt tail, see coach_chat.py
# _build_system_prompt_with_memory). 3-position pattern mirrors
# CLAUDE.md §1 TOP/BOTTOM duplication.
#
# Source of the lost-in-the-middle insight:
# `.planning/phases/wave-1c-coach-tool-dispatch-rca/probe-evidence/
# probe-2026-05-15-1958-payload.jsonl` — system prompt 45,879 chars,
# Wave A's MANDATE at chars 23,624 & 23,761 (51.5% / 51.8%) — peak
# lost-in-the-middle zone. Sonnet under-attended and chose deferral
# (« j'ai besoin de récupérer tes données ») instead of `tool_use`.
# ---------------------------------------------------------------------------

_TOOL_USE_MANDATE_REPEAT: str = (
    "\n"
    "## RAPPEL — INVOCATION OBLIGATOIRE D'OUTIL "
    "(seconde occurrence, post-règles)\n"
    "\n"
    "AVANT d'émettre tout placeholder `{{cite:tool_<name>}}` dans ta "
    "réponse, il est OBLIGATOIRE d'invoquer d'abord l'outil "
    "correspondant via le mécanisme `tool_use`. UNE citation = UN "
    "appel `tool_use` préalable. Aucune exception.\n"
    "\n"
    "Si la question de l'utilisateur appelle un calcul (projection "
    "rente, surplus mensuel, plafond 3a), n'attends pas que "
    "l'utilisateur fournisse les données : INVOQUE l'outil. L'outil "
    "récupère automatiquement le profil et les valeurs côté serveur. "
    "Toute formulation du type « j'ai besoin de récupérer tes "
    "données » indique un manquement à cette doctrine.\n"
    "\n"
    "## RAPPEL — VALEURS RÉGLEMENTAIRES (seconde occurrence)\n"
    "\n"
    "Pour TOUTE valeur réglementaire datée citée avec une clé "
    "non-`tool_*` (`r3a_*`, `lpp_*`, `avs_*`, `ifd_*`, etc.) : "
    "INVOQUE `tool_use(get_regulatory_constant, key=\"<registry-key>\")` "
    "AVANT d'écrire le chiffre, puis recopie EXACTEMENT la valeur du "
    "`tool_result`. Une valeur tirée de mémoire est par construction "
    "obsolète et déclenche le fallback templaté.\n"
)


def _build_citation_grammar_fragment() -> str:
    """Compose the FR doctrine fragment from `CITATION_REGISTRY`.

    Pure function — invoked once at module import to set
    `CITATION_GRAMMAR_FRAGMENT` to a frozen `str` constant. No I/O, no
    LLM call, no side effects.

    Returns :
        The composed FR fragment as a single multi-line string. Length
        target ≤80 lines (~4 kB) per `94.1-01-PLAN.md` token budget.
        Wave 1c — extended by the `_TOOL_USE_MANDATE` prelude (~12 lines)
        and the `_TOOL_USE_WRONG_RIGHT_EXAMPLE` pair (~10 lines) so the
        budget grows to ~6 kB ; still well within the staging system-prompt
        envelope (44 kB) measured at
        `.planning/phases/wave-1c-coach-tool-dispatch-rca/captured_staging_payload_hydrated.json`.
    """
    # Wave 1c (D-03) — tool_use INVOCATION mandate. Prepended BEFORE the
    # legacy GRAMMAIRE DE CITATION header so the narrator reads "invoke
    # first" before it reads "here's how to cite". See `_TOOL_USE_MANDATE`
    # docstring above for full doctrine.
    mandate = _TOOL_USE_MANDATE + "\n"

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

    # Wave 1b Plan 03 — tool_call_id paragraph (RESEARCH §4.4). Teaches the
    # narrator that `tool_*` keys mark numbers calculated server-side, and
    # that the per-call `inputs_hash` travels with the response container,
    # so the narrator only needs to place the single-segment placeholder
    # after the digit. Per Q5_DECISION (1-segment vs 2-segment grammar at
    # `wave-1b-03-PLAN.md` top), this respects CONTEXT hard constraint #4
    # (no edit to `_RE_CURRENCY` / `_RE_PERCENT` / `_RE_CITE_PLACEHOLDER`
    # regexes in citation_parser.py).
    tool_paragraph = (
        "\n"
        "Certaines clés (`tool_*`) marquent un chiffre calculé côté "
        "serveur — son `inputs_hash` voyage avec la réponse, tu n'as "
        "pas besoin de le citer dans le texte. Place simplement la clé "
        "`{{cite:tool_<nom>}}` après le chiffre, comme pour les autres "
        "clés du vocabulaire fermé.\n"
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
    # P003 (2026-05-12) — Examples rewritten to remove (a) the « ACCEPTÉ —
    # pas de clé adaptée » example that taught the narrator to emit the
    # FALLBACK_TEMPLATED_TEXT string verbatim (which led to silent self-
    # fallback, cycle P003 RCA H3), and (b) the « écris je n'ai pas cette
    # donnée à la place du chiffre » exit hatch in the rule section
    # (which compounded the same self-fallback path).
    # New examples cover : (1) registry-cited regulatory chiffre, (2) user-
    # supplied chiffre echoed back without clé (now genuinely gate-exempt
    # per the P003 step 5b exemption in citation_parser.gate), (3) the
    # rejected case where the narrator FABRICATES a number it cannot cite.
    examples = (
        "\n"
        "### Exemples (verbatim, à imiter) :\n"
        "\n"
        # Wave 1c (D-03) — WRONG/RIGHT contrast pair surfaces the
        # tool_use mandate at example level. Placed BEFORE the legacy
        # ACCEPTÉ entries so the narrator sees the failure mode FIRST,
        # then the correct invocation pattern, then the regulatory /
        # user-input variants.
        + _TOOL_USE_WRONG_RIGHT_EXAMPLE
        + "**ACCEPTÉ — chiffre réglementaire cité** :\n"
        "« Pour 2026, le plafond 3a salarié·e est fixé par "
        "l'OPP3 art. 7 al. 1 let. a {{cite:r3a_plafond_salarie_2026}}. »\n"
        "\n"
        "**ACCEPTÉ — chiffre calculé côté serveur** :\n"
        "L'outil `get_budget_status` renvoie un surplus mensuel de "
        "1'234 CHF. Tu peux répondre : « Selon ton dernier instantané, "
        "ton surplus mensuel pourrait être autour de 1'234 CHF "
        "{{cite:tool_budget_snapshot}}. La garde reconnaît la clé "
        "`tool_*` et lie automatiquement le chiffre à l'`inputs_hash` "
        "du calcul. »\n"
        "\n"
        "**ACCEPTÉ — chiffre fourni par l'utilisateur, échoué tel quel** :\n"
        "L'utilisateur écrit : « j'ai 49 ans, 7'600 CHF de salaire net ».\n"
        "Tu peux répondre : « Avec 49 ans et 7'600 CHF de salaire net, "
        "tu pourrais envisager… ». La garde reconnaît automatiquement "
        "les chiffres présents dans le message de l'utilisateur et les "
        "laisse passer sans `{{cite:<clé>}}` — c'est de l'écho de "
        "données, pas une affirmation de valeur réglementaire.\n"
        "\n"
        "**REJETÉ — chiffre fabriqué que tu ne peux pas sourcer** :\n"
        "« Tu pourrais économiser 1'200 CHF de plus par mois. » → "
        "le chiffre 1'200 n'est PAS dans le message de l'utilisateur "
        "et n'a pas de clé `{{cite:<clé>}}` adaptée dans le "
        "vocabulaire fermé. La garde le rejette. Pour formuler une "
        "estimation, soit cite la clé qui couvre le calcul, soit "
        "reformule au conditionnel sans avancer de chiffre précis "
        "(« une marge mensuelle resterait à dégager »).\n"
    )

    # Adjacency rule — the gate uses a 80-char window per
    # `citation_parser._CITATION_ADJACENCY_CHARS`. We translate this
    # operationally for the narrator without surfacing the integer.
    # P003 (2026-05-12) — last bullet rewritten to ACCURATELY describe
    # the new step 5b exemption added in `citation_parser.gate`.
    # Pre-P003 wording (« la garde reconnaît les négations et les
    # méta-citations ») was a prompt-code contract violation : the gate
    # had no user-input branch and rejected legitimate echoes.
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
        "- Les chiffres présents dans le message de l'utilisateur "
        "(âge, salaire, montants déclarés, nombre de comptes) sont "
        "automatiquement exemptés par la garde : tu peux les "
        "reprendre tels quels dans ta réponse sans `{{cite:<clé>}}`. "
        "Cette exemption ne couvre PAS les chiffres dérivés ou "
        "estimés par toi (calculs, ratios, totaux) — ceux-ci doivent "
        "soit citer une clé du vocabulaire fermé, soit rester "
        "qualitatifs.\n"
    )

    # Wave 1c (D-03) — mandate prepended BEFORE the legacy header so the
    # narrator reads "invoke first" before any FORMAT example.
    # Wave 1c-A1 (D-03 iteration) — `_TOOL_USE_MANDATE_REPEAT` appended at
    # the END of the fragment so a second copy of the doctrine sits below
    # the rule_section. Mitigates Liu 2024 lost-in-the-middle (probe
    # showed Wave A's single-position MANDATE at 51% was insufficient).
    return (
        mandate
        + header
        + tool_paragraph
        + keys_section
        + examples
        + rule_section
        + _TOOL_USE_MANDATE_REPEAT
    )


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

# Wave 1b Plan 03 — `tool_*` registry keys are activated for ANY narrator
# turn that calls a server-side coach tool (per RESEARCH §4.4 + CONTEXT
# D-02). Tool calls are LLM-driven, NOT intent-driven : the narrator can
# call `get_budget_status` even on a « retirement » intent. Adding the 6
# `tool_*` keys to EVERY intent bucket guarantees the keys are surfaced
# in the intent-scoped grammar regardless of the classified intent.
# Mirrors the « always-on » contract pinned by
# `test_intent_scoped_grammar_includes_tools` in
# `tests/test_coach_citation/test_tool_call_id_grammar.py`.
_WAVE_1B_TOOL_KEYS_ALWAYS_ON: frozenset[str] = frozenset({
    "tool_budget_snapshot",
    "tool_retirement_projection",
    "tool_cross_pillar_analysis",
    "tool_couple_optimization",
    "tool_cap_status",
    "tool_retrieve_memories",
})


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
    }) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
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
    }) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
    "tax": frozenset({
        "lifd_art_33_deduction",
        "lifd_art_33_deduction_3a",
        "lifd_art_33_rachat_lpp",
        "lifd_art_22_rentes",
        "lifd_art_38_capital_taux",
        "lifd_art_38_taux_reduit",
        "lhid_harmonisation",
    }) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
    # `housing` (canonical) + `mortgage` (alias used by eval fixtures) —
    # FINMA Tragbarkeit / LTV / amortissement rules.
    "housing": frozenset({
        "finma_taux_calculatoire",
        "amortissement_taux_2026",
        "finma_lcb_tragbarkeit",
        "ltv_max_residence_principale",
        "ratio_endettement_max_33pct",
    }) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
    "mortgage": frozenset({
        "finma_taux_calculatoire",
        "amortissement_taux_2026",
        "finma_lcb_tragbarkeit",
        "ltv_max_residence_principale",
        "ratio_endettement_max_33pct",
    }) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
    # `debt` — same Tragbarkeit / debt-service ratio surface as housing,
    # without the LTV/amortization specifics (debt-conso is not mortgage).
    "debt": frozenset({
        "finma_lcb_tragbarkeit",
        "ratio_endettement_max_33pct",
    }) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
    # `career` — LPP at career transition + AVS reference age.
    "career": frozenset({
        "lpp_taux_conv_obligatoire_2026",
        "opp2_coordination_2026",
        "lavs_age_reference_2026",
    }) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
    # `family` — LPP survivant + AVS (couple / orphelin).
    "family": frozenset({
        "lpp_rente_survivant_pct",
        "lavs_age_reference_2026",
    }) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
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

    # Wave 1b Plan 03 — same `tool_*` paragraph as the full fragment, so
    # the intent-scoped builder teaches the narrator the same tool_call_id
    # semantics regardless of which path is rendered.
    tool_paragraph = (
        "\n"
        "Certaines clés (`tool_*`) marquent un chiffre calculé côté "
        "serveur — son `inputs_hash` voyage avec la réponse, tu n'as "
        "pas besoin de le citer dans le texte. Place simplement la clé "
        "`{{cite:tool_<nom>}}` après le chiffre, comme pour les autres "
        "clés du vocabulaire fermé.\n"
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
        # Wave 1c (D-03) — same WRONG/RIGHT contrast pair as the full
        # fragment, to keep the doctrine identical regardless of which
        # path is rendered (intent-scoped vs full).
        + _TOOL_USE_WRONG_RIGHT_EXAMPLE
        + "**ACCEPTÉ — chiffre cité** :\n"
        "« Pour 2026, le plafond 3a salarié·e est fixé par "
        "l'OPP3 art. 7 al. 1 let. a {{cite:r3a_plafond_salarie_2026}}. »\n"
        "\n"
        "**ACCEPTÉ — chiffre calculé côté serveur** :\n"
        "L'outil `get_budget_status` renvoie un surplus mensuel de "
        "1'234 CHF. Tu peux répondre : « Selon ton dernier instantané, "
        "ton surplus mensuel pourrait être autour de 1'234 CHF "
        "{{cite:tool_budget_snapshot}}. La garde reconnaît la clé "
        "`tool_*` et lie automatiquement le chiffre à l'`inputs_hash` "
        "du calcul. »\n"
        "\n"
        "**ACCEPTÉ — pas de clé adaptée** :\n"
        "« Je n'ai pas cette donnée pour l'instant. Pour avancer "
        "ensemble, dis-moi un peu plus sur ta situation. »\n"
        "\n"
        # obs #157 (2026-05-17) — replaced earlier REJETÉ example that
        # used the literal value « 7'056 CHF cette année » (the 2024
        # Pilier 3a max). LLMs leak negative few-shot examples as
        # positive when surface form matches the user query (« cette
        # année ») — staging coach was emitting 7'056 for 2026 prompts.
        # Mirror the full fragment's safer fabricated-estimate framing.
        "**REJETÉ — chiffre fabriqué que tu ne peux pas sourcer** :\n"
        "« Tu pourrais économiser 1'200 CHF de plus par mois. » → "
        "le chiffre 1'200 n'est PAS dans le message de l'utilisateur "
        "et n'a pas de clé `{{cite:<clé>}}` adaptée dans le "
        "vocabulaire fermé. La garde le rejette. Pour formuler une "
        "estimation, soit cite la clé qui couvre le calcul, soit "
        "reformule au conditionnel sans avancer de chiffre précis "
        "(« une marge mensuelle resterait à dégager »).\n"
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

    # Wave 1c (D-03) — mandate prepended BEFORE the legacy header so the
    # narrator reads "invoke first" before any FORMAT example, identical
    # to the full fragment ordering.
    # Wave 1c-A1 (D-03 iteration) — `_TOOL_USE_MANDATE_REPEAT` appended at
    # the END so the doctrine appears at TOP and BOTTOM of the intent-
    # scoped fragment too, matching the full-fragment composition.
    mandate = _TOOL_USE_MANDATE + "\n"
    return (
        mandate
        + header
        + tool_paragraph
        + keys_section
        + examples
        + rule_section
        + _TOOL_USE_MANDATE_REPEAT
    )


__all__ = [
    "CITATION_GRAMMAR_FRAGMENT",
    "_build_citation_grammar_fragment",
    "build_intent_scoped_citation_grammar",
    "_INTENT_TO_CITATION_KEYS",
    "_WAVE_1B_TOOL_KEYS_ALWAYS_ON",
    "_TOOL_USE_MANDATE",
    "_TOOL_USE_MANDATE_REPEAT",
]

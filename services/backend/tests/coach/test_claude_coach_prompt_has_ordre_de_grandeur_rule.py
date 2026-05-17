"""
Tests — « ordre de grandeur » qualifier rule in the auth coach system prompt.

Regression for BUG-W2026-10 (Walker 2026-05-07): the authenticated coach cited
non-sourced Swiss medians (e.g. "la médiane des loyers tourne autour de
2'200 CHF") without the « ordre de grandeur » qualifier present in the
anonymous discovery prompt.

Verifies:
- The rule text appears in the system prompt returned by build_system_prompt
  for both a typical authenticated context and the no-context base case.
- The rule references concrete Swiss examples (médiane / taux d'imposition)
  so the LLM understands the scope (Swiss-specific approximate citations,
  not user-supplied amounts).
- The rule sits inside the « RÈGLES DE CONFORMITÉ » section, not lost in
  appended late blocks.
"""

from app.services.coach.claude_coach_service import build_system_prompt
from app.services.coach.coach_context_builder import build_coach_context


def _typical_ctx():
    """A typical authenticated user context (canton + age, no debt)."""
    return build_coach_context(has_debt=False, age=42, canton="VD")


def test_ordre_de_grandeur_rule_present_with_typical_context():
    prompt = build_system_prompt(ctx=_typical_ctx())
    assert "ordre de grandeur" in prompt.lower()


def test_ordre_de_grandeur_rule_present_with_no_context():
    """Even without a CoachContext, the base prompt must carry the rule."""
    prompt = build_system_prompt(ctx=None)
    assert "ordre de grandeur" in prompt.lower()


def test_ordre_de_grandeur_rule_cites_swiss_examples():
    """Rule must mention Swiss-specific examples so the LLM scopes it correctly.

    Without examples, the model could confuse this with user-supplied amounts.
    """
    prompt = build_system_prompt(ctx=_typical_ctx())
    lower = prompt.lower()
    # At least one of the canonical Swiss examples must appear in the rule's
    # neighbourhood (médiane de loyer / taux d'imposition cantonal).
    assert "médiane" in lower or "mediane" in lower
    assert "taux d'imposition" in lower or "taux d imposition" in lower


def test_ordre_de_grandeur_rule_lives_in_compliance_section():
    """The rule must be inside RÈGLES DE CONFORMITÉ, not in an appended block.

    Insertion location matters: rules in this section are read by the LLM as
    non-negotiable, before the routing rules and tool catalogs.
    """
    prompt = build_system_prompt(ctx=_typical_ctx())
    compliance_idx = prompt.find("RÈGLES DE CONFORMITÉ")
    moteur_idx = prompt.find("MOTEUR 4 COUCHES")
    rule_idx = prompt.lower().find("ordre de grandeur")

    assert compliance_idx != -1, "RÈGLES DE CONFORMITÉ heading missing"
    assert moteur_idx != -1, "MOTEUR 4 COUCHES heading missing"
    assert rule_idx != -1, "ordre de grandeur rule missing"
    assert compliance_idx < rule_idx < moteur_idx, (
        "ordre de grandeur rule must sit inside the RÈGLES DE CONFORMITÉ "
        "section (between the heading and MOTEUR 4 COUCHES)"
    )


def test_ordre_de_grandeur_rule_excludes_user_supplied_amounts():
    """Rule must clarify scope: NOT user-supplied amounts, NOT injected constants.

    Without this carve-out the LLM might over-qualify the user's own salary
    or the canonical pilier 3a plafond, which would degrade UX.
    """
    prompt = build_system_prompt(ctx=_typical_ctx())
    # Either the carve-out wording or one of its concrete anchors must appear.
    lower = prompt.lower()
    assert (
        "saisis par l'utilisateur" in lower
        or "saisis par l utilisateur" in lower
        or "constantes injectées" in lower
        or "constantes injectees" in lower
    )

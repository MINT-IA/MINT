"""La garde L3 anti-hallucination doit être ARMÉE sur le chemin chat prod.

Audit T07-F02 (beads MINT_nosync-3vi) : guard.validate() n'a jamais reçu de
context en prod — le cross-check « CHF affiché == financial_core » était du
code mort. Repro du bead : le LLM affirme une rente de 4200 CHF alors que
financial_core dit 2100 (déviation 100%) — aucun tiers ne détectait l'écart.
"""
from app.services.rag.guardrails import ComplianceGuardrails


def test_major_deviation_triggers_fallback_when_context_threaded():
    g = ComplianceGuardrails()
    out = g.filter_response(
        "D'après mes calculs, ta rente AVS sera de 4200 CHF par mois.",
        "fr",
        profile_context={"avs_rente": 2100.0},
    )
    assert any("allucination" in w for w in out["warnings"]), out["warnings"]
    # Déviation 100% >= seuil MAJOR 15% -> fallback sûr, pas le texte original.
    assert "4200" not in out["text"]


def test_accurate_number_passes_with_context():
    g = ComplianceGuardrails()
    out = g.filter_response(
        "Ta rente AVS pourrait se situer autour de 2100 CHF par mois.",
        "fr",
        profile_context={"avs_rente": 2100.0},
    )
    assert not any("allucination" in w for w in out["warnings"]), out["warnings"]
    assert "2100" in out["text"]


def test_no_context_behaves_as_before():
    g = ComplianceGuardrails()
    out = g.filter_response(
        "Ta rente AVS sera de 4200 CHF par mois.",
        "fr",
    )
    # Sans profil, le détecteur ne peut pas comparer — pas de fausse alerte.
    assert not any("allucination" in w for w in out["warnings"])

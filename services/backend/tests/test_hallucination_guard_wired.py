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


def test_mixed_type_profile_does_not_crash():
    """Le profil brut contient strings/bools — contrat numérique typé (Codex)."""
    g = ComplianceGuardrails()
    out = g.filter_response(
        "Ta rente AVS sera de 4200 CHF par mois.",
        "fr",
        profile_context={
            "archetype": "swiss_native",
            "canton": "VD",
            "has_lpp": True,
            "avs_rente": 2100.0,
        },
    )
    assert any("allucination" in w for w in out["warnings"])
    assert "4200" not in out["text"]


def test_current_turn_user_number_is_exempt():
    """Un montant déclaré DANS le message du tour n'est pas une hallucination."""
    g = ComplianceGuardrails()
    out = g.filter_response(
        "Merci, je note un revenu de 4200 CHF pour tes projections.",
        "fr",
        profile_context={"monthly_income": 6000.0},
        user_message="Je viens de passer à 80%, je gagne 4200 CHF maintenant.",
    )
    assert not any("allucination" in w for w in out["warnings"]), out["warnings"]
    assert "4200" in out["text"]


def test_swiss_grouped_formats_detected():
    """4'200 / 4’200 / 4 200 CHF — jamais un match partiel « 200 CHF »."""
    from app.services.coach.hallucination_detector import HallucinationDetector

    d = HallucinationDetector()
    for txt in ["4'200 CHF", "4’200 CHF", "4 200 CHF", "4 200 CHF"]:
        nums = d.extract_numbers(txt)
        assert nums and nums[0][1] == 4200.0, (txt, nums)


def test_rag_orchestrator_threads_profile_context(monkeypatch):
    """Preuve de câblage PROD : le VRAI RAGOrchestrator passe profile_context
    et user_message à filter_response (Codex : seul le no-RAG était armé)."""
    import inspect
    from app.services.rag import orchestrator as orch_mod

    src = inspect.getsource(orch_mod.RAGOrchestrator)
    call = src[src.find("filter_response(", src.find("async def query")):]
    call = call[: call.find(")")]
    assert "profile_context=profile_context" in call
    assert "user_message=question" in call

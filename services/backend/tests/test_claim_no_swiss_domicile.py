"""Un domicile fiscal récusé doit EFFACER le canton, pas seulement l'omettre.

CE QUI ÉTAIT CASSÉ

`_profile_fields_from_claim` écarte les valeurs nulles avant d'envoyer les
champs à la fusion. Un frontalier qui déclare n'avoir aucun domicile fiscal
suisse ne transmettait donc rien pour le canton — et l'ancien canton restait
intact sur le serveur.

Ce n'est pas cosmétique. Le canton du profil nourrit l'estimation d'impôt
cantonal (`coaching_engine`), l'obligation d'assurance ménage
(`coverage_checklist_service`) et la simulation de divorce. MINT aurait donc
dit « l'assurance ménage est obligatoire dans le canton X » pour un canton que
la personne venait exactement de récuser.

LA DISTINCTION QUI MANQUAIT

Une absence de valeur et une absence DÉCLARÉE ne sont pas la même chose. La
première dit « je ne sais pas » et ne doit rien défaire ; la seconde dit
« ceci n'a pas d'objet » et doit défaire ce qui avait été posé. D'où un second
canal, à côté des valeurs : les champs récusés.
"""

from app.api.v1.endpoints.sync import (
    _fields_cleared_by_claim,
    _merge_claim_fields,
    _profile_fields_from_claim,
)


class _Claim:
    """Le corps de requête, réduit à ce que ces fonctions lisent."""

    def __init__(self, wizard):
        self.wizard_answers = wizard
        self.mini_onboarding = {}


def _wizard(**extra):
    base = {
        "q_birth_year": 1988,
        "q_household_type": "single",
    }
    base.update(extra)
    return base


def test_a_declared_canton_still_travels():
    """La non-régression : sans récusation, rien ne change."""
    fields = _profile_fields_from_claim(_Claim(_wizard(q_canton="VD")))

    assert fields["canton"] == "VD"
    assert _fields_cleared_by_claim(_Claim(_wizard(q_canton="VD"))) == set()


def test_no_swiss_domicile_does_not_send_a_canton():
    claim = _Claim(_wizard(q_canton="VD", q_domicile_fiscal_suisse=False))

    fields = _profile_fields_from_claim(claim)

    assert "canton" not in fields, (
        "un canton ne doit pas voyager quand la personne dit n'avoir aucun "
        "domicile fiscal suisse"
    )
    assert "commune" not in fields


def test_no_swiss_domicile_ERASES_a_canton_already_stored():
    """Le cœur du correctif.

    La règle de fusion « ne pas écraser le cloud » protège une valeur qu'on
    ignore. Elle n'a pas à protéger une valeur que la personne vient de dire
    sans objet.
    """
    claim = _Claim(_wizard(q_domicile_fiscal_suisse=False))
    stocke = {"canton": "VD", "commune": "Lausanne", "birthYear": 1988}

    fusionne = _merge_claim_fields(
        stocke,
        _profile_fields_from_claim(claim),
        _fields_cleared_by_claim(claim),
    )

    assert "canton" not in fusionne, "le canton récusé doit disparaître"
    assert "commune" not in fusionne
    assert fusionne["birthYear"] == 1988, "et le reste du profil survit"


def test_an_unanswered_question_erases_nothing():
    """« Je ne sais pas » ne défait rien — c'est toute la distinction."""
    claim = _Claim(_wizard())
    stocke = {"canton": "VD", "commune": "Lausanne"}

    fusionne = _merge_claim_fields(
        stocke,
        _profile_fields_from_claim(claim),
        _fields_cleared_by_claim(claim),
    )

    assert fusionne["canton"] == "VD"
    assert fusionne["commune"] == "Lausanne"


def test_saying_YES_to_a_swiss_domicile_erases_nothing_either():
    claim = _Claim(_wizard(q_canton="GE", q_domicile_fiscal_suisse=True))

    assert _fields_cleared_by_claim(claim) == set()
    assert _profile_fields_from_claim(claim)["canton"] == "GE"

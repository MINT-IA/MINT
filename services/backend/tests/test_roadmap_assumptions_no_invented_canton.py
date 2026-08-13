"""Une hypothèse affichée doit être fondée, ou annoncée manquante.

La liste des hypothèses de la feuille de route énonçait « Taux marginal estimé
à X% (CH) » pour tout le monde. Quand le canton manquait, le taux était calculé
avec `profile.canton or 'ZH'` — donc sur Zurich — et l'étiquette affichée
disait « CH ». Un chiffre zurichois présenté comme national, à quelqu'un dont
on ignore justement le canton.

Le cas est devenu courant depuis qu'une personne sans domicile fiscal suisse
n'a plus de canton du tout.
"""

from app.services.rules_engine import _roadmap_assumptions


class _Profile:
    def __init__(self, canton=None, income=None):
        self.canton = canton
        self.incomeGrossYearly = income


def test_no_canton_produces_no_tax_rate_at_all():
    assumptions = _roadmap_assumptions(_Profile(canton=None, income=95000))

    joined = " ".join(assumptions)
    assert "Taux marginal non estimé" in joined
    assert "%" not in joined, "aucun taux ne doit être avancé sans canton"
    assert "ZH" not in joined and "(CH)" not in joined, (
        "ni Zurich ni une étiquette nationale ne remplacent un canton inconnu"
    )


def test_empty_canton_is_treated_as_absent():
    for empty in ("", "   "):
        joined = " ".join(_roadmap_assumptions(_Profile(canton=empty, income=95000)))
        assert "%" not in joined, f"canton {empty!r} traité comme connu"


def test_no_income_produces_no_tax_rate_either():
    joined = " ".join(_roadmap_assumptions(_Profile(canton="VD", income=None)))

    assert "Taux marginal non estimé" in joined
    assert "%" not in joined, "aucun taux sans revenu — 80'000 muets inclus"


def test_a_known_canton_and_income_do_produce_a_rate():
    # Oracle de contraste : sans lui, les tests ci-dessus passeraient même si
    # l'estimation était cassée pour tout le monde.
    assumptions = _roadmap_assumptions(_Profile(canton="VD", income=95000))

    joined = " ".join(assumptions)
    assert "(VD)" in joined
    assert "%" in joined


def test_the_default_risk_profile_is_always_stated():
    for profile in (_Profile(), _Profile(canton="VD", income=95000)):
        assert any(
            "risque modéré" in line for line in _roadmap_assumptions(profile)
        ), "l'hypothèse de risque ne dépend pas du canton"

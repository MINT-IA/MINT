"""Migration des 2 proxys heuristiques fiscaux (beads MINT_nosync-cm4).

Review Codex #994 r1 : deux calculs actifs consommaient encore le taux
plat legacy ``TAUX_IMPOT_RETRAIT_CAPITAL`` comme proxy d'un AUTRE impôt :

1. ``location_vs_propriete._estimate_tax_benefit_mortgage`` : impôt
   revenu ≈ base_rate × 3 (ZH : 19.5%) — l'économie fiscale d'une
   déduction est MARGINALE et dépend du revenu ; le modèle v2
   ``estimate_income_tax`` (130 points ESTV) la calcule exactement.
2. ``allocation_annuelle._build_investissement_libre_option`` : impôt
   fortune ≈ base_rate × 0.05 clampé 0.2-0.5% — taxe dès le premier
   franc alors que chaque canton exonère un socle (ZH : 77'000 CHF) ;
   ``WealthTaxService`` modélise exonération + barème effectif + marié.
"""

import pytest

from app.services.arbitrage.allocation_annuelle import compare_allocation_annuelle
from app.services.arbitrage.location_vs_propriete import (
    _estimate_tax_benefit_mortgage,
)
from app.services.fiscal.cantonal_comparator import estimate_income_tax
from app.services.fiscal.wealth_tax_service import WealthTaxService


# ────────────────────────────────────────────────────────────
# Proxy 2 — impôt fortune invest libre
# ────────────────────────────────────────────────────────────


def _invest_libre(montant, annees, canton="ZH", is_married=False):
    r = compare_allocation_annuelle(
        montant_disponible=montant,
        taux_marginal=0.30,
        a3a_maxed=True,  # isole l'option invest_libre
        annees_avant_retraite=annees,
        canton=canton,
        is_married=is_married,
    )
    return next(o for o in r.options if o.id == "invest_libre")


def test_invest_libre_below_exemption_zero_wealth_tax():
    """Sous le socle d'exonération cantonal, l'impôt fortune est NUL.

    ZH exonère 77'000 CHF : un plan de 7'000/an sur 5 ans culmine vers
    ~40'000 CHF — le proxy plat taxait dès le premier franc (fiction).
    """
    opt = _invest_libre(7000, 5, canton="ZH")
    assert opt.cumulative_tax_impact == 0.0
    assert all(y.cumulative_tax_delta == 0.0 for y in opt.trajectory)


def test_invest_libre_wealth_tax_identity_with_service():
    """Au-dessus du socle : impôt annuel == WealthTaxService au centime.

    Reproduit la trajectoire (versement -> croissance -> impôt) et
    vérifie chaque année contre le modèle canonique.
    """
    montant, annees, canton = 50000, 10, "ZH"
    opt = _invest_libre(montant, annees, canton=canton)
    svc = WealthTaxService()

    capital = 0.0
    cumul = 0.0
    for i, snap in enumerate(opt.trajectory):
        capital += montant
        capital *= 1.04  # rendement_marche défaut du moteur
        tax = svc.estimate_wealth_tax(capital, canton).impot_fortune
        capital -= tax
        cumul += tax
        assert snap.cumulative_tax_delta == pytest.approx(cumul, abs=0.05), (
            f"année {i + 1}"
        )
    assert opt.terminal_value == pytest.approx(capital, abs=0.05)
    assert cumul > 0, "le scénario doit dépasser le socle d'exonération"


def test_invest_libre_married_double_exemption():
    """Marié : socle doublé -> impôt fortune inférieur ou égal."""
    single = _invest_libre(30000, 8, canton="ZH", is_married=False)
    married = _invest_libre(30000, 8, canton="ZH", is_married=True)
    assert married.cumulative_tax_impact < single.cumulative_tax_impact
    assert married.terminal_value > single.terminal_value


# ────────────────────────────────────────────────────────────
# Proxy 1 — économie fiscale des déductions hypothécaires
# ────────────────────────────────────────────────────────────


def test_mortgage_tax_benefit_is_marginal_v2():
    """L'économie == différence marginale du modèle v2 au revenu donné."""
    interest, maintenance = 12000, 8000
    revenu = 140000
    benefit = _estimate_tax_benefit_mortgage(
        interest, maintenance, "VD", is_married=False, revenu_annuel=revenu
    )
    expected = estimate_income_tax(revenu, "VD") - estimate_income_tax(
        revenu - (interest + maintenance), "VD"
    )
    assert benefit == pytest.approx(expected, abs=0.01)
    assert 0 < benefit < (interest + maintenance)


def test_mortgage_tax_benefit_married_uses_v2_splitting():
    """Marié : le splitting v2 remplace le forfait ×0.80."""
    interest, maintenance, revenu = 12000, 8000, 140000
    benefit = _estimate_tax_benefit_mortgage(
        interest, maintenance, "VD", is_married=True, revenu_annuel=revenu
    )
    expected = estimate_income_tax(
        revenu, "VD", is_married=True
    ) - estimate_income_tax(
        revenu - (interest + maintenance), "VD", is_married=True
    )
    assert benefit == pytest.approx(expected, abs=0.01)


def test_mortgage_tax_benefit_default_income_anchor_documented():
    """Sans revenu fourni : ancrage = revenu minimal du test de tenue.

    revenu_ref = 3 x (5% de la dette + amortissement + entretien) — le
    revenu le plus bas auquel la banque accorderait ce prêt (règle du
    tiers, charges théoriques). Conservateur : un revenu réel plus haut
    aurait un taux marginal plus élevé, donc une économie plus grande.
    """
    interest, maintenance = 12000, 8000
    implicit = _estimate_tax_benefit_mortgage(
        interest,
        maintenance,
        "VD",
        is_married=False,
        mortgage_balance=600000,
        amortization=6000,
    )
    anchor = 3 * (600000 * 0.05 + 6000 + maintenance)
    explicit = _estimate_tax_benefit_mortgage(
        interest, maintenance, "VD", is_married=False, revenu_annuel=anchor
    )
    assert implicit == pytest.approx(explicit, abs=0.01)
    assert implicit > 0

def test_mortgage_anchor_uses_pre_amortization_balance_in_real_loop():
    """La boucle réelle transmet le solde AVANT amortissement (review #995).

    Année 1 : dette 80% du prix, amortissement 2e rang = (80% - 65%)
    du prix / 15. Le bénéfice fiscal de la trajectoire doit égaler le
    helper appelé avec CE solde — un solde post-amortissement décale
    l'ancrage (3 x 5% de la dette) et donc la marginale.
    """
    from app.services.arbitrage.location_vs_propriete import (
        compare_location_vs_propriete,
    )

    # prix choisi pour que les ancrages pre/post amortissement encadrent
    # le point 150k du modele v2 (0.18 x prix vs 0.1785 x prix) — dans un
    # meme segment lineaire la marginale serait identique et le test ne
    # discriminerait rien.
    prix = 837000.0
    r = compare_location_vs_propriete(
        capital_disponible=200000,
        loyer_mensuel_actuel=2000,
        prix_bien=prix,
        canton="VD",
        horizon_annees=5,
        taux_hypotheque=0.02,
        taux_entretien=0.01,
        is_married=False,
    )
    achat = next(o for o in r.options if o.id != "location")
    year1_benefit = -achat.trajectory[0].cumulative_tax_delta

    mortgage = prix * 0.80
    amort = (mortgage - prix * 0.65) / 15
    expected = _estimate_tax_benefit_mortgage(
        mortgage * 0.02,
        prix * 0.01,
        "VD",
        is_married=False,
        mortgage_balance=mortgage,
        amortization=amort,
    )
    assert year1_benefit == pytest.approx(expected, abs=0.01)

    # Discriminant : le solde post-amortissement donnerait un autre ancrage.
    post_amort = _estimate_tax_benefit_mortgage(
        mortgage * 0.02,
        prix * 0.01,
        "VD",
        is_married=False,
        mortgage_balance=mortgage - amort,
        amortization=amort,
    )
    assert abs(post_amort - expected) > 0.01, (
        "le test ne discrimine pas : ancrages pre/post amortissement egaux"
    )


def test_mortgage_benefit_deductible_exceeding_income_floors_at_zero_tax():
    """revenu - déductible < 0 : plancher à 0, pas de crash ni négatif."""
    benefit = _estimate_tax_benefit_mortgage(
        15000, 5000, "VD", is_married=False, revenu_annuel=10000
    )
    expected = estimate_income_tax(10000, "VD") - estimate_income_tax(0, "VD")
    assert benefit == pytest.approx(max(0.0, expected), abs=0.01)
    assert benefit >= 0

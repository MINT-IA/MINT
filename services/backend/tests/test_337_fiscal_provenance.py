"""Provenance des 39 clés fiscales du registre (beads MINT_nosync-337).

Verdict C de l'audit factuel (-zaw, `.planning/audit-etat-des-lieux-2026-07/
constants-audit/verdict_C_fiscal.md`) : les 39 entrées `mortgage.*` +
`capital_tax.*` portaient un ``source_url`` pointant vers une page d'accueil
générique (``finma.ch/fr/``, ``estv.admin.ch/``) et 34/39 étaient étiquetées
« law » alors que ce sont des approximations de modélisation (taux plat par
canton, échelle forfaitaire, rabais marié uniforme inventé).

Doctrine factuelle : une donnée réglementaire cite un document officiel
précis daté ; une approximation est étiquetée ``estimate`` avec une note
qui pointe le calcul canonique (modèle v2 -2i2). Ce module est la garde
mécanique qui empêche la régression.
"""

import pytest

from app.services.regulatory.registry import RegulatoryRegistry

GENERIC_HOMEPAGES = {
    "https://www.finma.ch/fr",
    "https://www.finma.ch",
    "https://www.estv.admin.ch",
    "https://www.admin.ch",
}

# Review #994 r1 : la garde verrouille l'ENSEMBLE EXACT des clés et les
# URLs officielles attendues par groupe — pas des formes approximatives.
ASB_HYPO_PDF = (
    "https://www.finma.ch/fr/~/media/finma/dokumente/dokumentencenter/"
    "myfinma/4dokumentation/selbstregulierung/"
    "sbvg_rl_hypofinanzierungen_20231213.pdf"
)
FEDLEX_ART38 = "https://www.fedlex.admin.ch/eli/cc/1991/1184_1184_1184/fr#art_38"
ESTV_CAPITAL_SIM = (
    "https://swisstaxcalculator.estv.admin.ch/#/calculator/capital-benefit-tax"
)
VZ_TENUE = (
    "https://www.vermoegenszentrum.ch/fr/competences/"
    "un-bien-foncier-doit-etre-financierement-supportable"
)

CANTONS = [
    "ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL", "ZG", "FR", "SO",
    "BS", "BL", "SH", "AR", "AI", "SG", "GR", "AG", "TG", "TI", "VD",
    "VS", "NE", "GE", "JU",
]

# Ensemble exact des 39 clés (verdict C) + URL officielle attendue.
# La directive ASB ne norme QUE max_2nd_pillar et amortization_rate
# (vérifié sur le PDF, review #994) — les 4 autres clés mortgage sont
# des conventions de place (test de tenue).
EXPECTED_SOURCES = {
    "mortgage.theoretical_rate": VZ_TENUE,
    "mortgage.maintenance_rate": VZ_TENUE,
    "mortgage.max_charge_ratio": VZ_TENUE,
    "mortgage.min_equity": VZ_TENUE,
    "mortgage.max_2nd_pillar": ASB_HYPO_PDF,
    "mortgage.amortization_rate": ASB_HYPO_PDF,
    "capital_tax.default_rate": FEDLEX_ART38,
    "capital_tax.married_discount": ESTV_CAPITAL_SIM,
    "capital_tax.bracket.0_100k": ESTV_CAPITAL_SIM,
    "capital_tax.bracket.100k_200k": ESTV_CAPITAL_SIM,
    "capital_tax.bracket.200k_500k": ESTV_CAPITAL_SIM,
    "capital_tax.bracket.500k_1m": ESTV_CAPITAL_SIM,
    "capital_tax.bracket.1m_plus": ESTV_CAPITAL_SIM,
    **{f"capital_tax.cantonal.{c}": ESTV_CAPITAL_SIM for c in CANTONS},
}

# Clés legacy du modèle capital v1 : encore consommées par la validation
# canton et le chemin override explicite (base_rate_override) — les deux
# anciens proxys heuristiques ont été migrés vers les modèles v2 (-cm4) ;
# le calcul canonique est estimate_capital_withdrawal_tax (v2, -2i2).
LEGACY_ESTIMATE_PREFIXES = (
    "capital_tax.default_rate",
    "capital_tax.married_discount",
    "capital_tax.bracket.",
    "capital_tax.cantonal.",
)


@pytest.fixture(scope="module")
def fiscal_params():
    reg = RegulatoryRegistry.instance()
    params = [
        p
        for p in reg.get_all()
        if p.key.startswith(("mortgage.", "capital_tax."))
    ]
    assert {p.key for p in params} == set(EXPECTED_SOURCES), (
        "périmètre verdict C : ensemble EXACT des 39 clés (review #994)"
    )
    return params


def test_no_generic_homepage_source(fiscal_params):
    """Aucune clé fiscale ne cite une page d'accueil comme source."""
    offenders = [
        p.key
        for p in fiscal_params
        if p.source_url.rstrip("/") in GENERIC_HOMEPAGES
    ]
    assert offenders == [], f"source générique (verdict C) : {offenders}"


def test_legacy_capital_keys_are_estimates_with_notes(fiscal_params):
    """Les clés du modèle v1 sont étiquetées estimate + note vers le v2.

    Verdict C : « taux plat » par canton, échelle forfaitaire et rabais
    marié uniforme ne correspondent à aucun barème officiel — les étiqueter
    « law » est une fausse attribution.
    """
    for p in fiscal_params:
        if p.key.startswith(LEGACY_ESTIMATE_PREFIXES):
            assert p.source_type == "estimate", (
                f"{p.key}: approximation étiquetée '{p.source_type}'"
            )
            assert p.notes, f"{p.key}: note manquante (chemin canonique v2)"
            assert "estimate_capital_withdrawal_tax" in p.notes, (
                f"{p.key}: la note doit pointer le calcul canonique"
            )
            if p.key.startswith("capital_tax.cantonal."):
                # Review #995 : depuis -cm4 les 2 proxys heuristiques
                # sont migrés — la note liste les usages restants réels
                # et ne doit plus prétendre de proxys actifs.
                assert "validation canton" in p.notes, (
                    f"{p.key}: usages restants non documentés"
                )
                assert "migrés" in p.notes, (
                    f"{p.key}: la note doit dater la migration -cm4"
                )


def test_exact_official_source_per_key(fiscal_params):
    """Chaque clé cite l'URL officielle attendue — au caractère près.

    Review #994 : une URL arbitraire « en .pdf contenant hypo » passait ;
    et la directive ASB était sur-attribuée à 4 clés de convention de
    place qu'elle ne norme pas.
    """
    for p in fiscal_params:
        assert p.source_url == EXPECTED_SOURCES[p.key], (
            f"{p.key}: {p.source_url}"
        )


def test_practice_keys_not_attributed_to_asb_directive(fiscal_params):
    """Les 4 conventions de place ne sont pas étiquetées « circular ASB »."""
    for key in (
        "mortgage.theoretical_rate",
        "mortgage.maintenance_rate",
        "mortgage.max_charge_ratio",
        "mortgage.min_equity",
    ):
        p = next(x for x in fiscal_params if x.key == key)
        assert p.source_type == "estimate", key
        assert p.notes, key


def test_amortization_rate_documents_real_rule(fiscal_params):
    """1 %/an est une approximation — la règle ASB réelle est documentée.

    Verdict C : amortir jusqu'à 2/3 de la valeur de nantissement en
    15 ans (linéaire) ; 1 %/an n'est qu'une approximation pratique.
    """
    p = next(x for x in fiscal_params if x.key == "mortgage.amortization_rate")
    assert p.source_type == "estimate"
    assert "2/3" in p.notes and "15 ans" in p.notes


def test_all_fiscal_keys_dated(fiscal_params):
    """Chaque clé fiscale porte effective_from + reviewed_at (fraîcheur)."""
    for p in fiscal_params:
        assert p.effective_from is not None, p.key
        assert p.reviewed_at is not None, p.key

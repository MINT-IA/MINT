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

# Clés legacy du modèle capital v1 : encore consommées UNIQUEMENT par la
# validation canton + le chemin override explicite (base_rate_override) —
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
    assert len(params) == 39, "périmètre verdict C : 6 mortgage + 33 capital_tax"
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
            assert "v2" in p.notes or "estimate_capital_withdrawal_tax" in p.notes, (
                f"{p.key}: la note doit pointer le calcul canonique"
            )


def test_mortgage_keys_cite_asb_directive(fiscal_params):
    """Les 6 clés mortgage citent la directive ASB précise (PDF), datée."""
    for p in fiscal_params:
        if p.key.startswith("mortgage."):
            assert p.source_url.endswith(".pdf"), (
                f"{p.key}: doit citer le document directive, pas un portail"
            )
            assert "hypo" in p.source_url.lower(), p.key


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

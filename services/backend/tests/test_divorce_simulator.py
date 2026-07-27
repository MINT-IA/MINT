"""
Tests for DivorceSimulator (P0 — legal compliance).

Covers:
    - LPP splitting: 50% of LPP accumulated during marriage (CC art. 122-124)
    - AVS splitting: income averaged over marriage years (LAVS art. 29sexies)
    - 3a splitting by matrimonial regime
    - Fortune splitting
    - Edge cases: 0-year marriage, one spouse 0 LPP, identical LPP, pre-marriage capital

Run: cd services/backend && python3 -m pytest tests/test_divorce_simulator.py -v
"""

import pytest

from app.services.divorce_simulator import DivorceSimulator, DivorceInput


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def simulator():
    return DivorceSimulator()


def _base_input(**overrides) -> DivorceInput:
    """Create a default DivorceInput with sensible defaults."""
    defaults = dict(
        duree_mariage_annees=10,
        regime_matrimonial="participation_acquets",
        nombre_enfants=2,
        revenu_annuel_conjoint_1=120_000,
        revenu_annuel_conjoint_2=60_000,
        lpp_conjoint_1_pendant_mariage=200_000,
        lpp_conjoint_2_pendant_mariage=80_000,
        avoirs_3a_conjoint_1=30_000,
        avoirs_3a_conjoint_2=15_000,
        fortune_commune=500_000,
        dette_commune=200_000,
        canton="VS",
    )
    defaults.update(overrides)
    return DivorceInput(**defaults)


# ---------------------------------------------------------------------------
# LPP Splitting Tests (CC art. 122-124)
# ---------------------------------------------------------------------------

class TestLPPSplitting:

    def test_lpp_50_50_split(self, simulator):
        """LPP accumulated during marriage is split 50/50."""
        data = _base_input(
            lpp_conjoint_1_pendant_mariage=200_000,
            lpp_conjoint_2_pendant_mariage=80_000,
        )
        result = simulator.simulate(data)
        lpp = result.partage_lpp
        assert lpp["total_lpp_pendant_mariage"] == 280_000
        assert lpp["conjoint_1_recoit"] == 140_000
        assert lpp["conjoint_2_recoit"] == 140_000

    def test_lpp_transfert_direction(self, simulator):
        """Transfer goes from higher LPP spouse to lower."""
        data = _base_input(
            lpp_conjoint_1_pendant_mariage=200_000,
            lpp_conjoint_2_pendant_mariage=80_000,
        )
        result = simulator.simulate(data)
        lpp = result.partage_lpp
        # Conjoint 1 had 200k, each gets 140k, so conjoint 1 transfers 60k
        assert lpp["transfert_lpp"] == 60_000
        assert lpp["transfert_direction"] == "conjoint_1_vers_conjoint_2"

    def test_lpp_one_spouse_zero(self, simulator):
        """One spouse has 0 LPP — other spouse splits 50/50."""
        data = _base_input(
            lpp_conjoint_1_pendant_mariage=100_000,
            lpp_conjoint_2_pendant_mariage=0,
        )
        result = simulator.simulate(data)
        lpp = result.partage_lpp
        assert lpp["conjoint_1_recoit"] == 50_000
        assert lpp["conjoint_2_recoit"] == 50_000
        assert lpp["transfert_lpp"] == 50_000

    def test_lpp_identical_amounts(self, simulator):
        """Both spouses have identical LPP — no transfer."""
        data = _base_input(
            lpp_conjoint_1_pendant_mariage=150_000,
            lpp_conjoint_2_pendant_mariage=150_000,
        )
        result = simulator.simulate(data)
        lpp = result.partage_lpp
        assert lpp["transfert_lpp"] == 0
        assert lpp["transfert_direction"] == "aucun_transfert"

    def test_lpp_pre_marriage_capital_excluded(self, simulator):
        """Pre-marriage LPP capital is excluded from split."""
        data = _base_input(
            lpp_conjoint_1_pendant_mariage=200_000,
            lpp_conjoint_2_pendant_mariage=80_000,
            lpp_at_marriage_conjoint_1=50_000,
            lpp_at_marriage_conjoint_2=30_000,
        )
        result = simulator.simulate(data)
        lpp = result.partage_lpp
        # Marriage-period: (200k-50k) + (80k-30k) = 150k + 50k = 200k
        assert lpp["total_lpp_pendant_mariage"] == 200_000
        assert lpp["conjoint_1_recoit"] == 100_000
        assert lpp["conjoint_2_recoit"] == 100_000
        assert "capital_pre_mariage_exclu" in lpp


# ---------------------------------------------------------------------------
# AVS Splitting Tests (LAVS art. 29sexies)
# ---------------------------------------------------------------------------

class TestAVSSplitting:

    def test_avs_income_averaged(self, simulator):
        """AVS income during marriage is averaged between spouses."""
        data = _base_input(
            revenu_annuel_conjoint_1=120_000,
            revenu_annuel_conjoint_2=60_000,
            duree_mariage_annees=10,
        )
        result = simulator.simulate(data)
        avs = result.splitting_avs
        assert avs["revenu_annuel_moyen_apres_splitting"] == 90_000
        assert avs["duree_splitting_annees"] == 10

    def test_avs_total_revenue_during_marriage(self, simulator):
        """Total revenue during marriage is correctly computed."""
        data = _base_input(
            revenu_annuel_conjoint_1=100_000,
            revenu_annuel_conjoint_2=50_000,
            duree_mariage_annees=5,
        )
        result = simulator.simulate(data)
        avs = result.splitting_avs
        assert avs["revenu_total_pendant_mariage"] == 750_000


# ---------------------------------------------------------------------------
# Edge Cases
# ---------------------------------------------------------------------------

class TestDivorceEdgeCases:

    def test_zero_year_marriage(self, simulator):
        """Marriage duration = 0 years does not crash."""
        data = _base_input(duree_mariage_annees=0)
        result = simulator.simulate(data)
        assert result.splitting_avs["duree_splitting_annees"] == 0
        assert result.splitting_avs["revenu_total_pendant_mariage"] == 0

    def test_no_children_no_pension_enfants(self, simulator):
        """No children means pension alimentaire has no child component."""
        data = _base_input(nombre_enfants=0, duree_mariage_annees=3)
        result = simulator.simulate(data)
        # Short marriage (<5y), no children: spousal pension = 0
        assert result.pension_alimentaire_estimee == 0

    def test_separation_biens_keeps_3a(self, simulator):
        """Under separation de biens, each spouse keeps their own 3a."""
        data = _base_input(
            regime_matrimonial="separation_biens",
            avoirs_3a_conjoint_1=50_000,
            avoirs_3a_conjoint_2=10_000,
        )
        result = simulator.simulate(data)
        p3a = result.partage_3a
        assert p3a["conjoint_1_part"] == 50_000
        assert p3a["conjoint_2_part"] == 10_000

    def test_communaute_biens_splits_3a(self, simulator):
        """Under communaute de biens, 3a is split 50/50."""
        data = _base_input(
            regime_matrimonial="communaute_biens",
            avoirs_3a_conjoint_1=60_000,
            avoirs_3a_conjoint_2=20_000,
        )
        result = simulator.simulate(data)
        p3a = result.partage_3a
        assert p3a["conjoint_1_part"] == 40_000
        assert p3a["conjoint_2_part"] == 40_000

    def test_negative_fortune_nette(self, simulator):
        """Debts exceeding fortune produce negative net fortune."""
        data = _base_input(fortune_commune=100_000, dette_commune=300_000)
        result = simulator.simulate(data)
        assert result.partage_fortune["fortune_nette"] == -200_000

    def test_disclaimer_present(self, simulator):
        """Result always includes a compliance disclaimer."""
        result = simulator.simulate(_base_input())
        assert "educatif" in result.disclaimer.lower()
        assert "LSFin" in result.disclaimer

    def test_checklist_includes_children_items(self, simulator):
        """Checklist includes child-specific items when children present."""
        data = _base_input(nombre_enfants=2)
        result = simulator.simulate(data)
        child_items = [c for c in result.checklist if "enfant" in c.lower()]
        assert len(child_items) >= 1


# ---------------------------------------------------------------------------
# Impact fiscal — delegation a l'etalon (hand-off 2026-07-27 §3.4)
# ---------------------------------------------------------------------------

class TestFiscalDelegueALEtalon:
    """L'impact fiscal du divorce DERIVE de l'etalon, plus d'une table plate.

    CANTON_TAX_RATES (12/26 cantons, taux plats x revenu brut) ignorait la
    progressivite et retombait sur DEFAULT_TAX_RATES en silence pour 14
    cantons. Hand-off §3.4 : « impot sur le revenu, donc l'etalon le
    couvre — fusionner, pas retirer. » Aucune assertion fiscale n'existait
    avant ces tests.
    """

    def test_impot_commun_delegue_a_l_etalon(self, simulator):
        from app.services.fiscal.cantonal_comparator import estimate_income_tax

        # AI etait ABSENT de l'ancienne table -> fallback silencieux.
        for canton in ("VS", "ZH", "AI"):
            result = simulator.simulate(_base_input(canton=canton))
            # base imposable = 85 % du brut (convention de l'etalon,
            # CantonalComparator.estimate_tax) — revue Codex P1.
            attendu = round(
                estimate_income_tax(180_000 * 0.85, canton, is_married=True), 2
            )
            obtenu = result.impact_fiscal_avant["impot_commun"]
            assert obtenu == pytest.approx(attendu, abs=0.01), (
                f"{canton} : {obtenu} != etalon {attendu}"
            )

    def test_impot_apres_sans_enfant_bareme_celibataire(self, simulator):
        """Revenus egaux, sans enfant : chacun a l'etalon celibataire."""
        from app.services.fiscal.cantonal_comparator import estimate_income_tax

        data = _base_input(
            nombre_enfants=0,
            revenu_annuel_conjoint_1=90_000,
            revenu_annuel_conjoint_2=90_000,
            canton="ZH",
        )
        result = simulator.simulate(data)
        attendu = round(
            estimate_income_tax(90_000 * 0.85, "ZH", is_married=False), 2
        )
        assert result.impact_fiscal_apres["impot_conjoint_1"] == pytest.approx(
            attendu, abs=0.01
        )
        assert result.impact_fiscal_apres["impot_conjoint_2"] == pytest.approx(
            attendu, abs=0.01
        )

    def test_parent_gardien_au_bareme_parental(self, simulator):
        """Avec enfants, le parent gardien profite du bareme parental.

        Proxy etalon : bareme marie (LIFD art. 36 al. 2bis — le bareme
        parental est le bareme des personnes mariees pour qui vit avec des
        enfants). L'autre ex-conjoint reste au bareme celibataire.
        """
        from app.services.fiscal.cantonal_comparator import estimate_income_tax

        data = _base_input(
            nombre_enfants=2,
            revenu_annuel_conjoint_1=90_000,
            revenu_annuel_conjoint_2=90_000,
            canton="ZH",
        )
        result = simulator.simulate(data)
        gardien = round(
            estimate_income_tax(90_000 * 0.85, "ZH", is_married=True), 2
        )
        autre = round(
            estimate_income_tax(90_000 * 0.85, "ZH", is_married=False), 2
        )
        assert result.impact_fiscal_apres["impot_conjoint_1"] == pytest.approx(
            gardien, abs=0.01
        )
        assert result.impact_fiscal_apres["impot_conjoint_2"] == pytest.approx(
            autre, abs=0.01
        )

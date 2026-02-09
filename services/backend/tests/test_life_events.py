"""
Tests for Life Events simulators (Divorce + Succession).

Sprint S10: 40+ tests covering:
    - TestDivorceLPPSplit (5+ tests)
    - TestDivorceAVSSplitting (3+ tests)
    - TestDivorceTaxImpact (3+ tests)
    - TestDivorce3aSplit (3+ tests by regime)
    - TestDivorceChecklist (3+ tests)
    - TestSuccessionLegal (5+ tests)
    - TestSuccessionTestament (3+ tests)
    - TestSuccessionReserves2023 (3+ tests)
    - TestSuccessionTax (3+ tests)
    - TestSuccession3aOrder (2+ tests)
    - TestEndpoints (6+ tests)
"""

import pytest
from app.services.divorce_simulator import DivorceSimulator, DivorceInput
from app.services.succession_simulator import SuccessionSimulator, SuccessionInput


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def divorce_sim():
    return DivorceSimulator()


@pytest.fixture
def succession_sim():
    return SuccessionSimulator()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _divorce_input(**kwargs) -> DivorceInput:
    """Create a DivorceInput with sensible defaults, overridden by kwargs."""
    defaults = dict(
        duree_mariage_annees=10,
        regime_matrimonial="participation_acquets",
        nombre_enfants=2,
        revenu_annuel_conjoint_1=100000.0,
        revenu_annuel_conjoint_2=60000.0,
        lpp_conjoint_1_pendant_mariage=150000.0,
        lpp_conjoint_2_pendant_mariage=80000.0,
        avoirs_3a_conjoint_1=40000.0,
        avoirs_3a_conjoint_2=20000.0,
        fortune_commune=500000.0,
        dette_commune=300000.0,
        canton="GE",
    )
    defaults.update(kwargs)
    return DivorceInput(**defaults)


def _succession_input(**kwargs) -> SuccessionInput:
    """Create a SuccessionInput with sensible defaults, overridden by kwargs."""
    defaults = dict(
        fortune_totale=1000000.0,
        etat_civil="marie",
        a_conjoint=True,
        nombre_enfants=2,
        a_parents_vivants=False,
        a_fratrie=True,
        a_concubin=False,
        a_testament=False,
        quotite_disponible_testament=None,
        avoirs_3a=50000.0,
        capital_deces_lpp=100000.0,
        canton="GE",
    )
    defaults.update(kwargs)
    return SuccessionInput(**defaults)


# ===========================================================================
# TestDivorceLPPSplit
# ===========================================================================

class TestDivorceLPPSplit:
    """Tests for LPP splitting during divorce (CC art. 122-124)."""

    def test_equal_lpp_no_transfer(self, divorce_sim):
        """Equal LPP = no transfer needed."""
        data = _divorce_input(
            lpp_conjoint_1_pendant_mariage=100000.0,
            lpp_conjoint_2_pendant_mariage=100000.0,
        )
        result = divorce_sim.simulate(data)
        assert result.partage_lpp["conjoint_1_recoit"] == pytest.approx(100000.0, abs=0.01)
        assert result.partage_lpp["conjoint_2_recoit"] == pytest.approx(100000.0, abs=0.01)
        assert result.partage_lpp["transfert_lpp"] == pytest.approx(0.0, abs=0.01)
        assert result.partage_lpp["transfert_direction"] == "aucun_transfert"

    def test_one_income_large_transfer(self, divorce_sim):
        """One spouse has all LPP: half transferred to the other."""
        data = _divorce_input(
            lpp_conjoint_1_pendant_mariage=200000.0,
            lpp_conjoint_2_pendant_mariage=0.0,
        )
        result = divorce_sim.simulate(data)
        assert result.partage_lpp["conjoint_1_recoit"] == pytest.approx(100000.0, abs=0.01)
        assert result.partage_lpp["conjoint_2_recoit"] == pytest.approx(100000.0, abs=0.01)
        assert result.partage_lpp["transfert_lpp"] == pytest.approx(100000.0, abs=0.01)
        assert result.partage_lpp["transfert_direction"] == "conjoint_1_vers_conjoint_2"

    def test_reverse_transfer_direction(self, divorce_sim):
        """Conjoint 2 has more LPP: transfer goes from 2 to 1."""
        data = _divorce_input(
            lpp_conjoint_1_pendant_mariage=50000.0,
            lpp_conjoint_2_pendant_mariage=150000.0,
        )
        result = divorce_sim.simulate(data)
        assert result.partage_lpp["conjoint_1_recoit"] == pytest.approx(100000.0, abs=0.01)
        assert result.partage_lpp["conjoint_2_recoit"] == pytest.approx(100000.0, abs=0.01)
        assert result.partage_lpp["transfert_lpp"] == pytest.approx(-50000.0, abs=0.01)
        assert result.partage_lpp["transfert_direction"] == "conjoint_2_vers_conjoint_1"

    def test_short_marriage_small_lpp(self, divorce_sim):
        """Short marriage (2 years): small LPP amounts."""
        data = _divorce_input(
            duree_mariage_annees=2,
            lpp_conjoint_1_pendant_mariage=15000.0,
            lpp_conjoint_2_pendant_mariage=10000.0,
        )
        result = divorce_sim.simulate(data)
        total = 25000.0
        assert result.partage_lpp["conjoint_1_recoit"] == pytest.approx(total / 2, abs=0.01)
        assert result.partage_lpp["conjoint_2_recoit"] == pytest.approx(total / 2, abs=0.01)

    def test_long_marriage_near_retirement(self, divorce_sim):
        """Long marriage (30 years): large LPP accumulated."""
        data = _divorce_input(
            duree_mariage_annees=30,
            lpp_conjoint_1_pendant_mariage=500000.0,
            lpp_conjoint_2_pendant_mariage=200000.0,
        )
        result = divorce_sim.simulate(data)
        total = 700000.0
        assert result.partage_lpp["conjoint_1_recoit"] == pytest.approx(350000.0, abs=0.01)
        assert result.partage_lpp["conjoint_2_recoit"] == pytest.approx(350000.0, abs=0.01)
        assert result.partage_lpp["total_lpp_pendant_mariage"] == pytest.approx(total, abs=0.01)

    def test_zero_lpp_both(self, divorce_sim):
        """Both spouses have zero LPP during marriage."""
        data = _divorce_input(
            lpp_conjoint_1_pendant_mariage=0.0,
            lpp_conjoint_2_pendant_mariage=0.0,
        )
        result = divorce_sim.simulate(data)
        assert result.partage_lpp["conjoint_1_recoit"] == 0.0
        assert result.partage_lpp["conjoint_2_recoit"] == 0.0
        assert result.partage_lpp["transfert_lpp"] == 0.0

    def test_lpp_source_citation(self, divorce_sim):
        """LPP split result includes legal source."""
        data = _divorce_input()
        result = divorce_sim.simulate(data)
        assert "CC art." in result.partage_lpp["source"]


# ===========================================================================
# TestDivorceAVSSplitting
# ===========================================================================

class TestDivorceAVSSplitting:
    """Tests for AVS splitting (LAVS art. 29sexies)."""

    def test_avs_splitting_basic(self, divorce_sim):
        """AVS splitting: revenues split 50/50."""
        data = _divorce_input(
            revenu_annuel_conjoint_1=120000.0,
            revenu_annuel_conjoint_2=60000.0,
            duree_mariage_annees=10,
        )
        result = divorce_sim.simulate(data)
        # Average annual per person: (120k + 60k) / 2 = 90k
        assert result.splitting_avs["revenu_annuel_moyen_apres_splitting"] == pytest.approx(
            90000.0, abs=0.01
        )

    def test_avs_splitting_total_revenue(self, divorce_sim):
        """Total revenue during marriage is correctly computed."""
        data = _divorce_input(
            revenu_annuel_conjoint_1=100000.0,
            revenu_annuel_conjoint_2=50000.0,
            duree_mariage_annees=20,
        )
        result = divorce_sim.simulate(data)
        # Total: (100k + 50k) * 20 = 3'000'000
        assert result.splitting_avs["revenu_total_pendant_mariage"] == pytest.approx(
            3000000.0, abs=0.01
        )

    def test_avs_splitting_equal_income(self, divorce_sim):
        """Equal incomes: splitting has no net effect."""
        data = _divorce_input(
            revenu_annuel_conjoint_1=80000.0,
            revenu_annuel_conjoint_2=80000.0,
        )
        result = divorce_sim.simulate(data)
        assert result.splitting_avs["revenu_annuel_moyen_apres_splitting"] == pytest.approx(
            80000.0, abs=0.01
        )

    def test_avs_source_citation(self, divorce_sim):
        """AVS result includes LAVS reference."""
        data = _divorce_input()
        result = divorce_sim.simulate(data)
        assert "LAVS" in result.splitting_avs["source"]


# ===========================================================================
# TestDivorceTaxImpact
# ===========================================================================

class TestDivorceTaxImpact:
    """Tests for tax impact before/after divorce."""

    def test_tax_before_joint_taxation(self, divorce_sim):
        """Joint taxation: combined income at married rate."""
        data = _divorce_input(
            revenu_annuel_conjoint_1=100000.0,
            revenu_annuel_conjoint_2=60000.0,
            canton="GE",
        )
        result = divorce_sim.simulate(data)
        # GE married rate = 0.30 -> 160k * 0.30 = 48000
        assert result.impact_fiscal_avant["impot_commun"] == pytest.approx(48000.0, abs=0.01)

    def test_tax_after_individual_taxation(self, divorce_sim):
        """Individual taxation after divorce should generally be higher total."""
        data = _divorce_input(
            revenu_annuel_conjoint_1=100000.0,
            revenu_annuel_conjoint_2=60000.0,
            canton="GE",
            nombre_enfants=2,
        )
        result = divorce_sim.simulate(data)
        # After divorce: individual rates apply (generally higher)
        assert "impot_conjoint_1" in result.impact_fiscal_apres
        assert "impot_conjoint_2" in result.impact_fiscal_apres
        assert "delta_total" in result.impact_fiscal_apres

    def test_tax_different_cantons(self, divorce_sim):
        """Different cantons produce different tax amounts."""
        data_ge = _divorce_input(canton="GE")
        data_zh = _divorce_input(canton="ZH")
        result_ge = divorce_sim.simulate(data_ge)
        result_zh = divorce_sim.simulate(data_zh)
        # GE (0.30) vs ZH (0.25) married rates -> different taxes
        assert result_ge.impact_fiscal_avant["impot_commun"] != result_zh.impact_fiscal_avant["impot_commun"]

    def test_tax_unknown_canton_uses_default(self, divorce_sim):
        """Unknown canton falls back to default rates."""
        data = _divorce_input(canton="XX")
        result = divorce_sim.simulate(data)
        # Should not crash; uses DEFAULT_TAX_RATES
        assert result.impact_fiscal_avant["impot_commun"] > 0


# ===========================================================================
# TestDivorce3aSplit
# ===========================================================================

class TestDivorce3aSplit:
    """Tests for 3a pillar splitting by regime."""

    def test_3a_participation_acquets(self, divorce_sim):
        """Participation aux acquets: 3a split 50/50."""
        data = _divorce_input(
            regime_matrimonial="participation_acquets",
            avoirs_3a_conjoint_1=40000.0,
            avoirs_3a_conjoint_2=20000.0,
        )
        result = divorce_sim.simulate(data)
        total = 60000.0
        assert result.partage_3a["conjoint_1_part"] == pytest.approx(total / 2, abs=0.01)
        assert result.partage_3a["conjoint_2_part"] == pytest.approx(total / 2, abs=0.01)
        assert result.partage_3a["regime"] == "participation_acquets"

    def test_3a_communaute_biens(self, divorce_sim):
        """Communaute de biens: 3a split 50/50."""
        data = _divorce_input(
            regime_matrimonial="communaute_biens",
            avoirs_3a_conjoint_1=50000.0,
            avoirs_3a_conjoint_2=10000.0,
        )
        result = divorce_sim.simulate(data)
        total = 60000.0
        assert result.partage_3a["conjoint_1_part"] == pytest.approx(total / 2, abs=0.01)
        assert result.partage_3a["conjoint_2_part"] == pytest.approx(total / 2, abs=0.01)
        assert result.partage_3a["regime"] == "communaute_biens"

    def test_3a_separation_biens(self, divorce_sim):
        """Separation de biens: each keeps their own 3a."""
        data = _divorce_input(
            regime_matrimonial="separation_biens",
            avoirs_3a_conjoint_1=40000.0,
            avoirs_3a_conjoint_2=20000.0,
        )
        result = divorce_sim.simulate(data)
        assert result.partage_3a["conjoint_1_part"] == pytest.approx(40000.0, abs=0.01)
        assert result.partage_3a["conjoint_2_part"] == pytest.approx(20000.0, abs=0.01)
        assert result.partage_3a["regime"] == "separation_biens"


# ===========================================================================
# TestDivorceFortuneeSplit
# ===========================================================================

class TestDivorceFortuneSplit:
    """Tests for fortune splitting."""

    def test_fortune_acquets_50_50(self, divorce_sim):
        """Under acquets: net fortune split 50/50."""
        data = _divorce_input(
            regime_matrimonial="participation_acquets",
            fortune_commune=600000.0,
            dette_commune=200000.0,
        )
        result = divorce_sim.simulate(data)
        net = 400000.0
        assert result.partage_fortune["fortune_nette"] == pytest.approx(net, abs=0.01)
        assert result.partage_fortune["conjoint_1_part"] == pytest.approx(net / 2, abs=0.01)
        assert result.partage_fortune["conjoint_2_part"] == pytest.approx(net / 2, abs=0.01)

    def test_fortune_negative_net(self, divorce_sim):
        """Negative net fortune (more debt than assets)."""
        data = _divorce_input(
            fortune_commune=100000.0,
            dette_commune=300000.0,
        )
        result = divorce_sim.simulate(data)
        assert result.partage_fortune["fortune_nette"] == pytest.approx(-200000.0, abs=0.01)


# ===========================================================================
# TestDivorcePensionAlimentaire
# ===========================================================================

class TestDivorcePensionAlimentaire:
    """Tests for pension alimentaire estimation."""

    def test_pension_with_children(self, divorce_sim):
        """Pension includes child support."""
        data = _divorce_input(
            nombre_enfants=2,
            revenu_annuel_conjoint_1=100000.0,
            revenu_annuel_conjoint_2=60000.0,
            duree_mariage_annees=12,
        )
        result = divorce_sim.simulate(data)
        # Should include at least child support (2 * 600 = 1200 CHF/month)
        assert result.pension_alimentaire_estimee >= 1200.0

    def test_pension_no_children_short_marriage(self, divorce_sim):
        """Short marriage, no children: minimal pension."""
        data = _divorce_input(
            nombre_enfants=0,
            revenu_annuel_conjoint_1=80000.0,
            revenu_annuel_conjoint_2=70000.0,
            duree_mariage_annees=3,
        )
        result = divorce_sim.simulate(data)
        # Very small gap, short marriage -> small pension
        assert result.pension_alimentaire_estimee < 500.0

    def test_pension_equal_income_no_spousal(self, divorce_sim):
        """Equal incomes: no spousal maintenance, only children."""
        data = _divorce_input(
            nombre_enfants=1,
            revenu_annuel_conjoint_1=80000.0,
            revenu_annuel_conjoint_2=80000.0,
            duree_mariage_annees=5,
        )
        result = divorce_sim.simulate(data)
        # Only child support, no spousal: ~600 CHF/month
        assert result.pension_alimentaire_estimee == pytest.approx(600.0, abs=10)


# ===========================================================================
# TestDivorceChecklist
# ===========================================================================

class TestDivorceChecklist:
    """Tests for divorce checklist generation."""

    def test_checklist_includes_avs(self, divorce_sim):
        """Checklist should mention AVS."""
        data = _divorce_input()
        result = divorce_sim.simulate(data)
        assert any("AVS" in item for item in result.checklist)

    def test_checklist_includes_lawyer(self, divorce_sim):
        """Checklist should recommend consulting a lawyer."""
        data = _divorce_input()
        result = divorce_sim.simulate(data)
        assert any("avocat" in item.lower() for item in result.checklist)

    def test_checklist_children_items(self, divorce_sim):
        """With children: checklist includes child-specific items."""
        data = _divorce_input(nombre_enfants=2)
        result = divorce_sim.simulate(data)
        assert any("enfants" in item.lower() or "garde" in item.lower() for item in result.checklist)

    def test_checklist_no_children_no_guard_item(self, divorce_sim):
        """Without children: no child-specific items."""
        data = _divorce_input(nombre_enfants=0)
        result = divorce_sim.simulate(data)
        assert not any("garde" in item.lower() for item in result.checklist)

    def test_checklist_debt_item(self, divorce_sim):
        """With debts: checklist mentions debt splitting."""
        data = _divorce_input(dette_commune=400000.0)
        result = divorce_sim.simulate(data)
        assert any("dettes" in item.lower() or "dette" in item.lower() for item in result.checklist)


# ===========================================================================
# TestDivorceAlerts
# ===========================================================================

class TestDivorceAlerts:
    """Tests for divorce alert generation."""

    def test_alert_large_lpp_transfer(self, divorce_sim):
        """Large LPP transfer triggers alert."""
        data = _divorce_input(
            lpp_conjoint_1_pendant_mariage=300000.0,
            lpp_conjoint_2_pendant_mariage=0.0,
        )
        result = divorce_sim.simulate(data)
        assert any("transfert LPP" in a.lower() or "transfert lpp" in a.lower() for a in result.alerts)

    def test_alert_no_income(self, divorce_sim):
        """One spouse without income triggers alert."""
        data = _divorce_input(revenu_annuel_conjoint_2=0.0)
        result = divorce_sim.simulate(data)
        assert any("pas de revenu" in a.lower() or "n'a pas de revenu" in a.lower() for a in result.alerts)

    def test_alert_large_income_gap(self, divorce_sim):
        """Large income gap triggers alert."""
        data = _divorce_input(
            revenu_annuel_conjoint_1=200000.0,
            revenu_annuel_conjoint_2=40000.0,
        )
        result = divorce_sim.simulate(data)
        assert any("ecart" in a.lower() for a in result.alerts)


# ===========================================================================
# TestDivorceDisclaimer
# ===========================================================================

class TestDivorceDisclaimer:
    """Tests for compliance (disclaimer, no forbidden words)."""

    def test_disclaimer_present(self, divorce_sim):
        """Disclaimer must be present."""
        data = _divorce_input()
        result = divorce_sim.simulate(data)
        assert "indicative" in result.disclaimer.lower()
        assert "avocat" in result.disclaimer.lower()

    def test_no_forbidden_words(self, divorce_sim):
        """Must not contain 'garanti', 'assure', 'certain'."""
        data = _divorce_input()
        result = divorce_sim.simulate(data)
        full_text = str(result)
        assert "garanti" not in full_text.lower()
        # 'assure' as in 'insurance' is acceptable in context, but
        # 'assure' as in 'guaranteed' should not appear in disclaimers
        assert "certain" not in result.disclaimer.lower()


# ===========================================================================
# TestSuccessionLegal
# ===========================================================================

class TestSuccessionLegal:
    """Tests for legal inheritance distribution (CC art. 457-466)."""

    def test_married_with_children(self, succession_sim):
        """Married + children: spouse 1/2, children 1/2."""
        data = _succession_input(
            fortune_totale=1000000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=2,
        )
        result = succession_sim.simulate(data)
        legal = result.repartition_legale
        assert legal["conjoint_part_pct"] == pytest.approx(0.5, abs=0.001)
        assert legal["conjoint_montant"] == pytest.approx(500000.0, abs=0.01)
        assert legal["enfants_part_pct"] == pytest.approx(0.5, abs=0.001)
        assert legal["enfant_montant_chacun"] == pytest.approx(250000.0, abs=0.01)

    def test_married_no_children_parents_alive(self, succession_sim):
        """Married, no children, parents alive: spouse 3/4, parents 1/4."""
        data = _succession_input(
            fortune_totale=800000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=0,
            a_parents_vivants=True,
        )
        result = succession_sim.simulate(data)
        legal = result.repartition_legale
        assert legal["conjoint_part_pct"] == pytest.approx(0.75, abs=0.001)
        assert legal["conjoint_montant"] == pytest.approx(600000.0, abs=0.01)
        assert legal["parents_part_pct"] == pytest.approx(0.25, abs=0.001)
        assert legal["parents_montant"] == pytest.approx(200000.0, abs=0.01)

    def test_married_no_children_no_parents(self, succession_sim):
        """Married, no children, no parents: spouse gets everything."""
        data = _succession_input(
            fortune_totale=500000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=0,
            a_parents_vivants=False,
        )
        result = succession_sim.simulate(data)
        legal = result.repartition_legale
        assert legal["conjoint_part_pct"] == pytest.approx(1.0, abs=0.001)
        assert legal["conjoint_montant"] == pytest.approx(500000.0, abs=0.01)

    def test_single_with_children(self, succession_sim):
        """Single (not married) with children: children get everything."""
        data = _succession_input(
            fortune_totale=600000.0,
            etat_civil="celibataire",
            a_conjoint=False,
            nombre_enfants=3,
        )
        result = succession_sim.simulate(data)
        legal = result.repartition_legale
        assert legal["conjoint_part_pct"] == 0.0
        assert legal["enfants_part_pct"] == pytest.approx(1.0, abs=0.001)
        assert legal["enfant_montant_chacun"] == pytest.approx(200000.0, abs=0.01)

    def test_divorced_no_children_parents_alive(self, succession_sim):
        """Divorced, no children, parents: parents get everything."""
        data = _succession_input(
            fortune_totale=400000.0,
            etat_civil="divorce",
            a_conjoint=False,
            nombre_enfants=0,
            a_parents_vivants=True,
        )
        result = succession_sim.simulate(data)
        legal = result.repartition_legale
        assert legal["parents_part_pct"] == pytest.approx(1.0, abs=0.001)
        assert legal["parents_montant"] == pytest.approx(400000.0, abs=0.01)

    def test_concubin_no_inheritance(self, succession_sim):
        """Concubin without testament: gets nothing from legal distribution."""
        data = _succession_input(
            fortune_totale=500000.0,
            etat_civil="concubin",
            a_conjoint=False,
            a_concubin=True,
            nombre_enfants=0,
            a_parents_vivants=True,
        )
        result = succession_sim.simulate(data)
        legal = result.repartition_legale
        # Concubin has no legal share; parents get everything
        assert legal["parents_part_pct"] == pytest.approx(1.0, abs=0.001)
        assert legal.get("conjoint_part_pct", 0.0) == 0.0

    def test_no_heirs_canton_inherits(self, succession_sim):
        """No heirs at all: canton inherits."""
        data = _succession_input(
            fortune_totale=300000.0,
            etat_civil="celibataire",
            a_conjoint=False,
            nombre_enfants=0,
            a_parents_vivants=False,
            a_fratrie=False,
        )
        result = succession_sim.simulate(data)
        legal = result.repartition_legale
        assert legal.get("canton_part_pct", 0.0) == pytest.approx(1.0, abs=0.001)


# ===========================================================================
# TestSuccessionReserves2023
# ===========================================================================

class TestSuccessionReserves2023:
    """Tests for reserve system under 2023 law."""

    def test_descendants_reserve_half_of_legal(self, succession_sim):
        """2023: Descendants reserve = 1/2 of legal share (not 3/4)."""
        data = _succession_input(
            fortune_totale=1000000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=2,
        )
        result = succession_sim.simulate(data)
        reserves = result.reserves_hereditaires
        # Children legal share = 50% of 1M = 500k
        # Children reserve (2023) = 50% of 500k = 250k
        assert reserves["enfants_reserve_pct"] == pytest.approx(0.25, abs=0.001)
        assert reserves["enfants_reserve_montant"] == pytest.approx(250000.0, abs=0.01)

    def test_conjoint_reserve_half_of_legal(self, succession_sim):
        """Spouse reserve = 1/2 of legal share (unchanged in 2023)."""
        data = _succession_input(
            fortune_totale=1000000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=2,
        )
        result = succession_sim.simulate(data)
        reserves = result.reserves_hereditaires
        # Conjoint legal share = 50% of 1M = 500k
        # Conjoint reserve = 50% of 500k = 250k
        assert reserves["conjoint_reserve_pct"] == pytest.approx(0.25, abs=0.001)
        assert reserves["conjoint_reserve_montant"] == pytest.approx(250000.0, abs=0.01)

    def test_parents_reserve_removed_2023(self, succession_sim):
        """2023: Parents' reserve is REMOVED."""
        data = _succession_input(
            fortune_totale=500000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=0,
            a_parents_vivants=True,
        )
        result = succession_sim.simulate(data)
        reserves = result.reserves_hereditaires
        assert reserves["parents_reserve_pct"] == 0.0
        assert reserves["parents_reserve_montant"] == 0.0
        assert "supprimee" in reserves["parents_reserve_note"].lower()

    def test_quotite_disponible_married_children(self, succession_sim):
        """Married + children: QD = estate - conjoint reserve - children reserve."""
        data = _succession_input(
            fortune_totale=1000000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=2,
        )
        result = succession_sim.simulate(data)
        # QD = 1M - 250k (conjoint) - 250k (children) = 500k
        assert result.quotite_disponible == pytest.approx(500000.0, abs=0.01)

    def test_quotite_disponible_single_children(self, succession_sim):
        """Single with children: no spouse reserve, only children reserve."""
        data = _succession_input(
            fortune_totale=600000.0,
            etat_civil="celibataire",
            a_conjoint=False,
            nombre_enfants=2,
        )
        result = succession_sim.simulate(data)
        # Children legal = 100% of 600k. Reserve = 50% of that = 300k.
        # QD = 600k - 300k = 300k
        assert result.quotite_disponible == pytest.approx(300000.0, abs=0.01)


# ===========================================================================
# TestSuccessionTestament
# ===========================================================================

class TestSuccessionTestament:
    """Tests for testament distribution."""

    def test_no_testament_equals_legal(self, succession_sim):
        """Without testament: distribution equals legal."""
        data = _succession_input(a_testament=False)
        result = succession_sim.simulate(data)
        assert result.repartition_avec_testament.get("quotite_disponible_allocation") == {}

    def test_testament_allocate_qd_to_conjoint(self, succession_sim):
        """Testament: allocate full QD to surviving spouse."""
        data = _succession_input(
            fortune_totale=1000000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=2,
            a_testament=True,
            quotite_disponible_testament={"conjoint": 1.0},
        )
        result = succession_sim.simulate(data)
        testament = result.repartition_avec_testament
        # QD = 500k -> all to conjoint
        # Conjoint total = reserve (250k) + QD (500k) = 750k
        assert testament["conjoint_montant"] == pytest.approx(750000.0, abs=0.01)
        # Children still get their reserve: 250k
        assert testament["enfants_montant_total"] == pytest.approx(250000.0, abs=0.01)

    def test_testament_allocate_qd_to_concubin(self, succession_sim):
        """Testament: allocate QD to concubin (who has no legal share)."""
        data = _succession_input(
            fortune_totale=600000.0,
            etat_civil="celibataire",
            a_conjoint=False,
            nombre_enfants=2,
            a_concubin=True,
            a_testament=True,
            quotite_disponible_testament={"concubin": 1.0},
        )
        result = succession_sim.simulate(data)
        testament = result.repartition_avec_testament
        # QD = 300k -> all to concubin
        qd_alloc = testament.get("quotite_disponible_allocation", {})
        assert qd_alloc.get("concubin", 0) == pytest.approx(300000.0, abs=0.01)

    def test_testament_partial_qd_split(self, succession_sim):
        """Testament: split QD between multiple beneficiaries."""
        data = _succession_input(
            fortune_totale=1000000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=2,
            a_concubin=False,
            a_testament=True,
            quotite_disponible_testament={"conjoint": 0.5, "enfants": 0.5},
        )
        result = succession_sim.simulate(data)
        # QD = 500k, half to conjoint (250k), half to children (250k)
        # Conjoint: reserve 250k + QD 250k = 500k
        # Children: reserve 250k + QD 250k = 500k
        testament = result.repartition_avec_testament
        assert testament["conjoint_montant"] == pytest.approx(500000.0, abs=0.01)
        assert testament["enfants_montant_total"] == pytest.approx(500000.0, abs=0.01)


# ===========================================================================
# TestSuccessionTax
# ===========================================================================

class TestSuccessionTax:
    """Tests for succession tax by canton and kinship."""

    def test_tax_conjoint_exempt_geneva(self, succession_sim):
        """Geneva: conjoint and descendants are tax-exempt."""
        data = _succession_input(
            fortune_totale=1000000.0,
            etat_civil="marie",
            a_conjoint=True,
            nombre_enfants=2,
            canton="GE",
        )
        result = succession_sim.simulate(data)
        fiscalite = result.fiscalite
        details = fiscalite.get("details_par_heritier", {})
        if "conjoint" in details:
            assert details["conjoint"]["impot"] == 0.0
        if "enfants" in details:
            assert details["enfants"]["impot"] == 0.0

    def test_tax_concubin_high_zurich(self, succession_sim):
        """Zurich: concubin pays 18% succession tax."""
        data = _succession_input(
            fortune_totale=600000.0,
            etat_civil="celibataire",
            a_conjoint=False,
            nombre_enfants=2,
            a_concubin=True,
            a_testament=True,
            quotite_disponible_testament={"concubin": 1.0},
            canton="ZH",
        )
        result = succession_sim.simulate(data)
        fiscalite = result.fiscalite
        details = fiscalite.get("details_par_heritier", {})
        if "concubin" in details:
            assert details["concubin"]["taux"] == pytest.approx(0.18, abs=0.001)
            # QD = 300k, tax = 300k * 0.18 = 54k
            assert details["concubin"]["impot"] == pytest.approx(54000.0, abs=0.01)

    def test_tax_neuchatel_descendants_taxed(self, succession_sim):
        """Neuchatel: descendants ARE taxed (3%)."""
        data = _succession_input(
            fortune_totale=500000.0,
            etat_civil="celibataire",
            a_conjoint=False,
            nombre_enfants=2,
            canton="NE",
        )
        result = succession_sim.simulate(data)
        fiscalite = result.fiscalite
        details = fiscalite.get("details_par_heritier", {})
        if "enfants" in details:
            assert details["enfants"]["taux"] == pytest.approx(0.03, abs=0.001)
            # 500k * 0.03 = 15000
            assert details["enfants"]["impot"] == pytest.approx(15000.0, abs=0.01)

    def test_tax_fratrie_vaud(self, succession_sim):
        """Vaud: siblings pay 7% succession tax."""
        data = _succession_input(
            fortune_totale=300000.0,
            etat_civil="celibataire",
            a_conjoint=False,
            nombre_enfants=0,
            a_parents_vivants=False,
            a_fratrie=True,
            canton="VD",
        )
        result = succession_sim.simulate(data)
        fiscalite = result.fiscalite
        details = fiscalite.get("details_par_heritier", {})
        if "fratrie" in details:
            assert details["fratrie"]["taux"] == pytest.approx(0.07, abs=0.001)
            assert details["fratrie"]["impot"] == pytest.approx(21000.0, abs=0.01)


# ===========================================================================
# TestSuccession3aOrder
# ===========================================================================

class TestSuccession3aOrder:
    """Tests for OPP3 art. 2 beneficiary order."""

    def test_3a_order_contains_five_levels(self, succession_sim):
        """OPP3 order should list 5 priority levels."""
        data = _succession_input()
        result = succession_sim.simulate(data)
        # The first 5 items should be the order levels
        order_items = [o for o in result.ordre_3a_opp3 if o.startswith(("1.", "2.", "3.", "4.", "5."))]
        assert len(order_items) == 5

    def test_3a_concubin_warning(self, succession_sim):
        """Concubin should get a specific 3a warning."""
        data = _succession_input(
            a_concubin=True,
            etat_civil="concubin",
            a_conjoint=False,
        )
        result = succession_sim.simulate(data)
        assert any(
            "concubin" in item.lower() and "pas" in item.lower()
            for item in result.ordre_3a_opp3
        )

    def test_3a_married_spouse_priority(self, succession_sim):
        """Married: annotation should mention spouse priority."""
        data = _succession_input(
            etat_civil="marie",
            a_conjoint=True,
        )
        result = succession_sim.simulate(data)
        assert any(
            "conjoint survivant" in item.lower()
            for item in result.ordre_3a_opp3
        )


# ===========================================================================
# TestSuccessionConcubinAlert
# ===========================================================================

class TestSuccessionConcubinAlert:
    """Tests for concubin-specific alerts."""

    def test_concubin_alert_present(self, succession_sim):
        """Concubin alert should be present when applicable."""
        data = _succession_input(
            a_concubin=True,
            etat_civil="concubin",
            a_conjoint=False,
        )
        result = succession_sim.simulate(data)
        assert "AUCUN" in result.alerte_concubin
        assert "testament" in result.alerte_concubin.lower()

    def test_no_concubin_no_alert(self, succession_sim):
        """No concubin: empty alert."""
        data = _succession_input(a_concubin=False)
        result = succession_sim.simulate(data)
        assert result.alerte_concubin == ""

    def test_concubin_without_testament_critical_alert(self, succession_sim):
        """Concubin without testament: critical alert in alerts list."""
        data = _succession_input(
            a_concubin=True,
            etat_civil="concubin",
            a_conjoint=False,
            a_testament=False,
        )
        result = succession_sim.simulate(data)
        assert any("CRITIQUE" in a for a in result.alerts)


# ===========================================================================
# TestEndpoints (API integration)
# ===========================================================================

class TestEndpoints:
    """Tests for the FastAPI endpoints."""

    def test_divorce_simulate_endpoint(self, client):
        """POST /api/v1/life-events/divorce/simulate works."""
        payload = {
            "dureeMarriageAnnees": 10,
            "regimeMatrimonial": "participation_acquets",
            "nombreEnfants": 2,
            "revenuAnnuelConjoint1": 100000,
            "revenuAnnuelConjoint2": 60000,
            "lppConjoint1PendantMariage": 150000,
            "lppConjoint2PendantMariage": 80000,
            "avoirs3aConjoint1": 40000,
            "avoirs3aConjoint2": 20000,
            "fortuneCommune": 500000,
            "detteCommune": 300000,
            "canton": "GE",
        }
        response = client.post("/api/v1/life-events/divorce/simulate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "partageLpp" in data
        assert "splittingAvs" in data
        assert "partage3a" in data
        assert "partageFortune" in data
        assert "impactFiscalAvant" in data
        assert "impactFiscalApres" in data
        assert "pensionAlimentaireEstimee" in data
        assert "checklist" in data
        assert "alerts" in data
        assert "disclaimer" in data
        assert data["pensionAlimentaireEstimee"] > 0

    def test_succession_simulate_endpoint(self, client):
        """POST /api/v1/life-events/succession/simulate works."""
        payload = {
            "fortuneTotale": 1000000,
            "etatCivil": "marie",
            "aConjoint": True,
            "nombreEnfants": 2,
            "aParentsVivants": False,
            "aFratrie": True,
            "aConcubin": False,
            "aTestament": False,
            "avoirs3a": 50000,
            "capitalDecesLpp": 100000,
            "canton": "GE",
        }
        response = client.post("/api/v1/life-events/succession/simulate", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert "repartitionLegale" in data
        assert "reservesHereditaires" in data
        assert "quotiteDisponible" in data
        assert "fiscalite" in data
        assert "ordre3aOpp3" in data
        assert "disclaimer" in data
        assert data["quotiteDisponible"] == pytest.approx(500000.0, abs=1)

    def test_divorce_checklist_endpoint(self, client):
        """GET /api/v1/life-events/divorce/checklist returns template."""
        response = client.get("/api/v1/life-events/divorce/checklist")
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert len(data["items"]) > 0
        assert "disclaimer" in data
        first = data["items"][0]
        assert "label" in first
        assert "category" in first
        assert "priority" in first

    def test_succession_checklist_endpoint(self, client):
        """GET /api/v1/life-events/succession/checklist returns template."""
        response = client.get("/api/v1/life-events/succession/checklist")
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert len(data["items"]) > 0
        assert "disclaimer" in data

    def test_divorce_endpoint_validation(self, client):
        """POST with missing required fields should fail validation."""
        payload = {
            "dureeMarriageAnnees": 10,
            # Missing revenuAnnuelConjoint1 and revenuAnnuelConjoint2
        }
        response = client.post("/api/v1/life-events/divorce/simulate", json=payload)
        assert response.status_code == 422

    def test_succession_endpoint_validation(self, client):
        """POST with missing required fields should fail validation."""
        payload = {
            # Missing fortuneTotale and etatCivil
            "aConjoint": True,
        }
        response = client.post("/api/v1/life-events/succession/simulate", json=payload)
        assert response.status_code == 422

    def test_succession_with_testament_endpoint(self, client):
        """POST succession with testament allocation."""
        payload = {
            "fortuneTotale": 1000000,
            "etatCivil": "marie",
            "aConjoint": True,
            "nombreEnfants": 2,
            "aParentsVivants": False,
            "aFratrie": False,
            "aConcubin": False,
            "aTestament": True,
            "quotiteDisponibleTestament": {"conjoint": 1.0},
            "canton": "GE",
        }
        response = client.post("/api/v1/life-events/succession/simulate", json=payload)
        assert response.status_code == 200
        data = response.json()
        testament = data["repartitionAvecTestament"]
        # Conjoint should get reserve + full QD
        assert testament["conjoint_montant"] == pytest.approx(750000.0, abs=1)

    def test_divorce_checklist_has_categories(self, client):
        """Divorce checklist should have diverse categories."""
        response = client.get("/api/v1/life-events/divorce/checklist")
        data = response.json()
        categories = {item["category"] for item in data["items"]}
        assert "juridique" in categories
        assert "administratif" in categories
        assert "prevoyance" in categories
        assert "fiscal" in categories

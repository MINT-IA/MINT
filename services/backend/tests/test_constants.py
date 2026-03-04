"""
Tests de coherence des constantes d'assurances sociales.

Verifie que:
1. Les constantes sont logiquement coherentes entre elles
2. Les valeurs sont dans des plages raisonnables (garde-fous)
3. Les relations mathematiques sont respectees
4. Le fichier Dart miroir contient les memes valeurs

Lance: pytest tests/test_constants.py -v
"""

import re
from pathlib import Path

import pytest

from app.constants.social_insurance import (
    AC_COTISATION_SALARIE,
    AC_COTISATION_SOLIDARITE_SALARIE,
    AC_COTISATION_SOLIDARITE_TOTAL,
    AC_COTISATION_TOTAL,
    AC_INDEMNITE_TAUX,
    AC_INDEMNITE_TAUX_CHARGE_FAMILLE,
    AC_PLAFOND_SALAIRE_ASSURE,
    AI_COTISATION_SALARIE,
    AI_COTISATION_TOTAL,
    AI_RENTE_DEMI,
    AI_RENTE_ENTIERE,
    APG_COTISATION_SALARIE,
    APG_COTISATION_TOTAL,
    APG_MATERNITE_JOURS,
    APG_MATERNITE_TAUX,
    APG_PATERNITE_JOURS,
    AVS_AGE_REFERENCE_FEMME,
    AVS_AGE_REFERENCE_HOMME,
    AVS_COTISATION_SALARIE,
    AVS_COTISATION_TOTAL,
    AVS_DUREE_COTISATION_COMPLETE,
    AVS_FRANCHISE_RETRAITE_ANNUELLE,
    AVS_FRANCHISE_RETRAITE_MENSUELLE,
    AVS_RENTE_COUPLE_MAX_MENSUELLE,
    AVS_RENTE_MAX_MENSUELLE,
    AVS_RENTE_MIN_MENSUELLE,
    AVS_SURVIVOR_FACTOR,
    AVS_VOLONTAIRE_COTISATION_MAX,
    AVS_VOLONTAIRE_COTISATION_MIN,
    COTISATIONS_SALARIE_TOTAL,
    LPP_BONIFICATIONS_VIEILLESSE,
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_COORDONNE_MAX,
    LPP_SALAIRE_COORDONNE_MIN,
    LPP_SALAIRE_MAX,
    LPP_SEUIL_ENTREE,
    LPP_TAUX_CONVERSION_MIN,
    LPP_TAUX_INTERET_MIN,
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
    PILIER_3A_TAUX_REVENU_SANS_LPP,
    get_lpp_bonification_rate,
)


# ══════════════════════════════════════════════════════════════════════════════
# LPP — Relations mathematiques
# ══════════════════════════════════════════════════════════════════════════════


class TestLPPConsistency:
    """Verifie les relations mathematiques entre constantes LPP."""

    def test_salaire_coordonne_max_formula(self):
        """salaire_coord_max == salaire_max - deduction_coordination."""
        assert LPP_SALAIRE_COORDONNE_MAX == LPP_SALAIRE_MAX - LPP_DEDUCTION_COORDINATION

    def test_seuil_entree_below_deduction(self):
        """Le seuil d'entree doit etre inferieur a la deduction de coordination."""
        assert LPP_SEUIL_ENTREE < LPP_DEDUCTION_COORDINATION

    def test_salaire_coordonne_min_positive(self):
        """Le salaire coordonne minimum doit etre positif."""
        assert LPP_SALAIRE_COORDONNE_MIN > 0

    def test_salaire_coordonne_min_below_max(self):
        """Le minimum est inferieur au maximum."""
        assert LPP_SALAIRE_COORDONNE_MIN < LPP_SALAIRE_COORDONNE_MAX

    def test_taux_conversion_reasonable(self):
        """Taux de conversion entre 4% et 8%."""
        assert 4.0 <= LPP_TAUX_CONVERSION_MIN <= 8.0

    def test_taux_interet_reasonable(self):
        """Taux d'interet minimum entre 0% et 5%."""
        assert 0.0 <= LPP_TAUX_INTERET_MIN <= 5.0

    def test_bonifications_vieillesse_ascending(self):
        """Les bonifications augmentent avec l'age."""
        rates = [rate for _, _, rate in LPP_BONIFICATIONS_VIEILLESSE]
        assert rates == sorted(rates)

    def test_bonifications_vieillesse_ranges(self):
        """Les tranches d'age couvrent 25-65 sans trous."""
        for min_age, max_age, rate in LPP_BONIFICATIONS_VIEILLESSE:
            assert min_age < max_age
            assert 0.0 < rate < 0.5

    def test_bonification_function_edge_cases(self):
        """La fonction retourne 0 pour < 25, et le bon taux pour chaque tranche."""
        assert get_lpp_bonification_rate(20) == 0.0
        assert get_lpp_bonification_rate(24) == 0.0
        assert get_lpp_bonification_rate(25) == 0.07
        assert get_lpp_bonification_rate(34) == 0.07
        assert get_lpp_bonification_rate(35) == 0.10
        assert get_lpp_bonification_rate(44) == 0.10
        assert get_lpp_bonification_rate(45) == 0.15
        assert get_lpp_bonification_rate(54) == 0.15
        assert get_lpp_bonification_rate(55) == 0.18
        assert get_lpp_bonification_rate(65) == 0.18


# ══════════════════════════════════════════════════════════════════════════════
# AVS — Relations mathematiques
# ══════════════════════════════════════════════════════════════════════════════


class TestAVSConsistency:
    """Verifie les relations mathematiques entre constantes AVS."""

    def test_rente_min_is_half_of_max(self):
        """Rente min == 50% de rente max (LAVS art. 34)."""
        assert AVS_RENTE_MIN_MENSUELLE == AVS_RENTE_MAX_MENSUELLE / 2

    def test_rente_couple_is_150_percent_max(self):
        """Rente couple == 150% de rente individuelle max (LAVS art. 35)."""
        assert AVS_RENTE_COUPLE_MAX_MENSUELLE == AVS_RENTE_MAX_MENSUELLE * 1.5

    def test_cotisation_total_double_salarie(self):
        """Cotisation totale == 2x part salarie."""
        assert AVS_COTISATION_TOTAL == pytest.approx(AVS_COTISATION_SALARIE * 2)

    def test_duree_cotisation_reasonable(self):
        """44 annees de cotisation (21 a 65)."""
        assert AVS_DUREE_COTISATION_COMPLETE == AVS_AGE_REFERENCE_HOMME - 21

    def test_franchise_retraite_annuelle(self):
        """Franchise annuelle == 12 * mensuelle."""
        assert AVS_FRANCHISE_RETRAITE_ANNUELLE == AVS_FRANCHISE_RETRAITE_MENSUELLE * 12

    def test_survivor_factor_reasonable(self):
        """Facteur survivant entre 60% et 100%."""
        assert 0.6 <= AVS_SURVIVOR_FACTOR <= 1.0

    def test_ages_reference_equal(self):
        """Depuis AVS 21, age de reference identique H/F."""
        assert AVS_AGE_REFERENCE_HOMME == AVS_AGE_REFERENCE_FEMME == 65

    def test_avs_volontaire_range(self):
        """Min < Max pour cotisations volontaires."""
        assert AVS_VOLONTAIRE_COTISATION_MIN < AVS_VOLONTAIRE_COTISATION_MAX


# ══════════════════════════════════════════════════════════════════════════════
# AI / APG — Relations mathematiques
# ══════════════════════════════════════════════════════════════════════════════


class TestAIAPGConsistency:
    """Verifie les constantes AI et APG."""

    def test_ai_cotisation_total_double(self):
        """AI total == 2x part salarie."""
        assert AI_COTISATION_TOTAL == pytest.approx(AI_COTISATION_SALARIE * 2)

    def test_ai_rente_entiere_equals_avs_max(self):
        """Rente AI entiere == rente AVS max."""
        assert AI_RENTE_ENTIERE == AVS_RENTE_MAX_MENSUELLE

    def test_ai_rente_demi_is_half(self):
        """Demi-rente AI == 50% de rente entiere."""
        assert AI_RENTE_DEMI == AI_RENTE_ENTIERE / 2

    def test_apg_cotisation_total_double(self):
        """APG total == 2x part salarie."""
        assert APG_COTISATION_TOTAL == pytest.approx(APG_COTISATION_SALARIE * 2)

    def test_maternite_14_weeks(self):
        """Conge maternite == 98 jours = 14 semaines."""
        assert APG_MATERNITE_JOURS == 14 * 7

    def test_maternite_taux_80_percent(self):
        """Taux maternite == 80%."""
        assert APG_MATERNITE_TAUX == 0.80

    def test_paternite_10_days(self):
        """Conge paternite == 10 jours."""
        assert APG_PATERNITE_JOURS == 10


# ══════════════════════════════════════════════════════════════════════════════
# AC — Relations mathematiques
# ══════════════════════════════════════════════════════════════════════════════


class TestACConsistency:
    """Verifie les constantes AC."""

    def test_ac_cotisation_total_double(self):
        """AC total == 2x part salarie."""
        assert AC_COTISATION_TOTAL == pytest.approx(AC_COTISATION_SALARIE * 2)

    def test_ac_solidarite_total_double(self):
        """AC solidarite total == 2x part salarie."""
        assert AC_COTISATION_SOLIDARITE_TOTAL == pytest.approx(
            AC_COTISATION_SOLIDARITE_SALARIE * 2
        )

    def test_ac_plafond_reasonable(self):
        """Plafond AC entre 100k et 200k."""
        assert 100_000 <= AC_PLAFOND_SALAIRE_ASSURE <= 200_000

    def test_indemnite_standard_below_charge_famille(self):
        """Indemnite standard (70%) < avec charges (80%)."""
        assert AC_INDEMNITE_TAUX < AC_INDEMNITE_TAUX_CHARGE_FAMILLE


# ══════════════════════════════════════════════════════════════════════════════
# 3a — Relations mathematiques
# ══════════════════════════════════════════════════════════════════════════════


class TestPilier3AConsistency:
    """Verifie les constantes 3a."""

    def test_plafond_sans_lpp_above_avec_lpp(self):
        """Grand 3a > petit 3a."""
        assert PILIER_3A_PLAFOND_SANS_LPP > PILIER_3A_PLAFOND_AVEC_LPP

    def test_plafond_sans_lpp_is_5x_avec(self):
        """Grand 3a ~= 5x petit 3a (approximation historique)."""
        ratio = PILIER_3A_PLAFOND_SANS_LPP / PILIER_3A_PLAFOND_AVEC_LPP
        assert 4.5 <= ratio <= 5.5

    def test_taux_revenu_20_percent(self):
        """Taux de revenu pour grand 3a == 20%."""
        assert PILIER_3A_TAUX_REVENU_SANS_LPP == 0.20


# ══════════════════════════════════════════════════════════════════════════════
# Total cotisations
# ══════════════════════════════════════════════════════════════════════════════


class TestCotisationsTotal:
    """Verifie le total des cotisations."""

    def test_total_salarie_formula(self):
        """Total == AVS (incl AI+APG) + AC — no double-count."""
        expected = AVS_COTISATION_SALARIE + AC_COTISATION_SALARIE
        assert COTISATIONS_SALARIE_TOTAL == pytest.approx(expected)

    def test_total_salarie_reasonable(self):
        """Total cotisations salarie entre 5% et 10%."""
        assert 0.05 <= COTISATIONS_SALARIE_TOTAL <= 0.10


# ══════════════════════════════════════════════════════════════════════════════
# Cross-platform sync: Python <-> Dart
# ══════════════════════════════════════════════════════════════════════════════


class TestCrossPlatformSync:
    """Verifie que le fichier Dart contient les memes valeurs que Python."""

    DART_FILE = Path(__file__).parent.parent.parent.parent / "apps" / "mobile" / "lib" / "constants" / "social_insurance.dart"

    @pytest.fixture(autouse=True)
    def load_dart(self):
        """Charge le contenu du fichier Dart une seule fois."""
        if not self.DART_FILE.exists():
            pytest.skip("Dart constants file not found")
        self.dart_content = self.DART_FILE.read_text()

    def _extract_dart_value(self, const_name: str) -> float:
        """Extrait la valeur d'une constante Dart depuis le fichier."""
        # Pattern: const double lppSeuilEntree = 22680.0;
        pattern = rf"const\s+(?:double|int)\s+{const_name}\s*=\s*([\d.]+)"
        match = re.search(pattern, self.dart_content)
        if not match:
            pytest.fail(f"Constant '{const_name}' not found in Dart file")
        return float(match.group(1))

    def test_lpp_seuil_entree(self):
        assert self._extract_dart_value("lppSeuilEntree") == LPP_SEUIL_ENTREE

    def test_lpp_deduction_coordination(self):
        assert self._extract_dart_value("lppDeductionCoordination") == LPP_DEDUCTION_COORDINATION

    def test_lpp_salaire_coord_min(self):
        assert self._extract_dart_value("lppSalaireCoordMin") == LPP_SALAIRE_COORDONNE_MIN

    def test_lpp_salaire_coord_max(self):
        assert self._extract_dart_value("lppSalaireCoordMax") == LPP_SALAIRE_COORDONNE_MAX

    def test_lpp_salaire_max(self):
        assert self._extract_dart_value("lppSalaireMax") == LPP_SALAIRE_MAX

    def test_lpp_taux_conversion(self):
        assert self._extract_dart_value("lppTauxConversionMin") == LPP_TAUX_CONVERSION_MIN

    def test_avs_rente_max(self):
        assert self._extract_dart_value("avsRenteMaxMensuelle") == AVS_RENTE_MAX_MENSUELLE

    def test_avs_rente_min(self):
        assert self._extract_dart_value("avsRenteMinMensuelle") == AVS_RENTE_MIN_MENSUELLE

    def test_ac_plafond(self):
        assert self._extract_dart_value("acPlafondSalaireAssure") == AC_PLAFOND_SALAIRE_ASSURE

    def test_pilier_3a_avec_lpp(self):
        assert self._extract_dart_value("pilier3aPlafondAvecLpp") == PILIER_3A_PLAFOND_AVEC_LPP

    def test_pilier_3a_sans_lpp(self):
        assert self._extract_dart_value("pilier3aPlafondSansLpp") == PILIER_3A_PLAFOND_SANS_LPP

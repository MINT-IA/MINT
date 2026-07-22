"""Tests for retroactive 3a catch-up calculator (S52).

Correct doctrine (réforme OPP3 art. 7a, en vigueur 2025-01-01):
  - Seules les lacunes >= 2025 sont rachetables (les antérieures sont perdues),
    dans une fenêtre de 10 ans. Premier rachat possible en 2026 (année 2025).
  - Le montant du rachat rétroactif payable au cours d'UNE année civile est
    plafonné au « petit » maximum 3a (CHF 7'258 en 2025/2026), identique que
    l'on soit affilié LPP ou indépendant sans LPP (asymétrie documentée de la
    réforme).
  - Le cap 20% du revenu ne concerne QUE la cotisation ordinaire de l'année
    courante (grand 3a sans LPP), pas le rachat rétroactif.

Sources: BSV/OFAS (Einkäufe Säule 3a), UBS, Treuhand Suisse, pierrenovello.ch.
Historique: la version S52 sommait 10 limites 2016-2025 (~68'863 CHF pour
Julien) — doctrine pré-correction, corrigée dans MINT_nosync-cli.
"""


from app.constants.social_insurance import (
    PILIER_3A_PLAFOND_AVEC_LPP,
    PILIER_3A_PLAFOND_SANS_LPP,
)
from app.services.pillar_3a_deep.retroactive_3a_service import (
    HISTORICAL_3A_LIMITS,
    calculate_retroactive_3a,
)

PETIT_MAX_2026 = PILIER_3A_PLAFOND_AVEC_LPP  # 7'258


class TestRetroactive3aDoctrine:
    """Cœur de la doctrine corrigée (plancher 2025 + cap petit max/an)."""

    def test_10_year_request_only_2025_eligible_in_2026(self):
        """Une demande de 10 ans en 2026 ne remplit QUE 2025 (plafonné au petit max)."""
        result = calculate_retroactive_3a(gap_years=10, taux_marginal=0.35)
        assert result.total_retroactive == HISTORICAL_3A_LIMITS[2025]  # 7'258, pas 68'863
        assert len(result.breakdown) == 1
        assert result.breakdown[0].year == 2025

    def test_5_year_request_still_only_2025_in_2026(self):
        """En 2026, même une demande de 5 ans ne rachète que 2025."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.30)
        assert result.total_retroactive == HISTORICAL_3A_LIMITS[2025]
        assert len(result.breakdown) == 1

    def test_1_year_gap_single_limit(self):
        """1 an de lacune = le petit max 2025."""
        result = calculate_retroactive_3a(gap_years=1, taux_marginal=0.25)
        assert result.total_retroactive == HISTORICAL_3A_LIMITS[2025]
        assert result.gap_years == 1

    def test_no_pre_2025_year_in_breakdown(self):
        """Aucune année < 2025 ne peut apparaître (lacunes antérieures perdues)."""
        result = calculate_retroactive_3a(gap_years=10, taux_marginal=0.35)
        assert all(entry.year >= 2025 for entry in result.breakdown)

    def test_total_retroactive_never_exceeds_petit_max_in_2026(self):
        """Le rachat rétroactif payable en 2026 ne dépasse jamais un petit max."""
        for gap in [1, 2, 3, 5, 7, 10, 15]:
            result = calculate_retroactive_3a(gap_years=gap, taux_marginal=0.30)
            assert result.total_retroactive <= PETIT_MAX_2026 + 0.01

    def test_tax_savings_equals_total_times_rate(self):
        """economies_fiscales = total_retroactive * taux_marginal."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.30)
        expected = result.total_retroactive * 0.30
        assert abs(result.economies_fiscales - expected) < 0.01

    def test_current_year_not_in_retroactive(self):
        """L'année courante (2026) n'est PAS dans le total rétroactif."""
        result = calculate_retroactive_3a(gap_years=3, taux_marginal=0.25)
        years_in_breakdown = [e.year for e in result.breakdown]
        assert 2026 not in years_in_breakdown
        assert result.total_current_year == 7258.0

    def test_total_contribution_equals_retroactive_plus_current(self):
        """total_contribution = total_retroactive + total_current_year."""
        result = calculate_retroactive_3a(gap_years=7, taux_marginal=0.30)
        assert abs(
            result.total_contribution
            - (result.total_retroactive + result.total_current_year)
        ) < 0.01


class TestRetroactive3aEdgeCases:
    """Bornes et cas limites."""

    def test_gap_request_over_max_still_capped_to_eligible(self):
        """Une demande > 10 ans reste bornée aux années éligibles (1 en 2026)."""
        result = calculate_retroactive_3a(gap_years=15, taux_marginal=0.30)
        assert result.gap_years == 1
        assert len(result.breakdown) == 1

    def test_gap_years_zero_yields_no_retroactive(self):
        """Aucune lacune déclarée -> aucun rachat fabriqué (review Codex -i0v)."""
        result = calculate_retroactive_3a(gap_years=0, taux_marginal=0.30)
        assert result.gap_years == 0
        assert result.total_retroactive == 0.0
        assert result.breakdown == []

    def test_zero_taux_marginal_no_savings(self):
        """Taux marginal nul → économie nulle."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.0)
        assert result.economies_fiscales == 0.0

    def test_max_taux_marginal(self):
        """Taux 50% → moitié du rétroactif en économie."""
        result = calculate_retroactive_3a(gap_years=3, taux_marginal=0.50)
        assert abs(
            result.economies_fiscales - result.total_retroactive * 0.50
        ) < 0.01

    def test_breakdown_capped_to_eligible_years_2026(self):
        """En 2026, le breakdown ne contient que 2025, quelle que soit la demande."""
        for gap in [1, 3, 5, 7, 10]:
            result = calculate_retroactive_3a(gap_years=gap, taux_marginal=0.25)
            assert len(result.breakdown) == 1
            assert result.breakdown[0].year == 2025


class TestRetroactive3aSansLpp:
    """Indépendants sans LPP — rachat rétroactif plafonné au petit max."""

    def test_sans_lpp_retroactive_same_as_with_lpp(self):
        """Le rachat rétroactif est le petit max pour tous (asymétrie réforme)."""
        with_lpp = calculate_retroactive_3a(
            gap_years=5, taux_marginal=0.30, has_lpp=True
        )
        sans_lpp = calculate_retroactive_3a(
            gap_years=5, taux_marginal=0.30, has_lpp=False
        )
        assert sans_lpp.total_retroactive == with_lpp.total_retroactive
        assert sans_lpp.total_retroactive == PETIT_MAX_2026
        # Seule la cotisation de l'année courante diffère (grand 3a sans LPP).
        assert sans_lpp.total_current_year == 36288.0
        assert with_lpp.total_current_year == 7258.0

    def test_sans_lpp_current_year_is_grand_3a(self):
        """Année courante sans LPP = grand 3a."""
        result = calculate_retroactive_3a(
            gap_years=1, taux_marginal=0.30, has_lpp=False
        )
        assert result.total_current_year == 36288.0


class TestRetroactive3aCompliance:
    """Conformité et format de sortie."""

    def test_premier_eclairage_contains_key_elements(self):
        """Le chiffre choc contient le nombre d'années éligibles + le montant CHF."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.30)
        assert "1" in result.premier_eclairage  # 1 année éligible (2025) en 2026
        assert "CHF" in result.premier_eclairage
        assert "2026" in result.premier_eclairage

    def test_disclaimer_present(self):
        """Le disclaimer mentionne l'outil éducatif + OPP3."""
        result = calculate_retroactive_3a(gap_years=1, taux_marginal=0.25)
        assert "ducatif" in result.disclaimer
        assert "OPP3" in result.disclaimer

    def test_sources_contain_legal_refs(self):
        """Les sources référencent OPP3 et LIFD."""
        result = calculate_retroactive_3a(gap_years=1, taux_marginal=0.25)
        sources_text = " ".join(result.sources)
        assert "OPP3" in sources_text
        assert "LIFD" in sources_text

    def test_no_banned_terms_in_premier_eclairage(self):
        """Le chiffre choc ne contient aucun terme LSFin banni."""
        banned = ["garanti", "certain", "assur", "sans risque", "optimal", "meilleur"]
        result = calculate_retroactive_3a(gap_years=10, taux_marginal=0.35)
        lower = result.premier_eclairage.lower()
        for term in banned:
            assert term not in lower, f"Terme banni '{term}' dans premier éclairage"


class TestRetroactive3aGoldenProfiles:
    """Profils golden — valeurs légalement correctes."""

    def test_julien_10_year_catchup(self):
        """Julien: 49, VS, 35% marginal, croit avoir 10 ans de lacune en 2026.

        Seule 2025 est rachetable → petit max 7'258, économie 7'258×0.35.
        (Ancienne doctrine erronée: 68'863 / 24'102.)
        """
        result = calculate_retroactive_3a(gap_years=10, taux_marginal=0.35)
        assert result.total_retroactive == 7258.0
        assert abs(result.economies_fiscales - 2540.30) < 0.01
        assert len(result.breakdown) == 1

    def test_lauren_5_year_catchup(self):
        """Lauren: 43, VD, 25% marginal, 5 ans demandés → 2025 seul."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=0.25)
        assert result.total_retroactive == 7258.0
        assert abs(result.economies_fiscales - 1814.50) < 0.01

    def test_marco_independent_3_year(self):
        """Marco: 24, TI, indépendant sans LPP, 20% marginal, 3 ans demandés.

        Rachat rétroactif = petit max 7'258 (pas grand 3a). Cotisation courante
        = grand 3a 36'288. (Ancienne doctrine erronée: ~105'979.)
        """
        result = calculate_retroactive_3a(
            gap_years=3, taux_marginal=0.20, has_lpp=False
        )
        assert result.total_retroactive == 7258.0
        assert result.total_current_year == 36288.0
        assert len(result.breakdown) == 1


class TestRetroactive3aParityFixes:
    """Cap 20% revenu (année courante) + clamp taux."""

    def test_sans_lpp_retroactive_is_petit_max_not_income_scaled(self):
        """Le rachat rétroactif sans LPP = petit max, indépendant du revenu."""
        result = calculate_retroactive_3a(
            gap_years=3, taux_marginal=0.30, has_lpp=False,
            revenu_net_annuel=80_000,
        )
        assert result.total_retroactive == 7258.0
        for entry in result.breakdown:
            assert entry.limit == 7258.0
        # Le cap 20% revenu s'applique à l'année courante uniquement.
        assert result.total_current_year == 16_000.0  # 20% de 80k

    def test_sans_lpp_income_cap_current_year(self):
        """Sans LPP, l'année courante respecte le cap 20% revenu."""
        result = calculate_retroactive_3a(
            gap_years=1, taux_marginal=0.25, has_lpp=False,
            revenu_net_annuel=80_000,
        )
        assert result.total_current_year == 16_000.0

    def test_sans_lpp_high_income_uses_grand_limit(self):
        """Sans LPP à haut revenu: année courante plafonnée au grand 3a."""
        result = calculate_retroactive_3a(
            gap_years=1, taux_marginal=0.25, has_lpp=False,
            revenu_net_annuel=500_000,  # 20% = 100K > grand limite ~36K
        )
        assert result.total_current_year == 36_288.0

    def test_sans_lpp_zero_income_no_capacity(self):
        """Sans LPP à revenu nul → aucune capacité de rachat ni de cotisation."""
        result = calculate_retroactive_3a(
            gap_years=1, taux_marginal=0.25, has_lpp=False,
            revenu_net_annuel=0,
        )
        assert result.total_retroactive == 0.0
        assert result.total_current_year == 0.0

    def test_taux_marginal_clamped_to_60_percent(self):
        """Taux marginal > 0.60 ramené à 0.60."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=1.50)
        assert result.economies_fiscales <= result.total_retroactive * 0.61

    def test_negative_taux_marginal_clamped_to_zero(self):
        """Taux marginal négatif ramené à 0."""
        result = calculate_retroactive_3a(gap_years=5, taux_marginal=-0.50)
        assert result.economies_fiscales == 0.0

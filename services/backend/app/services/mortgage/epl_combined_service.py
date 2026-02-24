"""
Combined EPL (3a + LPP) for housing equity calculator.

Wrapper that combines EPL withdrawals from both Pillar 3a and LPP (2nd pillar)
to calculate total available equity for a primary residence purchase.

Key rules:
- 3a: full withdrawal allowed for primary residence (OPP3 art. 1)
- LPP: subject to age-50 rule, min 20k, buyback blocage (see epl_service.py)
- Cantonal capital withdrawal tax applies to both
- Recommended order: cash first, then 3a, then LPP (least impact on protection)
- Buyback blocage: no EPL withdrawal if LPP buyback done in last 3 years

Sources:
    - OPP3 art. 1 (retrait EPL 3a pour logement)
    - LPP art. 30a-30g (retrait EPL LPP)
    - LPP art. 79b al. 3 (blocage rachat 3 ans)

Sprint S17 — Mortgage & Real Estate.
"""

from dataclasses import dataclass, field
from typing import List, Optional

from app.constants.social_insurance import (
    TAUX_IMPOT_RETRAIT_CAPITAL,
    RETRAIT_CAPITAL_TRANCHES,
    calculate_progressive_capital_tax,
)
from app.services.lpp_deep.epl_service import (
    EPLService,
    _DEFAULT_TAUX_RETRAIT,
)


DISCLAIMER = (
    "Estimation a titre indicatif. MINT est un outil educatif et ne constitue "
    "pas un conseil en prevoyance au sens de la LSFin. Le retrait EPL (3a et LPP) "
    "a des consequences sur vos prestations et votre prevoyance vieillesse. "
    "Consultez un ou une specialiste avant toute decision."
)


@dataclass
class DetailFondsPropresMix:
    """Breakdown of combined equity sources."""
    cash: float
    retrait_3a: float
    retrait_lpp: float
    impot_3a: float
    impot_lpp: float
    net_3a: float          # 3a after tax
    net_lpp: float          # LPP after tax
    total_brut: float       # Total before taxes
    total_net: float        # Total after taxes


@dataclass
class ChiffreChoc:
    """Shock figure with amount and explanatory text."""
    montant: float
    texte: str


@dataclass
class EplCombinedResult:
    """Complete result of the combined EPL calculation."""

    # Total equity
    total_fonds_propres: float     # Total available equity (CHF, net of taxes)

    # Detail
    detail: DetailFondsPropresMix

    # Coverage
    prix_cible: float              # Target purchase price (CHF)
    pourcentage_prix_couvert: float  # % of price covered by equity

    # Optimal mix recommendation
    mix_optimal: List[str]         # Ordered steps: "cash d'abord, puis 3a, puis LPP"

    # Shock figure
    chiffre_choc: ChiffreChoc

    # Compliance
    alertes: List[str] = field(default_factory=list)
    sources: List[str] = field(default_factory=list)
    disclaimer: str = DISCLAIMER


class EplCombinedService:
    """Combined EPL calculator (3a + LPP) for housing equity.

    Combines:
    - Cash savings (no restrictions)
    - 3a EPL withdrawal (full amount, cantonal tax on withdrawal)
    - LPP EPL withdrawal (subject to age-50 rule, min 20k, buyback blocage)

    Recommended order:
    1. Cash (no impact on social protection)
    2. 3a (impact on retirement capital, but no disability/death impact)
    3. LPP (impacts retirement + disability + death benefits)

    Sources:
        - OPP3 art. 1 (EPL 3a)
        - LPP art. 30a-30g (EPL LPP)
        - LPP art. 79b al. 3 (blocage rachat)
    """

    def __init__(self):
        self._epl_lpp_service = EPLService()

    def calculate(
        self,
        avoir_3a: float = 0.0,
        avoir_lpp_total: float = 0.0,
        avoir_obligatoire: float = 0.0,
        avoir_surobligatoire: float = 0.0,
        age: int = 35,
        canton: str = "ZH",
        epargne_cash: float = 0.0,
        prix_cible: float = 0.0,
        a_rachete_recemment: bool = False,
        annees_depuis_dernier_rachat: Optional[int] = None,
        avoir_lpp_a_50_ans: Optional[float] = None,
    ) -> EplCombinedResult:
        """Calculate combined EPL equity from all sources.

        Args:
            avoir_3a: Total 3a assets (CHF).
            avoir_lpp_total: Total LPP assets (CHF).
            avoir_obligatoire: Mandatory LPP portion (CHF).
            avoir_surobligatoire: Super-mandatory LPP portion (CHF).
            age: Person's current age.
            canton: Canton code for tax estimation.
            epargne_cash: Available cash savings (CHF).
            prix_cible: Target purchase price (CHF), for coverage %.
            a_rachete_recemment: Whether a LPP buyback was done recently.
            annees_depuis_dernier_rachat: Years since last LPP buyback.
            avoir_lpp_a_50_ans: LPP savings at age 50 (if known).

        Returns:
            EplCombinedResult with complete analysis.
        """
        # Sanitize
        avoir_3a = max(0.0, avoir_3a)
        avoir_lpp_total = max(0.0, avoir_lpp_total)
        avoir_obligatoire = max(0.0, avoir_obligatoire)
        avoir_surobligatoire = max(0.0, avoir_surobligatoire)
        age = max(18, min(70, age))
        canton = (canton.upper() if canton else "ZH")[:2]
        epargne_cash = max(0.0, epargne_cash)
        prix_cible = max(0.0, prix_cible)

        taux_impot = TAUX_IMPOT_RETRAIT_CAPITAL.get(canton, _DEFAULT_TAUX_RETRAIT)

        # ---- 3a EPL ----
        # Full withdrawal allowed for primary residence (OPP3 art. 1)
        # Progressive bracket taxation (matches Flutter + pillar_3a_deep)
        retrait_3a = avoir_3a
        impot_3a = calculate_progressive_capital_tax(retrait_3a, taux_impot)
        net_3a = round(retrait_3a - impot_3a, 2)

        # ---- LPP EPL ----
        # Use existing EPLService for complex LPP rules
        epl_lpp = self._epl_lpp_service.simulate(
            avoir_lpp_total=avoir_lpp_total,
            avoir_obligatoire=avoir_obligatoire,
            avoir_surobligatoire=avoir_surobligatoire,
            age=age,
            montant_retrait_souhaite=avoir_lpp_total,  # Request max
            a_rachete_recemment=a_rachete_recemment,
            annees_depuis_dernier_rachat=annees_depuis_dernier_rachat,
            avoir_a_50_ans=avoir_lpp_a_50_ans,
            canton=canton,
        )

        retrait_lpp = epl_lpp.montant_effectif
        impot_lpp = epl_lpp.impot_retrait_estime
        net_lpp = round(retrait_lpp - impot_lpp, 2)

        # ---- TOTALS ----
        total_brut = round(epargne_cash + retrait_3a + retrait_lpp, 2)
        total_net = round(epargne_cash + net_3a + net_lpp, 2)

        detail = DetailFondsPropresMix(
            cash=round(epargne_cash, 2),
            retrait_3a=round(retrait_3a, 2),
            retrait_lpp=round(retrait_lpp, 2),
            impot_3a=impot_3a,
            impot_lpp=impot_lpp,
            net_3a=net_3a,
            net_lpp=net_lpp,
            total_brut=total_brut,
            total_net=total_net,
        )

        # ---- COVERAGE ----
        if prix_cible > 0:
            pourcentage_couvert = round((total_net / prix_cible) * 100, 2)
        else:
            pourcentage_couvert = 0.0

        # ---- OPTIMAL MIX ----
        mix_optimal = self._build_optimal_mix(
            epargne_cash, avoir_3a, retrait_lpp, epl_lpp.blocage_rachat
        )

        # ---- ALERTES ----
        alertes = self._generate_alertes(
            retrait_3a, retrait_lpp, avoir_lpp_total, epl_lpp,
            prix_cible, total_net, age,
        )

        # ---- CHIFFRE CHOC ----
        if prix_cible > 0:
            fonds_propres_requis = prix_cible * 0.20
            if total_net >= fonds_propres_requis:
                surplus = round(total_net - fonds_propres_requis, 2)
                chiffre_choc = ChiffreChoc(
                    montant=total_net,
                    texte=(
                        f"Tu disposes de {total_net:,.0f} CHF de fonds propres "
                        f"(apres impots), soit {pourcentage_couvert:.1f}% du prix cible. "
                        f"C'est {surplus:,.0f} CHF au-dessus du minimum de 20%."
                    ),
                )
            else:
                gap = round(fonds_propres_requis - total_net, 2)
                chiffre_choc = ChiffreChoc(
                    montant=gap,
                    texte=(
                        f"Il te manque {gap:,.0f} CHF de fonds propres pour "
                        f"atteindre les 20% requis ({fonds_propres_requis:,.0f} CHF)."
                    ),
                )
        else:
            chiffre_choc = ChiffreChoc(
                montant=total_net,
                texte=(
                    f"Tu peux mobiliser {total_net:,.0f} CHF de fonds propres "
                    f"(apres impots) en combinant cash, 3a et LPP."
                ),
            )

        # ---- SOURCES ----
        sources = [
            "OPP3 art. 1 (retrait EPL 3a pour residence principale)",
            "LPP art. 30a-30g (retrait EPL LPP pour residence principale)",
            "LPP art. 79b al. 3 (blocage rachat 3 ans avant EPL)",
            "LPP art. 30c al. 2 (regle des 50 ans)",
            "LPP art. 30e (impact sur prestations de risque)",
        ]

        return EplCombinedResult(
            total_fonds_propres=total_net,
            detail=detail,
            prix_cible=prix_cible,
            pourcentage_prix_couvert=pourcentage_couvert,
            mix_optimal=mix_optimal,
            chiffre_choc=chiffre_choc,
            alertes=alertes,
            sources=sources,
            disclaimer=DISCLAIMER,
        )

    def _build_optimal_mix(
        self,
        cash: float,
        avoir_3a: float,
        retrait_lpp: float,
        blocage_lpp: bool,
    ) -> List[str]:
        """Build the recommended equity sourcing order."""
        steps: List[str] = []

        if cash > 0:
            steps.append(
                f"1. Utiliser l'epargne cash en priorite ({cash:,.0f} CHF) "
                f"— aucun impact sur la prevoyance."
            )

        if avoir_3a > 0:
            steps.append(
                f"2. Retirer le 3a ({avoir_3a:,.0f} CHF) — impact sur le capital "
                f"retraite uniquement, pas sur les prestations de risque."
            )

        if retrait_lpp > 0 and not blocage_lpp:
            steps.append(
                f"3. Retirer du LPP ({retrait_lpp:,.0f} CHF) — en dernier recours, "
                f"car cela reduit les prestations de risque (deces, invalidite)."
            )
        elif blocage_lpp:
            steps.append(
                "3. Le retrait LPP est actuellement bloque (rachat recemment effectue, "
                "delai de 3 ans — LPP art. 79b al. 3)."
            )
        elif retrait_lpp == 0:
            steps.append(
                "3. Pas de LPP disponible pour un retrait EPL."
            )

        if not steps:
            steps.append(
                "Aucune source de fonds propres identifiee. "
                "Verifier les montants saisis."
            )

        return steps

    def _generate_alertes(
        self,
        retrait_3a: float,
        retrait_lpp: float,
        avoir_lpp_total: float,
        epl_lpp,
        prix_cible: float,
        total_net: float,
        age: int,
    ) -> List[str]:
        """Generate alerts for the combined EPL calculation."""
        alertes: List[str] = []

        if retrait_lpp > 0 and avoir_lpp_total > 0:
            pct = (retrait_lpp / avoir_lpp_total) * 100
            if pct > 30:
                alertes.append(
                    f"Le retrait LPP represente {pct:.0f}% de ton avoir LPP. "
                    f"Tes prestations de risque (invalidite, deces) seront "
                    f"significativement reduites (LPP art. 30e). "
                    f"Envisage une assurance complementaire."
                )

        if epl_lpp.blocage_rachat:
            alertes.append(
                f"BLOQUE : le retrait LPP est interdit pendant encore "
                f"{epl_lpp.annees_restantes_blocage} an(s) suite a un rachat recent "
                f"(LPP art. 79b al. 3)."
            )

        if retrait_3a > 0:
            alertes.append(
                "Apres un retrait EPL 3a, le rachat (remboursement) est possible "
                "et deductible fiscalement, mais le capital manquera pour la retraite."
            )

        if retrait_lpp > 0:
            alertes.append(
                "Apres un retrait EPL LPP, les rachats sont bloques pendant 3 ans "
                "(LPP art. 79b al. 3). En cas de vente du bien, le remboursement "
                "a la caisse de pension est obligatoire (LPP art. 30d)."
            )

        if prix_cible > 0:
            fonds_propres_requis = prix_cible * 0.20
            part_2e_pilier_max = prix_cible * 0.10
            if retrait_lpp > part_2e_pilier_max:
                alertes.append(
                    f"Attention : seuls {part_2e_pilier_max:,.0f} CHF du 2e pilier "
                    f"peuvent etre comptes comme fonds propres (max 10% du prix). "
                    f"Le solde LPP ({retrait_lpp - part_2e_pilier_max:,.0f} CHF) "
                    f"peut quand meme etre retire mais ne compte pas comme fonds propres."
                )

        if age >= 50:
            alertes.append(
                "Regle des 50 ans : le retrait LPP est limite a max(avoir a 50 ans, "
                "50% de l'avoir actuel) (LPP art. 30c al. 2)."
            )

        return alertes

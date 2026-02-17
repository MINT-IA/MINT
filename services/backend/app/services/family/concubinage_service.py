"""
Comparateur mariage vs concubinage en droit suisse.

Met en evidence les differences juridiques et financieres majeures entre
le mariage et le concubinage, avec focus sur la fiscalite, la prevoyance,
la succession et la protection du partenaire.

Sources:
    - LIFD art. 9 al. 1 (imposition commune des epoux vs separee)
    - LAVS art. 29sexies (splitting AVS — uniquement pour maries)
    - LPP art. 19-20 (rente de survivant — uniquement pour maries)
    - CC art. 457-466 (droit successoral, reserve hereditaire)
    - CC art. 462 (droit du conjoint survivant)
    - LIFD art. 14 (impot sur les successions entre concubins = taux tiers)

Sprint S22 — Evenements de vie : Famille.
"""

from dataclasses import dataclass, field
from typing import Dict, List


DISCLAIMER = (
    "Estimations educatives simplifiees. Les montants reels dependent de "
    "ton canton, de ta situation personnelle et du droit cantonal applicable. "
    "Ne constitue pas un conseil fiscal ou juridique (LSFin/LLCA). "
    "Consulte un ou une specialiste."
)

# ---------------------------------------------------------------------------
# Taux d'impot sur les successions simplifie par canton
# Format: {canton: {"conjoint": taux, "concubin": taux}}
# Source: Lois cantonales sur les droits de succession, 2024
# Note: la plupart des cantons exonerent le conjoint survivant
# ---------------------------------------------------------------------------

TAUX_SUCCESSION_PAR_CANTON: Dict[str, Dict[str, float]] = {
    "ZH": {"conjoint": 0.00, "concubin": 0.18},   # ZH: conjoint exonere, concubin ~18%
    "BE": {"conjoint": 0.00, "concubin": 0.15},   # BE: conjoint exonere, concubin ~15%
    "LU": {"conjoint": 0.00, "concubin": 0.20},   # LU: conjoint exonere, concubin ~20%
    "BS": {"conjoint": 0.00, "concubin": 0.20},   # BS: conjoint exonere, concubin ~20%
    "VD": {"conjoint": 0.00, "concubin": 0.25},   # VD: conjoint exonere, concubin ~25%
    "GE": {"conjoint": 0.00, "concubin": 0.24},   # GE: conjoint exonere, concubin ~24%
    "ZG": {"conjoint": 0.00, "concubin": 0.10},   # ZG: conjoint exonere, concubin ~10%
    "FR": {"conjoint": 0.00, "concubin": 0.25},   # FR: conjoint exonere, concubin ~25%
    "VS": {"conjoint": 0.00, "concubin": 0.25},   # VS: conjoint exonere, concubin ~25%
    "NE": {"conjoint": 0.00, "concubin": 0.20},   # NE: conjoint exonere, concubin ~20%
    "JU": {"conjoint": 0.00, "concubin": 0.20},   # JU: conjoint exonere, concubin ~20%
    "SZ": {"conjoint": 0.00, "concubin": 0.00},   # SZ: pas d'impot succession (abolit)
    "AG": {"conjoint": 0.00, "concubin": 0.15},
    "SG": {"conjoint": 0.00, "concubin": 0.15},
    "TI": {"conjoint": 0.00, "concubin": 0.20},
    "GR": {"conjoint": 0.00, "concubin": 0.20},
    "TG": {"conjoint": 0.00, "concubin": 0.15},
    "BL": {"conjoint": 0.00, "concubin": 0.20},
    "AR": {"conjoint": 0.00, "concubin": 0.15},
    "AI": {"conjoint": 0.00, "concubin": 0.12},
    "GL": {"conjoint": 0.00, "concubin": 0.15},
    "SH": {"conjoint": 0.00, "concubin": 0.20},
    "OW": {"conjoint": 0.00, "concubin": 0.00},   # OW: pas d'impot succession
    "NW": {"conjoint": 0.00, "concubin": 0.00},   # NW: pas d'impot succession
    "UR": {"conjoint": 0.00, "concubin": 0.15},
    "SO": {"conjoint": 0.00, "concubin": 0.15},
}

_DEFAULT_TAUX_SUCCESSION = {"conjoint": 0.00, "concubin": 0.20}


@dataclass
class ComparisonItem:
    """Un point de comparaison mariage vs concubinage."""
    domaine: str           # Ex: "Fiscalite", "Prevoyance AVS", etc.
    mariage: str           # Description cote mariage
    concubinage: str       # Description cote concubinage
    avantage: str          # "mariage", "concubinage" ou "neutre"


@dataclass
class MariageConcubinageComparison:
    """Resultat complet de la comparaison mariage vs concubinage."""
    comparaisons: List[ComparisonItem]    # Liste des points de comparaison
    score_protection_mariage: int          # Score de protection sur 10
    score_protection_concubinage: int      # Score de protection sur 10
    impot_celibataires_total: float        # Impot en tant que 2 celibataires
    impot_maries_total: float              # Impot en tant que couple marie
    difference_fiscale: float              # Difference fiscale (>0 = penalite mariage)
    impot_succession_conjoint: float       # Impot de succession si conjoint
    impot_succession_concubin: float       # Impot de succession si concubin
    synthese: str                          # Synthese pedagogique
    chiffre_choc: str                      # Chiffre choc pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class InheritanceTaxComparison:
    """Resultat de la comparaison d'impot sur les successions."""
    canton: str                            # Code canton
    patrimoine: float                      # Patrimoine transmis (CHF)
    impot_conjoint: float                  # Impot si conjoint survivant (CHF)
    impot_concubin: float                  # Impot si concubin survivant (CHF)
    difference: float                      # Impot concubin - impot conjoint (CHF)
    taux_conjoint: float                   # Taux effectif conjoint
    taux_concubin: float                   # Taux effectif concubin
    chiffre_choc: str                      # Chiffre choc pedagogique
    sources: List[str] = field(default_factory=list)


@dataclass
class ChecklistConcubinage:
    """Checklist actionable pour les concubins."""
    items: List[str]                       # Liste des actions recommandees
    priorite_haute: List[str]              # Actions urgentes
    priorite_moyenne: List[str]            # Actions importantes
    priorite_basse: List[str]              # Actions de confort
    sources: List[str] = field(default_factory=list)


class ConcubinageService:
    """Comparateur mariage vs concubinage en droit suisse.

    Regles cles:
    - Concubins = imposition SEPAREE (2 declarations individuelles)
    - Pas de splitting AVS (chaque concubin garde ses propres cotisations)
    - Pas de rente de survivant AVS/LPP (sauf clause beneficiaire LPP si possible)
    - Pas de pension alimentaire obligatoire en cas de separation
    - Testament necessaire pour heritage (sinon reserve hereditaire aux parents)
    - Impot sur les successions entre concubins = tres eleve (taux "tiers")
    """

    def compare_mariage_vs_concubinage(
        self,
        revenu_1: float,
        revenu_2: float,
        canton: str = "ZH",
        enfants: int = 0,
        patrimoine: float = 0.0,
    ) -> MariageConcubinageComparison:
        """Compare mariage vs concubinage sur tous les aspects.

        Args:
            revenu_1: Revenu annuel personne 1 (CHF).
            revenu_2: Revenu annuel personne 2 (CHF).
            canton: Code canton (2 lettres).
            enfants: Nombre d'enfants.
            patrimoine: Patrimoine total du couple (CHF).

        Returns:
            MariageConcubinageComparison avec l'analyse complete.
        """
        # Import mariage service for fiscal comparison
        from app.services.family.mariage_service import MariageService
        mariage_svc = MariageService()
        fiscal = mariage_svc.compare_fiscal_impact(revenu_1, revenu_2, canton, enfants)

        # Succession
        succession = self.estimate_inheritance_tax(patrimoine, canton, is_married=False)
        succession_married = self.estimate_inheritance_tax(patrimoine, canton, is_married=True)

        comparaisons = [
            ComparisonItem(
                domaine="Fiscalite (impot sur le revenu)",
                mariage=f"Imposition commune (bareme marie). Impot estime: CHF {fiscal.impot_maries_total:,.0f}",
                concubinage=f"Imposition separee (2 declarations). Impot estime: CHF {fiscal.impot_celibataires_total:,.0f}",
                avantage="concubinage" if fiscal.est_penalite_mariage else "mariage",
            ),
            ComparisonItem(
                domaine="Prevoyance AVS",
                mariage="Splitting AVS: cotisations combinees divisees 50/50 (LAVS art. 29sexies). Protection en cas de divorce.",
                concubinage="Chacun garde ses propres cotisations. Pas de splitting. Risque de lacunes en cas d'interruption.",
                avantage="mariage",
            ),
            ComparisonItem(
                domaine="Prevoyance LPP",
                mariage="Rente de survivant = 60% de la rente LPP du defunt (LPP art. 19). Partage du capital en cas de divorce.",
                concubinage="Aucune rente de survivant LPP (sauf clause beneficiaire dans le reglement de caisse, si possible).",
                avantage="mariage",
            ),
            ComparisonItem(
                domaine="Succession",
                mariage=f"Conjoint = heritier legal (CC art. 462). Exonere d'impot dans la plupart des cantons. Impot: CHF {succession_married.impot_conjoint:,.0f}",
                concubinage=f"Concubin = aucun droit successoral. Testament obligatoire. Impot au taux 'tiers': CHF {succession.impot_concubin:,.0f}",
                avantage="mariage",
            ),
            ComparisonItem(
                domaine="Separation / Divorce",
                mariage="Pension alimentaire possible. Partage LPP (splitting). Partage des acquets (CC art. 181).",
                concubinage="Aucune pension alimentaire. Pas de partage de prevoyance. Chacun reprend ses biens.",
                avantage="neutre",
            ),
            ComparisonItem(
                domaine="Protection enfants",
                mariage="Autorite parentale conjointe automatique. Allocations familiales coordonnees.",
                concubinage="Reconnaissance de paternite necessaire. Autorite parentale conjointe sur demande.",
                avantage="mariage" if enfants > 0 else "neutre",
            ),
        ]

        # Scores de protection
        score_mariage = 8  # bonne protection globale
        score_concubinage = 3  # protection minimale

        # Synthese
        if fiscal.est_penalite_mariage:
            synthese = (
                f"Le concubinage est plus avantageux fiscalement "
                f"(~CHF {abs(fiscal.difference):,.0f}/an), mais le mariage offre "
                f"une bien meilleure protection (prevoyance, succession, enfants). "
                f"La difference de succession peut atteindre CHF {succession.difference:,.0f}."
            )
        else:
            synthese = (
                f"Le mariage est plus avantageux fiscalement "
                f"(~CHF {abs(fiscal.difference):,.0f}/an) ET offre "
                f"une bien meilleure protection (prevoyance, succession, enfants). "
                f"La difference de succession peut atteindre CHF {succession.difference:,.0f}."
            )

        chiffre_choc = (
            f"En cas de deces, ton concubin paierait ~CHF {succession.impot_concubin:,.0f} "
            f"d'impot de succession vs CHF {succession_married.impot_conjoint:,.0f} si vous "
            f"etiez maries. Difference: CHF {succession.difference:,.0f}."
        )

        sources = [
            "LIFD art. 9 al. 1 (imposition commune des epoux)",
            "LAVS art. 29sexies (splitting AVS)",
            "LPP art. 19-20 (rente de survivant)",
            "CC art. 457-466 (droit successoral)",
            "CC art. 462 (droit du conjoint survivant)",
            "Lois cantonales sur les droits de succession",
        ]

        return MariageConcubinageComparison(
            comparaisons=comparaisons,
            score_protection_mariage=score_mariage,
            score_protection_concubinage=score_concubinage,
            impot_celibataires_total=fiscal.impot_celibataires_total,
            impot_maries_total=fiscal.impot_maries_total,
            difference_fiscale=fiscal.difference,
            impot_succession_conjoint=succession_married.impot_conjoint,
            impot_succession_concubin=succession.impot_concubin,
            synthese=synthese,
            chiffre_choc=chiffre_choc,
            sources=sources,
        )

    def estimate_inheritance_tax(
        self,
        patrimoine: float,
        canton: str = "ZH",
        is_married: bool = False,
    ) -> InheritanceTaxComparison:
        """Estime l'impot de succession conjoint vs concubin.

        Args:
            patrimoine: Patrimoine a transmettre (CHF).
            canton: Code canton (2 lettres).
            is_married: True pour conjoint, False pour concubin.

        Returns:
            InheritanceTaxComparison avec le detail.
        """
        taux = TAUX_SUCCESSION_PAR_CANTON.get(canton, _DEFAULT_TAUX_SUCCESSION)
        taux_conjoint = taux["conjoint"]
        taux_concubin = taux["concubin"]

        impot_conjoint = round(patrimoine * taux_conjoint, 2)
        impot_concubin = round(patrimoine * taux_concubin, 2)
        difference = round(impot_concubin - impot_conjoint, 2)

        if difference > 0:
            chiffre_choc = (
                f"Succession dans le canton {canton}: ton concubin paierait "
                f"CHF {impot_concubin:,.0f} d'impot ({taux_concubin * 100:.0f}%), "
                f"contre CHF {impot_conjoint:,.0f} si vous etiez maries "
                f"({taux_conjoint * 100:.0f}%). Difference: CHF {difference:,.0f}."
            )
        else:
            chiffre_choc = (
                f"Canton {canton}: pas de difference significative d'impot "
                f"de succession entre conjoint et concubin."
            )

        sources = [
            f"Loi cantonale {canton} sur les droits de succession",
            "CC art. 462 (droit du conjoint survivant)",
            "CC art. 457 ss (droit successoral legal)",
        ]

        return InheritanceTaxComparison(
            canton=canton,
            patrimoine=patrimoine,
            impot_conjoint=impot_conjoint,
            impot_concubin=impot_concubin,
            difference=difference,
            taux_conjoint=taux_conjoint,
            taux_concubin=taux_concubin,
            chiffre_choc=chiffre_choc,
            sources=sources,
        )

    def checklist_concubinage(self) -> ChecklistConcubinage:
        """Retourne une checklist actionable pour les concubins.

        Returns:
            ChecklistConcubinage avec les actions recommandees par priorite.
        """
        priorite_haute = [
            "Rediger un testament (chacun) — le concubin n'herite de rien sans testament",
            "Verifier si ta caisse de pension (LPP) permet de designer ton concubin comme beneficiaire",
            "Declarer ton concubin comme beneficiaire 3a (formulaire aupres du prestataire)",
            "Souscrire une assurance-deces (risque pur) — indemnite non soumise a l'impot sur les successions dans certains cantons",
        ]

        priorite_moyenne = [
            "Rediger un contrat de concubinage (repartition des charges, bail, etc.)",
            "Reconnaissance de paternite a l'etat civil (si enfants prevus ou nes)",
            "Demander l'autorite parentale conjointe (si enfant reconnu)",
            "Clarifier la repartition des biens (inventaire commun vs separe)",
        ]

        priorite_basse = [
            "Verifier les clauses beneficiaires de toutes tes assurances-vie",
            "Envisager un mandat pour cause d'inaptitude (directives anticipees)",
            "Comparer les couts d'un mariage vs la protection actuelle",
            "Consulter un ou une specialiste pour un bilan juridique complet",
        ]

        items = priorite_haute + priorite_moyenne + priorite_basse

        sources = [
            "CC art. 457-466 (droit successoral)",
            "CC art. 481 (testament, legat)",
            "LPP art. 20a (clause beneficiaire LPP)",
            "CO art. 529-531 (contrat de societe simple / concubinage)",
        ]

        return ChecklistConcubinage(
            items=items,
            priorite_haute=priorite_haute,
            priorite_moyenne=priorite_moyenne,
            priorite_basse=priorite_basse,
            sources=sources,
        )

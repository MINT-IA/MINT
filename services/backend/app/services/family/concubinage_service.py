"""
Comparateur mariage vs concubinage en droit suisse.

Met en evidence les differences juridiques et financieres majeures entre
le mariage et le concubinage, avec focus sur la fiscalite, la prevoyance,
la succession et la protection du partenaire.

L'impot successoral n'est plus chiffre ici — ni en francs, ni en taux.
Voir ConcubinageService.compare_succession_concubin_vs_conjoint() pour le detail du
raisonnement et des sources.

Sources:
    - LIFD art. 9 al. 1 (imposition commune des epoux vs separee)
    - LAVS art. 29sexies (splitting AVS — uniquement pour maries)
    - LPP art. 19-20 (rente de survivant — uniquement pour maries)
    - CC art. 457-466 (droit successoral legal ; art. 462 = part successorale
      CIVILE du conjoint survivant)
    - CC art. 470-471 (reserve hereditaire et quotite disponible, revision du
      droit successoral en vigueur au 1.1.2023)
    - Lois fiscales CANTONALES sur les successions : l'exoneration du conjoint
      survivant et le taux dit « des tiers » du concubin en decoulent. Il
      n'existe pas d'impot successoral federal ordinaire — la LIFD ne regle
      pas cette matiere.

Sprint S22 — Evenements de vie : Famille.
"""

from dataclasses import dataclass, field
from typing import List


DISCLAIMER = (
    "Estimations educatives simplifiees. Les montants reels dependent de "
    "ton canton, de ta situation personnelle et du droit cantonal applicable. "
    "Ne constitue pas un conseil fiscal ou juridique (LSFin/LLCA). "
    "Consulte un ou une spécialiste."
)

# ---------------------------------------------------------------------------
# Pas de table de taux d'impôt successoral par canton.
#
# Une table `TAUX_SUCCESSION_PAR_CANTON` (un taux plat par canton pour le
# conjoint et pour le concubin) vivait ici. Elle a été retirée :
#   - elle est démentie sur au moins deux cantons (NW y figurait à 0.00 alors
#     que Nidwald impose les tiers après déduction, l'exonération n'y valant
#     que pour un concubin ayant tenu ménage commun plusieurs années ; NE y
#     figurait à 0.20 contre un ordre de grandeur bien supérieur après
#     franchise) ;
#   - un taux plat ne peut pas représenter un barème tantôt proportionnel,
#     tantôt progressif, assorti de franchises très inégales, ni l'impôt
#     communal que des cantons autorisent en plus du leur ;
#   - se tromper de plusieurs points sur un patrimoine courant fait basculer
#     une exonération en taxation lourde, ou l'inverse.
#
# Ce qui reste vérifiable est énoncé en toutes lettres par
# ConcubinageService.compare_succession_concubin_vs_conjoint(). Retirer un chiffre
# invérifiable est la bonne décision indépendamment de ce que vaut tel canton
# en particulier — même doctrine que pour le montant.
# ---------------------------------------------------------------------------


@dataclass
class ComparisonItem:
    """Un point de comparaison mariage vs concubinage."""
    domaine: str           # Ex: "Fiscalite", "Prevoyance AVS", etc.
    mariage: str           # Description cote mariage
    concubinage: str       # Description cote concubinage
    avantage: str          # "mariage", "concubinage" ou "neutre"


@dataclass
class MariageConcubinageComparison:
    """Resultat complet de la comparaison mariage vs concubinage.

    Les seuls montants portes ici sont ceux de l'impot sur le REVENU, calcules
    par MariageService. La succession n'est plus chiffree : voir
    ConcubinageService.compare_succession_concubin_vs_conjoint().
    """
    comparaisons: List[ComparisonItem]    # Liste des points de comparaison
    score_protection_mariage: int          # Score de protection sur 10
    score_protection_concubinage: int      # Score de protection sur 10
    impot_celibataires_total: float        # Impot sur le revenu, 2 celibataires
    impot_maries_total: float              # Impot sur le revenu, couple marie
    difference_fiscale: float              # Ecart revenu (>0 = penalite mariage)
    synthese: str                          # Synthese pedagogique
    premier_eclairage: str                 # Le mecanisme, pas un chiffre
    sources: List[str] = field(default_factory=list)


@dataclass
class InheritanceExposure:
    """Ce qui est verifiable sur l'impot successoral d'un concubin.

    Ne porte ni montant ni taux — volontairement. Le seul champ non textuel
    est le canton, qui est un fait confirme et non un calcul.
    """
    canton: str                            # Code canton (echo du fait connu)
    regle_transmission: str                # Ce qui peut etre legue, et a qui
    charge_concubin: str                   # Qui paie quoi, sans le chiffrer
    facteurs_determinants: List[str]       # Ce dont dependrait un vrai chiffre
    premier_eclairage: str                 # Le mecanisme, pas un chiffre
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
    - Testament indispensable : sans testament le concubin n'herite de rien.
      Avec testament, la quotite disponible plafonne a la moitie de la
      succession nette en presence de descendants ; la reserve des parents
      ayant ete supprimee le 1.1.2023, elle est entiere sans descendant
      (CC art. 470-471)
    - Le concubin releve du taux dit « des tiers » du droit fiscal cantonal.
      MINT ne le chiffre pas : voir compare_succession_concubin_vs_conjoint()
    """

    def compare_mariage_vs_concubinage(
        self,
        revenu_1: float,
        revenu_2: float,
        canton: str = "ZH",
        enfants: int = 0,
    ) -> MariageConcubinageComparison:
        """Compare mariage vs concubinage sur tous les aspects.

        NB : plus de parametre `patrimoine`. La succession n'est plus chiffree
        (voir `compare_succession_concubin_vs_conjoint`) : accepter un patrimoine qui ne
        change plus aucune sortie laisserait croire qu'il est pris en compte.

        Args:
            revenu_1: Revenu annuel personne 1 (CHF).
            revenu_2: Revenu annuel personne 2 (CHF).
            canton: Code canton (2 lettres).
            enfants: Nombre d'enfants.

        Returns:
            MariageConcubinageComparison avec l'analyse complete.
        """
        # Import mariage service for fiscal comparison
        from app.services.family.mariage_service import MariageService
        mariage_svc = MariageService()
        fiscal = mariage_svc.compare_fiscal_impact(revenu_1, revenu_2, canton, enfants)

        comparaisons = [
            # `avantage` reste NEUTRE sur la ligne fiscale, contrairement aux
            # lignes suivantes. Celles-ci reposent sur des faits juridiques nets
            # (le conjoint est heritier legal, il est exonere d'impot successoral
            # dans tous les cantons) ; celle-ci repose sur une estimation
            # forfaitaire, sans bareme cantonal detaille, sans commune et sans
            # deductions reelles. Designer un gagnant sur cette base est le meme
            # pseudo-conseil que celui retire cote mobile (PR #1053).
            ComparisonItem(
                domaine="Fiscalité (impôt sur le revenu)",
                mariage=f"Imposition commune, barème marié. Impôt estimé : CHF {fiscal.impot_maries_total:,.0f}",
                concubinage=f"Imposition séparée, 2 déclarations. Impôt estimé : CHF {fiscal.impot_celibataires_total:,.0f}",
                avantage="neutre",
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
                mariage=(
                    "Conjoint ou conjointe = héritier ou héritière légale "
                    "(CC art. 462). L'exonération d'impôt successoral, elle, ne "
                    "vient pas du Code civil : elle est accordée par la loi "
                    "fiscale cantonale, et elle vaut dans tous les cantons."
                ),
                concubinage=(
                    "Concubin ou concubine = aucun droit successoral légal. Sans "
                    "testament, il ou elle n'hérite de rien ; avec testament, la "
                    "quotité disponible plafonne à la moitié de la succession "
                    "nette en présence de descendants (CC art. 470-471). Ce qui "
                    "lui est légué relève du taux dit « des tiers », dont la "
                    "charge varie fortement selon le canton et la commune."
                ),
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

        # Synthese — l'ecart chiffre porte sur l'impot sur le REVENU. La
        # succession, elle, se dit par sa regle : aucun montant, aucun taux.
        if fiscal.est_penalite_mariage:
            synthese = (
                f"Le concubinage est plus avantageux fiscalement : environ "
                f"CHF {abs(fiscal.difference):,.0f}/an d'écart sur l'impôt sur le "
                f"revenu. Le mariage, lui, ouvre des protections que le "
                f"concubinage n'a pas (prévoyance, enfants). Sur la succession, "
                f"ce qui décide n'est pas un montant mais une règle : sans "
                f"testament, ton ou ta partenaire n'hérite de rien."
            )
        else:
            synthese = (
                f"Le mariage est plus avantageux fiscalement : environ "
                f"CHF {abs(fiscal.difference):,.0f}/an d'écart sur l'impôt sur le "
                f"revenu. Il ouvre en plus des protections que le concubinage "
                f"n'a pas (prévoyance, enfants). Sur la succession, ce qui décide "
                f"n'est pas un montant mais une règle : sans testament, ton ou ta "
                f"partenaire n'hérite de rien."
            )

        premier_eclairage = (
            "En cas de décès, ce qui sépare le plus le mariage du concubinage "
            "n'est pas un taux : c'est un droit. Sans testament, ton ou ta "
            "partenaire n'hérite de rien, alors qu'un conjoint ou une conjointe "
            "est héritier ou héritière légale. Avec un testament, tu peux lui "
            "léguer au plus la quotité disponible — la moitié de ta succession "
            "nette si tu as des descendants, la totalité sinon "
            "(CC art. 470-471)."
        )

        sources = [
            "LIFD art. 9 al. 1 (imposition commune des époux)",
            "LAVS art. 29sexies (splitting AVS)",
            "LPP art. 19-20 (rente de survivant)",
            "CC art. 457-466 (droit successoral légal)",
            "CC art. 462 (part successorale CIVILE du conjoint survivant)",
            "CC art. 470-471 (réserve héréditaire et quotité disponible)",
            "Lois fiscales cantonales sur les successions (exonération du "
            "conjoint survivant, taux dit « des tiers »)",
        ]

        return MariageConcubinageComparison(
            comparaisons=comparaisons,
            score_protection_mariage=score_mariage,
            score_protection_concubinage=score_concubinage,
            impot_celibataires_total=fiscal.impot_celibataires_total,
            impot_maries_total=fiscal.impot_maries_total,
            difference_fiscale=fiscal.difference,
            synthese=synthese,
            premier_eclairage=premier_eclairage,
            sources=sources,
        )

    def compare_succession_concubin_vs_conjoint(
        self, canton: str = "ZH",
    ) -> InheritanceExposure:
        """Enonce ce qui est verifiable sur la succession d'un concubin.

        Ne rend ni montant ni taux — et c'est le point de la methode.

        Pourquoi pas de montant. `patrimoine x taux` supposait que 100 % du
        patrimoine pouvait revenir au ou a la partenaire. La revision du droit
        successoral en vigueur au 1.1.2023 dit le contraire : sans testament,
        un concubin n'herite de rien ; avec testament, la reserve des
        descendants vaut la moitie de la succession, donc la quotite
        disponible plafonne a 1/2 en leur presence, et la reserve des parents
        ayant ete supprimee, elle est de 100 % sans descendant
        (CC art. 470-471). Un bien en copropriete n'entre par ailleurs dans la
        succession qu'a hauteur de la quote-part du defunt. Le patrimoine
        n'est donc pas la base d'imposition.

        Pourquoi pas de taux non plus. Le taux plat par canton qui vivait ici
        est dementi sur au moins deux cantons, et il ignore la commune, la
        forme du bareme (proportionnel ou progressif), la franchise, le
        montant réellement reçu et la duree de vie commune. Se tromper de
        plusieurs points fait basculer une exoneration en taxation lourde.

        Ce qui reste, et qui tient : le conjoint survivant est exonere dans
        TOUS les cantons — par la loi fiscale CANTONALE, pas par le Code civil
        (CC art. 462 regle sa part successorale civile ; il n'existe pas
        d'impot successoral federal ordinaire). Le concubin releve du taux dit
        « des tiers ». Et la regle qui decide vraiment est celle de la quotite
        disponible.

        Args:
            canton: Code canton (2 lettres) — repris tel quel, il n'alimente
                aucun calcul.

        Returns:
            InheritanceExposure : le mecanisme, ses sources, et les facteurs
            dont dependrait un chiffre reel.
        """
        regle_transmission = (
            "Sans testament, ton ou ta partenaire n'hérite de rien : ta "
            "succession revient à tes héritiers légaux. Avec un testament, ce "
            "que tu peux lui léguer dépend de tes descendants : si tu en as, "
            "leur réserve représente la moitié de la succession nette et la "
            "quotité disponible plafonne donc à l'autre moitié ; si tu n'en as "
            "pas, la réserve des parents a été supprimée le 1er janvier 2023 et "
            "tu peux disposer de la totalité (CC art. 470-471). Ce qui entre "
            "dans la succession, c'est ta part : un bien détenu en copropriété "
            "n'y figure qu'à hauteur de ta quote-part."
        )

        charge_concubin = (
            "Un conjoint ou une conjointe survivante est exonéré·e d'impôt "
            "successoral dans tous les cantons — cette exonération vient de la "
            "loi fiscale cantonale, pas du Code civil. Un concubin ou une "
            "concubine relève du taux dit « des tiers », et la charge varie "
            "énormément d'un canton à l'autre : de zéro à environ la moitié de "
            "la part reçue dans les cas les plus lourds. MINT ne chiffre pas ce "
            "taux : les barèmes sont tantôt proportionnels, tantôt progressifs, "
            "les franchises très inégales, et des cantons autorisent en plus un "
            "impôt communal qui peut presque doubler la charge cantonale."
        )

        facteurs_determinants = [
            "Ton canton — et ta commune : des cantons laissent la commune "
            "prélever un impôt successoral en plus du leur.",
            "Le montant effectivement reçu par le ou la bénéficiaire, pas ton "
            "patrimoine total : la franchise et le barème s'appliquent à cette "
            "part-là.",
            "Le lien avec la personne défunte : conjoint·e, descendant·e ou "
            "tiers — les barèmes en dépendent entièrement.",
            "La durée de vie commune : des cantons dispensent le concubin ou la "
            "concubine de l'impôt après plusieurs années de ménage commun, "
            "d'autres non.",
        ]

        premier_eclairage = (
            "En cas de décès, ce qui sépare le plus le mariage du concubinage "
            "n'est pas un taux : c'est un droit. Sans testament, ton ou ta "
            "partenaire n'hérite de rien, alors qu'un conjoint ou une conjointe "
            "est héritier ou héritière légale. Avec un testament, tu peux lui "
            "léguer au plus la quotité disponible — la moitié de ta succession "
            "nette si tu as des descendants, la totalité sinon "
            "(CC art. 470-471). L'impôt ne vient qu'après cette règle, et MINT "
            "ne le chiffre pas ici : il dépend de ton canton et de ta commune, "
            "de la part réellement reçue, du lien de parenté et de la durée de "
            "votre vie commune."
        )

        sources = [
            "CC art. 470-471 (réserve héréditaire et quotité disponible, "
            "révision du droit successoral en vigueur au 1.1.2023)",
            "CC art. 457 ss (droit successoral légal)",
            f"Loi fiscale du canton {canton} sur les successions (barème, "
            f"franchise, part communale éventuelle)",
        ]

        return InheritanceExposure(
            canton=canton,
            regle_transmission=regle_transmission,
            charge_concubin=charge_concubin,
            facteurs_determinants=facteurs_determinants,
            premier_eclairage=premier_eclairage,
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
            "Consulter un ou une spécialiste pour un bilan juridique complet",
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

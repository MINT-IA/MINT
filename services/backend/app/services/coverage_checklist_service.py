"""
Coverage Checklist Service.

Evaluates a person's insurance coverage and identifies gaps.
Generates a personalized checklist of recommended, obligatory,
and optional insurance products based on professional and personal status.

Sources:
    - CO art. 41 (responsabilite civile)
    - CO art. 324a (obligation employeur perte de gain)
    - LAA art. 4 (assurance accidents obligatoire)
    - Various cantonal regulations (assurance menage)

MINT est un outil educatif. Ce service ne constitue pas un conseil
en assurance au sens de la LSFin/LCA.
"""

from dataclasses import dataclass, field
from typing import List, Optional


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Cantons where assurance menage (household insurance) is obligatoire
# Nidwalden, Jura, Vaud, Fribourg, Nidwalden
CANTONS_MENAGE_OBLIGATOIRE = {"VD", "FR", "NW", "JU"}

DISCLAIMER = (
    "Cette analyse est fournie a titre educatif et indicatif. "
    "Les couts estimes sont des fourchettes indicatives basees sur "
    "des moyennes du marche suisse. MINT ne constitue pas un conseil "
    "en assurance au sens de la LCA. Consultez un ou une specialiste "
    "en assurances pour une analyse personnalisee."
)


# ---------------------------------------------------------------------------
# Input / Output dataclasses
# ---------------------------------------------------------------------------

@dataclass
class CoverageCheckInput:
    """Input for coverage checklist evaluation."""
    statut_professionnel: str       # "salarie", "independant", "sans_emploi"
    a_hypotheque: bool = False
    a_famille: bool = False          # has dependents
    est_locataire: bool = False
    voyages_frequents: bool = False
    a_ijm_collective: bool = False   # employer IJM
    a_laa: bool = False              # accident insurance via employer
    a_rc_privee: bool = False
    a_menage: bool = False
    a_protection_juridique: bool = False
    a_assurance_voyage: bool = False
    a_assurance_deces: bool = False
    canton: str = "GE"


@dataclass
class CoverageCheckResult:
    """Result of coverage checklist evaluation."""
    checklist: List[dict] = field(default_factory=list)
    score_couverture: int = 0
    lacunes_critiques: int = 0
    recommandations: List[dict] = field(default_factory=list)
    disclaimer: str = ""


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

class CoverageChecklistService:
    """Evaluate insurance coverage and generate personalized checklist.

    Checks mandatory, recommended, and optional insurance products
    based on the person's professional and personal situation.
    """

    def evaluate(self, input_data: CoverageCheckInput) -> CoverageCheckResult:
        """Run the coverage evaluation.

        Args:
            input_data: Person's insurance and personal data.

        Returns:
            CoverageCheckResult with checklist, score, and recommendations.
        """
        checklist = self._build_checklist(input_data)
        score = self._calc_score(checklist)
        lacunes_critiques = self._count_critical_gaps(checklist)
        recommandations = self._generate_recommendations(checklist, input_data)

        return CoverageCheckResult(
            checklist=checklist,
            score_couverture=score,
            lacunes_critiques=lacunes_critiques,
            recommandations=recommandations,
            disclaimer=DISCLAIMER,
        )

    def _build_checklist(self, data: CoverageCheckInput) -> List[dict]:
        """Build the insurance checklist based on profile.

        Each item has: id, categorie, titre, description, urgence, statut,
        cout_estime_annuel, source.
        """
        items = []

        # 1. RC privee
        items.append(self._eval_rc_privee(data))

        # 2. Assurance menage
        items.append(self._eval_menage(data))

        # 3. Protection juridique
        items.append(self._eval_protection_juridique(data))

        # 4. Assurance voyage
        items.append(self._eval_assurance_voyage(data))

        # 5. Assurance deces
        items.append(self._eval_assurance_deces(data))

        # 6. IJM individuelle
        items.append(self._eval_ijm(data))

        # 7. LAA privee
        items.append(self._eval_laa(data))

        # 8. RC professionnelle
        if data.statut_professionnel == "independant":
            items.append(self._eval_rc_professionnelle(data))

        return items

    def _eval_rc_privee(self, data: CoverageCheckInput) -> dict:
        """Evaluate RC privee (private liability insurance)."""
        statut = "couvert" if data.a_rc_privee else "non_couvert"
        urgence = "haute"
        return {
            "id": "rc_privee",
            "categorie": "recommandee",
            "titre": "Responsabilite civile (RC) privee",
            "description": (
                "Couvre les dommages causes a des tiers dans la vie quotidienne. "
                "Indispensable pour toute personne residant en Suisse."
            ),
            "urgence": urgence,
            "statut": statut,
            "cout_estime_annuel": "80-150 CHF",
            "source": "CO art. 41 (responsabilite civile delictuelle)",
        }

    def _eval_menage(self, data: CoverageCheckInput) -> dict:
        """Evaluate household insurance (assurance menage)."""
        is_obligatoire = data.canton.upper() in CANTONS_MENAGE_OBLIGATOIRE
        categorie = "obligatoire" if is_obligatoire else "recommandee"
        urgence = "critique" if is_obligatoire and not data.a_menage else "moyenne"
        statut = "couvert" if data.a_menage else "non_couvert"

        canton_note = ""
        if is_obligatoire:
            canton_note = (
                f" L'assurance menage est obligatoire dans le canton {data.canton.upper()}."
            )

        return {
            "id": "assurance_menage",
            "categorie": categorie,
            "titre": "Assurance menage (inventaire du menage)",
            "description": (
                "Couvre les biens personnels contre le vol, l'incendie, "
                "les degats d'eau et les evenements naturels."
                + canton_note
            ),
            "urgence": urgence,
            "statut": statut,
            "cout_estime_annuel": "100-300 CHF",
            "source": "Reglementations cantonales (VD, FR, NW, JU); LAMal",
        }

    def _eval_protection_juridique(self, data: CoverageCheckInput) -> dict:
        """Evaluate legal protection insurance."""
        is_useful = data.est_locataire or data.statut_professionnel == "salarie"
        categorie = "optionnelle"
        if is_useful:
            categorie = "recommandee"
        urgence = "moyenne" if is_useful else "basse"
        statut = "couvert" if data.a_protection_juridique else "non_couvert"

        detail = ""
        if data.est_locataire:
            detail = " Particulierement utile pour les litiges locatifs (droit du bail)."
        elif data.statut_professionnel == "salarie":
            detail = " Utile en cas de litige avec l'employeur (droit du travail)."

        return {
            "id": "protection_juridique",
            "categorie": categorie,
            "titre": "Protection juridique",
            "description": (
                "Couvre les frais juridiques en cas de litige "
                "(travail, bail, circulation, consommation)."
                + detail
            ),
            "urgence": urgence,
            "statut": statut,
            "cout_estime_annuel": "200-400 CHF",
            "source": "Code de procedure civile (CPC); droit du bail (CO art. 253 ss)",
        }

    def _eval_assurance_voyage(self, data: CoverageCheckInput) -> dict:
        """Evaluate travel insurance."""
        categorie = "recommandee" if data.voyages_frequents else "optionnelle"
        urgence = "moyenne" if data.voyages_frequents else "basse"
        statut = "couvert" if data.a_assurance_voyage else "non_couvert"

        return {
            "id": "assurance_voyage",
            "categorie": categorie,
            "titre": "Assurance voyage",
            "description": (
                "Couvre les frais medicaux a l'etranger, le rapatriement, "
                "l'annulation de voyage et la perte de bagages. "
                "La LAMal couvre les urgences en Europe (carte europeenne), "
                "mais pas les frais hors UE/AELE."
            ),
            "urgence": urgence,
            "statut": statut,
            "cout_estime_annuel": "50-150 CHF",
            "source": "LAMal art. 36 (couverture a l'etranger); conventions bilaterales",
        }

    def _eval_assurance_deces(self, data: CoverageCheckInput) -> dict:
        """Evaluate life/death insurance."""
        is_needed = data.a_hypotheque or data.a_famille
        categorie = "recommandee" if is_needed else "optionnelle"

        if is_needed and not data.a_assurance_deces:
            urgence = "haute"
        elif is_needed:
            urgence = "moyenne"
        else:
            urgence = "basse"

        statut = "couvert" if data.a_assurance_deces else "non_couvert"

        detail = ""
        if data.a_hypotheque:
            detail += " Importante pour couvrir le solde hypothecaire en cas de deces."
        if data.a_famille:
            detail += " Protege les personnes dependantes financierement."

        return {
            "id": "assurance_deces",
            "categorie": categorie,
            "titre": "Assurance deces (risque pur)",
            "description": (
                "Verse un capital aux beneficiaires en cas de deces. "
                "Complemente les prestations du 2e pilier (LPP) et de l'AVS."
                + detail
            ),
            "urgence": urgence,
            "statut": statut,
            "cout_estime_annuel": "100-500 CHF",
            "source": "LCA; LPP art. 18-20 (prestations deces 2e pilier)",
        }

    def _eval_ijm(self, data: CoverageCheckInput) -> dict:
        """Evaluate individual daily sickness benefit insurance (IJM)."""
        is_independant = data.statut_professionnel == "independant"
        is_sans_emploi = data.statut_professionnel == "sans_emploi"
        has_collective = data.a_ijm_collective

        if is_independant:
            categorie = "obligatoire"  # de facto vital for independants
            if not has_collective:
                urgence = "critique"
                statut = "non_couvert"
            else:
                urgence = "basse"
                statut = "couvert"
        elif is_sans_emploi:
            categorie = "recommandee"
            urgence = "haute" if not has_collective else "basse"
            statut = "couvert" if has_collective else "non_couvert"
        else:
            # Salarie
            categorie = "optionnelle"
            if has_collective:
                urgence = "basse"
                statut = "couvert"
            else:
                urgence = "moyenne"
                statut = "a_verifier"

        return {
            "id": "ijm_individuelle",
            "categorie": categorie,
            "titre": "Indemnite journaliere maladie (IJM)",
            "description": (
                "Couvre la perte de gain en cas de maladie de longue duree. "
                "L'employeur a une obligation limitee dans le temps "
                "(CO art. 324a, echelle bernoise/zurichoise). "
                "Sans IJM, le revenu s'arrete apres quelques semaines a mois."
            ),
            "urgence": urgence,
            "statut": statut,
            "cout_estime_annuel": "500-2000 CHF",
            "source": "CO art. 324a (obligation employeur); LCA (IJM individuelle)",
        }

    def _eval_laa(self, data: CoverageCheckInput) -> dict:
        """Evaluate private accident insurance (LAA)."""
        is_independant = data.statut_professionnel == "independant"
        is_sans_emploi = data.statut_professionnel == "sans_emploi"
        has_laa = data.a_laa

        if is_independant:
            categorie = "obligatoire"  # de facto vital
            if not has_laa:
                urgence = "critique"
                statut = "non_couvert"
            else:
                urgence = "basse"
                statut = "couvert"
        elif is_sans_emploi:
            categorie = "recommandee"
            urgence = "haute" if not has_laa else "basse"
            statut = "couvert" if has_laa else "non_couvert"
        else:
            # Salarie: LAA is covered by employer (obligatory)
            categorie = "obligatoire"
            urgence = "basse"
            statut = "couvert" if has_laa else "a_verifier"

        return {
            "id": "laa_privee",
            "categorie": categorie,
            "titre": "Assurance accidents (LAA)",
            "description": (
                "Couvre les frais medicaux et la perte de gain en cas d'accident "
                "(professionnel et non professionnel). Obligatoire pour les "
                "personnes salariees (couvert par l'employeur). "
                "Les personnes independantes doivent souscrire une LAA individuelle."
            ),
            "urgence": urgence,
            "statut": statut,
            "cout_estime_annuel": "300-800 CHF",
            "source": "LAA art. 1a et 4 (obligation d'assurance)",
        }

    def _eval_rc_professionnelle(self, data: CoverageCheckInput) -> dict:
        """Evaluate professional liability insurance (independants only)."""
        return {
            "id": "rc_professionnelle",
            "categorie": "recommandee",
            "titre": "Responsabilite civile professionnelle",
            "description": (
                "Couvre les dommages causes a des tiers dans le cadre de "
                "l'activite professionnelle. Essentielle pour les personnes "
                "independantes, obligatoire dans plusieurs professions "
                "(medical, juridique, fiduciaire)."
            ),
            "urgence": "haute",
            "statut": "a_verifier",
            "cout_estime_annuel": "200-2000 CHF",
            "source": "CO art. 41; reglementations professionnelles specifiques",
        }

    def _calc_score(self, checklist: List[dict]) -> int:
        """Calculate coverage score (0-100).

        Score is based on the percentage of relevant (non-optionnelle) items
        that are covered. Critical items count more.
        """
        if not checklist:
            return 0

        total_weight = 0
        covered_weight = 0

        for item in checklist:
            # Weight by category and urgency
            cat = item["categorie"]
            urgence = item["urgence"]

            if cat == "obligatoire":
                weight = 20
            elif cat == "recommandee":
                weight = 15
            else:
                weight = 5

            if urgence == "critique":
                weight *= 2
            elif urgence == "haute":
                weight *= 1.5

            total_weight += weight

            if item["statut"] == "couvert":
                covered_weight += weight
            elif item["statut"] == "a_verifier":
                covered_weight += weight * 0.5

        if total_weight == 0:
            return 100

        score = int(round(covered_weight / total_weight * 100))
        return min(100, max(0, score))

    def _count_critical_gaps(self, checklist: List[dict]) -> int:
        """Count critical urgency items that are not covered."""
        return sum(
            1 for item in checklist
            if item["urgence"] == "critique" and item["statut"] != "couvert"
        )

    def _generate_recommendations(
        self,
        checklist: List[dict],
        data: CoverageCheckInput,
    ) -> List[dict]:
        """Generate recommendations for uncovered items.

        Prioritize critical and high-urgency gaps.
        """
        recommandations = []

        # Sort by urgency priority
        urgence_order = {"critique": 0, "haute": 1, "moyenne": 2, "basse": 3}
        uncovered = [
            item for item in checklist
            if item["statut"] != "couvert"
        ]
        uncovered.sort(key=lambda x: urgence_order.get(x["urgence"], 99))

        for item in uncovered:
            rec_id = f"rec_{item['id']}"
            if item["urgence"] == "critique":
                priorite = "haute"
                prefix = "Action prioritaire : "
            elif item["urgence"] == "haute":
                priorite = "haute"
                prefix = "Recommandation : "
            elif item["urgence"] == "moyenne":
                priorite = "moyenne"
                prefix = "A considerer : "
            else:
                priorite = "basse"
                prefix = "Optionnel : "

            recommandations.append({
                "id": rec_id,
                "titre": f"{prefix}{item['titre']}",
                "description": (
                    f"{item['description']} "
                    f"Cout estime : {item['cout_estime_annuel']}."
                ),
                "source": item["source"],
                "priorite": priorite,
            })

        return recommandations

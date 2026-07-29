"""
Donation Service — Donation entre vifs.

Simulates the financial and legal impact of a donation (inter vivos gift)
in Switzerland, including cantonal donation tax, reserve hereditaire
(protected shares for heirs), quotite disponible, and avancement d'hoirie.

Sources:
    - CC art. 239-252 (donation entre vifs)
    - CC art. 457-466 (ordre des heritiers legaux)
    - CC art. 470-471 (reserves hereditaires, reforme 2023)
    - CC art. 626 (rapport des donations / avancement d'hoirie)
    - CC art. 527 (reduction des donations excessives)
    - Lois cantonales sur l'impot sur les donations
    - CO art. 243-244 (forme de la donation)

Key changes in 2023 revision (reserves):
    - Descendants reserve: reduced from 3/4 to 1/2 of legal share
    - Parents reserve: COMPLETELY REMOVED
    - Quotite disponible: increased accordingly

Ethical requirements:
    - Gender-neutral: no assumptions based on gender
    - Educational tone, never prescriptive
    - No banned terms: garanti, certain, assure, sans risque, optimal, meilleur, parfait
"""

from dataclasses import dataclass
from typing import List, Dict

from app.services.fiscal.succession_donation_socle import (
    CATEGORIES as SOCLE_CATEGORIES,
    verdict as socle_verdict,
)


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

DISCLAIMER: str = (
    "Cet outil educatif fournit une estimation indicative et ne constitue "
    "pas un conseil financier, fiscal ou juridique au sens de la LSFin. "
    "Les taux d'imposition sur les donations varient selon le canton, "
    "le lien de parente et le montant. Consulte un·e specialiste "
    "(notaire, avocat·e en droit successoral) pour ta situation concrete."
)

SOURCES: List[str] = [
    "CC art. 239-252 (donation entre vifs)",
    "CC art. 470-471 (reserves hereditaires, revision 2023)",
    "CC art. 626 (rapport des donations / avancement d'hoirie)",
    "CC art. 527 (reduction des donations excessives)",
    "CO art. 243-244 (forme de la donation)",
    "Lois cantonales sur l'impot sur les donations",
]

# -----------------------------------------------------------------------------
# Pas de table de taux de donation par canton — NE PAS EN RECRÉER UNE.
#
# TAUX_DONATION_CANTONAL (8 cantons) et TAUX_DONATION_DEFAULT vivaient ici :
# des taux plats non sourcés, démentis par le socle ESTV 1.1.2025. Erreur la
# plus grave : LU y figurait à fratrie 8 %/tiers 25 % alors que Lucerne ne
# prélève AUCUN impôt sur les donations (reprise dans la masse successorale
# si décès dans les 5 ans). « VD parent 5 % » contre un barème progressif
# 2.970-6.289 % ; VD descendant 0 % implicite alors que la ligne directe y
# est taxée ; un « défaut » fabriqué servait 18 cantons dont AI, pourtant
# sourcé.
#
# La source de vérité est app/services/fiscal/succession_donation_socle.py
# (statut / plage sourcée / mécanismes / bascule, parité verrouillée sur
# l'archive ESTV). Garde anti-résurrection : tools/checks/
# no_cantonal_rate_table.py. ADR :
# .planning/decisions/2026-07-28-remplacements-succession-donation-immo-lamal.md
# -----------------------------------------------------------------------------

# Reserve hereditaire rates (CC art. 470-471, revision 2023)
# These are the fraction of the LEGAL share that is protected.
RESERVES_2023: Dict[str, float] = {
    "descendant": 0.50,    # 50% of legal share (was 75% before 2023)
    "conjoint": 0.50,      # 50% of legal share (unchanged)
    "parent": 0.0,         # NO reserve since 2023 (was 50% before)
}


# ══════════════════════════════════════════════════════════════════════════════
# Data classes
# ══════════════════════════════════════════════════════════════════════════════

@dataclass
class DonationInput:
    """Input data for donation simulation."""
    montant: float                                     # Donation amount
    donateur_age: int                                  # Donor age
    lien_parente: str                                  # Relationship to donor
    canton: str                                        # Canton code
    type_donation: str = "especes"                     # "especes", "immobilier", "titres"
    valeur_immobiliere: float = 0.0                    # Property value if real estate
    avancement_hoirie: bool = True                     # Advance on inheritance? (default for descendants)
    nb_enfants: int = 0                                # Number of donor's children
    fortune_totale_donateur: float = 0.0               # Total estate of donor
    regime_matrimonial: str = "participation_acquets"   # Matrimonial regime
    has_spouse: bool = False                            # Whether donor has a spouse
    has_parents: bool = False                           # Whether donor's parents are alive


@dataclass
class DonationResult:
    """Result of donation simulation.

    La fiscalité est un VERDICT du socle ESTV (statut / plage sourcée /
    mécanismes / bascule / source) — plus de taux plat ni d'impôt
    « montant × taux » (ADR 2026-07-28 P4).
    """
    montant_donation: float                            # Donation amount
    verdict_fiscal: dict                               # Socle verdict (statut, plage, mécanismes, bascule, source)
    reserve_hereditaire_totale: float                  # Total reserved shares
    quotite_disponible: float                          # Freely disposable share
    donation_depasse_quotite: bool                     # Whether donation exceeds quotite
    montant_depassement: float                         # Excess amount
    impact_succession: str                             # Impact description
    checklist: List[str]                               # Action items
    alerts: List[str]                                  # Warning messages
    disclaimer: str                                    # Legal disclaimer
    sources: List[str]                                 # Legal references
    premier_eclairage: dict                                 # Impact number


# ══════════════════════════════════════════════════════════════════════════════
# Service
# ══════════════════════════════════════════════════════════════════════════════

class DonationService:
    """Simulate the financial and legal impact of a donation in Switzerland.

    Covers:
    - Cantonal donation tax (by relationship and canton)
    - Reserve hereditaire (2023 law) and quotite disponible
    - Avancement d'hoirie (CC art. 626)
    - Impact on future succession
    - Real estate specific rules

    Compliance: NEVER use "garanti", "assure", "certain", "sans risque".
    """

    def calculate(self, input_data: DonationInput) -> DonationResult:
        """Run the full donation simulation.

        Args:
            input_data: DonationInput with donation and family data.

        Returns:
            DonationResult with tax, reserves, and compliance outputs.
        """
        # Verdict fiscal (socle ESTV — pas de montant × taux).
        # Lien de parenté hors nomenclature -> classe « tiers » (comme
        # l'ancien fallback), sans fabriquer de chiffre.
        categorie = (
            input_data.lien_parente
            if input_data.lien_parente in SOCLE_CATEGORIES
            else "tiers"
        )
        verdict_fiscal = socle_verdict(input_data.canton, categorie, "donation")

        # Reserve and quotite disponible
        legal_shares = self._compute_legal_shares(input_data)
        reserve_totale = self._compute_reserve_totale(
            input_data, legal_shares
        )
        quotite_disponible = self._compute_quotite_disponible(
            input_data.fortune_totale_donateur, reserve_totale
        )

        # Check if donation exceeds quotite disponible
        donation_depasse, depassement = self._check_depassement(
            input_data, quotite_disponible
        )

        # Impact on succession
        impact = self._compute_impact_succession(input_data, donation_depasse)

        # Compliance outputs
        checklist = self._generate_checklist(input_data, verdict_fiscal)
        alerts = self._generate_alerts(
            input_data, verdict_fiscal, donation_depasse, depassement,
            quotite_disponible,
        )
        premier_eclairage = self._generate_premier_eclairage(
            input_data.montant, verdict_fiscal, input_data.lien_parente,
        )

        return DonationResult(
            montant_donation=round(input_data.montant, 2),
            verdict_fiscal=verdict_fiscal,
            reserve_hereditaire_totale=round(reserve_totale, 2),
            quotite_disponible=round(quotite_disponible, 2),
            donation_depasse_quotite=donation_depasse,
            montant_depassement=round(depassement, 2),
            impact_succession=impact,
            checklist=checklist,
            alerts=alerts,
            disclaimer=DISCLAIMER,
            sources=SOURCES,
            premier_eclairage=premier_eclairage,
        )

    # ------------------------------------------------------------------
    # Private computation methods
    # ------------------------------------------------------------------

    def _compute_legal_shares(self, data: DonationInput) -> Dict[str, float]:
        """Compute legal shares (parts legales) per CC art. 457-462.

        The legal share depends on which heirs exist:
        - Spouse + children: spouse 1/2, children 1/2
        - Spouse + parents (no children): spouse 3/4, parents 1/4
        - Spouse alone: spouse 1.0
        - Children alone: children 1.0
        - Parents alone: parents 1.0

        Returns:
            dict mapping heir category to share percentage.
        """
        has_spouse = data.has_spouse
        has_children = data.nb_enfants > 0
        has_parents = data.has_parents

        if has_spouse and has_children:
            return {"conjoint": 0.50, "descendants": 0.50}
        elif has_spouse and not has_children and has_parents:
            return {"conjoint": 0.75, "parents": 0.25}
        elif has_spouse and not has_children and not has_parents:
            return {"conjoint": 1.0}
        elif not has_spouse and has_children:
            return {"descendants": 1.0}
        elif not has_spouse and not has_children and has_parents:
            return {"parents": 1.0}
        else:
            # No protected heirs
            return {}

    def _compute_reserve_totale(
        self, data: DonationInput, legal_shares: Dict[str, float]
    ) -> float:
        """Compute total reserve hereditaire (protected shares).

        NEW LAW 2023 (CC art. 470-471):
        - Descendants reserve: 1/2 of their legal share
        - Spouse reserve: 1/2 of their legal share
        - Parents reserve: REMOVED (0%)

        Returns:
            Total reserve amount in CHF.
        """
        fortune = data.fortune_totale_donateur
        if fortune <= 0:
            return 0.0

        total_reserve_pct = 0.0

        # Spouse reserve
        conjoint_legal = legal_shares.get("conjoint", 0.0)
        if conjoint_legal > 0:
            total_reserve_pct += conjoint_legal * RESERVES_2023["conjoint"]

        # Descendants reserve
        descendants_legal = legal_shares.get("descendants", 0.0)
        if descendants_legal > 0:
            total_reserve_pct += descendants_legal * RESERVES_2023["descendant"]

        # Parents reserve: REMOVED in 2023
        # parents_legal = legal_shares.get("parents", 0.0)
        # No reserve for parents since 2023

        return round(fortune * total_reserve_pct, 2)

    def _compute_quotite_disponible(
        self, fortune_totale: float, reserve_totale: float
    ) -> float:
        """Compute quotite disponible (freely disposable share).

        quotite_disponible = fortune_totale - reserve_totale

        Returns:
            Quotite disponible in CHF (>= 0).
        """
        return max(0.0, round(fortune_totale - reserve_totale, 2))

    def _check_depassement(
        self, data: DonationInput, quotite_disponible: float
    ) -> tuple:
        """Check if donation exceeds quotite disponible.

        A donation to a non-reserved heir (concubin, tiers) that exceeds
        the quotite disponible can be contested by reserved heirs
        (CC art. 527 — action en reduction).

        For donations to reserved heirs (descendants, spouse), the donation
        is counted against their reserve, so the excess check is different.

        Returns:
            (depasse: bool, montant_depassement: float)
        """
        # If no fortune data, we cannot check
        if data.fortune_totale_donateur <= 0:
            return (False, 0.0)

        # For descendants and spouse, donation is part of their share
        # For others, it comes from the quotite disponible
        if data.lien_parente in ("conjoint", "descendant"):
            # These heirs have a reserve; donation counted as advance
            # Only exceeds if > total share (not just QD)
            # Simplified: we check against QD for all
            pass

        if data.montant > quotite_disponible and quotite_disponible > 0:
            depassement = round(data.montant - quotite_disponible, 2)
            return (True, depassement)
        elif quotite_disponible <= 0 and data.montant > 0 and data.fortune_totale_donateur > 0:
            return (True, round(data.montant, 2))
        return (False, 0.0)

    def _compute_impact_succession(
        self, data: DonationInput, donation_depasse: bool
    ) -> str:
        """Compute impact description on future succession.

        Returns:
            String describing the impact in French.
        """
        parts = []

        if data.lien_parente == "descendant" and data.avancement_hoirie:
            parts.append(
                "Cette donation est presumee etre un avancement d'hoirie "
                "(CC art. 626). Elle sera rapportee (comptee) lors du partage "
                "successoral. Le donataire devra rendre l'excedent si la donation "
                "depasse sa part hereditaire."
            )
        elif data.lien_parente == "descendant" and not data.avancement_hoirie:
            parts.append(
                "Cette donation est hors part successorale (dispense de rapport). "
                "Elle s'impute sur la quotite disponible du donateur. "
                "Si elle depasse la quotite disponible, les heritiers reserves "
                "peuvent agir en reduction (CC art. 527)."
            )
        elif data.lien_parente in ("concubin", "tiers"):
            parts.append(
                "Cette donation a un tiers ou concubin s'impute sur la quotite "
                "disponible du donateur. Elle reduit d'autant la masse successorale "
                "future."
            )
        elif data.lien_parente == "conjoint":
            parts.append(
                "La donation au conjoint s'impute en principe sur sa part "
                "successorale. Le regime matrimonial peut influencer le traitement."
            )
        else:
            parts.append(
                "Cette donation reduit la masse successorale future du donateur."
            )

        if donation_depasse:
            parts.append(
                "ATTENTION : cette donation depasse la quotite disponible. "
                "Les heritiers reserves pourront agir en reduction "
                "apres le deces du donateur (CC art. 527)."
            )

        return " ".join(parts)

    # ------------------------------------------------------------------
    # Compliance outputs
    # ------------------------------------------------------------------

    def _generate_checklist(
        self, data: DonationInput, verdict_fiscal: dict
    ) -> List[str]:
        """Generate action checklist for donation.

        Returns:
            List of actionable items in French (tu/toi).
        """
        checklist = [
            "Precise par ecrit si la donation est un avancement d'hoirie "
            "ou hors part successorale",
            "Conserve l'acte de donation pour la future declaration de succession",
            "Verifie les droits de mutation dans ton canton",
        ]

        if data.type_donation == "immobilier":
            checklist.insert(0,
                "Redige un acte de donation authentique (notaire) si immobilier"
            )
            checklist.append(
                "Fais estimer le bien par un expert agree"
            )
            checklist.append(
                "Procede a l'inscription au registre foncier (CC art. 655)"
            )

        if data.nb_enfants > 0 and data.lien_parente != "descendant":
            checklist.append(
                "Informe les autres heritiers reserves de la donation"
            )

        if data.lien_parente == "descendant" and data.nb_enfants > 1:
            checklist.append(
                "Informe les autres enfants de la donation pour eviter "
                "les conflits lors de la succession"
            )

        if data.lien_parente == "concubin" and verdict_fiscal["statut"] in (
            "taxe", "taxe_lourd",
        ):
            bascule = verdict_fiscal.get("bascule") or ""
            checklist.append(
                f"Attention : une donation à un·e concubin·e est imposée "
                f"dans le canton de {data.canton} (souvent la classe la "
                f"plus lourde du barème). {bascule}".rstrip()
            )

        if data.fortune_totale_donateur > 0:
            checklist.append(
                "Verifie que la donation respecte les reserves hereditaires "
                "(CC art. 470-471)"
            )

        checklist.append(
            "Consulte un·e notaire ou un·e avocat·e specialise·e en droit "
            "successoral pour valider la structure de la donation"
        )

        return checklist

    def _generate_alerts(
        self,
        data: DonationInput,
        verdict_fiscal: dict,
        donation_depasse: bool,
        depassement: float,
        quotite_disponible: float,
    ) -> List[str]:
        """Generate warning alerts.

        Returns:
            List of alert strings in French.
        """
        alerts: List[str] = []

        if donation_depasse:
            alerts.append(
                "ATTENTION : cette donation depasse la quotite disponible "
                "— les heritiers reserves peuvent la contester"
            )

        # Concubin : verdict du socle — message conservé, chiffre plat
        # retiré, bascule ajoutée (ADR 2026-07-28 P4).
        if data.lien_parente == "concubin" and verdict_fiscal["statut"] in (
            "taxe", "taxe_lourd",
        ):
            plage = verdict_fiscal.get("plage_max_pct")
            plage_txt = (
                f" (jusqu'à ~{plage:.0f}% selon le barème cantonal, hors "
                f"mécanismes communaux)"
                if plage is not None
                else ""
            )
            bascule = verdict_fiscal.get("bascule") or ""
            alerts.append(
                f"Donation à un·e concubin·e imposée dans le canton "
                f"de {data.canton}{plage_txt}. {bascule}".rstrip()
            )

        if data.type_donation == "immobilier":
            alerts.append(
                "Attention : la donation immobiliere necessite un acte notarie "
                "et l'inscription au registre foncier"
            )

        if data.donateur_age >= 70:
            alerts.append(
                "En cas de deces dans les annees suivantes, le fisc pourrait "
                "requalifier cette donation"
            )

        if (
            data.montant > 500_000
            and data.lien_parente in ("concubin", "tiers")
            and verdict_fiscal["statut"] in ("taxe", "taxe_lourd")
        ):
            alerts.append(
                f"Donation importante a un {data.lien_parente} : l'impot "
                f"cantonal de donation peut être substantiel — fais chiffrer "
                f"le barème exact par l'administration fiscale ou un·e notaire"
            )

        return alerts

    def _generate_premier_eclairage(
        self,
        montant: float,
        verdict_fiscal: dict,
        lien_parente: str,
    ) -> dict:
        """Generate the impact statement (premier éclairage).

        Verdict directionnel du socle : plage sourcée quand elle existe,
        jamais un impôt en francs calculé sur un taux plat.

        Returns:
            dict with montant and texte.
        """
        statut = verdict_fiscal["statut"]
        mecanismes = verdict_fiscal.get("mecanismes") or []

        if statut == "exonere":
            # LU donation : le message dédié du socle prime (pas de 0 muet).
            lucerne = next((m for m in mecanismes if "Lucerne" in m), None)
            if lucerne:
                texte = f"Donation de {montant:,.0f} CHF : {lucerne}"
            else:
                texte = (
                    f"Donation de {montant:,.0f} CHF exonérée d'impôt "
                    f"pour un·e {lien_parente} dans ce canton."
                )
            return {"montant": round(montant, 2), "texte": texte}

        if statut == "inconnu":
            return {
                "montant": round(montant, 2),
                "texte": (
                    f"Donation de {montant:,.0f} CHF : canton non couvert "
                    f"par le socle ESTV — consulte l'administration fiscale "
                    f"cantonale."
                ),
            }

        plage = verdict_fiscal.get("plage_max_pct")
        plage_txt = (
            f" — jusqu'à ~{plage:.0f}% selon le barème cantonal (hors "
            f"mécanismes communaux)"
            if plage is not None
            else " selon le barème cantonal"
        )
        bascule = verdict_fiscal.get("bascule")
        bascule_txt = f" {bascule}" if bascule else ""
        return {
            "montant": round(montant, 2),
            "texte": (
                f"Donation de {montant:,.0f} CHF à un·e {lien_parente} : "
                f"imposable dans ce canton{plage_txt}.{bascule_txt}"
            ),
        }

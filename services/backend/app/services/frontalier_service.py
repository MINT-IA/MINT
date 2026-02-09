"""
Frontalier (Cross-Border Worker) Service.

Provides analysis and recommendations for cross-border workers (permit G)
based on their country of residence and canton of work in Switzerland.

Covers fiscal regime, 3a rights, LPP rules, AVS coordination, and
country-specific bilateral agreements.

Sources:
    - CDI CH-FR (Convention de double imposition Suisse-France)
    - CDI CH-DE (Convention de double imposition Suisse-Allemagne)
    - CDI CH-IT (Accord 2024 nouveaux frontaliers Suisse-Italie)
    - CDI CH-AT (Convention de double imposition Suisse-Autriche)
    - CDI CH-LI (Convention Suisse-Liechtenstein)
    - LIFD art. 83-86 (imposition a la source)
    - LIFD art. 33 (deductions 3a)
    - OPP3 art. 7 (plafond 3a)
    - LPP art. 2 (affiliation obligatoire)
    - LAVS art. 153a (coordination EU/AELE)
    - ALCP Annexe II (libre circulation, coordination securite sociale)
    - Loi GE quasi-resident (90% revenus de source CH)

Ethical requirements:
    - Gender-neutral language throughout
    - NEVER use "garanti", "assure" (sens de garantie), "certain"
    - All recommendations include a source reference
    - Mandatory disclaimer on every response
"""

from dataclasses import dataclass, field
from typing import List, Optional, Dict


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PAYS_FRONTALIERS = {"FR", "DE", "IT", "AT", "LI"}

# 3a plafond (OPP3 art. 7)
PLAFOND_3A_SALARIE = 7_056.0

# Quasi-resident GE threshold: >= 90% income from CH
QUASI_RESIDENT_THRESHOLD = 0.90


# ---------------------------------------------------------------------------
# Country-specific rules
# ---------------------------------------------------------------------------

COUNTRY_RULES: Dict[str, dict] = {
    "FR": {
        "nom_pays": "France",
        "regime_fiscal": (
            "Imposition a la source dans le canton de travail. "
            "Convention de double imposition CH-FR applicable. "
            "Les cantons de GE, VD, VS, NE, JU, BE, BS, BL, SO "
            "retiennent l'impot a la source. Le frontalier declare "
            "ses revenus en France (credit d'impot)."
        ),
        "droit_3a": False,
        "droit_3a_detail": (
            "Pas de droit au 3e pilier (3a), sauf exception: "
            "les quasi-residents du canton de Geneve (>= 90% des revenus "
            "de source suisse) peuvent demander la taxation ordinaire "
            "et deduire les versements 3a."
        ),
        "regime_lpp": (
            "Affiliation LPP obligatoire comme tout salarie en Suisse. "
            "Au depart definitif: libre passage. Transfert sur un compte "
            "de libre passage en Suisse (obligation si destination UE). "
            "Retrait en capital possible selon conditions."
        ),
        "regime_avs": (
            "Cotisations AVS retenues normalement sur le salaire. "
            "Coordination EU/AELE: les periodes de cotisation dans "
            "les pays EU sont totalisees pour le calcul de la rente "
            "(LAVS art. 153a, ALCP Annexe II)."
        ),
        "specificites": [
            "Zone frontaliere historique CH-FR: reglement fiscal specifique.",
            "Possibilite de quasi-resident a Geneve si >= 90% des revenus sont de source suisse.",
            "La CMU ou LAMal au choix pour l'assurance maladie (droit d'option).",
        ],
        "source_convention": "CDI CH-FR, LIFD art. 83-86",
    },
    "DE": {
        "nom_pays": "Allemagne",
        "regime_fiscal": (
            "Imposition a la source en Suisse (4.5% max dans les cantons "
            "frontaliers). Le reste de l'impot est du en Allemagne. "
            "Attestation de residence necessaire (Ansaessigkeitsbescheinigung)."
        ),
        "droit_3a": False,
        "droit_3a_detail": (
            "Pas de droit au 3e pilier (3a). Les versements 3a ne sont "
            "pas deductibles en Allemagne. Pas de statut quasi-resident "
            "applicable."
        ),
        "regime_lpp": (
            "Affiliation LPP obligatoire. Au depart: libre passage, "
            "transfert sur compte de libre passage en Suisse "
            "(obligation EU). Retrait en capital sous conditions."
        ),
        "regime_avs": (
            "Cotisations AVS normales. Coordination EU/AELE: "
            "totalisation des periodes avec l'assurance retraite "
            "allemande (Deutsche Rentenversicherung). "
            "LAVS art. 153a, ALCP Annexe II."
        ),
        "specificites": [
            "Retenue a la source de 4.5% max (cantons frontaliers BS, BL, AG, ZH, SH, TG).",
            "Obligation de declarer en Allemagne avec credit d'impot pour l'impot suisse.",
            "Pas de droit d'option LAMal/GKV depuis 2002 pour les nouveaux frontaliers.",
        ],
        "source_convention": "CDI CH-DE, LIFD art. 83-86",
    },
    "IT": {
        "nom_pays": "Italie",
        "regime_fiscal": (
            "Nouvel accord 2024: pour les nouveaux frontaliers "
            "(debut d'activite apres le 17.07.2023), imposition partagee — "
            "80% Suisse, 20% Italie. Les anciens frontaliers restent sous "
            "l'ancien regime (imposition exclusivement en Suisse pour TI, GR, VS). "
            "L'Italie n'impose pas les anciens frontaliers."
        ),
        "droit_3a": False,
        "droit_3a_detail": (
            "Pas de droit au 3e pilier (3a). Pas de statut quasi-resident "
            "applicable. Les versements 3a ne sont pas deductibles en Italie."
        ),
        "regime_lpp": (
            "Affiliation LPP obligatoire. Au depart: libre passage, "
            "transfert sur compte de libre passage en Suisse "
            "(obligation EU). Retrait en capital sous conditions."
        ),
        "regime_avs": (
            "Cotisations AVS normales. Coordination EU/AELE: "
            "totalisation des periodes avec l'INPS (Italie). "
            "LAVS art. 153a, ALCP Annexe II."
        ),
        "specificites": [
            "Distinction cruciale: ancien frontalier (avant 17.07.2023) vs nouveau frontalier.",
            "Nouveaux frontaliers: imposition partagee 80% CH / 20% IT.",
            "Cantons concernes: TI, GR, VS.",
            "Commune de residence doit etre dans la zone frontaliere (20 km).",
        ],
        "source_convention": "CDI CH-IT (accord 2024), LIFD art. 83-86",
    },
    "AT": {
        "nom_pays": "Autriche",
        "regime_fiscal": (
            "Imposition a la source en Suisse. L'Autriche impose "
            "les revenus mondiaux avec credit d'impot pour l'impot "
            "suisse paye. Pas de regime frontalier specifique comme "
            "avec la France ou l'Allemagne."
        ),
        "droit_3a": False,
        "droit_3a_detail": (
            "Pas de droit au 3e pilier (3a). Les versements 3a ne sont "
            "pas deductibles en Autriche. Pas de statut quasi-resident "
            "applicable."
        ),
        "regime_lpp": (
            "Affiliation LPP obligatoire. Au depart: libre passage, "
            "transfert sur compte de libre passage en Suisse "
            "(obligation EU). Retrait en capital sous conditions."
        ),
        "regime_avs": (
            "Cotisations AVS normales. Coordination EU/AELE: "
            "totalisation des periodes avec la Pensionsversicherungsanstalt "
            "(Autriche). LAVS art. 153a, ALCP Annexe II."
        ),
        "specificites": [
            "Pas de zone frontaliere specifique — regles standard CDI.",
            "Cantons concernes: SG, GR.",
            "Declaration obligatoire en Autriche.",
        ],
        "source_convention": "CDI CH-AT, LIFD art. 83-86",
    },
    "LI": {
        "nom_pays": "Liechtenstein",
        "regime_fiscal": (
            "Cas particulier: le Liechtenstein n'est pas membre de l'UE "
            "mais fait partie de l'EEE. Conventions specifiques CH-LI. "
            "Imposition selon le lieu de travail (Suisse). "
            "Pas de retenue a la source standard — regime bilateral special."
        ),
        "droit_3a": False,
        "droit_3a_detail": (
            "Pas de droit au 3e pilier (3a) en Suisse. Le Liechtenstein "
            "dispose de son propre systeme de prevoyance."
        ),
        "regime_lpp": (
            "Affiliation LPP obligatoire si employe en Suisse. "
            "Au depart: libre passage, transfert possible vers "
            "le Liechtenstein sous conditions specifiques (convention CH-LI)."
        ),
        "regime_avs": (
            "Cotisations AVS normales en Suisse. Coordination via "
            "l'accord CH-LI. Totalisation des periodes possible. "
            "LAVS art. 153a."
        ),
        "specificites": [
            "Le Liechtenstein a son propre systeme de prevoyance (AHV/IV/EO).",
            "Convention bilaterale specifique, differente des accords EU/AELE.",
            "Cantons concernes: SG, GR.",
        ],
        "source_convention": "Convention CH-LI, LIFD art. 83-86",
    },
}


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class FrontalierInput:
    """Input data for cross-border worker analysis."""
    pays_residence: str            # FR, DE, IT, AT, LI
    permis: str                    # G (frontalier)
    canton_travail: str            # Canton where they work
    revenu_brut: float             # Gross annual salary in CHF
    a_3a: bool                     # Currently has a 3a account
    a_lpp: bool                    # Currently affiliated to LPP
    etat_civil: str                # celibataire, marie, divorce, veuf
    nombre_enfants: int            # Number of children
    part_revenu_suisse: float = 1.0  # Share of income from CH (0.0-1.0)


@dataclass
class FrontalierResult:
    """Result of cross-border worker analysis."""
    regime_fiscal: str
    droit_3a: bool
    droit_3a_detail: str
    regime_lpp: str
    regime_avs: str
    alertes: List[str]
    recommandations: List[dict]
    checklist: List[dict]
    specificites: List[str]
    disclaimer: str


# ---------------------------------------------------------------------------
# Disclaimer
# ---------------------------------------------------------------------------

DISCLAIMER = (
    "Cette analyse est indicative et basee sur les regles generales "
    "applicables aux travailleurs frontaliers. Les regles fiscales et de "
    "prevoyance dependent de votre situation individuelle et peuvent "
    "evoluer. Consultez un fiscaliste specialise en droit international "
    "pour une analyse personnalisee."
)


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

class FrontalierService:
    """Analyse la situation des travailleurs frontaliers (permis G).

    Couvre les aspects fiscaux, prevoyance (LPP/AVS), et droits 3a
    selon le pays de residence. Langage neutre, aucun terme banni.
    """

    def analyze(self, input_data: FrontalierInput) -> FrontalierResult:
        """Analyze cross-border worker situation.

        Args:
            input_data: FrontalierInput with worker details.

        Returns:
            FrontalierResult with regime info, alerts, and recommendations.
        """
        pays = input_data.pays_residence.upper()

        if pays not in COUNTRY_RULES:
            # Fallback for unknown country
            return self._unknown_country_result(pays)

        rules = COUNTRY_RULES[pays]

        # --- Determine 3a eligibility ---
        droit_3a = rules["droit_3a"]
        droit_3a_detail = rules["droit_3a_detail"]

        # Special case: quasi-resident GE
        is_quasi_resident_ge = (
            pays == "FR"
            and input_data.canton_travail.upper() == "GE"
            and input_data.part_revenu_suisse >= QUASI_RESIDENT_THRESHOLD
        )

        if is_quasi_resident_ge:
            droit_3a = True
            droit_3a_detail = (
                "En tant que quasi-resident du canton de Geneve "
                "(>= 90% de vos revenus sont de source suisse), vous avez "
                "le droit de demander la taxation ordinaire retroactive. "
                "Cela vous permet de deduire vos versements 3a "
                f"(plafond: CHF {PLAFOND_3A_SALARIE:,.0f}). "
                "Source: Loi GE sur l'imposition des personnes physiques."
            )

        # --- Build alerts ---
        alertes: List[str] = []

        if input_data.a_3a and not droit_3a:
            alertes.append(
                f"Attention: en tant que frontalier residant en {rules['nom_pays']}, "
                f"vous n'avez en principe pas droit au 3e pilier (3a). "
                f"Verifiez si vos versements actuels sont effectivement deductibles."
            )

        if not input_data.a_lpp:
            alertes.append(
                "Vous n'etes pas affilie a une caisse de pension LPP. "
                "En tant que salarie en Suisse, l'affiliation LPP est "
                "obligatoire si votre salaire depasse le seuil d'entree "
                "(CHF 22'050). Verifiez aupres de votre employeur. "
                "Source: LPP art. 2."
            )

        if pays == "IT":
            alertes.append(
                "Nouvel accord CH-IT 2024: si vous avez commence votre "
                "activite apres le 17.07.2023, vous etes soumis a "
                "l'imposition partagee (80% CH / 20% IT). Verifiez votre "
                "date de debut d'activite."
            )

        if pays == "FR" and input_data.canton_travail.upper() == "GE":
            if input_data.part_revenu_suisse >= QUASI_RESIDENT_THRESHOLD:
                alertes.append(
                    "Vous pourriez beneficier du statut de quasi-resident "
                    "a Geneve (>= 90% de revenus de source suisse). "
                    "Cela vous permettrait la taxation ordinaire et la "
                    "deduction du 3a et d'autres frais."
                )
            else:
                alertes.append(
                    f"Votre part de revenus de source suisse est de "
                    f"{input_data.part_revenu_suisse * 100:.0f}%. "
                    f"Le seuil de quasi-resident a Geneve est de 90%. "
                    f"Vous n'y avez en principe pas droit."
                )

        # --- Build recommendations ---
        recommandations: List[dict] = []

        if droit_3a:
            recommandations.append({
                "id": "ouvrir_3a",
                "titre": "Ouvrir ou maximiser le 3e pilier",
                "description": (
                    f"Vous avez droit au 3e pilier. Versez jusqu'a "
                    f"CHF {PLAFOND_3A_SALARIE:,.0f} par an pour beneficier "
                    f"de l'avantage fiscal."
                ),
                "source": "OPP3 art. 7, LIFD art. 33",
                "priorite": "haute",
            })
        else:
            recommandations.append({
                "id": "alternative_prevoyance",
                "titre": "Alternatives au 3e pilier",
                "description": (
                    f"En tant que frontalier residant en {rules['nom_pays']}, "
                    f"vous n'avez pas droit au 3a suisse. Explorez les "
                    f"produits de prevoyance privee dans votre pays de "
                    f"residence (ex: PER en France, Riester en Allemagne)."
                ),
                "source": rules["source_convention"],
                "priorite": "haute",
            })

        recommandations.append({
            "id": "verifier_convention",
            "titre": f"Verifier la convention de double imposition CH-{pays}",
            "description": (
                "Assurez-vous que vous beneficiez correctement de la "
                f"convention de double imposition entre la Suisse et "
                f"{rules['nom_pays']}. Un fiscaliste peut optimiser "
                f"votre situation."
            ),
            "source": rules["source_convention"],
            "priorite": "moyenne",
        })

        recommandations.append({
            "id": "libre_passage",
            "titre": "Anticiper le libre passage LPP",
            "description": (
                "En cas de depart de Suisse, votre avoir LPP sera "
                "transfere sur un compte de libre passage. Si vous "
                "partez dans un pays EU/AELE, le transfert direct "
                "vers une caisse etrangere est limite a la part "
                "surobligatoire."
            ),
            "source": "LFLP art. 25f, ALCP Annexe II",
            "priorite": "moyenne",
        })

        if input_data.nombre_enfants > 0:
            recommandations.append({
                "id": "allocations_familiales",
                "titre": "Allocations familiales transfrontalieres",
                "description": (
                    f"Avec {input_data.nombre_enfants} enfant(s), verifiez "
                    f"votre droit aux allocations familiales suisses ET "
                    f"au complement differentiel dans votre pays de residence. "
                    f"Les regles de coordination EU/AELE s'appliquent."
                ),
                "source": "LAFam, Reglement EU 883/2004",
                "priorite": "moyenne",
            })

        # --- Build checklist ---
        checklist: List[dict] = [
            {
                "item": "Permis G valide et renouvele",
                "statut": "a_verifier",
                "source": "LEI art. 35",
            },
            {
                "item": "Attestation de residence fiscale a jour",
                "statut": "a_verifier",
                "source": rules["source_convention"],
            },
            {
                "item": "Affiliation LPP active",
                "statut": "ok" if input_data.a_lpp else "manquant",
                "source": "LPP art. 2",
            },
            {
                "item": "Compte 3a (si eligible)",
                "statut": "ok" if (droit_3a and input_data.a_3a) else (
                    "non_applicable" if not droit_3a else "manquant"
                ),
                "source": "OPP3 art. 7",
            },
            {
                "item": "Assurance maladie (LAMal ou systeme du pays de residence)",
                "statut": "a_verifier",
                "source": "LAMal art. 3",
            },
            {
                "item": "Declaration fiscale dans le pays de residence",
                "statut": "a_verifier",
                "source": rules["source_convention"],
            },
        ]

        return FrontalierResult(
            regime_fiscal=rules["regime_fiscal"],
            droit_3a=droit_3a,
            droit_3a_detail=droit_3a_detail,
            regime_lpp=rules["regime_lpp"],
            regime_avs=rules["regime_avs"],
            alertes=alertes,
            recommandations=recommandations,
            checklist=checklist,
            specificites=rules["specificites"],
            disclaimer=DISCLAIMER,
        )

    def _unknown_country_result(self, pays: str) -> FrontalierResult:
        """Return a result for an unknown/unsupported country."""
        return FrontalierResult(
            regime_fiscal=(
                f"Pays '{pays}' non pris en charge. Les regles frontaliers "
                f"ne s'appliquent qu'aux pays limitrophes: FR, DE, IT, AT, LI."
            ),
            droit_3a=False,
            droit_3a_detail="Non determine — pays non pris en charge.",
            regime_lpp=(
                "Si vous travaillez en Suisse, l'affiliation LPP est "
                "obligatoire selon LPP art. 2."
            ),
            regime_avs="Cotisations AVS normales si employe en Suisse.",
            alertes=[
                f"Le pays '{pays}' n'est pas un pays frontalier reconnu. "
                f"Verifiez votre situation aupres d'un specialiste."
            ],
            recommandations=[{
                "id": "consulter_specialiste",
                "titre": "Consulter un specialiste",
                "description": (
                    "Votre situation ne correspond pas aux cas frontaliers "
                    "standard. Consultez un fiscaliste specialise en droit "
                    "international."
                ),
                "source": "LIFD art. 83-86",
                "priorite": "haute",
            }],
            checklist=[],
            specificites=[],
            disclaimer=DISCLAIMER,
        )

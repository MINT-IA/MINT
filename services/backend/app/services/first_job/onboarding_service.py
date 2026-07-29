"""
First Job Onboarding Service.

Provides salary breakdown, 3a recommendations, LAMal franchise comparison,
and a complete onboarding checklist for someone starting their first job
in Switzerland.

Deductions (employee share):
    - AVS/AI/APG: 5.30% (LAVS art. 5)
    - AC: 1.1% up to 148'200/year (LACI art. 3)
    - AANP: ~1.3% (estimate, varies by employer)
    - LPP: age-based rate on coordinated salary (LPP art. 16)

Sources:
    - LAVS art. 5 (cotisation AVS employe: 5.30%)
    - LACI art. 3 (cotisation chomage: 1.1%, solidarite: 0.5% au-dessus de 148'200)
    - LAA art. 91 (AANP: prime non-professionnel, ~1.0-1.5%)
    - LPP art. 2, 7 (seuil d'acces: 22'680 CHF/an)
    - LPP art. 8 (deduction de coordination: 26'460 CHF)
    - LPP art. 16 (bonifications de vieillesse par tranche d'age)
    - OPP3 art. 7 al. 1 (plafond 3a salaries: 7'258 CHF)
    - LAMal art. 61-65 (franchises: 300-2'500, quote-part 10%, max 700 CHF)

Sprint S19 — Chomage (LACI) + Premier emploi.
"""

from datetime import datetime, timezone
from typing import Iterable, List, Optional, Tuple
from uuid import uuid4

from app.constants.social_insurance import (
    AVS_COTISATION_SALARIE,
    AC_COTISATION_SALARIE,
    AC_COTISATION_SOLIDARITE_SALARIE,
    AC_PLAFOND_SALAIRE_ASSURE,
    LAMAL_QUOTE_PART_CAP_ADULT,
    LPP_SEUIL_ENTREE,
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_COORDONNE_MIN,
    LPP_SALAIRE_COORDONNE_MAX,
    LPP_BONIFICATIONS_VIEILLESSE,
    PILIER_3A_PLAFOND_AVEC_LPP,
)
from app.models.lucidity.money_truth_receipt import (
    FIRST_JOB_NET_SALARY_CLAIM_ID,
    MoneyTruthRange,
    MoneyTruthReceipt,
    MoneyTruthSource,
)
from app.schemas.enhanced_confidence import EnhancedConfidence
from app.services.coach.inputs_hash import compute_inputs_hash


# ---------------------------------------------------------------------------
# Constants — from app.constants.social_insurance (centralized source of truth)
# ---------------------------------------------------------------------------

# Employee deduction rates
AVS_AI_APG_RATE = AVS_COTISATION_SALARIE  # 5.30% employee share (LAVS art. 5)
AC_RATE = AC_COTISATION_SALARIE  # 1.1% employee (up to 148'200/year, LACI art. 3)
AC_SOLIDARITY_RATE = AC_COTISATION_SOLIDARITE_SALARIE  # 0.5% solidarity above 148'200
AC_SALARY_CAP = AC_PLAFOND_SALAIRE_ASSURE  # CHF/year
AANP_RATE = 0.013  # ~1.3% estimate (varies by employer/risk class, not in centralized constants)

# LPP (2nd pillar) thresholds
LPP_ENTRY_THRESHOLD = LPP_SEUIL_ENTREE  # CHF/year (LPP art. 2 al. 1)
LPP_COORDINATION_DEDUCTION = LPP_DEDUCTION_COORDINATION  # CHF (LPP art. 8 al. 1)
LPP_MIN_COORDINATED = LPP_SALAIRE_COORDONNE_MIN  # CHF (LPP art. 8 al. 2)
LPP_MAX_COORDINATED = LPP_SALAIRE_COORDONNE_MAX  # CHF (LPP art. 8 al. 1)

# Age-based LPP contribution rates (LPP art. 16)
# (min_age, max_age, total_rate)
# Employee pays half of total rate
LPP_BONIFICATIONS: List[Tuple[int, int, float]] = list(LPP_BONIFICATIONS_VIEILLESSE)

# 3rd pillar
PILLAR_3A_LIMIT = PILIER_3A_PLAFOND_AVEC_LPP  # CHF/year for employees (OPP3 art. 7 al. 1)

# LAMal franchise options
LAMAL_FRANCHISES = [300, 500, 1000, 1500, 2000, 2500]
LAMAL_QUOTE_PART_MAX = LAMAL_QUOTE_PART_CAP_ADULT  # 10% after franchise, capped at 700 CHF/year

# Approximate LAMal monthly premiums by franchise level (young adult, ZH 2025)
# These are approximate averages — actual premiums vary by insurer and canton
LAMAL_PREMIUM_ESTIMATES = {
    300: 380.0,
    500: 360.0,
    1000: 320.0,
    1500: 285.0,
    2000: 255.0,
    2500: 230.0,
}

# Estimated marginal tax rates by canton (very simplified)
# `CANTONAL_TAX_RATE_ESTIMATES` a ete SUPPRIMEE le 2026-07-27 : aucune source,
# et un defaut a 0.25 pour tout canton inconnu. Le taux marginal se derive du
# modele calibre ESTV (garde : tools/checks/no_cantonal_rate_table.py).

DISCLAIMER = (
    "MINT est un outil educatif. Ce simulateur ne constitue pas un conseil "
    "en matiere fiscale ou de prevoyance au sens de la LSFin. Les montants exacts "
    "dependent de ton employeur, de ta caisse de pension et de ta situation personnelle. "
    "Consulte un ou une specialiste pour une analyse personnalisee."
)

SOURCES = [
    "LAVS art. 5 (cotisation AVS employe: 5.30%)",
    "LACI art. 3 (cotisation chomage: 1.1%)",
    "LAA art. 91 (AANP: ~1.0-1.5%)",
    "LPP art. 2, 7 (seuil d'acces: 22'680 CHF/an)",
    "LPP art. 8 (deduction de coordination: 26'460 CHF, min coordonne: 3'780 CHF)",
    "LPP art. 16 (bonifications de vieillesse par tranche d'age)",
    "OPP3 art. 7 al. 1 (plafond 3a salaries: 7'258 CHF)",
    "LAMal art. 61-65 (franchises: 300-2'500, quote-part 10%, max 700 CHF)",
]


# ---------------------------------------------------------------------------
# MoneyTruthReceipt v1 — producteur du claim firstjob.net_salary.v1 (PR-B).
#
# Le net firstJob est L1 (mobile-canonical, offline). Ce producteur backend
# émet le MÊME receipt que le miroir Dart
# (`apps/mobile/lib/services/first_job_service.dart::buildNetSalaryReceipt`) :
# mêmes `inputs` normalisés, MÊME `inputs_hash` (compute_inputs_hash), même
# `value` après arrondi. La parité est verrouillée par
# `tools/fixtures/money_truth_receipt_v1.json`.
# ---------------------------------------------------------------------------

# Version du moteur de calcul (composant `engine_version` du receipt). Chaîne
# stable partagée avec le miroir Dart. Le mapping vers
# `constants_version_hash + app_version` de ProjectionAuditRecord est câblé en
# PR-E (persistance), hors de ce fichier.
FIRST_JOB_NET_ENGINE_VERSION = "firstjob-net-receipt-v1"

# Millésime des règles de cotisation appliquées (≠ millésime des statistiques,
# SPEC §4.1). Les taux AVS/AC/LPP/LAMal utilisés pour le net sont 2026.
FIRST_JOB_NET_TAX_YEAR = 2026

# Hypothèse bornante figée (SPEC §4.1) : la classe de risque AANP dépend de
# l'employeur. Le net point utilise 1.3% ; la bande recalcule le net avec
# l'AANP basse (1.0% -> net haut) et haute (1.5% -> net bas).
AANP_RATE_LOW = 0.010   # borne haute du net (déduction minimale)
AANP_RATE_HIGH = 0.015  # borne basse du net (déduction maximale)

# Champs du gate d'entrée (SPEC : firstJobGateWhySalaire/Age/Canton) — servent
# à dériver l'axe `completeness` de la confiance.
FIRST_JOB_GATE_FIELDS = ("salaireBrutMensuel", "age", "canton")


def _first_job_net_confidence(
    user_provided_fields: Optional[Iterable[str]] = None,
) -> EnhancedConfidence:
    """Mapping DÉCLARÉ PR-B des champs du gate vers les 4 axes EnhancedConfidence.

    Pas de nouveau scorer (règle 4 / NEVER #3) — on peuple la forme fil
    existante `EnhancedConfidence` (completeness × accuracy × freshness ×
    understanding, combiné = moyenne géométrique).

    - completeness : part des 3 champs du gate réellement fournis par
      l'utilisateur (salaireBrutMensuel, age, canton). Défaut : les 3 présents.
    - accuracy : 0.90 — taux AVS/AC/LPP/LAMal canoniques, mais l'AANP est une
      estimation (~1.0-1.5%) et l'impôt source est exclu -> pas 1.0.
    - freshness : 1.00 — les règles de cotisation appliquées sont l'année en
      cours (tax_year 2026).
    - understanding : 0.50 — le gate a explicité le « pourquoi »
      (firstJobGateWhy*), mais aucune session coach n'a encore eu lieu.
    """
    provided = (
        set(user_provided_fields)
        if user_provided_fields is not None
        else set(FIRST_JOB_GATE_FIELDS)
    )
    gate = set(FIRST_JOB_GATE_FIELDS)
    completeness = len(provided & gate) / len(gate)
    accuracy = 0.90
    freshness = 1.00
    understanding = 0.50
    combined = (completeness * accuracy * freshness * understanding) ** 0.25
    return EnhancedConfidence(
        completeness=completeness,
        accuracy=accuracy,
        freshness=freshness,
        understanding=understanding,
        score=combined,
    )


# ---------------------------------------------------------------------------
# Service class
# ---------------------------------------------------------------------------

class FirstJobOnboardingService:
    """Analyzes a first job salary and provides onboarding recommendations."""

    def analyze_salary(
        self,
        salaire_brut_mensuel: float,
        canton: str = "ZH",
        age: int = 25,
        etat_civil: str = "celibataire",
        has_children: bool = False,
        taux_activite: float = 100.0,
    ) -> dict:
        """Analyze first job salary and provide comprehensive recommendations.

        Args:
            salaire_brut_mensuel: Monthly gross salary (CHF).
            canton: Canton code (2 letters).
            age: Age of the person.
            etat_civil: Civil status.
            has_children: Has dependent children.
            taux_activite: Activity rate in percent (e.g. 80.0).

        Returns:
            Dict with all response fields for FirstJobResponse.
        """
        alertes: List[str] = []

        # 1. Calculate salary breakdown
        breakdown = self._calculate_salary_breakdown(
            brut=salaire_brut_mensuel,
            canton=canton,
            age=age,
            taux_activite=taux_activite,
        )

        # 2. 3a recommendation
        recommandations_3a = self._recommend_3a(
            brut_mensuel=salaire_brut_mensuel,
            canton=canton,
            age=age,
            taux_activite=taux_activite,
        )

        # 3. LAMal franchise recommendation
        recommandation_lamal = self._recommend_franchise(age=age)

        # 4. Checklist
        checklist = self._build_checklist()

        # 5. Alerts
        if taux_activite < 100:
            alertes.append(
                f"Avec un taux d'activite de {taux_activite:.0f}%, verifie que ton "
                f"salaire annuel atteint le seuil LPP de {LPP_ENTRY_THRESHOLD:,.0f} CHF/an."
            )

        annuel_brut = salaire_brut_mensuel * 12 * (taux_activite / 100)
        if annuel_brut < LPP_ENTRY_THRESHOLD:
            alertes.append(
                f"Ton salaire annuel ({annuel_brut:,.0f} CHF) est en dessous du seuil "
                f"d'acces au 2e pilier ({LPP_ENTRY_THRESHOLD:,.0f} CHF). Tu n'es pas "
                f"assure-e au LPP obligatoire."
            )

        if age < 25 and age >= 18:
            alertes.append(
                "Avant 25 ans, tu ne cotises pas encore aux bonifications de vieillesse LPP. "
                "Tu cotises uniquement pour le risque (invalidite, deces)."
            )

        # 6. Chiffre choc
        cotisations_invisibles = breakdown["cotisations_invisibles_employeur"]
        premier_eclairage = (
            f"Ton employeur paie {cotisations_invisibles:,.0f} CHF/mois de charges "
            f"sociales en plus de ton salaire brut. Ton cout reel pour l'entreprise "
            f"est de {salaire_brut_mensuel + cotisations_invisibles:,.0f} CHF/mois."
        )

        return {
            "decomposition_salaire": breakdown,
            "recommandations_3a": recommandations_3a,
            "recommandation_lamal": recommandation_lamal,
            "checklist_premier_emploi": checklist,
            "alertes": alertes,
            "premier_eclairage": premier_eclairage,
            "disclaimer": DISCLAIMER,
            "sources": list(SOURCES),
        }

    def build_net_salary_receipt(
        self,
        salaire_brut_mensuel: float,
        canton: str = "ZH",
        age: int = 25,
        etat_civil: str = "celibataire",
        taux_activite: float = 100.0,
        user_provided_fields: Optional[Iterable[str]] = None,
        receipt_id: Optional[str] = None,
        computed_at: Optional[str] = None,
    ) -> MoneyTruthReceipt:
        """Émet le MoneyTruthReceipt du claim firstjob.net_salary.v1 (SPEC §4).

        `value` = net firstJob (point, AANP 1.3%). `range` = recalcul du net
        avec l'AANP basse / haute (hypothèse bornante figée PR-B). `inputs_hash`
        = compute_inputs_hash des inputs normalisés (même algo, mêmes champs que
        le miroir Dart). `confidence` = mapping déclaré (voir
        `_first_job_net_confidence`).

        `receipt_id` / `computed_at` sont injectables pour les tests
        déterministes ; sinon uuid4 / horodatage courant.
        """
        canton_norm = canton.upper()
        etat_norm = etat_civil.lower()

        point = self._calculate_salary_breakdown(
            brut=salaire_brut_mensuel,
            canton=canton_norm,
            age=age,
            taux_activite=taux_activite,
            aanp_rate=AANP_RATE,
        )
        net = point["net_estime"]
        net_high = self._calculate_salary_breakdown(
            brut=salaire_brut_mensuel,
            canton=canton_norm,
            age=age,
            taux_activite=taux_activite,
            aanp_rate=AANP_RATE_LOW,  # déduction minimale -> net haut
        )["net_estime"]
        net_low = self._calculate_salary_breakdown(
            brut=salaire_brut_mensuel,
            canton=canton_norm,
            age=age,
            taux_activite=taux_activite,
            aanp_rate=AANP_RATE_HIGH,  # déduction maximale -> net bas
        )["net_estime"]

        inputs = {
            "salaireBrutMensuel": float(salaire_brut_mensuel),
            "age": int(age),
            "canton": canton_norm,
            "tauxActivite": float(taux_activite),
            "etatCivil": etat_norm,
        }

        assumptions = [
            "AANP 1.0-1.5% selon la classe de risque de l'employeur (defaut 1.3%)",
            f"tauxActivite={taux_activite:.0f}%",
            f"etatCivil={etat_norm}",
            "impot a la source non applique (resident-e impose-e ordinairement)",
            "net mensuel hors 13e salaire et hors bonus",
        ]

        return MoneyTruthReceipt(
            claim_id=FIRST_JOB_NET_SALARY_CLAIM_ID,
            receipt_id=receipt_id or str(uuid4()),
            inputs=inputs,
            inputs_hash=compute_inputs_hash(inputs),
            jurisdiction=f"CH-{canton_norm}",
            tax_year=FIRST_JOB_NET_TAX_YEAR,
            base="net",
            civil_status=etat_norm,
            assumptions=assumptions,
            engine="app.services.first_job.onboarding_service",
            engine_version=FIRST_JOB_NET_ENGINE_VERSION,
            rounding="CHF arrondi au 1 franc",
            sources=[
                MoneyTruthSource(id="avs", label="AVS/AI/APG (LAVS art. 5 / LAI art. 3 / LAPG art. 27)", vintage=FIRST_JOB_NET_TAX_YEAR),
                MoneyTruthSource(id="ac", label="AC (LACI art. 3)", vintage=FIRST_JOB_NET_TAX_YEAR),
                MoneyTruthSource(id="lpp", label="LPP bonifications (LPP art. 16)", vintage=FIRST_JOB_NET_TAX_YEAR),
                MoneyTruthSource(id="aanp", label="AANP estimation (LAA art. 91)", vintage=FIRST_JOB_NET_TAX_YEAR),
            ],
            value=net,
            range=MoneyTruthRange(low=net_low, high=net_high),
            confidence=_first_job_net_confidence(user_provided_fields),
            computed_at=computed_at
            or datetime.now(timezone.utc).isoformat(),
        )

    def _calculate_salary_breakdown(
        self,
        brut: float,
        canton: str,
        age: int,
        taux_activite: float,
        aanp_rate: float = AANP_RATE,
    ) -> dict:
        """Calculate detailed salary breakdown from gross to net.

        `aanp_rate` défaut = AANP_RATE (comportement inchangé). Le producteur
        de MoneyTruthReceipt (PR-B) le fait varier sur [1.0%, 1.5%] pour la
        borne haute / basse du net (l'AANP est l'hypothèse non confirmée du
        gate : la classe de risque exacte dépend de l'employeur).
        """
        annuel = brut * 12 * (taux_activite / 100)

        # Employee deductions
        avs = round(brut * AVS_AI_APG_RATE, 2)

        # AC: 1.1% up to 148'200/year, 0.5% solidarity above
        if annuel <= AC_SALARY_CAP:
            ac = round(brut * AC_RATE, 2)
        else:
            ac = round(brut * AC_SOLIDARITY_RATE, 2)

        aanp = round(brut * aanp_rate, 2)

        # LPP (employee share = half of total bonification rate)
        lpp = 0.0
        if annuel >= LPP_ENTRY_THRESHOLD and age >= 25:
            coordinated = max(annuel - LPP_COORDINATION_DEDUCTION, LPP_MIN_COORDINATED)
            coordinated = min(coordinated, LPP_MAX_COORDINATED)
            lpp_rate = self._get_lpp_rate(age)
            lpp = round((coordinated * lpp_rate) / 12 / 2, 2)  # employee share = half

        # Net estimate (without source tax for now)
        net = round(brut - avs - ac - aanp - lpp, 2)

        # Employer invisible contributions (matching + employer-only)
        # Employer pays: AVS 5.3%, AC 1.1%, AANP varies, LPP match, CAF, etc.
        employer_avs = round(brut * AVS_AI_APG_RATE, 2)
        employer_ac = round(brut * AC_RATE, 2) if annuel <= AC_SALARY_CAP else round(brut * AC_SOLIDARITY_RATE, 2)
        employer_aanp = round(brut * 0.008, 2)  # employer AAP + AANP share
        employer_lpp = lpp  # employer matches employee share
        employer_caf = round(brut * 0.005, 2)  # family allowances contribution (~0.5%)
        cotisations_invisibles = round(
            employer_avs + employer_ac + employer_aanp + employer_lpp + employer_caf, 2
        )

        return {
            "brut": brut,
            "avs_ai_apg": avs,
            "ac": ac,
            "aanp": aanp,
            "lpp_employe": lpp,
            "impot_source": None,
            "net_estime": net,
            "cotisations_invisibles_employeur": cotisations_invisibles,
        }

    def _get_lpp_rate(self, age: int) -> float:
        """Get the total LPP contribution rate for the given age."""
        for min_age, max_age, rate in LPP_BONIFICATIONS:
            if min_age <= age <= max_age:
                return rate
        return 0.0

    def _recommend_3a(
        self,
        brut_mensuel: float,
        canton: str,
        age: int,
        taux_activite: float,
    ) -> dict:
        """Generate 3a (pillar 3a) recommendation."""
        annuel = brut_mensuel * 12 * (taux_activite / 100)
        eligible = annuel > 0 and age >= 18

        plafond = PILLAR_3A_LIMIT if eligible else 0.0
        montant_mensuel = round(plafond / 12, 2) if eligible else 0.0

        # Estimate tax savings
        from app.services.fiscal.cantonal_comparator import estimate_tax_saving

        canton_upper = canton.upper()
        # DIFFERENCE d'impot, pas « plafond x taux » : le taux marginal du
        # dernier franc n'est pas celui des 7'258 francs precedents.
        economie_fiscale = (
            round(estimate_tax_saving(annuel, plafond, canton_upper), 2)
            if eligible
            else 0.0
        )

        alerte_assurance_vie = (
            "Attention: evite les produits 3a lies a une assurance-vie. "
            "Ils combinent epargne et assurance avec des frais eleves et peu de flexibilite. "
            "Prefere un compte 3a bancaire ou fintech (Finpension, VIAC, frankly, etc.)."
        )

        return {
            "eligible": eligible,
            "plafond_annuel": plafond,
            "montant_mensuel_suggere": montant_mensuel,
            "economie_fiscale_estimee": economie_fiscale,
            "alerte_assurance_vie": alerte_assurance_vie,
        }

    def _recommend_franchise(self, age: int) -> dict:
        """Generate LAMal franchise recommendation.

        Young + healthy -> higher franchise saves money.
        """
        options = []
        for franchise in LAMAL_FRANCHISES:
            prime = LAMAL_PREMIUM_ESTIMATES.get(franchise, 350.0)
            # Max annual cost = 12 * prime + franchise + min(quote_part_max, 700)
            cout_annuel_max = round(prime * 12 + franchise + LAMAL_QUOTE_PART_MAX, 2)
            options.append({
                "franchise": franchise,
                "prime_mensuelle_estimee": prime,
                "cout_annuel_max": cout_annuel_max,
            })

        # Recommend highest franchise for young healthy person
        if age < 35:
            franchise_recommandee = 2500
        elif age < 50:
            franchise_recommandee = 1500
        else:
            franchise_recommandee = 300

        # Economy vs franchise 300
        cout_300 = options[0]["cout_annuel_max"]
        cout_recommandee = next(
            o["cout_annuel_max"] for o in options if o["franchise"] == franchise_recommandee
        )
        economie = round(cout_300 - cout_recommandee, 2)

        return {
            "franchises_disponibles": options,
            "franchise_recommandee": franchise_recommandee,
            "economie_annuelle_vs_300": economie,
        }

    def _build_checklist(self) -> List[str]:
        """Build the first job onboarding checklist."""
        return [
            "Comparer les comptes 3a fintech (plutôt qu'une assurance-vie)",
            "Choisir ta franchise LAMal — compare sur priminfo.admin.ch",
            "Comparer une RC privée (coût courant ~CHF 5/mois)",
            "Verifier ton certificat de prevoyance LPP",
            "Preparer ta premiere declaration fiscale",
            "Mettre en place un virement automatique epargne (10-20% du net)",
            "Demander une attestation de salaire pour les impots",
        ]


# ---------------------------------------------------------------------------
# Convenience functions
# ---------------------------------------------------------------------------

def analyser_premier_emploi(
    salaire_brut_mensuel: float,
    canton: str = "ZH",
    age: int = 25,
    etat_civil: str = "celibataire",
    has_children: bool = False,
    taux_activite: float = 100.0,
) -> dict:
    """Convenience wrapper around FirstJobOnboardingService.analyze_salary()."""
    service = FirstJobOnboardingService()
    return service.analyze_salary(
        salaire_brut_mensuel=salaire_brut_mensuel,
        canton=canton,
        age=age,
        etat_civil=etat_civil,
        has_children=has_children,
        taux_activite=taux_activite,
    )


def get_first_job_checklist() -> dict:
    """Get the generic first job checklist."""
    service = FirstJobOnboardingService()
    return {"checklist": service._build_checklist()}


def build_first_job_net_salary_receipt(
    salaire_brut_mensuel: float,
    canton: str = "ZH",
    age: int = 25,
    etat_civil: str = "celibataire",
    taux_activite: float = 100.0,
    user_provided_fields: Optional[Iterable[str]] = None,
    receipt_id: Optional[str] = None,
    computed_at: Optional[str] = None,
) -> MoneyTruthReceipt:
    """Convenience wrapper — émet le MoneyTruthReceipt firstjob.net_salary.v1."""
    service = FirstJobOnboardingService()
    return service.build_net_salary_receipt(
        salaire_brut_mensuel=salaire_brut_mensuel,
        canton=canton,
        age=age,
        etat_civil=etat_civil,
        taux_activite=taux_activite,
        user_provided_fields=user_provided_fields,
        receipt_id=receipt_id,
        computed_at=computed_at,
    )

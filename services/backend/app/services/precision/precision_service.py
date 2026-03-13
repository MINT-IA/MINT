"""
Precision Service — Pure functions for guided precision entry.

Sprint S41 — Guided Precision Entry.

Provides 4 capabilities:
1. get_field_help(field_name) — contextual help for financial fields
2. cross_validate(profile) — cross-validation alerts for coherence
3. compute_smart_defaults(archetype, age, salary, canton) — contextual estimations
4. get_precision_prompts(context, profile) — progressive precision prompts

All functions are pure (no side effects, deterministic, testable).
All text is in French (tutoiement informel).
NEVER uses banned terms: "garanti", "certain", "assure", "sans risque",
    "optimal", "meilleur", "parfait", "conseiller".

Sources:
    - LPP art. 7 (seuil d'entree: 22'680 CHF)
    - LPP art. 8 (deduction de coordination: 26'460 CHF)
    - LPP art. 15-16 (bonifications vieillesse: 7/10/15/18%)
    - LAVS art. 29ter (duree cotisation complete: 44 ans)
    - LAVS art. 34 (rente maximale: 2'520 CHF/mois)
    - OPP3 art. 7 (plafond 3a: 7'258 CHF avec LPP, 36'288 CHF sans)
    - LIFD art. 38 (imposition du capital de prevoyance)
"""

from typing import Dict, List

from app.constants.social_insurance import (
    LPP_SEUIL_ENTREE,
    LPP_DEDUCTION_COORDINATION,
    LPP_SALAIRE_COORDONNE_MIN,
    LPP_TAUX_INTERET_MIN,
    AVS_DUREE_COTISATION_COMPLETE,
    PILIER_3A_PLAFOND_AVEC_LPP,
    get_lpp_bonification_rate,
)

from app.services.precision.precision_models import (
    FieldHelp,
    CrossValidationAlert,
    SmartDefault,
    PrecisionPrompt,
)


# ═══════════════════════════════════════════════════════════════════════════════
# Constants — field help registry
# ═══════════════════════════════════════════════════════════════════════════════

_FIELD_HELP_REGISTRY: Dict[str, FieldHelp] = {
    "lpp_total": FieldHelp(
        field_name="lpp_total",
        where_to_find=(
            "Ce chiffre se trouve sur ton certificat de prevoyance, "
            "a la ligne 'Avoir de vieillesse' ou 'Total des avoirs'."
        ),
        document_name="Certificat de prevoyance (attestation LPP annuelle)",
        german_name="Altersguthaben (Vorsorgeausweis)",
        fallback_estimation=(
            "Si tu ne l'as pas sous la main, on peut estimer en fonction de ton "
            "age, salaire et archetype. L'estimation sera moins precise."
        ),
    ),
    "lpp_obligatoire": FieldHelp(
        field_name="lpp_obligatoire",
        where_to_find=(
            "Sur ton certificat de prevoyance, cherche la ligne 'Part obligatoire' "
            "ou 'Avoir de vieillesse LPP'. C'est la partie soumise au taux de "
            "conversion de 6.8% (LPP art. 14)."
        ),
        document_name="Certificat de prevoyance (attestation LPP annuelle)",
        german_name="Obligatorisches Altersguthaben (BVG-Minimum)",
        fallback_estimation=(
            "Sans cette valeur, le comparatif rente vs capital sera approximatif. "
            "On peut estimer la part obligatoire, mais elle varie selon ta caisse."
        ),
    ),
    "lpp_surobligatoire": FieldHelp(
        field_name="lpp_surobligatoire",
        where_to_find=(
            "Sur ton certificat de prevoyance, c'est la difference entre "
            "l'avoir total et la part obligatoire. Parfois indique comme "
            "'Part surobligatoire' ou 'Ueberobligatorium'."
        ),
        document_name="Certificat de prevoyance (attestation LPP annuelle)",
        german_name="Ueberobligatorisches Altersguthaben",
        fallback_estimation=(
            "On peut estimer cette valeur si tu connais le total LPP. "
            "La repartition depend de ta caisse de pension."
        ),
    ),
    "salaire_brut": FieldHelp(
        field_name="salaire_brut",
        where_to_find=(
            "Ton salaire brut annuel figure sur ta fiche de salaire (ligne 'Salaire brut') "
            "ou sur ton contrat de travail. Inclus le 13e salaire si applicable."
        ),
        document_name="Fiche de salaire mensuelle ou contrat de travail",
        german_name="Bruttolohn (Lohnabrechnung / Arbeitsvertrag)",
        fallback_estimation=(
            "Tu peux aussi regarder ta declaration fiscale: "
            "le revenu d'activite lucrative dependante."
        ),
    ),
    "salaire_net": FieldHelp(
        field_name="salaire_net",
        where_to_find=(
            "Ton salaire net mensuel figure en bas de ta fiche de salaire, "
            "apres deductions AVS, LPP, AC, impot a la source (si applicable)."
        ),
        document_name="Fiche de salaire mensuelle",
        german_name="Nettolohn (Lohnabrechnung)",
        fallback_estimation=(
            "En general, le net represente 75-85% du brut selon le canton "
            "et la situation familiale."
        ),
    ),
    "taux_marginal": FieldHelp(
        field_name="taux_marginal",
        where_to_find=(
            "Ton taux marginal d'imposition figure sur ton avis de taxation "
            "(decision de taxation), ou tu peux le calculer avec les baremes "
            "cantonaux. C'est le taux applique sur le dernier franc gagne."
        ),
        document_name="Avis de taxation (decision de taxation cantonale)",
        german_name="Grenzsteuersatz (Steuerveranlagung)",
        fallback_estimation=(
            "On peut estimer ton taux marginal a partir de ton revenu et canton. "
            "Pour un resultat exact, scanne ta declaration fiscale."
        ),
    ),
    "avs_contribution_years": FieldHelp(
        field_name="avs_contribution_years",
        where_to_find=(
            "Tu peux demander un extrait de compte individuel (CI) aupres de "
            "ta caisse de compensation AVS ou en ligne sur www.ahv-iv.ch. "
            "Le nombre d'annees de cotisation y figure."
        ),
        document_name="Extrait de compte individuel AVS (CI)",
        german_name="Individuelles Konto (IK-Auszug), Beitragsjahre",
        fallback_estimation=(
            "Si tu es arrive en Suisse a 20 ans et n'as jamais interrompu, "
            "on estime tes annees = age - 20. Pour 44 ans complets, rente AVS pleine "
            "(LAVS art. 29ter)."
        ),
    ),
    "pillar_3a_balance": FieldHelp(
        field_name="pillar_3a_balance",
        where_to_find=(
            "Le solde de ton 3e pilier figure sur ton attestation 3a annuelle "
            "de ta banque ou assurance. Regarde le releve au 31 decembre."
        ),
        document_name="Attestation 3a (releve annuel banque/assurance)",
        german_name="Saeule 3a Saldo (Bescheinigung 3. Saeule)",
        fallback_estimation=(
            "Si tu ne connais pas le solde exact, on peut estimer a partir "
            "de ton age et de tes versements annuels passes."
        ),
    ),
    "mortgage_remaining": FieldHelp(
        field_name="mortgage_remaining",
        where_to_find=(
            "Le capital restant du figure sur ton releve hypothecaire annuel "
            "ou sur ton tableau d'amortissement de la banque."
        ),
        document_name="Releve hypothecaire annuel (attestation de la banque)",
        german_name="Hypothekarrestschuld (Hypothekarabrechnung)",
        fallback_estimation=(
            "Si tu ne connais pas le montant exact, verifie ton dernier "
            "releve bancaire ou contacte ta banque."
        ),
    ),
    "monthly_expenses": FieldHelp(
        field_name="monthly_expenses",
        where_to_find=(
            "Tes charges mensuelles incluent: loyer/hypotheque, assurances, "
            "alimentation, transport, etc. Fais le total de tes depenses "
            "recurrentes sur les 3 derniers mois."
        ),
        document_name="Releves bancaires des 3 derniers mois",
        german_name="Monatliche Ausgaben (Kontoauszuege)",
        fallback_estimation=(
            "En Suisse, les charges representent en moyenne 60-75% du salaire net. "
            "On peut estimer a partir de ton salaire et de ta situation."
        ),
    ),
    "replacement_ratio": FieldHelp(
        field_name="replacement_ratio",
        where_to_find=(
            "Le taux de remplacement n'est pas sur un document: c'est le ratio "
            "entre ton revenu projete a la retraite (AVS + LPP + 3a) et ton "
            "revenu actuel. MINT le calcule pour toi."
        ),
        document_name="Calcul MINT (projection retraite)",
        german_name="Ersatzquote (Einkommensersatz im Alter)",
        fallback_estimation=(
            "En Suisse, le 1er et 2e pilier visent environ 60% du dernier salaire. "
            "Avec le 3a, on peut atteindre 70-80%."
        ),
    ),
    "tax_saving_3a": FieldHelp(
        field_name="tax_saving_3a",
        where_to_find=(
            "L'economie d'impot 3a = montant verse x taux marginal. "
            "Le montant verse figure sur ton attestation 3a. "
            "Le taux marginal figure sur ton avis de taxation."
        ),
        document_name="Attestation 3a + avis de taxation",
        german_name="Steuerersparnis 3. Saeule (Steuerbescheid)",
        fallback_estimation=(
            "Si tu verses le maximum (7'258 CHF avec LPP, OPP3 art. 7), "
            "l'economie varie de 1'500 a 2'500 CHF selon ton taux marginal."
        ),
    ),
}

# ═══════════════════════════════════════════════════════════════════════════════
# Estimated net-to-gross ratios by canton (approximate)
# ═══════════════════════════════════════════════════════════════════════════════

_CANTON_NET_RATIO: Dict[str, float] = {
    "ZH": 0.78, "BE": 0.76, "LU": 0.79, "UR": 0.80,
    "SZ": 0.82, "OW": 0.81, "NW": 0.82, "GL": 0.80,
    "ZG": 0.83, "FR": 0.77, "SO": 0.78, "BS": 0.76,
    "BL": 0.77, "SH": 0.79, "AR": 0.80, "AI": 0.81,
    "SG": 0.79, "GR": 0.79, "AG": 0.79, "TG": 0.80,
    "TI": 0.78, "VD": 0.75, "VS": 0.78, "NE": 0.76,
    "GE": 0.74, "JU": 0.76,
}

# ═══════════════════════════════════════════════════════════════════════════════
# Estimated marginal tax rates by canton and income bracket
# ═══════════════════════════════════════════════════════════════════════════════

_MARGINAL_RATES_BY_CANTON: Dict[str, Dict[str, float]] = {
    # For each canton: low (<60k), mid (60k-120k), high (>120k)
    "ZH": {"low": 0.18, "mid": 0.28, "high": 0.35},
    "BE": {"low": 0.20, "mid": 0.30, "high": 0.38},
    "LU": {"low": 0.16, "mid": 0.25, "high": 0.32},
    "UR": {"low": 0.14, "mid": 0.22, "high": 0.28},
    "SZ": {"low": 0.12, "mid": 0.20, "high": 0.26},
    "OW": {"low": 0.13, "mid": 0.21, "high": 0.27},
    "NW": {"low": 0.12, "mid": 0.20, "high": 0.26},
    "GL": {"low": 0.16, "mid": 0.25, "high": 0.31},
    "ZG": {"low": 0.10, "mid": 0.18, "high": 0.23},
    "FR": {"low": 0.19, "mid": 0.29, "high": 0.36},
    "SO": {"low": 0.18, "mid": 0.28, "high": 0.35},
    "BS": {"low": 0.21, "mid": 0.31, "high": 0.38},
    "BL": {"low": 0.19, "mid": 0.29, "high": 0.36},
    "SH": {"low": 0.17, "mid": 0.26, "high": 0.33},
    "AR": {"low": 0.16, "mid": 0.25, "high": 0.31},
    "AI": {"low": 0.13, "mid": 0.21, "high": 0.27},
    "SG": {"low": 0.17, "mid": 0.26, "high": 0.33},
    "GR": {"low": 0.16, "mid": 0.25, "high": 0.32},
    "AG": {"low": 0.17, "mid": 0.26, "high": 0.33},
    "TG": {"low": 0.16, "mid": 0.24, "high": 0.31},
    "TI": {"low": 0.18, "mid": 0.28, "high": 0.35},
    "VD": {"low": 0.22, "mid": 0.32, "high": 0.40},
    "VS": {"low": 0.17, "mid": 0.27, "high": 0.34},
    "NE": {"low": 0.20, "mid": 0.30, "high": 0.37},
    "GE": {"low": 0.22, "mid": 0.33, "high": 0.42},
    "JU": {"low": 0.20, "mid": 0.30, "high": 0.37},
}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — get_field_help
# ═══════════════════════════════════════════════════════════════════════════════


def get_field_help(field_name: str) -> FieldHelp:
    """Retourne l'aide contextuelle pour un champ financier.

    Args:
        field_name: Nom du champ (ex: "lpp_total", "salaire_brut").

    Returns:
        FieldHelp avec where_to_find, document_name, german_name, fallback.

    Raises:
        ValueError: Si le champ n'est pas reconnu.
    """
    if field_name not in _FIELD_HELP_REGISTRY:
        known = ", ".join(sorted(_FIELD_HELP_REGISTRY.keys()))
        raise ValueError(
            f"Champ inconnu: '{field_name}'. Champs disponibles: {known}"
        )
    return _FIELD_HELP_REGISTRY[field_name]


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — cross_validate
# ═══════════════════════════════════════════════════════════════════════════════


def cross_validate(profile: dict) -> List[CrossValidationAlert]:
    """Verifie la coherence des donnees du profil.

    Effectue 6 verifications croisees:
    1. LPP vs age/salaire (montant attendu)
    2. Salaire brut vs net (ratio attendu ~0.75-0.85)
    3. 3a vs age (ne peut pas avoir de 3a avant 18 ans avec revenu AVS)
    4. LPP > 0 mais independant sans LPP declare
    5. Hypotheque > 0 mais pas proprietaire
    6. Taux marginal vs revenu (coherence)

    Args:
        profile: Dictionnaire avec les champs du profil utilisateur.
                 Tous les champs sont optionnels.

    Returns:
        Liste d'alertes de coherence (peut etre vide si tout est ok).
    """
    alerts: List[CrossValidationAlert] = []

    age = profile.get("age")
    salary = profile.get("salaire_brut", profile.get("gross_salary", 0))
    net_salary = profile.get("salaire_net", profile.get("net_salary", 0))
    lpp_total = profile.get("lpp_total", 0)
    pillar_3a = profile.get("pillar_3a_balance", profile.get("pillar_3a", 0))
    mortgage = profile.get("mortgage_remaining", profile.get("mortgage", 0))
    is_owner = profile.get("is_property_owner", profile.get("is_owner", False))
    is_independant = profile.get("is_independant", profile.get("is_independent", False))
    has_lpp = profile.get("has_lpp", True)
    taux_marginal = profile.get("taux_marginal", profile.get("marginal_rate", 0))
    canton = profile.get("canton", "").upper()

    # ── Check 1: LPP vs age/salary ──────────────────────────────────────
    if lpp_total > 0 and age is not None and age >= 25 and salary > 0:
        expected_lpp = _estimate_lpp_for_age_salary(age, salary)
        low_threshold = expected_lpp * 0.3
        high_threshold = expected_lpp * 2.5

        if lpp_total < low_threshold and expected_lpp > 0:
            alerts.append(CrossValidationAlert(
                field_name="lpp_total",
                severity="warning",
                message=(
                    f"Ton avoir LPP ({_format_chf(lpp_total)}) semble bas "
                    f"pour ton age ({age} ans) et salaire ({_format_chf(salary)}/an). "
                    f"As-tu recemment change d'emploi ou retire un EPL?"
                ),
                suggestion=(
                    "Verifie sur ton certificat de prevoyance. Si tu as change "
                    "d'emploi, ton ancien avoir est sur un compte de libre passage."
                ),
            ))
        elif lpp_total > high_threshold and expected_lpp > 0:
            alerts.append(CrossValidationAlert(
                field_name="lpp_total",
                severity="warning",
                message=(
                    f"Ton avoir LPP ({_format_chf(lpp_total)}) est eleve pour "
                    f"ton profil. Est-ce que ca inclut le surobligatoire? "
                    f"C'est bien le total (obligatoire + surobligatoire)?"
                ),
                suggestion=(
                    "Si c'est correct, tant mieux — ta caisse est genereuse! "
                    "Verifie que c'est bien le total sur ton certificat."
                ),
            ))

    # ── Check 2: Salary gross vs net ratio ──────────────────────────────
    if salary > 0 and net_salary > 0:
        actual_ratio = net_salary / salary
        expected_ratio = _CANTON_NET_RATIO.get(canton, 0.78)
        tolerance = 0.08

        if actual_ratio < expected_ratio - tolerance:
            alerts.append(CrossValidationAlert(
                field_name="salaire_net",
                severity="warning",
                message=(
                    f"L'ecart entre ton brut ({_format_chf(salary)}/an) et "
                    f"ton net ({_format_chf(net_salary)}/an) est plus grand que "
                    f"la moyenne pour le canton {canton}. "
                    f"As-tu un impot a la source ou des deductions inhabituelles?"
                ),
                suggestion=(
                    "Verifie que le brut inclut le 13e salaire si applicable, "
                    "et que le net est bien apres toutes les deductions."
                ),
            ))
        elif actual_ratio > expected_ratio + tolerance:
            alerts.append(CrossValidationAlert(
                field_name="salaire_net",
                severity="warning",
                message=(
                    f"Ton net ({_format_chf(net_salary)}/an) semble eleve "
                    f"par rapport au brut ({_format_chf(salary)}/an) "
                    f"pour le canton {canton}."
                ),
                suggestion=(
                    "Verifie que tu n'as pas indique le brut mensuel et "
                    "le net annuel (ou inversement)."
                ),
            ))

    # ── Check 3: 3a vs age ──────────────────────────────────────────────
    if pillar_3a > 0 and age is not None and age < 18:
        alerts.append(CrossValidationAlert(
            field_name="pillar_3a_balance",
            severity="error",
            message=(
                "Tu ne peux ouvrir un 3e pilier qu'a partir de 18 ans "
                "avec un revenu soumis a l'AVS (OPP3 art. 7)."
            ),
            suggestion=(
                "Verifie ton age ou le montant du 3a. "
                "Si tu as moins de 18 ans, le solde devrait etre a 0."
            ),
        ))

    # Check 3b: 3a balance seems too high for age
    if pillar_3a > 0 and age is not None and age >= 18:
        max_years_contributing = age - 18
        # Max possible: years × max 3a + modest return
        max_possible = max_years_contributing * PILIER_3A_PLAFOND_AVEC_LPP * 1.15
        if pillar_3a > max_possible and max_possible > 0:
            alerts.append(CrossValidationAlert(
                field_name="pillar_3a_balance",
                severity="warning",
                message=(
                    f"Ton solde 3a ({_format_chf(pillar_3a)}) semble eleve "
                    f"pour {max_years_contributing} annees de versement possibles. "
                    f"Es-tu independant sans LPP (plafond 36'288 CHF/an)?"
                ),
                suggestion=(
                    "Si tu es salarie avec LPP, le plafond est de 7'258 CHF/an "
                    "(OPP3 art. 7). Verifie le montant sur ton attestation 3a."
                ),
            ))

    # ── Check 4: LPP > 0 but independant without LPP ───────────────────
    if lpp_total > 0 and is_independant and not has_lpp:
        alerts.append(CrossValidationAlert(
            field_name="lpp_total",
            severity="error",
            message=(
                "Tu as indique un avoir LPP mais tu es declare comme "
                "independant sans LPP. Ces informations sont contradictoires."
            ),
            suggestion=(
                "Si tu es independant avec une LPP facultative, "
                "coche 'LPP facultative'. Si tu n'as pas de LPP, "
                "mets l'avoir LPP a 0."
            ),
        ))

    # ── Check 5: Mortgage > 0 but not property owner ───────────────────
    if mortgage > 0 and not is_owner:
        alerts.append(CrossValidationAlert(
            field_name="mortgage_remaining",
            severity="error",
            message=(
                "Tu as indique une hypotheque mais tu n'es pas declare "
                "comme proprietaire. Ces informations sont contradictoires."
            ),
            suggestion=(
                "Si tu es proprietaire, coche la case correspondante. "
                "Si tu es locataire, mets l'hypotheque a 0."
            ),
        ))

    # ── Check 6: Marginal rate vs income coherence ─────────────────────
    if taux_marginal > 0 and salary > 0 and canton:
        expected_bracket = _get_income_bracket(salary)
        rates = _MARGINAL_RATES_BY_CANTON.get(canton, {})
        expected_rate = rates.get(expected_bracket, 0)

        if expected_rate > 0:
            if taux_marginal < expected_rate * 0.5:
                alerts.append(CrossValidationAlert(
                    field_name="taux_marginal",
                    severity="warning",
                    message=(
                        f"Ton taux marginal ({taux_marginal:.0%}) semble bas "
                        f"pour un revenu de {_format_chf(salary)}/an "
                        f"dans le canton {canton}."
                    ),
                    suggestion=(
                        "Le taux marginal est le taux sur le DERNIER franc gagne, "
                        "pas le taux moyen. Verifie sur ton avis de taxation."
                    ),
                ))
            elif taux_marginal > expected_rate * 1.6:
                alerts.append(CrossValidationAlert(
                    field_name="taux_marginal",
                    severity="warning",
                    message=(
                        f"Ton taux marginal ({taux_marginal:.0%}) semble eleve "
                        f"pour un revenu de {_format_chf(salary)}/an "
                        f"dans le canton {canton}."
                    ),
                    suggestion=(
                        "Verifie que c'est bien le taux marginal et pas le taux "
                        "effectif (moyen). Le taux marginal est toujours plus eleve."
                    ),
                ))

    return alerts


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — compute_smart_defaults
# ═══════════════════════════════════════════════════════════════════════════════


def compute_smart_defaults(
    archetype: str,
    age: int,
    salary: float,
    canton: str,
) -> List[SmartDefault]:
    """Calcule des estimations contextuelles pour les champs manquants.

    Prend en compte l'archetype (swiss_native, expat_eu, independent_no_lpp, etc.),
    l'age, le salaire brut annuel et le canton pour fournir des estimations
    plus precises que des valeurs generiques.

    Args:
        archetype: Archetype financier (swiss_native, expat_eu, expat_non_eu,
                   independent_with_lpp, independent_no_lpp, cross_border, etc.)
        age: Age de l'utilisateur (18-70).
        salary: Salaire brut annuel en CHF.
        canton: Code canton (2 lettres, ex: "ZH", "VD").

    Returns:
        Liste de SmartDefault avec valeur estimee, source explicative et confidence.
    """
    defaults: List[SmartDefault] = []
    canton = canton.upper()

    # ── LPP estimation ──────────────────────────────────────────────────
    lpp_estimate = _estimate_lpp_for_archetype(archetype, age, salary)
    lpp_confidence = _lpp_confidence(archetype)

    defaults.append(SmartDefault(
        field_name="lpp_total",
        value=round(lpp_estimate, 0),
        source=(
            f"Estimation basee sur ton archetype {archetype}, "
            f"{age} ans, salaire {_format_chf(salary)}/an. "
            f"Cumul des bonifications LPP minimales (LPP art. 15-16) "
            f"avec interet de {LPP_TAUX_INTERET_MIN}%."
        ),
        confidence=lpp_confidence,
    ))

    # ── Marginal tax rate estimation ────────────────────────────────────
    marginal_rate = _estimate_marginal_rate(salary, canton)
    defaults.append(SmartDefault(
        field_name="taux_marginal",
        value=round(marginal_rate, 4),
        source=(
            f"Estimation basee sur un revenu de {_format_chf(salary)}/an "
            f"dans le canton {canton}. Baremes cantonaux approximatifs "
            f"(LIFD + impot cantonal + communal)."
        ),
        confidence=0.55,
    ))

    # ── Liquidity reserve estimation ────────────────────────────────────
    net_ratio = _CANTON_NET_RATIO.get(canton, 0.78)
    monthly_net = (salary * net_ratio) / 12
    # Recommended: 3-6 months of expenses. Estimate expenses at 70% of net.
    monthly_expenses = monthly_net * 0.70
    reserve_target = monthly_expenses * 4  # 4 months middle ground

    defaults.append(SmartDefault(
        field_name="reserve_liquidite",
        value=round(reserve_target, 0),
        source=(
            f"Estimation: 4 mois de charges (~{_format_chf(monthly_expenses)}/mois). "
            f"Les specialistes recommandent 3 a 6 mois de depenses en reserve. "
            f"Charges estimees a 70% du salaire net."
        ),
        confidence=0.40,
    ))

    # ── AVS contribution years estimation ───────────────────────────────
    avs_years = _estimate_avs_years(archetype, age)
    avs_confidence = 0.60 if archetype == "swiss_native" else 0.35

    defaults.append(SmartDefault(
        field_name="avs_contribution_years",
        value=float(avs_years),
        source=(
            f"Estimation basee sur ton archetype {archetype}, age {age} ans. "
            f"Cotisation AVS presumee depuis l'age de 20 ans (LAVS art. 29ter). "
            f"Duree complete = {AVS_DUREE_COTISATION_COMPLETE} ans."
        ),
        confidence=avs_confidence,
    ))

    return defaults


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — get_precision_prompts
# ═══════════════════════════════════════════════════════════════════════════════


def get_precision_prompts(
    context: str,
    profile: dict,
) -> List[PrecisionPrompt]:
    """Retourne les demandes de precision adaptees au contexte.

    Determine quels champs manquants ou estimes impactent le plus
    le resultat dans le contexte donne, et genere des prompts
    pour demander la precision au moment opportun.

    Args:
        context: Contexte declencheur. Valeurs supportees:
            - "rente_vs_capital": module rente vs capital
            - "tax_optimization": module optimisation fiscale
            - "fri_display": affichage du Financial Resilience Index
            - "retirement_projection": projection retraite
            - "mortgage_check": verification hypothecaire
        profile: Dictionnaire du profil utilisateur (champs renseignes).

    Returns:
        Liste de PrecisionPrompt (vide si tout est renseigne).
    """
    prompts: List[PrecisionPrompt] = []

    if context == "rente_vs_capital":
        prompts.extend(_prompts_rente_vs_capital(profile))
    elif context == "tax_optimization":
        prompts.extend(_prompts_tax_optimization(profile))
    elif context == "fri_display":
        prompts.extend(_prompts_fri_display(profile))
    elif context == "retirement_projection":
        prompts.extend(_prompts_retirement(profile))
    elif context == "mortgage_check":
        prompts.extend(_prompts_mortgage(profile))

    return prompts


# ═══════════════════════════════════════════════════════════════════════════════
# Private helpers — LPP estimation
# ═══════════════════════════════════════════════════════════════════════════════


def _estimate_lpp_for_age_salary(age: int, salary: float) -> float:
    """Estime l'avoir LPP cumule pour un age et salaire donnes (swiss_native)."""
    if salary < LPP_SEUIL_ENTREE or age < 25:
        return 0.0

    coordonne = max(salary - LPP_DEDUCTION_COORDINATION, LPP_SALAIRE_COORDONNE_MIN)
    coordonne = min(coordonne, 64_260.0)  # LPP_SALAIRE_COORDONNE_MAX

    total = 0.0
    rate = LPP_TAUX_INTERET_MIN / 100  # 1.25%

    for yr_age in range(25, min(age + 1, 66)):
        bonif_rate = get_lpp_bonification_rate(yr_age)
        annual_bonif = coordonne * bonif_rate
        total = total * (1 + rate) + annual_bonif

    return total


def _estimate_lpp_for_archetype(archetype: str, age: int, salary: float) -> float:
    """Estime l'avoir LPP selon l'archetype."""
    if archetype in ("independent_no_lpp",):
        return 0.0

    if salary < LPP_SEUIL_ENTREE:
        return 0.0

    if archetype in ("expat_eu", "expat_non_eu", "expat_us"):
        # Expats: assume contributions started at max(25, arrival ~30 for estimation)
        start_age = max(25, 30)  # Conservative: assume arrived at ~30
        if age < start_age:
            return 0.0
        return _estimate_lpp_cumulative(start_age, age, salary)

    if archetype == "cross_border":
        # Cross-border: LPP suisse standard, contributions from 25
        return _estimate_lpp_cumulative(25, age, salary)

    if archetype == "independent_with_lpp":
        # Independent with voluntary LPP: assume lower coverage (60% of standard)
        return _estimate_lpp_cumulative(25, age, salary) * 0.60

    # swiss_native, returning_swiss, default
    return _estimate_lpp_cumulative(25, age, salary)


def _estimate_lpp_cumulative(start_age: int, current_age: int, salary: float) -> float:
    """Calcule l'accumulation LPP de start_age a current_age."""
    if current_age < start_age or salary < LPP_SEUIL_ENTREE:
        return 0.0

    coordonne = max(salary - LPP_DEDUCTION_COORDINATION, LPP_SALAIRE_COORDONNE_MIN)
    coordonne = min(coordonne, 64_260.0)

    total = 0.0
    rate = LPP_TAUX_INTERET_MIN / 100

    for yr_age in range(max(start_age, 25), min(current_age + 1, 66)):
        bonif_rate = get_lpp_bonification_rate(yr_age)
        annual_bonif = coordonne * bonif_rate
        total = total * (1 + rate) + annual_bonif

    return total


def _lpp_confidence(archetype: str) -> float:
    """Confidence de l'estimation LPP selon l'archetype."""
    confidence_map = {
        "swiss_native": 0.45,
        "expat_eu": 0.25,
        "expat_non_eu": 0.20,
        "expat_us": 0.20,
        "independent_with_lpp": 0.25,
        "independent_no_lpp": 0.90,  # 0 is certain
        "cross_border": 0.35,
        "returning_swiss": 0.20,
    }
    return confidence_map.get(archetype, 0.30)


# ═══════════════════════════════════════════════════════════════════════════════
# Private helpers — Tax estimation
# ═══════════════════════════════════════════════════════════════════════════════


def _estimate_marginal_rate(salary: float, canton: str) -> float:
    """Estime le taux marginal d'imposition."""
    bracket = _get_income_bracket(salary)
    rates = _MARGINAL_RATES_BY_CANTON.get(canton, _MARGINAL_RATES_BY_CANTON.get("ZH", {}))
    return rates.get(bracket, 0.25)


def _get_income_bracket(salary: float) -> str:
    """Determine la tranche de revenu."""
    if salary < 60_000:
        return "low"
    elif salary <= 120_000:
        return "mid"
    return "high"


# ═══════════════════════════════════════════════════════════════════════════════
# Private helpers — AVS estimation
# ═══════════════════════════════════════════════════════════════════════════════


def _estimate_avs_years(archetype: str, age: int) -> int:
    """Estime les annees de cotisation AVS."""
    if age < 20:
        return 0

    if archetype == "swiss_native":
        return min(age - 20, AVS_DUREE_COTISATION_COMPLETE)

    if archetype in ("expat_eu", "expat_non_eu", "expat_us"):
        # Assume arrival ~30, so fewer years in CH
        ch_years = max(0, age - 30)
        return min(ch_years, AVS_DUREE_COTISATION_COMPLETE)

    if archetype == "cross_border":
        # Frontaliers: cotisent en CH
        return min(age - 20, AVS_DUREE_COTISATION_COMPLETE)

    if archetype == "returning_swiss":
        # Returning: assume 5 years gap
        return min(max(0, age - 20 - 5), AVS_DUREE_COTISATION_COMPLETE)

    # Default: assume from 20
    return min(age - 20, AVS_DUREE_COTISATION_COMPLETE)


# ═══════════════════════════════════════════════════════════════════════════════
# Private helpers — Precision prompts per context
# ═══════════════════════════════════════════════════════════════════════════════


def _prompts_rente_vs_capital(profile: dict) -> List[PrecisionPrompt]:
    """Prompts pour le module rente vs capital."""
    prompts: List[PrecisionPrompt] = []

    if not profile.get("lpp_obligatoire"):
        prompts.append(PrecisionPrompt(
            trigger="rente_vs_capital_opened",
            field_needed="lpp_obligatoire",
            prompt_text=(
                "Pour comparer rente et capital precisement, on a besoin "
                "de la part obligatoire de ta LPP. Elle est soumise au taux "
                "de conversion de 6.8% (LPP art. 14)."
            ),
            impact_text=(
                "Resultat plus fiable de 20-30%. La repartition obligatoire/"
                "surobligatoire change radicalement le comparatif."
            ),
        ))

    if not profile.get("taux_marginal") and not profile.get("marginal_rate"):
        prompts.append(PrecisionPrompt(
            trigger="rente_vs_capital_opened",
            field_needed="taux_marginal",
            prompt_text=(
                "Ton taux marginal d'imposition influence la fiscalite du "
                "retrait en capital. Avec ton vrai taux, le comparatif sera "
                "plus precis."
            ),
            impact_text=(
                "Precision fiscale amélioree. L'ecart de taux peut "
                "representer plusieurs milliers de CHF sur le retrait."
            ),
        ))

    return prompts


def _prompts_tax_optimization(profile: dict) -> List[PrecisionPrompt]:
    """Prompts pour le module optimisation fiscale."""
    prompts: List[PrecisionPrompt] = []

    if not profile.get("taux_marginal") and not profile.get("marginal_rate"):
        prompts.append(PrecisionPrompt(
            trigger="tax_optimization_opened",
            field_needed="taux_marginal",
            prompt_text=(
                "Pour estimer tes economies d'impot (3a, rachat LPP), "
                "on a besoin de ton taux marginal. Il figure sur ton "
                "avis de taxation."
            ),
            impact_text=(
                "Economies fiscales calculees au franc pres. "
                "Un ecart de 5% sur le taux = des centaines de CHF de difference."
            ),
        ))

    if not profile.get("pillar_3a_balance") and not profile.get("pillar_3a"):
        prompts.append(PrecisionPrompt(
            trigger="tax_optimization_opened",
            field_needed="pillar_3a_balance",
            prompt_text=(
                "Ton solde 3a actuel nous aide a calculer ton potentiel "
                "d'economie et a planifier tes retraits futurs."
            ),
            impact_text=(
                "Planification fiscale du retrait 3a plus precise. "
                "L'echelonnement des retraits peut faire economiser des milliers de CHF."
            ),
        ))

    return prompts


def _prompts_fri_display(profile: dict) -> List[PrecisionPrompt]:
    """Prompts pour l'affichage du Financial Resilience Index."""
    prompts: List[PrecisionPrompt] = []

    # Find the most impactful missing fields
    critical_fields = [
        ("lpp_total", "Ton avoir LPP est la plus grande composante de ta retraite."),
        ("taux_marginal", "Ton taux marginal determine l'efficacite fiscale de tes actions."),
        ("monthly_expenses", "Tes charges mensuelles determinent ta resilience de liquidite."),
        ("pillar_3a_balance", "Ton solde 3a impacte ton score fiscal et retraite."),
    ]

    for field_name, explanation in critical_fields:
        if not profile.get(field_name):
            prompts.append(PrecisionPrompt(
                trigger="fri_display_opened",
                field_needed=field_name,
                prompt_text=(
                    f"Pour un score FRI plus fiable, renseigne: {field_name}. "
                    f"{explanation}"
                ),
                impact_text="Score FRI plus representatif de ta situation reelle.",
            ))

    return prompts


def _prompts_retirement(profile: dict) -> List[PrecisionPrompt]:
    """Prompts pour la projection retraite."""
    prompts: List[PrecisionPrompt] = []

    if not profile.get("avs_contribution_years"):
        prompts.append(PrecisionPrompt(
            trigger="retirement_projection_opened",
            field_needed="avs_contribution_years",
            prompt_text=(
                "Tes annees de cotisation AVS determinent ta rente. "
                "Demande ton extrait CI sur www.ahv-iv.ch pour le chiffre exact."
            ),
            impact_text=(
                "Rente AVS calculee au franc pres. "
                "Chaque annee manquante reduit la rente d'environ 2.3%."
            ),
        ))

    if not profile.get("lpp_total"):
        prompts.append(PrecisionPrompt(
            trigger="retirement_projection_opened",
            field_needed="lpp_total",
            prompt_text=(
                "Ton avoir LPP est estime. Avec ton certificat de prevoyance, "
                "la projection sera nettement plus fiable."
            ),
            impact_text=(
                "Projection retraite avec une marge d'erreur reduite de 15-25%."
            ),
        ))

    return prompts


def _prompts_mortgage(profile: dict) -> List[PrecisionPrompt]:
    """Prompts pour la verification hypothecaire."""
    prompts: List[PrecisionPrompt] = []

    if not profile.get("mortgage_remaining") and not profile.get("mortgage"):
        prompts.append(PrecisionPrompt(
            trigger="mortgage_check_opened",
            field_needed="mortgage_remaining",
            prompt_text=(
                "Le capital restant du figure sur ton releve hypothecaire. "
                "Avec ce chiffre, le calcul de tragabilite sera exact."
            ),
            impact_text="Ratio d'endettement calcule avec precision.",
        ))

    return prompts


# ═══════════════════════════════════════════════════════════════════════════════
# Private helpers — Formatting
# ═══════════════════════════════════════════════════════════════════════════════


def _format_chf(amount: float) -> str:
    """Formate un montant en CHF lisible."""
    if amount >= 1_000_000:
        return f"CHF {amount:,.0f}".replace(",", "'")
    elif amount >= 1_000:
        return f"CHF {amount:,.0f}".replace(",", "'")
    return f"CHF {amount:.0f}"

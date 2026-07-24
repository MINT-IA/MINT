"""Wave 1a D-02 — 1:1 Python port of Flutter CoupleOptimizer.

Source of truth: ``apps/mobile/lib/services/financial_core/couple_optimizer.dart``
(423 lines, 4 analyses).

All FR strings are copied VERBATIM from the Dart source (Wave 1a D-13 +
CLAUDE.md rule 1 LSFin banned-terms compliance). Tax helpers (marginal
rate, tax saving, monthly income tax) and AVS helpers (computeMonthlyRente,
computeCouple, annualRente) are mirrored INLINE because the Python backend
has no equivalent of the Dart RetirementTaxCalculator helpers nor of the
Dart fiscal-service ``estimateTax`` shape (verified by repo-wide grep at
plan-time 2026-05-14). The existing Python retirement AVS estimation
service has a different signature (no ``arrivalAge``, no ``isFemale``, no
``birthYear`` parameter) — delegating would silently diverge.

Every non-trivial branch carries a ``# MIRROR Dart <file>:<line>``
traceability comment so the port can be cross-reviewed line-by-line
against the Dart source.

Analyses (mirroring Dart lines):
  1. LPP buyback order      — Dart lines 180-242
  2. 3a contribution order  — Dart lines 246-315 (incl. FATCA check)
  3. AVS couple cap         — Dart lines 319-369 (LAVS art. 35)
  4. Marriage penalty       — Dart lines 373-422

The legacy formatter at ``coach_chat.py:_format_couple_optimization`` reads
the same dict keys this port emits via ``to_legacy_dict()``
(``lpp_buyback``, ``pillar_3a``, ``avs_cap``, ``marriage_penalty`` with
sub-keys ``winner``, ``saving_delta``, ``reason``, ``trade_off``,
``cap_applied``, ``monthly_reduction``, ``has_penalty``, ``annual_delta``).
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, Optional


# ────────────────────────────────────────────────────────────
#  Enums and result dataclasses
# ────────────────────────────────────────────────────────────


class CoupleWinner(str, Enum):
    """Who should act first in a couple optimization.

    # MIRROR Dart couple_optimizer.dart:34 — ``enum CoupleWinner { mainUser, conjoint, noPreference }``

    Decision recorded 2026-05-14: Dart ``CoupleAnalysisResult`` has NO
    ``toJson()`` method (verified by grep across ``apps/mobile/lib/``;
    no ``CoupleAnalysisResult.toJson`` callsite exists). The legacy
    formatter at ``coach_chat.py:2729`` interpolates the ``winner``
    string raw into the FR sentence — neither side has a canonical
    serialization. We choose snake_case Python values so the port is
    self-consistent with the legacy ``ctx['couple_optimization']
    ['lpp_buyback']['winner']`` snake_case shape, and the plan-07
    parity test catches any Dart-side divergence later.
    """

    MAIN_USER = "main_user"
    CONJOINT = "conjoint"
    NO_PREFERENCE = "no_preference"


@dataclass(frozen=True)
class CoupleAnalysisResult:
    """Result of a single couple optimization analysis.

    # MIRROR Dart couple_optimizer.dart:37-57
    """

    winner: CoupleWinner
    saving_delta: float  # MIRROR Dart savingDelta (line 43) — absolute CHF.
    reason: str  # MIRROR Dart reason (line 46) — coach context, not user-facing directly.
    trade_off: str  # MIRROR Dart tradeOff (line 49) — LSFin compliance text.


@dataclass(frozen=True)
class AvsCoupleCapResult:
    """AVS couple cap result.

    # MIRROR Dart couple_optimizer.dart:60-82
    """

    cap_applied: bool  # MIRROR Dart capApplied (line 62).
    monthly_reduction: float  # MIRROR Dart monthlyReduction (line 65).
    user_rente_before_cap: float  # MIRROR Dart userRenteBeforeCap (line 68).
    conjoint_rente_before_cap: float  # MIRROR Dart conjointRenteBeforeCap (line 71).
    total_after_cap: float  # MIRROR Dart totalAfterCap (line 74).


@dataclass(frozen=True)
class MarriagePenaltyResult:
    """Marriage penalty analysis result.

    # MIRROR Dart couple_optimizer.dart:86-101
    """

    has_penalty: bool  # MIRROR Dart hasPenalty (line 88) — True if married pays MORE tax.
    annual_delta: float  # MIRROR Dart annualDelta (line 91) — +: penalty, -: bonus.
    trade_off: str  # MIRROR Dart tradeOff (line 94).


@dataclass(frozen=True)
class CoupleOptimizationResult:
    """Complete couple optimization output.

    # MIRROR Dart couple_optimizer.dart:104-130
    """

    lpp_buyback_order: Optional[CoupleAnalysisResult] = None
    pillar_3a_order: Optional[CoupleAnalysisResult] = None
    avs_cap: Optional[AvsCoupleCapResult] = None
    marriage_penalty: Optional[MarriagePenaltyResult] = None

    @classmethod
    def empty(cls) -> "CoupleOptimizationResult":
        """Return an empty result when no conjoint data is available.

        # MIRROR Dart couple_optimizer.dart:118-122 (const empty()).
        """
        return cls()

    @property
    def has_results(self) -> bool:
        """True when at least one analysis produced a result.

        # MIRROR Dart couple_optimizer.dart:125-129 (hasResults getter).
        """
        return (
            self.lpp_buyback_order is not None
            or self.pillar_3a_order is not None
            or self.avs_cap is not None
            or self.marriage_penalty is not None
        )

    def to_legacy_dict(self) -> Dict[str, Any]:
        """Produce the dict shape consumed by ``_format_couple_optimization``.

        The legacy formatter at ``coach_chat.py:2707-2761`` reads keys
        ``lpp_buyback``, ``pillar_3a``, ``avs_cap``, ``marriage_penalty``
        (snake_case top-level) with sub-keys ``winner``, ``saving_delta``,
        ``reason``, ``trade_off``, ``cap_applied``, ``monthly_reduction``,
        ``has_penalty``, ``annual_delta``. This method emits exactly that
        shape so callers can interleave the new path with the legacy
        formatter without contract drift.
        """
        out: Dict[str, Any] = {}
        if self.lpp_buyback_order is not None:
            out["lpp_buyback"] = {
                "winner": self.lpp_buyback_order.winner.value,
                "saving_delta": self.lpp_buyback_order.saving_delta,
                "reason": self.lpp_buyback_order.reason,
                "trade_off": self.lpp_buyback_order.trade_off,
            }
        if self.pillar_3a_order is not None:
            out["pillar_3a"] = {
                "winner": self.pillar_3a_order.winner.value,
                "saving_delta": self.pillar_3a_order.saving_delta,
                "reason": self.pillar_3a_order.reason,
                "trade_off": self.pillar_3a_order.trade_off,
            }
        if self.avs_cap is not None:
            out["avs_cap"] = {
                "cap_applied": self.avs_cap.cap_applied,
                "monthly_reduction": self.avs_cap.monthly_reduction,
                "user_rente_before_cap": self.avs_cap.user_rente_before_cap,
                "conjoint_rente_before_cap": self.avs_cap.conjoint_rente_before_cap,
                "total_after_cap": self.avs_cap.total_after_cap,
            }
        if self.marriage_penalty is not None:
            out["marriage_penalty"] = {
                "has_penalty": self.marriage_penalty.has_penalty,
                "annual_delta": self.marriage_penalty.annual_delta,
                "trade_off": self.marriage_penalty.trade_off,
            }
        return out


# ────────────────────────────────────────────────────────────
#  Constants (mirrored verbatim from Dart sources)
# ────────────────────────────────────────────────────────────


# MIRROR Dart tax_calculator.dart:299-305
_FAMILY_ADJUSTMENT: Dict[str, float] = {
    "celibataire": 1.00,
    "marie_sans_enfant": 0.85,
    "marie_1_enfant": 0.78,
    "marie_2_enfants": 0.72,
    "marie_3_enfants": 0.66,
}

# MIRROR Dart couple_optimizer.dart:146
_MIN_DELTA: float = 100.0

# MIRROR Dart social_insurance.dart:351 — `const double pilier3aPlafondAvecLpp = 7258.0`
# Also matches backend constant PILIER_3A_PLAFOND_AVEC_LPP at
# `services/backend/app/constants/social_insurance.py:339`.
_PILIER_3A_PLAFOND_AVEC_LPP: float = 7258.0

# AVS constants — MIRROR Dart social_insurance.dart:
_AVS_RENTE_MAX_MENSUELLE: float = 2520.0  # line 118
_AVS_RENTE_MIN_MENSUELLE: float = 1260.0  # line 121
_AVS_RENTE_COUPLE_MAX_MENSUELLE: float = 3780.0  # line 124 — LAVS art. 35 cap.
_AVS_DUREE_COTISATION_COMPLETE: int = 44  # line 133
_AVS_AGE_REFERENCE_HOMME: int = 65  # line 136
_AVS_REDUCTION_ANTICIPATION: float = 0.068  # line 160
_AVS_RAMD_MAX: float = 90_720.0  # line 204 — OFAS 318.117.011 (audit -zaw)
_AVS_13EME_ACTIVE: bool = True  # line 252
_AVS_NOMBRE_RENTES_PAR_AN: int = 13  # line 258

# MIRROR Dart social_insurance.dart:192-198 — late retirement bonus.
# Mémento OFAS 3.04 (audit -zaw) : 5.2 / 10.8 / 17.1 / 24.0 / 31.5 %.
_AVS_DEFERRAL_BONUS: Dict[int, float] = {
    1: 0.052,
    2: 0.108,
    3: 0.171,
    4: 0.240,
    5: 0.315,
}

# Echelle 44 (rente AVS depuis RAMD) : PAS de copie locale. La table + le
# lookup canoniques vivent dans app.constants.social_insurance.rente_from_ramd
# (règle 4 / NEVER #3 — une seule source de vérité backend, alimentée par le
# registre avs.echelle44). Voir _avs_compute_monthly_rente ci-dessous.


# ────────────────────────────────────────────────────────────
#  Tax helpers (mirrored INLINE from RetirementTaxCalculator)
# ────────────────────────────────────────────────────────────



def _family_key(*, is_married: bool, children: int) -> str:
    """Resolve the family adjustment key.

    # MIRROR Dart tax_calculator.dart:339-350.
    """
    if not is_married:
        return "celibataire"
    if children >= 3:
        return "marie_3_enfants"
    if children == 2:
        return "marie_2_enfants"
    if children == 1:
        return "marie_1_enfant"
    return "marie_sans_enfant"


def _child_factor(*, is_married: bool, children: int) -> float:
    """Réduction supplémentaire enfants RELATIVE à marié sans enfant.

    Ratios de la grille _FAMILY_ADJUSTMENT (approximation des déductions
    par enfant) — même convention que CantonalComparator.estimate_tax
    (PR #997). Célibataire avec enfants : inchangé (limite dite).
    """
    if not is_married or children <= 0:
        return 1.0
    return _FAMILY_ADJUSTMENT[
        _family_key(is_married=True, children=children)
    ] / _FAMILY_ADJUSTMENT["marie_sans_enfant"]


def _estimate_marginal_rate(
    revenu_brut_annuel: float,
    canton: str,
    *,
    is_married: bool = False,
    children: int = 0,
) -> float:
    """Taux marginal par différence sur le modèle v2 (beads -5up).

    Remplace « effectif(100k) x facteur revenu x 1.3 » (copie privée du
    modèle v1 supprimé de cantonal_comparator par PR #997) par la pente
    locale du modèle canonique : (impôt(r) - impôt(r - 1000)) / 1000.
    Enfants : ratio relatif marié (_child_factor). Borné à [0.0, 0.50]
    (convention lpp_conversion) — l'ancien plancher 5% inventait une
    économie pour des revenus non imposés.
    """
    from app.services.fiscal.cantonal_comparator import estimate_income_tax

    if revenu_brut_annuel <= 0:
        return 0.0
    delta = min(1000.0, revenu_brut_annuel)
    cf = _child_factor(is_married=is_married, children=children)
    hi = estimate_income_tax(revenu_brut_annuel, canton, is_married=is_married)
    lo = estimate_income_tax(
        revenu_brut_annuel - delta, canton, is_married=is_married
    )
    marginal = cf * (hi - lo) / delta
    return max(0.0, min(0.50, marginal))


def _estimate_tax_saving(
    income: float,
    deduction: float,
    canton: str,
    *,
    is_married: bool = False,
    children: int = 0,
    steps: int = 10,
) -> float:
    """Économie fiscale d'une déduction — différence EXACTE du modèle v2.

    L'intégration en 10 pas du miroir v1 approximait l'aire sous la
    marginale ; le modèle v2 se calcule directement :
    impôt(revenu) - impôt(revenu - déduction). ``steps`` est conservé
    pour compat de signature (ignoré). Enfants : ratio relatif marié.
    """
    from app.services.fiscal.cantonal_comparator import estimate_income_tax

    if deduction <= 0 or income <= 0:
        return 0.0
    cf = _child_factor(is_married=is_married, children=children)
    saving = estimate_income_tax(
        income, canton, is_married=is_married
    ) - estimate_income_tax(
        max(0.0, income - deduction), canton, is_married=is_married
    )
    return max(0.0, cf * saving)


def _estimate_monthly_income_tax(
    revenu_annuel_imposable: float,
    canton: str,
    *,
    etat_civil: str = "celibataire",
    nombre_enfants: int = 0,
) -> float:
    """Impôt revenu mensuel — modèle v2 / 12 (beads -5up).

    Remplace « revenu x taux effectif recomposé » par le modèle canonique
    estimate_income_tax (IFD 2026 + interpolation ESTV). Enfants : ratio
    relatif marié.
    """
    from app.services.fiscal.cantonal_comparator import estimate_income_tax

    if revenu_annuel_imposable <= 0:
        return 0.0
    is_married = etat_civil == "marie"
    cf = _child_factor(is_married=is_married, children=nombre_enfants)
    charge_totale = cf * estimate_income_tax(
        revenu_annuel_imposable, canton, is_married=is_married
    )
    return charge_totale / 12.0


# ────────────────────────────────────────────────────────────
#  AVS helpers (mirrored INLINE from AvsCalculator)
# ────────────────────────────────────────────────────────────


def _avs_compute_monthly_rente(
    *,
    current_age: int,
    retirement_age: int,
    gross_annual_salary: float = 0.0,
    arrival_age: Optional[int] = None,
    is_female: Optional[bool] = None,
    birth_year: Optional[int] = None,
) -> float:
    """Compute individual AVS monthly rente.

    # MIRROR Dart avs_calculator.dart:29-118 (computeMonthlyRente).

    Simplified Python port — covers the subset of inputs used by
    ``_analyze_avs_cap`` (no divorce splitting, no child-raising
    credits, no scan-derived ``anneesContribuees`` override). The Dart
    method also supports those paths but the couple analysis does not
    pass them.
    """
    # Gender-aware reference age (AVS21, LAVS art. 21 al. 1).
    # MIRROR Dart avs_calculator.dart:44-47 — refAge resolution.
    if is_female is not None and birth_year is not None:
        # Fonction partagée par cohorte (beads -xx9) — miroir Dart
        # social_insurance.dart avsReferenceAge, une seule implémentation
        # backend (règle 4).
        from app.constants.social_insurance import avs_reference_age

        ref_age = avs_reference_age(birth_year, is_female)
    else:
        ref_age = _AVS_AGE_REFERENCE_HOMME  # 65 — male/unknown default.

    full_years = _AVS_DUREE_COTISATION_COMPLETE

    # MIRROR Dart avs_calculator.dart:52-61 — current contribution years.
    if arrival_age is not None and arrival_age > 20:
        current_years = max(0, min(current_age - arrival_age, full_years))
    else:
        current_years = max(0, min(current_age - 20, full_years))
    future_years = max(0, min(retirement_age - current_age, 50))
    total_years = max(0, min(current_years + future_years, full_years))
    effective_years = max(0, min(total_years, full_years))  # no lacunes input
    gap_factor = effective_years / full_years if full_years > 0 else 0.0

    # MIRROR Dart avs_calculator.dart:69-102 — RAMD-based rente.
    # Fonction canonique unique (règle 4 / NEVER #3) — pas de copie locale.
    from app.constants.social_insurance import rente_from_ramd

    effective_salary = gross_annual_salary
    base_rente = rente_from_ramd(effective_salary)
    rente = base_rente * gap_factor

    # MIRROR Dart avs_calculator.dart:104-115 — early/late retirement adjustments.
    if retirement_age < 63:
        return 0.0  # MIRROR Dart line 107 — anticipation only from 63.
    elif retirement_age < ref_age:
        years_early = ref_age - retirement_age
        rente *= 1.0 - _AVS_REDUCTION_ANTICIPATION * years_early
    elif retirement_age > ref_age:
        years_late = max(1, min(retirement_age - ref_age, 5))
        bonus = _AVS_DEFERRAL_BONUS.get(years_late, _AVS_DEFERRAL_BONUS[5])
        rente *= 1.0 + bonus
    return rente


def _avs_compute_couple(
    *,
    avs_user: float,
    avs_conjoint: float,
    is_married: bool,
) -> Dict[str, float]:
    """Couple AVS with married cap (LAVS art. 35).

    # MIRROR Dart avs_calculator.dart:156-169 (computeCouple).

    Married couples: total capped at 150% of individual max (3780 CHF).
    Concubins: each gets individual rente, no cap.
    """
    total = avs_user + avs_conjoint
    couple_max = _AVS_RENTE_COUPLE_MAX_MENSUELLE
    if is_married and total > couple_max:
        ratio = couple_max / total
        return {
            "user": avs_user * ratio,
            "conjoint": avs_conjoint * ratio,
            "total": couple_max,
        }
    return {"user": avs_user, "conjoint": avs_conjoint, "total": total}


def _avs_annual_rente(monthly_rente: float, *, include_13eme: bool = True) -> float:
    """Convert monthly AVS rente to annual, including the 13th rente if active.

    # MIRROR Dart avs_calculator.dart:212-220 (annualRente).
    """
    if include_13eme and _AVS_13EME_ACTIVE:
        return monthly_rente * _AVS_NOMBRE_RENTES_PAR_AN
    return monthly_rente * 12


# ────────────────────────────────────────────────────────────
#  Profile-data accessors (untrusted-shape tolerant)
# ────────────────────────────────────────────────────────────


def _f(value: Any, default: float = 0.0) -> float:
    """Coerce to float with default. Untrusted profile_data shape tolerant."""
    if value is None:
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _i(value: Any, default: Optional[int] = None) -> Optional[int]:
    """Coerce to int with default."""
    if value is None:
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _user_income(profile_data: Dict[str, Any]) -> float:
    """User annual income: ``salaireBrutMensuel * nombreDeMois``.

    # MIRROR Dart couple_optimizer.dart:164 (user.salaireBrutMensuel * user.nombreDeMois).
    """
    return _f(profile_data.get("salaireBrutMensuel")) * _f(
        profile_data.get("nombreDeMois"), default=12.0
    )


def _conjoint_income(conjoint: Dict[str, Any]) -> float:
    """Conjoint annual income: salaireBrutMensuel * nombreDeMois + bonus.

    # MIRROR Dart coach_profile.dart:183-188 (ConjointProfile.revenuBrutAnnuel getter).
    """
    salaire = conjoint.get("salaireBrutMensuel")
    if salaire is None:
        return 0.0
    base = _f(salaire) * _f(conjoint.get("nombreDeMois"), default=12.0)
    bonus_pct = _f(conjoint.get("bonusPourcentage"), default=0.0)
    return base + bonus_pct / 100.0 * base


def _user_age(profile_data: Dict[str, Any]) -> Optional[int]:
    """Compute user age from birthYear (current year minus birthYear)."""
    birth_year = _i(profile_data.get("birthYear"))
    if birth_year is None or birth_year < 1900 or birth_year > 2030:
        return None
    # MIRROR Dart coach_profile.dart:192-206 (ConjointProfile.age getter).
    from datetime import datetime as _dt
    return _dt.now().year - birth_year


def _conjoint_age(conjoint: Dict[str, Any]) -> Optional[int]:
    """Compute conjoint age (mirrors ConjointProfile.age getter)."""
    birth_year = _i(conjoint.get("birthYear"))
    if birth_year is None or birth_year < 1900:
        return None
    from datetime import datetime as _dt
    current_year = _dt.now().year
    if birth_year > current_year - 10:
        return None
    return current_year - birth_year


def _user_effective_retirement_age(profile_data: Dict[str, Any]) -> int:
    """User target retirement age (default 65). Mirrors Dart getter."""
    return _i(profile_data.get("desiredRetirementAge"), default=65) or 65


def _conjoint_effective_retirement_age(conjoint: Dict[str, Any]) -> int:
    """Conjoint effective retirement age — Dart default 65.

    # MIRROR Dart coach_profile.dart:209 (ConjointProfile.effectiveRetirementAge).
    """
    return _i(conjoint.get("targetRetirementAge"), default=65) or 65


def _lacune_rachat_restante(prevoyance: Optional[Dict[str, Any]]) -> float:
    """Mirror PrevoyanceProfile.lacuneRachatRestante (Dart line 419-422).

    Returns ``max(rachatMaximum - rachatEffectue, 0)``.
    """
    if not prevoyance:
        return 0.0
    rachat_max = _f(prevoyance.get("rachatMaximum"))
    rachat_eff = _f(prevoyance.get("rachatEffectue"))
    return max(0.0, rachat_max - rachat_eff)


# ────────────────────────────────────────────────────────────
#  CoupleOptimizer service (port of Dart class)
# ────────────────────────────────────────────────────────────


class CoupleOptimizer:
    """Couple financial optimizer — Python port of Flutter ``CoupleOptimizer``.

    # MIRROR Dart couple_optimizer.dart:141-423 (entire class).

    Pure functions only. No side effects. Reads from ``profile_data``
    dict (the ``ProfileModel.data`` JSON dict using ``CoachProfile.toJson()``
    keys verbatim — camelCase).
    """

    # Block direct instantiation — mirror Dart `CoupleOptimizer._()` private ctor.
    def __init__(self) -> None:  # pragma: no cover
        raise TypeError("CoupleOptimizer is a static utility — do not instantiate.")

    @staticmethod
    def optimize(profile_data: Dict[str, Any]) -> CoupleOptimizationResult:
        """Run all 4 couple analyses.

        # MIRROR Dart couple_optimizer.dart:155-176 (CoupleOptimizer.optimize).

        Returns ``CoupleOptimizationResult.empty()`` when:
          - ``conjoint`` sub-dict is None / missing, OR
          - both user and conjoint incomes are zero.
        """
        conjoint = profile_data.get("conjoint")
        # MIRROR Dart line 160: no conjoint → empty.
        if not conjoint or not isinstance(conjoint, dict):
            return CoupleOptimizationResult.empty()

        user_income = _user_income(profile_data)
        conjoint_income = _conjoint_income(conjoint)
        # MIRROR Dart lines 164-168: both incomes zero → empty.
        if user_income <= 0 and conjoint_income <= 0:
            return CoupleOptimizationResult.empty()

        return CoupleOptimizationResult(
            lpp_buyback_order=CoupleOptimizer._analyze_lpp_buyback_order(
                profile_data, conjoint
            ),
            pillar_3a_order=CoupleOptimizer._analyze_3a_contribution_order(
                profile_data, conjoint
            ),
            avs_cap=CoupleOptimizer._analyze_avs_cap(profile_data, conjoint),
            marriage_penalty=CoupleOptimizer._analyze_marriage_penalty(
                profile_data, conjoint
            ),
        )

    # ── Analysis 1: LPP buyback order ──────────────────────────
    # MIRROR Dart couple_optimizer.dart:180-242 (_analyzeLppBuybackOrder).

    @staticmethod
    def _analyze_lpp_buyback_order(
        user: Dict[str, Any], conjoint: Dict[str, Any]
    ) -> Optional[CoupleAnalysisResult]:
        user_rachat = _lacune_rachat_restante(user.get("prevoyance"))
        conjoint_rachat = _lacune_rachat_restante(conjoint.get("prevoyance"))

        # MIRROR Dart line 188: both must have a buyback possibility.
        if user_rachat <= 0 and conjoint_rachat <= 0:
            return None

        user_income = _user_income(user)
        conjoint_income = _conjoint_income(conjoint)
        # MIRROR Dart line 192.
        if user_income <= 0 and conjoint_income <= 0:
            return None

        # MIRROR Dart line 195 — reference rachat amount = 10'000 CHF.
        reference_amount = 10_000.0
        canton = user.get("canton") or "ZH"
        children = _i(user.get("nombreEnfants"), default=0) or 0
        is_married = user.get("etatCivil") == "marie"

        # MIRROR Dart lines 200-208 — user tax saving for clamp(reference, 0, userRachat).
        user_saving = 0.0
        if user_income > 0 and user_rachat > 0:
            user_saving = _estimate_tax_saving(
                income=user_income,
                deduction=min(reference_amount, user_rachat),
                canton=canton,
                is_married=is_married,
                children=children,
            )

        # MIRROR Dart lines 210-218 — conjoint tax saving.
        conjoint_saving = 0.0
        if conjoint_income > 0 and conjoint_rachat > 0:
            conjoint_saving = _estimate_tax_saving(
                income=conjoint_income,
                deduction=min(reference_amount, conjoint_rachat),
                canton=canton,
                is_married=is_married,
                children=children,
            )

        delta = abs(user_saving - conjoint_saving)
        # MIRROR Dart lines 224-233 — winner resolution + verbatim FR strings.
        if delta < _MIN_DELTA:
            winner = CoupleWinner.NO_PREFERENCE
            reason = "Taux marginaux similaires — pas de préférence."  # Dart line 226.
        elif user_saving > conjoint_saving:
            winner = CoupleWinner.MAIN_USER
            reason = (
                "Taux marginal plus élevé → économie fiscale supérieure par CHF racheté."
            )  # Dart line 229.
        else:
            winner = CoupleWinner.CONJOINT
            reason = (
                "Taux marginal plus élevé → économie fiscale supérieure par CHF racheté."
            )  # Dart line 232.

        return CoupleAnalysisResult(
            winner=winner,
            saving_delta=delta,
            reason=reason,
            # MIRROR Dart lines 239-240 — verbatim trade-off.
            trade_off=(
                "Le rachat LPP est bloqué 3 ans avant le retrait (LPP art. 79b al. 3). "
                "Le timing dépend aussi de l'âge de chaque personne."
            ),
        )

    # ── Analysis 2: 3a contribution order ─────────────────────
    # MIRROR Dart couple_optimizer.dart:246-315 (_analyze3aContributionOrder).

    @staticmethod
    def _analyze_3a_contribution_order(
        user: Dict[str, Any], conjoint: Dict[str, Any]
    ) -> Optional[CoupleAnalysisResult]:
        user_income = _user_income(user)
        conjoint_income = _conjoint_income(conjoint)
        # MIRROR Dart line 252.
        if user_income <= 0 and conjoint_income <= 0:
            return None

        # FATCA check — MIRROR Dart lines 254-266.
        # conjoint.canContribute3a defaults True in Dart; only False when
        # FATCA-resident or explicitly disabled.
        conjoint_can_contribute = conjoint.get("canContribute3a")
        if conjoint_can_contribute is None:
            conjoint_can_contribute = True

        if not conjoint_can_contribute:
            return CoupleAnalysisResult(
                winner=CoupleWinner.MAIN_USER,
                saving_delta=0.0,
                # MIRROR Dart lines 261-262 — verbatim. Dart uses · (middle
                # dot) for inclusive form "Le·la conjoint·e" and "résident·e".
                reason=(
                    "Le·la conjoint·e est résident·e FATCA "
                    "— le versement 3a n'est pas possible pour cette personne."
                ),
                # MIRROR Dart lines 263-264 — verbatim.
                trade_off=(
                    "FATCA (Foreign Account Tax Compliance Act) "
                    "restreint l'accès à certains produits 3a pour les résidents US."
                ),
            )

        canton = user.get("canton") or "ZH"
        ceiling = _PILIER_3A_PLAFOND_AVEC_LPP
        children = _i(user.get("nombreEnfants"), default=0) or 0
        is_married = user.get("etatCivil") == "marie"

        # MIRROR Dart lines 272-290.
        user_saving = 0.0
        if user_income > 0:
            user_saving = _estimate_tax_saving(
                income=user_income,
                deduction=ceiling,
                canton=canton,
                is_married=is_married,
                children=children,
            )
        conjoint_saving = 0.0
        if conjoint_income > 0:
            conjoint_saving = _estimate_tax_saving(
                income=conjoint_income,
                deduction=ceiling,
                canton=canton,
                is_married=is_married,
                children=children,
            )

        delta = abs(user_saving - conjoint_saving)
        # MIRROR Dart lines 296-306 — verbatim FR strings.
        if delta < _MIN_DELTA:
            winner = CoupleWinner.NO_PREFERENCE
            # Dart lines 298-299 — multi-line concat.
            reason = (
                "Taux marginaux similaires — les deux bénéficient "
                "de manière comparable."
            )
        elif user_saving > conjoint_saving:
            winner = CoupleWinner.MAIN_USER
            reason = (
                "Revenu imposable plus élevé → déduction 3a plus avantageuse."
            )  # Dart line 302.
        else:
            winner = CoupleWinner.CONJOINT
            reason = (
                "Revenu imposable plus élevé → déduction 3a plus avantageuse."
            )  # Dart line 305.

        return CoupleAnalysisResult(
            winner=winner,
            saving_delta=delta,
            reason=reason,
            # MIRROR Dart lines 312-313 — verbatim. Dart uses   for
            # non-breaking space between CHF and the amount.
            trade_off=(
                f"Le plafond 3a est individuel (CHF {round(ceiling)}/an). "
                "Les deux partenaires peuvent verser chacun le maximum."
            ),
        )

    # ── Analysis 3: AVS couple cap (LAVS art. 35) ────────────
    # MIRROR Dart couple_optimizer.dart:319-369 (_analyzeAvsCap).

    @staticmethod
    def _analyze_avs_cap(
        user: Dict[str, Any], conjoint: Dict[str, Any]
    ) -> Optional[AvsCoupleCapResult]:
        # Need both ages and income to compute — MIRROR Dart line 325.
        conjoint_age = _conjoint_age(conjoint)
        if conjoint_age is None:
            return None

        user_age = _user_age(user)
        if user_age is None:
            # Dart accesses user.age as non-null inside computeMonthlyRente
            # call below; if the user has no birthYear the AVS path is
            # not meaningful — return None defensively.
            return None

        user_retirement_age = _user_effective_retirement_age(user)
        conjoint_retirement_age = _conjoint_effective_retirement_age(conjoint)

        # MIRROR Dart lines 330-336 — user rente.
        user_gender = user.get("gender")
        user_is_female = (
            True if user_gender == "F" else (False if user_gender == "M" else None)
        )
        user_birth_year = _i(user.get("birthYear"))
        user_rente = _avs_compute_monthly_rente(
            current_age=user_age,
            retirement_age=user_retirement_age,
            gross_annual_salary=_user_income(user),
            is_female=user_is_female,
            birth_year=user_birth_year,
        )

        # MIRROR Dart lines 338-345 — conjoint rente (incl. arrivalAge).
        conjoint_gender = conjoint.get("gender")
        conjoint_is_female = (
            True
            if conjoint_gender == "F"
            else (False if conjoint_gender == "M" else None)
        )
        conjoint_birth_year = _i(conjoint.get("birthYear"))
        conjoint_arrival_age = _i(conjoint.get("arrivalAge"))
        conjoint_rente = _avs_compute_monthly_rente(
            current_age=conjoint_age,
            retirement_age=conjoint_retirement_age,
            gross_annual_salary=_conjoint_income(conjoint),
            arrival_age=conjoint_arrival_age,
            is_female=conjoint_is_female,
            birth_year=conjoint_birth_year,
        )

        # MIRROR Dart line 347.
        is_married = user.get("etatCivil") == "marie"
        couple = _avs_compute_couple(
            avs_user=user_rente, avs_conjoint=conjoint_rente, is_married=is_married
        )

        # MIRROR Dart lines 355-357 — apply 13th rente (monthly equivalent).
        user_with_13 = _avs_annual_rente(user_rente) / 12.0
        conjoint_with_13 = _avs_annual_rente(conjoint_rente) / 12.0
        couple_with_13 = _avs_annual_rente(couple["total"]) / 12.0

        uncapped = user_with_13 + conjoint_with_13
        reduction = uncapped - couple_with_13

        return AvsCoupleCapResult(
            cap_applied=reduction > 0,
            monthly_reduction=reduction,
            user_rente_before_cap=user_with_13,
            conjoint_rente_before_cap=conjoint_with_13,
            total_after_cap=couple_with_13,
        )

    # ── Analysis 4: Marriage penalty ──────────────────────────
    # MIRROR Dart couple_optimizer.dart:373-422 (_analyzeMarriagePenalty).

    @staticmethod
    def _analyze_marriage_penalty(
        user: Dict[str, Any], conjoint: Dict[str, Any]
    ) -> Optional[MarriagePenaltyResult]:
        user_income = _user_income(user)
        conjoint_income = _conjoint_income(conjoint)
        # MIRROR Dart line 380.
        if user_income <= 0 and conjoint_income <= 0:
            return None

        canton = user.get("canton") or "ZH"
        enfants = _i(user.get("nombreEnfants"), default=0) or 0

        # MIRROR Dart lines 386-391 — joint filing.
        tax_married = (
            _estimate_monthly_income_tax(
                user_income + conjoint_income,
                canton,
                etat_civil="marie",
                nombre_enfants=enfants,
            )
            * 12
        )

        # MIRROR Dart lines 395-407 — two singles, children assigned to higher earner.
        user_has_kids = user_income >= conjoint_income
        tax_user_single = (
            _estimate_monthly_income_tax(
                user_income,
                canton,
                etat_civil="celibataire",
                nombre_enfants=enfants if user_has_kids else 0,
            )
            * 12
        )
        tax_conjoint_single = (
            _estimate_monthly_income_tax(
                conjoint_income,
                canton,
                etat_civil="celibataire",
                nombre_enfants=0 if user_has_kids else enfants,
            )
            * 12
        )

        # MIRROR Dart line 409.
        annual_delta = tax_married - (tax_user_single + tax_conjoint_single)

        if annual_delta > 0:
            # MIRROR Dart lines 414-417 — verbatim (Dart uses   non-breaking
            # space and ``round()`` of a non-negative annualDelta).
            trade_off = (
                f"Le mariage crée une surcharge fiscale de "
                f"CHF {round(annual_delta)}/an dans le canton {canton}. "
                f"Cet écart varie selon les cantons et les niveaux de revenu."
            )
        else:
            # MIRROR Dart lines 418-420.
            trade_off = (
                f"Le mariage crée un avantage fiscal de "
                f"CHF {round(abs(annual_delta))}/an dans le canton {canton}. "
                f"Cet avantage est dû au splitting pour les couples mariés."
            )

        return MarriagePenaltyResult(
            has_penalty=annual_delta > 0,
            annual_delta=annual_delta,
            trade_off=trade_off,
        )

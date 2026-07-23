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

# MIRROR Dart tax_calculator.dart:276-284
_EFFECTIVE_RATES_100K: Dict[str, float] = {
    "ZG": 0.0823, "NW": 0.0891, "OW": 0.0934, "AI": 0.0956,
    "AR": 0.1012, "SZ": 0.1034, "UR": 0.1067, "LU": 0.1089,
    "GL": 0.1102, "TG": 0.1145, "SH": 0.1167, "AG": 0.1189,
    "GR": 0.1203, "BL": 0.1256, "SG": 0.1278, "ZH": 0.1290,
    "FR": 0.1312, "SO": 0.1334, "TI": 0.1356, "BE": 0.1389,
    "NE": 0.1423, "VS": 0.1456, "VD": 0.1489, "JU": 0.1512,
    "GE": 0.1545, "BS": 0.1578,
}

# MIRROR Dart tax_calculator.dart:290-293
_INCOME_ADJUSTMENT: Dict[int, float] = {
    50_000: 0.75,
    80_000: 0.90,
    100_000: 1.00,
    150_000: 1.10,
    200_000: 1.18,
    300_000: 1.25,
    500_000: 1.32,
}

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

# MIRROR Dart social_insurance.dart avsEchelle44 — table officielle OFAS
# 318.117.011 p. 20 (51 paliers, dès 1.1.2025, inchangée 2026 — audit -zaw).
# Format: list of (RAMD_annual, rente_mensuelle).
_AVS_ECHELLE_44: list = [
    (15_120.0, 1_260.0),
    (16_632.0, 1_293.0),
    (18_144.0, 1_326.0),
    (19_656.0, 1_358.0),
    (21_168.0, 1_391.0),
    (22_680.0, 1_424.0),
    (24_192.0, 1_457.0),
    (25_704.0, 1_489.0),
    (27_216.0, 1_522.0),
    (28_728.0, 1_555.0),
    (30_240.0, 1_588.0),
    (31_752.0, 1_620.0),
    (33_264.0, 1_653.0),
    (34_776.0, 1_686.0),
    (36_288.0, 1_719.0),
    (37_800.0, 1_751.0),
    (39_312.0, 1_784.0),
    (40_824.0, 1_817.0),
    (42_336.0, 1_850.0),
    (43_848.0, 1_882.0),
    (45_360.0, 1_915.0),
    (46_872.0, 1_935.0),
    (48_384.0, 1_956.0),
    (49_896.0, 1_976.0),
    (51_408.0, 1_996.0),
    (52_920.0, 2_016.0),
    (54_432.0, 2_036.0),
    (55_944.0, 2_056.0),
    (57_456.0, 2_076.0),
    (58_968.0, 2_097.0),
    (60_480.0, 2_117.0),
    (61_992.0, 2_137.0),
    (63_504.0, 2_157.0),
    (65_016.0, 2_177.0),
    (66_528.0, 2_197.0),
    (68_040.0, 2_218.0),
    (69_552.0, 2_238.0),
    (71_064.0, 2_258.0),
    (72_576.0, 2_278.0),
    (74_088.0, 2_298.0),
    (75_600.0, 2_318.0),
    (77_112.0, 2_339.0),
    (78_624.0, 2_359.0),
    (80_136.0, 2_379.0),
    (81_648.0, 2_399.0),
    (83_160.0, 2_419.0),
    (84_672.0, 2_439.0),
    (86_184.0, 2_460.0),
    (87_696.0, 2_480.0),
    (89_208.0, 2_500.0),
    (90_720.0, 2_520.0),
]


# ────────────────────────────────────────────────────────────
#  Tax helpers (mirrored INLINE from RetirementTaxCalculator)
# ────────────────────────────────────────────────────────────


def _interpolate_income_adjustment(income: float) -> float:
    """Linear interpolation between income adjustment brackets.

    # MIRROR Dart tax_calculator.dart:365-383.
    """
    keys = sorted(_INCOME_ADJUSTMENT.keys())
    if income <= keys[0]:
        return _INCOME_ADJUSTMENT[keys[0]]
    if income >= keys[-1]:
        return _INCOME_ADJUSTMENT[keys[-1]]
    for i in range(len(keys) - 1):
        lower, upper = keys[i], keys[i + 1]
        if lower <= income <= upper:
            ratio = (income - lower) / (upper - lower)
            lower_adj = _INCOME_ADJUSTMENT[lower]
            upper_adj = _INCOME_ADJUSTMENT[upper]
            return lower_adj + (upper_adj - lower_adj) * ratio
    return 1.0  # fallback


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


def _estimate_marginal_rate(
    revenu_brut_annuel: float,
    canton: str,
    *,
    is_married: bool = False,
    children: int = 0,
) -> float:
    """Marginal tax rate by canton, income, family situation.

    # MIRROR Dart tax_calculator.dart:316-360.

    Returns marginal = effective * 1.3, clamped to [0.05, 0.45].
    No ``actualRate`` override here (the Python port operates on raw
    profile data; future enhancement may add the scan-derived override).
    """
    canton_code = (canton or "ZH").upper()
    base_rate = _EFFECTIVE_RATES_100K.get(canton_code, 0.13)  # MIRROR Dart line 333
    income_adj = _interpolate_income_adjustment(revenu_brut_annuel)
    family_adj = _FAMILY_ADJUSTMENT.get(
        _family_key(is_married=is_married, children=children),
        1.0,
    )
    effective = base_rate * income_adj * family_adj
    marginal = effective * 1.3  # MIRROR Dart line 357
    return max(0.05, min(0.45, marginal))


def _estimate_tax_saving(
    income: float,
    deduction: float,
    canton: str,
    *,
    is_married: bool = False,
    children: int = 0,
    steps: int = 10,
) -> float:
    """Estimate tax saving from a deduction via 10-step integration.

    # MIRROR Dart tax_calculator.dart:390-419.

    Sums ``stepSize * marginalRate(midPoint)`` over ``steps`` slices as
    income decreases. Used by the LPP buyback and 3a contribution
    analyses to estimate fiscal benefit.
    """
    if deduction <= 0 or steps <= 0:
        return 0.0
    step_size = deduction / steps
    current_income = income
    total_saved = 0.0
    for _ in range(steps):
        midpoint = current_income - (step_size / 2)
        rate = _estimate_marginal_rate(
            midpoint, canton, is_married=is_married, children=children
        )
        total_saved += step_size * rate
        current_income -= step_size
    return total_saved


def _estimate_monthly_income_tax(
    revenu_annuel_imposable: float,
    canton: str,
    *,
    etat_civil: str = "celibataire",
    nombre_enfants: int = 0,
) -> float:
    """Estimate monthly income tax (annual divided by 12).

    # MIRROR Dart tax_calculator.dart:476-490 (simplified).

    Dart's fiscal-service tax estimator is more nuanced (canton-specific
    bareme + multipliers). For Wave 1a parity on the fixture set we
    approximate ``chargeTotale = revenu × effective_rate(...)``. The
    plan-07 parity test will assert ±0.01 CHF on Julien/Lauren fixtures.
    """
    if revenu_annuel_imposable <= 0:
        return 0.0
    canton_code = (canton or "ZH").upper()
    base_rate = _EFFECTIVE_RATES_100K.get(canton_code, 0.13)
    income_adj = _interpolate_income_adjustment(revenu_annuel_imposable)
    is_married = etat_civil == "marie"
    family_adj = _FAMILY_ADJUSTMENT.get(
        _family_key(is_married=is_married, children=nombre_enfants),
        1.0,
    )
    effective_rate = base_rate * income_adj * family_adj
    charge_totale = revenu_annuel_imposable * effective_rate
    return charge_totale / 12.0


# ────────────────────────────────────────────────────────────
#  AVS helpers (mirrored INLINE from AvsCalculator)
# ────────────────────────────────────────────────────────────


def _rente_from_ramd(gross_annual_salary: float) -> float:
    """AVS rente based on RAMD using Echelle 44 (LAVS art. 34).

    # MIRROR Dart avs_calculator.dart:136-150 (renteFromRAMD).

    Concave lookup + linear interpolation between table points.
    """
    if gross_annual_salary <= 0:
        return 0.0
    table = _AVS_ECHELLE_44
    if gross_annual_salary <= table[0][0]:
        return table[0][1]
    if gross_annual_salary >= table[-1][0]:
        return table[-1][1]
    for i in range(len(table) - 1):
        lower = table[i]
        upper = table[i + 1]
        if lower[0] <= gross_annual_salary <= upper[0]:
            ratio = (gross_annual_salary - lower[0]) / (upper[0] - lower[0])
            return lower[1] + ratio * (upper[1] - lower[1])
    return table[-1][1]  # fallback


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
        # MIRROR Dart social_insurance.dart:150-157 (avsReferenceAge).
        if not is_female:
            ref_age = _AVS_AGE_REFERENCE_HOMME
        elif birth_year <= 1960:
            ref_age = 64
        elif birth_year == 1961:
            ref_age = 64
        elif birth_year == 1962:
            ref_age = 64
        elif birth_year == 1963:
            ref_age = 65
        else:
            ref_age = 65
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
    effective_salary = gross_annual_salary
    base_rente = _rente_from_ramd(effective_salary)
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

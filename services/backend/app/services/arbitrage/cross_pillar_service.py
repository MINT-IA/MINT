"""Wave 1a D-02 — server-side orchestrator for get_cross_pillar_analysis.

Chains the existing rules_engine + arbitrage modules. NO new financial math
(CLAUDE.md rule 4: financial_core reuse mandatory).

Architecture (grep-verified 2026-05-14):
  - `get_3a_ceiling` — imported from `app.services.rules_engine` (line 396).
    DO NOT import from `app.api.v1.endpoints.coach_chat` (that module ITSELF
    imports from rules_engine at line 86, so importing back here would
    create a circular import).
  - tax saving — Batch H (revue Codex) : la délégation historique à
    `compare_allocation_annuelle` (bornée au petit 3a, versement × taux) a été
    REMPLACÉE par la différence d'impôt canonique `estimate_tax_saving` sur le
    versement borné au plafond d'affiliation. Ce module ne référence plus
    `allocation_annuelle`.
  - `lpp_buyback_max` — there is NO server function that derives this from
    a profile. Flutter financial_core writes it into
    `profile_data["lpp_buyback_max"]` (persisted at
    `snapshots/snapshot_service.py:147`). The orchestrator RELAYS this
    value; if absent -> Decimal("0.00") + Sentry breadcrumb tag
    `lpp_buyback_source="missing_from_profile"` (emitted at the dispatcher
    layer in Task 2, not here — this service stays pure).
  - `tax_saving_potential`: différence d'impôt canonique
    (`estimate_tax_saving(base_déterminante, versement_borné_au_plafond,
    canton, is_married)`) — jamais versement × taux marginal (anti-patron
    #1061), jamais le petit plafond pour un non-affilié (Batch H, H3).
"""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

from app.services.rules_engine import (
    get_3a_ceiling,
)


@dataclass(frozen=True)
class CrossPillarAnalysis:
    annual_3a_contribution: Decimal
    # None = plafond 3a INCONNU (grand 3a dû sans revenu déterminant) — jamais
    # 0.00 fabriqué (revue Codex G1). La sérialisation affiche la règle.
    three_a_ceiling: Optional[Decimal]
    three_a_remaining: Optional[Decimal]
    lpp_buyback_max: Decimal
    lpp_capital: Decimal
    tax_saving_potential: Decimal
    # Diagnostic tags consumed by the dispatcher layer to enrich the
    # Sentry breadcrumb. NOT serialized into the Pydantic response.
    lpp_buyback_source: str = "from_profile"   # or "missing_from_profile"
    tax_saving_source: str = "strategy_a"      # or "strategy_b" or "missing_from_profile"


# Profil canonique persisté en camelCase (schemas/profile.py) -> clés snake_case
# lues par les règles internes. Les DEUX formes sont acceptées (revue Codex G3).
# Clés camelCase RÉELLES persistées par ``schemas/profile.py`` (revue Codex H1 :
# le profil persiste ``pillar3aAnnual`` et ``avoirLpp``, PAS ``annual3AContribution``
# ni ``lppAvoir``). Vérifiées sur ``Profile.model_dump(by_alias=True)``.
_PROFILE_KEY_ALIASES = {
    "employmentStatus": "employment_status",
    "has2ndPillar": "has_2nd_pillar",
    "incomeGrossYearly": "income_gross_yearly",
    "selfEmployedNetIncome": "self_employed_net_income",
    "pillar3aAnnual": "annual_3a_contribution",
    "avoirLpp": "lpp_avoir",
    "lppBuybackMax": "lpp_buyback_max",
}


def _normalize_profile_keys(profile_data: dict) -> dict:
    out = dict(profile_data)
    for camel, snake in _PROFILE_KEY_ALIASES.items():
        if out.get(snake) is None and profile_data.get(camel) is not None:
            out[snake] = profile_data[camel]
    return out


def _q(v) -> Decimal:
    """Quantize to 2 decimals. Matches the Decimal convention used across
    Wave 1a tools (plan-01 budget_snapshot, plan-02 retirement_projection)."""
    return Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


class CrossPillarService:
    @staticmethod
    def compute(profile_data: dict) -> CrossPillarAnalysis:
        """Compute the cross-pillar analysis from a ProfileModel.data dict.

        Reads (per `coach_context_builder.py` and `_format_cross_pillar_analysis`
        ctx conventions):
          - annual_3a_contribution (CHF, optional)
          - lpp_avoir (CHF, optional; legacy ctx key was `lpp_capital`)
          - lpp_buyback_max (CHF, optional; from Flutter financial_core)
          - tax_saving_potential (CHF, optional; Strategy B fallback)
          - employment_status, has_2nd_pillar (for ceiling lookup)
          - canton, income_gross_yearly, household_type, taux_marginal
            (for Strategy A marginal-rate input)

        Raises ValueError("cross pillar data missing") if NONE of the five
        payload-bearing fields (annual_3a_contribution, lpp_avoir,
        lpp_buyback_max, tax_saving_potential, lpp_capital alias) are
        present — mirrors `_format_cross_pillar_analysis` line 2602 guard.
        """
        # Normalisation camelCase (profil canonique persistant) -> snake_case
        # (règles internes) : les DEUX formes sont acceptées (revue Codex G3).
        profile_data = _normalize_profile_keys(profile_data)

        annual_3a = profile_data.get("annual_3a_contribution")
        lpp_avoir = profile_data.get("lpp_avoir")
        if lpp_avoir is None:
            # Legacy ctx alias — `_format_cross_pillar_analysis` reads
            # `ctx.get("lpp_capital")`. Some profiles persist under that
            # name. Accept both.
            lpp_avoir = profile_data.get("lpp_capital")
        lpp_buyback_raw = profile_data.get("lpp_buyback_max")
        tax_saving_raw_profile = profile_data.get("tax_saving_potential")

        if (
            annual_3a is None
            and lpp_avoir is None
            and lpp_buyback_raw is None
            and tax_saving_raw_profile is None
        ):
            raise ValueError("cross pillar data missing")

        # === 3a ceiling (OPP3 art. 7) — single source of truth ===
        employment_status = profile_data.get("employment_status", "salarie")
        has_2nd_pillar = profile_data.get("has_2nd_pillar", True)
        # Assiette selon le STATUT, pas la simple présence de la clé (revue Codex
        # I1) : net indépendant SEULEMENT si le statut est indépendant ; sinon
        # base salariale (une clé indépendante résiduelle d'un update partiel ne
        # remplace jamais le salaire). Activité mixte non combinée = dette dite.
        _is_indep = str(employment_status or "").lower().strip() in (
            "independant", "self_employed"
        )
        _self_net = profile_data.get("self_employed_net_income")
        if _is_indep and _self_net is not None:
            income_for_ceiling = _self_net
        else:
            income_for_ceiling = profile_data.get("income_gross_yearly")
        ceiling_raw = get_3a_ceiling(
            employment_status, has_2nd_pillar, annual_income=income_for_ceiling
        )

        annual_3a_d = _q(annual_3a) if annual_3a is not None else Decimal("0.00")
        # Plafond INCONNU (grand 3a dû sans revenu déterminant) : représenté
        # None, JAMAIS 0.00 fabriqué (une affirmation chiffrée fausse est pire
        # que 36'288 — revue Codex G1). La sérialisation coach affiche la règle.
        if ceiling_raw is None:
            three_a_ceiling_d = None
            three_a_remaining_d = None
        else:
            three_a_ceiling_d = _q(ceiling_raw)
            three_a_remaining_d = max(Decimal("0.00"), three_a_ceiling_d - annual_3a_d)

        # === LPP buyback max — RELAY from profile (no server function) ===
        if lpp_buyback_raw is None:
            lpp_buyback_max_d = Decimal("0.00")
            lpp_buyback_source = "missing_from_profile"
        else:
            lpp_buyback_max_d = _q(lpp_buyback_raw)
            lpp_buyback_source = "from_profile"

        # === LPP capital — relay from profile ===
        lpp_capital_d = _q(lpp_avoir) if lpp_avoir is not None else Decimal("0.00")

        # === Tax saving — Strategy A (chain) -> Strategy B (relay) -> 0 + tag ===
        tax_saving_d, tax_saving_source = _derive_tax_saving(
            profile_data=profile_data,
            annual_3a=annual_3a,
            lpp_buyback_max=float(lpp_buyback_max_d),
            tax_saving_raw_profile=tax_saving_raw_profile,
            ceiling=ceiling_raw,
            income_det=income_for_ceiling,
        )

        return CrossPillarAnalysis(
            annual_3a_contribution=annual_3a_d,
            three_a_ceiling=three_a_ceiling_d,
            three_a_remaining=three_a_remaining_d,
            lpp_buyback_max=lpp_buyback_max_d,
            lpp_capital=lpp_capital_d,
            tax_saving_potential=tax_saving_d,
            lpp_buyback_source=lpp_buyback_source,
            tax_saving_source=tax_saving_source,
        )


def _derive_tax_saving(
    profile_data: dict,
    annual_3a: float | None,
    lpp_buyback_max: float,
    tax_saving_raw_profile: float | None,
    ceiling: float | None = None,
    income_det: float | None = None,
) -> tuple[Decimal, str]:
    """Pick a tax-saving derivation path. Returns (value, source_tag).

    Strategy A (revue Codex H3) — DIFFÉRENCE d'impôt canonique
    ``estimate_tax_saving`` sur le versement borné au plafond D'AFFILIATION
    (``ceiling``), sur le revenu déterminant (``income_det``). Remplace la
    délégation à ``compare_allocation_annuelle`` qui bornait à 7'258 ET
    multipliait par le taux marginal — incohérent avec un plafond 20'000
    affiché pour un non-affilié. ``compare_allocation_annuelle`` reste inchangé
    pour ses autres appelants.

    Strategy B — read `profile_data["tax_saving_potential"]` directly.

    Fallback — return Decimal("0.00") with source tag "missing_from_profile".
    """
    montant_disponible = float(annual_3a) if annual_3a is not None else 0.0

    # --- Strategy A: différence d'impôt canonique, versement borné au plafond ---
    if (
        montant_disponible > 0
        and ceiling is not None
        and income_det is not None
        and profile_data.get("canton")
    ):
        try:
            from app.services.fiscal.cantonal_comparator import estimate_tax_saving
            from app.services.rules_engine import is_married_household

            deduction = min(montant_disponible, float(ceiling))
            is_married = is_married_household(profile_data.get("household_type"))
            saving = estimate_tax_saving(
                float(income_det),
                deduction,
                str(profile_data["canton"]),
                is_married=is_married,
            )
            return _q(saving), "strategy_a"
        except Exception:
            # Defensive — never let the chain crash compute().
            pass

    # --- Strategy B: relay from profile ---
    if tax_saving_raw_profile is not None:
        return _q(tax_saving_raw_profile), "strategy_b"

    # --- Fallback: 0 + tag ---
    return Decimal("0.00"), "missing_from_profile"

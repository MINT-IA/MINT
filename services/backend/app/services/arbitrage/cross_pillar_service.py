"""Wave 1a D-02 — server-side orchestrator for get_cross_pillar_analysis.

Chains the existing rules_engine + arbitrage modules. NO new financial math
(CLAUDE.md rule 4: financial_core reuse mandatory).

Architecture (grep-verified 2026-05-14):
  - `get_3a_ceiling` — imported from `app.services.rules_engine` (line 396).
    DO NOT import from `app.api.v1.endpoints.coach_chat` (that module ITSELF
    imports from rules_engine at line 86, so importing back here would
    create a circular import).
  - `compare_allocation_annuelle` — imported from
    `app.services.arbitrage.allocation_annuelle` (line 324). Called with
    `annees_avant_retraite=1` so trajectory[0].cumulative_tax_delta carries
    the year-1 tax saving (sign-flipped: negative = saving, per
    `_build_3a_option` line 101).
  - `lpp_buyback_max` — there is NO server function that derives this from
    a profile. Flutter financial_core writes it into
    `profile_data["lpp_buyback_max"]` (persisted at
    `snapshots/snapshot_service.py:147`). The orchestrator RELAYS this
    value; if absent -> Decimal("0.00") + Sentry breadcrumb tag
    `lpp_buyback_source="missing_from_profile"` (emitted at the dispatcher
    layer in Task 2, not here — this service stays pure).
  - `tax_saving_potential`:
      * Strategy A (preferred): call `compare_allocation_annuelle(...)` with
        the profile's annual 3a contribution + marginal rate + buyback.
        Read back the 3a option's year-1 cumulative_tax_delta (sign-flipped).
        The math itself runs in `_build_3a_option` line 94
        (`annual_tax_saving = contribution * taux_marginal`) — we are a
        CALLER, not a re-implementer.
      * Strategy B (fallback when canton/income missing): read
        `profile_data["tax_saving_potential"]` directly (Flutter wrote it
        via `coach_context_builder.py:78`).
      * If neither available -> Decimal("0.00") + breadcrumb tag
        `tax_saving_source="missing_from_profile"`.
"""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

from app.services.rules_engine import (
    get_3a_ceiling,
    calculate_marginal_tax_rate,
)
from app.services.arbitrage.allocation_annuelle import (
    compare_allocation_annuelle,
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
_PROFILE_KEY_ALIASES = {
    "employmentStatus": "employment_status",
    "has2ndPillar": "has_2nd_pillar",
    "incomeGrossYearly": "income_gross_yearly",
    "selfEmployedNetIncome": "self_employed_net_income",
    "annual3AContribution": "annual_3a_contribution",
    "lppAvoir": "lpp_avoir",
    "lppCapital": "lpp_capital",
    "lppBuybackMax": "lpp_buyback_max",
    "taxSavingPotential": "tax_saving_potential",
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
        # Assiette : net indépendant si fourni (OPP3 art. 7), sinon brut.
        income_for_ceiling = profile_data.get("self_employed_net_income")
        if income_for_ceiling is None:
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
) -> tuple[Decimal, str]:
    """Pick a tax-saving derivation path. Returns (value, source_tag).

    Strategy A — chain `compare_allocation_annuelle`. Requires `annual_3a`
    (or any positive disposable amount) AND a derivable marginal rate.
    The marginal rate comes from `profile_data["taux_marginal"]` if
    present, else from `calculate_marginal_tax_rate(canton, income, type)`
    if canton + income_gross_yearly are present.

    Strategy B — read `profile_data["tax_saving_potential"]` directly.

    Fallback — return Decimal("0.00") with source tag "missing_from_profile".
    """
    montant_disponible = float(annual_3a) if annual_3a is not None else 0.0

    # Derive marginal rate (Strategy A pre-requisite).
    taux_marginal: float | None = None
    explicit_taux = profile_data.get("taux_marginal")
    if explicit_taux is not None:
        taux_marginal = float(explicit_taux)
    else:
        canton = profile_data.get("canton")
        income_gross = profile_data.get("income_gross_yearly")
        if canton and income_gross is not None:
            household = profile_data.get("household_type", "single")
            taux_marginal = calculate_marginal_tax_rate(
                canton=str(canton),
                income_gross=float(income_gross),
                household_type=str(household),
            )

    # --- Strategy A: chain compare_allocation_annuelle ---
    if taux_marginal is not None and montant_disponible > 0:
        try:
            result = compare_allocation_annuelle(
                montant_disponible=montant_disponible,
                taux_marginal=taux_marginal,
                a3a_maxed=False,
                potentiel_rachat_lpp=lpp_buyback_max,
                is_property_owner=bool(profile_data.get("is_property_owner", False)),
                annees_avant_retraite=1,  # year-1 tax saving readout
                canton=str(profile_data.get("canton") or "VD"),
            )
            option_3a = next(
                (o for o in result.options if o.id == "3a"), None
            )
            if option_3a is not None and option_3a.trajectory:
                # cumulative_tax_delta is NEGATIVE for a saving
                # (`allocation_annuelle.py:101`). Sign-flip to positive.
                saving = -option_3a.trajectory[0].cumulative_tax_delta
                return _q(saving), "strategy_a"
        except Exception:
            # Defensive — never let the chain crash compute(). Fall
            # through to Strategy B / fallback.
            pass

    # --- Strategy B: relay from profile ---
    if tax_saving_raw_profile is not None:
        return _q(tax_saving_raw_profile), "strategy_b"

    # --- Fallback: 0 + tag ---
    return Decimal("0.00"), "missing_from_profile"

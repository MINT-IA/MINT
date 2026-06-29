"""GENERATED — do not edit by hand.
Source: apps/mobile/lib/services/navigation/screen_registry.dart
Generator: tools/contracts/regen_screen_registry_contract.py
Phase 53-04 — three-way intent contract parity gate.

Frozen set of intent tags the LLM is allowed to suggest via the
route_to_screen tool. Canonical tags are derived from MintScreenRegistry
entries with preferFromChat: true. Legacy aliases stay accepted so old
backend prompts/snapshots can still reach Flutter, where they resolve to
canonical routes.

Updating: edit screen_registry.dart, then run
  python3 tools/contracts/regen_screen_registry_contract.py
"""
from __future__ import annotations

GENERATED_ROUTE_TO_SCREEN_CANONICAL_INTENT_TAGS: frozenset[str] = frozenset({
    'annual_allocation',
    'arbitrage_bilan',
    'avs_cotisations_independant',
    'avs_guide',
    'bank_import',
    'budget_overview',
    'budget_setup',
    'cantonal_comparison',
    'cantonal_fiscal_comparator',
    'coach_chat',
    'compound_interest_simulator',
    'confidence_dashboard',
    'consult_specialist',
    'consumer_credit_simulator',
    'couple_accept_invitation',
    'coverage_check',
    'cross_border',
    'debt_help_resources',
    'debt_ratio',
    'debt_repayment',
    'debt_risk_check',
    'disability_gap',
    'disability_insurance_flow',
    'disability_self_employed',
    'dividende_vs_salaire',
    'document_scan',
    'documents_list',
    'early_pension_withdrawal',
    'education_hub',
    'education_theme_detail',
    'epl_combined',
    'explore_hub_famille',
    'explore_hub_fiscalite',
    'explore_hub_logement',
    'explore_hub_patrimoine',
    'explore_hub_retraite',
    'explore_hub_sante',
    'explore_hub_travail',
    'financial_summary',
    'gender_gap',
    'household_couple',
    'housing_purchase',
    'ijm_independant',
    'imputed_rental',
    'job_comparison',
    'lamal_franchise',
    'leasing_simulator',
    'libre_passage',
    'life_event_birth',
    'life_event_canton_move',
    'life_event_concubinage',
    'life_event_country_move',
    'life_event_death_of_relative',
    'life_event_divorce',
    'life_event_donation',
    'life_event_first_job',
    'life_event_housing_sale',
    'life_event_job_loss',
    'life_event_marriage',
    'life_timeline',
    'lpp_buyback',
    'lpp_volontaire',
    'mortgage_amortization',
    'open_banking',
    'pillar_3a_independant',
    'prepare_avs_letter',
    'prepare_lpp_transfer',
    'prepare_tax_form',
    'preretraite_complete',
    'provider_comparator_3a',
    'real_return_3a',
    'rent_vs_buy',
    'retirement_choice',
    'retirement_projection',
    'retroactive_3a',
    'saron_vs_fixed',
    'self_employment',
    'simulator_3a',
    'succession_patrimoine',
    'tax_optimization_3a',
    'withdrawal_sequencing',
})

GENERATED_ROUTE_TO_SCREEN_LEGACY_INTENT_TAGS: frozenset[str] = frozenset({
    'advisor_30_day_plan',
    'advisor_handoff',
    'advisor_wizard',
    'ask_mint',
    'avs_extract_guide',
    'decaissement_plan',
    'disability_gap_check',
    'document_scan_entry',
    'financial_cockpit',
    'household_accept_invite',
    'household_overview',
    'life_event_divorce_v2',
    'life_event_succession',
    'lpp_buyback_vs_market',
    'lpp_deep_epl',
    'lpp_deep_libre_passage',
    'lpp_deep_rachat',
    'mortgage_affordability_v2',
    'portfolio_overview',
    'profile_enrichment',
    'rente_vs_capital_arbitrage',
    'retirement_overview',
    'retirement_projection_v2',
    'simulator_3a_v2',
    'simulator_disability_gap',
    'succession_planning',
    'withdrawal_calendar',
})

GENERATED_ROUTE_TO_SCREEN_INTENT_TAGS: frozenset[str] = (
    GENERATED_ROUTE_TO_SCREEN_CANONICAL_INTENT_TAGS
    | GENERATED_ROUTE_TO_SCREEN_LEGACY_INTENT_TAGS
)

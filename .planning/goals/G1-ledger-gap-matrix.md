# G1 Ledger Gap Matrix

> Status: G1 canonical registry updated through accepted PROV-02 SHA
> `30728b8a0671a0b54bcf47807a0c69bac905e6e3`.
> Scope: data reality only. This file does not implement G2 DataQuest or any
> G3 product loop.
> Focused RET-REF reality: `lppCapitalNoticeDeadline` is a technical live atom
> at exact pushed runtime SHA `36152b997fbf0c32c1120ddb61f0a8e9d589aa52`.
> The production UI acquisition seam, strict self root, ordered writer, exact
> raw-free BND join, cold Dashboard consumer, authority invalidation and
> snapshot replacement purge are proven. External document/OCR IO remains
> synthetic, private-fixture use is false and the feature flag stays false.
> Exact pushed SHA `a00b4c68a272cbde9f21fee14662171c4a12530f`
> additionally proves the real `/rapport` dossier, capital-before-regulation
> ordering, production PDF header/length, missing/mismatch/legacy suppression,
> exact root+BND restoration and production-default absence. The host dossier
> and real-PDF text contracts pass 11/11. The minimized proof is
> `phase-37/ret-ref-01/lpp-capital-dossier-pdf-runtime-proof-a00b4c68a/`.
> `capital_notice_dossier_pdf_parity` is closed; activation remains NO-GO,
> RET-REF/G1 remain open and G2/G3 remain forbidden.
> Focused LPP regulation autonomous/recovery reality: exact pushed SHA
> `6066f1c94786aa1bc4697c29b4a670b7cea3dca4` proves the bounded autonomous
> regulation-only base, and exact pushed SHA
> `7cb5ea4c64e0a59d4e2f38f8f67eff7c924bd32a` proves the visible
> `missingDocumentReference` recovery slice in the same two-process Patrol
> contract. One suite passes 2/2 with distinct writer/reader PIDs; the cold
> reader removes the synthetic BND reference, proves the known card/handoff are
> absent, proves the exact recovery body and CTA route `/scan?type=lppPlan`, then
> restores and compares the original BND before continuing. Production-default
> Maestro passes 1/1 before and 1/1 after, the feature remains default-off,
> reinstall/restoration pass and the retained-output contract is complete at
> 22/22. UI assertions are traced to the tracked reader executed by the passing
> suite; XCTest output is not misrepresented as an assertion transcript. The
> `currentFund` relationship remains declared/unverified and does not establish
> legal applicability or objective caisse/fund identity. Exact pushed SHA
> `274736a50bca659579fe26f68ae4e600469e3a9a` runs the real `MintApp`
> `/rapport` dossier, production PDF-byte builder and all three recovery
> suppression states in the same 2/2 native suite; the 3/3 real-byte host text
> contract proves ordered allowlisted content and privacy. Its minimized proof
> is `phase-37/ret-ref-01/lpp-regulation-dossier-pdf-runtime-proof-274736a50/`.
> PDF/dossier caveat parity is closed; an activation decision remains open.
> Whole RET-REF also retains
> capital-notice acquisition, 3a-beneficiary and fiscal activation/currentness
> gaps. RET-REF remains `ticket_only`, G1 remains open at 8.2/10 and G2/G3
> remain forbidden.
> Focused exact 3a dossier/PDF reality: the strict-secure root, serialized
> writer, exact raw-free BND join, fail-closed consumer, metadata-only specialist
> handoff, `/rapport` route, `FinancialReport` pass-through, screen and real-PDF
> host contracts are GREEN on the current branch. Only an aggregate
> `knownCurrentDeclared` state is admitted; mixed known+inactive exports only
> known entries, while inactive entries are excluded. Ambiguous/all-inactive
> states suppress the whole section, and no beneficiary identity, order or
> share is modelled. The
> three flags remain false; wrapper audits, exact-SHA native runtime and
> activation remain open. The row is therefore quarantined, not promoted live;
> RET-REF/G1 remain open and G2/G3 remain forbidden.

## Parser contract

The table under `G1_P0_CANONICAL_KEYS` is the checked-in source for the G1
`ledger_dead_key_test`. Parsers must locate the heading exactly, parse the first
Markdown table that follows it, and require the columns in the declared order.

Stable cell rules:

- Multiple values use commas, never additional Markdown pipes.
- `NONE` means no live storage key, reader, consumer, or gate exists.
- Every `live` or `partial` P0 `reader_evidence` is a semantic anchor with the
  exact shape `repo/path.dart#ClassName.memberName@fieldToken`. The named Dart
  member must exist and contain a qualified ledger access derived from the
  row's `coach_profile_path`; a local/parameter shadow with the same name is
  not evidence. Source line numbers are deliberately not part of the contract.
- All unnamed/named/factory constructors, declarations, `fromWizardAnswers`,
  `fromJson`, `toJson`, and `copyWith*` are reconstruction surfaces, not
  downstream consumers. A token read in another member does not satisfy the
  named anchor. Completion-marker strings are accepted only through the exact
  qualified marker collection declared by `coach_profile_path`.
- `self`, `partner`, `household`, and `document_ref` are ownership classes,
  not user identifiers.
- `fact` is durable user reality; `scenario_lever` is case-local;
  `derived_output` is recomputed; `completion_marker` records knowledge state;
  `specialist_reference` points to a source-sensitive document or rule.
- The classification vocabulary is closed to exactly `fact`,
  `scenario_lever`, `derived_output`, `completion_marker`, and
  `specialist_reference`. `completion_marker` requires the matching
  `completion_marker` type; document-reference types require
  `specialist_reference`; scenario/derived rows may not claim durable storage,
  profile, or write edges.
- `legal_source_asof=required` means a confident output is forbidden until a
  source, source date, and legal year are available.
- Status is one of `live`, `partial`, `semantic_mismatch`, `quarantined`,
  `dead_on_restart`, or `missing`.
- A row with `blocks_G2=yes` blocks G2 until its ticket is implemented or a
  checked-in blocking ticket satisfies the G1 ticket template.

Source tokens are the live mobile `ProfileDataSource` values:
`estimated`, `userInput`, `crossValidated`, `certificate`, `openBanking`.
Confidence weights are the lowest declared source weight unless the row says
`source_weight`; runtime confidence must use the actual recorded source.

`_coach_tax_snapshots_v1` is the implemented, composite-default-off
G1-PROV-03 destination: a schema-v1 JSON envelope in strict secure storage,
reconstructed as `CoachProfile.fiscal.snapshots`. Its rows are `quarantined`
because the parser → review → provider → cold selector slice and exact ticket
proof are GREEN, but both kill switches remain false until frozen-SHA runtime
evidence, external audits and the activation decision pass. Legacy
`_coach_tax_*` values are quarantine input, never aliases for these fields.

## P0 loop codes

- `WORK`: work / first salary.
- `HOUSING`: housing / mortgage.
- `RETIREMENT`: Retirement Case / rente-capital.
- `DISABILITY`: disability / protection.
- `SUCCESSION`: succession / transmission.
- `FRONTALIER`: cross-border worker.

## G1_P0_CANONICAL_KEYS

| canonical_key | storage_key | coach_profile_path | type_unit | allowed_sources | freshness_tier | confidence_weight | classification | profile_owner | write_path | reader_evidence | consumers | p0_loops | tier | required_for_output | allowed_output_when_missing | legal_source_asof | sensitivity_purpose | status | existing_gate | missing_gate | blocks_G2 | ticket |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| birthYear | q_birth_year | birthYear | int_year | userInput,certificate | static | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@birthYear | age,archetype,AVS,LPP | WORK,HOUSING,RETIREMENT,DISABILITY,SUCCESSION,FRONTALIER | P0 | yes | partial+ask | n/a | age_sensitive_rules | live | static_ledger_parity,provider_tests | ledger_dead_key_behavioral,provenance_on_write | yes | G1-LDG-03 |
| dateOfBirth | q_date_of_birth | dateOfBirth | ISO_date | userInput,certificate | static | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/coach_narrative_service.dart#CoachNarrativeService._generateStatic@dateOfBirth | precise_age,AVS21 | RETIREMENT,DISABILITY | P0 | conditional | partial+ask | n/a | reference_age | live | static_ledger_parity | ledger_dead_key_behavioral,provenance_on_write | yes | G1-LDG-03 |
| canton | q_canton | canton | CH_canton_code | userInput,certificate | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@canton | tax,mortgage,budget | WORK,HOUSING,RETIREMENT,SUCCESSION,FRONTALIER | P0 | yes | partial+ask | required_for_tax | cantonal_tax | partial | static_ledger_parity,provider_tests | default_is_not_known,provenance_on_write | yes | G1-LDG-04 |
| commune | q_commune | commune | string | userInput,certificate | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/financial_core/confidence_scorer.dart#ConfidenceScorer.score@commune | communal_tax | HOUSING,RETIREMENT,SUCCESSION | P0 | conditional | partial+ask | required_for_precise_tax | communal_tax | live | static_ledger_parity,provider_tests | ledger_dead_key_behavioral,provenance_on_write | yes | G1-LDG-03 |
| householdType | q_civil_status | etatCivil | household_enum | userInput | event_static | 0.60 | fact | household | applySaveFact,mergeAnswers | apps/mobile/lib/models/coach_profile.dart:2617 | couple_AVS,household | HOUSING,RETIREMENT,SUCCESSION,FRONTALIER | P0 | yes | partial+ask | n/a | household_rules | semantic_mismatch | static_ledger_parity | semantic_enum_roundtrip,civil_status_split | yes | G1-LDG-02 |
| employmentStatus | q_employment_status | employmentStatus | employment_enum | userInput,certificate | event_static | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/models/coach_profile.dart:2684 | archetype,LPP,3a,protection | WORK,HOUSING,RETIREMENT,DISABILITY,FRONTALIER | P0 | yes | partial+ask | n/a | employment_eligibility | semantic_mismatch | static_ledger_parity,provider_tests | semantic_enum_roundtrip | yes | G1-LDG-02 |
| has2ndPillar | q_has_pension_fund | prevoyance.hasPensionFund | bool | userInput,certificate | event_static | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@hasPensionFund | LPP_gate,archetype | HOUSING,RETIREMENT,DISABILITY,FRONTALIER | P0 | yes | partial+ask | required_for_LPP | LPP_eligibility | live | static_ledger_parity,provider_tests | provenance_on_write | yes | G1-PROV-01 |
| goal | q_main_goal | goalA.type | goal_enum | userInput | event_static | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/models/coach_profile.dart:2969 | prioritization,Pulse | WORK,HOUSING,RETIREMENT,DISABILITY,SUCCESSION,FRONTALIER | P1 | no | generic_education | n/a | prompt_ranking | semantic_mismatch | static_ledger_parity,provider_tests | semantic_enum_roundtrip | yes | G1-LDG-02 |
| targetRetirementAge | q_target_retirement_age | targetRetirementAge | int_years_58_70 | userInput | event_static | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/lifecycle/lifecycle_detector.dart#LifecycleDetector.detect@targetRetirementAge | retirement_scenarios,donation_guard | RETIREMENT,SUCCESSION | P0 | yes | partial+ask | n/a | retirement_timing | live | static_ledger_parity | range_validation,provenance_on_write | yes | G1-LDG-03 |
| gender | q_gender | gender | enum_M_F | userInput,certificate | static | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/models/coach_profile.dart:2598 | AVS21 | RETIREMENT | P1 | conditional | partial+ask | required_for_AVS21 | reference_age | live | static_ledger_parity,provider_tests | provenance_on_write | no | G1-PROV-01 |
| incomeNetMonthly | q_net_income_period_chf+q_pay_frequency | monthlyNetIncomeDeclared | CHF_month | userInput,certificate,openBanking | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@monthlyNetIncomeDeclared | budget,liquidity | WORK,HOUSING,DISABILITY | P0 | conditional | partial+ask | n/a | affordability | live | static_ledger_parity | frequency_roundtrip,provenance_on_write | yes | G1-LDG-03 |
| incomeGrossMonthly | q_gross_salary_annual | salaireBrutMensuel | CHF_month | userInput,certificate,openBanking | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@salaireBrutMensuel | tax,LPP,protection | WORK,HOUSING,RETIREMENT,DISABILITY,FRONTALIER | P0 | conditional | partial+ask | n/a | salary_sensitivity | partial | static_ledger_parity | 13_month_roundtrip,provenance_on_write | yes | G1-LDG-03 |
| incomeNetYearly | q_net_income_period_chf+q_pay_frequency | monthlyNetIncomeDeclared | CHF_year | userInput,certificate | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/models/coach_profile.dart:2634 | tax,budget | WORK,HOUSING,DISABILITY | P1 | conditional | partial+ask | n/a | income_frequency | live | static_ledger_parity | frequency_roundtrip,provenance_on_write | no | G1-LDG-03 |
| incomeGrossYearly | q_gross_salary_annual | revenuBrutAnnuel | CHF_year | userInput,certificate | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/screens/unemployment_screen.dart#_UnemploymentScreenState._monthlyInsuredEarnings@revenuBrutAnnuel | tax,LPP,mortgage | WORK,HOUSING,RETIREMENT,DISABILITY,FRONTALIER | P0 | yes | partial+ask | n/a | salary_sensitivity | live | static_ledger_parity,provider_tests | provenance_on_write | yes | G1-PROV-01 |
| selfEmployedNetIncome | q_self_employed_income+q_net_income_period_chf+q_pay_frequency+q_employment_status | selfEmployedNetIncome | CHF_year | userInput,certificate | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/independent_ledger_facts.dart#IndependentLedgerFacts.selfEmployedAnnualIncome@selfEmployedNetIncome | independent_AVS,3a,IJM | WORK,RETIREMENT,DISABILITY,FRONTALIER | P0 | conditional | partial+ask | required_for_independent_rules | independent_income | live | static_ledger_parity,provider_tests | provenance_on_write | yes | G1-PROV-01 |
| companyProfitAnnual | q_company_profit_annual_chf | companyProfitAnnual | CHF_year | userInput,certificate | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/models/coach_profile.dart:2632 | company_owner_scenarios | WORK,RETIREMENT,DISABILITY | P1 | conditional | partial+ask | n/a | company_envelope | live | static_ledger_parity,provider_tests | provenance_on_write | no | G1-PROV-01 |
| employmentRate | q_employment_rate | employmentRate | percent_0_100 | userInput,certificate | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/models/coach_profile.dart:2667 | part_time,LPP | WORK,RETIREMENT,DISABILITY | P1 | conditional | partial+ask | n/a | coordination_deduction | live | static_ledger_parity,provider_tests | backend_range_validation,provenance_on_write | no | G1-PROV-01 |
| annualBonus | q_annual_bonus | bonusPourcentage | CHF_year_to_percent | userInput,certificate | annual | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/models/coach_profile.dart:2671 | annual_income | WORK,HOUSING,RETIREMENT,DISABILITY | P1 | conditional | partial+ask | n/a | salary_variability | live | static_ledger_parity,provider_tests | provenance_on_write | no | G1-PROV-01 |
| lppInsuredSalary | _coach_salaire_assure | prevoyance.salaireAssure | CHF_year | certificate,userInput | annual | source_weight | fact | self | applySaveFact,mergeAnswers,scan_confirm | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@salaireAssure | LPP,disability | RETIREMENT,DISABILITY | P0 | conditional | partial+ask | required_for_LPP | insured_salary | live | static_ledger_parity | provenance_on_write,source_date | yes | G1-PROV-01 |
| avoirLpp | _coach_avoir_lpp | prevoyance.avoirLppTotal | CHF | certificate,userInput,estimated | annual | source_weight | fact | self | applySaveFact,mergeAnswers,scan_confirm | apps/mobile/lib/models/coach_profile.dart:2789 | mortgage,retirement,disability | HOUSING,RETIREMENT,DISABILITY,SUCCESSION,FRONTALIER | P0 | yes | partial+ask | required_for_LPP | capital_base | quarantined | static_ledger_parity,provider_tests | scenario_must_not_overwrite_fact,provenance_on_write | yes | G1-SCN-01 |
| avoirLppObligatoire | _coach_avoir_lpp_oblig | prevoyance.avoirLppObligatoire | CHF | certificate | annual | 0.95 | fact | self | applySaveFact,mergeAnswers,scan_confirm | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@avoirLppObligatoire | rente_capital_split | RETIREMENT | P0 | conditional | partial+ask | required_for_precise_LPP | obligatory_split | live | static_ledger_parity | provenance_on_write,source_date | yes | G1-PROV-01 |
| avoirLppSurobligatoire | _coach_avoir_lpp_suroblig | prevoyance.avoirLppSurobligatoire | CHF | certificate | annual | 0.95 | fact | self | applySaveFact,mergeAnswers,scan_confirm | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@avoirLppSurobligatoire | rente_capital_split | RETIREMENT | P0 | conditional | partial+ask | required_for_precise_LPP | surobligatory_split | live | static_ledger_parity | provenance_on_write,source_date | yes | G1-PROV-01 |
| lppBuybackMax | _coach_rachat_maximum | prevoyance.rachatMaximum | CHF | certificate,userInput | annual | source_weight | fact | self | applySaveFact,mergeAnswers,scan_confirm | apps/mobile/lib/models/coach_profile.dart:2776 | buyback,tax | RETIREMENT | P1 | conditional | partial+ask | required_for_buyback | buyback_capacity | live | static_ledger_parity | provenance_on_write,source_date | no | G1-PROV-01 |
| hasVoluntaryLpp | q_has_voluntary_lpp | prevoyance.hasVoluntaryLpp | bool | userInput,certificate | event_static | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/models/coach_profile.dart:2731 | independent_LPP | RETIREMENT,DISABILITY,FRONTALIER | P1 | conditional | partial+ask | required_for_independent_LPP | eligibility | live | static_ledger_parity,provider_tests | provenance_on_write | no | G1-PROV-01 |
| pillar3aAnnual | q_3a_annual_contribution | pillar3aAnnualContribution | CHF_year | userInput,certificate,openBanking | annual | source_weight | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/financial_fitness_service.dart#FinancialFitnessService._calculatePrevoyance@pillar3aAnnualContribution | current_3a_score | RETIREMENT,FRONTALIER | P1 | conditional | partial+ask | required_for_3a_deduction | contribution_capacity | live | static_ledger_parity | direct_field_semantics,provenance_on_write | no | G1-LDG-05 |
| pillar3aBalance | q_3a_total | prevoyance.totalEpargne3a | CHF | userInput,certificate,openBanking | annual | source_weight | fact | self | applySaveFact,mergeAnswers,scan_confirm | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@totalEpargne3a | mortgage,retirement,succession | HOUSING,RETIREMENT,SUCCESSION,FRONTALIER | P0 | yes | partial+ask | required_for_3a | retirement_capital | live | static_ledger_parity,provider_tests | provenance_on_write,source_date | yes | G1-PROV-01 |
| savingsMonthly | q_savings_monthly | monthlySavingsContribution | CHF_month | userInput,openBanking | annual | source_weight | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/financial_fitness_service.dart#FinancialFitnessService._calculateBudget@monthlySavingsContribution | current_savings_rate_score | WORK,HOUSING,RETIREMENT | P1 | conditional | partial+ask | n/a | savings_capacity | partial | static_ledger_parity | direct_field_semantics,provenance_on_write | no | G1-LDG-05 |
| totalSavings | q_cash_total | patrimoine.epargneLiquide | CHF | userInput,certificate,openBanking,crossValidated | annual | source_weight | fact | self | applySaveFact,mergeAnswers,open_banking | apps/mobile/lib/domain/budget/budget_inputs.dart#BudgetInputs.fromCoachProfile@epargneLiquide | liquidity,mortgage,estate | HOUSING,RETIREMENT,DISABILITY,SUCCESSION | P0 | yes | partial+ask | n/a | liquidity | partial | static_ledger_parity,provider_tests | provenance_survives_reload | yes | G1-PROV-01 |
| wealthEstimate | q_wealth_estimate | patrimoine.wealthEstimate | CHF | userInput,estimated | annual | source_weight | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/streak_service.dart#StreakService.computeMilestones@wealthEstimate | wealth_reconciliation | RETIREMENT,SUCCESSION | P0 | conditional | partial+ask | n/a | aggregate_reconciliation | live | static_ledger_parity,provider_tests | provenance_on_write | yes | G1-PROV-01 |
| hasDebt | q_has_consumer_debt | dettes.hasDette | bool | userInput | volatile | 0.60 | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/goal_selection_service.dart#GoalSelectionService.availableGoals@hasDette | safe_mode,debt_gate | HOUSING,DISABILITY,SUCCESSION,RETIREMENT | P0 | conditional | partial+ask | n/a | debt_presence | partial | static_ledger_parity,provider_tests | legacy_provider_consumer_migration,provenance_on_write | yes | G1-BND-01 |
| totalDebt | _coach_dettes_autres+q_has_consumer_debt | dettes.autresDettes | CHF | userInput,certificate | volatile | source_weight | fact | self | applySaveFact,mergeAnswers | apps/mobile/lib/services/lifecycle_phase_service.dart#LifecyclePhaseService._addSituationalPriorities@autresDettes | net_worth,debt_ratio | HOUSING,DISABILITY,SUCCESSION,RETIREMENT | P0 | conditional | partial+ask | n/a | net_mass | live | static_ledger_parity,provider_tests | provenance_on_write | yes | G1-PROV-01 |
| spouseBirthYear | q_partner_birth_year | conjoint.birthYear | int_year | userInput,certificate | static | 0.60 | fact | partner | applySaveFact,mergeAnswers | NONE | NONE | HOUSING,RETIREMENT,SUCCESSION | P0 | conditional | partial+ask | n/a | couple_timeline | quarantined | static_ledger_parity,provider_tests | typed_consumer,household_bridge,owner_id,provenance_on_write | yes | G1-BND-02 |
| spouseIncomeNetMonthly | q_partner_net_income_chf | NONE | CHF_month | userInput,certificate | annual | 0.60 | fact | partner | applySaveFact,mergeAnswers | NONE | NONE | HOUSING,RETIREMENT,DISABILITY | P0 | conditional | partial+ask | n/a | household_income | quarantined | static_ledger_parity | typed_partner_net_income,semantic_net_income_roundtrip,household_bridge,owner_id,provenance_on_write | yes | G1-BND-02 |
| spouseAvsContributionYears | q_spouse_avs_contribution_years | conjoint.prevoyance.anneesContribuees | int_years_0_44 | userInput,certificate | annual | source_weight | fact | partner | applySaveFact,mergeAnswers | NONE | NONE | RETIREMENT,SUCCESSION | P0 | conditional | partial+ask | required_for_couple_AVS | survivor_income | quarantined | static_ledger_parity,provider_tests | typed_consumer,household_bridge,owner_id,provenance_on_write | yes | G1-BND-02 |
| hasAvsGaps | q_avs_lacunes_status | avsGapStatus | avs_gap_status | userInput,certificate | annual | source_weight | fact | self | applySaveFact,mergeAnswers,scan_confirm | NONE | NONE | RETIREMENT,FRONTALIER | P0 | conditional | partial+ask | required_for_AVS | contribution_gap | quarantined | static_ledger_parity,provider_tests | typed_consumer,no_fabricated_gap_years,provenance_on_write | yes | G1-LDG-06 |
| avsContributionYears | q_avs_contribution_years | prevoyance.anneesContribuees | int_years_0_44 | userInput,certificate | annual | source_weight | fact | self | applySaveFact,mergeAnswers,scan_confirm | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@anneesContribuees | AVS_projection | RETIREMENT,FRONTALIER | P0 | yes | partial+ask | required_for_AVS | contribution_years | partial | static_ledger_parity,provider_tests | write_order_independence,provenance_on_write | yes | G1-LDG-06 |
| childrenCount | q_children | nombreEnfants | int_count | userInput,certificate | event_static | 0.60 | fact | household | mergeAnswers | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@nombreEnfants | household,succession,benefits | HOUSING,RETIREMENT,DISABILITY,SUCCESSION,FRONTALIER | P0 | conditional | partial+ask | required_for_family_rules | dependants | live | screen_ledger_tests | ledger_dead_key_behavioral,provenance_on_write | yes | G1-LDG-03 |
| nationality | q_nationality | nationality | ISO_country_code | userInput,certificate | static | 0.60 | fact | self | mergeAnswers | apps/mobile/lib/services/fri_computation_service.dart#FriComputationService.detectArchetype@nationality | archetype,FATCA | RETIREMENT,FRONTALIER | P0 | conditional | partial+ask | required_for_cross_border | eligibility | live | NONE | ledger_dead_key_behavioral,provenance_on_write | yes | G1-LDG-03 |
| residencePermit | q_residence_permit | residencePermit | permit_enum | userInput,certificate | event_static | 0.60 | fact | self | mergeAnswers | apps/mobile/lib/services/fri_computation_service.dart#FriComputationService.detectArchetype@residencePermit | cross_border,archetype | FRONTALIER,RETIREMENT | P0 | yes | partial+ask | required_for_cross_border | permit_eligibility | live | NONE | ledger_dead_key_behavioral,provenance_on_write | yes | G1-LDG-03 |
| unemploymentContributionMonths | q_unemployment_contribution_months | unemploymentContributionMonths | int_months_0_24 | userInput,certificate | annual | source_weight | fact | self | mergeAnswers | apps/mobile/lib/screens/unemployment_screen.dart#_UnemploymentScreenState._contributionMonths@unemploymentContributionMonths | LACI | WORK | P0 | yes | partial+ask | required_for_LACI | unemployment_eligibility | live | job_screen_tests | ledger_dead_key_behavioral,provenance_on_write | yes | G1-LDG-03 |
| housingCostMonthly | q_housing_cost_period_chf+q_housing_pay_frequency | depenses.loyer | CHF_month | userInput,certificate,openBanking | volatile | source_weight | fact | household | mergeAnswers,budget_bridge | apps/mobile/lib/domain/budget/budget_inputs.dart#BudgetInputs.fromCoachProfile@loyer | budget,mortgage,retirement | HOUSING,RETIREMENT,DISABILITY | P0 | yes | partial+ask | n/a | budget_floor | partial | budget_screen_tests | provider_bridge_recompute,provenance_on_write | yes | G1-BND-03 |
| healthPremiumMonthly | q_lamal_premium_monthly_chf | depenses.assuranceMaladie | CHF_month | userInput,certificate,openBanking | annual | source_weight | fact | self | mergeAnswers,budget_bridge | apps/mobile/lib/domain/budget/budget_inputs.dart#BudgetInputs.fromCoachProfile@assuranceMaladie | budget,disability | RETIREMENT,DISABILITY | P0 | conditional | partial+ask | n/a | budget_floor | partial | budget_screen_tests | provider_bridge_recompute,provenance_on_write | yes | G1-BND-03 |
| monthlyExpenses | q_housing_cost_period_chf+q_lamal_premium_monthly_chf | userProvidedFields.monthlyExpenses | completion_marker | userInput,certificate,openBanking | volatile | source_weight | completion_marker | household | derived_on_rebuild | apps/mobile/lib/screens/disability/disability_gap_screen.dart#_DisabilityGapScreenState._monthlyExpenses@monthlyExpenses | disability,budget_floor | RETIREMENT,DISABILITY | P0 | yes | partial+ask | n/a | minimum_expense_gate | live | provider_tests | default_is_not_known | yes | G1-LDG-04 |
| has3a | q_has_3a | hasPillar3a | bool | userInput,certificate,openBanking | annual | source_weight | fact | self | mergeAnswers | NONE | NONE | RETIREMENT,FRONTALIER | P1 | conditional | partial+ask | required_for_3a | account_presence | quarantined | NONE | typed_consumer,semantic_roundtrip,provenance_on_write | no | G1-LDG-05 |
| pillar3aAccountsCount | q_3a_accounts_count | prevoyance.nombre3a | int_count_0_5 | userInput,certificate,openBanking | annual | source_weight | fact | self | mergeAnswers | apps/mobile/lib/services/financial_core/withdrawal_sequencing_service.dart#WithdrawalSequencingService._collectCapitalSources@nombre3a | staggered_withdrawal | RETIREMENT | P0 | conditional | partial+ask | required_for_staggering | withdrawal_order | live | NONE | ledger_dead_key_behavioral,provenance_on_write | yes | G1-LDG-03 |
| pillar3aProviders | q_3a_providers | providers3a | list_string | userInput,certificate,openBanking | annual | source_weight | fact | self | mergeAnswers | apps/mobile/lib/models/coach_profile.dart:3433 | account_inventory | RETIREMENT | P1 | conditional | partial+ask | required_for_staggering | provider_order | live | NONE | provenance_on_write | no | G1-PROV-01 |
| liquidSavingsAmount | q_cash_total | userProvidedFields.liquidSavingsAmount | completion_marker | userInput,certificate,openBanking,crossValidated | annual | source_weight | completion_marker | self | derived_on_rebuild | apps/mobile/lib/services/streak_service.dart#StreakService.computeMilestones@liquidSavingsAmount | liquidity_gate,estate | HOUSING,RETIREMENT,DISABILITY,SUCCESSION | P0 | yes | partial+ask | n/a | explicit_cash_gate | live | provider_tests | provenance_survives_reload | yes | G1-PROV-01 |
| investmentsTotal | q_investments_total | patrimoine.investissements | CHF | userInput,openBanking,certificate | annual | source_weight | fact | self | mergeAnswers,open_banking | apps/mobile/lib/services/financial_fitness_service.dart#FinancialFitnessService._calculatePatrimoine@investissements | estate,wealth | RETIREMENT,SUCCESSION | P0 | conditional | partial+ask | n/a | net_mass | live | donation_ledger_tests | provenance_on_write | yes | G1-PROV-01 |
| propertyMarketValue | q_property_market_value | patrimoine.propertyMarketValue | CHF | userInput,estimated,certificate | annual | source_weight | fact | household | mergeAnswers | apps/mobile/lib/services/cross_validation_service.dart#CrossValidationService._checkMortgageTragbarkeit@propertyMarketValue | mortgage,estate | HOUSING,RETIREMENT,SUCCESSION | P0 | conditional | partial+ask | n/a | property_net_value | live | donation_ledger_tests | provenance_on_write | yes | G1-PROV-01 |
| mortgageBalance | _coach_dettes_hypotheque | dettes.hypotheque | CHF | userInput,certificate | volatile | source_weight | fact | household | mergeAnswers,scan_confirm | apps/mobile/lib/models/coach_profile.dart:2872 | mortgage,estate | HOUSING,RETIREMENT,SUCCESSION | P0 | conditional | partial+ask | n/a | property_net_value | quarantined | donation_ledger_tests | duplicate_q_mortgage_balance_reconciliation,provenance_on_write | yes | G1-LDG-07 |
| mortgageRate | q_mortgage_rate | patrimoine.mortgageRate | percent | userInput,certificate | volatile | source_weight | fact | household | mergeAnswers | apps/mobile/lib/services/financial_core/cross_pillar_calculator.dart#CrossPillarCalculator._mortgageTaxDeduction@mortgageRate | amortization,renewal | HOUSING,RETIREMENT | P0 | conditional | partial+ask | n/a | rate_shock | live | mortgage_screen_tests | provenance_on_write | yes | G1-PROV-01 |
| debtPaymentsMonthly | q_debt_payments_period_chf | dettes.totalMensualite | CHF_month | userInput,certificate,openBanking | volatile | source_weight | fact | self | mergeAnswers,budget_bridge | apps/mobile/lib/services/financial_core/cross_pillar_calculator.dart#CrossPillarCalculator._budgetReallocation@totalMensualite | debt_ratio,budget | HOUSING,DISABILITY,RETIREMENT | P0 | conditional | partial+ask | n/a | debt_service | partial | debt_ledger_tests | provenance_on_write,provider_bridge_recompute | yes | G1-BND-03 |
| avsEstimatedMonthlyPension | _coach_avs_rente_estimee | prevoyance.renteAVSEstimeeMensuelle | CHF_month | certificate,estimated | annual | source_weight | fact | self | scan_confirm,mergeAnswers | NONE | NONE | RETIREMENT,DISABILITY | P0 | conditional | partial+ask | required_for_AVS | pension_income | quarantined | extraction_tests | typed_consumer,source_date,provenance_on_write | yes | G1-PROV-01 |
| avsRamd | _coach_avs_ramd | prevoyance.ramd | CHF_year | certificate | annual | 0.95 | fact | self | scan_confirm | apps/mobile/lib/models/coach_profile.dart:2783 | AVS_precision | RETIREMENT | P1 | conditional | partial+ask | required_for_precise_AVS | pension_precision | live | extraction_tests | source_date,provenance_on_write | no | G1-PROV-01 |
| lppConversionRate | _coach_taux_conversion | prevoyance.tauxConversion | decimal | certificate,estimated | annual | source_weight | fact | self | scan_confirm,mergeAnswers | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@tauxConversion | rente_capital | RETIREMENT | P0 | conditional | partial+ask | required_for_LPP | conversion_rate | partial | extraction_tests | default_is_not_known,source_date,provenance_on_write | yes | G1-LDG-04 |
| lppConversionRateSurob | _coach_taux_conversion_suroblig | prevoyance.tauxConversionSuroblig | decimal | certificate | annual | 0.95 | fact | self | scan_confirm,mergeAnswers | apps/mobile/lib/services/confidence/coach_profile_confidence_adapter.dart#CoachProfileConfidenceAdapter.compute@tauxConversionSuroblig | rente_capital | RETIREMENT | P0 | conditional | partial+ask | required_for_precise_LPP | conversion_rate | live | extraction_tests | source_date,provenance_on_write | yes | G1-PROV-01 |
| lppProjectedAnnualPension | _coach_lpp_evidence_v1 | prevoyance.projectedRenteLpp | CHF_year | certificate | annual | 0.95 | fact | self | acceptLppReview | NONE | NONE | RETIREMENT,DISABILITY | P0 | conditional | partial+ask | required_for_certificate_projection | pension_income | quarantined | provenance_restart_test,lpp_typed_evidence | typed_consumer,scenario_must_not_overwrite_fact | yes | G1-SCN-01 |
| lppProjectedCapital65 | _coach_lpp_evidence_v1 | prevoyance.projectedCapital65 | CHF | certificate | annual | 0.95 | fact | self | acceptLppReview | NONE | NONE | RETIREMENT | P0 | conditional | partial+ask | required_for_certificate_projection | capital_projection | quarantined | provenance_restart_test,lpp_typed_evidence | typed_consumer,scenario_must_not_overwrite_fact | yes | G1-SCN-01 |
| lppDisabilityCoverage | _coach_lpp_evidence_v1 | prevoyance.disabilityCoverage | CHF_year | certificate | annual | 0.95 | fact | self | acceptLppReview | NONE | NONE | DISABILITY | P0 | conditional | partial+ask | required_for_LPP_coverage | protection_gap | quarantined | provenance_restart_test,lpp_typed_evidence | typed_consumer,partner_downstream_recompute | yes | G1-BND-02 |
| lppDeathCoverage | _coach_lpp_evidence_v1 | prevoyance.deathCoverage | CHF | certificate | annual | 0.95 | fact | self | acceptLppReview | NONE | NONE | SUCCESSION,RETIREMENT | P1 | conditional | partial+ask | required_for_survivor | survivor_gap | quarantined | provenance_restart_test,lpp_typed_evidence | typed_consumer,partner_downstream_recompute | no | G1-BND-02 |
| taxAssessmentContext | _coach_tax_snapshots_v1 | fiscal.snapshots[] | TaxSnapshot_metadata | estimated,userInput,certificate | annual | source_weight | fact | self | scan_confirm | apps/mobile/lib/models/coach_profile.dart#FiscalSnapshotSelector.selectAssessedBaseline@fiscal | FiscalSnapshotSelector.selectAssessedBaseline | RETIREMENT,SUCCESSION,FRONTALIER | P0 | yes | partial+ask | required_for_precise_tax | period,subject,jurisdiction | quarantined | tax_extraction_tests,ticket_red_green | frozen_runtime_proof,external_audits,activation_decision | yes | G1-PROV-03 |
| taxIccTaxableIncome | _coach_tax_snapshots_v1 | fiscal.snapshots[].cantonalCommunalTaxableIncomeChf | CHF_year | estimated,userInput,certificate | annual | source_weight | fact | self | scan_confirm | apps/mobile/lib/models/coach_profile.dart#FiscalSnapshotSelector._matchesRequestedField@cantonalCommunalTaxableIncomeChf | tax_context | RETIREMENT,FRONTALIER | P0 | conditional | partial+ask | required_for_precise_tax | tax_sensitivity | quarantined | tax_extraction_tests,ticket_red_green | frozen_runtime_proof,external_audits,activation_decision | yes | G1-PROV-03 |
| taxIfdTaxableIncome | _coach_tax_snapshots_v1 | fiscal.snapshots[].federalTaxableIncomeChf | CHF_year | estimated,userInput,certificate | annual | source_weight | fact | self | scan_confirm | apps/mobile/lib/models/coach_profile.dart#FiscalSnapshotSelector._matchesRequestedField@federalTaxableIncomeChf | tax_context | RETIREMENT,FRONTALIER | P0 | conditional | partial+ask | required_for_precise_tax | federal_tax_sensitivity | quarantined | tax_extraction_tests,ticket_red_green | frozen_runtime_proof,external_audits,activation_decision | yes | G1-PROV-03 |
| taxIccTaxableWealth | _coach_tax_snapshots_v1 | fiscal.snapshots[].cantonalCommunalTaxableWealthChf | CHF | estimated,userInput,certificate | annual | source_weight | fact | self | scan_confirm | apps/mobile/lib/models/coach_profile.dart#FiscalSnapshotSelector._matchesRequestedField@cantonalCommunalTaxableWealthChf | wealth_tax | RETIREMENT,SUCCESSION | P1 | conditional | partial+ask | required_for_precise_tax | wealth_tax | quarantined | tax_extraction_tests,ticket_red_green | frozen_runtime_proof,external_audits,activation_decision | no | G1-PROV-03 |
| taxIccAssessedTax | _coach_tax_snapshots_v1 | fiscal.snapshots[].cantonalCommunalAssessedTax.amountChf | CHF_year | estimated,userInput,certificate | annual | source_weight | fact | self | scan_confirm | apps/mobile/lib/models/coach_profile.dart#FiscalSnapshotSelector._matchesCantonalAssessedTax@cantonalCommunalAssessedTax | tax_context | RETIREMENT,FRONTALIER | P1 | conditional | partial+ask | required_for_precise_tax | tax_baseline | quarantined | tax_extraction_tests,ticket_red_green | frozen_runtime_proof,external_audits,activation_decision | no | G1-PROV-03 |
| taxIfdAssessedTax | _coach_tax_snapshots_v1 | fiscal.snapshots[].federalDirectAssessedTax.amountChf | CHF_year | estimated,userInput,certificate | annual | source_weight | fact | self | scan_confirm | apps/mobile/lib/models/coach_profile.dart#FiscalSnapshotSelector._matchesFederalAssessedTax@federalDirectAssessedTax | tax_context | RETIREMENT,FRONTALIER | P1 | conditional | partial+ask | required_for_precise_tax | federal_tax_baseline | quarantined | tax_extraction_tests,ticket_red_green | frozen_runtime_proof,external_audits,activation_decision | no | G1-PROV-03 |
| taxExplicitMarginalRate | _coach_tax_snapshots_v1 | fiscal.snapshots[].explicitMarginalIncomeTaxRate | ratio_0_1 | estimated,userInput,certificate | annual | source_weight | fact | self | scan_confirm | apps/mobile/lib/models/coach_profile.dart#FiscalSnapshotSelector._matchesRequestedField@explicitMarginalIncomeTaxRate | withdrawal_tax,buyback | RETIREMENT | P0 | conditional | partial+ask | required_for_precise_tax | tax_sensitivity | quarantined | tax_extraction_tests,ticket_red_green | frozen_runtime_proof,external_audits,activation_decision | yes | G1-PROV-03 |
| taxExplicitAverageRate | _coach_tax_snapshots_v1 | fiscal.snapshots[].explicitAverageIncomeTaxRate | ratio_0_1 | estimated,userInput,certificate | annual | source_weight | fact | self | scan_confirm | apps/mobile/lib/models/coach_profile.dart#FiscalSnapshotSelector._matchesRequestedField@explicitAverageIncomeTaxRate | tax_context_only | RETIREMENT,FRONTALIER | P1 | conditional | partial+ask | n/a | tax_context | quarantined | tax_extraction_tests,ticket_red_green | frozen_runtime_proof,external_audits,activation_decision | no | G1-PROV-03 |
| workCanton | NONE | NONE | CH_canton_code | userInput,certificate | annual | 0.60 | fact | self | NONE | NONE | source_tax,cross_border | FRONTALIER | P0 | yes | partial+ask | required | work_tax | missing | NONE | canonical_storage,typed_field,provenance_on_write | yes | G1-FRONT-01 |
| workCountry | NONE | NONE | ISO_country_code | userInput,certificate | event_static | 0.60 | fact | self | NONE | NONE | social_security | FRONTALIER | P0 | yes | partial+ask | required | social_security_jurisdiction | missing | NONE | canonical_storage,typed_field,provenance_on_write | yes | G1-FRONT-01 |
| residenceCountry | NONE | NONE | ISO_country_code | userInput,certificate | event_static | 0.60 | fact | self | NONE | NONE | treaty,tax,social_security | FRONTALIER | P0 | yes | partial+ask | required | residence_jurisdiction | missing | NONE | canonical_storage,typed_field,provenance_on_write | yes | G1-FRONT-01 |
| lppRegulationReference | _coach_lpp_evidence_v1 | lppRegulationReference | document_ref | certificate | event_static | 0.95 | specialist_reference | self | acceptLppRegulationReference,recordLppRegulation,derived_on_rebuild | apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart#_RetirementDashboardScreenState._buildLppRegulationEducation@lppRegulationReference | retirement_lpp_regulation_reference_education,retirement_lpp_regulation_handoff_cta,retirement_lpp_regulation_handoff_sheet,retirement_lpp_regulation_reference_recovery,retirement_lpp_regulation_reconfirm_cta,financial_report_lpp_regulation_handoff | RETIREMENT | P0 | conditional | educational_only | required | regulation_terms | live | lpp_plan_classifier,lpp_regulation_document_authority,lpp_regulation_ledger_contract,lpp_regulation_provider,lpp_regulation_document_bridge,lpp_regulation_bridge_hardening,canonical_regulation_kind,bridge_wrapper_audits,writer_model_wrapper_audits,lpp_regulation_handoff_model,lpp_regulation_dashboard_consumer_5_of_5,retirement_dashboard_regression_24_of_24,consumer_wrapper_audits,autonomous_declared_fund_relationship,snapshotless_regulation_root,cold_profile_without_numeric_lpp,numeric_add_replacement_preservation,distinct_process_runtime,exact_22_of_22_evidence,production_default_off_before_after,privacy_retention_guard,bounded_opus_audits,schema3_recovery_marker,opaque_resolution_classifier,visible_legacy_missing_mismatch_recovery,recovery_copy_6_locales,recovery_runtime_missing_bnd_7cb5ea4c6,bnd_restore_compare,dossier_pdf_parity_runtime_274736a50 | activation_decision | yes | G1-RET-REF-01 |
| lppCapitalNoticeDeadline | _coach_lpp_evidence_v1 | lppCapitalNoticeDeadline | ISO_date | certificate | event_static | 0.95 | specialist_reference | self | acceptLppCapitalNotice,recordLppCapitalNotice,derived_on_rebuild | apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart#_RetirementDashboardScreenState._buildLppCapitalNoticeEducation@lppCapitalNoticeDeadline | retirement_dashboard_deadline_education,financial_report_lpp_capital_notice_handoff,pdf_lpp_capital_notice_section | RETIREMENT | P0 | conditional | educational_only | required | withdrawal_deadline | live | ret_ref_capital_notice_native_green_36152b997,native_production_ui_acquisition_seam,strict_self_root,serialized_writer,exact_raw_free_bnd,cold_dashboard_consumer,authority_replacement_invalidation,snapshot_replacement_invalidation,process_death_runtime,wrapper_opus_audits,capital_notice_dossier_pdf_exact_sha_a00b4c68a,report_route_handoff_order,pdf_header_length_runtime,host_dossier_pdf_parity_11_of_11,recovery_suppression_exact_restoration,runtime_code_opus_audit,integration_code_product_opus_audits,minimized_proof_checksums | activation_decision | yes | G1-RET-REF-01 |
| pillar3aBeneficiaryClause | _coach_pillar3a_beneficiary_evidence_v1 | currentPillar3aBeneficiaryEvidence | document_ref | certificate,userInput | event_static | 0.95 | specialist_reference | self | acceptPillar3aBeneficiaryReview,recordPillar3aBeneficiaryEvidence | apps/mobile/lib/providers/document_provider.dart#DocumentProvider.resolvePillar3aBeneficiaryConsumer@currentPillar3aBeneficiaryEvidence | retirement_pillar3a_beneficiary_authority,retirement_pillar3a_beneficiary_handoff_sheet,financial_report_pillar3a_beneficiary_handoff,pdf_pillar3a_beneficiary_section | RETIREMENT,SUCCESSION | P0 | conditional | educational_only | required | institutional_attestation_declared_relation_specialist_handoff | quarantined | exact_secure_root,serialized_cas_writer,raw_free_bnd_join,fail_closed_consumer,dossier_pdf_host_contract,offline_unicode_pdf | exact_sha_native_runtime,wrapper_code_product_audits,activation_decision | yes | G1-RET-REF-01 |
| matrimonialRegime | NONE | NONE | regime_enum | userInput,certificate | event_static | source_weight | fact | household | NONE | NONE | succession,rente_capital | RETIREMENT,SUCCESSION | P0 | conditional | partial+ask | required | estate_partition | missing | NONE | canonical_storage,typed_field,provenance_on_write | yes | G1-SUCCESSION-01 |
| estateInstrumentReferences | NONE | NONE | list_document_ref | certificate | event_static | 0.95 | specialist_reference | document_ref | NONE | NONE | will,pact,mandate | SUCCESSION,RETIREMENT | P0 | conditional | educational_only | required | specialist_handoff | missing | NONE | document_reference_contract,source_date | yes | G1-SUCCESSION-01 |
| latestTaxDecisionReference | _coach_tax_snapshots_v1 | latestTaxDecisionReference | document_ref | certificate | event_static | 0.95 | specialist_reference | self | acceptTaxReview,derived_on_rebuild | apps/mobile/lib/services/financial_core/confidence_scorer.dart#ConfidenceScorer._hasPrecisionReadyTaxDecision@latestTaxDecisionReference | tax_baseline,data_block_fiscal_prompt | RETIREMENT,SUCCESSION,FRONTALIER | P0 | conditional | partial+ask | required | tax_source | live | ret_ref_green_cdc786782,specialist_reference_contract,tax_provenance_profile,confidence_scorer_tax_kill_switch | frozen_runtime_proof,external_audits,activation_decision | yes | G1-RET-REF-01 |

`pillar3aBeneficiaryClause` is intentionally not a `beneficiary_order` fact.
Its secure root separates institution-attested document metadata from a
user-declared current contract relation. The qualified consumer and specialist
handoff expose neither beneficiary identity nor class/order/rank/share. The
row's `currentPillar3aBeneficiaryEvidence` path is the dedicated secure-root
projection on `CoachProfileProvider`, not a `CoachProfile` financial value.
Mixed known+inactive resolution does not promote the inactive contract: only
known metadata is projected; every ambiguous state fails the whole handoff.
`quarantined` records the actual proof level: production code and host dossier/
PDF contracts exist behind three default-false flags, but wrapper audits,
frozen exact-SHA native runtime and activation are still missing. It must not be
changed to `live` until those gates are accepted and the ledger reader gate can
validate this dedicated secure-root consumer mechanically.

`lppRegulationReference` now has bounded autonomous regulation-only and visible
recovery technical atoms under the same G1-RET-REF-01 ticket. The schema-3 root
stores the required user declaration (`currentFund`, `uncertain` or
`formerOrOther`) or a strict opaque legacy-recovery reason without binding
regulation applicability to a numeric LPP snapshot. Its qualified reader remains
`_RetirementDashboardScreenState._buildLppRegulationEducation`, which classifies
the BND bridge through `DocumentProvider.resolveLppRegulationReference`, resolves
the known state only on an exact join, and otherwise renders the state-specific
legacy, missing-reference or mismatch recovery. Exact evidence still feeds the
neutral card, CTA and local metadata-only specialist sheet in all three loaded
Dashboard branches. The sheet retains the semantic header, screen-local privacy
boundary and six conditional questions; it has no IDs, raw document, financial
values, advice, route, network, share or export.

Exact pushed runtime SHA `6066f1c94786aa1bc4697c29b4a670b7cea3dca4`
supersedes the historical `fe857a733385357a12d564bd0a7894b30f887e82`
snapshot-bound proof for current cutover semantics. Exact pushed SHA
`7cb5ea4c64e0a59d4e2f38f8f67eff7c924bd32a` extends that same runtime with
`missingDocumentReference`: the known card and handoff disappear, the exact
French recovery body and CTA appear without stale tuple data, the CTA reaches
`/scan?type=lppPlan`, and the original BND is restored and compared in a
`finally` boundary. One Patrol suite still passes 2/2, writer and cold reader
remain distinct by PID, a cold profile begins without a numeric LPP snapshot,
and the regulation reference survives later numeric snapshot addition and
replacement. Production-default Maestro passes 1/1 before and after;
reinstall/restoration and 22/22 retained-output completeness pass. These UI
claims come from the tracked reader contract plus the passing suite aggregate;
XCTest output does not expose the internal assertions individually.

The `currentFund` relationship is declared/unverified. It is the intended
bounded declarative authority for the relationship label on this educational
reference; it does not establish legal applicability or objective caisse
verification. The runtime does not objectively prove the caisse/fund identity,
and the matrix does not invent objective verification as a hard activation
blocker. At exact pushed SHA
`274736a50bca659579fe26f68ae4e600469e3a9a`, the reader joins production
bootstrap, shows the exact allowlisted handoff on `/rapport`, builds production
report bytes and suppresses the section in missing, mismatch and legacy
recovery states before restoring the root and BND. The native suite is 2/2;
the host real-byte text contract is 3/3; Maestro before/after, 22/22 outputs,
reinstall, cleanup, restoration and privacy pass. The minimized proof is
`phase-37/ret-ref-01/lpp-regulation-dossier-pdf-runtime-proof-274736a50/`.
The combined runtime wrapper refusal at 2579>2500 lines is explicit; accepted
dossier, PDF and bootstrap component lenses leave P0/P1=0. PDF/dossier caveat
parity is closed, while an explicit activation decision remains open. The
feature stays default-off. No plan value may become a person fact,
calculation, advice or raw document record. Capital-notice activation, the 3a
beneficiary reference and fiscal activation/currentness keep the whole RET-REF
ticket open. RET-REF remains `ticket_only`, G1 remains open at 8.2/10 and G2/G3
remain forbidden.

The bounded capital-notice acquisition blocker is now superseded by exact
pushed runtime SHA `36152b997fbf0c32c1120ddb61f0a8e9d589aa52`. The production
UI acquisition seam performs the numeric certificate review, then
`/scan?type=lppPlan`, the real regulation/capital review and the exact ordered
ledger/BND writes; the scan session is purged before the Dashboard consumer.
Writer and reader are distinct processes, authority replacement and numeric
snapshot replacement both fail closed, and production-default Maestro remains
absent. The minimized proof is
`phase-37/ret-ref-01/lpp-capital-native-runtime-proof-36152b997/`. The real
report/PDF consumer slice is separately GREEN at exact pushed SHA `a00b4c68a`
with minimized proof
`phase-37/ret-ref-01/lpp-capital-dossier-pdf-runtime-proof-a00b4c68a/`.
External document/OCR IO remains synthetic;
`capital_notice_dossier_pdf_parity` is closed and only `activation_decision`
remains in this row's explicit missing-gate cell.

PROV-02 makes the four LPP rows previously marked `dead_on_restart` durable at
the accepted SHA. They remain `quarantined`, not falsely `live`, until their
named downstream/scenario gates prove real consumption; a reconstruction
assignment is not a consumer. The strict root accepts exactly 13 canonical LPP
facts. Spouse pension, child pension, employee contribution and employer
contribution remain unowned P2 follow-ups outside this matrix: the current
adapter excludes them before review/persistence and missing values never become
zero.

## Hard-floor predicate

A row is a live P0 ledger key only when all applicable predicates pass:

1. The row parses with the exact stable columns above and has no duplicate
   `canonical_key`.
2. `fact` rows have one canonical durable storage target and one typed reader;
   aliases must be explicitly quarantined, never silently accepted.
3. Coach-writable rows appear in the backend allowlist, mobile mapper, this
   registry, and a behavioral round-trip fixture.
4. The fixture writes through the declared provider path, reloads persisted
   answers, and asserts the typed `coach_profile_path`, including every allowed
   enum value and required prerequisite ordering.
5. Missing defaults never count as known or fresh. A completion marker or
   provenance record must prove user knowledge.
6. Every P0 row has at least one real production consumer or is honestly
   non-live with a blocking ticket.
7. A `scenario_lever` or `derived_output` may not claim `storage_key`,
   `coach_profile_path`, or `write_path`; its future Case `scenario_id` belongs
   outside the durable fact ledger.
8. Rows requiring current law fail closed to `partial+ask` or
   `educational_only` when source, source date, or legal year is absent.

Required red fixtures include `householdType=couple/family/concubine`,
`employmentStatus=unemployed`, `goal=retire/emergency/optimize_taxes/other`, AVS
years written before birth year, explicit cash provenance after reload, and
scenario outputs attempting to overwrite LPP facts.

## Current gate conclusion

`tools/checks/tests/test_g1_p0_ledger_dead_keys.py` now loads this registry,
enforces the closed vocabulary and qualified-reader contract, and carries
negative fixtures for duplicate/dead keys, local/parameter shadows,
named/factory constructors, unsupported classification, and type drift. The
targeted gate is green after recorded RED failures.

Two rows remain deliberately honest rather than falsely green:

- `hasAvsGaps` is P0 `quarantined` under `G1-LDG-06`: its canonical storage
  and write paths remain valid, but no production output reads the declared
  `avsGapStatus`. Financial Fitness consumes the separate certificate-owned
  `AvsGapEvidence.selfCertifiedYears`; that evidence is not a reader for this
  declaration, so `reader_evidence` and `consumers` remain `NONE` until a real
  typed consumer exists.
- `spouseIncomeNetMonthly` is `quarantined` under `G1-BND-02`: the storage key
  is net monthly income, but current reconstruction converts it into
  `conjoint.salaireBrutMensuel` with a fixed factor, so no typed net path or
  consumer proves value preservation.
- `has3a` is P1 `quarantined`: its former anchor was an unqualified model
  adapter read, not an independently qualified production consumer.

G2 remains blocked by these and the other exact matrix/ticket gaps; a green
lexical hard floor does not make the full G1 goal complete.

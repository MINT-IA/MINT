I have all the information needed. Here is the complete audit verdict:

---

NO_UNRESOLVED_CRITICAL_HIGH

---

## JOS-009 Follow-up Audit

**Branch:** `codex/mint-dataquest-transmit-property-clean` | **Date:** 2026-07-04 | **Scope:** frequency isolation fix + prior M1/M2 resolution

---

### Core Contract — All Pass

| Contract | Status | Evidence |
|---|---|---|
| `q_pay_frequency` income-only | ✅ | `budget_setup_screen.dart:161` writes `q_housing_cost_frequency`; no other budget path touches `q_pay_frequency` |
| Budget setup does not overwrite income frequency | ✅ | `budget_setup_screen_test.dart:55` + patrol `answers['q_pay_frequency']=='yearly'` post-save |
| Housing uses `q_housing_cost_frequency` | ✅ | `coach_profile.dart:2469-2471` reads `q_housing_cost_frequency` first, defaults `'monthly'`, no income-frequency reference |
| Legacy `_coach_depenses_loyer` / `_coach_depenses_assurance` hydrate | ✅ | `coach_profile.dart:2466-2467, 2483-2484`; unit test `save_fact_mapping_test.dart:394-405` covers it |
| Dossier housing not divided by 12 due to yearly income | ✅ | `dossier_payload_service.dart:1170-1173` legacy fallback rejects `'yearly'` → `null` → ask, not `/12` |
| Runtime proof device class | ✅ | iPhone 17 Pro (iOS 26.2, UDID `B03E429D-...`), evidence `20260704T200804Z-jos009-budget-frequency-patrol/README.md` |

---

### Prior Mediums — Resolution Status

**M1 (open-banking back-fill) — RESOLVED.** `fromWizardAnswers` at `coach_profile.dart:2466-2467` reads `_coach_depenses_loyer` as a null-coalescing fallback after `q_housing_cost_period_chf`. Existing OB profiles with the legacy key correctly hydrate `depenses.loyer` without any explicit migration. Covered by unit test `legacy open banking fixed charge keys still hydrate depenses` (`save_fact_mapping_test.dart:394-405`).

**M2 (dossier yearly-income /12 housing) — RESOLVED.** The `_monthlyAmountForPeriodFrequency` legacy fallback at `dossier_payload_service.dart:1170-1173` explicitly rejects `'yearly'`/`'annual'`/`'annuel'` as legacy frequency values, returning `null`. When `q_housing_cost_frequency` is absent and income is yearly, the dossier emits `null` for living costs and requests `ask_parent_annual_living_costs` — no silent division. Test `does not use yearly income frequency as housing fallback` (`dossier_payload_service_test.dart:486-521`) covers the case.

**L2 from prior audit (DATA_LEDGER missing `'annual'` token) — RESOLVED.** `DATA_LEDGER.md:152` now documents `yearly`, `annual`, and `annuel` as accepted yearly tokens for income frequency.

---

### Residual Findings

**LOW — L1: Patrol `canPop` branch not E2E covered.** The patrol test routes directly to `/budget/setup` without a prior route on the GoRouter stack, covering only the `router.go('/budget')` fallback. The `router.canPop()` branch (in-app deeplink) is covered only by the widget test (`budget_setup_screen_test.dart`), not by a Patrol-level interaction. Not a blocker; the widget-level coverage is adequate for the branching logic itself.

**LOW — L3: `q_debt_payments_period_chf` still coupled to income frequency.** `dossier_payload_service.dart:1146` uses `periodFrequencyKey: 'q_pay_frequency'` for debt payments — unchanged by this PR. A yearly-income user whose debt payment amount was entered as a monthly figure would have it divided by 12 in the dossier. Pre-existing behavior, not a JOS-009 regression, but now more visible by contrast with the housing fix.

---

### Residual Risks

- Scenario fixtures that set `q_housing_cost_period_chf` without `q_housing_cost_frequency` and have `q_pay_frequency='yearly'` will trigger the `ask_parent_annual_living_costs` next-question rather than computing living costs from the housing entry — a friction path but not a financial error.
- `updateInline()` and `updateFromOpenBanking()` both use `putIfAbsent` for `q_housing_cost_frequency`, meaning an existing stored value is preserved. If a legacy profile has `q_housing_cost_frequency='yearly'` persisted from a manual injection, subsequent inline updates will not correct it. No test currently exercises this edge.

---

### Score: **9 / 10**

Core isolation is correct. Both prior MEDIUMs (M1 open-banking back-fill, M2 dossier /12 division) are resolved with unit-test coverage. Runtime proof is on the accepted iPhone 17 Pro target. Two LOWs remain: canPop E2E gap (L1) and pre-existing debt-payment frequency coupling (L3). Neither is a blocker for merge.

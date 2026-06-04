Post-push audit for the 2026-06-04 CJT commits. Scope: commits
`84a33b736`, `74cb97d36`, `22b420cf5`, and `59bff3e48`, with drift/debt
tracking separated from runtime proof.

# Post-push commit audit — 2026-06-04

## Scope and method

Audited commits:

- `84a33b736` — `fix: preserve money trust budget on restart`
- `74cb97d36` — `docs: refresh cjt proof matrix after money trust fix`
- `22b420cf5` — `docs: close cjt-018 runtime locator gate`
- `59bff3e48` — `fix: remove stale plan mint preview wording`

Inputs checked:

- Local diff inspection with `git show --stat --name-status` and targeted
  source reads.
- Mechanical whitespace checks with `git show --check` per commit.
- Budget/coach preflight from `AGENTS.md`: `docs/data-flow.md`,
  `docs/coach-tool-routing.md`, budget key grep, and `INTERNAL_TOOL_NAMES`.
- Two read-only specialist reviews:
  - `code-reviewer` on source/test reliability.
  - `architect-review` on source-of-truth, facade risk, and design/i18n debt.

## Commit audit table

| Commit | Scope | Audit verdict | Debt / drift tracked | Action |
|---|---|---|---|---|
| `84a33b736` | Budget setup, Coach silent opener, tests, CJT-024 Maestro evidence | No P0 found. The code preserves the typed budget in `BudgetProvider` when the canonical profile disappears after secure persistence failure, and the Coach opener reads stored direct budget only when no material profile supersedes it. | P2: `budget_inputs_v1` fallback needed clearer top-level source-of-truth documentation. P3: three generated `maestro.log` files have blank EOF whitespace under `git show --check`. | `docs/data-flow.md` now documents `budget_inputs_v1` as a degraded local read model with strict precedence. Log whitespace is tracked as evidence hygiene, not runtime behavior. |
| `74cb97d36` | Journey matrix refresh | Docs-only change; no source/test behavior touched. `git show --check 74cb97d36` exited `0`. | None found in this audit. | No change. |
| `22b420cf5` | CJT-018 closure evidence, context guard, guard tests | No source/test behavioral issue found. `OPEN_GATES` contains only `CJT-013` and `CJT-015`, matching current tracker state. `git show --check 22b420cf5` exited `0`. | Scope risk: CJT-018 closure proves simulator locator frames only; it does not close TestFlight or Universal Link proof. | Keep CJT-015 open. |
| `59bff3e48` | `ReportPreviewWidget` title i18n and test | The specific stale `Plan Mint` title was replaced by existing ARB key `reportTitleBilanFlash`. `git show --check 59bff3e48` exited `0`. | P1: `ReportPreviewWidget` appears non-production-wired (`rg` finds only the widget file and its test). P2: if revived, it still has hardcoded French copy and design-system debt (`FilledButton`, `OutlinedButton`, direct `fontSize`). | Do not treat its widget test as runtime journey proof. Decide in the screen-role inventory whether to delete the widget or wire and fully localize/design-pass it. |

## Drift / debt register

| ID | Severity | Type | Evidence | Current handling |
|---|---|---|---|---|
| D-20260604-01 | P1 | Facade / dead-code risk | `rg -n "import .*report_preview_widget|ReportPreviewWidget\\(" apps/mobile/lib apps/mobile/test` returned only `apps/mobile/lib/widgets/report_preview_widget.dart` and `apps/mobile/test/widgets/report_preview_widget_test.dart`. | Removed 2026-06-04 by deleting the dead widget and its test instead of wiring a facade. Runtime proof: `flow_money_trust_chain_budget_mon_argent_rapport_coach` passed on iPhone 17 Pro iOS 26.2; artifacts `../maestro-ci/report-preview-dead-widget-removal-money-trust-20260604T120413/`. |
| D-20260604-02 | P2 | i18n/design debt if revived | `apps/mobile/lib/widgets/report_preview_widget.dart` contained hardcoded French strings and direct Material buttons/styles outside the localized title. | Removed 2026-06-04 with the dead widget; associated design-lint baseline entries were deleted. |
| D-20260604-03 | P2 | Source-of-truth doc drift | `docs/data-flow.md` previously stated `wizard_answers_v2` as sole local source without top-level mention of `budget_inputs_v1`, while code allowed a direct-input fallback. | Clarified in `docs/data-flow.md` in this audit pass. |
| D-20260604-04 | P3 | Evidence hygiene | `git show --check 84a33b736` reports blank EOF lines in three generated CJT-024 `maestro.log` files. | Low-risk follow-up cleanup only; avoid rewriting pushed history. |
| D-20260604-05 | P2 | Legacy naming inventory | `apps/mobile/lib/models/age_band_policy.dart` contains historical `Mise à jour Plan Mint (nouveau canton)`. | Keep in wider screen-role/copy inventory; not active `/rapport` proof. |
| D-20260604-06 | P2 | Release process | Direct staging push was used for a requested staging advance; no PR gate was involved for this branch handoff. | Track as operational debt. Use PR or cited CI gates for subsequent release promotion. |

## Non-regression notes

- Budget keys touched by `84a33b736` are existing canonical keys:
  `q_housing_cost_period_chf`, `q_lamal_premium_monthly_chf`,
  `q_pay_frequency`, and `_coach_depenses_*`.
- `BudgetProvider.refreshFromProfile()` does not persist profile-derived
  inputs into `budget_inputs_v1`; it clears matching profile-derived
  fallback entries.
- `CoachChatScreen` permits stored direct budget only when the profile is
  missing or has no material data.
- `ReportPreviewWidget` should not be used as evidence that the active Rapport
  or Bilan journey is rendered correctly; active journey proof remains the
  `/rapport` Maestro and widget suites listed in CJT-002/CJT-010/CJT-024.

---
description: Non-destructive cleanup checkpoint for the dirty CJT worktree.
status: active-checkpoint
date: 2026-06-04
---

# Worktree Cleanup Checkpoint

This checkpoint freezes the current repo state into reviewable lots before any
further matrix work continues.

It is intentionally non-destructive: do not reset, stash globally, delete
evidence, or reorder history until the lots below have been reviewed and gated.

## Current Git State

Branch:

```text
qa/runtime-navigation-spine-20260602...origin/staging [behind 1]
```

Divergence:

```text
origin/staging...HEAD = 1 left / 0 right
```

Interpretation: `origin/staging` contains one commit not in this branch:

```text
863678e64 chore(testflight): bump staging build number
```

Dirty tracked diff:

```text
48 files changed, 1741 insertions(+), 566 deletions(-)
```

Untracked files are mostly durable CJT evidence folders and new Maestro flows.

## Non-Negotiable Cleanup Rules

- No `git reset --hard`.
- No `git checkout -- <path>` on broad paths.
- No global stash as the main cleanup strategy.
- No deleting Maestro/evidence folders unless their replacement evidence is
  already documented and referenced.
- No closing CJT-015 or CJT-013 from local/simulator proof.
- Stage by matrix row / CJT, not by filesystem convenience.
- For `BUG-TRACKER.md` and `JOURNEY-TRUTH-MATRIX.md`, stage hunks only after
  their matching code/evidence lot has passed its gate.

## Proposed Patchsets

### Lot A — CJT-015 / Row 1 Release Domain and TestFlight Evidence

Purpose: keep release-gate truth coherent around `mint-ai.ch` and build 71.

Likely files:

- `.planning/.../evidence/deeplinks/testflight-certificates-gate-20260602.md`
- `.planning/.../evidence/deeplinks/universal-links-release-gate-20260602.md`
- `.planning/.../evidence/deeplinks/testflight-token-retry-plan-20260604.md`
- `tools/checks/cjt_context_guard.py`
- `tools/checks/tests/test_cjt_context_guard.py`
- `tools/simulator/flows/regression/bug__S004_F006_F007__universal_link_opens_app.yaml`
- matching Row 1 / CJT-015 matrix and bug-tracker hunks

Gate:

```bash
python3 -m pytest tools/checks/tests/test_cjt_context_guard.py -q
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py
```

Status: external release proof still open.

### Lot B — Row 15 / CJT-028 Fact Capture to Data Spine

Purpose: keep Coach `save_fact` persistence and context-packet proof isolated.

Likely files:

- `apps/mobile/lib/models/coach_profile.dart`
- `apps/mobile/test/services/chat/fact_extraction_fallback_test.dart`
- matching Row 15 / CJT-028 matrix and bug-tracker hunks

Gate:

```bash
cd apps/mobile
flutter test test/services/chat/fact_extraction_fallback_test.dart
flutter analyze lib/models/coach_profile.dart test/services/chat/fact_extraction_fallback_test.dart
```

Status: local Flutter persistence proof only; authenticated backend sync still
open.

### Lot C — Row 22 Navigation Roles and Coach Routing

Purpose: keep primary-screen ownership and route registry semantics isolated.

Likely files:

- `apps/mobile/lib/services/navigation/screen_registry.dart`
- `apps/mobile/test/services/navigation/screen_registry_test.dart`
- `apps/mobile/test/services/navigation/route_planner_test.dart`
- `apps/mobile/lib/widgets/coach/chat_drawer_host.dart`
- `apps/mobile/test/services/coach/chat_drawer_summon_test.dart`
- `.planning/.../evidence/coach-navigation/row-22-primary-screen-inventory-20260604.md`
- `.planning/.../evidence/coach-navigation/row-22-primary-screen-visual-crawl-review-20260604.md`
- matching Row 22 / CJT-026 / CJT-027 / budget routing hunks

Gate:

```bash
cd apps/mobile
flutter test test/services/navigation/screen_registry_test.dart test/services/navigation/route_planner_test.dart test/services/coach/chat_drawer_summon_test.dart
flutter analyze lib/services/navigation/screen_registry.dart lib/widgets/coach/chat_drawer_host.dart
cd ../..
./tools/mint-routes check
python3 tools/checks/cjt_context_guard.py
```

Status: Row 22 remains `PARTIAL`.

### Lot D — Row 22 Budget Inclusive Income Copy

Purpose: isolate the salary-only empty-state correction and ARB/l10n churn.

Likely files:

- `apps/mobile/lib/l10n/app_*.arb`
- `apps/mobile/lib/l10n/app_localizations*.dart`
- `apps/mobile/test/screens/budget_screen_smoke_test.dart`
- `.planning/.../evidence/maestro-ci/row-22-budget-income-copy-20260604T144318/`
- matching Row 22 matrix / bug-tracker hunks

Gate:

```bash
cd apps/mobile
flutter gen-l10n
flutter test test/screens/budget_screen_smoke_test.dart
cd ../..
python3 tools/checks/arb_parity.py
```

Status: do not mix generated l10n with unrelated code unless this lot owns it.

### Lot E — Row 22 Profile/Dossier First-Viewport Proof

Purpose: keep the large `/profile/bilan` first-viewport redesign and its
runtime evidence reviewable.

Likely files:

- `apps/mobile/lib/screens/profile/financial_summary_screen.dart`
- `apps/mobile/test/screens/profile/financial_summary_screen_test.dart`
- `tools/simulator/flows/maestro-perfect-set/flow_row22_primary_screen_visual_crawl.yaml`
- `tools/simulator/flows/maestro-perfect-set/flow_row22_profile_dossier_production_profile.yaml`
- `.planning/.../evidence/maestro-ci/row-22-primary-screen-crawl-20260604T141534/`
- `.planning/.../evidence/maestro-ci/row-22-profile-dossier-*`
- matching Row 22 matrix / review hunks

Gate:

```bash
cd apps/mobile
flutter test test/screens/profile/financial_summary_screen_test.dart
flutter analyze lib/screens/profile/financial_summary_screen.dart test/screens/profile/financial_summary_screen_test.dart
cd ../..
python3 tools/checks/maestro_locator_audit.py
```

Runtime note: keep both the stalled visual crawl and the follow-up green
watchdog `0` proofs, because the stalled run explains why Row 22 stays
`PARTIAL`.

### Lot F — Row 23 Design / I18n / Accessibility Guards

Purpose: isolate primary-screen design-system guardrails.

Likely files:

- `apps/mobile/test/i18n/hardcoded_string_audit_test.dart`
- `apps/mobile/test/design/primary_screen_design_contract_test.dart`
- `apps/mobile/test/accessibility/primary_screen_dynamic_type_test.dart`
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart`
- `apps/mobile/lib/models/age_band_policy.dart`
- `apps/mobile/test/screens/s44_phase2_smoke_test.dart`
- `.planning/.../evidence/rapport-design/row-23-primary-screen-dynamic-type-20260604.md`
- matching Row 23 / D-20260604-05 hunks

Gate:

```bash
cd apps/mobile
flutter test test/i18n/hardcoded_string_audit_test.dart test/design/primary_screen_design_contract_test.dart test/accessibility/primary_screen_dynamic_type_test.dart test/screens/s44_phase2_smoke_test.dart
flutter analyze
```

Status: Row 23 remains `PARTIAL` until visual/runtime accessibility proof is
broader.

### Lot G — Row 24 Privacy Runtime and Consent/Log Proof

Purpose: isolate privacy proof and runtime privacy-control flow.

Likely files:

- `apps/mobile/test/widgets/document/third_party_declaration_sheet_test.dart`
- `tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml`
- `.planning/.../evidence/privacy-controls/row-24-privacy-consent-log-scrub-proof-20260604.md`
- `.planning/.../evidence/maestro-ci/row-24-privacy-control-runtime-20260604T182101/`
- matching Row 24 matrix hunks

Gate:

```bash
cd apps/mobile
flutter test test/widgets/document/third_party_declaration_sheet_test.dart
cd ../..
python3 tools/checks/maestro_locator_audit.py
```

Status: Row 24 remains `PARTIAL`; live delete/export and production log audit
remain open.

### Lot H — Row 21 / CJT-029 Daily Return Action Routing

Purpose: isolate the Cap du jour `/explorer` -> `/explore` runtime bug fix.

Likely files:

- `apps/mobile/lib/widgets/aujourdhui/cap_du_jour_banner.dart`
- `apps/mobile/lib/widgets/mint_card_action_bar.dart`
- `apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart`
- `apps/mobile/test/widgets/aujourdhui/cap_du_jour_banner_test.dart`
- `apps/mobile/test/widgets/mint_card_action_bar_test.dart`
- `apps/mobile/test/widgets/mint_card_action_bar_routing_test.dart`
- `apps/mobile/test/widgets/confidence_score_card_actionbar_test.dart`
- `tools/simulator/flows/maestro-perfect-set/flow_row21_daily_return_attention_action.yaml`
- `tools/simulator/flows/regression/bug__S001__cap_du_jour_action_bar_reachable.yaml`
- `.planning/.../evidence/daily-return/row-21-daily-return-attention-action-proof-20260604.md`
- `.planning/.../evidence/maestro-ci/row-21-daily-return-attention-action-20260604T183725/`
- matching Row 21 / CJT-029 hunks

Gate:

```bash
cd apps/mobile
flutter test test/widgets/mint_card_action_bar_test.dart test/widgets/mint_card_action_bar_routing_test.dart test/widgets/aujourdhui/cap_du_jour_banner_test.dart test/widgets/confidence_score_card_actionbar_test.dart
flutter analyze lib/widgets/aujourdhui/cap_du_jour_banner.dart lib/widgets/mint_card_action_bar.dart lib/screens/coach/chat_as_verb_demo_screen.dart
cd ../..
python3 tools/checks/maestro_locator_audit.py
```

Status: Row 21 remains `PARTIAL`; completion/next-priority proof still open.

### Lot I — Row 17 / CJT-030 Compound Simulator Primary Inputs

Purpose: isolate the latest simulator-design correction.

Likely files:

- `apps/mobile/lib/screens/simulator_compound_screen.dart`
- `apps/mobile/test/screens/simulator_screens_smoke_test.dart`
- `.planning/.../evidence/simulator-design/row-17-compound-visible-input-contract-20260604.md`
- matching Row 17 / CJT-030 hunks

Gate:

```bash
cd apps/mobile
flutter test test/screens/simulator_screens_smoke_test.dart
flutter analyze lib/screens/simulator_compound_screen.dart test/screens/simulator_screens_smoke_test.dart
```

Status: Row 17 remains `PARTIAL`; `/simulator/rente-capital` still needs a
dedicated audit.

## Recommended Execution Order

1. Run the global safety gate once on the current dirty tree.
2. Stage and commit Lot A if the release-domain docs/guard are coherent.
3. Stage and commit Lot B.
4. Stage and commit Lot C.
5. Stage and commit Lot D, keeping generated l10n with its ARB source changes.
6. Stage and commit Lot E.
7. Stage and commit Lot F.
8. Stage and commit Lot G.
9. Stage and commit Lot H.
10. Stage and commit Lot I.
11. Stage final shared `BUG-TRACKER.md` / `JOURNEY-TRUTH-MATRIX.md` hunks only
    if any hunk could not be attached cleanly to its own lot.
12. Re-run global safety gate.
13. Only after clean commits: decide whether to merge/rebase the one missing
    `origin/staging` commit `863678e64`.

## Global Safety Gate

Use this before and after cleanup:

```bash
cd apps/mobile
flutter analyze
flutter test test/screens/simulator_screens_smoke_test.dart test/services/navigation/screen_registry_test.dart test/services/navigation/route_planner_test.dart
cd ../..
./tools/mint-routes check
python3 tools/checks/cjt_context_guard.py
python3 tools/checks/maestro_locator_audit.py
python3 tools/checks/arb_parity.py
git diff --check
```

Current known result from this session: these passed, except `git diff --check`
prints existing CRLF warnings for generated l10n files while exiting `0`.

## Risks To Watch

- `BUG-TRACKER.md` and `JOURNEY-TRUTH-MATRIX.md` are shared across almost every
  lot. Use hunk staging or leave them for a final governance commit.
- Generated l10n files have CRLF warnings. Do not “fix” line endings as a side
  effect unless that is a deliberate standalone cleanup.
- The branch is behind `origin/staging` by the TestFlight build-number commit.
  Do not merge/rebase it into the dirty tree before the lots are isolated.
- Maestro evidence includes failed/stalled runs. Keep them when they explain why
  a row remains `PARTIAL`.

## Definition Of Clean

The cleanup is complete only when:

- every dirty file belongs to exactly one lot above, or is explicitly marked as
  pre-existing/user-owned;
- every lot has a test gate and a matrix/bug-tracker status;
- no release gate is over-closed;
- Engram has a summary of the cleanup result;
- the next agent can answer “what changed, why, and how it was proven” without
  reading chat history.

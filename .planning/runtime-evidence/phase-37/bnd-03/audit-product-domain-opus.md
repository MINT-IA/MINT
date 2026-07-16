I have enough evidence. The diff is entirely test-harness and CI-orchestration; I verified the one behavioral coupling (the Dart harness) against the live product code.

## Product/domain verdict: PASS

### Scope of change
Three files, all test/CI infrastructure — no product screens, providers, Swiss constants, or compliance strings are modified:
- `apps/mobile/test/providers/provider_bridge_recompute_test.dart` — wraps `BudgetSetupScreen` in `MaterialApp.router` + `GoRouter`.
- `tools/checks/tests/test_g1_bnd03_budget_runtime_orchestrator.py` — orchestrator harness test.
- `tools/simulator/patrol_bnd03_budget_process_death.sh` — BND-03 process-death orchestrator.

### Verification performed
- **Harness change is real wiring, not a facade.** `budget_setup_screen.dart:244` calls `context.go('/budget')` on save when `!context.canPop()`. Under the old `home: BudgetSetupScreen(...)` harness there was no `GoRouter` in context, so the save CTA would throw. The switch to `MaterialApp.router` with `/budget/setup` + `/budget` routes (`provider_bridge_recompute_test.dart:112-135`) makes the test exercise the true production navigation path. Legitimate.
- **Ledger spine intact.** Save writes through `provider.mergeAnswers(answers)` (`budget_setup_screen.dart:238`) into the single `CoachProfileProvider` source of truth — no duplicated user variables. The BND-03 read contract still asserts cold start derives `BudgetInputs.fromCoachProfile(profile!)` "not stale cache" (orchestrator test lines ~552-560).
- **Orchestrator change raises evidence fidelity.** Production entrypoint is now built from `git archive --format=tar "$sha" -- apps/mobile` extracted into a physical disposable tree, replacing the prior "restore checkout cache + `ditto --norsrc` stage". The exact-SHA source, forbidden-path guard (`.git build .dart_tool ios/Pods …`), unsafe-alias walk, and `production_mobile_tree` rev-parse assertion make the persistence proof match the committed code rather than a possibly-contaminated cache. This is stronger, not weaker, evidence.

### P0
None.

### P1
None. No Swiss threshold, constant, rule, or compliance string is touched; nothing in this diff can drive a user financial decision.

### P2
- **Return-to-scenario leg is set up but not asserted.** The harness adds a `/budget` route with `Key('budget_route_probe')` (`provider_bridge_recompute_test.dart:121-123`), but the only test using `_budgetSetupHarness()` (line 238-270) asserts ledger persistence after save and never asserts `find.byKey(Key('budget_route_probe'))`. The router is present only to keep `context.go('/budget')` from throwing. Adding an explicit assertion that the probe is shown post-save would turn this into a genuine "write-back + return to originating scenario" interaction-model proof. Evidence: no `budget_route_probe` reference outside the definition.
- **Metadata mode string is long/opaque** (`patrol_external_build_xcode_then_exact_archive_physical_production_install`, orchestrator line for `mode=`). Cosmetic; harmless for the artifact consumer.

### Swiss domain review
- **AVS / LPP / 3a / tax / mortgage / succession:** not affected — no constants, thresholds, or logic in scope.
- **Insurance (LAMal):** only touched incidentally through unchanged fixtures (`q_lamal_premium_monthly_chf`, franchise). The setup screen still writes LAMal premium and franchise to the ledger; no rule logic changed. No regression.
- **Compliance boundaries:** no advice, ranking, guarantee, or product-recommendation language added; the diff introduces no user-facing copy at all.

### Mint product logic review
The change strengthens the **ledger → DataQuest → scenario → dossier** spine rather than expanding it. It (a) makes the widget test honor the real go_router hop back into the `/budget` scenario after a DataQuest-style budget input, and (b) makes the BND-03 process-death proof build the production app from the exact committed SHA, so the "budget survives cold start / process death" guarantee is verified against shipped code. Both keep the single-source-of-truth (`CoachProfileProvider.mergeAnswers`) model coherent. No movement away from the spine.

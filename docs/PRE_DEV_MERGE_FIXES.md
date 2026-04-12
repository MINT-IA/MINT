# Pre-dev-merge cleanup — 2026-04-08

Summary of the external-audit-driven sweep on `feature/v2.2-p0a-code-unblockers` before opening the PR to `dev`.

## Fixes landed

| # | Fix | Outcome | Commit(s) |
|---|---|---|---|
| 1 | Regenerate `docs/SHIP_GATE_v2.2.md` (was stale at 17/18 FAIL) | 18/18 PASS at HEAD, SHIP READY (code side) | `docs(ship-gate): regenerate SHIP_GATE_v2.2.md — 18/18 automated gates PASS at HEAD` |
| 2 | Rewrite `.planning/STATE.md` (was "0/15 phases, Phase 1 not started") | Reflects 16-phase reality, 14 code-complete + 2 partial, 6 human gates pending | `docs(state): update STATE.md to reflect v2.2 code-complete reality` |
| 3 | Migrate `SemanticsService.announce` → `sendAnnouncement` | Deprecation warning cleared on `mint_trame_confiance.dart` + `mint_alert_host.dart`; 68/68 trust+alert widget tests green; seam typedef preserved for hermetic tests | `fix(a11y): migrate SemanticsService.announce to non-deprecated sendAnnouncement API` |
| 4 | Tone down "fully shipped" wording in Phase 12 SUMMARY | Reflects code-complete-on-branch vs full ship; other summaries already honest | `docs(summaries): tone down 'fully shipped' wording in Phase 12…` |
| 5 | Patrol `LateInitializationError` investigation + defer | Kept `skip: true` (architectural binding mismatch, not fixable without CI emulators); new investigation doc at `.planning/phases/12-l1.6c-ton-ux-ship-gate/12-PATROL-DEFERRED.md`, both test files cross-reference it | `docs(patrol): document LateInitializationError investigation, defer fix to v2.3` |
| 6 | Working tree cleanup (1 modified + 8 untracked) | Compliance regen committed; 6 design briefs landed; motion audit + milestone archive + 10-02b escalation landed; tree clean | `chore(compliance): regen COMPLIANCE_REGRESSION_v2.2.md…`, `docs(visions): land v2.2 design brief series…`, `docs: land motion/interaction audit + v0.1 milestone context archive + 10-02b escalation note` |

## Deferred (out of scope for this sweep)

- **Patrol integration tests** — `onboarding_patrol_test.dart` + `document_patrol_test.dart` remain `skip: true`. Root cause is the `IntegrationTestWidgetsFlutterBinding` vs widget-test-binding mismatch; `app.main()` throws `LateInitializationError` under widget-test bindings. Correct fix requires CI emulator infra (QA-04 iOS simulator / QA-05 Android emulator). Deferred to v2.3. Full trace in `12-PATROL-DEFERRED.md`.
- **Info-level `prefer_const_constructors` warnings** in `mint_trame_confiance.dart` (5 lines) — unrelated to the deprecation migration, pre-existing, not ship-gating. Left untouched.

## Verification

- `bash tools/ship_gate/run_all_gates_v2_2.sh` → **18/18 PASS, SHIP READY (code side)**
- `git status` → **clean**
- `git log --oneline dev..HEAD | wc -l` → **172 commits ahead of dev**
- Targeted Flutter tests (`test/widgets/trust/` + `test/widgets/alert/`) → **68/68 passing**

## Next step

Orchestrator opens PR `feature/v2.2-p0a-code-unblockers` → `dev`. Merge handled outside this sweep.

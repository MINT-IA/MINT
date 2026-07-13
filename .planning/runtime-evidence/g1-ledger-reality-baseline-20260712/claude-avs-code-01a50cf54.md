$ env CLAUDE_AUDIT_WORKTREE=/tmp/mint-g1-avs-audit-01a50cf54.j2gwQ2/repo CLAUDE_AUDIT_MAX_DIFF_LINES=6000 tools/checks/claude_external_audit.sh code bc2ba0d08
## MINT External Auditor — Report (mode: code)

**Scope:** diff `bc2ba0d08 → HEAD` (AVS couple cap rework, divorce-splitting removal, CoupleOptimizer AVS quarantine, tests + docs).

### What the diff does
- Deletes the legally-unsupportable production paths: the salary/age-derived AVS couple cap in `CoupleOptimizer._analyzeAvsCap` (now `avsCap` is always `null`) and the salary-duration divorce-splitting proxy in `computeMonthlyRente`.
- Adds `AvsCalculator.computeCouplePensions` — a fail-closed, person-owned, scale/status/entitlement-aware LAVS art. 35 + RAVS 53bis/53ter calculator.
- Rewrites the affected tests; adds `avs_couple_test_fixtures.dart`, `avs_couple_legal_contract_test.dart`, and two contract docs.

### Verification performed
- **No dangling references / compile safety:** No production `lib` code calls the removed `computeCouple`, passes `isDivorced/exSpouseAnnualSalary/marriageYears`, or reads `AvsCoupleCapResult`/`.avsCap` fields (`capApplied`, `monthlyReduction`, `totalAfterCap`). Confirmed no test outside the diff references the removed API or record fields (`.total/.user/.conjoint` hits are all unrelated types). Suite should compile.
- **Fail-closed behavior is real:** `CoupleOptimizer.optimize` no longer emits any AVS number; every updated test asserts `result.avsCap` is `null` (`couple_optimizer_test.dart:74,169,184,200,209`, `phase5_production_bugs_test.dart:179,202,226`, `golden_couple_integrated_test.dart:770,786`).
- **New algorithm matches its cited spec/tests:** ceil-based weighted integer scale `(sLow + 2·sHigh)/3` → `.ceil()` (`avs_calculator.dart`), pending state for scale<44 without official table, `null` capped amounts while pending, proportional reduction only when `payableCap` known, art. 53ter multiplier (deferred→1, else max percentage). Consistent with `avs_couple_legal_contract_test.dart` cases 6–33.
- **Divorce-splitting removal is not a production regression:** no production caller ever passed `isDivorced=true`; the proxy was inert in production and is documented as never an official calculation.

### Findings

**P0 — none introduced.**

**P1 — none introduced.**

**P2 / observations**
1. Stale doc comment: `couple_optimizer.dart:125` still says "Run all 4 couple analyses" but `optimize()` now returns 3 (`lppBuybackOrder`, `pillar3aOrder`, `marriagePenalty`).
2. Facade-without-wiring (accepted, non-blocking): `computeCouplePensions` (~300 LOC) has **zero production consumers** — only tests/fixtures reference it. This is explicitly a staged NO-GO for activation per `AVS_COUPLE_LEGAL_CONTRACT.md §0`, it fails closed, and no UI claims couple AVS works, so it is not a deceptive facade. Should be flagged so a future reviewer doesn't mistake it for a shipped feature.
3. Pre-existing, **not modified by this diff** (informational): the 13th-pension inflation remains live in production — `retirement_projection_service.dart:661,747` (`annualRente(...)/12` inflates the ordinary monthly rente by 13/12) and `avs_gap_widget.dart:63` (`annualRente(_renteLoss)*20`). The newly added `AVS_THIRTEENTH_PENSION_CONTRACT.md` documents these as G1-AVS-02 NO-GO but the diff does not fix them. To prove: `rg -n 'annualRente' apps/mobile/lib`.

### Verdict

**PASS**

Rationale: within the audited scope, the change is a clean, fail-closed refactor that removes two legally-wrong production behaviors, adds tested legally-grounded logic that is deliberately not activated, introduces no P0/P1 correctness/privacy/routing regressions, and leaves the test suite compilable and self-consistent. The remaining items are P2 (a stale comment, an intentional un-wired library, and a pre-existing 13th-pension bug this diff neither introduces nor is expected to fix). This PASS applies to the diff only and does not lift the standing G1 couple-AVS / 13th-pension NO-GO for feature activation.

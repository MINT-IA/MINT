# Claude external audit — AVS typed cashflow + UTC + migration — product-domain — `06115ed38`

## Immutable scope

- Global G1 status: **8.2/10 — NO-GO**. This report does not authorize G2/G3.
- Exact range: `f029e0514...06115ed38` (`f029e0514214bc071fd0344a987b9f9cc5c06498` → `06115ed388c4a1b30abf24314efc83893fb75eca`).
- Command (first pass only; launched after the code pass completed):

```sh
env CLAUDE_AUDIT_WORKTREE=/tmp/mint-g1-avs-audit-06115ed38.MUIdLm/repo CLAUDE_AUDIT_MAX_DIFF_LINES=11000 CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh product-domain f029e0514
```

- Wrapper: `tools/checks/claude_external_audit.sh` exclusively; no raw Claude command.
- Model / effort: **Opus / high**.
- Started UTC: `2026-07-13T16:23:20Z`; ended UTC: `2026-07-13T16:26:56Z`.
- Exit code: **0**; stdout: 29 lines; stderr: 0 lines.

## Clean detached-clone proof

- Detached clone: `/tmp/mint-g1-avs-audit-06115ed38.MUIdLm/repo`
- Base: `f029e0514214bc071fd0344a987b9f9cc5c06498`
- HEAD: `06115ed388c4a1b30abf24314efc83893fb75eca`
- `git status --short --branch`: `## HEAD (no branch)` before and after each audit
- `git diff --no-ext-diff --unified=80 f029e0514...HEAD | wc -l`: `10226`
- Diff stat: `32 files changed, 3001 insertions(+), 269 deletions(-)`
- The four pre-existing dirty files in the primary checkout were therefore absent from both prompts.

## External verdict and MINT triage

- Claude product/domain verdict: **PASS** for the dormant, fail-closed mobile foundation.
- **P0: none.**
- **P1 raised — legal-source labels unverified by the audit prompt.** Claude flagged `apps/mobile/lib/services/financial_core/avs_thirteenth_pension_calculator.dart:285-290` and `apps/mobile/lib/constants/social_insurance.dart:220-223`. Triage: the checked-in contract does provide primary links for LAVS art. 34ter and OFAS C 13 RV at `docs/codex/AVS_THIRTEENTH_PENSION_CONTRACT.md:483-496`, so the deleted legacy `art. 34 nouveau` label is not contrary evidence. However, the exact `RAVS art. 52ater-52aquinquies` range is not mapped in that source table. Keep a source-evidence P1 before any UI/PDF exposure; this is not proof that the legal rule itself is wrong.
- **P2 confirmed — married/registered two-AI state is semantically mislabeled.** `avs_calculator.dart:350-400` withholds the household value and asks for `aiCoupleCapProvider.laiArticle37Paragraph1bis`, but returns `notApplicable` through `nonQualifyingCapState`; the correct degraded state is `pending`. No current UI consumer, so no wrong amount reaches users.
- **P2 confirmed — supplement is not separately surfaced.** The external audit calls the omission conservative; local inspection confirms the activation path fuses the supplement into comparison bars instead of rendering a December line.
- **P2 confirmed — registry sub-centime throws** at the legacy `double` → exact-money boundary.
- The product/domain PASS does not override the separate code-audit P1. Under the MINT hard floor, the combined disposition remains NO-GO.
- No audit carousel was started.

## Three previously known P2s

| Known P2 | Confirmation at `06115ed38` | Evidence / disposition |
|---|---|---|
| Generic independent-scenario owner | **CONFIRMED OPEN** | `apps/mobile/lib/services/independants_service.dart:635-646` hard-codes `ownerId: 'independant-self-scenario'` rather than the real person-owned ledger identity. Dormant behind the local-only flag, but must be fixed before activation. |
| Supplement fused without a dedicated renderer | **CONFIRMED OPEN** | `independants_service.dart:649-663` folds `eligibleOldAgeCashflowWithSupplementChf` into both projection totals. `lpp_volontaire_screen.dart:445-501` renders only those aggregate bars and never reads `avsThirteenthScenario`; `rg` finds no renderer outside the service/calculator. |
| Legal-zero precedence versus missing monthly sources | **NOT CONFIRMED AS OPEN — CLOSED IN THIS RANGE** | Production resolves an official December `notEntitled` zero before the missing-history failure at `avs_thirteenth_pension_calculator.dart:665-690`. Direct tests at `avs_thirteenth_pension_calculator_test.dart:1284-1316` prove both official not-entitled and pre-2026 legal zero beat unknown prior months while keeping the annual paid base null. |

## Captured stdout (verbatim)

~~~text
I've verified the migration against the live repo. Findings below.

## Product/domain verdict: PASS

The change retires the flat `× 13` annualization of AVS and replaces it with an owner-scoped, evidence-tiered December-supplement calculator that is fail-closed and clearly separates *certified* from *illustrative*. My grep confirms the migration is complete (no dangling references to the removed `AvsCalculator.annualRente`, `avs13emeRente*`, `avsMaxAnnualRenteForYear`; the remaining `annualRente:` hits are the unrelated LPP parameter), and the new calculator plus its scenario field are dormant (no UI/PDF consumer). Net effect on shipping surfaces is *more* correct, not less.

---

### P0 — none
No confident-wrong law reaching users, no privacy exposure (scenario `ownerId`s are literals, no PII), no harmful decision driver. Every behavioral change is conservative/fail-closed and the disclosure strings are honest.

### P1
1. **Unverified legal citations in the new calculator.** `avs_thirteenth_pension_calculator.dart:284-290` hard-codes `LAVS art. 34ter`, `RAVS art. 52ater-52aquinquies`, `OFAS C 13 RV version 01.01.2026` as `_legalSources`, and `social_insurance.dart:223` cites `LAVS art. 34ter`. None is sourced in the diff, and the article numbers do not match the prior code's own citation (`LAVS art. 34 nouveau`, `Cst art. 112 al. 4bis`). Per audit convention, unsupported current-law references are P1 → treat as **unverified**. Mitigant that keeps this from blocking the verdict: these strings are dormant — `pdf_service.dart:1007/1161` renders a *different* `legalSources` sourced from `coach_chat_screen.dart:1574`, and the calculator's `legalSources`/results are not read by any screen. **Required before surfacing:** confirm the exact enacted LAVS/RAVS article numbers and the OFAS directive version, or downgrade the labels to "source to confirm."

### P2
1. **Married two-AI couple cap mislabeled `notApplicable`.** `avs_calculator.dart` new `bothDisability` branch returns `AvsCoupleCapState.notApplicable` + `missing: ['aiCoupleCapProvider.laiArticle37Paragraph1bis']` for two disability pensions when married/registered. LAVS art. 35 al. 1 *does* plafonner two AI pensions, so `notApplicable` is semantically wrong — though the household total is withheld (`null`), so no incorrect number surfaces, and there is no UI consumer (`CoupleOptimizer.optimize` always returns `avsCap: null`). Consider `pending` + provider-required rather than `notApplicable`.
2. **Self-employed annual projection now omits a real entitlement.** `independants_service.dart:649` defaults `renteAvsMax` to the 12-month `avsRenteMaxAnnuelle` (30'240) with the 13th behind the off-by-default flag. The relative AVS-only vs AVS+LPP comparison (the screen's purpose) is unaffected since both legs use the same base, and the gap-widget/localization strings now explicitly disclose "the separate December supplement is not included" — so this is disclosed conservatism, not a silent error. Consider surfacing the 13th as a clearly-labeled separate December line so lucidity isn't lost.
3. **`ChfAmount.fromLegacyDouble` can throw on a sub-centime reg override.** `independants_service.dart:637-639` feeds `reg('avs.max_monthly_pension')` into `fromLegacyDouble`, which `throwsArgumentError` for >2-decimal values. Default (2520.0) is safe and the flag is off, but a backend registry override with sub-centime precision would throw when the flag is enabled. Low risk; guard or round before conversion.

---

### Swiss domain review
- **AVS (1er pilier):** Core of the change. 13th pension modeled correctly: supplement = 1/12 of the annual sum of *old-age* pensions actually paid (test 01: full year at 2'520 → 2'520 supplement; test 03: half-year → 900). Correctly **excludes** AI/survivor/orphan/child/complementary/AVS21-transition cashflows (tests 14-16, 23-24) and requires 1-December old-age entitlement + alive-on-1-Dec (tests 10, 12-13). Uses actual paid (post-cap) monthly pensions as the determining base, so no double-count of the couple plafonnement. Removing `× 13` from the transition-phase *monthly* chart source (`retirement_projection_service.dart`) is a genuine fix — the old code inflated each monthly line by 13/12 (~+8.3%).
- **LPP / 3a / tax / mortgage / insurance:** Not materially affected. LPP `annualRente:` parameter is untouched; the `couple_optimizer` comment (4→3 analyses) is cosmetic (`avsCap` already always null).
- **Succession / disability / family status:** Disability handling touched only in the dormant couple-cap contract (P2 #1). No inheritance/donation logic changed.
- **Compliance language:** No banned promise terms introduced; localization strings ("supplement is not included / séparé") avoid advice and correctly state uncertainty.

### Mint product logic review
This is a meaningful step **toward** the ledger → evidence → scenario → dossier spine. The new calculator is built around *owner-scoped monthly evidence* with explicit tiers (`avsFundLedger` → `avsFundDecision` → `userDeclaredFromDocument` → `scenario`) and a readiness enum that keeps `certified` reserved for official-fund evidence while user/scenario data stays `illustrativeOnly`/`declaredComplete` — exactly the known/estimated/certified distinction the product model wants. The kill switch is correctly **excluded from `applyFromMap`** (`feature_flags.dart`), so a backend flag cannot upgrade an educational scenario into a fund entitlement — a genuine anti-facade guarantee. The 1'460-line contract test suite and the six-locale ARB guard (`avs_gap_widget_test.dart`) lock the behavior. The remaining gap is that the December supplement is not yet surfaced anywhere (no dossier/PDF line), so the *user-value* delivery is deferred; that is acceptable for a dormant, correctly-fenced foundation, but the P1 citation verification must land before this is ever rendered.
~~~

## Captured stderr (verbatim)

~~~text
~~~

## Gate disposition

**NO-GO at the combined gate.** Product/domain sees the dormant foundation as a net improvement, but source mapping must be completed before surfacing, the code audit found a live backend contradiction, and two activation P2s remain. G1 stays **8.2/10 NO-GO**.

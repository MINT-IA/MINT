I've verified the load-bearing claims. Key findings from the live code:

- `ExpatService` is no longer referenced by `frontalier_screen.dart` (only by the separate `/expatriation` screen), so no dead import remains.
- The removed `isCrossBorder` withholding path in `NetIncomeBreakdown.compute` was consumed **only** via `cap_sequence_engine.dart:645`, which is now guarded to fail closed. The other ~19 `compute` callers already used ordinary taxation, so no new mis-taxation is introduced anywhere.
- The readiness-based `isCrossBorder` getter has exactly one live consumer (`cap_sequence_engine`, guarded). CAP late-LPP nudges still key off the permit-based `archetype`, unaffected.
- The freshness boundary math checks out: `annualNeedsRefresh` crosses 0.60 at ~25.71 months, i.e. known at 782 days / stale at 783 days, matching the spec.
- The accord-1983 canton set `{BE,SO,BS,BL,VD,VS,NE,JU}` is correct; Geneva is correctly excluded and routed to the CDI-1966 candidate.

---

Product/domain verdict: PASS

This change replaces a Swiss-domain-incoherent frontalier calculator with a fail-closed, calculation-free jurisdiction-collection flow. It is coherent with Swiss cross-border reality and the MINT lucidity model, and it materially reduces legal/compliance risk.

## P0 — none

## P1 — none blocking

## P2 (polish / follow-up)

- **P2-1 — Frontalier net estimate falls through to ordinary taxation.** `apps/mobile/lib/models/coach_profile.dart:3243` makes `isCrossBorder` true only when the three canonical facts are known+fresh. A real permit-G user who has not yet filled `/segments/frontalier` therefore reads `isCrossBorder == false`, so `cap_sequence_engine.dart:645` does *not* fail closed and estimates net budget margin via ordinary Swiss taxation (`NetIncomeBreakdown.compute`). This over-taxes a source-taxed frontalier, so the estimate is directionally conservative (understates net → understates free margin) and only applies when `monthlyNetIncomeDeclared` is absent. Not harmful (fails safe, labelled estimate), but the number is not accurate for frontaliers. Reproduction: `cap_sequence_engine_test.dart` `permit G without jurisdiction cannot change the ordinary margin` intentionally locks this behaviour. Recommend surfacing an "estimation ordinaire — à confirmer" label or extending the fail-closed guard to `hasCrossBorderProductContext` when declared net is missing.

- **P2-2 — No dossier/PDF export in this slice.** `swiss-domain-verdict.md` §11 specifies a specialist dossier (facts, `legalYear`, instrument, open questions, disclaimer). The screen renders the specialist-questions card (`frontier_specialist_questions_card`) but there is no export. Acceptable for the slice (verdict marks it as target), but the "specialist-ready handoff" is currently read-only on screen, not a transferable artifact.

- **P2-3 — Runtime evidence self-declared pending.** `DATA_LEDGER.md §4.0B`, `WIRING_GRAPH.mmd`, and `swiss-domain-verdict.md §13` all correctly state FRONT-01 is code-GREEN at `733571002` with exact-SHA Patrol/Maestro and wrapper audits still pending. The Patrol test (`g1_front01_..._patrol_test.dart`) is gated behind `MINT_PATROL_CLI` and skips otherwise, so widget tests are the current proof floor. This is honestly documented, not a facade-without-wiring — but the ticket is not promoted and G1 remains NO-GO by the diff's own account.

## Swiss domain review

- **Tax (fiscal):** Correctly removes flat cantonal `sourceTaxRates`, the fabricated withholding table, and the ranked CH/FR charge comparison. Geneva → CDI 1966 art. 17 candidate; the eight accord-1983 cantons → 1983 candidate; both labelled "candidate," never a personal fiscal conclusion. No barème A/B/C/H, no rate, no amount is emitted. Coherent.
- **90-day rule:** The legally-wrong universal 90-day telework gauge is deleted. The Patrol/widget tests assert absence of "90 jours" and any `CHF/EUR/Fr.` amount. This was a genuine P0-class métier error in the prior screen; its removal is the core value of the change.
- **Social insurance (AVS/A1):** Correctly split from the fiscal card (`frontier_social_insurance_card`) with its own uncertainty and A1 handoff question — respects the OFAS accord-cadre independence from tax. No affiliation is concluded.
- **LPP / 3a:** `canContribute3a` no longer returns true for cross-border with income (old FIX-102 removed); permit G / complete jurisdiction evidence does not fabricate 3a eligibility (`frontier_model_quarantine_test.dart` proves this). Correct — frontalier 3a eligibility depends on quasi-resident/TOU facts not collected here.
- **Inheritance / mortgage / disability / pension:** Not touched by this flow; correctly out of scope.
- **Cantonal/legal-year sensitivity:** Constants are jurisdiction *codes* and instrument *names* only — no current-law thresholds are asserted, so no stale-constant risk. `legalYear`-scoped rule selection is documented as future work in the verdict, appropriately deferred rather than faked.

## Mint product logic review

Strong move toward the ledger → DataQuest → scenario → dossier spine:

- **One source of truth / no duplicated variables:** The three facts (`residenceCountry`, `workCountry`, `workCanton`) are typed nullable fields on `CoachProfile`, written only via `CoachProfileProvider.mergeAnswers` with `{source, updatedAt, sourceDate}` provenance and `userProvidedFields` markers. The screen reads `context.watch<CoachProfileProvider>().profile` — no `extra`, no screen-local state. `frontier_jurisdiction_persistence_test.dart` proves atomic persist + cold-rebuild + explicit clearing.
- **Progressive collection / no re-ask:** Conditional requirement (canton only when `workCountry == CH`), non-CH work atomically clears the canton, stale canton shows the prior value with one-gesture reconfirmation — no blank re-ask.
- **Known / missing / estimated / stale / specialist distinction:** Five explicit states with distinct widget keys, each fail-closed (`frontierJurisdictionAt` returns `missing`/`stale` with hidden conclusions).
- **Compliance boundaries:** Educational disclaimer, "candidate" framing, no ranking/guarantee/product recommendation, specialist-handoff card. Clean.
- **Interaction model:** Missing → coach CTA; domestic → explicit `/fiscal` CTA; back via `safePop`. Write-back to ledger verified.

The remaining spine gap is the dossier artifact (P2-2) and the frontalier-specific net estimate (P2-1); neither blocks the product/domain integrity of this change.

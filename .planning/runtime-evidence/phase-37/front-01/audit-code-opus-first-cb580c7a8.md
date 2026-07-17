I have completed the audit. Let me summarize my findings.

## MINT External Audit — G1-FRONT-01 (Frontier Jurisdiction)

**Audit mode:** code · **Base:** `757a5f3` → HEAD (branch `codex/mint-product-usability-plan-20260712`)

### What was verified against checked-in code (source of truth)

- **Routing is wired, not a facade.** `/segments/frontalier` → `FrontalierScreen` (`app.dart:1403-1405`); the screen genuinely reads `context.watch<CoachProfileProvider>().profile` and writes via `mergeAnswers`. Reconfirm/collector CTAs perform real provider writes; missing/domestic CTAs route to live `/coach/chat` and `/fiscal`.
- **Readiness gate rewired and consistent.** `gateFrontalier`/`gateFrontalierAt` now derive from `frontierJurisdictionAt`; `_frontier` entry's `requiredFields` updated to `residenceCountry/workCountry`. Verified by passing `readiness_gate_custom_gates_test`.
- **Legacy calculator island fully removed.** `ExpatService`, `calculateSourceTax`, `simulate90DayRule`, `compareSocialCharges`, and the invented `GE`/`7000`/`180`/`France` defaults are gone from `frontalier_screen.dart`. `ExpatService` remains legitimately used only by the separate `/expatriation` screen.
- **Cross-border tax approximation removed.** `NetIncomeBreakdown.compute` no longer has the flat withholding path; `rg -n "isCrossBorder:"` returns zero dangling callers; `isCrossBorder` now fails closed on complete canonical evidence only. `cap_engine`'s late-LPP logic still keys on `archetype`, so no unintended behavior loss.
- **No dangling references / i18n parity.** All 22 removed `frontalier*` ARB keys have zero production references; every new key is implemented across abstract + 6 locales. `flutter analyze` on all changed files and new tests: **No issues found**.
- **Correctness of the domain contract holds.** Freshness boundary (known @782d / stale @783d), FR/CH/GE→CDI 1966 art. 17 candidate, the exact 8-canton 1983 set (`{BE,SO,BS,BL,VD,VS,NE,JU}`, Geneva correctly excluded), fail-closed provenance (`userInput`/`certificate` + non-future `updatedAt` + `sourceDate` slot + provided-field marker), and atomic canton-clear on non-CH work country all match the swiss-domain verdict.
- **Tests pass, end-to-end.** Ran the full affected surface: `frontier_canonical_fields`, `frontier_model_quarantine`, `frontier_jurisdiction_persistence` (incl. cold-rebuild + invalid-code rejection), `frontier_legal_output_quarantine`, `frontalier_ledger_quarantine`, `cap_sequence_engine`, `readiness_gate_custom_gates`, `life_event_screens_additional_smoke`, plus `coach_profile` roundtrip/provenance/provider suites — **all green**.
- **Privacy/compliance.** The three facts are mobile-only (not in the 36-key `save_fact` allowlist), stored with local field-centric provenance, stripped from backend sync; no new PII egress. Removing the unfounded fiscal/social calculators reduces compliance risk.

### Findings

**P0:** none · **P1:** none

**P2 (non-blocking):**
- `gateFrontalier` returns `blocked(['employmentStatus'])` for a *ready domestic* profile — the missing-field label is semantically misleading (the user isn't missing employment status), though the routing-away behavior is intended and tested (`readiness_gate_custom_gates_test.dart`).
- Work-canton dropdown iterates `SwissCantonCode.supportedValues` (a `Set`), so order is insertion order (AG, AI, AR…), not display-sorted — minor UX only.

### Scope honesty
The diff and docs consistently label this **code-GREEN, promotion pending**: exact-SHA Patrol/Maestro runtime + both wrapper audits are explicitly outstanding, and no doc claims G1 closure or G2/G3 authorization. This matches reality — the tracked Patrol harness (`patrol_front01_...sh`) and integration test exist but produce no committed runtime evidence, exactly as stated.

## Verdict: PASS

The change is correct, tested, analyzer-clean, properly wired end-to-end, and privacy-improving, with no facade-without-wiring risk. Remaining gaps (exact-SHA runtime proof) are accurately disclosed and out of scope for code-level correctness.

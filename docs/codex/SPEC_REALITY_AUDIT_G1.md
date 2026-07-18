# G1 Spec Reality Audit

Audit date: 2026-07-07
Code baseline: `095eeaa32` on `claude/mint-swiss-coach-eu33i7`
Scope: the five `docs/codex` specs challenged against live code before product coding.

## Verdict

The five specs are the right architecture direction for Mint, but several claims were product targets, not live code. G1 corrects that drift and makes the corrected reality executable.

## Main Gaps

- `WIRING_GRAPH` I-1 is false: `/scan/review`, `/scan/impact`, `/rapport`, and `/confidence` still carry domain objects or maps through `state.extra`.
- I-2 is partial: scan routes still fall into `Document non disponible`; `/rapport` has persisted fallback but no timeout/error state.
- I-3 is false as written: `save_fact` is not the only sanctioned profile write path.
- I-4 is verified debt: Budget, Document, Household, FinancialPlan, and Timeline remain provider islands.
- I-5 is partial: legacy `ProfileProvider` still has 5 live consumers.
- Data Ledger: 18 backend-writable keys are ineffective locally, 11 unmapped plus 7 mapped to wizard keys that `CoachProfile.fromWizardAnswers` does not read.
- `DataQuest`/`Case` does not exist in code yet; biography/freshness primitives do.
- Maestro setup is partial: only F-2 is checked in, iOS has the `mint` URL scheme, Android lacks the intent-filter.

## Next Mechanical Correction

Start with ledger parity. Until backend facts reliably land in `CoachProfile`, Data Quest, Maestro, and simulator UX will all produce misleading confidence.

## Live Delta — LPP regulation authority (2026-07-18, HEAD `6066f1c94786aa1bc4697c29b4a670b7cea3dca4`)

The 2026-07-07 audit remains the historical baseline. This focused matrix
reconciles the G1 PROV-02/RET-REF regulation slice against live production code
and tests; it does not promote the ticket or close G1.

| Boundary | Live evidence | Current verdict |
|---|---|---|
| transport shape | `DocumentType.lppPlan`/`VaultDocumentType.lppPlan`, exact zero-fact parser and separate backend authenticated-multipart contract tests (`198e1b53e`) | CODE-GREEN |
| volatile authority | strict empty `ExtractionResult` plus one snapshotless `LppRegulationAcquisitionCandidate` carrying only the optional previous reference id; only `scanSessionId` crosses navigation (`df807024d`) | CODE-GREEN |
| mobile acquisition | three local flags ANDed; regulation-only journey allowed; PDF-only `withData=false`; optional previous-reference boundary revalidated before/after picker and response; direct `DocumentService` call (`df807024d`) | CODE-GREEN |
| backend privacy | current bytes classified before caches; exact plan returns processing-only UUID and zero facts; no personal extractor, `DocumentModel`, GET row, RAG, raw preview or response cache (`b30e3c109`) | CODE-GREEN; backend wrapper lenses P0/P1=0 |
| kind precedence | explicit certificate title or two structured personal `label: value` facts outrank a regulation mention (`ba0f331a0`) | CODE-GREEN |
| review writer | dedicated source-date/legal-year plus required declared `fundRelationship` (`currentFund`, `uncertain`, `formerOrOther`); exact `accept -> record`; record-only identical-receipt retry; discard session then `/retraite`; no impact/Biography/generic sync (`df807024d`, hardened `40e24f608`) | CODE-GREEN |
| durable authority + consumer | schema-2 root-level `selfRegulationReference`, regulation-only cold hydration, snapshotless raw-free document reference, declared/non-verified relationship and card/local sheet in all loaded Dashboard branches with privacy boundary plus six complete specialist questions (`df807024d`, `40e24f608`) | CODE-GREEN |
| exact-SHA mobile runtime | one Patrol native suite passes 2/2 at `6066f1c94786aa1bc4697c29b4a670b7cea3dca4`: production-shaped synthetic PDF/zero-fact writer -> distinct-PID native relaunch -> regulation-only cold Dashboard reader; later numeric add and replacement both preserve the reference; `private_fixture_used=false` | **PASS** |
| default-off runtime | physical production export/build/sign/install, Maestro before/after with all three flags false, and exact canonical state/container-identity preservation pass | **PASS** |
| final independent review | bounded Opus-high code/product-domain source audit at the exact SHA plus the earlier production/copy matrix | **PASS, P0/P1=0** |
| sanitized evidence | minimized proof tracked at `.planning/runtime-evidence/phase-37/ret-ref-01/lpp-regulation-runtime-proof-6066f1c94/`; full runtime archive `.planning/runtime-evidence/phase-37/ret-ref-01/lpp-autonomous-runtime-6066f1c94786a-20260718T101106Z/` has 2/2 and 22/22 logs, while the adjacent `lpp-autonomous-runtime-harness-6066f1c94/` has aggregate P0/P1=0. The two complete archives remain local excluded provenance and are not claimed as tracked | **PASS** |
| activation | three local flags remain false and outside remote hydration | **NO-GO** |

Therefore the former acquisition facade, snapshot coupling and runtime gaps are
closed for this bounded technical atom. `fundRelationship` is a user declaration,
not objective caisse verification, and the production flags remain false.
Visible recovery for legacy/mismatched authority, PDF/dossier caveat parity,
activation and the other RET-REF obligations remain open; the ticket stays
`ticket_only`, G1 remains open and G2/G3 remain forbidden.

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

## Live Delta — LPP regulation authority and recovery (2026-07-18, HEAD `ce5a020503c9e1733a81fa01b8dc6dd79b7c01d1`)

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
| durable authority + recovery marker | strict schema-3 root-level `selfRegulationReference` XOR tuple-free `selfRegulationRecoveryReason=legacyMissingFundRelationship`; schema-1 discards the valid nested tuple and leaves only the reason, schema 2 rewrites with null reason, malformed/null/extra and reason+reference fail closed; cold save precedes publication and only durable explicit accept clears the marker | CODE-GREEN |
| opaque BND resolution | `LppRegulationReferenceResolution` returns only `unavailable`, `resolved`, `missingDocumentReference` or `mismatchedDocumentReference`; exact current evidence wins, no tuple is exposed, and idle/loading/failed hydration remains hidden | CODE-GREEN |
| visible recovery + route | exact renders known education; legacy marker, ready missing BND and ready mismatch render state-specific six-language non-inference copy in one recovery container and reuse `/scan?type=lppPlan`; no stale id/year/relationship, fact, handoff, advice or new store/route | CODE-GREEN |
| autonomous exact-SHA runtime | one Patrol native suite passes 2/2 at `6066f1c94786aa1bc4697c29b4a670b7cea3dca4`: production-shaped synthetic PDF/zero-fact writer -> distinct-PID native relaunch -> regulation-only cold Dashboard reader; later numeric add and replacement both preserve the reference; `private_fixture_used=false` | **PASS** |
| recovery exact-SHA runtime | at `7cb5ea4c64e0a59d4e2f38f8f67eff7c924bd32a`, the same distinct-PID 2/2 suite starts resolved, empties BND, freshly classifies `missingDocumentReference`, proves known/handoff absence plus exact recovery body/CTA and emitted scan URI, then restores/reloads/compares BND before numeric continuation | **PASS, bounded to missing BND** |
| dossier/PDF exact-SHA runtime | at `274736a50bca659579fe26f68ae4e600469e3a9a`, the reader joins production bootstrap, opens the real `MintApp` `/rapport` route, proves the resolved allowlisted handoff, builds production report bytes, suppresses the dossier for missing/mismatch/legacy recovery, then restores root and BND; native suite 2/2 and host real-byte text contract 3/3 | **PASS, bounded; no OS share/viewer claim** |
| assertion trace | XCTest exposes the 2/2 aggregate, not internal Flutter assertions; UI claims are grounded jointly by the tracked exact-SHA reader and passing native suite, never presented as an XCTest assertion transcript | **PASS, bounded** |
| default-off runtime | physical production export/build/sign/install, Maestro 1/1 before and 1/1 after with all three flags false, exact canonical state/container preservation, cleanup/privacy and 22/22 retained outputs pass | **PASS** |
| final independent review | dossier code PASS; its product P1 for the missing PDF is remediated by PDF code/product PASS; bootstrap code/product PASS; current P0/P1=0. The combined runtime wrapper refused 2579 lines against its 2500-line budget and is not relabelled PASS; runtime truth comes from executable exact-SHA gates | **PASS, honestly bounded** |
| sanitized evidence | autonomous and recovery proofs remain tracked; dossier/PDF proof is `phase-37/ret-ref-01/lpp-regulation-dossier-pdf-runtime-proof-274736a50/`, with only allowlisted summaries and verified checksums | **PASS** |
| activation | three local flags remain false and outside remote hydration | **NO-GO** |

Therefore the former acquisition facade, snapshot coupling, process-death and
visible legacy/missing/mismatch recovery gaps are closed for these bounded
technical atoms. `fundRelationship` remains a user declaration, not objective
caisse verification, and production flags remain false. PDF/dossier caveat parity is closed
at exact pushed SHA `274736a50bca659579fe26f68ae4e600469e3a9a` with minimized
proof `phase-37/ret-ref-01/lpp-regulation-dossier-pdf-runtime-proof-274736a50/`.
Activation and the other RET-REF obligations remain open; the ticket
stays `ticket_only`, G1 remains open at 8.2/10 and G2/G3 remain forbidden.

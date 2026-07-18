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

## Live Delta — LPP regulation authority (2026-07-18, HEAD `deb199c7f`)

The 2026-07-07 audit remains the historical baseline. This focused matrix
reconciles the G1 PROV-02/RET-REF regulation slice against live production code
and tests; it does not promote the ticket or close G1.

| Boundary | Live evidence | Current verdict |
|---|---|---|
| transport shape | `DocumentType.lppPlan`/`VaultDocumentType.lppPlan`, exact zero-fact parser and separate backend authenticated-multipart contract tests (`198e1b53e`) | CODE-GREEN |
| volatile authority | strict empty `ExtractionResult` plus one `LppRegulationAcquisitionCandidate`; only `scanSessionId` crosses navigation (`8febd214a`) | CODE-GREEN |
| mobile acquisition | three local flags ANDed; current non-empty self snapshot; PDF-only `withData=false`; exact tuple revalidated before/after picker and response; direct `DocumentService` call (`73b505bcf`) | CODE-GREEN |
| backend privacy | current bytes classified before caches; exact plan returns processing-only UUID and zero facts; no personal extractor, `DocumentModel`, GET row, RAG, raw preview or response cache (`b30e3c109`) | CODE-GREEN; backend wrapper lenses P0/P1=0 |
| kind precedence | explicit certificate title or two structured personal `label: value` facts outrank a regulation mention (`ba0f331a0`) | CODE-GREEN |
| review writer | dedicated source-date/legal-year review; exact `accept -> record`; record-only identical-receipt retry; discard session then `/retraite`; no impact/Biography/generic sync (`4907667b8`, spy repair `deb199c7f`) | CODE-GREEN |
| durable authority + consumer | existing strict self metadata, exact raw-free BND resolution, card/local sheet in all loaded Dashboard branches, privacy boundary and six complete specialist questions (`eed6884ac`, `d58ed29b2`, `242d7d082`, `f86a29cde`) | CODE-GREEN |
| exact-SHA mobile runtime | production-shaped widget/provider acquisition with injected synthetic PDF and exact zero-fact uploader response -> review writer -> process termination -> cold Dashboard reader, plus replacement invalidation; `private_fixture_used=false` | **MISSING** |
| default-off/recovery runtime | Maestro before/after selector hidden with flags off; missing/cold `scanSessionId` recovery; no stale writer CTA | **MISSING** |
| final independent review | post-writer Sonnet reruns plus Opus final code/product confirmations | **PASS, P0/P1=0** |
| tracked evidence bundle | archive sanitized runtime outputs and the accepted audit outputs without private fixture/path/hash/raw bytes | **MISSING** |
| activation | three local flags remain false and outside remote hydration | **NO-GO** |

Therefore the obsolete statement is specifically **“no production mobile plan
acquisition/review caller.”** That facade gap is closed in code. The still-live
gap is exact-SHA runtime, tracked evidence archival and activation acceptance,
not acquisition wiring or final independent review. G1 remains open and G2/G3
remain forbidden.

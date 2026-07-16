Verification complete. The strict `LppEvidenceFactKey` set (`apps/mobile/lib/models/lpp_evidence.dart:52-117`) is a fixed, pre-existing model enum — this diff renders it faithfully and does not narrow it. That reframes the coverage question as a standing model-scope observation, not a regression introduced here.

---

Product/domain verdict: PASS

This diff wires the strict person-owned LPP ledger to a raw-free "confirmed document reference" that surfaces in Timeline and Document Detail. It is default-off in production (`typedLppEvidence`, `documentLppEvidenceEnabled`, `partnerLppAccountabilityEnabled` all false), privacy-preserving, fail-closed, and genuinely wired (real `ChangeNotifierProxyProvider(2)` in `app.dart`, real `recordConfirmedLppReview` injection at `/scan/review`, and a grep-based anti-facade test). No new Swiss thresholds, constants, or calculations are introduced, so no current-law-sensitive value could regress. Verdict is PASS.

## P0 — none

## P1 — none
No confident-wrong Swiss logic, no privacy exposure, no harmful-decision path. Notably strong: the reference stores exactly `{referenceId, kind, snapshotId, ownerKind, confirmedAt}` and the read path fails closed on hydration failure, snapshot replacement, owner mismatch, and expired partner authority (`document_provider.dart` `byId`/`currentReferences`; `coach_profile_provider.dart` `currentLppSnapshot`). Delete removes only metadata, ledger facts persist (`document_detail_screen.dart:_confirmDeleteReference` + `documentReferenceRemoveMessage`).

## P2

- **Confirmed detail shows no data vintage.** `_buildConfirmedReferenceContent` (`document_detail_screen.dart`) renders bare CHF/percent values with no "as of [certificate effective date]" or `confirmedAt`, even though the strict facts carry `sourceDate` and the reference carries `confirmedAt`. For a lucidity product, a pension certificate's effective date is material (vested capital grows yearly). Surface the certificate `sourceDate` / `confirmedAt` on the detail so a user cannot read stale-vintage capital as "today". Freshness decay per `DATA_LEDGER §5` is also not reflected here.

- **Survivor pensions absent from durable LPP evidence (model scope, not this diff).** The strict `LppEvidenceFactKey` enum (`lpp_evidence.dart:52-117`) has `deathCapitalLumpSumChf` but no spouse/orphan survivor **pension** keys (`rente de conjoint/veuf`, `rente d'enfant`), even though the legacy volatile view and ARB strings (`documentsFieldRenteConjoint`, `documentsFieldRenteEnfant`) still exist. Death lump-sum alone does not capture ongoing LPP survivor annuities, which are central to Swiss succession/death lucidity. This diff faithfully renders the model, so it is not a regression here — but the confirmed-reference surface it introduces makes the gap user-visible. Recommend a follow-up to extend the strict fact set (and the succession dossier) with survivor pensions.

- **Reduced confirmed field set vs legacy preview.** Confirmed detail omits `salaireAvs`, `deductionCoordination`, `tauxEnveloppe`, and employee/employer contributions that the legacy `_buildDetailContent` shows, because they are not strict fact keys. Acceptable (strict = confirmed), but worth an explicit product decision so users don't perceive data loss between the review preview and the confirmed record.

- **Orphaned stale references accumulate.** Replacing an LPP snapshot leaves the prior `ConfirmedDocumentReference` in `_confirmed_document_references_v1` forever (filtered out of `currentReferences`, never GC'd). Tiny 5-field records, but consider pruning references whose `snapshotId` no longer matches any current owner slot.

- **"Fields extracted N/N" wording on a confirmed record.** `documentDetailFieldsExtracted(snapshot.facts.length, snapshot.facts.length)` reuses extraction-phase copy on a confirmed reference; reads fine (N/N) but "extracted" is slightly off-register for a confirmed ledger fact.

## Swiss domain review
- **LPP (2nd pillar):** Core flow. Field labels/units are coherent — capitals in CHF (obligatoire/surobligatoire/total with the `LppBalanceCoherence` total≥parts invariant reused), insured salary and pensions `/an`, conversion + fund-return rates rendered via `_ratioAsPercent` (decimal→%, e.g. 0.02→2.0%). `fundReturnRateRatio` remains quarantined from calculator-facing `rendementCaisse` (`withLppEvidenceProjectionFrom` keeps current, not certificate). **Gap:** no survivor (veuve/veuf, orphelin) pension keys (see P2).
- **Succession/inheritance:** Touched only via LPP death capital; survivor pensions and their tax/beneficiary-order consequences are out of scope of the strict model.
- **AVS / 3a / tax / mortgage / disability insurance:** Not affected. Disability LPP pension/capital keys are displayed but no disability-gap logic changes. No new tax/mortgage constants.
- **Legal boundaries:** No advice, ranking, guarantee, or product-recommendation language added; new ARB strings are neutral state/notice copy.

## Mint product logic review
This moves Mint toward the ledger → DataQuest → scenario → dossier spine correctly. It is a textbook I-4 island fix done the safe way: the strict `_coach_lpp_evidence_v1` root stays the sole financial authority, and `DocumentProvider`/`TimelineProvider` become read-only, authority-gated projections that own no financial facts. No duplicated source of truth, no `GoRouter.extra` domain payload (deep link is opaque `/documents/<referenceId>`), and confirmed facts resolve back through `currentLppSnapshot`. The Timeline document node now delivers real value (routes to the confirmed cert view) instead of the prior dead `/explore` link. Consistent with the docs' `ticket_only` status: this is code-GREEN wiring, and the change does not, by itself, close G1 or authorize activation — runtime/wrapper evidence remains the separate gate, which is correctly not claimed here.
